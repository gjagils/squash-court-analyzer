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
        Button(action: {
            // Trigger highlight effect on tap
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = true
            }
            // Keep highlighted briefly then execute
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                action()
                withAnimation(.easeOut(duration: 0.2)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: 6) {
                // Icon with glow
                ZStack {
                    // Glow effect when pressed
                    if isPressed {
                        ShotIconView(type: shotType, color: color, size: 28)
                            .blur(radius: 8)
                            .opacity(0.7)
                    }

                    ShotIconView(type: shotType, color: isPressed ? color : AppColors.textPrimary, size: 28)
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
                    .fill(isPressed ? color.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPressed ? color.opacity(0.7) : Color.white.opacity(0.1), lineWidth: isPressed ? 2 : 1)
                    .shadow(color: isPressed ? color.opacity(0.5) : .clear, radius: 8)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shot Icon View (routes to custom or SF Symbol)
struct ShotIconView: View {
    let type: ShotType
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 28

    var body: some View {
        switch type {
        case .drive:
            // Custom: vertical arrow down
            DriveIcon(color: color, size: size)
        case .cross:
            // SF Symbol v1
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundColor(color)
        case .volley:
            // SF Symbol v1
            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundColor(color)
        case .drop:
            // SF Symbol v1
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundColor(color)
        case .lob:
            // Custom: high arc with arrow point
            LobIcon(color: color, size: size)
        case .boast:
            // Custom: zigzag like the reference image
            BoastIcon(color: color, size: size)
        }
    }
}

// MARK: - Custom Icons

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

struct LobIcon: View {
    var color: Color = AppColors.textPrimary
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth: CGFloat = 2.5

            // Higher arc that starts and ends at same height
            var path = Path()
            path.move(to: CGPoint(x: w * 0.08, y: h * 0.85))
            path.addQuadCurve(
                to: CGPoint(x: w * 0.92, y: h * 0.85),
                control: CGPoint(x: w * 0.5, y: h * -0.15)  // Higher control point
            )

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))

            // Arrow head at the end (pointing down-right following the curve tangent)
            var arrowHead = Path()
            arrowHead.move(to: CGPoint(x: w * 0.72, y: h * 0.62))
            arrowHead.addLine(to: CGPoint(x: w * 0.92, y: h * 0.85))
            arrowHead.addLine(to: CGPoint(x: w * 0.68, y: h * 0.85))

            context.stroke(arrowHead, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
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

            // Boast: incoming ball hits side wall, then front wall, then comes back diagonally
            // Incoming line parallel to the outgoing arrow segment
            var path = Path()
            // Start: incoming ball from bottom-right, parallel to outgoing line
            path.move(to: CGPoint(x: w * 0.55, y: h * 0.9))
            // Hit left side wall
            path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.17))
            // Hit front wall
            path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.15))
            // Diagonal down-right (ball coming back) - outgoing with arrow
            path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.55))

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))

            // Arrow head at the end
            var arrowHead = Path()
            arrowHead.move(to: CGPoint(x: w * 0.72, y: h * 0.42))
            arrowHead.addLine(to: CGPoint(x: w * 0.92, y: h * 0.55))
            arrowHead.addLine(to: CGPoint(x: w * 0.95, y: h * 0.32))

            context.stroke(arrowHead, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
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
