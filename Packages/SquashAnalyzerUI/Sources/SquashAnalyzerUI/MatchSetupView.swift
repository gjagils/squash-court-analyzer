import SwiftUI
import SquashAnalyzerCore

/// Minimal "Kies speler" step before a new coach/referee match starts. Much
/// smaller than iOS' full `MatchStartView`: just two names, each optionally
/// picked from the existing player list, no head-start/coaching-focus setup.
/// Picking a player and then editing the name away drops the id again, same
/// rule as iOS' `PickedPlayer`.
public struct MatchSetupView: View {
    let playerStore: any PlayerProfileStore
    let title: String
    let onCancel: (() -> Void)?
    let onStart: (_ player1Name: String, _ player2Name: String, _ player1Id: String?, _ player2Id: String?) -> Void

    @State private var players: [PlayerProfile] = []
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var player1Pick: PlayerProfile? = nil
    @State private var player2Pick: PlayerProfile? = nil
    @State private var pickingSlot: Int? = nil

    public init(playerStore: any PlayerProfileStore, title: String, onCancel: (() -> Void)? = nil,
                onStart: @escaping (_ player1Name: String, _ player2Name: String, _ player1Id: String?, _ player2Id: String?) -> Void) {
        self.playerStore = playerStore
        self.title = title
        self.onCancel = onCancel
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(SetupPalette.text)

            playerRow(label: "Speler 1", name: $player1Name, slot: 1)
            playerRow(label: "Speler 2", name: $player2Name, slot: 2)

            Button("Start") {
                onStart(resolvedName(player1Name, fallback: "Speler 1"), resolvedName(player2Name, fallback: "Speler 2"),
                        pickedId(player1Pick, currentName: player1Name), pickedId(player2Pick, currentName: player2Name))
            }
            .buttonStyle(.borderedProminent)

            if let onCancel {
                Button("Terug", action: onCancel)
                    .foregroundColor(SetupPalette.muted)
            }
        }
        .padding(24)
        .task { players = (try? await playerStore.loadPlayers()) ?? [] }
        .sheet(isPresented: pickerIsPresented) {
            NavigationStack {
                List(players) { player in
                    Button(player.name) { pick(player) }
                        .foregroundColor(SetupPalette.text)
                }
                .navigationTitle("Kies speler")
            }
        }
    }

    private func playerRow(label: String, name: Binding<String>, slot: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1)
                .foregroundColor(SetupPalette.gold)
            HStack(spacing: 8) {
                TextField(label, text: name)
                    .accessibilityLabel(label)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(SetupPalette.text)
                Button("Kies speler") { pickingSlot = slot }
                    .disabled(players.isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(get: { pickingSlot != nil }, set: { if !$0 { pickingSlot = nil } })
    }

    private func pick(_ player: PlayerProfile) {
        if pickingSlot == 1 { player1Pick = player; player1Name = player.name }
        else if pickingSlot == 2 { player2Pick = player; player2Name = player.name }
        pickingSlot = nil
    }

    private func resolvedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// Only counts while the current text still matches the picked name.
    private func pickedId(_ pick: PlayerProfile?, currentName: String) -> String? {
        guard let pick else { return nil }
        return pick.name.trimmingCharacters(in: .whitespaces) == currentName.trimmingCharacters(in: .whitespaces) ? pick.id : nil
    }
}

private enum SetupPalette {
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let muted = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
}
