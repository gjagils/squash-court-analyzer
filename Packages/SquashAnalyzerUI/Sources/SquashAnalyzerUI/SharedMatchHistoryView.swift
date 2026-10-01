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
    @State private var completing: Match? = nil
    @State private var message: String? = nil

    public init(store: any MatchHistoryStore, aiCoach: AICoachContext? = nil, shareText: ((String) -> Void)? = nil) {
        self.store = store
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
            HistoryPalette.background.ignoresSafeArea()
            if isLoading {
                ProgressView("Wedstrijden laden…").foregroundColor(HistoryPalette.text)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("Wedstrijden konden niet worden geladen.").foregroundColor(HistoryPalette.muted)
                    Button("Opnieuw laden") { Task { await load() } }
                }
            } else if entries.isEmpty {
                VStack(spacing: 12) {
                    AppSymbol("clock.arrow.circlepath", size: 48, color: HistoryPalette.muted)
                    Text("Nog geen afgeronde wedstrijden").font(.headline)
                    Text("Voltooide en afgebroken coach- en scheidsrechterwedstrijden verschijnen hier.")
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(HistoryPalette.muted)
                .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        filters
                        if let message {
                            Text(message)
                                .font(.system(size: 12))
                                .foregroundColor(HistoryPalette.gold)
                        }
                        if shown.isEmpty {
                            Text("Geen wedstrijden met dit filter")
                                .foregroundColor(HistoryPalette.muted)
                                .padding(.top, 24)
                        }
                        ForEach(shown) { entry in
                            row(for: entry)
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
        .navigationTitle("Afgeronde wedstrijden")
        .task { await load() }
        .sheet(isPresented: $choosingPlayer) {
            NavigationStack {
                List {
                    Button("Alle spelers") { playerFilter = nil; choosingPlayer = false }
                    ForEach(playerNames, id: \.self) { name in
                        Button(name) { playerFilter = name; choosingPlayer = false }
                    }
                }
                .navigationTitle("Speler")
            }
        }
        .sheet(isPresented: Binding(get: { analysed != nil }, set: { if !$0 { analysed = nil } })) {
            if let match = analysed {
                SharedCoachDashboardView(match: match, game: match.games.last ?? match.currentGame, aiCoach: aiCoach,
                                         shareText: shareText) { analysed = nil }
            }
        }
        .sheet(isPresented: Binding(get: { shareReport != nil }, set: { if !$0 { shareReport = nil } })) {
            if let report = shareReport, let shareText {
                SharedMatchShareView(report: report, shareText: shareText) { shareReport = nil }
            }
        }
        .alert("Wedstrijd verwijderen?", isPresented: $confirmDelete) {
            Button("Annuleren", role: .cancel) { deleting = nil }
            Button("Verwijderen", role: .destructive) {
                if let entry = deleting { remove(entry) }
            }
        } message: {
            Text("De wedstrijd verdwijnt uit de lijst. Verdiende badges worden als verwijderd gemarkeerd.")
        }
    }

    // MARK: Filters

    private var filters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                filterChip("Alles", "alles")
                filterChip("Coach", "coach")
                filterChip("Scheidsrechter", "referee")
            }
            Button { choosingPlayer = true } label: {
                HStack {
                    Text(playerFilter ?? "Alle spelers")
                        .foregroundColor(HistoryPalette.text)
                    Spacer()
                    Text(playerFilter == nil ? "▾" : "✕")
                        .foregroundColor(HistoryPalette.muted)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter op speler")
        }
    }

    private func filterChip(_ title: String, _ value: String) -> some View {
        let selected = kindFilter == value
        return Button { kindFilter = value } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(selected ? HistoryPalette.background : HistoryPalette.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? HistoryPalette.gold : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: Rows

    private func row(for entry: MatchHistorySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { if entry.kind == "coach" { open(entry, analysis: true) } } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.kind == "coach" ? "COACH" : "SCHEIDSRECHTER")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundColor(HistoryPalette.gold)
                            if entry.status == "abandoned" {
                                Text("INCOMPLEET")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(1)
                                    .foregroundColor(HistoryPalette.red)
                            }
                        }
                        Text("\(entry.player1Name) – \(entry.player2Name)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(HistoryPalette.text)
                        Text(Self.dateText(for: entry.updatedAt))
                            .font(.system(size: 12))
                            .foregroundColor(HistoryPalette.muted)
                    }
                    Spacer()
                    Text("\(entry.player1Games) – \(entry.player2Games)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(HistoryPalette.text)
                }
            }
            .buttonStyle(.plain)

            if entry.kind == "coach" && entry.status == "abandoned" {
                Button { open(entry, analysis: false) } label: {
                    Text("Uitslag aanvullen")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(HistoryPalette.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).stroke(HistoryPalette.gold.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 18) {
                if entry.kind == "coach" {
                    Button("Bekijk analyse") { open(entry, analysis: true) }
                        .foregroundColor(HistoryPalette.gold)
                }
                Spacer()
                if shareText != nil {
                    Button("Delen") { share(entry) }
                        .foregroundColor(HistoryPalette.blue)
                }
                Button {
                    deleting = entry
                    confirmDelete = true
                } label: {
                    AppSymbol("trash", size: 16, color: HistoryPalette.muted)
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Verwijder \(entry.player1Name) – \(entry.player2Name)")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }

    // MARK: Actions

    private func open(_ entry: MatchHistorySummary, analysis: Bool) {
        Task { @MainActor in
            guard let match = try? await store.coachMatch(id: entry.id) else {
                message = "Deze wedstrijd kon niet worden geopend."
                return
            }
            if analysis { analysed = match } else { completing = match }
        }
    }

    private func share(_ entry: MatchHistorySummary) {
        Task { @MainActor in
            if entry.kind == "coach" {
                shareReport = (try? await store.coachMatch(id: entry.id))?.shareReport
            } else {
                shareReport = (try? await store.refereeMatch(id: entry.id))?.shareReport
            }
            if shareReport == nil { message = "Deze wedstrijd kon niet worden gedeeld." }
        }
    }

    private func complete(_ match: Match, _ winners: [Player]) {
        guard match.completeResult(with: winners) else { return }
        completing = nil
        Task { @MainActor in
            do {
                try await store.saveCoachMatch(match)
                message = "Uitslag aangevuld."
            } catch {
                message = "Opslaan is niet gelukt."
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
                message = "Verwijderen is niet gelukt."
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
        formatter.locale = Locale(identifier: "nl_NL")
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

private enum HistoryPalette {
    static let text = Color(red: 0.95, green: 0.93, blue: 0.90)
    static let muted = Color(red: 0.70, green: 0.68, blue: 0.65)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let blue = Color(red: 0.45, green: 0.60, blue: 0.75)
    static let red = Color(red: 0.90, green: 0.40, blue: 0.35)
    static let background = Color(red: 0.06, green: 0.05, blue: 0.04)
}
