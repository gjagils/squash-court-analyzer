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
        game?.selectedPlayer != nil
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

            ZStack {
                // Court floor with gradient
                courtFloor(size: courtSize)

                // Interactive zones (when player is selected)
                if isInteractive {
                    interactiveZones(size: courtSize)
                }

                // Court markings
                courtMarkings(size: courtSize, scale: scale)

                // Wall labels
                wallLabels(size: courtSize)

                // Instruction overlay when player selected
                if let player = game?.selectedPlayer, let game = game {
                    instructionOverlay(size: courtSize, player: player, game: game)
                }
            }
            .frame(width: courtSize.width, height: courtSize.height)
            .position(x: availableWidth / 2, y: availableHeight / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Interactive Zones
    private func interactiveZones(size: CGSize) -> some View {
        let zoneWidth = size.width / 2
        let zoneHeight = size.height / 3

        return ZStack {
            // 6 tappable zones in a 2x3 grid
            ForEach(0..<3, id: \.self) { row in
                ForEach(0..<2, id: \.self) { col in
                    let zone = zoneFor(row: row, col: col)
                    let xOffset = CGFloat(col) * zoneWidth + zoneWidth / 2
                    let yOffset = CGFloat(row) * zoneHeight + zoneHeight / 2

                    ZoneTapArea(zone: zone) {
                        onZoneTapped?(zone)
                    }
                    .frame(width: zoneWidth - 4, height: zoneHeight - 4)
                    .position(x: xOffset, y: yOffset)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func zoneFor(row: Int, col: Int) -> CourtZone {
        switch (row, col) {
        case (0, 0): return .frontLeft
        case (0, 1): return .frontRight
        case (1, 0): return .middleLeft
        case (1, 1): return .middleRight
        case (2, 0): return .backLeft
        case (2, 1): return .backRight
        default: return .middleLeft
        }
    }

    // MARK: - Instruction Overlay
    private func instructionOverlay(size: CGSize, player: Player, game: Game) -> some View {
        VStack {
            Text("Tik waar \(game.name(for: player)) scoorde")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(player == .player1 ? Color.blue : Color.red)
                )
                .shadow(radius: 4)
        }
        .position(x: size.width / 2, y: size.height / 2)
        .allowsHitTesting(false)
    }

    // MARK: - Court Floor
    private func courtFloor(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.76, green: 0.60, blue: 0.42),
                        Color(red: 0.68, green: 0.52, blue: 0.34)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.clear,
                                Color.white.opacity(0.03),
                                Color.clear,
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red.opacity(0.8), lineWidth: 4)
            )
            .frame(width: size.width, height: size.height)
    }

    // MARK: - Court Markings
    private func courtMarkings(size: CGSize, scale: CGFloat) -> some View {
        let lineColor = Color.red.opacity(0.9)
        let lineWidth: CGFloat = 2

        let shortLineY = shortLineDistance * scale
        let halfCourtX = size.width / 2
        let serviceBoxPixels = serviceBoxSize * scale

        return ZStack {
            // Short line
            Path { path in
                path.move(to: CGPoint(x: 0, y: shortLineY))
                path.addLine(to: CGPoint(x: size.width, y: shortLineY))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Half court line
            Path { path in
                path.move(to: CGPoint(x: halfCourtX, y: shortLineY))
                path.addLine(to: CGPoint(x: halfCourtX, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Left service box
            Path { path in
                path.move(to: CGPoint(x: 0, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: serviceBoxPixels, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: serviceBoxPixels, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Right service box
            Path { path in
                path.move(to: CGPoint(x: size.width, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: size.width - serviceBoxPixels, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: size.width - serviceBoxPixels, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Service box arcs
            Path { path in
                path.addArc(
                    center: CGPoint(x: halfCourtX, y: size.height),
                    radius: serviceBoxPixels,
                    startAngle: .degrees(180),
                    endAngle: .degrees(225),
                    clockwise: false
                )
            }
            .stroke(lineColor, lineWidth: lineWidth)

            Path { path in
                path.addArc(
                    center: CGPoint(x: halfCourtX, y: size.height),
                    radius: serviceBoxPixels,
                    startAngle: .degrees(0),
                    endAngle: .degrees(-45),
                    clockwise: true
                )
            }
            .stroke(lineColor, lineWidth: lineWidth)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - Wall Labels
    private func wallLabels(size: CGSize) -> some View {
        let labelColor = Color.white.opacity(0.9)
        let labelFont = Font.system(size: 10, weight: .semibold, design: .rounded)

        return ZStack {
            Text("FRONT WALL")
                .font(labelFont)
                .foregroundColor(labelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.7))
                .cornerRadius(4)
                .position(x: size.width / 2, y: 15)

            Text("BACK WALL")
                .font(labelFont)
                .foregroundColor(labelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.7))
                .cornerRadius(4)
                .position(x: size.width / 2, y: size.height - 15)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - Helper
    private func calculateCourtSize(availableWidth: CGFloat, availableHeight: CGFloat) -> CGSize {
        let widthBasedHeight = availableWidth / aspectRatio
        let heightBasedWidth = availableHeight * aspectRatio

        if widthBasedHeight <= availableHeight {
            return CGSize(width: availableWidth, height: widthBasedHeight)
        } else {
            return CGSize(width: heightBasedWidth, height: availableHeight)
        }
    }
}

// MARK: - Zone Tap Area

struct ZoneTapArea: View {
    let zone: CourtZone
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(isPressed ? 0.3 : 0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CourtView()
            .padding(20)
    }
}

#Preview("Interactive - Player Selected") {
    ZStack {
        Color.black.ignoresSafeArea()

        let game = Game()
        let _ = game.selectPlayer(.player1)

        CourtView(game: game) { zone in
            print("Tapped: \(zone)")
        }
        .padding(20)
    }
}
