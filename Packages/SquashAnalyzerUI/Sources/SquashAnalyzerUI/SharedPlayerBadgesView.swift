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
    /// The player's photo for the header; nil shows the initial
    let photo: Data?
    let badgeStore: any PlayerBadgeSummaryStore
    let shareText: (String) -> Void
    /// Shares the card as a picture plus the link (Android draws the picture); nil shares the link only
    let cardPicture: ((CardSnapshot, String) -> Void)?
    /// Reloads after a card link was imported while this screen was open
    let cardInbox: CardInbox

    @State private var moments: [BadgeMoment] = []
    @State private var isLoading = true
    @State private var shareFailed = false

    public init(playerId: String, playerName: String, photo: Data? = nil, badgeStore: any PlayerBadgeSummaryStore,
                shareText: @escaping (String) -> Void, shareCard: ((CardSnapshot, String) -> Void)? = nil, cardInbox: CardInbox) {
        self.playerId = playerId
        self.playerName = playerName
        self.photo = photo
        self.badgeStore = badgeStore
        self.shareText = shareText
        self.cardPicture = shareCard
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
            SharedColors.background.ignoresSafeArea()
            if isLoading {
                ProgressView("Badges laden…").foregroundColor(SharedColors.textPrimary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        section("BADGES · \(earnedKinds) VAN \(BadgeKind.allCases.count)") {
                            // Rows of three, not a LazyVGrid: on Android that becomes a
                            // scroll area of its own inside the page
                            VStack(spacing: 18) {
                                ForEach(0..<Self.rowCount, id: \.self) { row in
                                    badgeRow(row)
                                }
                            }
                        }
                        section("DELEN") {
                            ActionButton("DEEL KAART", icon: "square.and.arrow.up", style: .filled, color: SharedColors.gold) {
                                Task { await shareCard() }
                            }
                            .accessibilityLabel("Deel kaart")
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
        }
        .pageTitle(playerName)
        .alert("Delen lukt niet", isPresented: $shareFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("De kaart van \(playerName) kon niet worden gemaakt.")
        }
        .task(id: cardInbox.importCount) { await load() }
    }

    private static var rowCount: Int { (BadgeKind.allCases.count + 2) / 3 }

    private func badgeRow(_ row: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            gridCell(row * 3)
            gridCell(row * 3 + 1)
            gridCell(row * 3 + 2)
        }
    }

    @ViewBuilder
    private func gridCell(_ index: Int) -> some View {
        if index < BadgeKind.allCases.count {
            let kind = BadgeKind.allCases[index]
            NavigationLink {
                SharedBadgeMomentsView(kind: kind, moments: moments(of: kind)) { moment in remove(moment) }
            } label: {
                badgeTile(kind)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(kind.title), \(count(kind) > 0 ? "\(count(kind)) keer verdiend" : "nog niet verdiend")")
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }

    private func moments(of kind: BadgeKind) -> [BadgeMoment] {
        var list: [BadgeMoment] = []
        for moment in moments where moment.badge == kind {
            list.append(moment)
        }
        return list
    }

    private var header: some View {
        HStack(spacing: 14) {
            PlayerAvatarPlaceholder(color: SharedColors.gold, size: 52, photo: photo)
            VStack(alignment: .leading, spacing: 4) {
                Text(playerName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                Text(moments.count == 1 ? "1 badge verdiend" : "\(moments.count) badges verdiend")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textSecondary)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(SharedColors.textMuted)
            content()
        }
    }

    private func badgeTile(_ kind: BadgeKind) -> some View {
        let earned = count(kind)
        return VStack(spacing: 4) {
            BadgeMedallion(kind: kind, size: 76, showsTitle: true, isLocked: earned == 0)
            if earned > 0 {
                Text("\(earned)×")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.gold)
            } else {
                Text(kind.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func remove(_ moment: BadgeMoment) {
        Task {
            try? await badgeStore.deleteMoment(moment.id)
            await load()
        }
    }

    private func shareCard() async {
        do {
            guard let snapshot = try await badgeStore.cardSnapshot(forPlayer: playerId) else {
                shareFailed = true
                return
            }
            let url = try snapshot.webURL()
            let text = "Badgekaart van \(snapshot.name): \(url.absoluteString)"
            if let cardPicture { cardPicture(snapshot, text) } else { shareText(text) }
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

/// Every match in which the player earned this badge, as iOS' BadgeMomentsView:
/// the badge with what it means, then "N× verdiend" with opponent and date.
/// Deleting only marks the award, so recomputing the match does not bring it back.
struct SharedBadgeMomentsView: View {
    let kind: BadgeKind
    @State var moments: [BadgeMoment]
    let onDelete: (BadgeMoment) -> Void

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            List {
                Section {
                    HStack(spacing: 14) {
                        BadgeMedallion(kind: kind, size: 72, showsTitle: false, isLocked: moments.isEmpty)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(SharedColors.textPrimary)
                            Text(kind.detail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textSecondary)
                            if kind.coachOnly {
                                Text("Alleen in coachmodus, waar de slagen worden bijgehouden")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.textMuted)
                            } else if kind.isCareer {
                                Text("Telt de wedstrijden op dit toestel")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.textMuted)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section("\(moments.count)× verdiend") {
                    ForEach(moments) { moment in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(moment.opponentName.isEmpty ? "Wedstrijd" : "Tegen \(moment.opponentName)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(SharedColors.textPrimary)
                            Text(Self.dateText(moment.earnedAt))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textMuted)
                        }
                        // Opaque: Android draws the red swipe-to-delete layer underneath
                        .listRowBackground(SharedColors.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            onDelete(moments[index])
                        }
                        moments.remove(atOffsets: offsets)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .pageTitle(kind.title)
    }

    /// "1 okt 2026 16:20", like iOS' medium date with short time
    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: date)
    }
}
