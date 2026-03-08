import SwiftUI

/// Full-screen referee / scorekeeper view
struct RefereeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var match: RefereeMatch
    let onDismiss: () -> Void

    @State private var showingNextGameConfirm = false
    @State private var showingMatchOver = false
    @State private var shareItemsToShow: ShareItemsWrapper? = nil
    @State private var matchSaved = false

    // Timers
    @State private var matchStartTime = Date()
    @State private var gameStartTime = Date()
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                // Player columns + server dot
                HStack(alignment: .center, spacing: 0) {
                    playerColumn(.player1)
                    serverDot
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
        }
        .onReceive(ticker) { t in now = t }
        .onChange(of: match.currentGameNumber) { _, _ in
            gameStartTime = Date()
        }
        .alert("Game klaar!", isPresented: $showingNextGameConfirm) {
            Button("Volgende game") { match.confirmNextGame() }
            Button("Bekijk stand", role: .cancel) { }
        } message: {
            if let winner = match.currentGameWinner {
                Text("\(match.name(for: winner)) wint game \(match.currentGameNumber)!\n\(match.player1Score)-\(match.player2Score)")
            }
        }
        .alert("Wedstrijd klaar!", isPresented: $showingMatchOver) {
            Button("Deel uitslag") { shareScore() }
            Button("Sluiten", role: .cancel) { onDismiss() }
        } message: {
            if let winner = match.matchWinner {
                Text("🏆 \(match.name(for: winner)) wint!\n\(match.player1GamesWon)-\(match.player2GamesWon)")
            }
        }
        .sheet(item: $shareItemsToShow) { wrapper in
            ShareSheet(items: wrapper.items)
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

            if !match.completedGames.isEmpty {
                HStack(spacing: 10) {
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

    private func playerColumn(_ player: Player) -> some View {
        let isServer = match.currentServer == player
        let color: Color = player == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        let score = player == .player1 ? match.player1Score : match.player2Score
        let isOverridden = player == .player1 ? match.player1PreferredSide != nil : match.player2PreferredSide != nil

        return VStack(spacing: 6) {
            // Avatar circle
            ZStack {
                Circle()
                    .stroke(color.opacity(isServer ? 1.0 : 0.4), lineWidth: 2)
                    .frame(width: 52, height: 52)
                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(color.opacity(isServer ? 1.0 : 0.4))
            }

            // Name
            Text(match.name(for: player))
                .font(AppFonts.label(14))
                .foregroundColor(isServer ? color : AppColors.textSecondary)
                .lineLimit(1)

            // Links / Rechts selector (only for server) — above the score
            if isServer {
                VStack(spacing: 3) {
                    Text("SERVICE")
                        .font(AppFonts.caption(9))
                        .foregroundColor(color.opacity(0.6))
                        .tracking(1)

                    HStack(spacing: 6) {
                        sideChip("Links", side: .left, active: match.serverSide == .left,
                                 color: color, pinned: isOverridden && match.serverSide == .left)
                        sideChip("Rechts", side: .right, active: match.serverSide == .right,
                                 color: color, pinned: isOverridden && match.serverSide == .right)
                    }
                }
            } else {
                // Reserve height so non-server column doesn't collapse
                Color.clear.frame(height: 44)
            }

            // Score
            Text("\(score)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(isServer ? color : AppColors.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isServer ? color.opacity(0.05) : Color.clear)
    }

    private func sideChip(_ label: String, side: ServerSide, active: Bool, color: Color, pinned: Bool) -> some View {
        Button(action: { match.overrideSide(to: side) }) {
            HStack(spacing: 3) {
                if pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                }
                Text(label)
                    .font(AppFonts.label(12))
            }
            .foregroundColor(active ? AppColors.backgroundDark : color.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
        .disabled(active || match.isGameOver)
    }

    // MARK: - Server Dot

    private var serverDot: some View {
        let color: Color = match.currentServer == .player1 ? AppColors.warmOrange : AppColors.steelBlue
        let offset: CGFloat = match.currentServer == .player1 ? -9 : 9

        return ZStack {
            Rectangle()
                .fill(color.opacity(0.2))
                .frame(width: 1.5)
            Circle()
                .fill(color)
                .frame(width: 13, height: 13)
                .offset(x: offset)
        }
        .frame(width: 22)
        .animation(.easeInOut(duration: 0.25), value: match.currentServer)
    }

    // MARK: - Action Grid

    private var actionGrid: some View {
        VStack(spacing: 8) {
            // WON RALLY
            HStack(spacing: 8) {
                actionButton("WON RALLY", color: AppColors.accentGold) {
                    withAnimation(.easeInOut(duration: 0.15)) { match.awardPoint(to: .player1) }
                }
                actionButton("WON RALLY", color: AppColors.accentGold) {
                    withAnimation(.easeInOut(duration: 0.15)) { match.awardPoint(to: .player2) }
                }
            }

            // LET CALL
            HStack(spacing: 8) {
                actionButton("LET CALL", color: AppColors.warmOrange) {
                    match.callLet()
                }
                actionButton("LET CALL", color: AppColors.warmOrange) {
                    match.callLet()
                }
            }

            // STROKE
            HStack(spacing: 8) {
                actionButton("STROKE", color: Color(red: 0.85, green: 0.3, blue: 0.3)) {
                    match.callStroke(to: .player1)
                }
                actionButton("STROKE", color: Color(red: 0.85, green: 0.3, blue: 0.3)) {
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

    private var timerRow: some View {
        HStack {
            Image(systemName: "timer")
                .font(.system(size: 12))
                .foregroundColor(AppColors.accentGold.opacity(0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text("MATCH")
                    .font(AppFonts.caption(8))
                    .foregroundColor(AppColors.textMuted)
                    .tracking(1)
                Text(elapsed(since: matchStartTime))
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
                Text(elapsed(since: gameStartTime))
                    .font(AppFonts.score(16))
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
            }

            Image(systemName: "timer")
                .font(.system(size: 12))
                .foregroundColor(AppColors.accentGold.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func elapsed(since start: Date) -> String {
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
        guard match.isMatchOver, !matchSaved else { return }
        let results = match.allGameResults.map {
            RefereeGameResult(number: $0.number, player1Score: $0.p1, player2Score: $0.p2, winner: $0.winner)
        }
        let saved = SavedRefereeMatch(
            player1Name: match.player1Name,
            player2Name: match.player2Name,
            bestOf: match.bestOf,
            gameResults: results
        )
        modelContext.insert(saved)
        try? modelContext.save()
        matchSaved = true
    }

    // MARK: - Share

    private func shareScore() {
        shareItemsToShow = ShareItemsWrapper(items: [match.whatsAppText])
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

// Make RefereeMatch Identifiable for fullScreenCover(item:)
extension RefereeMatch: Identifiable {
    var id: String { "\(player1Name)-\(player2Name)-\(bestOf)" }
}
