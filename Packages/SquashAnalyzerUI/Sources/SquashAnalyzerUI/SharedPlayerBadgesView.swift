import SwiftUI
import SquashAnalyzerCore

/// A player's badges on Android, like iOS' PlayerBadgesView: how many earned,
/// every badge of the catalogue (earned in colour with a count, the rest grey
/// with how to earn it), and per earned badge the moments it was earned, which
/// can be deleted. Named `Shared...` because the iOS app target has its own
/// `PlayerBadgesView`.
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

    @State private var moments: [BadgeMoment] = []
    @State private var isLoading = true
    @State private var shareFailed = false
    @State private var openBadge: BadgeKind? = nil
    @State private var deleting: BadgeMoment? = nil
    @State private var confirmDelete = false

    public init(playerId: String, playerName: String, badgeStore: any PlayerBadgeSummaryStore,
                shareText: @escaping (String) -> Void, cardInbox: CardInbox) {
        self.playerId = playerId
        self.playerName = playerName
        self.badgeStore = badgeStore
        self.shareText = shareText
        self.cardInbox = cardInbox
    }

    private func count(_ badge: BadgeKind) -> Int {
        var result = 0
        for moment in moments where moment.badge == badge {
            result += 1
        }
        return result
    }

    private var earnedKinds: Int {
        var result = 0
        for kind in BadgeKind.allCases where count(kind) > 0 {
            result += 1
        }
        return result
    }

    public var body: some View {
        ZStack {
            BadgePalette.backgroundDark.ignoresSafeArea()
            if isLoading {
                ProgressView("Badges laden…").foregroundColor(BadgePalette.textPrimary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(moments.isEmpty ? "Nog geen badges verdiend" : "\(moments.count) badges verdiend")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(BadgePalette.textPrimary)
                        if moments.isEmpty {
                            Text("Kies \(playerName) via \"Kies speler\" bij een coach- of scheidsrechterwedstrijd om badges te verdienen.")
                                .font(.system(size: 13))
                                .foregroundColor(BadgePalette.textSecondary)
                        }
                        Text("BADGES · \(earnedKinds) VAN \(BadgeKind.allCases.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(BadgePalette.gold)
                        ForEach(BadgeKind.allCases) { kind in
                            badgeRow(kind)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            if let badge = openBadge {
                momentsOverlay(badge)
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
        .alert("Verdienmoment verwijderen?", isPresented: $confirmDelete) {
            Button("Annuleren", role: .cancel) { deleting = nil }
            Button("Verwijder", role: .destructive) {
                if let moment = deleting { remove(moment) }
            }
        } message: {
            Text("Deze badge telt dan niet meer mee. De verwijdering gaat mee in de volgende kaart die je deelt.")
        }
        .task(id: cardInbox.importCount) { await load() }
    }

    private func badgeRow(_ kind: BadgeKind) -> some View {
        let earned = count(kind)
        return Button { if earned > 0 { openBadge = kind } } label: {
            HStack(spacing: 14) {
                BadgeMedallion(kind: kind, size: 52, showsTitle: false, isLocked: earned == 0)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(earned > 0 ? BadgePalette.textPrimary : BadgePalette.textMuted)
                    Text(kind.detail)
                        .font(.system(size: 12))
                        .foregroundColor(BadgePalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if earned > 0 {
                    Text("×\(earned)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(BadgePalette.gold)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(earned > 0 ? 0.06 : 0.02)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), \(earned > 0 ? "\(earned) keer verdiend" : "nog niet verdiend")")
    }

    private func momentsOverlay(_ badge: BadgeKind) -> some View {
        var list: [BadgeMoment] = []
        for moment in moments where moment.badge == badge {
            list.append(moment)
        }
        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                BadgeMedallion(kind: badge, size: 72, showsTitle: false)
                Text(badge.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(BadgePalette.textPrimary)
                ForEach(list) { moment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(moment.opponentName.isEmpty ? "Verdiend" : "Tegen \(moment.opponentName)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(BadgePalette.textPrimary)
                            Text(Self.dateText(moment.earnedAt))
                                .font(.system(size: 12))
                                .foregroundColor(BadgePalette.textSecondary)
                        }
                        Spacer()
                        Button("Verwijder") {
                            deleting = moment
                            confirmDelete = true
                        }
                        .foregroundColor(Color(red: 0.90, green: 0.40, blue: 0.35))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                }
                Button("Sluiten") { openBadge = nil }
                    .foregroundColor(BadgePalette.textSecondary)
                    .padding(.top, 4)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(BadgePalette.backgroundDark))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(BadgePalette.gold.opacity(0.4), lineWidth: 1))
            .padding(24)
        }
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: date)
    }

    private func remove(_ moment: BadgeMoment) {
        deleting = nil
        Task {
            try? await badgeStore.deleteMoment(moment.id)
            await load()
            if let badge = openBadge, count(badge) == 0 { openBadge = nil }
        }
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
        isLoading = moments.isEmpty
        moments = (try? await badgeStore.moments(forPlayer: playerId)) ?? []
        isLoading = false
    }
}
