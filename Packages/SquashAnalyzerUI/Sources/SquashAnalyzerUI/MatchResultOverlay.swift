import SwiftUI
import Foundation
import SquashAnalyzerCore

// MARK: - What the result card shows

/// One finished game as a chip on the result card ("G2 11-8")
public struct ResultGame: Identifiable, Equatable {
    public let number: Int
    public let player1Score: Int
    public let player2Score: Int
    public let winner: Player
    public var id: Int { number }

    public init(number: Int, player1Score: Int, player2Score: Int, winner: Player) {
        self.number = number
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
    }
}

/// A grey line under the chips, optionally with a timer icon
public struct ResultCaptionLine: Identifiable, Equatable {
    public let text: String
    public let showsTimer: Bool
    public var id: String { text }

    public init(_ text: String, showsTimer: Bool = false) {
        self.text = text
        self.showsTimer = showsTimer
    }
}

/// The content of the "GAME 2 KLAAR" / "WEDSTRIJD KLAAR" card, built from a
/// referee or coach match. Shared by iOS and Android so both show the same.
public struct MatchResult: Equatable {
    public let title: String
    public let player1Name: String
    public let player2Name: String
    /// Points (end of a game) or games (end of the match)
    public let player1Score: Int
    public let player2Score: Int
    public let winner: Player?
    public let winnerText: String?
    public let games: [ResultGame]
    /// Games played before scoring started, shown as "G1 –"
    public let untracked: Int
    public let showsChips: Bool
    public let captions: [ResultCaptionLine]
    /// "Wedstrijd automatisch opgeslagen" (coach)
    public let savedNote: String?
    public let isMatchOver: Bool

    public init(title: String, player1Name: String, player2Name: String, player1Score: Int, player2Score: Int,
                winner: Player?, winnerText: String?, games: [ResultGame], untracked: Int, showsChips: Bool,
                captions: [ResultCaptionLine], savedNote: String?, isMatchOver: Bool) {
        self.title = title
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
        self.winnerText = winnerText
        self.games = games
        self.untracked = untracked
        self.showsChips = showsChips
        self.captions = captions
        self.savedNote = savedNote
        self.isMatchOver = isMatchOver
    }

    /// End of a referee game, before "Volgende game"
    public static func refereeGame(_ match: RefereeMatch) -> MatchResult {
        let winner = match.currentGameWinner
        return MatchResult(
            title: "GAME \(match.currentGameNumber) KLAAR",
            player1Name: match.player1Name, player2Name: match.player2Name,
            player1Score: match.player1Score, player2Score: match.player2Score,
            winner: winner,
            winnerText: winner.map { "\(match.name(for: $0)) wint game \(match.currentGameNumber)" },
            games: refereeGames(match), untracked: match.firstGameNumber - 1, showsChips: true,
            captions: [ResultCaptionLine(standText(match)), ResultCaptionLine(gameStatsText(match), showsTimer: true)],
            savedNote: nil, isMatchOver: false
        )
    }

    /// End of a referee match
    public static func refereeMatch(_ match: RefereeMatch) -> MatchResult {
        let winner = match.matchWinner
        return MatchResult(
            title: "WEDSTRIJD KLAAR",
            player1Name: match.player1Name, player2Name: match.player2Name,
            player1Score: match.player1TotalGames, player2Score: match.player2TotalGames,
            winner: winner,
            winnerText: winner.map { "🏆 \(match.name(for: $0)) wint de wedstrijd" },
            games: refereeGames(match), untracked: match.firstGameNumber - 1, showsChips: true,
            captions: [ResultCaptionLine(matchStatsText(match), showsTimer: true)],
            savedNote: nil, isMatchOver: true
        )
    }

    /// End of a coach game (or of the match when it is over)
    public static func coach(_ match: Match, game: Game) -> MatchResult {
        let over = match.isMatchOver
        let winner = over ? match.matchWinner : game.winner
        var games: [ResultGame] = []
        for index in 0..<match.games.count {
            let played = match.games[index]
            if let gameWinner = played.winner {
                games.append(ResultGame(number: match.gameNumber(at: index), player1Score: played.player1Score,
                                        player2Score: played.player2Score, winner: gameWinner))
            }
        }
        return MatchResult(
            title: over ? "WEDSTRIJD KLAAR" : "GAME \(match.currentGameNumber) KLAAR",
            player1Name: match.player1Name, player2Name: match.player2Name,
            player1Score: over ? match.player1GamesWon : game.player1Score,
            player2Score: over ? match.player2GamesWon : game.player2Score,
            winner: winner,
            winnerText: winner.map { "\(match.name(for: $0)) wint" + (over ? " de wedstrijd" : " game \(match.currentGameNumber)") },
            games: games, untracked: match.firstGameNumber - 1,
            showsChips: games.count > 1 || over || match.firstGameNumber > 1,
            captions: [],
            savedNote: over ? "Wedstrijd automatisch opgeslagen" : "Game automatisch opgeslagen",
            isMatchOver: over
        )
    }

    private static func refereeGames(_ match: RefereeMatch) -> [ResultGame] {
        var games: [ResultGame] = []
        for game in match.completedGames {
            games.append(ResultGame(number: game.number, player1Score: game.player1Score, player2Score: game.player2Score, winner: game.winner))
        }
        if let winner = match.currentGameWinner {
            games.append(ResultGame(number: match.currentGameNumber, player1Score: match.player1Score, player2Score: match.player2Score, winner: winner))
        }
        return games
    }

    /// "Gelijk 1 – 1" or "Jan leidt 2 – 1", games won including this one
    static func standText(_ match: RefereeMatch) -> String {
        let p1 = match.player1TotalGames
        let p2 = match.player2TotalGames
        if p1 == p2 { return "Gelijk \(p1) – \(p2)" }
        let leader = p1 > p2 ? Player.player1 : Player.player2
        return "\(match.name(for: leader)) leidt \(max(p1, p2)) – \(min(p1, p2))"
    }

    /// "8:42 · 19 rallies · 1 stroke"
    static func gameStatsText(_ match: RefereeMatch) -> String {
        let secs = Int(match.currentGameDuration)
        let seconds = secs % 60
        var parts = ["\(secs / 60):" + (seconds < 10 ? "0" : "") + "\(seconds)", "\(match.pointHistory.count) rallies"]
        var strokes = 0
        for entry in match.pointHistory where entry.isStroke { strokes += 1 }
        if strokes > 0 { parts.append("\(strokes) stroke" + (strokes == 1 ? "" : "s")) }
        return parts.joined(separator: " · ")
    }

    /// "42 min · 73 rallies · 2 strokes"
    static func matchStatsText(_ match: RefereeMatch) -> String {
        let minutes = max(1, Int((match.matchDuration / 60.0).rounded()))
        var parts = ["\(minutes) min", "\(match.totalRallies) rallies"]
        let strokes = match.totalStrokes
        if strokes > 0 { parts.append("\(strokes) stroke" + (strokes == 1 ? "" : "s")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Buttons

/// A button on the result card
public struct ResultButton {
    public let title: String
    public let icon: String?
    public let action: () -> Void

    public init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

// MARK: - The card

/// Dimmed scrim with the flat referee-style result card: title, the two
/// players with their score, the winner line, game chips, captions, earned
/// badges, then the buttons (an optional row of two gold ones, the main one,
/// an outlined one, "Undo laatste punt" and a small text link).
public struct MatchResultOverlay: View {
    let result: MatchResult
    let player1Photo: Data?
    let player2Photo: Data?
    let badgeEarnings: [MatchBadgeEarning]
    let onBadges: (() -> Void)?
    let secondary: [ResultButton]
    let primary: ResultButton
    let outlined: ResultButton?
    let onUndo: (() -> Void)?
    let link: ResultButton?

    public init(result: MatchResult, player1Photo: Data? = nil, player2Photo: Data? = nil,
                badgeEarnings: [MatchBadgeEarning] = [], onBadges: (() -> Void)? = nil,
                secondary: [ResultButton] = [], primary: ResultButton, outlined: ResultButton? = nil,
                onUndo: (() -> Void)? = nil, link: ResultButton? = nil) {
        self.result = result
        self.player1Photo = player1Photo
        self.player2Photo = player2Photo
        self.badgeEarnings = badgeEarnings
        self.onBadges = onBadges
        self.secondary = secondary
        self.primary = primary
        self.outlined = outlined
        self.onUndo = onUndo
        self.link = link
    }

    static func color(for player: Player) -> Color {
        player == Player.player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            ScrollView {
                card
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 22) {
            Text(result.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.textPrimary)
                .tracking(3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 4) {
                side(Player.player1, name: result.player1Name, score: result.player1Score, photo: player1Photo)
                Text("–")
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.textMuted)
                    .padding(.bottom, 14)
                side(Player.player2, name: result.player2Name, score: result.player2Score, photo: player2Photo)
            }

            if let winner = result.winner, let text = result.winnerText {
                Text(text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Self.color(for: winner))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 10) {
                if result.showsChips {
                    chips
                }
                ForEach(result.captions) { line in
                    caption(line)
                }
                if let note = result.savedNote {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(note)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(CoachPalette.textMuted)
                    }
                }
            }

            if !badgeEarnings.isEmpty {
                MatchBadgesRow(earnings: badgeEarnings) { onBadges?() }
            }

            VStack(spacing: 12) {
                if !secondary.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(0..<secondary.count, id: \.self) { index in
                            goldButton(secondary[index])
                        }
                    }
                }
                filledButton(primary)
                if let outlined {
                    outlinedButton(outlined)
                }
                if let onUndo {
                    undoButton(onUndo)
                }
                if let link {
                    Button(action: link.action) {
                        Text(link.title)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(CoachPalette.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(CoachPalette.backgroundMedium)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(result.winner.map { Self.color(for: $0).opacity(0.35) } ?? Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func side(_ player: Player, name: String, score: Int, photo: Data?) -> some View {
        let color = Self.color(for: player)
        let won = result.winner == nil || result.winner == player
        return VStack(spacing: 6) {
            PlayerAvatarPlaceholder(color: color, size: 44, active: won, photo: photo)
            Text(name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(won ? color : CoachPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(score)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(won ? color : CoachPalette.textPrimary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(0..<result.untracked, id: \.self) { index in
                chip(number: index + 1, score: "–", color: CoachPalette.textMuted)
            }
            ForEach(result.games) { game in
                chip(number: game.number, score: "\(game.player1Score)-\(game.player2Score)", color: Self.color(for: game.winner))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func chip(number: Int, score: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("G\(number)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(color.opacity(0.7))
                .tracking(1)
            Text(score)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 1))
    }

    private func caption(_ line: ResultCaptionLine) -> some View {
        HStack(spacing: 5) {
            if line.showsTimer {
                AppSymbol("timer", size: 11, color: CoachPalette.gold.opacity(0.6))
            }
            Text(line.text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func filledButton(_ button: ResultButton) -> some View {
        Button(action: button.action) {
            Text(button.title.uppercased())
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundColor(CoachPalette.backgroundDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CoachPalette.warmOrange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func outlinedButton(_ button: ResultButton) -> some View {
        let color = CoachPalette.textSecondary
        return Button(action: button.action) {
            Text(button.title.uppercased())
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Outlined gold button with an icon; two of them share a row
    private func goldButton(_ button: ResultButton) -> some View {
        let color = CoachPalette.gold
        return Button(action: button.action) {
            HStack(spacing: 6) {
                if let icon = button.icon {
                    AppSymbol(icon, size: 12, color: color, weight: .semibold)
                }
                Text(button.title.uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// "Undo laatste punt", so a mis-tap on the final point can still be corrected
    private func undoButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AppSymbol("arrow.uturn.backward", size: 12, color: CoachPalette.textSecondary, weight: .semibold)
                Text("Undo laatste punt")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(CoachPalette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Earned badges

/// Outlined gold row listing who earned what in this match; tapping it opens
/// the badges. Only shown when a picked player earned something.
public struct MatchBadgesRow: View {
    let earnings: [MatchBadgeEarning]
    let onTap: () -> Void

    public init(earnings: [MatchBadgeEarning], onTap: @escaping () -> Void) {
        self.earnings = earnings
        self.onTap = onTap
    }

    public var body: some View {
        let color = CoachPalette.gold
        return Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BADGES VERDIEND")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(color)
                    ForEach(earnings) { earning in
                        earningLine(earning)
                    }
                }
                Spacer(minLength: 0)
                AppSymbol("chevron.right", size: 13, color: color, weight: .semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bekijk badges")
    }

    private func earningLine(_ earning: MatchBadgeEarning) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(earning.badges) { kind in
                    BadgeMedallion(kind: kind, size: 26, showsTitle: false)
                }
            }
            Text("\(earning.name) · " + (earning.badges.count == 1 ? earning.badges[0].title : "\(earning.badges.count) badges"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textPrimary)
                .lineLimit(1)
        }
    }
}

/// The badges earned in this match, per player, with what each one means.
/// Android's sheet from the result card (iOS opens its own badge screen).
public struct SharedMatchBadgesSheet: View {
    let earnings: [MatchBadgeEarning]
    let onClose: () -> Void

    public init(earnings: [MatchBadgeEarning], onClose: @escaping () -> Void) {
        self.earnings = earnings
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CoachPalette.backgroundDark.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(earnings) { earning in
                            playerSection(earning)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Badges")
            .toolbar {
                #if os(iOS) && !SKIP
                // iOS: "✕ Sluiten" top left, like every other screen (CloseButton in the app)
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { closeButton }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { closeButton }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { onClose() }
                }
                #endif
            }
        }
    }

    #if os(iOS) && !SKIP
    private var closeButton: some View {
        Button { onClose() } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text("Sluiten")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(CoachPalette.textSecondary)
            .lineLimit(1)
            .fixedSize()
            // Toolbars draw icons a size up; keep the ✕ as small as on Spelers
            .imageScale(.medium)
        }
        .buttonStyle(.plain)
    }
    #endif

    private func playerSection(_ earning: MatchBadgeEarning) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(earning.name.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundColor(CoachPalette.gold)
            ForEach(earning.badges) { kind in
                HStack(spacing: 14) {
                    BadgeMedallion(kind: kind, size: 52, showsTitle: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kind.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CoachPalette.textPrimary)
                        Text(kind.detail)
                            .font(.system(size: 12))
                            .foregroundColor(CoachPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
