import SwiftUI
import SwiftData
import SquashAnalyzerCore
import SquashAnalyzerUI

/// Full-screen referee / scorekeeper view
struct RefereeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var match: RefereeMatch
    let onDismiss: () -> Void

    @State private var showingNextGameConfirm = false
    @State private var showingMatchOver = false
    @State private var showingShareSheet = false
    @State private var savedRefereeMatch: SavedRefereeMatch? = nil
    /// The live link to share (WhatsApp), see LiveShareButton
    @State private var liveShareItems: ShareItemsWrapper? = nil

    init(match: RefereeMatch, onDismiss: @escaping () -> Void) {
        _match = State(initialValue: match)
        self.onDismiss = onDismiss
    }

    /// Changes whenever something worth keeping changed
    private var progressKey: String {
        "\(match.player1Score)-\(match.player2Score)-\(match.currentGameNumber)-\(match.pointHistory.count)-\(match.completedGames.count)-\(match.currentServer.rawValue)-\(match.serverSide.rawValue)"
    }

    /// Keeps an unfinished match in a file so it can be resumed; a finished one is in SwiftData
    private func keepProgress() {
        if match.isMatchOver {
            RefereeInProgressStore.clear()
        } else {
            RefereeInProgressStore.save(match)
        }
        // Live viewers get the new state; the final one deletes the session
        LiveShareSync.send(matchId: match.id, snapshot: match.liveSnapshot)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar

                gameScoreHeader

                Divider().background(Color.white.opacity(0.08))

                // Player columns with the rally-by-rally scoring line in between
                HStack(alignment: .top, spacing: 0) {
                    playerColumn(.player1)
                    RefereeScoringTimeline(entries: match.pointHistory, server: match.currentServer)
                    playerColumn(.player2)
                }
                .frame(maxHeight: .infinity)

                Divider().background(Color.white.opacity(0.08))

                // Action grid
                actionGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Timers
                timerRow

                // Undo
                undoButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }

            if let call = match.lastCallText {
                callFlash(text: call)
            }

            if showingNextGameConfirm {
                RefereeGameOverOverlay(
                    match: match,
                    onNextGame: {
                        match.confirmNextGame()
                        showingNextGameConfirm = false
                    },
                    onUndo: {
                        withAnimation(.easeInOut(duration: 0.15)) { match.undo() }
                        showingNextGameConfirm = false
                    },
                    onDismiss: { showingNextGameConfirm = false }
                )
            }

            if showingMatchOver {
                RefereeMatchOverOverlay(
                    match: match,
                    onShare: { shareScore(); showingMatchOver = false },
                    onUndo: {
                        // The match was auto-saved the moment it ended; take that back too.
                        unsaveMatch()
                        withAnimation(.easeInOut(duration: 0.15)) { match.undo() }
                        showingMatchOver = false
                    },
                    onDismiss: { onDismiss() }
                )
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            // Back to the result card, as on Android
            if match.isMatchOver { showingMatchOver = true }
        }) {
            MatchShareSheet(report: match.shareReport)
        }
        .onChange(of: match.isGameOver) { _, isOver in
            guard isOver else { return }
            if match.isMatchOver {
                saveMatchIfComplete()
                showingMatchOver = true
            } else {
                showingNextGameConfirm = true
            }
        }
        // Every rally, call and box change is kept, so Sluiten or closing the app can be resumed
        .onChange(of: progressKey) { _, _ in keepProgress() }
        .onAppear { keepProgress() }
        .sheet(item: $liveShareItems) { wrapper in
            ShareSheet(items: wrapper.items)
        }
        .onChange(of: match.lastCallText) { _, call in
            guard let call else { return }
            Task {
                try? await Task.sleep(nanoseconds: call.hasPrefix("LET") ? 2_000_000_000 : 1_500_000_000)
                if match.lastCallText == call { match.clearCallText() }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("Sluiten")
                }
                .font(AppFonts.body(14))
                .foregroundColor(AppColors.textSecondary)
            }

            if !match.isMatchOver {
                LiveShareButton(matchId: match.id, snapshot: { match.liveSnapshot }) { text in
                    liveShareItems = ShareItemsWrapper(items: [text])
                }
            }

            Spacer()

            Text("SCHEIDSRECHTER")
                .font(AppFonts.title(14))
                .foregroundColor(AppColors.textPrimary)
                .tracking(2)

            Spacer()

            Button(action: shareScore) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accentGold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Game Score Header

    private var gameScoreHeader: some View {
        VStack(spacing: 3) {
            Text("GAME \(match.currentGameNumber)")
                .font(AppFonts.caption(10))
                .foregroundColor(AppColors.textMuted)
                .tracking(2)

            HStack(spacing: 8) {
                Text(match.player1Name)
                    .font(AppFonts.label(13))
                    .foregroundColor(AppColors.warmOrange)
                    .lineLimit(1)

                Text("\(match.player1GamesWon) – \(match.player2GamesWon)")
                    .font(AppFonts.score(22))
                    .foregroundColor(AppColors.textPrimary)

                Text(match.player2Name)
                    .font(AppFonts.label(13))
                    .foregroundColor(AppColors.steelBlue)
                    .lineLimit(1)
            }

            if !match.completedGames.isEmpty || match.firstGameNumber > 1 {
                HStack(spacing: 10) {
                    ForEach(1..<match.firstGameNumber, id: \.self) { number in
                        Text("G\(number): –")
                            .font(AppFonts.caption(9))
                            .foregroundColor(AppColors.textMuted)
                    }
                    ForEach(match.completedGames) { game in
                        let c: Color = game.winner == .player1 ? AppColors.warmOrange : AppColors.steelBlue
                        Text("G\(game.number): \(game.player1Score)-\(game.player2Score)")
                            .font(AppFonts.caption(9))
                            .foregroundColor(c.opacity(0.75))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Player Column

    /// The server's column stands out: tinted background with name, score and
    /// "tik = punt" in white; the receiver keeps the player colour.
    private func playerColumn(_ player: Player) -> some View {
        let isServer = match.currentServer == player
        let color: Color = player == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        let score = player == .player1 ? match.player1Score : match.player2Score
        let highlight = ServerHighlight(color: color, isServer: isServer)

        return VStack(spacing: 6) {
            PlayerAvatar(name: match.name(for: player), color: color, size: 52, active: isServer)

            // Name
            Text(match.name(for: player))
                .font(AppFonts.label(14))
                .foregroundColor(highlight.name)
                .lineLimit(1)

            // Links / Rechts selector — always laid out so both scores line up,
            // only visible and tappable for the current server
            ServiceSideSelector(
                side: match.serverSide,
                preferredSide: match.preferredSide(for: player),
                color: color,
                disabled: match.isGameOver
            ) { side in
                withAnimation(.easeInOut(duration: 0.15)) { match.overrideSide(to: side) }
            }
            .opacity(isServer ? 1 : 0)
            .allowsHitTesting(isServer)

            // Score: tapping it awards the rally to this player
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { match.awardPoint(to: player) }
            }) {
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(highlight.score)
                        .contentTransition(.numericText())
                    Text("TIK = PUNT")
                        .font(AppFonts.caption(9))
                        .foregroundColor(highlight.caption)
                        .tracking(1.4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(color.opacity(0.25), lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(match.isGameOver)
            .padding(.horizontal, 10)
            .accessibilityLabel("Punt voor \(match.name(for: player))")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 12)
        .background(isServer ? color.opacity(0.05) : Color.clear)
    }

    // MARK: - Action Grid

    // Rallies are awarded by tapping a score; left column follows player 1's
    // warm palette, right column player 2's cool palette
    private var actionGrid: some View {
        VStack(spacing: 8) {
            // LET CALL
            HStack(spacing: 8) {
                actionButton("LET CALL", color: AppColors.warmOrange) {
                    match.callLet()
                }
                actionButton("LET CALL", color: AppColors.coolBlue) {
                    match.callLet()
                }
            }

            // STROKE
            HStack(spacing: 8) {
                actionButton("STROKE", color: AppColors.warmRed) {
                    match.callStroke(to: .player1)
                }
                actionButton("STROKE", color: AppColors.coolIndigo) {
                    match.callStroke(to: .player2)
                }
            }

            // After "Bekijk stand" the game-over card is gone; carry on from here
            if match.isGameOver && !match.isMatchOver && !showingNextGameConfirm {
                HardwareButton(title: "Volgende game", color: AppColors.warmOrange) {
                    withAnimation(.easeInOut(duration: 0.15)) { match.confirmNextGame() }
                }
            }
        }
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        let disabled = match.isGameOver
        return Button(action: action) {
            Text(title)
                .font(AppFonts.label(13))
                .tracking(1)
                .foregroundColor(disabled ? AppColors.textMuted : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(disabled ? 0.04 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color.opacity(disabled ? 0.08 : 0.35), lineWidth: 1)
                        )
                )
        }
        .disabled(disabled)
    }

    // MARK: - Timer Row

    // Start times live on the match (the share texts use them); TimelineView
    // redraws once a second without a timer that restarts on every re-render.
    private var timerRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accentGold.opacity(0.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text("MATCH")
                        .font(AppFonts.caption(8))
                        .foregroundColor(AppColors.textMuted)
                        .tracking(1)
                    Text(elapsed(since: match.matchStartedAt, at: context.date))
                        .font(AppFonts.score(16))
                        .foregroundColor(AppColors.textSecondary)
                        .monospacedDigit()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("GAME")
                        .font(AppFonts.caption(8))
                        .foregroundColor(AppColors.textMuted)
                        .tracking(1)
                    Text(elapsed(since: match.gameStartedAt, at: context.date))
                        .font(AppFonts.score(16))
                        .foregroundColor(AppColors.textSecondary)
                        .monospacedDigit()
                }

                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accentGold.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func elapsed(since start: Date, at now: Date) -> String {
        let secs = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    // MARK: - Undo Button

    private var undoButton: some View {
        Button(action: { match.undo() }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14))
                Text("Undo")
                    .font(AppFonts.label(16))
            }
            .foregroundColor(match.canUndo ? AppColors.textPrimary : AppColors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(match.canUndo ? 0.07 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(match.canUndo ? 0.15 : 0.06), lineWidth: 1)
                    )
            )
        }
        .disabled(!match.canUndo)
    }

    // MARK: - Call Flash

    private func callFlash(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(AppFonts.title(28))
                .foregroundColor(.white)
                .tracking(4)
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))
                )
                .transition(.scale.combined(with: .opacity))
            Spacer()
        }
        .allowsHitTesting(false)
    }

    // MARK: - Save

    private func saveMatchIfComplete() {
        guard match.isMatchOver, savedRefereeMatch == nil else { return }
        let results = match.allGameResults.map {
            RefereeGameResult(number: $0.number, player1Score: $0.player1Score, player2Score: $0.player2Score, winner: $0.winner)
        }
        let saved = SavedRefereeMatch(
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            bestOf: match.bestOf,
            gameResults: results,
            player1GamesBefore: match.player1GamesBefore,
            player2GamesBefore: match.player2GamesBefore
        )
        saved.matchId = match.id
        saved.player1Id = match.player1Id
        saved.player2Id = match.player2Id
        modelContext.insert(saved)
        try? BadgeAwarder(context: modelContext).syncAwards(
            matchId: match.id,
            playerIds: match.playerIds,
            playerNames: [.player1: match.player1Name, .player2: match.player2Name],
            input: match.badgeInput
        )
        try? modelContext.save()
        savedRefereeMatch = saved
    }

    private func unsaveMatch() {
        guard let saved = savedRefereeMatch else { return }
        modelContext.delete(saved)
        try? BadgeAwarder(context: modelContext).removeAwards(forMatch: match.id)
        try? modelContext.save()
        savedRefereeMatch = nil
    }

    // MARK: - Share

    private func shareScore() {
        showingShareSheet = true
    }
}

// MARK: - Scoring Timeline

// MARK: - Referee Setup Sheet

// MARK: - Referee Game Over Overlay (tussen games)

private struct RefereeGameOverOverlay: View {
    let match: RefereeMatch
    let onNextGame: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @Query private var players: [SavedPlayer]

    var body: some View {
        // The card is shared with Android (SquashAnalyzerUI's MatchResultOverlay)
        MatchResultOverlay(
            result: .refereeGame(match),
            player1Photo: players.photo(named: match.player1Name),
            player2Photo: players.photo(named: match.player2Name),
            primary: ResultButton("Volgende game") { onNextGame() },
            onUndo: onUndo,
            link: ResultButton("Bekijk stand") { onDismiss() }
        )
    }
}

// MARK: - Referee Match Over Overlay

private struct RefereeMatchOverOverlay: View {
    let match: RefereeMatch
    let onShare: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @Query private var players: [SavedPlayer]
    @State private var showingBadges = false

    private var badgeEarnings: [MatchBadgeEarning] {
        BadgeEngine().earnings(for: match.badgeInput, playerIds: match.playerIds,
                               names: [.player1: match.player1Name, .player2: match.player2Name])
    }

    var body: some View {
        MatchResultOverlay(
            result: .refereeMatch(match),
            player1Photo: players.photo(named: match.player1Name),
            player2Photo: players.photo(named: match.player2Name),
            badgeEarnings: badgeEarnings,
            onBadges: { showingBadges = true },
            primary: ResultButton("Deel score") { onShare() },
            outlined: ResultButton("Sluiten") { onDismiss() },
            onUndo: onUndo
        )
        .sheet(isPresented: $showingBadges) {
            MatchBadgesSheet(earnings: badgeEarnings, matchId: match.id)
        }
    }
}

extension RefereeView {
    /// Player colours as used throughout the referee screen
    static func color(for player: Player) -> Color {
        player == .player1 ? AppColors.warmOrange : AppColors.steelBlue
    }
}

