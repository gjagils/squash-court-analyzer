import ActivityKit
import SwiftUI
import WidgetKit

/// The Live Activity of a live match: a dark card on the lock screen and the
/// score in the Dynamic Island. Design approved by Gerd-Jan (October 2026):
/// the referee screen's colours, player 1 orange, player 2 steel blue.
struct LiveScoreActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveScoreAttributes.self) { context in
            LiveScoreLockScreenView(state: context.state, startedAt: context.attributes.startedAt)
                .activityBackgroundTint(LiveScoreColors.card)
                .activitySystemActionForegroundColor(LiveScoreColors.textPrimary)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveScoreIslandPlayer(state: state, player: 1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LiveScoreIslandPlayer(state: state, player: 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(state.shownScore(1))–\(state.shownScore(2))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(LiveScoreColors.textPrimary)
                            .lineLimit(1)
                        if let badge = state.badge {
                            LiveScoreBadgeView(badge: badge)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(state.islandLine)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 8)
                        if state.isPlaying || state.isWarmup {
                            Text(state.serviceText).lineLimit(1)
                        }
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.textSecondary)
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    LiveScoreServerDot(visible: state.isServing(1), size: 6)
                    Text("\(state.shownScore(1))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(LiveScoreColors.player1)
                }
                .padding(.leading, 2)
            } compactTrailing: {
                HStack(spacing: 5) {
                    Text("\(state.shownScore(2))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(LiveScoreColors.player2)
                    LiveScoreServerDot(visible: state.isServing(2), size: 6)
                }
                .padding(.trailing, 2)
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

/// The referee screen's colours (docs/style/README.md); the extension does
/// not link SquashAnalyzerUI, so they are repeated here
enum LiveScoreColors {
    static let card = Color(red: 0x18 / 255.0, green: 0x0E / 255.0, blue: 0x04 / 255.0)
    static let accent = Color(red: 0xF2 / 255.0, green: 0x8C / 255.0, blue: 0x26 / 255.0)
    static let player1 = accent
    static let player2 = Color(red: 0x80 / 255.0, green: 0x94 / 255.0, blue: 0xAD / 255.0)
    static let serverDot = Color(red: 0xFF / 255.0, green: 0x99 / 255.0, blue: 0x26 / 255.0)
    static let gold = Color(red: 0xE6 / 255.0, green: 0xB8 / 255.0, blue: 0x59 / 255.0)
    static let textPrimary = Color(red: 0xF2 / 255.0, green: 0xED / 255.0, blue: 0xE6 / 255.0)
    static let textSecondary = Color(red: 0xB3 / 255.0, green: 0xAD / 255.0, blue: 0xA6 / 255.0)

    static func player(_ number: Int) -> Color { number == 1 ? player1 : player2 }
}

/// The lock screen card
struct LiveScoreLockScreenView: View {
    let state: LiveScoreAttributes.ContentState
    let startedAt: Date?

    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(.bottom, 2)
            row(1)
            row(2)
            footer
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(
            ContainerRelativeShape()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            LiveScoreGlyph()
                .frame(width: 14, height: 14)
            Text(state.headerTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let badge = state.badge {
                LiveScoreBadgeView(badge: badge)
            } else if let startedAt {
                Text(startedAt, style: .timer)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .frame(height: 18)
    }

    private func row(_ player: Int) -> some View {
        HStack(spacing: 8) {
            LiveScoreServerDot(visible: state.isServing(player), size: 8)
            Text(state.name(player))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.player(player))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            LiveScorePips(filled: state.pips(player), total: state.gamesToWin, color: LiveScoreColors.player(player), size: 9)
            Text("\(state.shownScore(player))")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(LiveScoreColors.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 58, alignment: .trailing)
        }
        .frame(height: 42)
    }

    private var footer: some View {
        HStack {
            Text(state.footerLeading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            Text(state.footerTrailing)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .monospacedDigit()
        .foregroundColor(LiveScoreColors.textSecondary)
        .frame(height: 16)
    }
}

/// Name and pips of one player in the expanded Dynamic Island
struct LiveScoreIslandPlayer: View {
    let state: LiveScoreAttributes.ContentState
    let player: Int

    var body: some View {
        let alignment: HorizontalAlignment = player == 1 ? .leading : .trailing
        VStack(alignment: alignment, spacing: 6) {
            HStack(spacing: 5) {
                if player == 1 { LiveScoreServerDot(visible: state.isServing(1), size: 7) }
                Text(state.name(player))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(LiveScoreColors.player(player))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if player == 2 { LiveScoreServerDot(visible: state.isServing(2), size: 7) }
            }
            LiveScorePips(filled: state.pips(player), total: state.gamesToWin, color: LiveScoreColors.player(player), size: 8)
        }
        .frame(maxWidth: .infinity, alignment: player == 1 ? .leading : .trailing)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}

/// The orange dot of the server, with a soft glow; keeps its place when hidden
struct LiveScoreServerDot: View {
    let visible: Bool
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(LiveScoreColors.serverDot)
            .frame(width: size, height: size)
            .shadow(color: LiveScoreColors.serverDot.opacity(0.8), radius: size * 0.6)
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(!visible)
            .accessibilityLabel("Opslag")
    }
}

/// One square per game needed to win, filled for the games won
struct LiveScorePips: View {
    let filled: Int
    let total: Int
    let color: Color
    let size: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filled ? color : color.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(color.opacity(index < filled ? 0 : 0.5), lineWidth: 1))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityLabel("\(filled) games")
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
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }
}

/// The app's mark, small: the magnifier ring around a squash ball with two
/// yellow dots, in orange
struct LiveScoreGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(LiveScoreColors.accent, lineWidth: side * 0.14)
                    .padding(side * 0.07)
                HStack(spacing: side * 0.12) {
                    Circle().fill(LiveScoreColors.accent).frame(width: side * 0.16, height: side * 0.16)
                    Circle().fill(LiveScoreColors.accent).frame(width: side * 0.16, height: side * 0.16)
                }
            }
            .frame(width: side, height: side)
        }
        .accessibilityHidden(true)
    }
}
