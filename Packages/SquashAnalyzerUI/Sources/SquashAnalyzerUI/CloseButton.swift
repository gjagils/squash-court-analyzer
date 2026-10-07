import SwiftUI

/// "✕ Sluiten" as on Spelers: the one close button of the app (also for
/// "Annuleren"), on iPhone and Android. Grey text, no capsule. In a sheet's
/// toolbar it goes in `ToolbarItem(placement: .cancellationAction)`.
public struct CloseButton: View {
    let title: String
    let action: () -> Void

    public init(title: String = "Sluiten", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                AppSymbol("xmark", size: 14, color: SharedColors.textSecondary)
                Text(title)
            }
            .font(SharedFonts.system(14, weight: .medium, design: .rounded))
            .foregroundColor(SharedColors.textSecondary)
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
