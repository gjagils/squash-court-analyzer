import SwiftUI
import SquashAnalyzerCore

/// A player's earned badges. Named `Shared...` (not `PlayerBadgesView`)
/// because the iOS app target already has its own, richer `PlayerBadgesView`
/// (earning moments, card sharing) — the two must not collide once both are
/// in scope via `import SquashAnalyzerUI`, same reason as
/// `SharedBadgeCatalogView`. Career badges are not shown here yet: they need
/// cross-match history, which the Android history browser doesn't have yet.
///
/// "Deel kaart" sends the card as a snapshot link
/// (`https://squashanalyzer.com/kaart/#…`), the same link iOS shares, through
/// `shareText` (the platform's share sheet).
public struct SharedPlayerBadgesView: View {
    let playerId: String
    let playerName: String
    let badgeStore: any PlayerBadgeSummaryStore
    let shareText: (String) -> Void
    /// Reloads after a card link was imported while this screen was open
    let cardInbox: CardInbox

    @State private var badges: [BadgeKind] = []
    @State private var isLoading = true
    @State private var shareFailed = false

    public init(playerId: String, playerName: String, badgeStore: any PlayerBadgeSummaryStore,
                shareText: @escaping (String) -> Void, cardInbox: CardInbox) {
        self.playerId = playerId
        self.playerName = playerName
        self.badgeStore = badgeStore
        self.shareText = shareText
        self.cardInbox = cardInbox
    }

    public var body: some View {
        ZStack {
            BadgePalette.backgroundDark.ignoresSafeArea()
            if isLoading {
                ProgressView("Badges laden…").foregroundColor(BadgePalette.textPrimary)
            } else if badges.isEmpty {
                VStack(spacing: 12) {
                    AppSymbol("medal", size: 48, color: BadgePalette.textSecondary)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await shareCard() } } label: {
                    Label("Deel kaart", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Deel kaart")
                .disabled(isLoading)
            }
        }
        .alert("Delen lukt niet", isPresented: $shareFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("De kaart van \(playerName) kon niet worden gemaakt.")
        }
        .task(id: cardInbox.importCount) { await load() }
    }

    private func shareCard() async {
        do {
            guard let snapshot = try await badgeStore.cardSnapshot(forPlayer: playerId) else {
                shareFailed = true
                return
            }
            let url = try snapshot.webURL()
            shareText("Badgekaart van \(snapshot.name): \(url.absoluteString)")
        } catch {
            shareFailed = true
        }
    }

    private func load() async {
        isLoading = true
        badges = (try? await badgeStore.badges(forPlayer: playerId)) ?? []
        isLoading = false
    }
}
