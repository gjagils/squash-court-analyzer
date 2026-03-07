import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// View for displaying saved match history and standalone games
struct MatchHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMatch.savedAt, order: .reverse) private var savedMatches: [SavedMatch]
    @Query(sort: \SavedGame.savedAt, order: .reverse) private var allSavedGames: [SavedGame]
    @Binding var isPresented: Bool
    let onSelectMatch: (SavedMatch) -> Void
    var onSelectGame: ((SavedGame) -> Void)? = nil

    @State private var showingImporter = false
    @State private var importError: String? = nil
    @State private var showingImportError = false
    @State private var showingImportSuccess = false

    private var standaloneGames: [SavedGame] {
        allSavedGames.filter { $0.match == nil }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                headerView

                if savedMatches.isEmpty && standaloneGames.isEmpty {
                    emptyStateView
                } else {
                    contentListView
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import mislukt", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "Onbekende fout")
        }
        .alert("Import gelukt!", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("De game of wedstrijd is succesvol geïmporteerd.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { isPresented = false }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Terug")
                }
                .font(AppFonts.body(14))
                .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("WEDSTRIJDEN")
                .font(AppFonts.title(18))
                .foregroundColor(AppColors.textPrimary)
                .tracking(3)

            Spacer()

            Button(action: { showingImporter = true }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accentGold)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textMuted)

            Text("Geen opgeslagen wedstrijden")
                .font(AppFonts.body(16))
                .foregroundColor(AppColors.textSecondary)

            Text("Speel een wedstrijd en sla deze op\nom hier terug te zien")
                .font(AppFonts.caption(14))
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)

            Button(action: { showingImporter = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Importeer JSON")
                }
                .font(AppFonts.label(14))
                .foregroundColor(AppColors.accentGold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.accentGold.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Content List

    private var contentListView: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                if !savedMatches.isEmpty {
                    Section {
                        ForEach(savedMatches) { match in
                            MatchHistoryCard(match: match) {
                                onSelectMatch(match)
                            } onDelete: {
                                deleteMatch(match)
                            }
                        }
                    } header: {
                        HistorySectionHeader(title: "WEDSTRIJDEN")
                    }
                }

                if !standaloneGames.isEmpty {
                    Section {
                        ForEach(standaloneGames) { game in
                            StandaloneGameCard(game: game) {
                                onSelectGame?(game)
                                if onSelectGame != nil {
                                    isPresented = false
                                }
                            } onDelete: {
                                deleteGame(game)
                            }
                        }
                    } header: {
                        HistorySectionHeader(title: "LOSSE GAMES")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Delete

    private func deleteMatch(_ match: SavedMatch) {
        withAnimation {
            modelContext.delete(match)
            try? modelContext.save()
        }
    }

    private func deleteGame(_ game: SavedGame) {
        withAnimation {
            modelContext.delete(game)
            try? modelContext.save()
        }
    }

    // MARK: - Import

    private func handleImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Geen toegang tot bestand"
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            try ExportService.importFromJSON(data, context: modelContext)
            showingImportSuccess = true
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

// MARK: - Section Header

struct HistorySectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(AppFonts.caption(11))
                .foregroundColor(AppColors.accentGold)
                .tracking(2)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(AppColors.backgroundDark.opacity(0.95))
    }
}

// MARK: - Standalone Game Card

struct StandaloneGameCard: View {
    let game: SavedGame
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @State private var shareItemsToShow: ShareItemsWrapper? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                HStack {
                    Text(game.formattedDate)
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)
                    Spacer()
                    Text("Game \(game.gameNumber)")
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)
                }

                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(game.player1Name)
                            .font(AppFonts.label(14))
                            .foregroundColor(game.gameWinner == .player1 ? AppColors.warmOrange : AppColors.textPrimary)
                            .lineLimit(1)
                        Text("\(game.player1Score)")
                            .font(AppFonts.title(28))
                            .foregroundColor(game.gameWinner == .player1 ? AppColors.warmOrange : AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("vs").font(AppFonts.caption(12)).foregroundColor(AppColors.textMuted)
                        Text("-").font(AppFonts.title(28)).foregroundColor(AppColors.textMuted)
                    }

                    VStack(spacing: 2) {
                        Text(game.player2Name)
                            .font(AppFonts.label(14))
                            .foregroundColor(game.gameWinner == .player2 ? AppColors.steelBlue : AppColors.textPrimary)
                            .lineLimit(1)
                        Text("\(game.player2Score)")
                            .font(AppFonts.title(28))
                            .foregroundColor(game.gameWinner == .player2 ? AppColors.steelBlue : AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 16) {
                    Label("\(game.points.count) punten", systemImage: "circle.fill")
                        .font(AppFonts.caption(10))
                        .foregroundColor(AppColors.textMuted)
                    if game.totalLets > 0 {
                        Label("\(game.totalLets) lets", systemImage: "pause.circle")
                            .font(AppFonts.caption(10))
                            .foregroundColor(AppColors.textMuted)
                    }
                    Spacer()
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 12))
                        Text("Bekijk analyse").font(AppFonts.caption(11))
                    }
                    .foregroundColor(AppColors.accentGold)

                    Spacer()

                    Button(action: { shareGame() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                            Text("Delen").font(AppFonts.caption(11))
                        }
                        .foregroundColor(AppColors.steelBlue)
                    }

                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash").font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .padding(.leading, 8)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundMedium))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Game verwijderen?", isPresented: $showingDeleteConfirm) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) { onDelete() }
        } message: {
            Text("Deze actie kan niet ongedaan worden gemaakt.")
        }
        .sheet(item: $shareItemsToShow) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    private func shareGame() {
        var items: [Any] = []
        items.append(ExportService.textSummary(from: game))
        if let data = try? ExportService.exportJSON(from: game),
           let url = try? ExportService.writeToTempFile(data, filename: "squash_game_\(game.player1Name)_vs_\(game.player2Name).json") {
            items.append(url)
        }
        shareItemsToShow = ShareItemsWrapper(items: items)
    }
}

// MARK: - Match History Card

struct MatchHistoryCard: View {
    let match: SavedMatch
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @State private var shareItemsToShow: ShareItemsWrapper? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Text(match.formattedDate)
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)

                    Spacer()

                    if let winnerName = match.winnerName {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text(winnerName)
                                .font(AppFonts.caption(11))
                        }
                        .foregroundColor(AppColors.accentGold)
                    }
                }

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(match.player1Name)
                            .font(AppFonts.label(14))
                            .foregroundColor(match.matchWinner == .player1 ? AppColors.warmOrange : AppColors.textPrimary)
                            .lineLimit(1)
                        Text("\(match.player1GamesWon)")
                            .font(AppFonts.title(32))
                            .foregroundColor(match.matchWinner == .player1 ? AppColors.warmOrange : AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("vs").font(AppFonts.caption(12)).foregroundColor(AppColors.textMuted)
                        Text("-").font(AppFonts.title(32)).foregroundColor(AppColors.textMuted)
                    }

                    VStack(spacing: 4) {
                        Text(match.player2Name)
                            .font(AppFonts.label(14))
                            .foregroundColor(match.matchWinner == .player2 ? AppColors.steelBlue : AppColors.textPrimary)
                            .lineLimit(1)
                        Text("\(match.player2GamesWon)")
                            .font(AppFonts.title(32))
                            .foregroundColor(match.matchWinner == .player2 ? AppColors.steelBlue : AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                if !match.games.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(match.games.sorted(by: { $0.gameNumber < $1.gameNumber })) { game in
                            Text("\(game.player1Score)-\(game.player2Score)")
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.05)))
                        }
                    }
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis").font(.system(size: 12))
                        Text("Bekijk analyse").font(AppFonts.caption(11))
                    }
                    .foregroundColor(AppColors.accentGold)

                    Spacer()

                    Button(action: { shareMatch() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                            Text("Delen").font(AppFonts.caption(11))
                        }
                        .foregroundColor(AppColors.steelBlue)
                    }

                    Button(action: { showingDeleteConfirm = true }) {
                        Image(systemName: "trash").font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .padding(.leading, 8)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.backgroundMedium))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Wedstrijd verwijderen?", isPresented: $showingDeleteConfirm) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) { onDelete() }
        } message: {
            Text("Deze actie kan niet ongedaan worden gemaakt.")
        }
        .sheet(item: $shareItemsToShow) { wrapper in
            ShareSheet(items: wrapper.items)
        }
    }

    private func shareMatch() {
        var items: [Any] = []
        items.append(ExportService.textSummary(from: match))
        if let data = try? ExportService.exportJSON(from: match),
           let url = try? ExportService.writeToTempFile(data, filename: "squash_match_\(match.player1Name)_vs_\(match.player2Name).json") {
            items.append(url)
        }
        shareItemsToShow = ShareItemsWrapper(items: items)
    }
}

// MARK: - Preview

#Preview {
    MatchHistoryView(
        isPresented: .constant(true),
        onSelectMatch: { _ in },
        onSelectGame: { _ in }
    )
    .modelContainer(for: [SavedMatch.self, SavedGame.self, SavedPoint.self], inMemory: true)
}
