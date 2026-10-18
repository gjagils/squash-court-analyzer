import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The Live Activity of a live match: on the lock screen the players left and
/// right with the points large in the middle and a SquashAnalyzer bar below
/// (design chosen 18 October 2026, "variant 3"), the score again in the
/// Dynamic Island. Player 1 orange, player 2 steel blue.
struct LiveScoreActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveScoreAttributes.self) { context in
            LiveScoreLockScreenView(state: context.state, photos: LiveScorePhotos(matchId: context.attributes.matchId),
                                    startedAt: context.attributes.startedAt)
                .activityBackgroundTint(LiveScoreColors.card)
                .activitySystemActionForegroundColor(LiveScoreColors.textPrimary)
        } dynamicIsland: { context in
            let state = context.state
            let photos = LiveScorePhotos(matchId: context.attributes.matchId)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveScoreIslandPlayer(state: state, player: 1, photo: photos.player1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveScoreIslandPlayer(state: state, player: 2, photo: photos.player2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        Text("\(state.points(1))–\(state.points(2))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(LiveScoreColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let badge = state.ballBadge {
                            LiveScoreBadgeView(badge: badge)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        LiveScoreMark(size: 11)
                        LiveScoreStatusText(text: state.statusLine, size: 11)
                            .layoutPriority(1)
                        Spacer(minLength: 4)
                        LiveScoreChips(chips: state.gameChips, size: 11)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    LiveScoreAvatar(state: state, player: 1, photo: photos.player1, size: 22, lineWidth: 1.5)
                    Text("\(state.islandScore(1))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(LiveScoreColors.player1)
                }
            } compactTrailing: {
                HStack(spacing: 5) {
                    Text("\(state.islandScore(2))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(LiveScoreColors.player2Text)
                    LiveScoreAvatar(state: state, player: 2, photo: photos.player2, size: 22, lineWidth: 1.5)
                }
            } minimal: {
                Text(state.minimalText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.player1)
                    .minimumScaleFactor(0.7)
            }
            .keylineTint(LiveScoreColors.accent)
        }
    }
}

/// The viewer page's colours (live.html, docs/style/README.md); the extension
/// does not link SquashAnalyzerUI, so they are repeated here
enum LiveScoreColors {
    static let card = Color(red: 0x18 / 255.0, green: 0x0E / 255.0, blue: 0x04 / 255.0)
    static let accent = Color(red: 0xF2 / 255.0, green: 0x8C / 255.0, blue: 0x26 / 255.0)
    /// --line: the card's border and player 1's boxes
    static let line = accent.opacity(0.35)
    /// --border: the divider between the rows and neutral outlines
    static let border = Color.white.opacity(0.09)
    static let player1 = accent
    /// --blue: player 2's avatar ring
    static let player2 = Color(red: 0x59 / 255.0, green: 0x73 / 255.0, blue: 0x8C / 255.0)
    /// --blue-light: player 2's name, score and serve dot
    static let player2Text = Color(red: 0x80 / 255.0, green: 0x94 / 255.0, blue: 0xAD / 255.0)
    static let player2Line = player2Text.opacity(0.45)
    static let live = Color(red: 0xE5 / 255.0, green: 0x48 / 255.0, blue: 0x4D / 255.0)
    static let gold = Color(red: 0xE6 / 255.0, green: 0xB8 / 255.0, blue: 0x59 / 255.0)
    static let textPrimary = Color(red: 0xF2 / 255.0, green: 0xED / 255.0, blue: 0xE6 / 255.0)
    static let textSecondary = Color(red: 0xB3 / 255.0, green: 0xAD / 255.0, blue: 0xA6 / 255.0)

    /// Name, serve dot and chip text
    static func playerText(_ number: Int) -> Color { number == 1 ? player1 : player2Text }
    /// Avatar ring
    static func ring(_ number: Int) -> Color { number == 1 ? player1 : player2 }
}

/// The thumbnails the app stored for this match (LiveScorePhotoStore)
struct LiveScorePhotos {
    let player1: UIImage?
    let player2: UIImage?

    init(matchId: String) {
        player1 = LiveScorePhotoStore.image(matchId: matchId, player: 1)
        player2 = LiveScorePhotoStore.image(matchId: matchId, player: 2)
    }

    func photo(_ player: Int) -> UIImage? { player == 1 ? player1 : player2 }
}

/// The lock screen card, laid out like a sports score: both players left and
/// right (photo with a ring, the server's dot on it, the name below), the
/// points large in the middle with the games under them, and a bar along the
/// bottom with SquashAnalyzer, the finished games and the time played. The
/// system clips a Live Activity at about 160 pt: top part about 112, bar 36.
struct LiveScoreLockScreenView: View {
    let state: LiveScoreAttributes.ContentState
    let photos: LiveScorePhotos
    let startedAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                side(1)
                middle
                    .layoutPriority(1)
                side(2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)
            bar
        }
        .overlay(
            ContainerRelativeShape()
                .stroke(LiveScoreColors.line, lineWidth: 1)
        )
    }

    private func side(_ player: Int) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                LiveScoreAvatar(state: state, player: player, photo: photos.photo(player), size: 44, lineWidth: 2.5)
                Circle()
                    .fill(LiveScoreColors.playerText(player))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(LiveScoreColors.card, lineWidth: 2))
                    .offset(x: 1, y: 1)
                    .opacity(state.isServing(player) && !state.isFinished ? 1 : 0)
            }
            Text(state.name(player) + (state.isFinished && state.winner == player ? " 🏆" : ""))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.playerText(player))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.name(player) + (state.serveLine(player).map { line in ", " + line } ?? ""))
    }

    private var middle: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                if state.isFinished {
                    LiveScorePill(text: "AFGELOPEN", live: false)
                } else {
                    LiveScorePill(text: "LIVE", live: true)
                }
                // A game or match ball says more than the game number
                if let badge = state.ballBadge {
                    LiveScoreBadgeView(badge: badge)
                } else {
                    LiveScoreStatusText(text: state.statusLine, size: 11)
                }
            }
            .frame(height: 18)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(state.points(1))")
                Text("–")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary)
                Text("\(state.points(2))")
            }
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(LiveScoreColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                LiveScoreGamesBox(games: state.games(1), player: 1, size: 12)
                Text("games")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary)
                LiveScoreGamesBox(games: state.games(2), player: 2, size: 12)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// SquashAnalyzer on the left (only the mark when the games need the
    /// room); the finished games and the time played on the right
    private var bar: some View {
        HStack(spacing: 6) {
            LiveScoreBrand()
            Spacer(minLength: 4)
            LiveScoreChips(chips: state.gameChips, size: 11)
                .fixedSize()
                .layoutPriority(1)
            timer
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(LiveScoreColors.accent.opacity(0.08))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LiveScoreColors.line)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var timer: some View {
        if let startedAt, !state.isFinished {
            // "34:12"; the .timer style writes "34 minutes" on the lock screen
            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundColor(LiveScoreColors.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

/// The app's logo mark as a loose line drawing (Apple: no container, not the
/// app icon): the magnifying glass with the two eyes, in orange
struct LiveScoreMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let unit = canvas.width / 24.0
            var glass = Path()
            glass.addEllipse(in: CGRect(x: 4.0 * unit, y: 4.0 * unit, width: 13.0 * unit, height: 13.0 * unit))
            glass.move(to: CGPoint(x: 15.5 * unit, y: 15.5 * unit))
            glass.addLine(to: CGPoint(x: 20.5 * unit, y: 20.5 * unit))
            context.stroke(glass, with: .color(LiveScoreColors.accent),
                           style: StrokeStyle(lineWidth: 2.2 * unit, lineCap: .round))
            let eye = 1.0 * unit
            for x in [8.6, 12.4] {
                context.fill(Path(ellipseIn: CGRect(x: x * unit - eye, y: 9.6 * unit - eye, width: 2 * eye, height: 2 * eye)),
                             with: .color(LiveScoreColors.accent))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "SquashAnalyzer" with the mark, in the bar of the card; where the bar is
/// full (many games, a small screen) only the mark stays
struct LiveScoreBrand: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                LiveScoreMark(size: 13)
                (Text("Squash").foregroundColor(LiveScoreColors.textPrimary)
                    + Text("Analyzer").foregroundColor(LiveScoreColors.accent))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize()
            }
            LiveScoreMark(size: 13)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SquashAnalyzer")
    }
}

/// The orange status line in capitals ("GAME 3 · BEST OF 5")
struct LiveScoreStatusText: View {
    let text: String
    let size: CGFloat

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundColor(LiveScoreColors.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// The viewer page's badge: a red ● LIVE pill, or a grey outlined one at the end
struct LiveScorePill: View {
    let text: String
    let live: Bool

    var body: some View {
        HStack(spacing: 4) {
            if live {
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
            }
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundColor(live ? Color.white : LiveScoreColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(live ? LiveScoreColors.live : Color.clear)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(live ? LiveScoreColors.live : LiveScoreColors.border, lineWidth: 1))
        .fixedSize()
    }
}

/// A round photo with a ring in the player's colour, or the first letter
struct LiveScoreAvatar: View {
    let state: LiveScoreAttributes.ContentState
    let player: Int
    let photo: UIImage?
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(state.initial(player))
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundColor(LiveScoreColors.playerText(player))
            }
        }
        .frame(width: size, height: size)
        .background(LiveScoreColors.card)
        .clipShape(Circle())
        .overlay(Circle().stroke(LiveScoreColors.ring(player), lineWidth: lineWidth))
        .accessibilityHidden(true)
    }
}

/// The games won as a number in a small box, outlined in the player's colour
struct LiveScoreGamesBox: View {
    let games: Int
    let player: Int
    let size: CGFloat

    var body: some View {
        Text("\(games)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(LiveScoreColors.textSecondary)
            .frame(minWidth: size * 1.1)
            .padding(.horizontal, size * 0.35)
            .padding(.vertical, size * 0.18)
            .overlay(RoundedRectangle(cornerRadius: size * 0.5)
                .stroke(player == 2 ? LiveScoreColors.player2Line : LiveScoreColors.line, lineWidth: 1))
            .accessibilityLabel("\(games) games")
    }
}

/// The finished games, each in the colour of whoever won it
struct LiveScoreChips: View {
    let chips: [LiveScoreGameChip]
    let size: CGFloat

    var body: some View {
        HStack(spacing: size * 0.45) {
            ForEach(chips) { chip in
                Text(chip.text)
                    .font(.system(size: size, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(textColor(chip.winner))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, size * 0.6)
                    .padding(.vertical, size * 0.15)
                    .overlay(Capsule().stroke(lineColor(chip.winner), lineWidth: 1))
            }
        }
    }

    private func textColor(_ winner: Int) -> Color {
        winner == 1 || winner == 2 ? LiveScoreColors.playerText(winner) : LiveScoreColors.textSecondary
    }

    private func lineColor(_ winner: Int) -> Color {
        switch winner {
        case 1: return LiveScoreColors.line
        case 2: return LiveScoreColors.player2Line
        default: return LiveScoreColors.border
        }
    }
}

/// Avatar, name and games of one player in the expanded Dynamic Island
struct LiveScoreIslandPlayer: View {
    let state: LiveScoreAttributes.ContentState
    let player: Int
    let photo: UIImage?

    var body: some View {
        let leading = player == 1
        VStack(alignment: leading ? .leading : .trailing, spacing: 4) {
            HStack(spacing: 6) {
                if leading { LiveScoreAvatar(state: state, player: player, photo: photo, size: 28, lineWidth: 2) }
                VStack(alignment: leading ? .leading : .trailing, spacing: 0) {
                    Text(state.name(player))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(LiveScoreColors.playerText(player))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Circle()
                        .fill(LiveScoreColors.playerText(player))
                        .frame(width: 6, height: 6)
                        .opacity(state.isServing(player) ? 1 : 0)
                        .padding(.vertical, 2)
                        .accessibilityLabel("Opslag")
                        .accessibilityHidden(!state.isServing(player))
                }
                if !leading { LiveScoreAvatar(state: state, player: player, photo: photo, size: 28, lineWidth: 2) }
            }
            LiveScoreGamesBox(games: state.games(player), player: player, size: 13)
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

struct LiveScoreBadgeView: View {
    let badge: LiveScoreBadge

    private var color: Color {
        switch badge {
        case .gameBall, .matchBall: return LiveScoreColors.gold
        case .pause, .finished: return LiveScoreColors.textSecondary
        }
    }

    var body: some View {
        Text(badge.title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            .fixedSize()
    }
}
