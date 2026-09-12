import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let startupPersistenceWarning: String?

    init(startupPersistenceWarning: String? = nil) {
        self.startupPersistenceWarning = startupPersistenceWarning
    }

    @State private var match = Match()
    @State private var showingSetup = true
    @State private var showingAnalysis = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var showingSavedMatchAnalysis = false
    @State private var savedMatchForAnalysis: Match? = nil
    @State private var savedGameForAnalysis: Game? = nil
    @State private var showingPreviousGameAnalysis = false
    @State private var showingCancelConfirm = false
    @State private var showingLetSelector = false
    @State private var rallyElapsedTime: TimeInterval = 0
    @State private var rallyTimer: Timer? = nil
    @State private var recoverableMatch: Match?
    @State private var showingRecoveryPrompt = false
    @State private var hasCheckedForRecovery = false
    @State private var persistenceErrorMessage: String?
    @State private var showingPersistenceError = false
    @State private var showingStartupPersistenceWarning = false

    private var currentGame: Game {
        match.currentGame
    }

    var body: some View {
        ZStack {
            // Main game view
            gameView

            // Point type selector overlay (shown after player selection)
            if currentGame.selectedPlayer != nil && currentGame.selectedPointType == nil {
                pointTypeSelectorOverlay
            }

            // Shot type selector overlay (shown after zone selection)
            if currentGame.selectedZone != nil {
                shotTypeSelectorOverlay
            }

            // Setup overlay
            if showingSetup {
                MatchSetupView(match: match, isPresented: $showingSetup, onViewHistory: {
                    showingSetup = false
                    showingHistory = true
                })
                    .transition(.opacity)
            }

            // Coach Dashboard overlay (replaces old AnalysisView)
            if showingAnalysis {
                CoachDashboardView(game: currentGame, match: match) {
                    showingAnalysis = false
                }
                .transition(.opacity)
            }

            // Game over overlay (when not showing analysis yet)
            if currentGame.isGameOver && !showingAnalysis && currentGame.selectedZone == nil {
                GameOverOverlay(
                    game: currentGame,
                    match: match,
                    onAnalysis: { showingAnalysis = true },
                    onNextGame: {
                        match.onGameEnd()
                        persistMatch()
                    },
                    onNewMatch: {
                        finishOrAbandonCurrentMatch()
                        match = Match()
                        showingSetup = true
                    },
                    onStop: {
                        abandonCurrentMatch()
                        match = Match()
                        showingSetup = true
                    },
                    onUndo: {
                        // Reset status first: the points-count change below re-persists the match.
                        match.status = .inProgress
                        withAnimation { currentGame.undoLastPoint() }
                    }
                )
                .onAppear {
                    if match.isMatchOver { match.status = .completed }
                    persistMatch()
                }
            }

            // Previous game analysis overlay
            if showingPreviousGameAnalysis, match.currentGameIndex > 0 {
                CoachDashboardView(game: match.games[match.currentGameIndex - 1], match: match) {
                    showingPreviousGameAnalysis = false
                }
                .transition(.opacity)
            }

            // Saved match analysis overlay
            if showingSavedMatchAnalysis, let reviewGame = savedGameForAnalysis {
                CoachDashboardView(game: reviewGame, match: savedMatchForAnalysis) {
                    showingSavedMatchAnalysis = false
                    savedMatchForAnalysis = nil
                    savedGameForAnalysis = nil
                }
                .transition(.opacity)
            }

            // History overlay
            if showingHistory {
                MatchHistoryView(
                    isPresented: $showingHistory,
                    onSelectMatch: { savedMatch in
                        let liveMatch = savedMatch.toMatch()
                        savedMatchForAnalysis = liveMatch
                        savedGameForAnalysis = liveMatch.currentGame
                        showingHistory = false
                        showingSavedMatchAnalysis = true
                    },
                    onSelectGame: { savedGame in
                        savedMatchForAnalysis = nil
                        savedGameForAnalysis = savedGame.toGame()
                        showingHistory = false
                        showingSavedMatchAnalysis = true
                    }
                )
                .transition(.opacity)
            }

            // Settings overlay
            if showingSettings {
                SettingsView(isPresented: $showingSettings)
                    .transition(.opacity)
            }

            // Let selector overlay
            if showingLetSelector {
                LetSelectorOverlay(
                    game: currentGame,
                    onLetSelected: { player in
                        currentGame.addLet(requestedBy: player)
                        showingLetSelector = false
                    },
                    onCancel: {
                        showingLetSelector = false
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingLetSelector)
        .animation(.easeInOut(duration: 0.3), value: showingSetup)
        .animation(.easeInOut(duration: 0.3), value: showingAnalysis)
        .animation(.easeInOut(duration: 0.3), value: showingHistory)
        .animation(.easeInOut(duration: 0.3), value: showingPreviousGameAnalysis)
        .animation(.easeInOut(duration: 0.3), value: showingSavedMatchAnalysis)
        .animation(.easeInOut(duration: 0.3), value: showingSettings)
        .animation(.easeInOut(duration: 0.25), value: currentGame.scoringStep)
        .onAppear {
            startRallyTimer()
            checkForInterruptedMatch()
            showingStartupPersistenceWarning = startupPersistenceWarning != nil
        }
        .onDisappear {
            stopRallyTimer()
        }
        .onChange(of: currentGame.points.count) { _, _ in
            // Reset timer when a point is scored
            rallyElapsedTime = 0
            persistMatch()
        }
        .onChange(of: currentGame.lets.count) { _, _ in
            // Reset timer when a let is called
            rallyElapsedTime = 0
            persistMatch()
        }
        .onChange(of: showingSetup) { _, isShowing in
            if isShowing {
                stopRallyTimer()
            } else {
                startRallyTimer()
                if !showingHistory { persistMatch() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                persistMatch()
            }
        }
        .alert("Wedstrijd stoppen?", isPresented: $showingCancelConfirm) {
            Button("Annuleren", role: .cancel) { }
            Button("Stoppen", role: .destructive) {
                abandonCurrentMatch()
                match = Match()
                showingSetup = true
            }
        } message: {
            Text("Weet je zeker dat je deze wedstrijd wilt stoppen? De huidige wedstrijd gaat verloren.")
        }
        .alert("Wedstrijd hervatten?", isPresented: $showingRecoveryPrompt) {
            Button("Hervatten") {
                if let recoverableMatch {
                    match = recoverableMatch
                    showingSetup = false
                }
                self.recoverableMatch = nil
            }
            Button("Afbreken", role: .destructive) {
                if let recoverableMatch {
                    try? SwiftDataMatchRepository(context: modelContext).markAbandoned(recoverableMatch)
                }
                self.recoverableMatch = nil
            }
            // Explicit cancel role, otherwise SwiftUI adds an untranslated "Cancel" button
            Button("Later", role: .cancel) {
                self.recoverableMatch = nil
            }
        } message: {
            if let recoverableMatch {
                Text("\(recoverableMatch.player1Name) – \(recoverableMatch.player2Name) is nog niet afgerond.")
            }
        }
        .alert("Opslaan mislukt", isPresented: $showingPersistenceError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceErrorMessage ?? "Onbekende opslagfout")
        }
        .alert("Veilige tijdelijke opslag actief", isPresented: $showingStartupPersistenceWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(startupPersistenceWarning ?? "")
        }
    }

    // MARK: - Local-first persistence
    private func persistMatch() {
        guard !showingSetup else { return }
        do {
            try SwiftDataMatchRepository(context: modelContext).upsert(match)
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showingPersistenceError = true
        }
    }

    private func checkForInterruptedMatch() {
        guard !hasCheckedForRecovery else { return }
        hasCheckedForRecovery = true
        do {
            recoverableMatch = try SwiftDataMatchRepository(context: modelContext).mostRecentInProgressMatch()
            showingRecoveryPrompt = recoverableMatch != nil
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showingPersistenceError = true
        }
    }

    private func finishOrAbandonCurrentMatch() {
        if match.isMatchOver {
            match.status = .completed
            persistMatch()
        } else {
            abandonCurrentMatch()
        }
    }

    private func abandonCurrentMatch() {
        guard !showingSetup else { return }
        do {
            try SwiftDataMatchRepository(context: modelContext).markAbandoned(match)
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showingPersistenceError = true
        }
    }

    // MARK: - Game View
    private var gameView: some View {
        ZStack {
            // Warm dark background with glow
            AppBackground()

            VStack(spacing: 12) {
                // Header
                headerView

                // Scoreboard
                ScoreboardView(game: currentGame, match: match)
                    .padding(.horizontal, 20)

                // Rally timer and instruction text
                HStack(spacing: 8) {
                    RallyTimerView(elapsedTime: rallyElapsedTime)
                        .opacity(currentGame.isGameOver || showingSetup ? 0 : 1)

                    Spacer(minLength: 0)

                    instructionText
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    // Balances the timer so the instruction stays centred
                    RallyTimerView(elapsedTime: rallyElapsedTime)
                        .hidden()
                }
                .padding(.horizontal, 24)
                .frame(height: 34)

                // Court view
                CourtView(game: currentGame) { zone in
                    handleZoneTap(zone)
                }
                .padding(.horizontal, 16)

                // Player buttons (hidden when point type or shot is being selected)
                if currentGame.selectedPlayer == nil {
                    PlayerButtonsView(game: currentGame) { player in
                        handlePlayerSelect(player)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Let / Undo row + last point
                bottomActions
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Point Type Selector Overlay
    private var pointTypeSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        currentGame.goBackStep()
                    }
                }

            PointTypeSelectorOverlay(
                game: currentGame,
                onPointTypeSelected: { pointType in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentGame.selectPointType(pointType)
                    }
                },
                onBack: {
                    withAnimation {
                        currentGame.goBackStep()
                    }
                }
            )
        }
        .transition(.opacity)
    }

    // MARK: - Shot Type Selector Overlay
    private var shotTypeSelectorOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        currentGame.goBackStep()
                    }
                }

            VStack {
                Spacer()

                ShotTypeSelectorView(
                    game: currentGame,
                    onShotSelected: { shotType in
                        handleShotTypeSelect(shotType)
                    },
                    onBack: {
                        withAnimation {
                            currentGame.goBackStep()
                        }
                    }
                )

                Spacer().frame(height: 60)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Header View (same layout as the referee top bar)
    private var headerView: some View {
        ZStack {
            Text("COACH")
                .font(AppFonts.title(14))
                .foregroundColor(AppColors.textPrimary)
                .tracking(2)

            HStack {
                // Stop match
                Button(action: { showingCancelConfirm = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Stop")
                    }
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    // Previous game analysis
                    if match.currentGameIndex > 0 && !currentGame.isGameOver {
                        Button(action: { showingPreviousGameAnalysis = true }) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.accentGold)
                        }
                    }

                    Button(action: { showingHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Instruction Text
    private var instructionText: some View {
        Group {
            switch currentGame.scoringStep {
            case .selectPlayer:
                Text("Kies wie scoort")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)
            case .selectPointType:
                Text("Hoe werd het punt gewonnen?")
                    .font(AppFonts.body(14))
                    .foregroundColor(currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
            case .selectZone:
                Text("Tik op de baan waar het punt viel")
                    .font(AppFonts.body(14))
                    .foregroundColor(currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
            case .selectShot:
                Text("Kies het type slag")
                    .font(AppFonts.body(14))
                    .foregroundColor(currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
            }
        }
    }

    // MARK: - Bottom actions (referee-style outlined buttons)
    private var bottomActions: some View {
        let selecting = currentGame.selectedZone != nil
        let letDisabled = selecting || currentGame.isGameOver
        let undoDisabled = selecting || !currentGame.canUndo

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                coachActionButton("LET CALL", icon: "arrow.counterclockwise",
                                  color: AppColors.warmOrange, disabled: letDisabled) {
                    showingLetSelector = true
                }
                coachActionButton("UNDO", icon: "arrow.uturn.backward",
                                  color: AppColors.textPrimary, disabled: undoDisabled) {
                    withAnimation { currentGame.undoLastPoint() }
                }
            }

            // Last point indicator
            HStack(spacing: 6) {
                if let lastPoint = currentGame.lastPoint, currentGame.selectedPlayer == nil {
                    Circle()
                        .fill(lastPoint.scorer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
                        .frame(width: 6, height: 6)
                    if let zone = lastPoint.zone, let shot = lastPoint.shotType {
                        Text("\(currentGame.name(for: lastPoint.scorer)): \(zone.shortName) (\(shot.shortName)) · \(lastPoint.pointType.shortName)")
                    } else {
                        Text("\(currentGame.name(for: lastPoint.scorer)): \(lastPoint.pointType.shortName)")
                    }
                }
            }
            .font(AppFonts.caption(11))
            .foregroundColor(AppColors.textMuted)
            .lineLimit(1)
            .frame(height: 16)
        }
    }

    private func coachActionButton(_ title: String, icon: String, color: Color, disabled: Bool,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(AppFonts.label(13))
                    .tracking(1)
            }
            .foregroundColor(disabled ? AppColors.textMuted : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(disabled ? 0.04 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(disabled ? 0.08 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Handlers
    private func handlePlayerSelect(_ player: Player) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentGame.selectedPlayer == player {
                currentGame.clearSelection()
            } else {
                currentGame.selectPlayer(player)
            }
        }
    }

    private func handleZoneTap(_ zone: CourtZone) {
        guard currentGame.selectedPlayer != nil else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.selectZone(zone)
        }
    }

    private func handleShotTypeSelect(_ shotType: ShotType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.addPoint(shotType: shotType)
        }
    }

    // MARK: - Rally Timer
    private func startRallyTimer() {
        stopRallyTimer()
        rallyElapsedTime = Date().timeIntervalSince(currentGame.lastPointTime)
        rallyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            rallyElapsedTime = Date().timeIntervalSince(currentGame.lastPointTime)
        }
    }

    private func stopRallyTimer() {
        rallyTimer?.invalidate()
        rallyTimer = nil
    }
}

// MARK: - Rally Timer View
struct RallyTimerView: View {
    let elapsedTime: TimeInterval

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 12))
                .foregroundColor(AppColors.accentGold.opacity(0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text("RALLY")
                    .font(AppFonts.caption(8))
                    .foregroundColor(AppColors.textMuted)
                    .tracking(1)
                Text(formattedTime)
                    .font(AppFonts.score(14))
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Match Setup View

enum SetupMode { case coach, referee }

struct MatchSetupView: View {
    let match: Match
    @Binding var isPresented: Bool
    var onViewHistory: (() -> Void)? = nil

    @State private var selectedMode: SetupMode = .coach

    @State private var player1Name: String = ""
    @State private var player2Name: String = ""
    @State private var startingServer: Player = .player1

    @State private var player1CoachingFocus: [String] = []
    @State private var player1CoachingNotes: String = ""
    @State private var player2CoachingFocus: [String] = []
    @State private var player2CoachingNotes: String = ""

    @State private var showingPlayer1Picker = false
    @State private var showingPlayer2Picker = false
    @State private var showingPlayerManagement = false
    @State private var createdRefereeMatch: RefereeMatch? = nil

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────────
                HStack {
                    // History icon — consistent across the whole app
                    if let onViewHistory = onViewHistory {
                        Button(action: onViewHistory) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        Color.clear.frame(width: 22)
                    }

                    Spacer()

                    Text("SQUASH ANALYZER")
                        .font(AppFonts.title(20))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(3)

                    Spacer()

                    Button(action: { showingPlayerManagement = true }) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accentGold)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 24)

                // ── Mode toggle ─────────────────────────────────────────────
                modePicker
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                Spacer()

                // ── Player names ────────────────────────────────────────────
                VStack(spacing: 20) {
                    PlayerNameInputWithPicker(
                        title: "Speler 1",
                        name: $player1Name,
                        coachingFocus: selectedMode == .coach ? player1CoachingFocus : [],
                        color: AppColors.warmOrange,
                        placeholder: "Naam speler 1",
                        onPickPlayer: { showingPlayer1Picker = true }
                    )
                    PlayerNameInputWithPicker(
                        title: "Speler 2",
                        name: $player2Name,
                        coachingFocus: selectedMode == .coach ? player2CoachingFocus : [],
                        color: AppColors.steelBlue,
                        placeholder: "Naam speler 2",
                        onPickPlayer: { showingPlayer2Picker = true }
                    )
                }
                .padding(.horizontal, 24)

                // ── First server ─────────────────────────────────────────────
                VStack(spacing: 12) {
                    Text("Wie serveert eerst?")
                        .font(AppFonts.label(14))
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 16) {
                        ServerSelectionButton(
                            name: player1Name.isEmpty ? "Speler 1" : player1Name,
                            color: AppColors.warmOrange,
                            isSelected: startingServer == .player1
                        ) { startingServer = .player1 }

                        ServerSelectionButton(
                            name: player2Name.isEmpty ? "Speler 2" : player2Name,
                            color: AppColors.steelBlue,
                            isSelected: startingServer == .player2
                        ) { startingServer = .player2 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                // ── Start button ─────────────────────────────────────────────
                if selectedMode == .coach {
                    HardwareButton(
                        title: "Start Wedstrijd",
                        subtitle: nil,
                        color: AppColors.warmOrange,
                        colorDark: AppColors.warmOrangeDark
                    ) {
                        startMatch()
                    }
                    .padding(.horizontal, 24)
                } else {
                    HardwareButton(
                        title: "Start Scheidsrechter",
                        subtitle: nil,
                        color: AppColors.warmOrange,
                        colorDark: AppColors.warmOrangeDark
                    ) {
                        startReferee()
                    }
                    .padding(.horizontal, 24)
                }

                Spacer().frame(height: 44)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedMode)
        .sheet(isPresented: $showingPlayer1Picker) {
            PlayerManagementView { player in
                player1Name = player.name
                player1CoachingFocus = player.coachingFocusAreas
                player1CoachingNotes = player.coachingNotes
            }
        }
        .sheet(isPresented: $showingPlayer2Picker) {
            PlayerManagementView { player in
                player2Name = player.name
                player2CoachingFocus = player.coachingFocusAreas
                player2CoachingNotes = player.coachingNotes
            }
        }
        .sheet(isPresented: $showingPlayerManagement) {
            PlayerManagementView()
        }
        .fullScreenCover(item: $createdRefereeMatch) { m in
            RefereeView(match: m) { createdRefereeMatch = nil }
        }
    }

    // ── Mode picker ───────────────────────────────────────────────────────────

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab(mode: .coach,   icon: "chart.bar.xaxis", title: "COACH")
            modeTab(mode: .referee, icon: "whistle",          title: "SCHEIDSRECHTER")
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func modeTab(mode: SetupMode, icon: String, title: String) -> some View {
        let isSelected = selectedMode == mode
        let color: Color = AppColors.warmOrange
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedMode = mode }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(AppFonts.label(12))
                    .tracking(1)
            }
            .foregroundColor(isSelected ? AppColors.backgroundDark : color.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(isSelected ? color : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    private func startMatch() {
        match.setupMatch(
            player1: player1Name,
            player2: player2Name,
            startingServer: startingServer,
            player1CoachingFocus: player1CoachingFocus,
            player1CoachingNotes: player1CoachingNotes,
            player2CoachingFocus: player2CoachingFocus,
            player2CoachingNotes: player2CoachingNotes
        )
        isPresented = false
    }

    private func startReferee() {
        let p1 = player1Name.trimmingCharacters(in: .whitespaces)
        let p2 = player2Name.trimmingCharacters(in: .whitespaces)
        createdRefereeMatch = RefereeMatch(
            player1Name: p1.isEmpty ? "Speler 1" : p1,
            player2Name: p2.isEmpty ? "Speler 2" : p2,
            bestOf: 5,
            startingServer: startingServer
        )
    }
}

// MARK: - Player Name Input with Picker
struct PlayerNameInputWithPicker: View {
    let title: String
    @Binding var name: String
    let coachingFocus: [String]
    let color: Color
    let placeholder: String
    let onPickPlayer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(AppFonts.caption(11))
                    .foregroundColor(color)
                    .tracking(1)
                Spacer()
                Button(action: onPickPlayer) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 12))
                        Text("Kies speler")
                            .font(AppFonts.caption(11))
                    }
                    .foregroundColor(AppColors.accentGold)
                }
            }

            HStack(spacing: 0) {
                TextField(placeholder, text: $name)
                    .font(AppFonts.body(16))
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )

            // Show selected coaching focus tags
            if !coachingFocus.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(coachingFocus, id: \.self) { tag in
                            Text(tag)
                                .font(AppFonts.caption(10))
                                .foregroundColor(color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(color.opacity(0.15)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Server Selection Button
struct ServerSelectionButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? color : AppColors.textMuted)

                Text(name)
                    .font(AppFonts.label(13))
                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

// MARK: - Game Over Overlay
struct GameOverOverlay: View {
    let game: Game
    let match: Match
    let onAnalysis: () -> Void
    let onNextGame: () -> Void
    let onNewMatch: () -> Void
    var onStop: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text(match.isMatchOver ? "WEDSTRIJD KLAAR" : "GAME \(match.currentGameIndex + 1) KLAAR")
                    .font(AppFonts.title(22))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Winner announcement
                if let winner = game.winner {
                    Text("\(game.name(for: winner)) wint\(match.isMatchOver ? " de wedstrijd!" : " de game!")")
                        .font(AppFonts.body(18))
                        .foregroundColor(AppColors.accentGold)
                }

                // Score display
                HStack(spacing: 12) {
                    LEDScoreDisplay(score: game.player1Score, size: 60)
                    LEDColon(size: 60)
                    LEDScoreDisplay(score: game.player2Score, size: 60)
                }
                .padding(16)
                .background(LEDDisplayBackground())

                // Games score
                if match.games.count > 1 || match.isMatchOver {
                    Text("Games: \(match.player1GamesWon) - \(match.player2GamesWon)")
                        .font(AppFonts.label(14))
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack(spacing: 12) {
                    // Auto-save indicator
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text(match.isMatchOver ? "Wedstrijd automatisch opgeslagen" : "Game automatisch opgeslagen")
                            .font(AppFonts.caption(11))
                            .foregroundColor(AppColors.textMuted)
                    }

                    // Analysis button
                    HardwareButton(
                        title: "Bekijk Analyse",
                        subtitle: nil,
                        color: AppColors.accentGold,
                        colorDark: AppColors.accentGoldDark
                    ) {
                        onAnalysis()
                    }

                    // Next game or new match button
                    if match.isMatchOver {
                        HardwareButton(
                            title: "Nieuwe Wedstrijd",
                            subtitle: nil,
                            color: AppColors.warmOrange,
                            colorDark: AppColors.warmOrangeDark
                        ) {
                            onNewMatch()
                        }
                    } else {
                        HardwareButton(
                            title: "Volgende Game",
                            subtitle: nil,
                            color: AppColors.warmOrange,
                            colorDark: AppColors.warmOrangeDark
                        ) {
                            onNextGame()
                        }

                    }

                    if let undo = onUndo {
                        OverlayUndoButton(action: undo)
                    }

                    // Stop button (mid-match)
                    if !match.isMatchOver, let stop = onStop {
                        Button(action: stop) {
                            Text("Stop wedstrijd")
                                .font(AppFonts.caption(13))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.backgroundMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.accentGold.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: AppColors.warmOrangeGlow.opacity(0.2), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Let Selector Overlay
struct LetSelectorOverlay: View {
    let game: Game
    let onLetSelected: (Player) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 20) {
                Text("LET")
                    .font(AppFonts.title(22))
                    .foregroundColor(AppColors.accentGold)
                    .tracking(3)

                Text("Wie vraagt de let?")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 16) {
                    // Player 1 button
                    Button(action: { onLetSelected(.player1) }) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 24))
                            Text(game.player1Name)
                                .font(AppFonts.label(14))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .foregroundColor(AppColors.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.warmOrange.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.warmOrange, lineWidth: 2)
                        )
                    }

                    // Player 2 button
                    Button(action: { onLetSelected(.player2) }) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 24))
                            Text(game.player2Name)
                                .font(AppFonts.label(14))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .foregroundColor(AppColors.textPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.steelBlue.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.steelBlue, lineWidth: 2)
                        )
                    }
                }

                // Let count display
                if game.totalLets > 0 {
                    Text("Lets deze game: \(game.totalLets)")
                        .font(AppFonts.caption(12))
                        .foregroundColor(AppColors.textMuted)
                }

                // Cancel button
                Button(action: onCancel) {
                    Text("Annuleren")
                        .font(AppFonts.label(14))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.backgroundMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.accentGold.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Point Type Selector Overlay

struct PointTypeSelectorOverlay: View {
    let game: Game
    let onPointTypeSelected: (PointType) -> Void
    let onBack: () -> Void

    private var playerColor: Color {
        game.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            if let player = game.selectedPlayer {
                Text("\(game.name(for: player).uppercased()) SCOORT")
                    .font(AppFonts.caption(11))
                    .foregroundColor(playerColor)
                    .tracking(1.5)
            }

            Text("Hoe werd het punt gewonnen?")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)

            // Point type buttons
            VStack(spacing: 12) {
                PointTypeButton(
                    pointType: .winner,
                    color: playerColor,
                    action: { onPointTypeSelected(.winner) }
                )
                PointTypeButton(
                    pointType: .forcedError,
                    color: playerColor,
                    action: { onPointTypeSelected(.forcedError) }
                )
                PointTypeButton(
                    pointType: .unforcedError,
                    color: playerColor,
                    action: { onPointTypeSelected(.unforcedError) }
                )
            }

            // Back button
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Terug")
                        .font(AppFonts.caption(12))
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.backgroundMedium.opacity(0.97))
                .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(playerColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

struct PointTypeButton: View {
    let pointType: PointType
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: pointType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pointType.rawValue.uppercased())
                        .font(AppFonts.label(13))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(0.5)
                    Text(pointType.description)
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(pointType.shortName)
                    .font(AppFonts.mono(13))
                    .foregroundColor(color.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Main Game") {
    ContentView()
}
