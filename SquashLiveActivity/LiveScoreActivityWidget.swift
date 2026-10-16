import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The Live Activity of a live match: on the lock screen the same ticker as
/// the viewer page (server/live-worker/public/live.html): a round photo or
/// first letter per player, the server's side under the name, the games in a
/// small box and the points; above it a red LIVE pill and the status line,
/// below it the finished games in the winner's colour. The score again in the
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

/// The lock screen card. Compact: the system clips a Live Activity at about
/// 160 pt, so avatars are 32 pt and the points 34 pt
struct LiveScoreLockScreenView: View {
    let state: LiveScoreAttributes.ContentState
    let photos: LiveScorePhotos
    let startedAt: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 4)
            row(1)
            Rectangle()
                .fill(LiveScoreColors.border)
                .frame(height: 1)
            row(2)
            if !state.gameChips.isEmpty || startedAt != nil {
                footer
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(
            ContainerRelativeShape()
                .stroke(LiveScoreColors.line, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                if state.isFinished {
                    LiveScorePill(text: "AFGELOPEN", live: false)
                } else {
                    LiveScorePill(text: "LIVE", live: true)
                }
                LiveScoreStatusText(text: state.statusLine, size: 12)
                if let badge = state.ballBadge {
                    LiveScoreBadgeView(badge: badge)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            LiveScoreBrand()
        }
        .frame(height: 20)
    }

    private func row(_ player: Int) -> some View {
        HStack(spacing: 10) {
            LiveScoreAvatar(state: state, player: player, photo: photos.photo(player), size: 32, lineWidth: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.name(player) + (state.isFinished && state.winner == player ? " 🏆" : ""))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(LiveScoreColors.playerText(player))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                LiveScoreServeLine(state: state, player: player, size: 11)
            }
            Spacer(minLength: 6)
            LiveScoreGamesBox(games: state.games(player), size: 15)
            Text("\(state.points(player))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(LiveScoreColors.textPrimary)
                .lineLimit(1)
                .frame(width: 46, alignment: .trailing)
        }
        .frame(height: 42)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            LiveScoreChips(chips: state.gameChips, size: 12)
            Spacer(minLength: 6)
            if let startedAt, !state.isFinished {
                Text(startedAt, style: .timer)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .frame(height: 20)
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

/// "SquashAnalyzer" with the mark, top right of the card; where the header is
/// full (MATCHBAL and a long status, a small screen) only the mark stays
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

/// "● serveert rechts" under the server's name; keeps its height for the other
struct LiveScoreServeLine: View {
    let state: LiveScoreAttributes.ContentState
    let player: Int
    let size: CGFloat

    var body: some View {
        let line = state.serveLine(player)
        HStack(spacing: 4) {
            Circle()
                .fill(LiveScoreColors.playerText(player))
                .frame(width: size * 0.6, height: size * 0.6)
            Text(line ?? "serveert")
                .font(.system(size: size, weight: .regular, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
                .lineLimit(1)
        }
        .opacity(line == nil ? 0 : 1)
        .accessibilityHidden(line == nil)
    }
}

/// The games won as a number in a small bordered box
struct LiveScoreGamesBox: View {
    let games: Int
    let size: CGFloat

    var body: some View {
        Text("\(games)")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(LiveScoreColors.textSecondary)
            .frame(minWidth: size * 1.1)
            .padding(.horizontal, size * 0.35)
            .padding(.vertical, size * 0.18)
            .overlay(RoundedRectangle(cornerRadius: size * 0.5).stroke(LiveScoreColors.line, lineWidth: 1))
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
            LiveScoreGamesBox(games: state.games(player), size: 13)
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
