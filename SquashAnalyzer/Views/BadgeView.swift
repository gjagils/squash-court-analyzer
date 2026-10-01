import SwiftUI
import SquashAnalyzerCore
import SquashAnalyzerUI

/// A badge medallion: the artwork in colour once earned, greyed out while it is
/// still to earn.
struct BadgeView: View {
    let kind: BadgeKind
    var size: CGFloat = 64
    var showsTitle = true
    var isLocked = false

    var body: some View {
        VStack(spacing: 6) {
            medallion
                .frame(width: size, height: size)
                .grayscale(isLocked ? 1 : 0)
                .opacity(isLocked ? 0.35 : 1)

            if showsTitle {
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isLocked ? AppColors.textMuted : AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Badge \(kind.title)\(isLocked ? ", nog niet verdiend" : "")")
    }

    /// The artwork lives in SquashAnalyzerUI, shared with Android
    private var medallion: some View {
        BadgeArtwork(kind: kind)
    }
}

#Preview {
    HStack {
        BadgeView(kind: .fiveInARow)
        BadgeView(kind: .elevenNil, isLocked: true)
        BadgeView(kind: .houdini)
    }
    .padding()
    .background(AppColors.backgroundDark)
}
