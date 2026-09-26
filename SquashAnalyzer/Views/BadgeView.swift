import SwiftUI

/// A badge medallion: the artwork in colour once earned, greyed out while it is
/// still to earn. A badge without artwork yet gets a plain gold medallion.
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

    @ViewBuilder
    private var medallion: some View {
        if let image = UIImage(named: kind.imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Circle().fill(AppColors.accentGold.opacity(0.18))
                Circle().strokeBorder(AppColors.accentGold, lineWidth: size * 0.05)
                Image(systemName: "medal.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(AppColors.accentGold)
            }
        }
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
