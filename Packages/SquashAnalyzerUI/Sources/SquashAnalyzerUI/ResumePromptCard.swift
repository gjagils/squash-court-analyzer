import SwiftUI

/// "Wedstrijd hervatten?" when the Coach or Scheidsrechter tile is tapped with
/// an unfinished match: the same question, text and buttons as iOS' alert
/// (Core's `resumeMessage`). A card instead of an alert, because on Android an
/// alert clears its state before the button's action runs.
struct ResumePromptCard: View {
    let message: String
    let onResume: () -> Void
    let onNew: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            SharedColors.background.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Wedstrijd hervatten?")
                    .font(SharedFonts.system(18, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text(message)
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .multilineTextAlignment(.center)
                button("Hervatten", SharedColors.accent, action: onResume)
                button("Nieuwe wedstrijd", SharedColors.warmRed, action: onNew)
                Button("Annuleren", action: onCancel)
                    .foregroundColor(SharedColors.textSecondary)
            }
            .padding(24)
            .background(SharedColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(SharedColors.accent.opacity(0.4), lineWidth: 1))
            .padding(24)
        }
    }

    private func button(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        ActionButton(title, color: color, action: action)
    }
}
