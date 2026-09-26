import SwiftUI

/// Full-screen referee / scorekeeper view
struct RefereeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var match: RefereeMatch
    let onDismiss: () -> Void

    @State private var showingNextGameConfirm = false
    @State private var showingMatchOver = false
    @State private var showingShareSheet = false
    @State private var savedRefereeMatch: SavedRefereeMatch? = nil

    init(match: RefereeMatch, onDismiss: @escaping () -> Void) {
        _match = State(initialValue: match)
        self.onDismiss = onDismiss
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
        .sheet(isPresented: $showingShareSheet) {
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

        return VStack(spacing: 6) {
            PlayerAvatar(name: match.name(for: player), color: color, size: 52, active: isServer)

            // Name
            Text(match.name(for: player))
                .font(AppFonts.label(14))
                .foregroundColor(isServer ? AppColors.textPrimary : color)
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
                        .foregroundColor(isServer ? AppColors.textPrimary : color)
                        .contentTransition(.numericText())
                    Text("TIK = PUNT")
                        .font(AppFonts.caption(9))
                        .foregroundColor(isServer ? AppColors.textPrimary.opacity(0.8) : color.opacity(0.55))
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
            RefereeGameResult(number: $0.number, player1Score: $0.p1, player2Score: $0.p2, winner: $0.winner)
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

/// Vertical rally-by-rally line between the two player columns: newest rally at
/// the top under the "now" marker, each pill showing the scorer's new score and
/// the box they serve from next ("4R"). Player 1 pills hang left, player 2 right.
private struct RefereeScoringTimeline: View {
    let entries: [RefereePointEntry]   // oldest first
    let server: Player

    private let width: CGFloat = 100
    private let rowHeight: CGFloat = 30
    private let dotSize: CGFloat = 14

    var body: some View {
        let serverColor = Self.color(for: server)

        VStack(spacing: 0) {
            nowMarker(color: serverColor)
                .frame(height: 52)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(entries.reversed()) { entry in
                        row(entry)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [serverColor.opacity(0.7), serverColor.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5)
                .padding(.top, 26)
        }
        .frame(width: width)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.25), value: entries)
        .animation(.easeInOut(duration: 0.25), value: server)
    }

    private func nowMarker(color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: 34, height: 34)
                .blur(radius: 5)
            Circle()
                .fill(color)
                .frame(width: 15, height: 15)
                .shadow(color: color.opacity(0.9), radius: 6)
        }
    }

    private func row(_ entry: RefereePointEntry) -> some View {
        let color = Self.color(for: entry.scorer)
        let isLeft = entry.scorer == .player1
        // Reserve half the width minus the dot radius so the dot sits on the line
        let inner = width / 2 - dotSize / 2

        return HStack(spacing: 0) {
            if isLeft {
                Spacer(minLength: 0)
                pill(entry, color: color, dotOnRight: true)
                Color.clear.frame(width: inner)
            } else {
                Color.clear.frame(width: inner)
                pill(entry, color: color, dotOnRight: false)
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: rowHeight)
    }

    private func pill(_ entry: RefereePointEntry, color: Color, dotOnRight: Bool) -> some View {
        HStack(spacing: 4) {
            if !dotOnRight { dot(color: color) }
            Text(entry.label)
                .font(AppFonts.label(11))
                .foregroundColor(.white)
                .monospacedDigit()
            if dotOnRight { dot(color: color) }
        }
        .padding(.leading, dotOnRight ? 8 : 3)
        .padding(.trailing, dotOnRight ? 3 : 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color)
                .overlay(
                    // Strokes get a thin light ring so they stand out in the history
                    Capsule().stroke(Color.white.opacity(entry.isStroke ? 0.7 : 0), lineWidth: 1)
                )
        )
    }

    private func dot(color: Color) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: dotSize, height: dotSize)
            .overlay(
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            )
    }

    private static func color(for player: Player) -> Color {
        player == .player1 ? AppColors.warmOrange : AppColors.steelBlue
    }
}

// MARK: - Referee Setup Sheet

struct RefereeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player1Name: String
    @State private var player2Name: String
    @State private var bestOf: Int = 5
    @State private var startingServer: Player = .player1
    @State private var showingReferee = false
    @State private var createdMatch: RefereeMatch? = nil
    @State private var showingPickerFor: Player? = nil

    init(player1Name: String = "", player2Name: String = "") {
        _player1Name = State(initialValue: player1Name)
        _player2Name = State(initialValue: player2Name)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 28) {
                        Text("SCHEIDSRECHTER")
                            .font(AppFonts.title(20))
                            .foregroundColor(AppColors.textPrimary)
                            .tracking(3)
                            .padding(.top, 32)

                        // Player names
                        VStack(spacing: 16) {
                            playerField(label: "SPELER 1", text: $player1Name, color: AppColors.warmOrange, player: .player1)
                            playerField(label: "SPELER 2", text: $player2Name, color: AppColors.steelBlue, player: .player2)
                        }
                        .padding(.horizontal, 24)

                        // Best of
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BEST OF")
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.accentGold)
                                .tracking(1)
                                .padding(.horizontal, 24)

                            HStack(spacing: 12) {
                                ForEach([3, 5, 7], id: \.self) { n in
                                    Button(action: { bestOf = n }) {
                                        Text("\(n)")
                                            .font(AppFonts.label(16))
                                            .foregroundColor(bestOf == n ? AppColors.backgroundDark : AppColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(bestOf == n ? AppColors.accentGold : Color.white.opacity(0.07))
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // First server
                        VStack(alignment: .leading, spacing: 10) {
                            Text("EERSTE SERVER")
                                .font(AppFonts.caption(11))
                                .foregroundColor(AppColors.accentGold)
                                .tracking(1)
                                .padding(.horizontal, 24)

                            HStack(spacing: 12) {
                                serverButton(.player1, name: player1Name.isEmpty ? "Speler 1" : player1Name, color: AppColors.warmOrange)
                                serverButton(.player2, name: player2Name.isEmpty ? "Speler 2" : player2Name, color: AppColors.steelBlue)
                            }
                            .padding(.horizontal, 24)
                        }

                        // Start button
                        Button(action: startReferee) {
                            Text("Start scheidsrechter")
                                .font(AppFonts.label(16))
                                .foregroundColor(AppColors.backgroundDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.accentGold)
                                )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $createdMatch) { m in
                RefereeView(match: m) {
                    createdMatch = nil
                    dismiss()
                }
            }
            .sheet(item: $showingPickerFor) { pickerPlayer in
                PlayerManagementView { savedPlayer in
                    if pickerPlayer == .player1 {
                        player1Name = savedPlayer.name
                    } else {
                        player2Name = savedPlayer.name
                    }
                }
            }
        }
    }

    private func startReferee() {
        let p1 = player1Name.trimmingCharacters(in: .whitespaces)
        let p2 = player2Name.trimmingCharacters(in: .whitespaces)
        createdMatch = RefereeMatch(
            player1Name: p1.isEmpty ? "Speler 1" : p1,
            player2Name: p2.isEmpty ? "Speler 2" : p2,
            bestOf: bestOf,
            startingServer: startingServer
        )
    }

    private func playerField(label: String, text: Binding<String>, color: Color, player: Player) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.caption(11))
                .foregroundColor(color)
                .tracking(1)
            HStack(spacing: 8) {
                TextField("Naam speler", text: text)
                    .font(AppFonts.body(16))
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))

                Button(action: { showingPickerFor = player }) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 22))
                        .foregroundColor(color.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func serverButton(_ player: Player, name: String, color: Color) -> some View {
        Button(action: { startingServer = player }) {
            Text(name)
                .font(AppFonts.label(14))
                .foregroundColor(startingServer == player ? AppColors.backgroundDark : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(startingServer == player ? color : Color.white.opacity(0.07))
                )
        }
    }
}

// MARK: - Referee Game Over Overlay (tussen games)

private struct RefereeGameOverOverlay: View {
    let match: RefereeMatch
    let onNextGame: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var winner: Player? { match.currentGameWinner }

    var body: some View {
        ResultOverlayCard(accent: winner.map(RefereeView.color(for:))) {
            ResultTitle("GAME \(match.currentGameNumber) KLAAR")

            ResultScoreRow(
                player1Name: match.player1Name,
                player2Name: match.player2Name,
                player1Score: match.player1Score,
                player2Score: match.player2Score,
                winner: winner
            )

            if let winner {
                ResultWinnerLine(text: "\(match.name(for: winner)) wint game \(match.currentGameNumber)",
                                 color: RefereeView.color(for: winner))
            }

            VStack(spacing: 10) {
                GameResultChips(games: match.allGameResults, untracked: match.firstGameNumber - 1)
                ResultCaption(standText)
                ResultCaption(gameStatsText, icon: "timer")
            }

            VStack(spacing: 12) {
                HardwareButton(title: "Volgende game", color: AppColors.warmOrange) { onNextGame() }
                OverlayUndoButton(action: onUndo)
                Button(action: onDismiss) {
                    Text("Bekijk stand")
                        .font(AppFonts.caption(13))
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 2)
            }
        }
    }

    /// "Gelijk 1 – 1" or "Jan leidt 2 – 1", games won including this one
    private var standText: String {
        let p1 = match.player1TotalGames, p2 = match.player2TotalGames
        if p1 == p2 { return "Gelijk \(p1) – \(p2)" }
        let leader: Player = p1 > p2 ? .player1 : .player2
        return "\(match.name(for: leader)) leidt \(max(p1, p2)) – \(min(p1, p2))"
    }

    private var gameStatsText: String {
        let secs = Int(match.currentGameDuration)
        var parts = [String(format: "%d:%02d", secs / 60, secs % 60), "\(match.pointHistory.count) rallies"]
        let strokes = match.pointHistory.filter(\.isStroke).count
        if strokes > 0 { parts.append("\(strokes) stroke\(strokes == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Referee Match Over Overlay

private struct RefereeMatchOverOverlay: View {
    let match: RefereeMatch
    let onShare: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var showingBadges = false

    private var winner: Player? { match.matchWinner }

    private var badgeEarnings: [MatchBadgeEarning] {
        BadgeEngine().earnings(for: match.badgeInput, playerIds: match.playerIds,
                               names: [.player1: match.player1Name, .player2: match.player2Name])
    }

    var body: some View {
        ResultOverlayCard(accent: winner.map(RefereeView.color(for:))) {
            ResultTitle("WEDSTRIJD KLAAR")

            ResultScoreRow(
                player1Name: match.player1Name,
                player2Name: match.player2Name,
                player1Score: match.player1TotalGames,
                player2Score: match.player2TotalGames,
                winner: winner
            )

            if let winner {
                ResultWinnerLine(text: "🏆 \(match.name(for: winner)) wint de wedstrijd",
                                 color: RefereeView.color(for: winner))
            }

            VStack(spacing: 10) {
                GameResultChips(games: match.allGameResults, untracked: match.firstGameNumber - 1)
                ResultCaption(matchStatsText, icon: "timer")
            }

            let earnings = badgeEarnings
            if !earnings.isEmpty {
                MatchBadgesStrip(earnings: earnings) { showingBadges = true }
            }

            VStack(spacing: 12) {
                HardwareButton(title: "Deel score", color: AppColors.warmOrange) { onShare() }
                HardwareButton(title: "Sluiten", color: AppColors.textSecondary, style: .outlined) { onDismiss() }
                OverlayUndoButton(action: onUndo)
            }
        }
        .sheet(isPresented: $showingBadges) {
            MatchBadgesSheet(earnings: badgeEarnings, matchId: match.id)
        }
    }

    private var matchStatsText: String {
        let minutes = max(1, Int((match.matchDuration / 60).rounded()))
        var parts = ["\(minutes) min", "\(match.totalRallies) rallies"]
        if match.totalStrokes > 0 { parts.append("\(match.totalStrokes) stroke\(match.totalStrokes == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

extension RefereeView {
    /// Player colours as used throughout the referee screen
    static func color(for player: Player) -> Color {
        player == .player1 ? AppColors.warmOrange : AppColors.steelBlue
    }
}

// MARK: - Result overlay building blocks (referee + coach)

/// Dimmed scrim with the flat referee-style result card on top. `accent` tints
/// the hairline border in the winner's colour.
struct ResultOverlayCard<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.backgroundMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accent?.opacity(0.35) ?? Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }
}

struct ResultTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(AppFonts.title(20))
            .foregroundColor(AppColors.textPrimary)
            .tracking(3)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Avatars, names and the big rounded scores side by side; the winner keeps
/// their colour, the loser is dimmed – same treatment as the live columns.
struct ResultScoreRow: View {
    let player1Name: String
    let player2Name: String
    let player1Score: Int
    let player2Score: Int
    let winner: Player?
    var scoreSize: CGFloat = 64

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            side(.player1, name: player1Name, score: player1Score)
            Text("–")
                .font(.system(size: scoreSize * 0.55, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .baselineOffset(scoreSize * 0.22)   // centre the dash on the digits
            side(.player2, name: player2Name, score: player2Score)
        }
    }

    private func side(_ player: Player, name: String, score: Int) -> some View {
        let color = RefereeView.color(for: player)
        let won = winner == nil || winner == player
        return VStack(spacing: 6) {
            PlayerAvatar(name: name, color: color, size: 44, active: won)
            Text(name)
                .font(AppFonts.label(13))
                .foregroundColor(won ? color : AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(score)")
                .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                .foregroundColor(won ? color : AppColors.textPrimary.opacity(0.55))
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}

struct ResultWinnerLine: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(AppFonts.body(16))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct ResultCaption: View {
    let text: String
    var icon: String? = nil
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accentGold.opacity(0.6))
            }
            Text(text)
                .font(AppFonts.caption(12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// "G1 11-13" chips in the winner's colour, like the row under the live header.
/// `untracked` games (played before scoring started) show as grey "G1 –" chips.
struct GameResultChips: View {
    let games: [(number: Int, p1: Int, p2: Int, winner: Player)]
    var untracked: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<untracked, id: \.self) { index in
                chip(number: index + 1, score: "–", color: AppColors.textMuted)
            }
            ForEach(games, id: \.number) { game in
                chip(number: game.number, score: "\(game.p1)-\(game.p2)", color: RefereeView.color(for: game.winner))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func chip(number: Int, score: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("G\(number)")
                .font(AppFonts.caption(9))
                .foregroundColor(color.opacity(0.7))
                .tracking(1)
            Text(score)
                .font(AppFonts.label(12))
                .foregroundColor(color)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Service side selector (referee + coach)

/// "SERVICE" caption with the Links / Rechts box chips for the current server.
/// The active chip is filled in the player's colour; a pin marks the box the
/// player starts from after every hand-out. `compact` is the scoreboard size.
struct ServiceSideSelector: View {
    let side: ServerSide
    let preferredSide: ServerSide?
    let color: Color
    var compact: Bool = false
    var disabled: Bool = false
    let onSelect: (ServerSide) -> Void

    var body: some View {
        VStack(spacing: compact ? 2 : 3) {
            Text("SERVICE")
                .font(AppFonts.caption(compact ? 8 : 9))
                .foregroundColor(color.opacity(0.6))
                .tracking(1)

            HStack(spacing: compact ? 4 : 6) {
                chip("Links", .left)
                chip("Rechts", .right)
            }
        }
    }

    private func chip(_ label: String, _ box: ServerSide) -> some View {
        let active = side == box
        return Button(action: { onSelect(box) }) {
            HStack(spacing: 3) {
                if preferredSide == box {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                }
                Text(label)
                    .font(AppFonts.label(compact ? 11 : 12))
            }
            .foregroundColor(active ? AppColors.backgroundDark : color.opacity(0.4))
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? color : color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(active ? 0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(active || disabled)
    }
}

// MARK: - Overlay Undo Button

/// "Undo laatste punt" for game-over / match-over overlays, so a mis-tap on the
/// final point can still be corrected. Used by referee and coach overlays.
struct OverlayUndoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Undo laatste punt")
                    .font(AppFonts.label(13))
            }
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// Make RefereeMatch Identifiable for fullScreenCover(item:)
extension RefereeMatch: Identifiable {}
