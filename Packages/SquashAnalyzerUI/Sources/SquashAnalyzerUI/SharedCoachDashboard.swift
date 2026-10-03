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
    /// Read once when the screen opens: the Keychain/Keystore is not free (T18)
    @State private var hasKey = false
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
            SharedColors.background.ignoresSafeArea()
                .onAppear { hasKey = aiCoach?.keyStore.hasOpenAIKey == true }
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
                    volleys
                    localAdvice
                    // Only with an OpenAI key (Instellingen); without one the local advice is it
                    if hasKey {
                        aiCard
                    }
                    // As on iOS; Skip's sheet is not full height, so keep it clear of the system bar
                    Button(action: onClose) {
                        Text("SLUITEN")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(SharedColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(SharedColors.textSecondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.textSecondary.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
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
                            .foregroundColor(SharedColors.gold)
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
                AppSymbol("xmark", size: 16, color: SharedColors.textSecondary, weight: .medium)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sluiten")
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text("Coach dashboard")
                .font(PageTitleStyle.font)
                .foregroundColor(SharedColors.textPrimary)
            if let winner = game.winner {
                Text("\(game.name(for: winner)) wint!")
                    .font(.system(size: 14))
                    .foregroundColor(SharedColors.gold)
            }
        }
    }

    private func color(for side: Player) -> Color {
        side == Player.player1 ? SharedColors.accent : SharedColors.steelBlueLight
    }

    private var playerPicker: some View {
        HStack(spacing: 8) {
            playerButton(Player.player1, score: game.player1Score)
            Text("-")
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundColor(SharedColors.textMuted)
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
                    .foregroundColor(selected ? color(for: side) : SharedColors.textSecondary)
                Text("\(score)")
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(selected ? color(for: side) : SharedColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? color(for: side).opacity(0.15) : SharedColors.cardTint))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? color(for: side).opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Analyse voor \(game.name(for: side))")
    }

    private var gamePicker: some View {
        // A fixed row, as on iOS
        HStack(spacing: 8) {
                ForEach(0..<games.count, id: \.self) { index in
                    let candidate = games[index]
                    Button { chooseGame(index) } label: {
                        Text("Game \(gameNumber(of: candidate)) (\(candidate.player1Score)-\(candidate.player2Score))")
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(index == gameIndex ? SharedColors.textPrimary : SharedColors.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(index == gameIndex ? SharedColors.gold.opacity(0.3) : SharedColors.cardTint))
                    }
                    .buttonStyle(.plain)
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
            stat("Gewonnen", won.map { seconds in CoachAdvice.formatDuration(seconds) } ?? "-", SharedColors.positive, icon: "timer")
            stat("Verloren", lost.map { seconds in CoachAdvice.formatDuration(seconds) } ?? "-", SharedColors.warmRed, icon: "timer")
            stat("Beste zone", game.bestZone(for: player)?.rawValue ?? "-", SharedColors.gold, icon: "mappin")
            stat("Beste slag", game.bestShotType(for: player)?.rawValue ?? "-", SharedColors.accent, icon: "star.fill",
                 shot: game.bestShotType(for: player))
        }
    }

    /// With an icon on top, as iOS' QuickStatBadge
    private func stat(_ label: String, _ value: String, _ tint: Color, icon: String, shot: ShotType? = nil) -> some View {
        VStack(spacing: 4) {
            if let shot {
                ShotIconView(type: shot, color: tint, size: 14)
                    .frame(height: 14)
            } else {
                AppSymbol(icon, size: 12, color: tint)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(SharedColors.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(SharedColors.cardTint))
    }

    /// 2×3 or 3×3, whichever the game was played with (`Game.heatmapLayout`)
    private var heatmap: some View {
        let rows = game.heatmapLayout.rows
        var most = 1
        for zone in CourtZone.allCases {
            most = max(most, game.pointsWon(by: player, in: zone))
        }
        let highest = most
        return VStack(spacing: 6) {
            Text("Heatmap")
                .font(.system(size: 10))
                .foregroundColor(SharedColors.textMuted)
            VStack(spacing: 2) {
                ForEach(0..<rows.count, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<rows[row].count, id: \.self) { column in
                            let count = game.pointsWon(by: player, in: rows[row][column])
                            ZStack {
                                Rectangle().fill(SharedColors.positive.opacity(0.2 + Double(count) / Double(highest) * 0.6))
                                Text("\(count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(SharedColors.textPrimary)
                            }
                            .frame(width: rows[row].count == 2 ? CGFloat(43) : CGFloat(28), height: 28)
                        }
                    }
                }
            }
            // Sand court underneath, as on iOS
            .padding(6)
            .background(SharedColors.courtSand.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.cardTint))
    }

    private var shots: some View {
        let top = CoachAdvice.topShots(in: game, for: player)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Slagen")
                .font(.system(size: 10))
                .foregroundColor(SharedColors.textMuted)
                .frame(maxWidth: .infinity)
            if top.isEmpty {
                Text("Nog geen slagen")
                    .font(.system(size: 10))
                    .foregroundColor(SharedColors.textMuted)
            }
            ForEach(0..<top.count, id: \.self) { index in
                shotRow(top[index], most: mostShots(top))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.cardTint))
    }

    private func mostShots(_ top: [ShotCount]) -> Int {
        var most = 1
        for item in top { most = max(most, item.count) }
        return most
    }

    /// Icon, name, a small bar and the count, as on iOS
    private func shotRow(_ item: ShotCount, most: Int) -> some View {
        HStack(spacing: 6) {
            ShotIconView(type: item.shot, color: SharedColors.gold, size: 14)
                .frame(width: 14, height: 14)
            Text(item.name)
                .font(.system(size: 10))
                .foregroundColor(SharedColors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 2)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SharedColors.gold.opacity(0.6))
                    .frame(width: max(CGFloat(4), CGFloat(40) * CGFloat(item.count) / CGFloat(most)), height: 8)
                Spacer(minLength: 0)
            }
            .frame(width: 40, height: 8)
            Text("\(item.count)")
                .font(.system(size: 10))
                .foregroundColor(SharedColors.textPrimary)
                .frame(width: 16, alignment: .trailing)
        }
    }

    private var pointTypes: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Puntverdeling", icon: "chart.pie.fill")
            HStack(spacing: 8) {
                countBadge("Winners", game.winners(by: player).count, SharedColors.positive)
                countBadge("Druk", game.forcedErrors(by: player).count, SharedColors.gold)
                countBadge("Service", game.servicePoints(by: player).count, SharedColors.accent)
            }
            HStack(spacing: 8) {
                countBadge("Cadeautjes", game.unforcedErrors(by: player).count, SharedColors.steelBlueLight)
                countBadge("Eigen fouten", game.unforcedErrors(by: player.opponent).count, SharedColors.warmRed)
                countBadge("Strokes", game.strokes(by: player).count, SharedColors.warmRed)
            }
            // How the own unforced errors went: "Down 2 · Out 1"
            if let kinds = ErrorKind.summary(game.errorKindCounts(madeBy: player)) {
                Text("Eigen fouten: \(kinds)")
                    .font(.system(size: 11))
                    .foregroundColor(SharedColors.textSecondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.cardTint))
    }

    /// Points won out of the air, with the shots: "3 drop, 1 kill"
    private var volleys: some View {
        let count = game.volleysWon(by: player).count
        return HStack(spacing: 12) {
            AppSymbol("bolt.fill", size: 18, color: SharedColors.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Uit de lucht")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SharedColors.textPrimary)
                Text(CoachAdvice.volleyBreakdown(in: game, for: player) ?? "Nog geen volleys")
                    .font(.system(size: 11))
                    .foregroundColor(SharedColors.textSecondary)
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(count > 0 ? SharedColors.gold : SharedColors.textMuted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.cardTint))
    }

    private func countBadge(_ label: String, _ count: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(SharedColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.10)))
    }

    /// Gold icon and the title, as on iOS
    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            AppSymbol(icon, size: 15, color: SharedColors.gold)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
        }
    }

    // MARK: Advice

    private var localAdvice: some View {
        // With the match, so findings that also showed in an earlier game are named
        let items = CoachAdvice.local(in: game, for: player, match: match)
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Tactisch Advies", icon: "lightbulb.fill")
            ZoneProfileTable(profile: ZoneProfile.of(game, for: player))
                .padding(.bottom, 4)
            if items.isEmpty {
                Text("Nog te weinig punten voor advies.")
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.textMuted)
            }
            ForEach(0..<items.count, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    // A topic icon in the tone colour, as iOS' AdviceRow
                    AppSymbol(Self.icon(for: items[index].topic), size: 12, color: toneColor(items[index].tone))
                        .frame(width: 16)
                        .padding(.top, 2)
                    Text(items[index].text)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.cardTint))
    }

    /// The same symbol per advice topic as iOS (CoachDashboardView.icon(for:))
    static func icon(for topic: AdviceTopic) -> String {
        switch topic {
        case .speedUp: return "hare.fill"
        case .slowDown: return "tortoise.fill"
        case .ownErrors, .hurry: return "brain.head.profile"
        case .forcedErrors: return "hand.raised.fill"
        case .letsAgainst: return "figure.walk"
        case .opponentErrors: return "arrow.up.circle"
        case .opponentServicePoints: return "exclamationmark.circle"
        case .ownServicePoints: return "bolt.fill"
        case .letsFor: return "figure.run"
        case .avoidZone: return "exclamationmark.triangle"
        case .bestShot: return "star"
        case .wonArea: return "target"
        case .lostArea: return "arrow.down.right.circle"
        case .errorArea: return "xmark.circle"
        case .opening: return "scope"
        case .volleys, .opponentVolleys: return "bolt.circle"
        }
    }

    private func toneColor(_ tone: AdviceTone) -> Color {
        switch tone {
        case .success: return SharedColors.positive
        case .warning: return SharedColors.accent
        case .info: return SharedColors.steelBlueLight
        }
    }

    // MARK: AI Coach


    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("AI Coach", icon: "brain")
                Spacer()
                if !hasKey {
                    Text("API key vereist")
                        .font(.system(size: 10))
                        .foregroundColor(SharedColors.textMuted)
                }
            }
            if let advice {
                aiAdviceView(advice)
            } else if let aiError {
                Text(aiError)
                    .font(.system(size: 12))
                    .foregroundColor(SharedColors.accent)
                Button("Opnieuw proberen") { requestAdvice() }
                    .foregroundColor(SharedColors.steelBlueLight)
            } else if loadingAI {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("AI analyseert de game…")
                        .font(.system(size: 13))
                        .foregroundColor(SharedColors.textSecondary)
                }
            } else {
                Button { requestAdvice() } label: {
                    Text(hasKey ? "Vraag AI Coach om advies" : "Stel je API key in bij Instellingen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hasKey ? SharedColors.steelBlueLight : SharedColors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(hasKey ? SharedColors.steelBlueLight.opacity(0.2) : SharedColors.cardTint))
                }
                .buttonStyle(.plain)
                .disabled(!hasKey)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedColors.cardTint))
    }

    private func aiAdviceView(_ advice: TacticalAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(advice.samenvatting)
                .font(.system(size: 13))
                .foregroundColor(SharedColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            bulletList("Sterke punten:", advice.sterktePunten, SharedColors.positive)
            bulletList("Werkpunten:", advice.werkPunten, SharedColors.accent)
            Text(advice.focusVolgendeGame)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(SharedColors.gold.opacity(0.15)))
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
                        .foregroundColor(SharedColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func requestAdvice() {
        guard let aiCoach, let key = aiCoach.keyStore.openAIAPIKey, !key.isEmpty else { return }
        let asked = player
        let askedGame = gameIndex
        // Built here, so only the texts (not the Game) go into the task
        let request = AICoachClient.prompt(game: game, player: asked, coachingFocus: match.coachingFocus(for: asked))
        let client = aiCoach.client
        loadingAI = true
        aiError = nil
        Task {
            do {
                let result = try await client.send(request, apiKey: key)
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
