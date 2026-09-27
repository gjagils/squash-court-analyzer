import SwiftUI
import SquashAnalyzerCore

/// A player's earned badges. Named `Shared...` (not `PlayerBadgesView`)
/// because the iOS app target already has its own, richer `PlayerBadgesView`
/// (earning moments, card sharing) — the two must not collide once both are
/// in scope via `import SquashAnalyzerUI`, same reason as
/// `SharedBadgeCatalogView`. Career badges are not shown here yet: they need
/// cross-match history, which the Android history browser doesn't have yet.
public struct SharedPlayerBadgesView: View {
    let playerId: String
    let playerName: String
    let badgeStore: any PlayerBadgeSummaryStore

    @State private var badges: [BadgeKind] = []
    @State private var isLoading = true

    public init(playerId: String, playerName: String, badgeStore: any PlayerBadgeSummaryStore) {
        self.playerId = playerId
        self.playerName = playerName
        self.badgeStore = badgeStore
    }

    public var body: some View {
        ZStack {
            BadgePalette.backgroundDark.ignoresSafeArea()
            if isLoading {
                ProgressView("Badges laden…").foregroundColor(BadgePalette.textPrimary)
            } else if badges.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "medal").font(.system(size: 48))
                    Text("Nog geen badges verdiend").font(.headline)
                    Text("Kies \(playerName) via \"Kies speler\" bij een coach- of scheidsrechterwedstrijd om badges te verdienen.")
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(BadgePalette.textSecondary)
                .padding(24)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 16) {
                        ForEach(badges) { badge in
                            BadgeMedallion(kind: badge, size: 64)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(playerName)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        badges = (try? await badgeStore.badges(forPlayer: playerId)) ?? []
        isLoading = false
    }
}
