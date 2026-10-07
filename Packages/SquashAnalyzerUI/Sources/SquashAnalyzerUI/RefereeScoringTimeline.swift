import SwiftUI
import SquashAnalyzerCore

/// Vertical rally-by-rally line between the two player columns: newest rally at
/// the top under the "now" marker, each pill showing the scorer's new score and
/// the box they serve from next ("4R"). Player 1 pills hang left, player 2 right.
/// Shared by iOS (RefereeView) and Android (RefereeScoringView).
public struct RefereeScoringTimeline: View {
    let entries: [RefereePointEntry]   // oldest first
    let server: Player

    public init(entries: [RefereePointEntry], server: Player) {
        self.entries = entries
        self.server = server
    }

    private let width: CGFloat = 100
    private let rowHeight: CGFloat = 30
    private let dotSize: CGFloat = 14

    public var body: some View {
        let serverColor = Self.color(for: server)

        VStack(spacing: 0) {
            nowMarker(color: serverColor)
                .frame(height: 52)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(entries.reversed()) { entry in
                        row(entry)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            #if !SKIP
            .scrollBounceBehavior(.basedOnSize)
            #endif
        }
        .background(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [serverColor.opacity(0.7), serverColor.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5)
                .padding(.top, 26)
        }
        .frame(width: width)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.25), value: entries)
        .animation(.easeInOut(duration: 0.25), value: server)
    }

    private func nowMarker(color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: 34, height: 34)
                .blur(radius: 5)
            Circle()
                .fill(color)
                .frame(width: 15, height: 15)
                .shadow(color: color.opacity(0.9), radius: 6)
        }
    }

    private func row(_ entry: RefereePointEntry) -> some View {
        let color = Self.color(for: entry.scorer)
        let isLeft = entry.scorer == .player1
        // Reserve half the width minus the dot radius so the dot sits on the line
        let inner = width / 2 - dotSize / 2

        return HStack(spacing: 0) {
            if isLeft {
                Spacer(minLength: 0)
                pill(entry, color: color, dotOnRight: true)
                Color.clear.frame(width: inner)
            } else {
                Color.clear.frame(width: inner)
                pill(entry, color: color, dotOnRight: false)
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: rowHeight)
    }

    private func pill(_ entry: RefereePointEntry, color: Color, dotOnRight: Bool) -> some View {
        HStack(spacing: 4) {
            if !dotOnRight { dot(color: color) }
            Text(entry.label)
                .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                #if !SKIP
                .monospacedDigit()
                #endif
            if dotOnRight { dot(color: color) }
        }
        .padding(.leading, dotOnRight ? CGFloat(8) : CGFloat(3))
        .padding(.trailing, dotOnRight ? CGFloat(3) : CGFloat(8))
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color)
                .overlay(
                    // Strokes get a thin light ring so they stand out in the history
                    Capsule().stroke(Color.white.opacity(entry.isStroke ? 0.7 : 0.0), lineWidth: 1)
                )
        )
    }

    private func dot(color: Color) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: dotSize, height: dotSize)
            .overlay(
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            )
    }

    private static func color(for player: Player) -> Color {
        player == .player1 ? SharedColors.accent : SharedColors.steelBlue
    }
}
