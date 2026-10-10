import SwiftUI
import Foundation
import SquashAnalyzerCore

/// Shared Android referee screen. It keeps the same core controls as iOS:
/// tap a score for a rally, choose Links/Rechts for the server, call LET or
/// STROKE, undo mistakes, and continue after a finished game.
public struct RefereeScoringView: View {
    /// Observed, not owned: the session owns the match (a new match is a new value here)
    let match: RefereeMatch
    let onMatchChanged: (RefereeMatch) -> Void
    let onExit: @MainActor () -> Void
    let shareText: ((String) -> Void)?
    /// Photos of the picked players, by player id
    let photos: [String: Data]
    /// Sharing the stand during the match (the share icon in the header)
    @State private var sharingNow = false
    /// Badges earned in this match, worked out once when the match ends
    @State private var badgeEarnings: [MatchBadgeEarning] = []
    /// The game end whose result card was put aside ("Bekijk stand"); a new
    /// game end, or the same one after an undo and a new point, shows it again
    @State private var hiddenResult: String? = nil
    @State private var showingBadges = false

    public init(match: RefereeMatch, shareText: ((String) -> Void)? = nil, photos: [String: Data] = [:],
                onMatchChanged: @escaping (RefereeMatch) -> Void, onExit: @escaping @MainActor () -> Void) {
        self.match = match
        self.photos = photos
        self.shareText = shareText
        self.onMatchChanged = onMatchChanged
        self.onExit = onExit
    }

    public var body: some View {
        FontScaleCap { screen }
    }

    private var screen: some View {
        ZStack {
            GlowBackground()

            VStack(spacing: 12) {
                header
                gameHeader
                playerColumns
                actionGrid
                RefereeTimers(match: match)
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

            Color.clear
                .frame(width: 0, height: 0)
                .task(id: match.isMatchOver) { badgeEarnings = computeBadgeEarnings() }

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

    private func computeBadgeEarnings() -> [MatchBadgeEarning] {
        guard match.isMatchOver else { return [] }
        return SharedMatchBadgesStrip.earnings(player1Id: match.player1Id, player1Name: match.player1Name,
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
                    AppSymbol("xmark", size: 13, color: SharedColors.textSecondary)
                    Text("Sluiten").lineLimit(1)
                }
                .font(SharedFonts.system(14, weight: .medium, design: .rounded))
            }
            .foregroundColor(SharedColors.textSecondary)
            if !match.isMatchOver {
                LiveShareButton(matchId: match.id, snapshot: { match.liveSnapshot },
                                photos: { [photo(Player.player1), photo(Player.player2)] }, share: shareText)
            }
            Spacer()
            Text("Scheidsrechter")
                .font(PageTitleStyle.font)
                .foregroundColor(SharedColors.textPrimary)
                // With the LIVE button next to it the title broke into "SCHEIDSRECHTE / R" on Android
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            if shareText != nil {
                Button { sharingNow = true } label: {
                    AppSymbol("square.and.arrow.up", size: 20, color: SharedColors.gold)
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
                .font(SharedFonts.system(10, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textMuted)
                .tracking(2)
            HStack(spacing: 8) {
                Text(match.player1Name)
                    .foregroundColor(SharedColors.accent)
                Text("\(match.player1GamesWon) – \(match.player2GamesWon)")
                    .font(SharedFonts.system(22, weight: .bold, design: .monospaced))
                    .foregroundColor(SharedColors.textPrimary)
                Text(match.player2Name)
                    .foregroundColor(SharedColors.steelBlue)
            }
            .font(SharedFonts.system(13, weight: .bold, design: .rounded))
            if !match.completedGames.isEmpty || match.firstGameNumber > 1 {
                // Plain small text, as on iOS
                HStack(spacing: 10) {
                    ForEach(1..<match.firstGameNumber, id: \.self) { number in
                        gameChip("G\(number): –", color: SharedColors.textMuted)
                    }
                    ForEach(match.completedGames) { game in
                        let color = game.winner == .player1 ? SharedColors.accent : SharedColors.steelBlue
                        gameChip("G\(game.number): \(game.player1Score)-\(game.player2Score)", color: color.opacity(0.75))
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func gameChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(SharedFonts.system(9, weight: .medium, design: .rounded))
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
        let color = player == .player1 ? SharedColors.accent : SharedColors.steelBlue
        let score = player == .player1 ? match.player1Score : match.player2Score
        let highlight = ServerHighlight(color: color, isServer: isServer)

        return VStack(spacing: 8) {
            PlayerAvatarPlaceholder(color: color, size: 48, active: isServer,
                                    photo: PlayerPhotos.photo(in: photos, id: player == Player.player1 ? match.player1Id : match.player2Id, name: match.name(for: player)))
            Text(match.name(for: player))
                .font(SharedFonts.system(14, weight: .bold, design: .rounded))
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
            // Invisible for the receiver: VoiceOver/TalkBack skip it too
            .accessibilityHidden(!isServer)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) { match.awardPoint(to: player) }
                matchChanged()
            }) {
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(SharedFonts.system(76, weight: .bold, design: .rounded))
                        .foregroundColor(highlight.score)
                    Text("TIK = PUNT")
                        .font(SharedFonts.system(9, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
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
                actionButton("LET CALL", color: SharedColors.accent) { match.callLet(); matchChanged() }
                actionButton("LET CALL", color: SharedColors.coolBlue) { match.callLet(); matchChanged() }
            }
            HStack(spacing: 8) {
                actionButton("STROKE", color: SharedColors.warmRed) { match.callStroke(to: .player1); matchChanged() }
                    .accessibilityLabel("Stroke voor \(match.player1Name)")
                actionButton("STROKE", color: SharedColors.coolIndigo) { match.callStroke(to: .player2); matchChanged() }
                    .accessibilityLabel("Stroke voor \(match.player2Name)")
            }
            if match.isGameOver && !match.isMatchOver {
                Button("VOLGENDE GAME") {
                    withAnimation(.easeInOut(duration: 0.15)) { match.confirmNextGame() }
                    matchChanged()
                }
                .font(SharedFonts.system(14, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(SharedColors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SharedFonts.system(13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(match.isGameOver ? SharedColors.textMuted : color)
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


    private var undoButton: some View {
        Button(action: { undoLastPoint() }) {
            HStack(spacing: 8) {
                AppSymbol("arrow.uturn.backward", size: 16, color: match.canUndo ? SharedColors.textPrimary : SharedColors.textMuted)
                Text("Undo")
            }
            .font(SharedFonts.system(16, weight: .bold, design: .rounded))
            .foregroundColor(match.canUndo ? SharedColors.textPrimary : SharedColors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(SharedColors.tint(match.canUndo ? 0.07 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SharedColors.line(match.canUndo ? 0.15 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!match.canUndo)
        .padding(.horizontal, 16)
    }

    private func callFlash(_ text: String) -> some View {
        Text(text)
            .font(SharedFonts.system(28, weight: .bold, design: .rounded))
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

/// MATCH and GAME time, as on iOS. A view of its own: only this ticks every
/// second, not the whole referee screen (T18).
struct RefereeTimers: View {
    let match: RefereeMatch
    @State private var now = Date()

    var body: some View {
        let _ = now
        return HStack {
            AppSymbol("timer", size: 12, color: SharedColors.gold.opacity(0.5))
            timer("MATCH", match.matchDuration, alignment: .leading)
            Spacer()
            timer("GAME", match.currentGameDuration, alignment: .trailing)
            AppSymbol("timer", size: 12, color: SharedColors.gold.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .task(id: match.isMatchOver) {
            while !Task.isCancelled && !match.isMatchOver {
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
                .font(SharedFonts.system(8, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(SharedColors.textMuted)
            Text(text)
                .font(SharedFonts.system(16, weight: .bold, design: .monospaced))
                .foregroundColor(SharedColors.textSecondary)
        }
        .accessibilityLabel("\(label == "MATCH" ? "Wedstrijdtijd" : "Gametijd") \(text)")
    }
}
