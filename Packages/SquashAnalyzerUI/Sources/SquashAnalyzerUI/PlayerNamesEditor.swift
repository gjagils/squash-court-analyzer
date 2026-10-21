import SwiftUI
import SquashAnalyzerCore

/// Correcting the two names during a match (Gerd-Jan, 21 October 2026): a
/// typo, or the real names after a quick start with "Speler 1". Shared by
/// the coach and the referee screen; the caller applies the names to its
/// match (`Match.rename`, `RefereeMatch.rename`) and saves. The fields look
/// like the ones of the match setup.
struct PlayerNamesEditor: View {
    let player1Name: String
    let player2Name: String
    /// Picked from Spelers: another name drops the link (as in the setup), so the sheet says so
    let player1Linked: Bool
    let player2Linked: Bool
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    @State private var name1 = ""
    @State private var name2 = ""

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Namen aanpassen", bundle: textBundle)
                    .font(SharedFonts.system(20, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text("De namen gelden voor deze wedstrijd, ook voor wie live meekijkt. De stand blijft staan.", bundle: textBundle)
                    .font(SharedFonts.system(13))
                    .foregroundColor(SharedColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                nameField(label: loc("Speler 1"), name: $name1, color: SharedColors.accent)
                nameField(label: loc("Speler 2"), name: $name2, color: SharedColors.steelBlue)
                if player1Linked || player2Linked {
                    Text("Een speler uit Spelers blijft gekoppeld zolang de naam dezelfde is. Een andere naam is een andere speler: badges en profiel tellen deze wedstrijd dan niet voor de gekozen speler.", bundle: textBundle)
                        .font(SharedFonts.system(12))
                        .foregroundColor(SharedColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 12) {
                    ActionButton(loc("ANNULEREN"), style: .outlined, color: SharedColors.textSecondary) { onCancel() }
                    ActionButton(loc("BEWAAR"), style: .filled, color: SharedColors.accent) {
                        // Empty is the default name in the app's language, as in the setup
                        onSave(resolved(name1, fallback: loc("Speler 1")), resolved(name2, fallback: loc("Speler 2")))
                    }
                }
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(SharedColors.preferredScheme)
        .onAppear {
            name1 = player1Name
            name2 = player2Name
        }
    }

    private func nameField(label: String, name: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(SharedFonts.system(11, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundColor(color)
            TextField(loc("Naam \(label.lowercased())"), text: name)
                .accessibilityLabel(label)
                .textFieldStyle(.plain)
                .font(SharedFonts.system(17))
                .padding()
                .background(SharedColors.tint(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
                .foregroundColor(SharedColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func resolved(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
