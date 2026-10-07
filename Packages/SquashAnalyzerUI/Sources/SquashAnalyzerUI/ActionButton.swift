import SwiftUI

/// The one button of the shared screens (T17): full width, 12 pt corners, the
/// same height and font everywhere, in three styles from the style guide.
/// A view, not a ButtonStyle: SkipUI does not support custom button styles
/// reliably. Big functional tiles (score, LET/STROKE, server choice) keep
/// their own look.
public struct ActionButton: View {
    public enum Style {
        /// Solid colour with dark text: the main action of a screen
        case filled
        /// 12% tint with a thin border and coloured text: everything else
        case outlined
        /// Text only: a way out ("Sluiten zonder opslaan")
        case text
    }

    let title: String
    let icon: String?
    let style: Style
    let color: Color
    let disabled: Bool
    let action: () -> Void

    public static let font = SharedFonts.system(14, weight: .semibold, design: .rounded)

    public init(_ title: String, icon: String? = nil, style: Style = .outlined, color: Color = SharedColors.accent,
                disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.color = color
        self.disabled = disabled
        self.action = action
    }

    public var body: some View {
        let tint = disabled ? SharedColors.textMuted : color
        let foreground = style == .filled ? SharedColors.background : tint
        let fill = style == .filled ? tint : (style == .outlined ? tint.opacity(disabled ? 0.04 : 0.12) : Color.clear)
        let border = style == .outlined ? tint.opacity(disabled ? 0.10 : 0.35) : Color.clear
        return Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    AppSymbol(icon, size: 13, color: foreground, weight: .semibold)
                }
                Text(title)
                    .font(ActionButton.font)
                    .tracking(1)
                    .foregroundColor(foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            // .background(colour) + clipShape: filled shapes behind text misbehave on Android
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
