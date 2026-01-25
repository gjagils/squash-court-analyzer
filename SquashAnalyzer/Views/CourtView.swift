import SwiftUI

struct CourtView: View {
    // Court dimensions in meters (official squash court)
    private let courtWidth: CGFloat = 6.4   // meters (21 feet)
    private let courtLength: CGFloat = 9.75 // meters (32 feet)
    private let serviceBoxSize: CGFloat = 1.6 // meters (63 inches)
    private let shortLineDistance: CGFloat = 5.44 // meters from front wall (17.85 feet)

    // Computed ratio for proper scaling
    private var aspectRatio: CGFloat {
        courtWidth / courtLength
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

                // Court markings
                courtMarkings(size: courtSize, scale: scale)

                // Wall labels
                wallLabels(size: courtSize)
            }
            .frame(width: courtSize.width, height: courtSize.height)
            .position(x: availableWidth / 2, y: availableHeight / 2)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Court Floor
    private func courtFloor(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.76, green: 0.60, blue: 0.42), // Lighter wood
                        Color(red: 0.68, green: 0.52, blue: 0.34)  // Darker wood
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                // Wood grain effect
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
                // Court border (walls)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red.opacity(0.8), lineWidth: 4)
            )
            .frame(width: size.width, height: size.height)
    }

    // MARK: - Court Markings
    private func courtMarkings(size: CGSize, scale: CGFloat) -> some View {
        let lineColor = Color.red.opacity(0.9)
        let lineWidth: CGFloat = 2

        // Calculate positions
        let shortLineY = shortLineDistance * scale // Distance from top (front wall)
        let halfCourtX = size.width / 2
        let serviceBoxPixels = serviceBoxSize * scale

        return ZStack {
            // Short line (horizontal line dividing front and back)
            Path { path in
                path.move(to: CGPoint(x: 0, y: shortLineY))
                path.addLine(to: CGPoint(x: size.width, y: shortLineY))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Half court line (vertical line in back area)
            Path { path in
                path.move(to: CGPoint(x: halfCourtX, y: shortLineY))
                path.addLine(to: CGPoint(x: halfCourtX, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Left service box
            Path { path in
                // Bottom-left corner box
                path.move(to: CGPoint(x: 0, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: serviceBoxPixels, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: serviceBoxPixels, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Right service box
            Path { path in
                // Bottom-right corner box
                path.move(to: CGPoint(x: size.width, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: size.width - serviceBoxPixels, y: size.height - serviceBoxPixels))
                path.addLine(to: CGPoint(x: size.width - serviceBoxPixels, y: size.height))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Service box quarter circles (the curved lines inside service boxes)
            // Left service box arc
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

            // Right service box arc
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
    }

    // MARK: - Wall Labels
    private func wallLabels(size: CGSize) -> some View {
        let labelColor = Color.white.opacity(0.9)
        let labelFont = Font.system(size: 10, weight: .semibold, design: .rounded)

        return ZStack {
            // Front wall label (top)
            Text("FRONT WALL")
                .font(labelFont)
                .foregroundColor(labelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.7))
                .cornerRadius(4)
                .position(x: size.width / 2, y: 15)

            // Back wall label (bottom)
            Text("BACK WALL")
                .font(labelFont)
                .foregroundColor(labelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.7))
                .cornerRadius(4)
                .position(x: size.width / 2, y: size.height - 15)

            // Short line label
            Text("Short Line")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color.red.opacity(0.7))
                .position(x: size.width - 35, y: (shortLineDistance / courtLength) * size.height - 10)

            // Service box labels
            Text("Service")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color.red.opacity(0.7))
                .position(x: 30, y: size.height - 30)

            Text("Service")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color.red.opacity(0.7))
                .position(x: size.width - 30, y: size.height - 30)
        }
        .frame(width: size.width, height: size.height)
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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CourtView()
            .padding(20)
    }
}
