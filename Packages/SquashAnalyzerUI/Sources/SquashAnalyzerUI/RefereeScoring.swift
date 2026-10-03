import SwiftUI
import Foundation
import SquashAnalyzerCore

/// Shared Android referee screen. It keeps the same core controls as iOS:
/// tap a score for a rally, choose Links/Rechts for the server, call LET or
/// STROKE, undo mistakes, and continue after a finished game.
public struct RefereeScoringView: View {
    @State private var match: RefereeMatch
    let onMatchChanged: (RefereeMatch) -> Void
    let onExit: @MainActor () -> Void
    let shareText: ((String) -> Void)?
    /// Photos of the picked players, by player id
    let photos: [String: Data]
    /// Sharing the stand during the match (the share icon in the header)
    @State private var sharingNow = false
    /// Ticks every second for the match and game timers
    @State private var now = Date()
    /// The game end whose result card was put aside ("Bekijk stand"); a new
    /// game end, or the same one after an undo and a new point, shows it again
    @State private var hiddenResult: String? = nil
    @State private var showingBadges = false

    public init(match: RefereeMatch, shareText: ((String) -> Void)? = nil, photos: [String: Data] = [:],
                onMatchChanged: @escaping (RefereeMatch) -> Void, onExit: @escaping @MainActor () -> Void) {
        _match = State(initialValue: match)
        self.photos = photos
        self.shareText = shareText
        self.onMatchChanged = onMatchChanged
        self.onExit = onExit
    }

    public var body: some View {
        ZStack {
            GlowBackground()

            VStack(spacing: 12) {
                header
                gameHeader
                playerColumns
                actionGrid
                timers
                undoButton
            }
            .padding(.bottom, 20)

            if match.isGameOver && hiddenResult != resultKey {
                resultCard
            }

            if sharingNow, let shareText {
                SharedMatchShareView(report: match.shareReport, player1Photo: photo(Player.player1), player2Photo: photo(Player.player2),
                                     shareText: shareText) {
                    sharingNow = false
                    // Back to the result card, as on iOS
                    if match.isMatchOver { hiddenResult = nil }
                }
            }

            if let call = match.lastCallText {
                callFlash(call)
                    .task(id: call) {
                        try? await Task.sleep(nanoseconds: call.hasPrefix("LET") ? UInt64(2_000_000_000) : UInt64(1_500_000_000))
                        if match.lastCallText == call { match.clearCallText() }
                    }
            }
        }
    }

    // MARK: - Result card (as on iOS)

    private var resultKey: String {
        "\(match.currentGameNumber)-\(match.player1Score)-\(match.player2Score)"
    }

    private func photo(_ player: Player) -> Data? {
        PlayerPhotos.photo(in: photos, id: player == Player.player1 ? match.player1Id : match.player2Id, name: match.name(for: player))
    }

    private var badgeEarnings: [MatchBadgeEarning] {
        SharedMatchBadgesStrip.earnings(player1Id: match.player1Id, player1Name: match.player1Name,
                                        player2Id: match.player2Id, player2Name: match.player2Name,
                                        badgeInput: match.badgeInput)
    }

    /// Undo also forgets a hidden result card: winning the same point again
    /// gives the same score, and the card must show again
    private func undoLastPoint() {
        withAnimation(.easeInOut(duration: 0.15)) { match.undo() }
        hiddenResult = nil
        matchChanged()
    }

    @ViewBuilder
    private var resultCard: some View {
        if match.isMatchOver {
            MatchResultOverlay(
                result: MatchResult.refereeMatch(match),
                player1Photo: photo(Player.player1), player2Photo: photo(Player.player2),
                badgeEarnings: badgeEarnings, onBadges: { showingBadges = true },
                primary: shareText == nil ? ResultButton("Sluiten") { close() }
                    : ResultButton("Deel score") { hiddenResult = resultKey; sharingNow = true },
                outlined: shareText == nil ? nil : ResultButton("Sluiten") { close() },
                onUndo: { undoLastPoint() }
            )
            .sheet(isPresented: $showingBadges) {
                SharedMatchBadgesSheet(earnings: badgeEarnings) { showingBadges = false }
            }
        } else {
            MatchResultOverlay(
                result: MatchResult.refereeGame(match),
                player1Photo: photo(Player.player1), player2Photo: photo(Player.player2),
                primary: ResultButton("Volgende game") {
                    withAnimation(.easeInOut(duration: 0.15)) { match.confirmNextGame() }
                    matchChanged()
                },
                onUndo: { undoLastPoint() },
                link: ResultButton("Bekijk stand") { hiddenResult = resultKey }
            )
        }
    }

    /// Save and send the new state to live viewers
    private func matchChanged() {
        onMatchChanged(match)
        LiveShareSync.send(matchId: match.id, snapshot: match.liveSnapshot)
    }

    private var header: some View {
        HStack {
            Button(action: close) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                    Text("Sluiten")
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(CoachPalette.textSecondary)
            if !match.isMatchOver {
                LiveShareButton(matchId: match.id, snapshot: { match.liveSnapshot }, share: shareText)
            }
            Spacer()
            Text("SCHEIDSRECHTER")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.textPrimary)
                .tracking(2)
                // With the LIVE button next to it the title broke into "SCHEIDSRECHTE / R" on Android
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            if shareText != nil {
                Button { sharingNow = true } label: {
                    AppSymbol("square.and.arrow.up", size: 20, color: CoachPalette.gold)
                        .frame(width: 74, height: 32, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Deel de stand")
            } else {
                Color.clear.frame(width: 74, height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var gameHeader: some View {
        VStack(spacing: 4) {
            Text("GAME \(match.currentGameNumber)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(CoachPalette.textMuted)
                .tracking(2)
            HStack(spacing: 8) {
                Text(match.player1Name)
                    .foregroundColor(CoachPalette.warmOrange)
                Text("\(match.player1GamesWon) – \(match.player2GamesWon)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(CoachPalette.textPrimary)
                Text(match.player2Name)
                    .foregroundColor(CoachPalette.steelBlue)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            if !match.completedGames.isEmpty || match.firstGameNumber > 1 {
                // Plain small text, as on iOS
                HStack(spacing: 10) {
                    ForEach(1..<match.firstGameNumber, id: \.self) { number in
                        gameChip("G\(number): –", color: CoachPalette.textMuted)
                    }
                    ForEach(match.completedGames) { game in
                        let color = game.winner == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
                        gameChip("G\(game.number): \(game.player1Score)-\(game.player2Score)", color: color.opacity(0.75))
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func gameChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundColor(color)
    }

    private var playerColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            playerColumn(.player1)
            timeline
            playerColumn(.player2)
        }
        .frame(maxHeight: .infinity)
    }

    private func playerColumn(_ player: Player) -> some View {
        let isServer = match.currentServer == player
        let color = player == .player1 ? CoachPalette.warmOrange : CoachPalette.steelBlue
        let score = player == .player1 ? match.player1Score : match.player2Score
        let highlight = ServerHighlight(color: color, isServer: isServer)

        return VStack(spacing: 8) {
            PlayerAvatarPlaceholder(color: color, size: 48, active: isServer,
                                    photo: PlayerPhotos.photo(in: photos, id: player == Player.player1 ? match.player1Id : match.player2Id, name: match.name(for: player)))
            Text(match.name(for: player))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(highlight.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ServiceSideSelector(
                side: match.serverSide,
                preferredSide: match.preferredSide(for: player),
                color: color,
                compact: true,
                disabled: match.isGameOver
            ) { side in
                withAnimation(.easeInOut(duration: 0.15)) { match.overrideSide(to: side) }
                matchChanged()
            }
            .opacity(isServer ? 1.0 : 0.0)
            .allowsHitTesting(isServer)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { match.awardPoint(to: player) }
                matchChanged()
            }) {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 76, weight: .bold, design: .rounded))
                        .foregroundColor(highlight.score)
                    Text("TIK = PUNT")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(highlight.caption)
                        .tracking(1.4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(isServer ? 0.10 : 0.05))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(isServer ? 0.35 : 0.12), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .disabled(match.isGameOver)
            .accessibilityLabel("Punt voor \(match.name(for: player))")
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, 12)
        .background(isServer ? color.opacity(0.05) : Color.clear)
    }

    private var timeline: some View {
        RefereeScoringTimeline(entries: match.pointHistory, server: match.currentServer)
    }

    private var actionGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("LET CALL", color: CoachPalette.warmOrange) { match.callLet(); matchChanged() }
                actionButton("LET CALL", color: CoachPalette.coolBlue) { match.callLet(); matchChanged() }
            }
            HStack(spacing: 8) {
                actionButton("STROKE", color: CoachPalette.warmRed) { match.callStroke(to: .player1); matchChanged() }
                actionButton("STROKE", color: CoachPalette.coolIndigo) { match.callStroke(to: .player2); matchChanged() }
            }
            if match.isGameOver && !match.isMatchOver {
                Button("VOLGENDE GAME") {
                    withAnimation(.easeInOut(duration: 0.15)) { match.confirmNextGame() }
                    matchChanged()
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(CoachPalette.backgroundDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CoachPalette.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(match.isGameOver ? CoachPalette.textMuted : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(match.isGameOver ? 0.04 : 0.12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(match.isGameOver ? 0.08 : 0.35), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .disabled(match.isGameOver)
    }

    /// MATCH and GAME time, as on iOS
    private var timers: some View {
        let _ = now
        return HStack {
            AppSymbol("timer", size: 12, color: CoachPalette.gold.opacity(0.5))
            timer("MATCH", match.matchDuration, alignment: .leading)
            Spacer()
            timer("GAME", match.currentGameDuration, alignment: .trailing)
            AppSymbol("timer", size: 12, color: CoachPalette.gold.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                now = Date()
            }
        }
    }

    private func timer(_ label: String, _ seconds: TimeInterval, alignment: HorizontalAlignment) -> some View {
        let total = Int(seconds)
        let text = (total / 60 < 10 ? "0" : "") + "\(total / 60):" + (total % 60 < 10 ? "0" : "") + "\(total % 60)"
        return VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(CoachPalette.textMuted)
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(CoachPalette.textSecondary)
        }
        .accessibilityLabel("\(label == "MATCH" ? "Wedstrijdtijd" : "Gametijd") \(text)")
    }

    private var undoButton: some View {
        Button(action: { undoLastPoint() }) {
            HStack(spacing: 8) {
                AppSymbol("arrow.uturn.backward", size: 16, color: match.canUndo ? CoachPalette.textPrimary : CoachPalette.textMuted)
                Text("Undo")
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(match.canUndo ? CoachPalette.textPrimary : CoachPalette.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white.opacity(match.canUndo ? 0.07 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(match.canUndo ? 0.15 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!match.canUndo)
        .padding(.horizontal, 16)
    }

    private func callFlash(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .tracking(3)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.85)))
            .transition(.scale.combined(with: .opacity))
    }

    /// Only tells the session view; it closes once the save is done, so
    /// "Even opslaan…" and the retry card can show (no own dismiss here)
    @MainActor private func close() {
        onExit()
    }
}
