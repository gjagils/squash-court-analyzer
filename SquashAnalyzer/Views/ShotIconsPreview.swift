import SwiftUI

// MARK: - Shot Type Icons

struct DriveIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Vertical arrow from top to bottom
            var path = Path()
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.85))

            // Arrow head
            path.move(to: CGPoint(x: w * 0.3, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.85))
            path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.65))

            context.stroke(path, with: .color(color), lineWidth: strokeWidth)
        }
        .frame(width: size, height: size)
    }
}

struct CrossIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Diagonal line from top-left to bottom-right
            var path = Path()
            path.move(to: CGPoint(x: w * 0.2, y: h * 0.2))
            path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.8))

            // Arrow head
            path.move(to: CGPoint(x: w * 0.6, y: h * 0.8))
            path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.8))
            path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.6))

            context.stroke(path, with: .color(color), lineWidth: strokeWidth)
        }
        .frame(width: size, height: size)
    }
}

struct VolleyIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Lightning bolt style for quick volley
            var path = Path()
            path.move(to: CGPoint(x: w * 0.6, y: h * 0.1))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.9))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct DropIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Steep downward curve for drop shot
            var path = Path()
            path.move(to: CGPoint(x: w * 0.2, y: h * 0.25))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.75, y: h * 0.8),
                control: CGPoint(x: w * 0.3, y: h * 0.8)
            )

            // Arrow head
            path.move(to: CGPoint(x: w * 0.55, y: h * 0.75))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.8))
            path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.6))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct LobIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Arc that starts and ends at same height (parabola)
            var path = Path()
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.7))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.7),
                control: CGPoint(x: w * 0.5, y: h * 0.1)
            )

            // Arrow head at end
            path.move(to: CGPoint(x: w * 0.7, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.7))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.75))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct BoastIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Boast: hits side wall, then front wall, then angles back
            // Like the image: diagonal up-left, then right along top, then diagonal down-right
            var path = Path()
            // Start from bottom right, go to left wall
            path.move(to: CGPoint(x: w * 0.85, y: h * 0.85))
            path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.2))
            // Hit front wall (go right)
            path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.2))
            // Come back down
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.5))

            // Arrow head
            path.move(to: CGPoint(x: w * 0.7, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.35))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview Grid

struct ShotIconsPreview: View {
    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 30) {
                Text("SHOT TYPE ICONS")
                    .font(AppFonts.title(20))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(2)

                // Icons grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    IconPreviewCell(name: "Drive", icon: DriveIcon(size: 50))
                    IconPreviewCell(name: "Cross", icon: CrossIcon(size: 50))
                    IconPreviewCell(name: "Volley", icon: VolleyIcon(size: 50))
                    IconPreviewCell(name: "Drop", icon: DropIcon(size: 50))
                    IconPreviewCell(name: "Lob", icon: LobIcon(size: 50))
                    IconPreviewCell(name: "Boast", icon: BoastIcon(size: 50))
                }
                .padding(.horizontal, 20)

                Divider()
                    .background(AppColors.textMuted)
                    .padding(.horizontal, 40)

                // Selected state example
                Text("GESELECTEERD")
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 30) {
                    IconPreviewCell(
                        name: "Drive",
                        icon: DriveIcon(color: AppColors.warmOrange, size: 50),
                        isSelected: true
                    )
                    IconPreviewCell(
                        name: "Boast",
                        icon: BoastIcon(color: AppColors.warmOrange, size: 50),
                        isSelected: true
                    )
                }
            }
            .padding()
        }
    }
}

struct IconPreviewCell<Icon: View>: View {
    let name: String
    let icon: Icon
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Glow effect when selected
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.warmOrange.opacity(0.2))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.warmOrange, lineWidth: 2)
                        .shadow(color: AppColors.warmOrange.opacity(0.6), radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }

                icon
            }
            .frame(width: 70, height: 70)

            Text(name.uppercased())
                .font(AppFonts.caption(10))
                .foregroundColor(isSelected ? AppColors.warmOrange : AppColors.textSecondary)
        }
    }
}

#Preview("Shot Icons") {
    ShotIconsPreview()
}
