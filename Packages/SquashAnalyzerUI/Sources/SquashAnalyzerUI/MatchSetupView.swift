import SwiftUI
import SquashAnalyzerCore

/// What the setup step hands to a new coach or referee match
public struct MatchSetupChoice: Equatable {
    public let player1Name: String
    public let player2Name: String
    public let player1Id: String?
    public let player2Id: String?
    public let startingServer: Player
    /// Games each player already won before the app was used ("Later instappen")
    public let player1GamesBefore: Int
    public let player2GamesBefore: Int
    /// Coaching focus of a picked player (empty otherwise)
    public let player1Focus: [String]
    public let player2Focus: [String]
}

/// The step before a new coach/referee match, like iOS' MatchStartView: two
/// names (each optionally picked from the player list, with that player's
/// focus shown), who serves first, and "Later instappen" with the games
/// already played. Picking a player and then editing the name away drops the
/// id again, same rule as iOS' `PickedPlayer`.
public struct MatchSetupView: View {
    let playerStore: any PlayerProfileStore
    let title: String
    let onCancel: (() -> Void)?
    let onStart: (MatchSetupChoice) -> Void

    @State private var players: [PlayerProfile] = []
    @State private var player1Name = ""
    @State private var player2Name = ""
    @State private var player1Pick: PlayerProfile? = nil
    @State private var player2Pick: PlayerProfile? = nil
    @State private var pickingSlot: Int? = nil
    @State private var server = Player.player1
    @State private var lateStart = false
    @State private var gamesBefore1 = 0
    @State private var gamesBefore2 = 0

    public init(playerStore: any PlayerProfileStore, title: String, onCancel: (() -> Void)? = nil,
                onStart: @escaping (MatchSetupChoice) -> Void) {
        self.playerStore = playerStore
        self.title = title
        self.onCancel = onCancel
        self.onStart = onStart
    }

    private var name1: String { resolvedName(player1Name, fallback: "Speler 1") }
    private var name2: String { resolvedName(player2Name, fallback: "Speler 2") }
    private var headStartIsValid: Bool { Match.isValidHeadStart(player1: gamesBefore1, player2: gamesBefore2) }

    public var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(SetupPalette.text)
                    .padding(.top, 8)

                playerRow(label: "Speler 1", name: $player1Name, slot: 1, focus: focus(player1Pick, currentName: player1Name))
                playerRow(label: "Speler 2", name: $player2Name, slot: 2, focus: focus(player2Pick, currentName: player2Name))

                serverPicker
                lateStartSection

                Button(action: start) {
                    Text("Start")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(SetupPalette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SetupPalette.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(lateStart && !headStartIsValid)

                if let onCancel {
                    Button("Terug", action: onCancel)
                        .foregroundColor(SetupPalette.muted)
                }
            }
            .padding(24)
        }
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

    private func playerRow(label: String, name: Binding<String>, slot: Int, focus: [String]) -> some View {
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
            if !focus.isEmpty {
                Text(focus.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundColor(SetupPalette.gold)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var serverPicker: some View {
        VStack(spacing: 10) {
            Text("Wie serveert eerst?")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(SetupPalette.muted)
            HStack(spacing: 10) {
                serverButton(Player.player1, name1)
                serverButton(Player.player2, name2)
            }
        }
    }

    private func serverButton(_ player: Player, _ name: String) -> some View {
        let selected = server == player
        return Button { server = player } label: {
            Text(name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundColor(selected ? SetupPalette.background : SetupPalette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? SetupPalette.orange : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) serveert eerst")
    }

    private var lateStartSection: some View {
        VStack(spacing: 12) {
            Button { lateStart.toggle() } label: {
                Text(lateStart ? "Later instappen ▴" : "Later instappen? ▾")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SetupPalette.muted)
            }
            .buttonStyle(.plain)
            if lateStart {
                Text("GAMES GEWONNEN")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(SetupPalette.gold)
                gamesRow(name1, value: gamesBefore1, onMinus: { gamesBefore1 = max(0, gamesBefore1 - 1) }, onPlus: { gamesBefore1 = min(2, gamesBefore1 + 1) })
                gamesRow(name2, value: gamesBefore2, onMinus: { gamesBefore2 = max(0, gamesBefore2 - 1) }, onPlus: { gamesBefore2 = min(2, gamesBefore2 + 1) })
                Text(headStartIsValid
                     ? "Start bij game \(1 + gamesBefore1 + gamesBefore2) · stand \(gamesBefore1) – \(gamesBefore2)"
                     : "Met deze stand is de wedstrijd al beslist")
                    .font(.system(size: 12))
                    .foregroundColor(SetupPalette.muted)
            }
        }
    }

    private func gamesRow(_ name: String, value: Int, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        HStack {
            Text(name)
                .foregroundColor(SetupPalette.text)
                .lineLimit(1)
            Spacer()
            Button(action: onMinus) { Text("−").font(.system(size: 22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(SetupPalette.gold)
                .accessibilityLabel("Minder games voor \(name)")
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(SetupPalette.text)
                .frame(width: 28)
            Button(action: onPlus) { Text("+").font(.system(size: 22, weight: .bold)).frame(width: 44, height: 36) }
                .buttonStyle(.plain)
                .foregroundColor(SetupPalette.gold)
                .accessibilityLabel("Meer games voor \(name)")
        }
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func start() {
        let late = lateStart && headStartIsValid
        onStart(MatchSetupChoice(
            player1Name: name1, player2Name: name2,
            player1Id: pickedId(player1Pick, currentName: player1Name), player2Id: pickedId(player2Pick, currentName: player2Name),
            startingServer: server,
            player1GamesBefore: late ? gamesBefore1 : 0, player2GamesBefore: late ? gamesBefore2 : 0,
            player1Focus: focus(player1Pick, currentName: player1Name), player2Focus: focus(player2Pick, currentName: player2Name)
        ))
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
        guard let pick, pick.name.trimmingCharacters(in: .whitespaces) == currentName.trimmingCharacters(in: .whitespaces) else { return nil }
        return pick.id
    }

    private func focus(_ pick: PlayerProfile?, currentName: String) -> [String] {
        guard let pick, pickedId(pick, currentName: currentName) != nil else { return [] }
        return pick.coachingFocusAreas
    }
}

private enum SetupPalette {
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let muted = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let orange = Color(red: 0.95, green: 0.55, blue: 0.15)
    static let background = Color(red: 0.06, green: 0.05, blue: 0.04)
}
