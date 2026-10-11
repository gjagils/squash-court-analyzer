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
        // A disabled filled button is drawn as a quiet outlined one: light text on a
        // grey fill could not be read (on light it was white on grey)
        let filled = style == .filled && !disabled
        let outlined = style == .outlined || (style == .filled && disabled)
        let foreground = filled ? SharedColors.background : tint
        let fill = filled ? tint : (outlined ? tint.opacity(disabled ? 0.08 : 0.12) : Color.clear)
        let border = outlined ? tint.opacity(disabled ? 0.30 : 0.35) : Color.clear
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
                    // Two buttons side by side with large text on Android
                    // ("COACHKAART" ran into the edge): shrink rather than clip
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 8)
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
