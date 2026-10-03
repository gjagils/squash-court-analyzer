import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

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
    @State private var persistenceErrorMessage: String?
    @State private var showingPersistenceError = false
    @State private var showingStartupPersistenceWarning = false
    /// A player card link that was opened and waits for the import sheet (shared with Android)
    @State private var cardInbox = CardInbox()
    /// 6 or 9 zones, a setting (Instellingen)
    @AppStorage(CourtLayout.storageKey) private var courtLayout = CourtLayout.six.rawValue
    /// "Uit de lucht" for the point being entered; off again after every point
    @State private var volley = false
    /// Down / Out / Service / Grond for an unforced error; cleared after every point
    @State private var errorKind: ErrorKind? = nil
    /// The live link to share (WhatsApp), see LiveShareButton
    @State private var liveShareItems: ShareItemsWrapper? = nil

    private var currentGame: Game {
        match.currentGame
    }

    var body: some View {
        ZStack {
            // Main game view
            gameView

            // Home overlay
            if showingSetup {
                // History and saved analyses are layered above home, so closing them lands back here
                HomeView(match: match, isPresented: $showingSetup, onViewHistory: {
                    showingHistory = true
                }, onOpenSettings: {
                    showingSettings = true
                }, onResumeCoach: { unfinished in
                    match = unfinished
                    showingSetup = false
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
            TeamImportService.addSamplePlayersIfNew(context: modelContext)
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
            if phase == .background {
                AutomaticBackup.runIfDue(context: modelContext)
            }
        }
        // A player card link (website or squashanalyzer://kaart#…)
        .onOpenURL { url in
            cardInbox.receive(url.absoluteString)
        }
        .onChange(of: cardInbox.pending) { _, snapshot in
            if let snapshot {
                CardImportPresenter.present(snapshot, container: modelContext.container) { cardInbox.pending = nil }
            }
        }
        .alert(Match.stopTitle, isPresented: $showingCancelConfirm) {
            // Stays in progress; the Coach tile offers it again (as on Android)
            Button("Bewaar en ga later verder") {
                persistMatch()
                match = Match()
                showingSetup = true
            }
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
            Text(match.stopMessage)
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
        .sheet(item: $liveShareItems) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    #if DEBUG
    // MARK: - App Store screenshots (see scripts/screenshots.sh)
    private func applyScreenshotScenario(_ scenario: ScreenshotScenario) {
        switch scenario {
        case .setup, .referee:
            break   // handled by HomeView / MatchStartView
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
        case .badges:
            match = ScreenshotScenario.makeCoachBadgesMatch(context: modelContext)
            showingSetup = false
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
        // Live viewers get the new state; the final one deletes the session
        LiveShareSync.send(matchId: match.id, snapshot: match.liveSnapshot())
    }

    /// The match ends without a final score: stop live sharing
    private func stopLive() {
        guard LiveShare.shared.isLive(match.id) else { return }
        Task { await LiveShare.shared.stop() }
    }

    private func finishOrAbandonCurrentMatch() {
        if match.isMatchOver {
            match.status = .completed
            persistMatch()
        } else {
            abandonCurrentMatch()
        }
    }

    /// Stop (Core's Match.stopAction, the same on Android): a finished match is
    /// saved, one without any recorded rally discarded, anything else asks.
    private func requestStop() {
        switch match.stopAction {
        case .finish:
            finishOrAbandonCurrentMatch()
        case .discard:
            discardCurrentMatch()
        case .ask:
            showingCancelConfirm = true
            return
        }
        match = Match()
        showingSetup = true
    }

    private func discardCurrentMatch() {
        guard !showingSetup else { return }
        stopLive()
        do {
            try SwiftDataMatchRepository(context: modelContext).delete(match)
        } catch {
            persistenceErrorMessage = error.localizedDescription
            showingPersistenceError = true
        }
    }

    private func abandonCurrentMatch() {
        guard !showingSetup else { return }
        stopLive()
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
                               onSelectPlayer: { player in handleScoreTap(player) })
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

                // Score-tap flow: the middle of the screen shows only the current step
                scoreTapStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Let / Undo row + last point
                bottomActions
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
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

                if !match.isMatchOver {
                    LiveShareButton(matchId: match.id, snapshot: { match.liveSnapshot() }) { text in
                        liveShareItems = ShareItemsWrapper(items: [text])
                    }
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
                Text(currentGame.isStarted ? "Tik op de score van wie scoort" : "Tik START bij de eerste service")
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

            // Last point indicator
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

    // MARK: - Score-tap flow (staged middle area)

    /// Empty until a score is tapped, then one step at a time: point types with
    /// icons → the court for the zone → the shots with icons → empty again.
    @ViewBuilder
    private var scoreTapStage: some View {
        let color: Color = currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        switch currentGame.scoringStep {
        case .selectPlayer:
            VStack {
                Spacer(minLength: 0)
                if !currentGame.isStarted && !currentGame.isGameOver && !match.isMatchOver {
                    startButton
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .transition(.opacity)
        case .selectPointType:
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(PointType.allCases) { type in
                    if !type.serverOnly || currentGame.selectedPlayer == currentGame.currentServer {
                        if type == .unforcedError {
                            // How it went wrong; the court is not asked for an unforced error
                            ErrorKindToggle(selection: $errorKind,
                                            available: currentGame.errorKindOptions(whenScoring: currentGame.selectedPlayer ?? .player1),
                                            color: color)
                                .padding(.top, 4)
                        }
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
                CourtView(isInteractive: currentGame.scoringStep == .selectZone, selectedPlayer: currentGame.selectedPlayer,
                          layout: CourtLayout.from(stored: courtLayout)) { zone in
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
                VolleyToggle(isOn: $volley, color: color)
                // The shots that fit the zone's row: 3 in a row, or 4 as 2×2
                ForEach(Array(ShotType.rows(ShotType.options(for: currentGame.selectedZone)).enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 12) {
                        ForEach(row) { shot in
                            ShotTypeButton(shotType: shot, color: color) { handleShotTypeSelect(shot) }
                        }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .transition(.opacity)
        }
    }

    /// START at the first serve of a game: from then the rally clock runs, so
    /// the warm-up and the break between games never count as a rally
    private var startButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentGame.start()
            }
            startRallyTimer()
            LiveShareSync.send(matchId: match.id, snapshot: match.liveSnapshot())
        }) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("START GAME \(match.currentGameNumber)")
                    .font(AppFonts.label(15))
                    .tracking(1)
            }
            .foregroundColor(Color.black.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accentGold)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start game \(match.currentGameNumber)")
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
                currentGame.selectPlayer(player)
            }
            errorKind = nil
        }
    }

    private func handleInlinePointType(_ pointType: PointType) {
        let kind = pointType == .unforcedError ? errorKind : nil
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.selectPointType(pointType, errorKind: kind)
        }
        errorKind = nil
    }

    private func cancelInlinePoint() {
        volley = false
        errorKind = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.clearSelection()
        }
    }

    /// "Niels: Winner · Volley drop · Voor Links" (the summary is shared with Android)
    private func lastPointText(_ point: Point) -> String {
        "\(currentGame.name(for: point.scorer)): " + point.summary
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
    private func handleZoneTap(_ zone: CourtZone) {
        guard currentGame.selectedPlayer != nil else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.selectZone(zone)
        }
    }

    private func handleShotTypeSelect(_ shotType: ShotType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentGame.addPoint(shotType: shotType, isVolley: volley)
        }
        volley = false
    }

    // MARK: - Rally Timer
    private func startRallyTimer() {
        stopRallyTimer()
        rallyElapsedTime = currentGame.rallySeconds()
        rallyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            rallyElapsedTime = currentGame.rallySeconds()
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

// MARK: - Game Over Overlay
struct GameOverOverlay: View {
    let game: Game
    let match: Match
    let onAnalysis: () -> Void
    let onNextGame: () -> Void
    let onNewMatch: () -> Void
    var onStop: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil

    @Query private var players: [SavedPlayer]
    @State private var showingShareSheet = false
    @State private var showingBadges = false

    private var badgeEarnings: [MatchBadgeEarning] {
        guard match.isMatchOver else { return [] }
        return BadgeEngine().earnings(for: match.badgeInput, playerIds: match.playerIds,
                                      names: [.player1: match.player1Name, .player2: match.player2Name])
    }

    var body: some View {
        // The card is shared with Android (SquashAnalyzerUI's MatchResultOverlay)
        MatchResultOverlay(
            result: .coach(match, game: game),
            player1Photo: players.photo(named: match.player1Name),
            player2Photo: players.photo(named: match.player2Name),
            badgeEarnings: badgeEarnings,
            onBadges: { showingBadges = true },
            secondary: [
                ResultButton("Analyse", icon: "chart.bar.xaxis") { onAnalysis() },
                ResultButton("Deel score", icon: "square.and.arrow.up") { showingShareSheet = true }
            ],
            primary: match.isMatchOver ? ResultButton("Nieuwe wedstrijd") { onNewMatch() }
                                       : ResultButton("Volgende game") { onNextGame() },
            onUndo: onUndo,
            link: match.isMatchOver ? nil : onStop.map { stop in ResultButton("Stop wedstrijd") { stop() } }
        )
        .sheet(isPresented: $showingShareSheet) {
            MatchShareSheet(report: match.shareReport)
        }
        .sheet(isPresented: $showingBadges) {
            MatchBadgesSheet(earnings: badgeEarnings, matchId: match.id)
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
