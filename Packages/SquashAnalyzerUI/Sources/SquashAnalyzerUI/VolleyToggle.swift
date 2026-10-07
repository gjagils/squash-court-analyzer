import SwiftUI
import SquashAnalyzerCore

/// "Uit de lucht": the volley switch above the shot buttons (iOS and Android).
/// A volley is no longer a shot of its own but goes with one (volley drop,
/// volley kill, …); never with a lob, which `Game.addPoint` enforces.
public struct VolleyToggle: View {
    @Binding var isOn: Bool
    let color: Color

    public init(isOn: Binding<Bool>, color: Color) {
        _isOn = isOn
        self.color = color
    }

    public var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                AppSymbol("bolt.fill", size: 14, color: isOn ? Color.black.opacity(0.8) : color)
                Text("UIT DE LUCHT")
                    .font(SharedFonts.system(12, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(isOn ? Color.black.opacity(0.8) : color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOn ? color : color.opacity(0.10))
                    .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Uit de lucht, aan" : "Uit de lucht, uit")
    }
}
