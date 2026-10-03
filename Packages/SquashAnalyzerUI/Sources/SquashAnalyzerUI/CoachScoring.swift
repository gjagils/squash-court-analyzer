import SwiftUI
import Foundation
import SquashAnalyzerCore

/// Shared scoreboard: same layout as iOS's own `ScoreboardView`, but with
/// `PlayerAvatarPlaceholder` instead of the SwiftData-backed `PlayerAvatar`
/// (no player photos yet on Android — same scope cut as phase 5's Spelers).
public struct SharedScoreboardView: View {
    let game: Game
    let match: Match?
    var onSelectPlayer: ((Player) -> Void)? = nil
    var onServiceChanged: () -> Void
    /// Photos of the picked players, by player id
    var photos: [String: Data] = [:]

    public init(game: Game, match: Match? = nil, photos: [String: Data] = [:], onServiceChanged: @escaping () -> Void = {},
                onSelectPlayer: ((Player) -> Void)? = nil) {
        self.game = game
        self.photos = photos
        self.match = match
        self.onSelectPlayer = onSelectPlayer
        self.onServiceChanged = onServiceChanged
    }

    private func photo(for player: Player) -> Data? {
        PlayerPhotos.photo(in: photos, id: player == Player.player1 ? match?.player1Id : match?.player2Id,
                           name: game.name(for: player))
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            playerScore(.player1)
            gameColumn
            playerScore(.player2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private var gameColumn: some View {
        VStack(spacing: 3) {
            Text("GAME \(match?.currentGameNumber ?? 1)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textMuted)
                .tracking(2)
            Text("\(match?.player1GamesWon ?? 0) – \(match?.player2GamesWon ?? 0)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(SharedColors.textPrimary)
            Text("GAMES")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textMuted)
                .tracking(1.5)

            pointsTimeline
                .padding(.top, 8)
        }
        .frame(width: 84)
        .padding(.top, 6)
    }

    /// Small version of the referee scoring line, as on iOS: newest rally on
    /// top under the "now" marker, player 1 pills left of the line, player 2
    /// right, each with the scorer's new score. The last five rallies.
    private var pointsTimeline: some View {
        let width = CGFloat(84)
        let rowHeight = CGFloat(15)
        let rows = 5
        var recent: [Point] = []
        for point in game.points.suffix(rows).reversed() { recent.append(point) }
        let serverColor = game.currentServer == Player.player1 ? SharedColors.accent : SharedColors.steelBlue

        return VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(serverColor.opacity(0.28))
                    .frame(width: 14, height: 14)
                    .blur(radius: 2)
                Circle()
                    .fill(serverColor)
                    .frame(width: 7, height: 7)
            }
            .frame(height: 14)
            ForEach(recent) { point in
                timelineRow(point, width: width, rowHeight: rowHeight)
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, height: CGFloat(14) + CGFloat(rows) * rowHeight, alignment: .top)
        .background(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(colors: [serverColor.opacity(0.7), serverColor.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 1)
                .padding(.top, 7)
        }
        .clipped()
    }

    private func timelineRow(_ point: Point, width: CGFloat, rowHeight: CGFloat) -> some View {
        let isLeft = point.scorer == Player.player1
        let color = isLeft ? SharedColors.accent : SharedColors.steelBlue
        let score = isLeft ? point.player1Score : point.player2Score
        let dotSize = CGFloat(8)
        let inner = width / CGFloat(2) - dotSize / CGFloat(2)
        return HStack(spacing: 0) {
            if isLeft {
                Spacer(minLength: 0)
                timelinePill("\(score)", color: color, dotOnRight: true, dotSize: dotSize)
                Color.clear.frame(width: inner)
            } else {
                Color.clear.frame(width: inner)
                timelinePill("\(score)", color: color, dotOnRight: false, dotSize: dotSize)
                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: rowHeight)
    }

    private func timelinePill(_ text: String, color: Color, dotOnRight: Bool, dotSize: CGFloat) -> some View {
        HStack(spacing: 2) {
            if !dotOnRight { timelineDot(color, dotSize) }
            Text(text)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            if dotOnRight { timelineDot(color, dotSize) }
        }
        .padding(.leading, dotOnRight ? CGFloat(5) : CGFloat(2))
        .padding(.trailing, dotOnRight ? CGFloat(2) : CGFloat(5))
        .padding(.vertical, 1.5)
        .background(color)
        .clipShape(Capsule())
    }

    private func timelineDot(_ color: Color, _ size: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(Circle().fill(color).frame(width: 3, height: 3))
    }

    // The score button must not contain the separate service-side buttons.
    // Nested buttons merge competing click actions in Android semantics.
    private func playerScore(_ player: Player) -> some View {
        playerColumn(player)
    }

    private func playerColumn(_ player: Player) -> some View {
        let color = player == .player1 ? SharedColors.accent : SharedColors.steelBlue
        let score = player == .player1 ? game.player1Score : game.player2Score
        let isServing = game.currentServer == player
        let isScoring = game.selectedPlayer == player
        let highlight = ServerHighlight(color: color, isServer: isServing)

        return VStack(spacing: 4) {
            // Avatar and name start a point too, as the whole column does on iOS
            Button(action: { onSelectPlayer?(player) }) {
                VStack(spacing: 4) {
                    PlayerAvatarPlaceholder(color: color, size: 34, active: isServing, photo: photo(for: player))
                    Text(game.name(for: player))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(highlight.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(game.isGameOver)

            ServiceSideSelector(
                side: game.serverSide,
                preferredSide: game.preferredSide(for: player),
                color: color,
                compact: true,
                disabled: game.isGameOver
            ) { side in
                withAnimation(.easeInOut(duration: 0.15)) { game.overrideSide(to: side) }
                onServiceChanged()
            }
            .opacity(isServing ? 1.0 : 0.0)
            .allowsHitTesting(isServing)
            // Invisible for the receiver: VoiceOver/TalkBack skip it too
            .accessibilityHidden(!isServing)

            Button(action: { onSelectPlayer?(player) }) {
                Text("\(score)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(highlight.score)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(game.isGameOver)
            .accessibilityLabel("Punt voor \(game.name(for: player))")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isScoring ? color.opacity(0.18) : (isServing ? color.opacity(0.06) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(isScoring ? 0.7 : 0.0), lineWidth: 1))
        )
    }
}


/// Coach mode's scoring screen, shared between iOS and Android. Reproduces
/// the app's "score-tap" flow (the default input mode — see
/// SquashAnalyzer/Views/ContentView.swift's `scoreTapStage`): tap a player's
/// score to start a point, then point type → zone (`CourtView`) → shot, one
/// step at a time in the middle of the screen.
///
/// Deliberately smaller than iOS's ContentView: no quick-entry mode, let
/// calls, coaching notes, badges, previous-game analysis, or share sheet —
/// this proves the core scoring loop works end to end on Android (state
/// machine + all three risky shared views + persistence), matching the scope
/// cut already made for phase 5's Spelers (no photos/badges/team-import).
public struct CoachScoringView: View {
    /// Observed, not owned: the session owns the match (a new match is a new value here)
    let match: Match
    let aiCoach: AICoachContext?
    let shareText: ((String) -> Void)?
    let onMatchChanged: (Match) -> Void
    /// Photos of the picked players, by player id
    let photos: [String: Data]
    /// "Bewaar en ga later verder": saved, resumed from the Coach tile
    let onExit: () -> Void
    /// "Opslaan als incompleet"
    let onAbandon: (() -> Void)?
    /// "Niet opslaan"
    let onDiscard: (() -> Void)?
    /// "Nieuwe wedstrijd" on the match-over card; nil shows "Klaar" (back home)
    let onNewMatch: (() -> Void)?
    /// Afgeronde wedstrijden and Instellingen from the header, as on iOS; nil hides the button
    let onHistory: (() -> Void)?
    let onSettings: (() -> Void)?
    @State private var showingStop = false
    @State private var showingLet = false
    @State private var showingComplete = false
    /// Badges earned in this match, worked out once when the match ends
    @State private var badgeEarnings: [MatchBadgeEarning] = []
    /// The finished game shown in the analysis sheet
    @State private var analysedGame: Game?
    @State private var showingAnalysis = false
    @State private var showingShare = false
    @State private var showingBadges = false
    /// 6 or 9 zones, a setting (Instellingen)
    @AppStorage(CourtLayout.storageKey) private var courtLayout = CourtLayout.six.rawValue
    /// "Uit de lucht" for the point being entered; off again after every point
    @State private var volley = false
    /// Down / Out / Service / Grond for an unforced error; cleared after every point

    public init(match: Match, aiCoach: AICoachContext? = nil, shareText: ((String) -> Void)? = nil,
                photos: [String: Data] = [:],
                onMatchChanged: @escaping (Match) -> Void, onAbandon: (() -> Void)? = nil, onDiscard: (() -> Void)? = nil,
                onHistory: (() -> Void)? = nil, onSettings: (() -> Void)? = nil, onNewMatch: (() -> Void)? = nil,
                onExit: @escaping () -> Void) {
        self.match = match
        self.onNewMatch = onNewMatch
        self.onHistory = onHistory
        self.onSettings = onSettings
        self.photos = photos
        self.onAbandon = onAbandon
        self.onDiscard = onDiscard
        self.aiCoach = aiCoach
        self.shareText = shareText
        self.onMatchChanged = onMatchChanged
        self.onExit = onExit
    }

    private var game: Game { match.currentGame }

    public var body: some View {
        ZStack {
            GlowBackground()

            VStack(spacing: 12) {
                header
                SharedScoreboardView(game: game, match: match, photos: photos, onServiceChanged: { matchChanged() }) { player in handleScoreTap(player) }
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    RallyClock(game: game, hidden: game.isGameOver || match.isMatchOver)
                    instructionText
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .frame(height: 28)

                if match.isMatchOver || game.isGameOver {
                    // The result card covers the screen (see resultCard)
                    Spacer(minLength: 0)
                } else {
                    scoreTapStage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                bottomActions
                    .padding(.horizontal, 24)
                lastPointLine
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)

            if match.isMatchOver || game.isGameOver {
                resultCard
            }
            if showingLet {
                letOverlay
            }
            if showingStop {
                stopOverlay
            }
            if showingComplete {
                SharedCompleteResultView(match: match, onSave: { winners in
                    if match.completeResult(with: winners) {
                        showingComplete = false
                        // Saved and on to a new match, as on iOS
                        if let onNewMatch { onNewMatch() } else { matchChanged() }
                    }
                }, onCancel: { showingComplete = false })
            }
        }
        .task(id: match.isMatchOver) {
            badgeEarnings = computeBadgeEarnings()
        }
        .sheet(isPresented: $showingAnalysis) {
            SharedCoachDashboardView(match: match, game: analysedGame ?? game, aiCoach: aiCoach, shareText: shareText) {
                showingAnalysis = false
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Coach")
                .font(PageTitleStyle.font)
                .foregroundColor(SharedColors.textPrimary)
                .lineLimit(1)
            HStack {
                Button { requestStop() } label: {
                    HStack(spacing: 4) {
                        AppSymbol("xmark", size: 14, color: SharedColors.textSecondary)
                        Text("Stop")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textSecondary)
                }
                if !match.isMatchOver {
                    LiveShareButton(matchId: match.id, snapshot: { match.liveSnapshot() }, share: shareText)
                }
                Spacer()
                // The previous game's analysis while playing, from game 2 on (as on iOS)
                if match.currentGameIndex > 0 && !game.isGameOver && !match.isMatchOver {
                    Button {
                        analysedGame = match.games[match.currentGameIndex - 1]
                        showingAnalysis = true
                    } label: {
                        AppSymbol("chart.bar.xaxis", size: 18, color: SharedColors.gold)
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Analyse vorige game")
                }
                if let onHistory {
                    Button(action: onHistory) {
                        AppSymbol("clock.arrow.circlepath", size: 20, color: SharedColors.textSecondary)
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Afgeronde wedstrijden")
                }
                if let onSettings {
                    Button(action: onSettings) {
                        AppSymbol("gearshape", size: 20, color: SharedColors.textSecondary)
                            .frame(width: 36, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Instellingen")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Instruction text

    private var instructionText: some View {
        Group {
            if match.isMatchOver || game.isGameOver {
                EmptyView()
            } else {
                switch game.scoringStep {
                case .selectPlayer:
                    Text(game.isStarted ? "Tik op de score van wie scoort" : "Tik START bij de eerste service")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textSecondary)
                case .selectPointType:
                    Text("Hoe werd het punt gewonnen?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                case .selectErrorKind:
                    Text("Wat voor fout was het?")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                case .selectZone:
                    Text("Tik op de baan waar het punt viel")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                case .selectShot:
                    Text("Kies het type slag")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                }
            }
        }
    }

    private var playerColor: Color {
        game.selectedPlayer == .player1 ? SharedColors.accent : SharedColors.steelBlue
    }

    // MARK: - Score-tap flow (staged middle area, mirrors ContentView.scoreTapStage)

    @ViewBuilder
    private var scoreTapStage: some View {
        switch game.scoringStep {
        case .selectPlayer:
            VStack {
                Spacer(minLength: 0)
                if !game.isStarted && !game.isGameOver && !match.isMatchOver {
                    startButton
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        case .selectPointType:
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(PointType.allCases) { type in
                    if !type.serverOnly || game.selectedPlayer == game.currentServer {
                        PointTypeButton(pointType: type, color: playerColor, compact: true) {
                            selectPointType(type)
                        }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        case .selectErrorKind:
            // How the unforced error went wrong; no court for an unforced error
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                ErrorKindPicker(available: game.errorKindOptions(whenScoring: game.selectedPlayer ?? Player.player1),
                                color: playerColor) { kind in
                    handleErrorKind(kind)
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        case .selectZone:
            // The court gets an exact size that fits above the cancel button
            GeometryReader { geometry in
                let court = CourtView.fittedSize(in: CGSize(width: geometry.size.width - 32,
                                                            height: geometry.size.height - 50))
                VStack(spacing: 10) {
                    CourtView(isInteractive: true, selectedPlayer: game.selectedPlayer,
                              layout: CourtLayout.from(stored: courtLayout)) { zone in
                        handleZoneTap(zone)
                    }
                    .frame(width: court.width, height: court.height)
                    cancelButton
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        case .selectShot:
            VStack(spacing: 12) {
                Spacer(minLength: 0)
                if let zone = game.selectedZone {
                    Text(zone.rawValue.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(playerColor)
                        .tracking(1.5)
                }
                VolleyToggle(isOn: $volley, color: playerColor)
                // The shots that fit the zone's row: 3 in a row, or 4 as 2×2.
                // Two plain rows, not a nested ForEach (Skip mixes up captured
                // values in nested loops, see docs/android-port.md).
                let rows = ShotType.rows(ShotType.options(for: game.selectedZone))
                if rows.count > 0 {
                    HStack(spacing: 12) {
                        ForEach(rows[0]) { shot in
                            ShotTypeButton(shotType: shot, color: playerColor) { handleShotTypeSelect(shot) }
                        }
                    }
                }
                if rows.count > 1 {
                    HStack(spacing: 12) {
                        ForEach(rows[1]) { shot in
                            ShotTypeButton(shotType: shot, color: playerColor) { handleShotTypeSelect(shot) }
                        }
                    }
                }
                cancelButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }

    /// START at the first serve of a game: from then the rally clock runs, so
    /// the warm-up and the break between games never count as a rally
    private var startButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                game.start()
            }
            matchChanged()
        }) {
            HStack(spacing: 10) {
                AppSymbol("play.fill", size: 16, color: Color.black.opacity(0.8))
                Text("START GAME \(match.currentGameNumber)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(Color.black.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(SharedColors.gold)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start game \(match.currentGameNumber)")
    }

    /// Save (the session's store) and send the new state to live viewers
    private func matchChanged() {
        onMatchChanged(match)
        LiveShareSync.send(matchId: match.id, snapshot: match.liveSnapshot())
    }

    private var cancelButton: some View {
        Button(action: {
            game.clearSelection()
            volley = false
        }) {
            Text("Annuleer")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(SharedColors.textMuted)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Game / match over

    // MARK: - Result card (as on iOS)

    private func photo(_ player: Player) -> Data? {
        PlayerPhotos.photo(in: photos, id: player == Player.player1 ? match.player1Id : match.player2Id, name: match.name(for: player))
    }

    private func computeBadgeEarnings() -> [MatchBadgeEarning] {
        guard match.isMatchOver else { return [] }
        return SharedMatchBadgesStrip.earnings(player1Id: match.player1Id, player1Name: match.player1Name,
                                               player2Id: match.player2Id, player2Name: match.player2Name,
                                               badgeInput: match.badgeInput)
    }

    /// Game over and match over, the same card as iOS' GameOverOverlay
    private var resultCard: some View {
        var secondary: [ResultButton] = [ResultButton("Analyse", icon: "chart.bar.xaxis") {
            analysedGame = game
            showingAnalysis = true
        }]
        if shareText != nil {
            secondary.append(ResultButton("Deel score", icon: "square.and.arrow.up") { showingShare = true })
        }
        let primary: ResultButton
        if match.isMatchOver {
            if let onNewMatch {
                primary = ResultButton("Nieuwe wedstrijd") { onNewMatch() }
            } else {
                primary = ResultButton("Klaar") { onExit() }
            }
        } else {
            primary = ResultButton("Volgende game") {
                match.onGameEnd()
                matchChanged()
            }
        }
        return MatchResultOverlay(
            result: MatchResult.coach(match, game: game),
            player1Photo: photo(Player.player1), player2Photo: photo(Player.player2),
            badgeEarnings: badgeEarnings, onBadges: { showingBadges = true },
            secondary: secondary, primary: primary,
            onUndo: {
                // Back in play: the match is no longer finished
                match.status = MatchStatus.inProgress
                game.undoLastPoint()
                matchChanged()
            },
            link: match.isMatchOver ? nil : ResultButton("Stop wedstrijd") { requestStop() }
        )
        .sheet(isPresented: $showingShare) {
            if let shareText {
                SharedMatchShareView(report: match.shareReport, player1Photo: photo(Player.player1), player2Photo: photo(Player.player2),
                                     shareText: shareText) { showingShare = false }
            }
        }
        .sheet(isPresented: $showingBadges) {
            SharedMatchBadgesSheet(earnings: badgeEarnings) { showingBadges = false }
        }
    }

    // MARK: - Rally timer, last point, let and stop


    /// "Gerard: Winner · Volley drop · Voor Links" (Core's Point.summary, as on iOS)
    private var lastPointLine: some View {
        Group {
            // Coloured dot and hidden while a point is entered, as on iOS
            if let last = game.points.last, game.selectedPlayer == nil {
                HStack(spacing: 6) {
                    Circle()
                        .fill(last.scorer == Player.player1 ? SharedColors.accent : SharedColors.steelBlue)
                        .frame(width: 6, height: 6)
                    Text("\(game.name(for: last.scorer)): \(last.summary)")
                }
            } else {
                Text(" ")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(SharedColors.textMuted)
        .lineLimit(1)
        .frame(height: 16)
    }

    /// "Wie vraagt de let?", as iOS' LetSelectorOverlay: tapping beside it cancels
    private var letOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { showingLet = false }
            VStack(spacing: 20) {
                Text("LET")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundColor(SharedColors.gold)
                Text("Wie vraagt de let?")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SharedColors.textSecondary)
                HStack(spacing: 16) {
                    letButton(Player.player1, SharedColors.accent)
                    letButton(Player.player2, SharedColors.steelBlue)
                }
                if game.totalLets > 0 {
                    Text("Lets deze game: \(game.totalLets)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(SharedColors.textMuted)
                }
                Button { showingLet = false } label: {
                    Text("Annuleren")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(SharedColors.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(SharedColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(SharedColors.gold.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 40)
        }
    }

    private func letButton(_ player: Player, _ color: Color) -> some View {
        Button { callLet(player) } label: {
            VStack(spacing: 8) {
                AppSymbol("arrow.counterclockwise", size: 24, color: SharedColors.textPrimary)
                Text(match.name(for: player))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(SharedColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func callLet(_ player: Player) {
        game.addLet(requestedBy: player)
        showingLet = false
        matchChanged()
    }

    /// Stop, as on iOS (Core's Match.stopAction): a finished match is saved
    /// and closed, an empty one dropped, anything else asks
    private func requestStop() {
        switch match.stopAction {
        case .finish:
            onExit()
        case .discard:
            stopLive()
            if let onDiscard { onDiscard() } else { onExit() }
        case .ask:
            showingStop = true
        }
    }

    /// The match ends here without a final score: viewers see it is over
    private func stopLive() {
        guard LiveShare.shared.isLive(match.id) else { return }
        Task { await LiveShare.shared.stop() }
    }

    private var stopOverlay: some View {
        overlayCard {
            Text(Match.stopTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(SharedColors.textPrimary)
            Text(match.stopMessage)
                .font(.system(size: 13))
                .foregroundColor(SharedColors.textSecondary)
                .multilineTextAlignment(.center)
            overlayButton("Bewaar en ga later verder", SharedColors.accent) {
                showingStop = false
                onExit()
            }
            if let onAbandon {
                overlayButton("Opslaan als incompleet", SharedColors.textSecondary) {
                    showingStop = false
                    stopLive()
                    onAbandon()
                }
            }
            overlayButton("Uitslag aanvullen", SharedColors.textSecondary) {
                showingStop = false
                showingComplete = true
            }
            if let onDiscard {
                overlayButton("Niet opslaan", SharedColors.error) {
                    showingStop = false
                    stopLive()
                    onDiscard()
                }
            }
            Button("Doorspelen") { showingStop = false }
                .foregroundColor(SharedColors.textSecondary)
        }
    }

    private func overlayCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                content()
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20).fill(SharedColors.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(SharedColors.accent.opacity(0.4), lineWidth: 1))
            .padding(24)
        }
    }

    private func overlayButton(_ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack(spacing: 8) {
            coachActionButton("LET CALL", icon: "arrow.counterclockwise",
                              disabled: game.selectedPlayer != nil || game.isGameOver || match.isMatchOver) {
                showingLet = true
            }
            coachActionButton("UNDO", icon: "arrow.uturn.backward",
                              disabled: game.selectedZone != nil || !game.canUndo || match.isMatchOver) {
                game.undoLastPoint()
                matchChanged()
            }
        }
    }

    private func coachActionButton(_ title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AppSymbol(icon, size: 13, color: disabled ? SharedColors.textMuted : SharedColors.textPrimary)
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1)
            }
            .foregroundColor(disabled ? SharedColors.textMuted : SharedColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SharedColors.textPrimary.opacity(disabled ? 0.04 : 0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(SharedColors.textPrimary.opacity(disabled ? 0.08 : 0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Handlers (mirror ContentView.swift's coach handlers)

    private func handleScoreTap(_ player: Player) {
        guard !game.isGameOver else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if game.selectedPlayer == player {
                game.clearSelection()
            } else {
                game.selectPlayer(player)
            }
        }
    }

    private func selectPointType(_ pointType: PointType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            game.selectPointType(pointType)
        }
        if game.scoringStep == .selectPlayer {
            matchChanged()
        }
    }

    private func handleErrorKind(_ kind: ErrorKind?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            game.selectErrorKind(kind)
        }
        matchChanged()
    }

    private func handleZoneTap(_ zone: CourtZone) {
        guard game.selectedPlayer != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            game.selectZone(zone)
        }
        if game.scoringStep == .selectPlayer {
            matchChanged()
        }
    }

    private func handleShotTypeSelect(_ shotType: ShotType) {
        withAnimation(.easeInOut(duration: 0.2)) {
            game.addPoint(shotType: shotType, isVolley: volley)
        }
        volley = false
        matchChanged()
    }
}

/// Time since the last point or let, like iOS' rally timer. A view of its own:
/// only this ticks every second, not the whole scoring screen (T18).
struct RallyClock: View {
    let game: Game
    let hidden: Bool
    @State private var now = Date()

    var body: some View {
        let seconds = Int(game.rallySeconds(at: now))
        let text = (seconds / 60 < 10 ? "0" : "") + "\(seconds / 60):" + (seconds % 60 < 10 ? "0" : "") + "\(seconds % 60)"
        return HStack(spacing: 6) {
            AppSymbol("timer", size: 12, color: SharedColors.gold.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
            Text("RALLY")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(SharedColors.textMuted)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(SharedColors.textSecondary)
            }
        }
        .opacity(hidden ? 0.0 : 1.0)
        .accessibilityLabel("Rallytijd \(text)")
        // Stops ticking while the game is over
        .task(id: hidden) {
            while !Task.isCancelled && !hidden {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                now = Date()
            }
        }
    }
}
