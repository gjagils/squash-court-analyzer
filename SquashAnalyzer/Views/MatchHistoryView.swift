import SwiftUI
import SwiftData

/// View for displaying saved match history
struct MatchHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedMatch.savedAt, order: .reverse) private var savedMatches: [SavedMatch]
    @Binding var isPresented: Bool
    let onSelectMatch: (SavedMatch) -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Header
                headerView

                if savedMatches.isEmpty {
                    emptyStateView
                } else {
                    matchListView
                }
            }
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

            // Placeholder for symmetry
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Terug")
            }
            .font(AppFonts.body(14))
            .foregroundColor(.clear)
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

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Match List
    private var matchListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(savedMatches) { match in
                    MatchHistoryCard(match: match) {
                        onSelectMatch(match)
                    } onDelete: {
                        deleteMatch(match)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Delete Match
    private func deleteMatch(_ match: SavedMatch) {
        withAnimation {
            modelContext.delete(match)
            try? modelContext.save()
        }
    }
}

// MARK: - Match History Card
struct MatchHistoryCard: View {
    let match: SavedMatch
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header row: Date and delete button
                HStack {
                    Text(match.formattedDate)
                        .font(AppFonts.caption(11))
                        .foregroundColor(AppColors.textMuted)

                    Spacer()

                    // Winner badge
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

                // Players and score
                HStack(spacing: 16) {
                    // Player 1
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

                    // VS divider
                    VStack(spacing: 4) {
                        Text("vs")
                            .font(AppFonts.caption(12))
                            .foregroundColor(AppColors.textMuted)

                        Text("-")
                            .font(AppFonts.title(32))
                            .foregroundColor(AppColors.textMuted)
                    }

                    // Player 2
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

                // Game scores
                if !match.games.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(match.games.sorted(by: { $0.gameNumber < $1.gameNumber })) { game in
                            Text("\(game.player1Score)-\(game.player2Score)")
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.05))
                                )
                        }
                    }
                }

                // Delete button row
                HStack {
                    Spacer()
                    Button(action: { showingDeleteConfirm = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Verwijderen")
                                .font(AppFonts.caption(11))
                        }
                        .foregroundColor(AppColors.textMuted)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.backgroundMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .alert("Wedstrijd verwijderen?", isPresented: $showingDeleteConfirm) {
            Button("Annuleren", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Deze actie kan niet ongedaan worden gemaakt.")
        }
    }
}

// MARK: - Preview
#Preview {
    MatchHistoryView(
        isPresented: .constant(true),
        onSelectMatch: { _ in }
    )
    .modelContainer(for: [SavedMatch.self, SavedGame.self, SavedPoint.self], inMemory: true)
}
