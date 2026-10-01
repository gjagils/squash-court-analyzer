import SwiftUI
import SquashAnalyzerCore

/// Read-only list of completed/abandoned coach and referee matches. Much
/// smaller than iOS' full `MatchHistoryView` (1000+ lines: import/export,
/// backup, filters, completing an incomplete match) — just a list, no
/// tap-through detail yet. Named `Shared...`, not `MatchHistoryView`, for
/// the same reason as `SharedBadgeCatalogView`: the iOS app target already
/// has its own `MatchHistoryView`.
public struct SharedMatchHistoryView: View {
    let store: any MatchHistoryStore

    @State private var entries: [MatchHistorySummary] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    public init(store: any MatchHistoryStore) {
        self.store = store
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
                    LazyVStack(spacing: 12) {
                        ForEach(entries) { entry in
                            row(for: entry)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Afgeronde wedstrijden")
        .task { await load() }
    }

    private func row(for entry: MatchHistorySummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.kind == "coach" ? "COACH" : "SCHEIDSRECHTER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(HistoryPalette.gold)
                    if entry.status == "abandoned" {
                        Text("AFGEBROKEN")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(HistoryPalette.muted)
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
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
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
        isLoading = true
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
    static let background = Color(red: 0.06, green: 0.05, blue: 0.04)
}
