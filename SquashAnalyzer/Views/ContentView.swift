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
    @State private var showingResultCompletion = false
    @State private var showingLetSelector = false
    @State private var rallyElapsedTime: TimeInterval = 0
    @State private var rallyTimer: Timer? = nil
    @State private var recoverableMatch: Match?
    @State private var showingRecoveryPrompt = false
    @State private var hasCheckedForRecovery = false
    @State private var persistenceErrorMessage: String?
    @State private var showingPersistenceError = false
    @State private var showingStartupPersistenceWarning = false
    @AppStorage(CoachInputSettings.modeKey) private var inputModeRaw = CoachInputMode.scoreTap.rawValue

    private var inputMode: CoachInputMode { CoachInputMode(rawValue: inputModeRaw) ?? .scoreTap }
    private var quickEntry: Bool { inputMode == .quick }
    private var scoreTapEntry: Bool { inputMode == .scoreTap }

    private var currentGame: Game {
        match.currentGame
    }

    var body: some View {
        ZStack {
            // Main game view
            gameView

            // Point type selector overlay (shown after player selection; inline in the score-tap flow)
            if !scoreTapEntry && currentGame.selectedPlayer != nil && currentGame.selectedPointType == nil {
                pointTypeSelectorOverlay
            }

            // Shot type selector overlay (shown after zone selection; inline in the score-tap flow)
            if !scoreTapEntry && currentGame.selectedZone != nil {
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
                    onStop: { requestStop() },
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

            // Fill in the winners of the games that were not tracked
            if showingResultCompletion {
                MatchResultCompletionSheet(match: match) { winners in
                    if match.completeResult(with: winners) {
                        persistMatch()
                        match = Match()
                        showingSetup = true
                    }
                    showingResultCompletion = false
                } onCancel: {
                    showingResultCompletion = false
                }
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
        .animation(.easeInOut(duration: 0.3), value: showingResultCompletion)
        .animation(.easeInOut(duration: 0.25), value: currentGame.scoringStep)
        .onAppear {
            startRallyTimer()
            #if DEBUG
            ScreenshotScenario.importTeamIfRequested(context: modelContext)
            if let scenario = ScreenshotScenario.current {
                applyScreenshotScenario(scenario)
                return
            }
            #endif
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
        .alert("Incomplete wedstrijd opslaan?", isPresented: $showingCancelConfirm) {
            Button("Opslaan als incompleet") {
                abandonCurrentMatch()
                match = Match()
                showingSetup = true
            }
            Button("Uitslag aanvullen") {
                showingResultCompletion = true
            }
            Button("Niet opslaan", role: .destructive) {
                discardCurrentMatch()
                match = Match()
                showingSetup = true
            }
            Button("Doorspelen", role: .cancel) { }
        } message: {
            Text("\(match.player1Name) – \(match.player2Name) staat \(match.player1GamesWon)-\(match.player2GamesWon) in games en is nog niet afgelopen. Sla hem op als incompleet, vul de winnaars van de gemiste games in, of gooi hem weg.")
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

    #if DEBUG
    // MARK: - App Store screenshots (see scripts/screenshots.sh)
    private func applyScreenshotScenario(_ scenario: ScreenshotScenario) {
        switch scenario {
        case .setup, .referee:
            break   // handled by MatchSetupView
        case .coachMatch:
            match = ScreenshotScenario.makeCoachMatch()
            showingSetup = false
        case .coachZone:
            match = ScreenshotScenario.makeCoachZoneMatch()
            showingSetup = false
        case .coachGameOver:
            match = ScreenshotScenario.makeCoachGameOverMatch()
            showingSetup = false
        case .history:
            _ = ScreenshotScenario.seededSampleMatch(context: modelContext)
            showingSetup = false
            showingHistory = true
        case .dashboard:
            guard let saved = ScreenshotScenario.seededSampleMatch(context: modelContext) else { return }
            let liveMatch = saved.toMatch()
            savedMatchForAnalysis = liveMatch
            savedGameForAnalysis = liveMatch.currentGame
            showingSetup = false
            showingSavedMatchAnalysis = true
        }
    }
    #endif

    // MARK: - Local-first persistence
    private func persistMatch() {
        guard !showingSetup else { return }
        #if DEBUG
        if ScreenshotScenario.isActive { return }
        #endif
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

    /// Stopping a match that is not over asks whether to keep it; one without any
    /// recorded rally is discarded straight away.
    private func requestStop() {
        if match.isMatchOver {
            finishOrAbandonCurrentMatch()
        } else if match.allPoints.isEmpty && match.allLets.isEmpty && match.firstGameNumber == 1 {
            discardCurrentMatch()
        } else {
            showingCancelConfirm = true
            return
        }
        match = Match()
        showingSetup = true
    }

    private func discardCurrentMatch() {
        guard !showingSetup else { return }
        do {
            try SwiftDataMatchRepository(context: modelContext).delete(match)
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showingPersistenceError = true
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

                // Scoreboard (tapping a score starts a point in the score-tap flow)
                ScoreboardView(game: currentGame, match: match,
                               onSelectPlayer: scoreTapEntry ? { player in handleScoreTap(player) } : nil)
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

                if scoreTapEntry {
                    // Score-tap flow: the middle of the screen shows only the current step
                    scoreTapStage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Court view
                    CourtView(game: currentGame) { zone in
                        handleZoneTap(zone)
                    }
                    .padding(.horizontal, 16)
                }

                // Player buttons (hidden when point type or shot is being selected)
                if !scoreTapEntry && currentGame.selectedPlayer == nil {
                    Group {
                        if quickEntry {
                            QuickEntryButtonsView(game: currentGame) { player, action in
                                handleQuickEntry(player, action)
                            }
                        } else {
                            PlayerButtonsView(game: currentGame) { player in
                                handlePlayerSelect(player)
                            }
                        }
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
                Button(action: { requestStop() }) {
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
                Text(scoreTapEntry ? "Tik op de score van wie scoort" : "Kies wie scoort")
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
                                  color: AppColors.textPrimary, disabled: letDisabled) {
                    showingLetSelector = true
                }
                coachActionButton("UNDO", icon: "arrow.uturn.backward",
                                  color: AppColors.textPrimary, disabled: undoDisabled) {
                    withAnimation { currentGame.undoLastPoint() }
                }
            }

            // Last point indicator, or the optional shot chips right after a quick-entry point
            if quickEntry, currentGame.selectedPlayer == nil, currentGame.lastPointAwaitsShot,
               let lastPoint = currentGame.lastPoint {
                shotStrip(for: lastPoint)
                    .frame(height: 28)
                    .transition(.opacity)
            } else {
                HStack(spacing: 6) {
                    if let lastPoint = currentGame.lastPoint, currentGame.selectedPlayer == nil {
                        Circle()
                            .fill(lastPoint.scorer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
                            .frame(width: 6, height: 6)
                        Text(lastPointText(lastPoint))
                    }
                }
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)
                .frame(height: 16)
            }
        }
    }

    // MARK: - Score-tap flow (staged middle area)

    /// Empty until a score is tapped, then one step at a time: point types with
    /// icons → the court for the zone → the shots with icons → empty again.
    @ViewBuilder
    private var scoreTapStage: some View {
        let color: Color = currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        switch currentGame.scoringStep {
        case .selectPlayer:
            Color.clear
        case .selectPointType:
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(PointType.allCases) { type in
                    if !type.serverOnly || currentGame.selectedPlayer == currentGame.currentServer {
                        PointTypeButton(pointType: type, color: color, compact: true) { handleInlinePointType(type) }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .transition(.opacity)
        case .selectZone:
            VStack(spacing: 10) {
                CourtView(game: currentGame) { zone in
                    handleZoneTap(zone)
                }
                .padding(.horizontal, 16)
                cancelButton
            }
            .transition(.opacity)
        case .selectShot:
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                if let zone = currentGame.selectedZone {
                    Text(zone.rawValue.uppercased())
                        .font(AppFonts.caption(11))
                        .foregroundColor(color)
                        .tracking(1.5)
                }
                HStack(spacing: 12) {
                    ForEach([ShotType.drive, .cross, .volley]) { shot in
                        ShotTypeButton(shotType: shot, color: color) { handleShotTypeSelect(shot) }
                    }
                }
                HStack(spacing: 12) {
                    ForEach([ShotType.drop, .lob, .boast]) { shot in
                        ShotTypeButton(shotType: shot, color: color) { handleShotTypeSelect(shot) }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .transition(.opacity)
        }
    }

    private var cancelButton: some View {
        Button(action: cancelInlinePoint) {
            Text("Annuleer")
                .font(AppFonts.caption(13))
                .foregroundColor(AppColors.textMuted)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    /// Tap on a score: start a point for that player, switch player, or cancel on the same one
    private func handleScoreTap(_ player: Player) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentGame.selectedPlayer == player {
                currentGame.clearSelection()
            } else {
                currentGame.zoneForUnforcedErrors = true
                currentGame.selectPlayer(player)
            }
        }
    }

    private func handleInlinePointType(_ pointType: PointType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.selectPointType(pointType)
        }
    }

    private func cancelInlinePoint() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.clearSelection()
        }
    }

    /// "Slag?" plus one chip per shot; tapping one completes the last point
    private func shotStrip(for point: Point) -> some View {
        let color: Color = point.scorer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        return HStack(spacing: 5) {
            Text("SLAG?")
                .font(AppFonts.caption(9))
                .foregroundColor(color.opacity(0.7))
                .tracking(1)
            ForEach(ShotType.allCases) { shot in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { currentGame.assignShotToLastPoint(shot) }
                    persistMatch()
                }) {
                    Text(shot.rawValue)
                        .font(AppFonts.label(11))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.10))
                                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// "Niels: Winner · Drop · Voor Links", "Niels: Stroke · Midden Links" or "Niels: Unforced error"
    private func lastPointText(_ point: Point) -> String {
        var parts = [point.pointType.title]
        if let shot = point.shotType { parts.append(shot.rawValue) }
        if let zone = point.zone { parts.append(zone.rawValue) }
        return "\(currentGame.name(for: point.scorer)): " + parts.joined(separator: " · ")
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

    private func handleQuickEntry(_ player: Player, _ action: QuickEntryAction) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.selectPlayer(player)
            switch action {
            case .winner: currentGame.selectPointType(.winner)          // → zone, then scored
            case .unforcedError: currentGame.selectPointType(.unforcedError)   // scored at once
            case .more: break                                           // point-type overlay
            }
        }
    }

    private func handleZoneTap(_ zone: CourtZone) {
        guard currentGame.selectedPlayer != nil else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.selectZone(zone)
            // Quick entry: the point is in as soon as the zone is known; the shot is optional
            if quickEntry, currentGame.selectedZone != nil, currentGame.selectedPointType?.requiresShot == true {
                currentGame.addPoint(shotType: nil)
            }
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
    @State private var player1GamesBefore: Int = 0
    @State private var player2GamesBefore: Int = 0

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

                // ── Later instappen (start at game 2–5 with the stand so far) ──
                HeadStartPicker(
                    player1Games: $player1GamesBefore,
                    player2Games: $player2GamesBefore,
                    player1Name: player1Name.isEmpty ? "Speler 1" : player1Name,
                    player2Name: player2Name.isEmpty ? "Speler 2" : player2Name
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

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
        #if DEBUG
        .onAppear {
            switch ScreenshotScenario.current {
            case .setup:
                player1Name = ScreenshotScenario.player1
                player2Name = ScreenshotScenario.player2
            case .referee:
                selectedMode = .referee
                createdRefereeMatch = ScreenshotScenario.makeRefereeMatch()
            default:
                break
            }
        }
        #endif
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
            player2CoachingNotes: player2CoachingNotes,
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore
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
            startingServer: startingServer,
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore
        )
    }
}

// MARK: - Head start picker ("Later instappen")

/// Collapsed: one muted line. Expanded: a games-won stepper per player, so a
/// match can be picked up at game 2–5 with the stand so far. Neither player can
/// already have the games needed to win.
struct HeadStartPicker: View {
    @Binding var player1Games: Int
    @Binding var player2Games: Int
    let player1Name: String
    let player2Name: String
    var bestOf: Int = 5

    @State private var expanded = false

    private var maxPerPlayer: Int { (bestOf / 2) }          // 2 for best of 5
    private var firstGame: Int { 1 + player1Games + player2Games }
    private var hasHeadStart: Bool { firstGame > 1 }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "forward.end")
                        .font(.system(size: 11, weight: .semibold))
                    Text(summaryText)
                        .font(AppFonts.caption(12))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(hasHeadStart ? AppColors.accentGold : AppColors.textMuted)
            }
            .buttonStyle(.plain)

            if expanded {
                HStack(spacing: 16) {
                    stepper(name: player1Name, value: $player1Games, color: AppColors.warmOrange)
                    stepper(name: player2Name, value: $player2Games, color: AppColors.steelBlue)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// "Later instappen" until a stand is set, then "Start bij game 3 · stand 1 – 1"
    private var summaryText: String {
        hasHeadStart ? "Start bij game \(firstGame) · stand \(player1Games) – \(player2Games)" : "Later instappen?"
    }

    private func stepper(name: String, value: Binding<Int>, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(name)
                .font(AppFonts.caption(11))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 14) {
                stepButton("minus", color: color, enabled: value.wrappedValue > 0) { value.wrappedValue -= 1 }
                Text("\(value.wrappedValue)")
                    .font(AppFonts.score(22))
                    .foregroundColor(value.wrappedValue > 0 ? color : AppColors.textSecondary)
                    .frame(minWidth: 22)
                    .contentTransition(.numericText())
                stepButton("plus", color: color, enabled: value.wrappedValue < maxPerPlayer) { value.wrappedValue += 1 }
            }

            Text("GAMES GEWONNEN")
                .font(AppFonts.caption(8))
                .foregroundColor(AppColors.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func stepButton(_ icon: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(enabled ? color : AppColors.textMuted.opacity(0.5))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(color.opacity(enabled ? 0.12 : 0.03))
                        .overlay(Circle().stroke(color.opacity(enabled ? 0.35 : 0.1), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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

    @State private var shareItems: ShareItemsWrapper? = nil

    private var winner: Player? { match.isMatchOver ? match.matchWinner : game.winner }

    /// Finished games of this match, newest last
    private var gameResults: [(number: Int, p1: Int, p2: Int, winner: Player)] {
        match.games.enumerated().compactMap { index, g in
            g.winner.map { (number: match.gameNumber(at: index), p1: g.player1Score, p2: g.player2Score, winner: $0) }
        }
    }

    var body: some View {
        ResultOverlayCard(accent: winner.map(RefereeView.color(for:))) {
            ResultTitle(match.isMatchOver ? "WEDSTRIJD KLAAR" : "GAME \(match.currentGameNumber) KLAAR")

            if match.isMatchOver {
                ResultScoreRow(
                    player1Name: match.player1Name,
                    player2Name: match.player2Name,
                    player1Score: match.player1GamesWon,
                    player2Score: match.player2GamesWon,
                    winner: winner
                )
            } else {
                ResultScoreRow(
                    player1Name: game.player1Name,
                    player2Name: game.player2Name,
                    player1Score: game.player1Score,
                    player2Score: game.player2Score,
                    winner: winner
                )
            }

            if let winner {
                ResultWinnerLine(
                    text: "\(game.name(for: winner)) wint\(match.isMatchOver ? " de wedstrijd" : " game \(match.currentGameNumber)")",
                    color: RefereeView.color(for: winner)
                )
            }

            VStack(spacing: 10) {
                if gameResults.count > 1 || match.isMatchOver || match.firstGameNumber > 1 {
                    GameResultChips(games: gameResults, untracked: match.firstGameNumber - 1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text(match.isMatchOver ? "Wedstrijd automatisch opgeslagen" : "Game automatisch opgeslagen")
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    secondaryButton("Analyse", icon: "chart.bar.xaxis") { onAnalysis() }
                    secondaryButton("Deel score", icon: "square.and.arrow.up") {
                        shareItems = ShareItemsWrapper(items: [match.whatsAppText])
                    }
                }

                if match.isMatchOver {
                    HardwareButton(title: "Nieuwe wedstrijd", color: AppColors.warmOrange) { onNewMatch() }
                } else {
                    HardwareButton(title: "Volgende game", color: AppColors.warmOrange) { onNextGame() }
                }

                if let undo = onUndo {
                    OverlayUndoButton(action: undo)
                }

                if !match.isMatchOver, let stop = onStop {
                    Button(action: stop) {
                        Text("Stop wedstrijd")
                            .font(AppFonts.caption(13))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .sheet(item: $shareItems) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    /// Outlined gold button with an icon, two of them share the row above the primary action
    private func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        let color = AppColors.accentGold
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title.uppercased())
                    .font(AppFonts.label(13))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Fist icon (stroke)

/// The ✊ emoji tinted in the player's colour: desaturated first so the knuckle
/// shading survives, then multiplied with the colour.
struct FistIcon: View {
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Text("✊")
            .font(.system(size: size * 0.92))
            .grayscale(1)
            .brightness(0.12)
            .colorMultiply(color)
            .frame(width: size, height: size)
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
                PointTypeButton(
                    pointType: .stroke,
                    color: playerColor,
                    action: { onPointTypeSelected(.stroke) }
                )
                // Only the server can score straight from the serve
                if game.selectedPlayer == game.currentServer {
                    PointTypeButton(
                        pointType: .servicePoint,
                        color: playerColor,
                        action: { onPointTypeSelected(.servicePoint) }
                    )
                }
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
    var compact: Bool = false
    let action: () -> Void

    /// The referee's stroke signal is a closed fist; SF Symbols has none, so the ✊ emoji is tinted
    @ViewBuilder
    private var icon: some View {
        if pointType == .stroke {
            FistIcon(color: color, size: 22)
        } else {
            Image(systemName: pointType.icon)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pointType.title.uppercased())
                        .font(AppFonts.label(13))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(0.5)
                    Text(pointType.description)
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, compact ? 9 : 14)
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
