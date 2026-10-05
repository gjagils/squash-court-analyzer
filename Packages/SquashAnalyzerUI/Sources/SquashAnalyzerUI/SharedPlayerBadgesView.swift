import SwiftUI
import SquashAnalyzerCore

/// A player's badges on Android, like iOS' PlayerBadgesView: how many earned,
/// every badge of the catalogue (earned in colour with a count, the rest grey
/// with how to earn it), and per earned badge the moments it was earned, which
/// can be deleted. A badge with tiers is one tile, showing the highest tier
/// earned. Named `Shared...` because the iOS app target has its own
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

    /// Moments of one tier
    private func count(_ badge: BadgeKind) -> Int {
        var result = 0
        for moment in moments where moment.badge == badge {
            result += 1
        }
        return result
    }

    /// How often the badge was earned: the tier with the most moments (bronze
    /// comes with every silver or gold, unless a moment was deleted)
    private func familyCount(_ family: BadgeKind) -> Int {
        var result = 0
        for kind in family.series {
            result = max(result, count(kind))
        }
        return result
    }

    /// The highest tier earned, or the bronze/plain badge while nothing is earned
    private func shownKind(_ family: BadgeKind) -> BadgeKind {
        var best = family
        for kind in family.series where count(kind) > 0 {
            best = kind
        }
        return best
    }

    private var earnedFamilies: Int {
        var result = 0
        for family in BadgeKind.families where familyCount(family) > 0 {
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
                        section("BADGES · \(earnedFamilies) VAN \(BadgeKind.families.count)") {
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

    private static var rowCount: Int { (BadgeKind.families.count + 2) / 3 }

    private func badgeRow(_ row: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            gridCell(row * 3)
            gridCell(row * 3 + 1)
            gridCell(row * 3 + 2)
        }
    }

    @ViewBuilder
    private func gridCell(_ index: Int) -> some View {
        if index < BadgeKind.families.count {
            let family = BadgeKind.families[index]
            NavigationLink {
                SharedBadgeMomentsView(family: family, moments: moments(of: family)) { moment in remove(moment) }
            } label: {
                badgeTile(family)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(shownKind(family).tieredTitle), \(familyCount(family) > 0 ? "\(familyCount(family)) keer verdiend" : "nog niet verdiend")")
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }

    /// The moments of every tier of the badge, newest first (as loaded)
    private func moments(of family: BadgeKind) -> [BadgeMoment] {
        var list: [BadgeMoment] = []
        for moment in moments where moment.badge.family == family {
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

    private func badgeTile(_ family: BadgeKind) -> some View {
        let earned = familyCount(family)
        let shown = shownKind(family)
        return VStack(spacing: 4) {
            BadgeMedallion(kind: shown, size: 76, showsTitle: true, isLocked: earned == 0)
            if earned > 0 {
                Text(Self.earnedText(shown, count: earned))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.gold)
            } else {
                Text(family.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// "Goud · 3×" for a tier, "3×" for a badge without tiers
    static func earnedText(_ kind: BadgeKind, count: Int) -> String {
        guard let tier = kind.tier else { return "\(count)×" }
        return tier.title + " · \(count)×"
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
/// the badge with what it means, then "N× verdiend" with the tier, opponent and
/// date. Deleting only marks the award, so recomputing the match does not bring it back.
struct SharedBadgeMomentsView: View {
    /// The bronze or plain badge; the moments cover every tier of it
    let family: BadgeKind
    @State var moments: [BadgeMoment]
    let onDelete: (BadgeMoment) -> Void

    /// The highest tier among the moments, or the badge itself while none is earned
    private var shownKind: BadgeKind {
        var best = family
        for kind in family.series {
            for moment in moments where moment.badge == kind {
                best = kind
            }
        }
        return best
    }

    var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            List {
                Section {
                    HStack(spacing: 14) {
                        BadgeMedallion(kind: shownKind, size: 72, showsTitle: false, isLocked: moments.isEmpty)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(SharedColors.textPrimary)
                            Text(family.detail)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textSecondary)
                            if let summary = family.tierSummary {
                                Text(summary)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.textMuted)
                            }
                            if family.coachOnly {
                                Text("Alleen in coachmodus, waar de slagen worden bijgehouden")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.textMuted)
                            } else if family.isCareer {
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
                            Text(Self.momentTitle(moment))
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
        .pageTitle(family.title)
    }

    /// "Goud · Tegen Kristian", "Tegen Kristian" or "Wedstrijd"
    static func momentTitle(_ moment: BadgeMoment) -> String {
        let against = moment.opponentName.isEmpty ? "Wedstrijd" : "Tegen \(moment.opponentName)"
        guard let tier = moment.badge.tier else { return against }
        return tier.title + " · " + against
    }

    /// "1 okt 2026 16:20", like iOS' medium date with short time
    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy HH:mm"
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter.string(from: date)
    }
}
