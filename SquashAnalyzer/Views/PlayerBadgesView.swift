import SwiftUI
import SwiftData

// MARK: - "Badges verdiend" strip on the match-over screen (coach + referee)

/// Outlined gold row listing who earned what in this match; tapping it opens
/// the badge screen. Only shown when a picked player earned something.
struct MatchBadgesStrip: View {
    let earnings: [MatchBadgeEarning]
    let onTap: () -> Void

    var body: some View {
        let color = AppColors.accentGold
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BADGES VERDIEND")
                        .font(AppFonts.label(11))
                        .tracking(1)
                        .foregroundColor(color)
                    ForEach(earnings) { earning in
                        HStack(spacing: 8) {
                            ForEach(earning.badges) { kind in
                                BadgeView(kind: kind, size: 26, showsTitle: false)
                            }
                            Text("\(earning.name) · \(earning.badges.count == 1 ? earning.badges[0].title : "\(earning.badges.count) badges")")
                                .font(AppFonts.body(13))
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.35), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Bekijk badges")
    }
}

// MARK: - Sheet from the match-over screen

/// Badge screen for the players who earned something in this match, with a
/// switch between them when both did.
struct MatchBadgesSheet: View {
    let earnings: [MatchBadgeEarning]
    let matchId: UUID

    @Environment(\.dismiss) private var dismiss
    @Query private var players: [SavedPlayer]
    @State private var selected: UUID?

    init(earnings: [MatchBadgeEarning], matchId: UUID) {
        self.earnings = earnings
        self.matchId = matchId
        let ids = earnings.map(\.playerId)
        _players = Query(filter: #Predicate<SavedPlayer> { ids.contains($0.id) })
        _selected = State(initialValue: earnings.first?.playerId)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if earnings.count > 1 {
                    Picker("Speler", selection: $selected) {
                        ForEach(earnings) { earning in
                            Text(earning.name).tag(Optional(earning.playerId))
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                if let player = players.first(where: { $0.id == selected }) {
                    PlayerBadgesContent(player: player, highlightMatchId: matchId)
                        .id(player.id)
                } else {
                    Spacer()
                }
            }
            .background(AppBackground())
            .navigationTitle("Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Badge screen of one player (also from the player list)

struct PlayerBadgesView: View {
    let player: SavedPlayer

    var body: some View {
        PlayerBadgesContent(player: player, highlightMatchId: nil)
            .background(AppBackground())
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// Header, the badges new in a match, the collection with a count per badge
/// and the badges still to earn. A badge in the collection opens its earning moments.
struct PlayerBadgesContent: View {
    let player: SavedPlayer
    let highlightMatchId: UUID?

    @Query private var awards: [SavedBadgeAward]

    init(player: SavedPlayer, highlightMatchId: UUID?) {
        self.player = player
        self.highlightMatchId = highlightMatchId
        let cardId = player.badgeCardId
        _awards = Query(filter: #Predicate<SavedBadgeAward> { $0.cardId == cardId && $0.deletedAt == nil },
                        sort: \SavedBadgeAward.earnedAt, order: .reverse)
    }

    private func count(of kind: BadgeKind) -> Int {
        awards.filter { $0.badge == kind.rawValue }.count
    }

    private var newInMatch: [BadgeKind] {
        guard let highlightMatchId else { return [] }
        let kinds = Set(awards.filter { $0.matchId == highlightMatchId }.compactMap(\.badgeKind))
        return BadgeKind.allCases.filter(kinds.contains)
    }

    private var collected: [BadgeKind] { BadgeKind.allCases.filter { count(of: $0) > 0 } }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if !newInMatch.isEmpty {
                    section("NIEUW IN DEZE WEDSTRIJD") {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(newInMatch) { kind in
                                BadgeView(kind: kind)
                            }
                        }
                    }
                }

                section("BADGES · \(collected.count) VAN \(BadgeKind.allCases.count)") {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                        ForEach(BadgeKind.allCases) { kind in
                            NavigationLink {
                                BadgeMomentsView(player: player, kind: kind)
                            } label: {
                                badgeTile(kind)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                section("DELEN") {
                    CardShareActions(player: player)
                }
            }
            .padding(20)
        }
    }

    private func badgeTile(_ kind: BadgeKind) -> some View {
        let count = count(of: kind)
        return VStack(spacing: 4) {
            BadgeView(kind: kind, size: 76, isLocked: count == 0)
            if count > 0 {
                Text("\(count)×")
                    .font(AppFonts.label(13))
                    .foregroundColor(AppColors.accentGold)
            } else {
                Text(kind.detail)
                    .font(AppFonts.caption(10))
                    .foregroundColor(AppColors.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 14) {
            PlayerAvatarImage(photo: player.photoData.flatMap(UIImage.init(data:)), color: AppColors.accentGold, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(AppFonts.title(18))
                    .foregroundColor(AppColors.textPrimary)
                Text(awards.count == 1 ? "1 badge verdiend" : "\(awards.count) badges verdiend")
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFonts.label(11))
                .tracking(1.5)
                .foregroundColor(AppColors.textMuted)
            content()
        }
    }
}

// MARK: - Earning moments of one badge

/// Every match in which the player earned this badge; swipe to delete one.
/// Deleting only marks the award, so recomputing the match does not bring it back.
struct BadgeMomentsView: View {
    let player: SavedPlayer
    let kind: BadgeKind

    @Environment(\.modelContext) private var modelContext
    @Query private var awards: [SavedBadgeAward]
    @Query private var cards: [SavedPlayerCard]

    init(player: SavedPlayer, kind: BadgeKind) {
        self.player = player
        self.kind = kind
        let cardId = player.badgeCardId
        let badge = kind.rawValue
        _awards = Query(filter: #Predicate<SavedBadgeAward> { $0.cardId == cardId && $0.badge == badge && $0.deletedAt == nil },
                        sort: \SavedBadgeAward.earnedAt, order: .reverse)
        _cards = Query(filter: #Predicate<SavedPlayerCard> { $0.cardId == cardId })
    }

    /// On a joined card a coach deletes only the badges they awarded; the owner deletes any
    private func canDelete(_ award: SavedBadgeAward) -> Bool {
        guard let card = cards.first, !card.isOwner else { return true }
        return award.awardedBy == BadgeAwarder.installId
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "nl_NL")
        return formatter
    }()

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    BadgeView(kind: kind, size: 72, showsTitle: false, isLocked: awards.isEmpty)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title)
                            .font(AppFonts.title(17))
                            .foregroundColor(AppColors.textPrimary)
                        Text(kind.detail)
                            .font(AppFonts.caption(12))
                            .foregroundColor(AppColors.textSecondary)
                        if kind.coachOnly {
                            Text("Alleen in coachmodus, waar de slagen worden bijgehouden")
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.textMuted)
                        } else if kind.isCareer {
                            Text("Telt de wedstrijden op dit toestel")
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("\(awards.count)× verdiend") {
                ForEach(awards) { award in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(award.opponentName.isEmpty ? "Wedstrijd" : "Tegen \(award.opponentName)")
                            .font(AppFonts.label(14))
                            .foregroundColor(AppColors.textPrimary)
                        Text(Self.dateFormatter.string(from: award.earnedAt))
                            .font(AppFonts.caption(12))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    .swipeActions {
                        if canDelete(award) {
                            Button("Verwijder", role: .destructive) { delete(award) }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delete(_ award: SavedBadgeAward) {
        award.deletedAt = Date()
        try? modelContext.save()
        CardSync.shared.awardsChanged([award])
    }
}

// MARK: - Catalogue of every badge

/// All badges that can be earned, grouped by where you earn them, without a player
struct BadgeCatalogView: View {
    var body: some View {
        List {
            Section {
                Text("Spelers die je kiest via \"Kies speler\" verdienen badges tijdens een wedstrijd, in coach- en scheidsrechtermodus. Badges met het label Coach vragen om de slagen die alleen coachmodus bijhoudt.")
                    .font(AppFonts.caption(12))
                    .foregroundColor(AppColors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(BadgeKind.Category.allCases, id: \.self) { category in
                Section {
                    ForEach(BadgeKind.allCases.filter { $0.category == category }) { kind in
                        HStack(spacing: 14) {
                            BadgeView(kind: kind, size: 56, showsTitle: false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title)
                                    .font(AppFonts.label(15))
                                    .foregroundColor(AppColors.textPrimary)
                                Text(kind.detail)
                                    .font(AppFonts.caption(12))
                                    .foregroundColor(AppColors.textSecondary)
                                HStack(spacing: 6) {
                                    if kind.coachOnly { tag("Coach") }
                                    if kind.isOnce { tag("Eén keer") }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                } header: {
                    Text(category.rawValue.uppercased())
                        .font(AppFonts.label(11))
                        .tracking(1.5)
                        .foregroundColor(AppColors.accentGold)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Alle badges")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(AppFonts.label(9))
            .tracking(1)
            .foregroundColor(AppColors.accentGold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().stroke(AppColors.accentGold.opacity(0.5), lineWidth: 1))
    }
}
