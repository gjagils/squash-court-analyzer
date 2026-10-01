import SwiftUI
import SquashAnalyzerCore

/// What the dashboard and the settings need for AI Coach: where the key is
/// kept and how requests are sent (both supplied by the platform)
public struct AICoachContext {
    public let keyStore: any APIKeyStore
    public let client: AICoachClient

    public init(keyStore: any APIKeyStore, client: AICoachClient) {
        self.keyStore = keyStore
        self.client = client
    }
}

enum DashboardPalette {
    static let background = Color(red: 0.06, green: 0.05, blue: 0.04)
    static let card = Color.white.opacity(0.05)
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let secondary = Color(red: 0.75, green: 0.73, blue: 0.70)
    static let muted = Color(red: 0.55, green: 0.53, blue: 0.50)
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let blue = Color(red: 0.45, green: 0.60, blue: 0.75)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let green = Color(red: 0.40, green: 0.78, blue: 0.45)
    static let red = Color(red: 0.92, green: 0.38, blue: 0.33)
}

/// Android's coach dashboard after a game: the numbers per player, where
/// points were won, the local advice (Core's `CoachAdvice`, same as iOS) and
/// AI Coach. Smaller than iOS' `CoachDashboardView` (no sharing).
public struct SharedCoachDashboardView: View {
    let match: Match
    let aiCoach: AICoachContext?
    let shareText: ((String) -> Void)?
    let onClose: () -> Void

    @State private var player: Player = Player.player1
    @State private var gameIndex: Int
    @State private var advice: TacticalAdvice?
    @State private var aiError: String?
    @State private var loadingAI = false

    /// Finished games, and the one being looked at when it is still open
    private let games: [Game]

    public init(match: Match, game initial: Game, aiCoach: AICoachContext?, shareText: ((String) -> Void)? = nil,
                onClose: @escaping () -> Void) {
        self.match = match
        self.aiCoach = aiCoach
        self.shareText = shareText
        self.onClose = onClose
        var available: [Game] = []
        for game in match.games where game.isGameOver || game === initial {
            available.append(game)
        }
        games = available
        var index = available.count - 1
        for (position, game) in available.enumerated() where game === initial {
            index = position
        }
        _gameIndex = State(initialValue: max(0, index))
    }

    private var game: Game { games.isEmpty ? match.currentGame : games[min(gameIndex, games.count - 1)] }

    public var body: some View {
        ZStack {
            DashboardPalette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    header
                    playerPicker
                    if games.count > 1 {
                        gamePicker
                    }
                    quickStats
                    HStack(alignment: .top, spacing: 12) {
                        heatmap
                        shots
                    }
                    pointTypes
                    localAdvice
                    aiCard
                        // Skip's sheet is not full height; keep the last card clear of the system bar
                        .padding(.bottom, 48)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: Header and pickers

    /// Close sits top right, like iOS: the bottom of Skip's sheet lies under
    /// the system navigation bar, where a button would be hard to see
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            titleBlock
                .frame(maxWidth: .infinity)
            if let shareText {
                HStack {
                    Button { shareText(GameSummaryText.text(for: game)) } label: {
                        Text("Deel")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DashboardPalette.gold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Deel game-analyse")
                    Spacer()
                }
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DashboardPalette.secondary)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sluiten")
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text("GAME-ANALYSE")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundColor(DashboardPalette.text)
            if let winner = game.winner {
                Text("\(game.name(for: winner)) wint!")
                    .font(.system(size: 14))
                    .foregroundColor(DashboardPalette.gold)
            }
        }
    }

    private func color(for side: Player) -> Color {
        side == Player.player1 ? DashboardPalette.orange : DashboardPalette.blue
    }

    private var playerPicker: some View {
        HStack(spacing: 8) {
            playerButton(Player.player1, score: game.player1Score)
            Text("-")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundColor(DashboardPalette.muted)
            playerButton(Player.player2, score: game.player2Score)
        }
    }

    private func playerButton(_ side: Player, score: Int) -> some View {
        let selected = side == player
        return Button { choose(side) } label: {
            VStack(spacing: 2) {
                Text(game.name(for: side))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(selected ? color(for: side) : DashboardPalette.secondary)
                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(selected ? color(for: side) : DashboardPalette.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? color(for: side).opacity(0.15) : DashboardPalette.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? color(for: side).opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Analyse voor \(game.name(for: side))")
    }

    private var gamePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<games.count, id: \.self) { index in
                    let candidate = games[index]
                    Button { chooseGame(index) } label: {
                        Text("Game \(gameNumber(of: candidate)) (\(candidate.player1Score)-\(candidate.player2Score))")
                            .font(.system(size: 11))
                            .foregroundColor(index == gameIndex ? DashboardPalette.text : DashboardPalette.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(index == gameIndex ? DashboardPalette.gold.opacity(0.3) : DashboardPalette.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func gameNumber(of candidate: Game) -> Int {
        for (index, game) in match.games.enumerated() where game === candidate {
            return match.gameNumber(at: index)
        }
        return 1
    }

    /// Another player or game: the AI answer was about the previous choice.
    /// (Unlabelled on purpose: a `player:` label would become a Kotlin
    /// parameter that shadows the `player` state.)
    private func choose(_ side: Player) {
        player = side
        resetAI()
    }

    private func chooseGame(_ index: Int) {
        gameIndex = index
        resetAI()
    }

    private func resetAI() {
        advice = nil
        aiError = nil
        loadingAI = false
    }

    // MARK: Numbers

    private var quickStats: some View {
        let won = game.averageDurationWon(by: player)
        let lost = game.averageDurationLost(by: player)
        return HStack(spacing: 8) {
            stat("Gewonnen", won.map { seconds in CoachAdvice.formatDuration(seconds) } ?? "-", DashboardPalette.green)
            stat("Verloren", lost.map { seconds in CoachAdvice.formatDuration(seconds) } ?? "-", DashboardPalette.red)
            stat("Beste zone", game.bestZone(for: player)?.rawValue ?? "-", DashboardPalette.gold)
            stat("Beste slag", game.bestShotType(for: player)?.rawValue ?? "-", DashboardPalette.orange)
        }
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DashboardPalette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(DashboardPalette.card))
    }

    private var heatmap: some View {
        var most = 1
        for zone in CourtZone.allCases {
            most = max(most, game.pointsWon(by: player, in: zone))
        }
        let highest = most
        return VStack(spacing: 6) {
            Text("Heatmap")
                .font(.system(size: 10))
                .foregroundColor(DashboardPalette.muted)
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { column in
                            let count = game.pointsWon(by: player, in: CoachAdvice.courtRows[row][column])
                            ZStack {
                                Rectangle().fill(DashboardPalette.green.opacity(0.2 + Double(count) / Double(highest) * 0.6))
                                Text("\(count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(DashboardPalette.text)
                            }
                            .frame(width: 28, height: 28)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(DashboardPalette.card))
    }

    private var shots: some View {
        let top = CoachAdvice.topShots(in: game, for: player)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Slagen")
                .font(.system(size: 10))
                .foregroundColor(DashboardPalette.muted)
                .frame(maxWidth: .infinity)
            if top.isEmpty {
                Text("Nog geen slagen")
                    .font(.system(size: 10))
                    .foregroundColor(DashboardPalette.muted)
            }
            ForEach(0..<top.count, id: \.self) { index in
                HStack {
                    Text(top[index].shot.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(DashboardPalette.secondary)
                    Spacer()
                    Text("\(top[index].count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DashboardPalette.gold)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(DashboardPalette.card))
    }

    private var pointTypes: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Puntverdeling")
            HStack(spacing: 8) {
                countBadge("Winners", game.winners(by: player).count, DashboardPalette.green)
                countBadge("Druk", game.forcedErrors(by: player).count, DashboardPalette.gold)
                countBadge("Service", game.servicePoints(by: player).count, DashboardPalette.orange)
            }
            HStack(spacing: 8) {
                countBadge("Cadeautjes", game.unforcedErrors(by: player).count, DashboardPalette.blue)
                countBadge("Eigen fouten", game.unforcedErrors(by: player.opponent).count, DashboardPalette.red)
                countBadge("Strokes", game.strokes(by: player).count, DashboardPalette.red)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(DashboardPalette.card))
    }

    private func countBadge(_ label: String, _ count: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DashboardPalette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.10)))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(DashboardPalette.gold)
    }

    // MARK: Advice

    private var localAdvice: some View {
        let items = CoachAdvice.local(in: game, for: player)
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Tactisch advies")
            if items.isEmpty {
                Text("Nog te weinig punten voor advies.")
                    .font(.system(size: 12))
                    .foregroundColor(DashboardPalette.muted)
            }
            ForEach(0..<items.count, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(toneColor(items[index].tone))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    Text(items[index].text)
                        .font(.system(size: 13))
                        .foregroundColor(DashboardPalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(DashboardPalette.card))
    }

    private func toneColor(_ tone: AdviceTone) -> Color {
        switch tone {
        case .success: return DashboardPalette.green
        case .warning: return DashboardPalette.orange
        case .info: return DashboardPalette.blue
        }
    }

    // MARK: AI Coach

    private var hasKey: Bool { aiCoach?.keyStore.hasOpenAIKey == true }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("AI Coach")
                Spacer()
                if !hasKey {
                    Text("API key vereist")
                        .font(.system(size: 10))
                        .foregroundColor(DashboardPalette.muted)
                }
            }
            if let advice {
                aiAdviceView(advice)
            } else if let aiError {
                Text(aiError)
                    .font(.system(size: 12))
                    .foregroundColor(DashboardPalette.orange)
                Button("Opnieuw proberen") { requestAdvice() }
                    .foregroundColor(DashboardPalette.blue)
            } else if loadingAI {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("AI analyseert de game…")
                        .font(.system(size: 13))
                        .foregroundColor(DashboardPalette.secondary)
                }
            } else {
                Button { requestAdvice() } label: {
                    Text(hasKey ? "Vraag AI Coach om advies" : "Stel je API key in bij Instellingen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hasKey ? DashboardPalette.blue : DashboardPalette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(hasKey ? DashboardPalette.blue.opacity(0.2) : DashboardPalette.card))
                }
                .buttonStyle(.plain)
                .disabled(!hasKey)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(DashboardPalette.card))
    }

    private func aiAdviceView(_ advice: TacticalAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(advice.samenvatting)
                .font(.system(size: 13))
                .foregroundColor(DashboardPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            bulletList("Sterke punten:", advice.sterktePunten, DashboardPalette.green)
            bulletList("Werkpunten:", advice.werkPunten, DashboardPalette.orange)
            Text(advice.focusVolgendeGame)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DashboardPalette.text)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(DashboardPalette.gold.opacity(0.15)))
        }
    }

    private func bulletList(_ title: String, _ lines: [String], _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !lines.isEmpty {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
                ForEach(0..<lines.count, id: \.self) { index in
                    Text("• \(lines[index])")
                        .font(.system(size: 12))
                        .foregroundColor(DashboardPalette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func requestAdvice() {
        guard let aiCoach, let key = aiCoach.keyStore.openAIAPIKey, !key.isEmpty else { return }
        let asked = player
        let askedGame = gameIndex
        // Built here, so only the request body (not the Game) goes into the task
        guard let body = try? AICoachClient.requestBody(game: game, player: asked, coachingFocus: match.coachingFocus(for: asked)) else { return }
        let client = aiCoach.client
        loadingAI = true
        aiError = nil
        Task {
            do {
                let result = try await client.send(body, apiKey: key)
                // Only show it when the choice did not change meanwhile
                if asked == player && askedGame == gameIndex {
                    advice = result
                }
            } catch {
                if asked == player && askedGame == gameIndex {
                    aiError = (error as? AICoachError)?.message ?? AICoachError.noConnection.message
                }
            }
            loadingAI = false
        }
    }
}
