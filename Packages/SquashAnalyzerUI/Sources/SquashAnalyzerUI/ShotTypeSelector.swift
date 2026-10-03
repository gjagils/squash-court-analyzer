import SwiftUI
import SquashAnalyzerCore

enum ShotPalette {
    static let warmOrange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let steelBlue = Color(red: 0.35, green: 0.45, blue: 0.55)
    static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let textSecondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let backgroundMedium = Color(red: 0.12, green: 0.10, blue: 0.08)
}

/// Public so both the shared coach flow and CoachScoring.swift can reuse it.
public struct ShotTypeButton: View {
    let shotType: ShotType
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    public init(shotType: ShotType, color: Color, action: @escaping () -> Void) {
        self.shotType = shotType
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                action()
                withAnimation(.easeOut(duration: 0.2)) { isPressed = false }
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    if isPressed {
                        ShotIconView(type: shotType, color: color, size: 28)
                            .blur(radius: 8)
                            .opacity(0.7)
                    }
                    ShotIconView(type: shotType, color: isPressed ? color : ShotPalette.textPrimary, size: 28)
                }
                .frame(height: 32)

                Text(shotType.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isPressed ? color : ShotPalette.textSecondary)
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
                    .stroke(isPressed ? color.opacity(0.7) : Color.white.opacity(0.1), lineWidth: isPressed ? 2.0 : 1.0)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct ShotIconView: View {
    let type: ShotType
    var color: Color = ShotPalette.textPrimary
    var size: CGFloat = 28

    /// SF Symbols draw smaller than their font size; Material icons fill their box
    private var symbolSize: CGFloat {
        #if SKIP
        return size * 0.85
        #else
        return size * 0.7
        #endif
    }

    var body: some View {
        switch type {
        case .drive:
            DriveIcon(color: color, size: size)
        case .cross:
            AppSymbol("arrow.left.and.right", size: symbolSize, color: color, weight: .medium)
        case .volley:
            AppSymbol("bolt.fill", size: symbolSize, color: color, weight: .medium)
        case .drop:
            AppSymbol("arrow.down.to.line", size: symbolSize, color: color, weight: .medium)
        case .lob:
            LobIcon(color: color, size: size)
        case .boast:
            BoastIcon(color: color, size: size)
        case .kill:
            KillIcon(color: color, size: size)
        }
    }
}

/// Vertical arrow, top to bottom (was a `Canvas` drawing; see file header).
struct DriveIcon: View {
    var color: Color = ShotPalette.textPrimary
    var size: CGFloat = 40

    var body: some View {
        let w = size, h = size
        Path { path in
            path.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.9))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.65))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

/// Kill: a steep arrow driven down to just above the tin (the short line)
struct KillIcon: View {
    var color: Color = ShotPalette.textPrimary
    var size: CGFloat = 40

    var body: some View {
        let w = size, h = size
        Path { path in
            path.move(to: CGPoint(x: w * 0.22, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.74))
            path.move(to: CGPoint(x: w * 0.40, y: h * 0.66))
            path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.74))
            path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.51))
            path.move(to: CGPoint(x: w * 0.18, y: h * 0.88))
            path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.88))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .frame(width: size, height: size)
    }
}

/// Arc rising then curving down, with an open arrowhead (was `Canvas`).
struct LobIcon: View {
    var color: Color = ShotPalette.textPrimary
    var size: CGFloat = 40

    var body: some View {
        let w = size, h = size
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: w * 0.10, y: h * 0.65))
                path.addCurve(
                    to: CGPoint(x: w * 0.78, y: h * 0.82),
                    control1: CGPoint(x: w * 0.20, y: h * -0.10),
                    control2: CGPoint(x: w * 0.55, y: h * 0.15)
                )
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            Path { arrowHead in
                arrowHead.move(to: CGPoint(x: w * 0.58, y: h * 0.68))
                arrowHead.addLine(to: CGPoint(x: w * 0.78, y: h * 0.82))
                arrowHead.addLine(to: CGPoint(x: w * 0.82, y: h * 0.58))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// Ball bouncing off the side wall then the front wall (was `Canvas`).
struct BoastIcon: View {
    var color: Color = ShotPalette.textPrimary
    var size: CGFloat = 40

    var body: some View {
        let w = size, h = size
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: w * 0.55, y: h * 0.9))
                path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.17))
                path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.15))
                path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.55))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            Path { arrowHead in
                arrowHead.move(to: CGPoint(x: w * 0.72, y: h * 0.42))
                arrowHead.addLine(to: CGPoint(x: w * 0.92, y: h * 0.55))
                arrowHead.addLine(to: CGPoint(x: w * 0.95, y: h * 0.32))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}
