import SwiftUI

struct CourtView: View {
    var game: Game? = nil
    var onZoneTapped: ((CourtZone) -> Void)? = nil

    // Court dimensions in meters (official squash court)
    private let courtWidth: CGFloat = 6.4   // meters (21 feet)
    private let courtLength: CGFloat = 9.75 // meters (32 feet)
    private let serviceBoxSize: CGFloat = 1.6 // meters (63 inches)
    private let shortLineDistance: CGFloat = 5.44 // meters from front wall (17.85 feet)

    // Computed ratio for proper scaling
    private var aspectRatio: CGFloat {
        courtWidth / courtLength
    }

    private var isInteractive: Bool {
        game?.selectedPlayer != nil && game?.selectedZone == nil
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Calculate court size maintaining aspect ratio
            let courtSize = calculateCourtSize(
                availableWidth: availableWidth,
                availableHeight: availableHeight
            )

            // Scale factor: pixels per meter
            let scale = courtSize.height / courtLength

            SportsPanel(accent: isInteractive ? playerColor : nil) {
                ZStack {
                    courtFloor(size: courtSize)

                    // Interactive zones (when player is selected but zone not yet)
                    if isInteractive {
                        interactiveZones(size: courtSize)
                    }

                    // Court markings
                    courtMarkings(size: courtSize, scale: scale)

                    // Instruction overlay when player selected
                    if let player = game?.selectedPlayer, game?.selectedZone == nil, let game = game {
                        instructionOverlay(size: courtSize, player: player, game: game)
                    }
                }
                .frame(width: courtSize.width, height: courtSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(10)
            }
            .frame(width: courtSize.width + 20, height: courtSize.height + 20)
            .position(x: availableWidth / 2, y: availableHeight / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Interactive Zones
    private func interactiveZones(size: CGSize) -> some View {
        let zoneWidth = size.width / 3
        let zoneHeight = size.height / 3

        return ZStack {
            // 9 tappable zones in a 3x3 grid
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<3, id: \.self) { col in
                    let zone = zoneFor(row: row, col: col)
                    let xOffset = CGFloat(col) * zoneWidth + zoneWidth / 2
                    let yOffset = CGFloat(row) * zoneHeight + zoneHeight / 2

                    ZoneTapArea(zone: zone, playerColor: playerColor) {
                        onZoneTapped?(zone)
                    }
                    .frame(width: zoneWidth - 6, height: zoneHeight - 6)
                    .position(x: xOffset, y: yOffset)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var playerColor: Color {
        guard let player = game?.selectedPlayer else { return AppColors.warmOrange }
        return player == .player1 ? AppColors.warmOrange : AppColors.deepBlue
    }

    private func zoneFor(row: Int, col: Int) -> CourtZone {
        switch (row, col) {
        case (0, 0): return .frontLeft
        case (0, 1): return .frontMiddle
        case (0, 2): return .frontRight
        case (1, 0): return .middleLeft
        case (1, 1): return .middleMiddle
        case (1, 2): return .middleRight
        case (2, 0): return .backLeft
        case (2, 1): return .backMiddle
        case (2, 2): return .backRight
        default: return .middleMiddle
        }
    }

    // MARK: - Instruction Overlay
    private func instructionOverlay(size: CGSize, player: Player, game: Game) -> some View {
        let color = player == .player1 ? AppColors.warmOrange : AppColors.deepBlue

        return VStack {
            Text("KIES EEN ZONE")
                .font(AppFonts.caption(11))
                .foregroundColor(color)
                .tracking(1.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.78))
                        .overlay(Capsule().stroke(color.opacity(0.55), lineWidth: 1))
                )
        }
        .position(x: size.width / 2, y: size.height / 2)
        .allowsHitTesting(false)
    }

    // MARK: - Court Floor
    private func courtFloor(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.075),
                            Color.white.opacity(0.035),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 6)
                .fill(
                    RadialGradient(
                        colors: [AppColors.accentGold.opacity(0.055), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: size.height * 0.65
                    )
                )
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Court Markings (no arcs)
    private func courtMarkings(size: CGSize, scale: CGFloat) -> some View {
        let lineColor = AppColors.accentGold.opacity(0.62)
        let lineWidth: CGFloat = 1.5

        let shortLineY = shortLineDistance * scale
        let halfCourtX = size.width / 2
        let serviceBoxPixels = serviceBoxSize * scale

        return ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 6)
                .stroke(lineColor, lineWidth: 2)
                .frame(width: size.width, height: size.height)

            // Short line (horizontal)
            Path { path in
                path.move(to: CGPoint(x: 0, y: shortLineY))
                path.addLine(to: CGPoint(x: size.width, y: shortLineY))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Half court line (vertical, from short line to back)
            Path { path in
                path.move(to: CGPoint(x: halfCourtX, y: shortLineY))
                path.addLine(to: CGPoint(x: halfCourtX, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Left service box (L-shape only, no arc) — against short line
            Path { path in
                path.move(to: CGPoint(x: 0, y: shortLineY + serviceBoxPixels))
                path.addLine(to: CGPoint(x: serviceBoxPixels, y: shortLineY + serviceBoxPixels))
                path.addLine(to: CGPoint(x: serviceBoxPixels, y: shortLineY))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Right service box (L-shape only, no arc) — against short line
            Path { path in
                path.move(to: CGPoint(x: size.width, y: shortLineY + serviceBoxPixels))
                path.addLine(to: CGPoint(x: size.width - serviceBoxPixels, y: shortLineY + serviceBoxPixels))
                path.addLine(to: CGPoint(x: size.width - serviceBoxPixels, y: shortLineY))
            }
            .stroke(lineColor, lineWidth: lineWidth)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - Helper
    private func calculateCourtSize(availableWidth: CGFloat, availableHeight: CGFloat) -> CGSize {
        // Account for panel padding
        let adjustedWidth = availableWidth - 20
        let adjustedHeight = availableHeight - 20

        let widthBasedHeight = adjustedWidth / aspectRatio
        let heightBasedWidth = adjustedHeight * aspectRatio

        if widthBasedHeight <= adjustedHeight {
            return CGSize(width: adjustedWidth, height: widthBasedHeight)
        } else {
            return CGSize(width: heightBasedWidth, height: adjustedHeight)
        }
    }
}

// MARK: - Zone Tap Area

struct ZoneTapArea: View {
    let zone: CourtZone
    var playerColor: Color = AppColors.warmOrange
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Zone highlight
            RoundedRectangle(cornerRadius: 6)
                .fill(playerColor.opacity(isPressed ? 0.28 : 0.08))

            // Border
            RoundedRectangle(cornerRadius: 6)
                .stroke(playerColor.opacity(isPressed ? 0.85 : 0.28), lineWidth: 1)

            // Zone label
            Text(zone.shortName)
                .font(AppFonts.caption(10))
                .foregroundColor(playerColor.opacity(isPressed ? 1 : 0.72))
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
                onTap()
            }
        }
    }
}

// MARK: - Preview

#Preview("Court - Default") {
    ZStack {
        AppBackground()
        CourtView()
            .padding(20)
    }
}

#Preview("Court - Player Selected") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = game.selectPlayer(.player1)

        CourtView(game: game) { zone in
            print("Tapped: \(zone)")
        }
        .padding(20)
    }
}

#Preview("Court - Player 2 Selected") {
    ZStack {
        AppBackground()

        let game = Game()
        let _ = game.selectPlayer(.player2)

        CourtView(game: game) { zone in
            print("Tapped: \(zone)")
        }
        .padding(20)
    }
}
