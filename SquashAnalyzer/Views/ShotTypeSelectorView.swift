import SwiftUI

/// View for selecting the type of shot after zone selection
struct ShotTypeSelectorView: View {
    let game: Game
    let onShotSelected: (ShotType) -> Void
    let onBack: () -> Void

    private var playerColor: Color {
        game.selectedPlayer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with context
            headerSection

            // Shot type grid
            shotTypeGrid

            // Back button
            backButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.backgroundMedium.opacity(0.95))
                .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(playerColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 6) {
            if let player = game.selectedPlayer, let zone = game.selectedZone {
                Text("\(game.name(for: player).uppercased()) SCOORT")
                    .font(AppFonts.caption(11))
                    .foregroundColor(playerColor)
                    .tracking(1.5)

                Text("in \(zone.rawValue)")
                    .font(AppFonts.body(14))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("Welke slag?")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, 4)
        }
    }

    // MARK: - Shot Type Grid
    private var shotTypeGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(ShotType.allCases) { shotType in
                ShotTypeButton(
                    shotType: shotType,
                    color: playerColor
                ) {
                    onShotSelected(shotType)
                }
            }
        }
    }

    // MARK: - Back Button
    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("Terug")
                    .font(AppFonts.caption(12))
            }
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - Shot Type Button
struct ShotTypeButton: View {
    let shotType: ShotType
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Custom Icon with glow
                ZStack {
                    // Glow effect when pressed
                    if isPressed {
                        ShotIcon(type: shotType, color: color, size: 28)
                            .blur(radius: 6)
                            .opacity(0.6)
                    }

                    ShotIcon(type: shotType, color: isPressed ? color : AppColors.textPrimary, size: 28)
                }
                .frame(height: 32)

                // Name
                Text(shotType.rawValue.uppercased())
                    .font(AppFonts.caption(10))
                    .foregroundColor(isPressed ? color : AppColors.textSecondary)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPressed ? color.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPressed ? color.opacity(0.6) : Color.white.opacity(0.1), lineWidth: isPressed ? 1.5 : 1)
                    .shadow(color: isPressed ? color.opacity(0.4) : .clear, radius: 6)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Shot Icon Router
struct ShotIcon: View {
    let type: ShotType
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        switch type {
        case .drive:
            DriveIcon(color: color, size: size)
        case .cross:
            CrossIcon(color: color, size: size)
        case .volley:
            VolleyIcon(color: color, size: size)
        case .drop:
            DropIcon(color: color, size: size)
        case .lob:
            LobIcon(color: color, size: size)
        case .boast:
            BoastIcon(color: color, size: size)
        }
    }
}

// MARK: - Custom Shot Icons

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
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))

            // Arrow head
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.65))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
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
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.15))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))

            // Arrow head
            path.move(to: CGPoint(x: w * 0.6, y: h * 0.85))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.6))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
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
            path.move(to: CGPoint(x: w * 0.6, y: h * 0.05))
            path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.45))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.95))

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
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.2))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.8, y: h * 0.85),
                control: CGPoint(x: w * 0.25, y: h * 0.85)
            )

            // Arrow head
            path.move(to: CGPoint(x: w * 0.58, y: h * 0.78))
            path.addLine(to: CGPoint(x: w * 0.8, y: h * 0.85))
            path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.62))

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
            path.move(to: CGPoint(x: w * 0.1, y: h * 0.75))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.9, y: h * 0.75),
                control: CGPoint(x: w * 0.5, y: h * 0.0)
            )

            // Arrow head at end
            path.move(to: CGPoint(x: w * 0.72, y: h * 0.48))
            path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.75))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.78))

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
            var path = Path()
            // Start from bottom right, go to left wall (top)
            path.move(to: CGPoint(x: w * 0.9, y: h * 0.9))
            path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.2))
            // Hit front wall (go right)
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.2))
            // Come back down
            path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.55))

            // Arrow head
            path.move(to: CGPoint(x: w * 0.72, y: h * 0.38))
            path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.55))
            path.addLine(to: CGPoint(x: w * 0.98, y: h * 0.38))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Shot Type Selector - Player 1") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = {
            game.player1Name = "Niels"
            game.player2Name = "Paul"
            game.selectPlayer(.player1)
            game.selectZone(.frontLeft)
        }()

        ShotTypeSelectorView(
            game: game,
            onShotSelected: { shot in print("Selected: \(shot)") },
            onBack: { print("Back") }
        )
    }
}

#Preview("Shot Type Selector - Player 2") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = {
            game.player1Name = "Niels"
            game.player2Name = "Paul"
            game.selectPlayer(.player2)
            game.selectZone(.backRight)
        }()

        ShotTypeSelectorView(
            game: game,
            onShotSelected: { shot in print("Selected: \(shot)") },
            onBack: { print("Back") }
        )
    }
}
