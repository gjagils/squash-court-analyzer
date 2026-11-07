import SwiftUI
import SquashAnalyzerCore

/// Asks once whether the example players still on this phone may go
/// (`SamplePlayerCleanup`). Shows nothing; with none of them the question is done.
public struct SamplePlayersQuestion: View {
    private let store: any PlayerProfileStore
    /// Something else is on screen first (the tour, "Nieuw in", a cover)
    private let waiting: Bool

    @AppStorage(SamplePlayerCleanup.doneKey) private var done = false
    @State private var found: [PlayerProfile] = []

    public init(store: any PlayerProfileStore, waiting: Bool = false) {
        self.store = store
        self.waiting = waiting
    }

    private var names: String {
        var list: [String] = []
        for player in found { list.append(player.name) }
        return list.joined(separator: ", ")
    }

    public var body: some View {
        Color.clear
            .frame(width: 0.0, height: 0.0)
            .task { await look() }
            .alert(loc("Voorbeeldspelers verwijderen?"), isPresented: Binding(get: { !found.isEmpty && !waiting }, set: { _ in })) {
                Button(loc("Behouden"), role: .cancel) {
                    done = true
                    found = []
                }
                Button(loc("Verwijderen"), role: .destructive) {
                    let players = found
                    done = true
                    found = []
                    Task { await remove(players) }
                }
            } message: {
                Text(loc("In je spelerslijst staan nog de voorbeeldspelers \(names). Die zijn alleen om te proberen. Je wedstrijden blijven bewaard."))
            }
    }

    private func look() async {
        guard !done else { return }
        // Not answered when the list cannot be read: the question comes back next time
        guard let players = try? await store.loadPlayers() else { return }
        found = SamplePlayerCleanup.found(in: players, team: TeamRoster.ids())
        if found.isEmpty { done = true }
    }

    private func remove(_ players: [PlayerProfile]) async {
        for player in players {
            try? await store.deletePlayer(player.id)
        }
    }
}
