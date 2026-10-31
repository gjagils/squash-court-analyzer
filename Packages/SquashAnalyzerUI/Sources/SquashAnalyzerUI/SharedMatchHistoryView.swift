import SwiftUI
import SquashAnalyzerCore

/// Afgeronde wedstrijden on Android, like iOS' MatchHistoryView: filter on
/// coach/referee and on a player, open a coach match for its analysis, share
/// any match, finish an incomplete one ("Uitslag aanvullen") and delete. Named
/// `Shared...` because the iOS app target has its own `MatchHistoryView`.
public struct SharedMatchHistoryView: View {
    let store: any MatchHistoryStore
    let aiCoach: AICoachContext?
    let shareText: ((String) -> Void)?
    /// Opening an analysis leaves the list, as on iOS; nil shows it over the list
    let onOpenAnalysis: ((Match) -> Void)?

    @State private var entries: [MatchHistorySummary] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    /// "alles", "coach" or "referee"
    @State private var kindFilter = "alles"
    @State private var playerFilter: String? = nil
    @State private var choosingPlayer = false
    @State private var deleting: MatchHistorySummary? = nil
    @State private var confirmDelete = false
    @State private var analysed: Match? = nil
    @State private var shareReport: MatchShareReport? = nil
    /// A referee match opened from its row, with its date
    @State private var refereeDetail: MatchShareReport? = nil
    @State private var refereeDetailDate = ""
    @State private var completing: Match? = nil
    @State private var message: String? = nil

    public init(store: any MatchHistoryStore, aiCoach: AICoachContext? = nil, shareText: ((String) -> Void)? = nil,
                onOpenAnalysis: ((Match) -> Void)? = nil) {
        self.store = store
        self.onOpenAnalysis = onOpenAnalysis
        self.aiCoach = aiCoach
        self.shareText = shareText
    }

    private var shown: [MatchHistorySummary] {
        var result: [MatchHistorySummary] = []
        for entry in entries {
            if kindFilter != "alles" && entry.kind != kindFilter { continue }
            if let name = playerFilter, entry.player1Name != name && entry.player2Name != name { continue }
            result.append(entry)
        }
        return result
    }

    private var playerNames: [String] {
        var names: [String] = []
        for entry in entries {
            if !names.contains(entry.player1Name) { names.append(entry.player1Name) }
            if !names.contains(entry.player2Name) { names.append(entry.player2Name) }
        }
        return names.sorted()
    }

    public var body: some View {
        ZStack {
            SharedColors.background.ignoresSafeArea()
            if isLoading {
                ProgressView(loc("Wedstrijden laden…")).foregroundColor(SharedColors.textPrimary)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("Wedstrijden konden niet worden geladen.", bundle: textBundle).foregroundColor(SharedColors.textSecondary)
                    Button(loc("Opnieuw laden")) { Task { await load() } }
                }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    AppSymbol("clock.arrow.circlepath", size: 48, color: SharedColors.textSecondary)
                    Text("Nog geen afgeronde wedstrijden", bundle: textBundle).font(.headline)
                    Text("Voltooide en afgebroken coach- en scheidsrechterwedstrijden verschijnen hier.", bundle: textBundle)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(SharedColors.textSecondary)
                .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        filters
                        if let message {
                            Text(message)
                                .font(SharedFonts.system(12))
                                .foregroundColor(SharedColors.gold)
                        }
                        if shown.isEmpty {
                            Text("Geen wedstrijden met dit filter", bundle: textBundle)
                                .foregroundColor(SharedColors.textSecondary)
                                .padding(.top, 24)
                        }
                        if !refereeEntries.isEmpty {
                            sectionHeader(loc("SCHEIDSRECHTER"), icon: "whistle")
                            ForEach(refereeEntries) { entry in
                                refereeCard(entry)
                            }
                        }
                        if !coachEntries.isEmpty {
                            sectionHeader("COACH", icon: "list.bullet.clipboard")
                            ForEach(coachEntries) { entry in
                                coachCard(entry)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            if let match = completing {
                SharedCompleteResultView(match: match, onSave: { winners in complete(match, winners) },
                                         onCancel: { completing = nil })
            }
        }
        .pageTitle(loc("Wedstrijden"))
        .task {
            await load()
            await AppUsage.shared.used(AppUsagePart.analysis)
        }
        .sheet(isPresented: $choosingPlayer) {
            NavigationStack {
                List {
                    Button(loc("Alle spelers")) { playerFilter = nil; choosingPlayer = false }
                    ForEach(playerNames, id: \.self) { name in
                        Button(name) { playerFilter = name; choosingPlayer = false }
                    }
                }
                .pageTitle(loc("Speler"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        CloseButton { choosingPlayer = false }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { analysed != nil }, set: { if !$0 { analysed = nil } })) {
            if let match = analysed {
                SharedCoachDashboardView(match: match, game: match.games.last ?? match.currentGame, aiCoach: aiCoach,
                                         shareText: shareText) { analysed = nil }
            }
        }
        .sheet(isPresented: Binding(get: { refereeDetail != nil }, set: { if !$0 { refereeDetail = nil } })) {
            if let report = refereeDetail {
                RefereeMatchDetailView(report: report, date: refereeDetailDate,
                                       onShare: shareText == nil ? nil : {
                                           // One sheet at a time: the share sheet follows the details
                                           refereeDetail = nil
                                           Task { @MainActor in
                                               try? await Task.sleep(nanoseconds: 400_000_000)
                                               shareReport = report
                                           }
                                       }) { refereeDetail = nil }
            }
        }
        .sheet(isPresented: Binding(get: { shareReport != nil }, set: { if !$0 { shareReport = nil } })) {
            if let report = shareReport, let shareText {
                SharedMatchShareView(report: report, shareText: shareText) { shareReport = nil }
            }
        }
        .alert(loc("Wedstrijd verwijderen?"), isPresented: $confirmDelete) {
            Button(loc("Annuleren"), role: .cancel) { deleting = nil }
            Button(loc("Verwijderen"), role: .destructive) {
                if let entry = deleting { remove(entry) }
            }
        } message: {
            Text("Deze actie kan niet ongedaan worden gemaakt.", bundle: textBundle)
        }
    }

    // MARK: Filters

    private var filters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                filterChip(loc("Alles"), "alles")
                filterChip(loc("Scheidsrechter"), "referee")
                filterChip("Coach", "coach")
            }
            Button { choosingPlayer = true } label: {
                HStack {
                    Text(playerFilter ?? loc("Alle spelers"))
                        .foregroundColor(SharedColors.textPrimary)
                    Spacer()
                    AppSymbol(playerFilter == nil ? "chevron.down" : "xmark", size: 14, color: SharedColors.textSecondary)
                }
                .padding(12)
                .background(SharedColors.tint(0.05)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("Filter op speler"))
        }
    }

    private func filterChip(_ title: String, _ value: String) -> some View {
        let selected = kindFilter == value
        return Button { kindFilter = value } label: {
            Text(title)
                .font(SharedFonts.system(13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundColor(selected ? SharedColors.onAccent : SharedColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? SharedColors.accent : SharedColors.tint(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: Rows (as iOS' MatchHistoryCard and RefereeMatchCard)

    private var coachEntries: [MatchHistorySummary] {
        var result: [MatchHistorySummary] = []
        for entry in shown where entry.kind == "coach" { result.append(entry) }
        return result
    }

    private var refereeEntries: [MatchHistorySummary] {
        var result: [MatchHistorySummary] = []
        for entry in shown where entry.kind != "coach" { result.append(entry) }
        return result
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            AppSymbol(icon, size: 11, color: SharedColors.accent)
            Text(title)
                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                .tracking(2)
                .foregroundColor(SharedColors.accent)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var incompleteLabel: some View {
        Text("INCOMPLEET", bundle: textBundle)
            .font(SharedFonts.system(9, weight: .semibold, design: .rounded))
            .tracking(1)
            .foregroundColor(SharedColors.warmRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(SharedColors.warmRed.opacity(0.6), lineWidth: 1))
    }

    /// An oefenpartij (backlog C8): kept, but no badges and not in the profile
    private var practiceLabel: some View {
        Text("OEFENPARTIJ", bundle: textBundle)
            .font(SharedFonts.system(9, weight: .semibold, design: .rounded))
            .tracking(1)
            .foregroundColor(SharedColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(SharedColors.textSecondary.opacity(0.5), lineWidth: 1))
    }

    private var medal: some View {
        AppSymbol("medal.fill", size: 11, color: SharedColors.gold)
            .accessibilityLabel(loc("Badge verdiend"))
    }

    private func gameChips(_ entry: MatchHistorySummary) -> [String] {
        var chips: [String] = []
        for _ in 0..<entry.untrackedBefore { chips.append("–") }
        for game in entry.games { chips.append("\(game.player1Score)-\(game.player2Score)") }
        for _ in 0..<entry.untrackedAfter { chips.append("–") }
        return chips
    }

    private func deleteButton(_ entry: MatchHistorySummary) -> some View {
        Button {
            deleting = entry
            confirmDelete = true
        } label: {
            AppSymbol("trash", size: 13, color: SharedColors.textSecondary)
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("Verwijder \(entry.player1Name) – \(entry.player2Name)"))
    }

    private func shareButton(_ entry: MatchHistorySummary) -> some View {
        Button { share(entry) } label: {
            HStack(spacing: 4) {
                AppSymbol("square.and.arrow.up", size: 12, color: SharedColors.steelBlue)
                Text("Delen", bundle: textBundle)
                    .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.steelBlue)
            }
        }
        .buttonStyle(.plain)
    }

    private func coachCard(_ entry: MatchHistorySummary) -> some View {
        let winner = entry.winner
        let chips = gameChips(entry)
        return VStack(spacing: 12) {
            Button { open(entry, analysis: true) } label: {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text(Self.dateText(for: entry.updatedAt))
                            .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.textSecondary)
                        if entry.status == "abandoned" { incompleteLabel }
                        if PracticeMatches.shared.contains(id: entry.id) { practiceLabel }
                        if entry.hasBadges { medal }
                        Spacer()
                        if let name = entry.winnerName {
                            HStack(spacing: 4) {
                                AppSymbol("crown.fill", size: 10, color: SharedColors.gold)
                                Text(name)
                                    .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.gold)
                            }
                        }
                    }
                    HStack(spacing: 16) {
                        scoreSide(entry.player1Name, entry.player1Games, won: winner == Player.player1, color: SharedColors.accent)
                        VStack(spacing: 4) {
                            Text("vs").font(SharedFonts.system(12, weight: .medium, design: .rounded)).foregroundColor(SharedColors.textMuted)
                            Text("-").font(SharedFonts.system(32, weight: .bold, design: .rounded)).foregroundColor(SharedColors.textMuted)
                        }
                        scoreSide(entry.player2Name, entry.player2Games, won: winner == Player.player2, color: SharedColors.steelBlue)
                    }
                    if !chips.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(0..<chips.count, id: \.self) { index in
                                Text(chips[index])
                                    .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                    .foregroundColor(chips[index] == "–" ? SharedColors.textMuted.opacity(0.6) : SharedColors.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(SharedColors.tint(chips[index] == "–" ? 0.03 : 0.05))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if entry.status == "abandoned" {
                Button { open(entry, analysis: false) } label: {
                    HStack(spacing: 4) {
                        AppSymbol("flag.checkered", size: 12, color: SharedColors.accent)
                        Text("Uitslag aanvullen", bundle: textBundle)
                            .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(SharedColors.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button { open(entry, analysis: true) } label: {
                    HStack(spacing: 4) {
                        AppSymbol("magnifyingglass", size: 12, color: SharedColors.accent)
                        Text("Bekijk analyse", bundle: textBundle)
                            .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                            .foregroundColor(SharedColors.accent)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if shareText != nil { shareButton(entry) }
                deleteButton(entry)
                    .padding(.leading, 8)
            }
        }
        .padding(16)
        .background(SharedColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.line(0.1), lineWidth: 1))
    }

    private func scoreSide(_ name: String, _ games: Int, won: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
                .foregroundColor(won ? color : SharedColors.textPrimary)
                .lineLimit(1)
            Text("\(games)")
                .font(SharedFonts.system(32, weight: .bold, design: .rounded))
                .foregroundColor(won ? color : SharedColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func refereeCard(_ entry: MatchHistorySummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // The names and scores open the match (a button of its own, as on the
            // coach card: Delen and the bin below keep their own tap on Android)
            Button { openReferee(entry) } label: {
                HStack(spacing: 14) {
                    AppSymbol("whistle", size: 18, color: SharedColors.accent)
                        .frame(width: 36, height: 36)
                        .background(SharedColors.accent.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.player1Name)
                                .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
                                .foregroundColor(SharedColors.accent)
                                .lineLimit(1)
                            Text("vs")
                                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textMuted)
                            Text(entry.player2Name)
                                .font(SharedFonts.system(14, weight: .semibold, design: .rounded))
                                .foregroundColor(SharedColors.steelBlue)
                                .lineLimit(1)
                            Spacer()
                            if entry.hasBadges { medal }
                            Text("\(entry.player1Games)-\(entry.player2Games)")
                                .font(SharedFonts.system(16, weight: .bold, design: .monospaced))
                                .foregroundColor(SharedColors.textPrimary)
                        }
                        HStack(spacing: 8) {
                            Text(entry.gameScoresText)
                                .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                .foregroundColor(SharedColors.textMuted)
                            if let name = entry.winnerName {
                                Text("· \(name) wint", bundle: textBundle)
                                    .font(SharedFonts.system(11, weight: .medium, design: .rounded))
                                    .foregroundColor(SharedColors.gold.opacity(0.8))
                            } else {
                                incompleteLabel
                            }
                            Spacer()
                        }
                    }
                    AppSymbol("chevron.right", size: 12, color: SharedColors.textMuted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("Open \(entry.player1Name) – \(entry.player2Name)"))
            HStack {
                Text(Self.dateText(for: entry.updatedAt))
                    .font(SharedFonts.system(10, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textMuted.opacity(0.7))
                if PracticeMatches.shared.contains(id: entry.id) { practiceLabel }
                Spacer()
                if shareText != nil { shareButton(entry) }
                deleteButton(entry)
            }
            .padding(.leading, 50)
        }
        .padding(14)
        .background(SharedColors.tint(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SharedColors.gold.opacity(0.15), lineWidth: 1))
    }

    // MARK: Actions

    private func open(_ entry: MatchHistorySummary, analysis: Bool) {
        Task { @MainActor in
            guard let match = try? await store.coachMatch(id: entry.id) else {
                message = loc("Deze wedstrijd kon niet worden geopend.")
                return
            }
            if analysis {
                if let onOpenAnalysis { onOpenAnalysis(match) } else { analysed = match }
            } else {
                completing = match
            }
        }
    }

    /// A referee match: its games, times and runs (it has no analysis)
    private func openReferee(_ entry: MatchHistorySummary) {
        Task { @MainActor in
            guard let report = (try? await store.refereeMatch(id: entry.id))?.shareReport else {
                message = loc("Deze wedstrijd kon niet worden geopend.")
                return
            }
            refereeDetailDate = Self.dateText(for: entry.updatedAt)
            refereeDetail = report
        }
    }

    private func share(_ entry: MatchHistorySummary) {
        Task { @MainActor in
            if entry.kind == "coach" {
                shareReport = (try? await store.coachMatch(id: entry.id))?.shareReport
            } else {
                shareReport = (try? await store.refereeMatch(id: entry.id))?.shareReport
            }
            if shareReport == nil { message = loc("Deze wedstrijd kon niet worden gedeeld.") }
        }
    }

    private func complete(_ match: Match, _ winners: [Player]) {
        guard match.completeResult(with: winners) else { return }
        completing = nil
        Task { @MainActor in
            do {
                try await store.saveCoachMatch(match)
                message = loc("Uitslag aangevuld.")
            } catch {
                message = loc("Opslaan is niet gelukt.")
            }
            await load()
        }
    }

    private func remove(_ entry: MatchHistorySummary) {
        deleting = nil
        Task { @MainActor in
            do {
                try await store.delete(entry)
                message = nil
            } catch {
                message = loc("Verwijderen is niet gelukt.")
            }
            await load()
        }
    }

    /// `DateFormatter` with a fixed pattern, not `Date.FormatStyle`: Skip's
    /// Android runtime has no `Date.FormatStyle` support, but `DateFormatter`
    /// transpiles to `java.text.SimpleDateFormat`.
    private static func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        formatter.locale = displayLocale
        return formatter.string(from: date)
    }

    private func load() async {
        isLoading = entries.isEmpty
        do {
            entries = try await store.loadHistory()
            loadFailed = false
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}

