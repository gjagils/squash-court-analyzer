import SwiftUI
import SquashAnalyzerCore

/// Shared scoreboard: same layout as iOS's own `ScoreboardView`, but with
/// `PlayerAvatarPlaceholder` instead of the SwiftData-backed `PlayerAvatar`
/// (no player photos yet on Android — same scope cut as phase 5's Spelers).
public struct SharedScoreboardView: View {
    let game: Game
    let match: Match?
    var onSelectPlayer: ((Player) -> Void)? = nil
    var onServiceChanged: () -> Void

    public init(game: Game, match: Match? = nil, onServiceChanged: @escaping () -> Void = {}, onSelectPlayer: ((Player) -> Void)? = nil) {
        self.game = game
        self.match = match
        self.onSelectPlayer = onSelectPlayer
        self.onServiceChanged = onServiceChanged
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            playerScore(.player1)
            gameColumn
            playerScore(.player2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private var gameColumn: some View {
        VStack(spacing: 3) {
            Text("GAME \(match?.currentGameNumber ?? 1)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textMuted)
                .tracking(2)
            Text("\(match?.player1GamesWon ?? 0) – \(match?.player2GamesWon ?? 0)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(CoachPalette.textPrimary)
            Text("GAMES")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textMuted)
                .tracking(1.5)
        }
        .frame(width: 84)
        .padding(.top, 6)
    }

    // The score button must not contain the separate service-side buttons.
    // Nested buttons merge competing click actions in Android semantics.
    private func playerScore(_ player: Player) -> some View {
        playerColumn(player)
    }

    private func playerColumn(_ player: Player) -> some View {
        let color = player == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
        let score = player == .player1 ? game.player1Score : game.player2Score
        let isServing = game.currentServer == player
        let isScoring = game.selectedPlayer == player

        return VStack(spacing: 4) {
            PlayerAvatarPlaceholder(color: color, size: 34, active: isServing)

            Text(game.name(for: player))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isServing ? color : CoachPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ServiceSideSelector(
                side: game.serverSide,
                preferredSide: game.preferredSide(for: player),
                color: color,
                compact: true,
                disabled: game.isGameOver
            ) { side in
                withAnimation(.easeInOut(duration: 0.15)) { game.overrideSide(to: side) }
                onServiceChanged()
            }
            .opacity(isServing ? 1.0 : 0.0)
            .allowsHitTesting(isServing)

            Button(action: { onSelectPlayer?(player) }) {
                Text("\(score)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(isServing ? color : CoachPalette.textPrimary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(game.isGameOver)
            .accessibilityLabel("Punt voor \(game.name(for: player))")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isScoring ? color.opacity(0.18) : (isServing ? color.opacity(0.06) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(isScoring ? 0.7 : 0.0), lineWidth: 1))
        )
    }
}

enum CoachPalette {
    static let warmOrange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let steelBlue = Color(red: 0.35, green: 0.45, blue: 0.55)
    static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let textSecondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let textMuted = Color(red: 0.50, green: 0.48, blue: 0.45)
    static let backgroundDark = Color(red: 0.06, green: 0.05, blue: 0.04)
    static let backgroundMedium = Color(red: 0.12, green: 0.10, blue: 0.08)
}

/// Coach mode's scoring screen, shared between iOS and Android. Reproduces
/// the app's "score-tap" flow (the default input mode — see
/// SquashAnalyzer/Views/ContentView.swift's `scoreTapStage`): tap a player's
/// score to start a point, then point type → zone (`CourtView`) → shot, one
/// step at a time in the middle of the screen.
///
/// Deliberately smaller than iOS's ContentView: no quick-entry mode, let
/// calls, coaching notes, badges, previous-game analysis, or share sheet —
/// this proves the core scoring loop works end to end on Android (state
/// machine + all three risky shared views + persistence), matching the scope
/// cut already made for phase 5's Spelers (no photos/badges/team-import).
public struct CoachScoringView: View {
    @State private var match: Match
    let aiCoach: AICoachContext?
    let shareText: ((String) -> Void)?
    let onMatchChanged: (Match) -> Void
    let onExit: () -> Void
    /// The finished game shown in the analysis sheet
    @State private var analysedGame: Game?
    @State private var showingAnalysis = false
    @State private var showingShare = false

    public init(match: Match, aiCoach: AICoachContext? = nil, shareText: ((String) -> Void)? = nil,
                onMatchChanged: @escaping (Match) -> Void, onExit: @escaping () -> Void) {
        _match = State(initialValue: match)
        self.aiCoach = aiCoach
        self.shareText = shareText
        self.onMatchChanged = onMatchChanged
        self.onExit = onExit
    }

    private var game: Game { match.currentGame }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [CoachPalette.backgroundMedium, CoachPalette.backgroundDark],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                SharedScoreboardView(game: game, match: match, onServiceChanged: { onMatchChanged(match) }) { player in handleScoreTap(player) }
                    .padding(.horizontal, 20)

                instructionText
                    .padding(.horizontal, 24)
                    .frame(height: 28)

                if match.isMatchOver {
                    matchOverBanner
                } else if game.isGameOver {
                    gameOverBanner
                } else {
                    scoreTapStage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                bottomActions
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("COACH")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.textPrimary)
                .tracking(2)
            HStack {
                Button(action: onExit) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Bewaar & sluit")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(CoachPalette.textSecondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Instruction text

    private var instructionText: some View {
        Group {
            if match.isMatchOver || game.isGameOver {
                EmptyView()
            } else {
                switch game.scoringStep {
                case .selectPlayer:
                    Text("Tik op de score van wie scoort")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(CoachPalette.textSecondary)
                case .selectPointType:
                    Text("Hoe werd het punt gewonnen?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                case .selectZone:
                    Text("Tik op de baan waar het punt viel")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                case .selectShot:
                    Text("Kies het type slag")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                }
            }
        }
    }

    private var playerColor: Color {
        game.selectedPlayer == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
    }

    // MARK: - Score-tap flow (staged middle area, mirrors ContentView.scoreTapStage)

    @ViewBuilder
    private var scoreTapStage: some View {
        switch game.scoringStep {
        case .selectPlayer:
            Color.clear
        case .selectPointType:
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(PointType.allCases) { type in
                    if !type.serverOnly || game.selectedPlayer == game.currentServer {
                        PointTypeButton(pointType: type, color: playerColor, compact: true) {
                            selectPointType(type)
                        }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        case .selectZone:
            VStack(spacing: 10) {
                CourtView(isInteractive: true, selectedPlayer: game.selectedPlayer) { zone in
                    handleZoneTap(zone)
                }
                .padding(.horizontal, 16)
                cancelButton
            }
        case .selectShot:
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                if let zone = game.selectedZone {
                    Text(zone.rawValue.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                        .tracking(1.5)
                }
                HStack(spacing: 12) {
                    ForEach([ShotType.drive, .cross, .volley]) { shot in
                        ShotTypeButton(shotType: shot, color: playerColor) { handleShotTypeSelect(shot) }
                    }
                }
                HStack(spacing: 12) {
                    ForEach([ShotType.drop, .lob, .boast]) { shot in
                        ShotTypeButton(shotType: shot, color: playerColor) { handleShotTypeSelect(shot) }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }

    private var cancelButton: some View {
        Button(action: { game.clearSelection() }) {
            Text("Annuleer")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textMuted)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Game / match over

    private var gameOverBanner: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            if let winner = game.winner {
                Text("\(game.name(for: winner)) WINT DE GAME")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.textPrimary)
                Text("\(game.player1Score) – \(game.player2Score)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(CoachPalette.textPrimary)
            }
            analysisButton
            Button(action: {
                match.onGameEnd()
                onMatchChanged(match)
            }) {
                Text("VOLGENDE GAME")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.backgroundDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(CoachPalette.textPrimary))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }

    private var matchOverBanner: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            if let winner = match.matchWinner {
                Text("\(match.name(for: winner)) WINT DE WEDSTRIJD")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.textPrimary)
                    .multilineTextAlignment(.center)
                Text("\(match.player1GamesWon) – \(match.player2GamesWon)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(CoachPalette.textPrimary)
            }
            SharedMatchBadgesStrip(earnings: SharedMatchBadgesStrip.earnings(
                player1Id: match.player1Id, player1Name: match.player1Name,
                player2Id: match.player2Id, player2Name: match.player2Name,
                badgeInput: match.badgeInput
            ))
            HStack(spacing: 10) {
                analysisButton
                if let shareText {
                    outlineButton("DEEL SCORE") { showingShare = true }
                        .sheet(isPresented: $showingShare) {
                            SharedMatchShareView(report: match.shareReport, shareText: shareText) { showingShare = false }
                        }
                }
            }
            Button(action: onExit) {
                Text("KLAAR")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.backgroundDark)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(CoachPalette.textPrimary))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }

    /// Opens the game analysis (stats, advice, AI Coach) for the game just finished
    private var analysisButton: some View {
        outlineButton("ANALYSE") {
            analysedGame = game
            showingAnalysis = true
        }
        .sheet(isPresented: $showingAnalysis) {
            SharedCoachDashboardView(match: match, game: analysedGame ?? game, aiCoach: aiCoach, shareText: shareText) {
                showingAnalysis = false
            }
        }
    }

    private func outlineButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().stroke(CoachPalette.textPrimary.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack(spacing: 8) {
            coachActionButton("UNDO", icon: "arrow.uturn.backward",
                              disabled: game.selectedZone != nil || !game.canUndo || match.isMatchOver) {
                game.undoLastPoint()
                onMatchChanged(match)
            }
        }
    }

    private func coachActionButton(_ title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AppSymbol(icon, size: 13, color: disabled ? CoachPalette.textMuted : CoachPalette.textPrimary)
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1)
            }
            .foregroundColor(disabled ? CoachPalette.textMuted : CoachPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(CoachPalette.textPrimary.opacity(disabled ? 0.04 : 0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(CoachPalette.textPrimary.opacity(disabled ? 0.08 : 0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Handlers (mirror ContentView.swift's coach handlers)

    private func handleScoreTap(_ player: Player) {
        guard !game.isGameOver else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if game.selectedPlayer == player {
                game.clearSelection()
            } else {
                game.zoneForUnforcedErrors = true
                game.selectPlayer(player)
            }
        }
    }

    private func selectPointType(_ pointType: PointType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            game.selectPointType(pointType)
        }
        if game.scoringStep == .selectPlayer {
            onMatchChanged(match)
        }
    }

    private func handleZoneTap(_ zone: CourtZone) {
        guard game.selectedPlayer != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            game.selectZone(zone)
        }
        if game.scoringStep == .selectPlayer {
            onMatchChanged(match)
        }
    }

    private func handleShotTypeSelect(_ shotType: ShotType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            game.addPoint(shotType: shotType)
        }
        onMatchChanged(match)
    }
}
