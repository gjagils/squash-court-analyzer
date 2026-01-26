import SwiftUI

/// App icon design - can be used to generate the app icon
/// Screenshot this view at 1024x1024 for the App Store icon
struct AppIconView: View {
    let size: CGFloat

    init(size: CGFloat = 1024) {
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15),
                            Color(red: 0.05, green: 0.05, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Stylized court
            courtShape
                .offset(y: size * 0.05)

            // Squash ball
            squashBall
                .offset(x: size * 0.15, y: -size * 0.12)

            // Motion lines behind ball
            motionLines
                .offset(x: size * 0.08, y: -size * 0.08)
        }
        .frame(width: size, height: size)
    }

    private var courtShape: some View {
        ZStack {
            // Court floor
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.76, green: 0.60, blue: 0.42),
                            Color(red: 0.58, green: 0.42, blue: 0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.5, height: size * 0.65)

            // Court lines
            courtLines
        }
    }

    private var courtLines: some View {
        let lineColor = Color.red.opacity(0.9)
        let lineWidth = size * 0.012
        let courtWidth = size * 0.5
        let courtHeight = size * 0.65

        return ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: size * 0.02)
                .stroke(lineColor, lineWidth: lineWidth * 1.5)
                .frame(width: courtWidth, height: courtHeight)

            // Short line (horizontal)
            Rectangle()
                .fill(lineColor)
                .frame(width: courtWidth - lineWidth, height: lineWidth)
                .offset(y: courtHeight * 0.06)

            // Half court line (vertical, bottom half)
            Rectangle()
                .fill(lineColor)
                .frame(width: lineWidth, height: courtHeight * 0.44)
                .offset(y: courtHeight * 0.28)

            // Service box left
            Path { path in
                let boxSize = courtWidth * 0.25
                path.move(to: CGPoint(x: -courtWidth/2, y: courtHeight/2 - boxSize))
                path.addLine(to: CGPoint(x: -courtWidth/2 + boxSize, y: courtHeight/2 - boxSize))
                path.addLine(to: CGPoint(x: -courtWidth/2 + boxSize, y: courtHeight/2))
            }
            .stroke(lineColor, lineWidth: lineWidth)

            // Service box right
            Path { path in
                let boxSize = courtWidth * 0.25
                path.move(to: CGPoint(x: courtWidth/2, y: courtHeight/2 - boxSize))
                path.addLine(to: CGPoint(x: courtWidth/2 - boxSize, y: courtHeight/2 - boxSize))
                path.addLine(to: CGPoint(x: courtWidth/2 - boxSize, y: courtHeight/2))
            }
            .stroke(lineColor, lineWidth: lineWidth)
        }
    }

    private var squashBall: some View {
        let ballSize = size * 0.22

        return ZStack {
            // Ball shadow
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: ballSize, height: ballSize)
                .offset(x: size * 0.015, y: size * 0.015)
                .blur(radius: size * 0.02)

            // Ball base
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.1),
                            Color(red: 0.05, green: 0.05, blue: 0.05)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: ballSize
                    )
                )
                .frame(width: ballSize, height: ballSize)

            // Ball highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0)
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: ballSize * 0.5
                    )
                )
                .frame(width: ballSize, height: ballSize)

            // Yellow dot (competition ball indicator)
            Circle()
                .fill(Color.yellow)
                .frame(width: ballSize * 0.2, height: ballSize * 0.2)
                .offset(x: ballSize * 0.15, y: ballSize * 0.1)
        }
    }

    private var motionLines: some View {
        let lineColor = Color.white.opacity(0.6)

        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(lineColor.opacity(0.8 - Double(i) * 0.25))
                    .frame(width: size * (0.08 - Double(i) * 0.015), height: size * 0.015)
                    .offset(
                        x: -size * (0.12 + Double(i) * 0.06),
                        y: size * (0.02 + Double(i) * 0.03)
                    )
                    .rotationEffect(.degrees(-25))
            }
        }
    }
}

// MARK: - Preview

#Preview("App Icon 1024x1024") {
    AppIconView(size: 1024)
        .frame(width: 1024, height: 1024)
}

#Preview("App Icon Preview (300pt)") {
    VStack(spacing: 20) {
        AppIconView(size: 300)

        Text("SquashAnalyzer")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.white)
    }
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("App Icon Sizes") {
    HStack(spacing: 20) {
        VStack {
            AppIconView(size: 60)
            Text("60pt")
                .font(.caption)
        }
        VStack {
            AppIconView(size: 120)
            Text("120pt")
                .font(.caption)
        }
        VStack {
            AppIconView(size: 180)
            Text("180pt")
                .font(.caption)
        }
    }
    .padding()
}
