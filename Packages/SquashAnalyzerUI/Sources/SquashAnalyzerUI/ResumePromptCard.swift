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
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Wedstrijd hervatten?")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(CoachPalette.textPrimary)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(CoachPalette.textSecondary)
                    .multilineTextAlignment(.center)
                button("Hervatten", CoachPalette.warmOrange, action: onResume)
                button("Nieuwe wedstrijd", CoachPalette.warmRed, action: onNew)
                Button("Annuleren", action: onCancel)
                    .foregroundColor(CoachPalette.textSecondary)
            }
            .padding(24)
            .background(CoachPalette.backgroundMedium)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(CoachPalette.warmOrange.opacity(0.4), lineWidth: 1))
            .padding(24)
        }
    }

    private func button(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
