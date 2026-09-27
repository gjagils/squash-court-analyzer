import SwiftUI
import SquashAnalyzerCore

/// One row per point type, shown right after a player is selected (score-tap
/// flow's step 2). `compact` matches the inline "middle of the screen" style.
public struct PointTypeButton: View {
    let pointType: PointType
    let color: Color
    var compact: Bool = false
    let action: () -> Void

    public init(pointType: PointType, color: Color, compact: Bool = false, action: @escaping () -> Void) {
        self.pointType = pointType
        self.color = color
        self.compact = compact
        self.action = action
    }

    @ViewBuilder
    private var icon: some View {
        if pointType == .stroke {
            FistIcon(color: color, size: 22)
        } else {
            Image(systemName: pointType.icon)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon.frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pointType.title.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.95, green: 0.93, blue: 0.90))
                        .tracking(0.5)
                    Text(pointType.description)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.70, green: 0.68, blue: 0.65))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, compact ? 9.0 : 14.0)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The referee's stroke signal is a closed fist; SF Symbols has none, so the
/// ✊ emoji is tinted instead.
struct FistIcon: View {
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Text("✊")
            .font(.system(size: size * 0.92))
            .grayscale(1)
            .brightness(0.12)
            .colorMultiply(color)
            .frame(width: size, height: size)
    }
}
