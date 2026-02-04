import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var match = Match()
    @State private var showingSetup = true
    @State private var showingAnalysis = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var matchSaved = false
    @State private var showingSavedMatchAnalysis = false
    @State private var savedMatchForAnalysis: Match? = nil
    @State private var savedGameForAnalysis: Game? = nil
    @State private var showingPreviousGameAnalysis = false
    @State private var showingCancelConfirm = false
    @State private var showingLetSelector = false

    private var currentGame: Game {
        match.currentGame
    }

    var body: some View {
        ZStack {
            // Main game view
            gameView

            // Shot type selector overlay
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
                    matchSaved: matchSaved,
                    onAnalysis: { showingAnalysis = true },
                    onNextGame: { match.onGameEnd() },
                    onNewMatch: {
                        match = Match()
                        matchSaved = false
                        showingSetup = true
                    },
                    onSaveMatch: { saveMatch() }
                )
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
        .alert("Wedstrijd stoppen?", isPresented: $showingCancelConfirm) {
            Button("Annuleren", role: .cancel) { }
            Button("Stoppen", role: .destructive) {
                match = Match()
                matchSaved = false
                showingSetup = true
            }
        } message: {
            Text("Weet je zeker dat je deze wedstrijd wilt stoppen? De huidige wedstrijd gaat verloren.")
        }
    }

    // MARK: - Save Match
    private func saveMatch() {
        _ = SavedMatch.from(match, context: modelContext)
        try? modelContext.save()
        matchSaved = true
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

                // Instruction text
                instructionText
                    .padding(.horizontal, 24)

                // Court view
                CourtView(game: currentGame) { zone in
                    handleZoneTap(zone)
                }
                .padding(.horizontal, 16)

                // Player buttons (hidden when selecting shot)
                if currentGame.selectedZone == nil {
                    PlayerButtonsView(game: currentGame) { player in
                        handlePlayerSelect(player)
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Bottom info row
                bottomInfoRow

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
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

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // History button
            Button(action: { showingHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
            }

            // Stop match button
            Button(action: { showingCancelConfirm = true }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.leading, 8)

            // Previous game analysis button
            if match.currentGameIndex > 0 && !currentGame.isGameOver {
                Button(action: { showingPreviousGameAnalysis = true }) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accentGold)
                }
                .padding(.leading, 8)
            }

            Spacer()

            Text("SQUASH ANALYZER")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)
                .tracking(3)

            Spacer()

            // Undo button
            Button(action: {
                withAnimation {
                    currentGame.undoLastPoint()
                }
            }) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 20))
                    .foregroundColor(currentGame.canUndo ? AppColors.textSecondary : AppColors.textMuted)
            }
            .disabled(!currentGame.canUndo)

            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Instruction Text
    private var instructionText: some View {
        Group {
            switch currentGame.scoringStep {
            case .selectPlayer:
                Text("Kies wie scoort")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)
            case .selectZone:
                Text("Tik op de baan waar het punt gescoord werd")
                    .font(AppFonts.body(14))
                    .foregroundColor(currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
            case .selectShot:
                Text("Kies het type slag")
                    .font(AppFonts.body(14))
                    .foregroundColor(currentGame.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
            }
        }
    }

    // MARK: - Bottom Info Row
    private var bottomInfoRow: some View {
        HStack(spacing: 16) {
            // Let button
            if currentGame.selectedZone == nil && !currentGame.isGameOver {
                Button(action: {
                    showingLetSelector = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Let")
                    }
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.accentGold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColors.accentGold.opacity(0.15))
                    )
                }
            }

            // Undo button (when there are points)
            if currentGame.canUndo && currentGame.selectedZone == nil {
                Button(action: {
                    withAnimation {
                        currentGame.undoLastPoint()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Ongedaan")
                    }
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }

            // Last point indicator
            if let lastPoint = currentGame.lastPoint, currentGame.selectedZone == nil {
                HStack(spacing: 6) {
                    Circle()
                        .fill(lastPoint.scorer == .player1 ? AppColors.warmOrange : AppColors.steelBlue)
                        .frame(width: 8, height: 8)
                    Text("\(currentGame.name(for: lastPoint.scorer)): \(lastPoint.zone.shortName) (\(lastPoint.shotType.shortName))")
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
        .frame(height: 36)
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
}

// MARK: - Match Setup View
struct MatchSetupView: View {
    let match: Match
    @Binding var isPresented: Bool
    var onViewHistory: (() -> Void)? = nil

    @State private var player1Name: String = ""
    @State private var player2Name: String = ""
    @State private var startingServer: Player = .player1

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                // Header
                Text("SQUASH ANALYZER")
                    .font(AppFonts.title(22))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(3)
                    .padding(.top, 40)

                Text("Best of 5 games")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Player names input
                VStack(spacing: 20) {
                    PlayerNameInput(
                        title: "Speler 1",
                        name: $player1Name,
                        color: AppColors.warmOrange,
                        placeholder: "Naam speler 1"
                    )

                    PlayerNameInput(
                        title: "Speler 2",
                        name: $player2Name,
                        color: AppColors.steelBlue,
                        placeholder: "Naam speler 2"
                    )
                }
                .padding(.horizontal, 24)

                // Starting server selection
                VStack(spacing: 12) {
                    Text("Wie serveert eerst?")
                        .font(AppFonts.label(14))
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 16) {
                        ServerSelectionButton(
                            name: player1Name.isEmpty ? "Speler 1" : player1Name,
                            color: AppColors.warmOrange,
                            isSelected: startingServer == .player1
                        ) {
                            startingServer = .player1
                        }

                        ServerSelectionButton(
                            name: player2Name.isEmpty ? "Speler 2" : player2Name,
                            color: AppColors.steelBlue,
                            isSelected: startingServer == .player2
                        ) {
                            startingServer = .player2
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Start button
                HardwareButton(
                    title: "Start Wedstrijd",
                    subtitle: nil,
                    color: AppColors.warmOrange,
                    colorDark: AppColors.warmOrangeDark
                ) {
                    startMatch()
                }
                .padding(.horizontal, 24)

                // View saved matches button
                if let onViewHistory = onViewHistory {
                    Button(action: onViewHistory) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16))
                            Text("Opgeslagen wedstrijden")
                                .font(AppFonts.label(14))
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                }

                Spacer().frame(height: 24)
            }
        }
    }

    private func startMatch() {
        match.setupMatch(
            player1: player1Name,
            player2: player2Name,
            startingServer: startingServer
        )
        isPresented = false
    }
}

// MARK: - Player Name Input
struct PlayerNameInput: View {
    let title: String
    @Binding var name: String
    let color: Color
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(AppFonts.caption(11))
                .foregroundColor(color)
                .tracking(1)

            TextField(placeholder, text: $name)
                .font(AppFonts.body(16))
                .foregroundColor(AppColors.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
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
    let matchSaved: Bool
    let onAnalysis: () -> Void
    let onNextGame: () -> Void
    let onNewMatch: () -> Void
    let onSaveMatch: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Title
                Text(match.isMatchOver ? "WEDSTRIJD VOORBIJ" : "GAME OVER")
                    .font(AppFonts.title(26))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(4)

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
                    // Analysis button
                    HardwareButton(
                        title: "Bekijk Analyse",
                        subtitle: nil,
                        color: AppColors.accentGold,
                        colorDark: AppColors.accentGold.opacity(0.7)
                    ) {
                        onAnalysis()
                    }

                    // Save button (only when match is over)
                    if match.isMatchOver {
                        HardwareButton(
                            title: matchSaved ? "Opgeslagen ✓" : "Wedstrijd Opslaan",
                            subtitle: nil,
                            color: matchSaved ? AppColors.textMuted : AppColors.steelBlue,
                            colorDark: matchSaved ? AppColors.textMuted.opacity(0.7) : AppColors.steelBlueDark
                        ) {
                            if !matchSaved {
                                onSaveMatch()
                            }
                        }
                        .disabled(matchSaved)
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
                            color: AppColors.steelBlue,
                            colorDark: AppColors.steelBlueDark
                        ) {
                            onNextGame()
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

// MARK: - Preview

#Preview("Main Game") {
    ContentView()
}
