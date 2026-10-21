import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The Live Activity of a team match (Competitie), design B (20 October
/// 2026): at the top the partij under way, large (two courts: two compact
/// rows), below it a strip E1–E4 with the result of each partij, and a bar
/// with the team names and the partijen per team (SBN: partijen first,
/// games second). All four decided: the four results as rows. Home orange,
/// away steel blue, as on the team page.
struct TeamScoreActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeamScoreAttributes.self) { context in
            TeamScoreLockScreenView(state: context.state, photos: TeamScorePhotos(teamId: context.attributes.teamId))
                .activityBackgroundTint(LiveScoreColors.card)
                .activitySystemActionForegroundColor(LiveScoreColors.textPrimary)
        } dynamicIsland: { context in
            let state = context.state
            let photos = TeamScorePhotos(teamId: context.attributes.teamId)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        LiveScoreMark(size: 12)
                        LiveScorePill(text: state.isFinished ? String(localized: "AFGELOPEN") : "LIVE", live: !state.isFinished)
                    }
                        .padding(.leading, 6)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.islandStatus)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(state.livePartijen.isEmpty ? LiveScoreColors.textSecondary : LiveScoreColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.trailing, 6)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // The team line with the partijen, then the partij(en) under way, or the strip E1–E4
                    VStack(spacing: 4) {
                        TeamScoreTeamLine(state: state, nameSize: 13, boxSize: 13, caption: false)
                            .frame(height: 20)
                        let live = state.livePartijen.prefix(2)
                        if live.isEmpty {
                            TeamScoreStrip(state: state, height: 20, size: 10)
                        } else {
                            ForEach(Array(live), id: \.slot) { partij in
                                TeamScoreRow(state: state, slot: partij.slot, photos: photos, height: 20, avatar: 16, nameSize: 12,
                                             boxSize: 11)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    if !state.isFinished {
                        Circle()
                            .fill(LiveScoreColors.live)
                            .frame(width: 6, height: 6)
                    }
                    Text("\(state.partijenWon(1))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(LiveScoreColors.player1)
                }
            } compactTrailing: {
                Text("\(state.partijenWon(2))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.player2Text)
            } minimal: {
                Text(state.minimalText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.player1)
                    .minimumScaleFactor(0.7)
            }
            .keylineTint(LiveScoreColors.accent)
        }
    }
}

/// The partij photos the app stored for this team match (TeamScorePhotoStore)
struct TeamScorePhotos {
    private let images: [String: UIImage]

    init(teamId: String) {
        var found: [String: UIImage] = [:]
        for slot in TeamScoreAttributes.ContentState.slots {
            for side in [1, 2] {
                if let image = LiveScorePhotoStore.image(matchId: TeamScorePhotoStore.key(teamId: teamId, slot: slot), player: side) {
                    found["\(slot)-\(side)"] = image
                }
            }
        }
        images = found
    }

    func photo(slot: Int, side: Int) -> UIImage? { images["\(slot)-\(side)"] }
}

/// The lock screen card (design B). During the evening: the partij under way
/// large (heading, both players, the points in the middle), or two compact
/// rows when two courts play at once, or the next partij; then the strip
/// E1–E4. All four decided: a row per partij with the games. Along the
/// bottom the bar with the mark, a red live dot and the partijen per team.
/// The system clips a Live Activity at about 160 pt: top 66 + strip 30 + bar 44.
struct TeamScoreLockScreenView: View {
    let state: TeamScoreAttributes.ContentState
    let photos: TeamScorePhotos

    var body: some View {
        VStack(spacing: 0) {
            switch state.focus {
            case .finished:
                VStack(spacing: 0) {
                    ForEach(TeamScoreAttributes.ContentState.slots, id: \.self) { slot in
                        TeamScoreRow(state: state, slot: slot, photos: photos, height: 25, avatar: 20, nameSize: 14, boxSize: 12)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 7)
                .padding(.bottom, 5)
            case .live(let live) where live.count > 1:
                VStack(spacing: 2) {
                    ForEach(Array(live.prefix(2)), id: \.slot) { partij in
                        TeamScoreRow(state: state, slot: partij.slot, photos: photos, height: 28, avatar: 22, nameSize: 14,
                                     boxSize: 13, pointsSize: 18)
                    }
                }
                .frame(height: 62)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                strip
            case .live(let live):
                TeamScoreFocusView(state: state, slot: live[0].slot, photos: photos)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                strip
            case .next(let slot):
                TeamScoreFocusView(state: state, slot: slot, photos: photos)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                strip
            }
            bar
        }
        .overlay(
            ContainerRelativeShape()
                .stroke(LiveScoreColors.line, lineWidth: 1)
        )
    }

    private var strip: some View {
        TeamScoreStrip(state: state, height: 22, size: 12)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private var bar: some View {
        HStack(spacing: 8) {
            // A red dot instead of the LIVE pill, so long team names keep their room
            HStack(spacing: 5) {
                LiveScoreMark(size: 16)
                Circle()
                    .fill(LiveScoreColors.live)
                    .frame(width: 7, height: 7)
                    .opacity(state.isFinished ? 0 : 1)
                    .accessibilityLabel("Live")
                    .accessibilityHidden(state.isFinished)
            }
            TeamScoreTeamLine(state: state, nameSize: 14, boxSize: 15, caption: true)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(LiveScoreColors.accent.opacity(0.08))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LiveScoreColors.line)
                .frame(height: 1)
        }
    }
}

/// The partij at the top: "● E3 · bezig" with "games 1–1" on the right, and
/// below it the home player (photo, name), the points large in the middle
/// ("pauze" between games) and the away player. The serve dot (gold) only
/// when the push says who serves.
struct TeamScoreFocusView: View {
    let state: TeamScoreAttributes.ContentState
    let slot: Int
    let photos: TeamScorePhotos

    private var partij: TeamScorePartij? { state.partij(slot) }
    private var isLive: Bool { partij?.isLive == true }
    private var isPause: Bool { partij?.isPause == true }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                if isLive {
                    Circle()
                        .fill(isPause ? LiveScoreColors.textSecondary : LiveScoreColors.live)
                        .frame(width: 6, height: 6)
                }
                Text(state.focusHeading(slot))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isLive && !isPause ? LiveScoreColors.live : LiveScoreColors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(isLive ? state.gamesText(slot) : state.progressText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(height: 16)
            if partij == nil {
                Text("spelers nog niet bekend")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            } else {
                HStack(spacing: 8) {
                    player(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    centre
                        .fixedSize()
                    player(2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: 40)
            }
        }
    }

    private func player(_ side: Int) -> some View {
        let avatar = ZStack(alignment: side == 1 ? .bottomTrailing : .bottomLeading) {
            TeamScoreAvatar(initial: state.initial(slot: slot, side: side), side: side, photo: photos.photo(slot: slot, side: side),
                            size: 32, empty: false)
            Circle()
                .fill(LiveScoreColors.gold)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(LiveScoreColors.card, lineWidth: 2))
                .offset(x: side == 1 ? 2 : -2, y: 2)
                .opacity(partij?.isServing(side) == true ? 1 : 0)
                .accessibilityHidden(true)
        }
        let name = Text(state.name(slot: slot, side: side))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(LiveScoreColors.playerText(side).opacity(state.hasName(slot: slot, side: side) ? 1 : 0.6))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        return HStack(spacing: 7) {
            if side == 1 {
                avatar
                name
            } else {
                name
                avatar
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.name(slot: slot, side: side) + (partij?.isServing(side) == true ? String(localized: ", serveert") : ""))
    }

    @ViewBuilder
    private var centre: some View {
        if let partij, partij.isPause {
            Text("pauze")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
        } else if let partij, partij.isLive {
            // The same points as a single match's lock screen: white, the dash grey
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(partij.points(1))")
                Text("–")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary)
                Text("\(partij.points(2))")
            }
            .font(.system(size: 40, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(LiveScoreColors.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("–")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
        }
    }
}

/// Four boxes E1–E4: a decided partij filled in the winner's colour with its
/// games ("3–0", home first) or "w.o." / "opgave"; one under way outlined red
/// with "bezig"; one not started grey with "–"
struct TeamScoreStrip: View {
    let state: TeamScoreAttributes.ContentState
    let height: CGFloat
    let size: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TeamScoreAttributes.ContentState.slots, id: \.self) { slot in
                tile(slot)
            }
        }
    }

    private func tile(_ slot: Int) -> some View {
        let tile = state.tile(slot)
        let colour: Color
        let fill: Color
        let line: Color
        let text: String
        switch tile {
        case .decided(let winner, let result):
            colour = winner == 0 ? LiveScoreColors.textSecondary : LiveScoreColors.playerText(winner)
            fill = winner == 0 ? Color.clear : colour.opacity(0.2)
            line = winner == 0 ? LiveScoreColors.border : colour
            text = result
        case .live:
            colour = LiveScoreColors.live
            fill = LiveScoreColors.live.opacity(0.1)
            line = LiveScoreColors.live
            text = String(localized: "bezig")
        case .waiting:
            colour = LiveScoreColors.textSecondary.opacity(0.7)
            fill = Color.clear
            line = LiveScoreColors.border
            text = "–"
        }
        return HStack(spacing: 4) {
            Text("E\(slot)")
                .font(.system(size: size - 2, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(colour)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: height * 0.3))
        .overlay(RoundedRectangle(cornerRadius: height * 0.3).stroke(line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("E\(slot): " + text)
    }
}

/// Home name left, the partijen of both teams exactly in the middle (with
/// "partijen" under them on the lock screen), away name right; long names
/// shrink, then are cut off. The winner's box is filled at the end.
struct TeamScoreTeamLine: View {
    let state: TeamScoreAttributes.ContentState
    let nameSize: CGFloat
    let boxSize: CGFloat
    let caption: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(state.teamName(1))
                .font(.system(size: nameSize, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.player1)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 1) {
                HStack(spacing: 6) {
                    TeamScoreGamesBox(games: state.partijenWon(1), side: 1, won: state.isFinished && state.teamWinner == 1,
                                      size: boxSize, unit: String(localized: "partijen"))
                    Text("–")
                        .font(.system(size: boxSize - 1, weight: .bold, design: .rounded))
                        .foregroundColor(LiveScoreColors.textSecondary)
                    TeamScoreGamesBox(games: state.partijenWon(2), side: 2, won: state.isFinished && state.teamWinner == 2,
                                      size: boxSize, unit: String(localized: "partijen"))
                }
                if caption {
                    Text("partijen")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(LiveScoreColors.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .fixedSize()
            Text(state.teamName(2))
                .font(.system(size: nameSize, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.player2Text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

/// One partij: "E1", home avatar and name, the games with the middle text,
/// the away name and avatar. A slot without a partij is greyed with "–".
/// Used for the results at the end, for two partijen at once and in the
/// expanded Dynamic Island.
struct TeamScoreRow: View {
    let state: TeamScoreAttributes.ContentState
    let slot: Int
    let photos: TeamScorePhotos
    let height: CGFloat
    let avatar: CGFloat
    let nameSize: CGFloat
    let boxSize: CGFloat
    /// The size of the live points; the box size when nil
    var pointsSize: CGFloat? = nil

    var body: some View {
        if state.partij(slot) == nil {
            waiting
        } else {
            row
        }
    }

    /// A slot nobody plays yet: the team names are in the bar already, so
    /// "nog niet begonnen" instead of "Delft 8 E2" four times over
    private var waiting: some View {
        ZStack {
            Text("nog niet begonnen")
                .font(.system(size: nameSize - 2, weight: .medium, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary.opacity(0.7))
                .lineLimit(1)
            HStack(spacing: 0) {
                Text("E\(slot)")
                    .font(.system(size: boxSize - 1, weight: .semibold, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
    }

    private var row: some View {
        let partij = state.partij(slot)
        // Both sides get the same width, so the middle sits on the card's centre line
        return HStack(spacing: 5) {
            HStack(spacing: 5) {
                // The red live dot leads the row
                HStack(spacing: 3) {
                    Circle()
                        .fill(isLive ? LiveScoreColors.live : Color.clear)
                        .frame(width: 5, height: 5)
                    Text("E\(slot)")
                        .font(.system(size: boxSize - 1, weight: .semibold, design: .rounded))
                        .foregroundColor(isLive ? LiveScoreColors.live : LiveScoreColors.textSecondary)
                }
                .frame(width: boxSize * 1.6 + 8, alignment: .leading)
                TeamScoreAvatar(initial: state.initial(slot: slot, side: 1), side: 1, photo: photos.photo(slot: slot, side: 1),
                                size: avatar, empty: partij == nil)
                name(1, partij: partij)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            centre(partij)
            HStack(spacing: 5) {
                name(2, partij: partij)
                TeamScoreAvatar(initial: state.initial(slot: slot, side: 2), side: 2, photo: photos.photo(slot: slot, side: 2),
                                size: avatar, empty: partij == nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: height)
    }

    private func name(_ side: Int, partij: TeamScorePartij?) -> some View {
        let won = partij?.winnerSide == side
        // No partij yet: grey; a partij without this name ("Delft 8 E2"): the team colour, dimmed
        let colour = partij == nil ? LiveScoreColors.textSecondary.opacity(0.6)
            : LiveScoreColors.playerText(side).opacity(state.hasName(slot: slot, side: side) ? 1 : 0.6)
        return Text(state.name(slot: slot, side: side))
            .font(.system(size: nameSize, weight: won ? .bold : .semibold, design: .rounded))
            .foregroundColor(colour)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private func centre(_ partij: TeamScorePartij?) -> some View {
        HStack(spacing: 4) {
            if let partij {
                TeamScoreGamesBox(games: partij.games(1), side: 1, won: partij.winnerSide == 1, size: boxSize)
            } else {
                TeamScoreGamesBox(games: nil, side: 1, won: false, size: boxSize)
            }
            middle
                .frame(width: max(boxSize * 3.6, (pointsSize ?? boxSize) * 2.8))
            if let partij {
                TeamScoreGamesBox(games: partij.games(2), side: 2, won: partij.winnerSide == 2, size: boxSize)
            } else {
                TeamScoreGamesBox(games: nil, side: 2, won: false, size: boxSize)
            }
        }
        .fixedSize()
    }

    private var isLive: Bool {
        switch state.middle(slot) {
        case .live, .pause: return true
        default: return false
        }
    }

    @ViewBuilder
    private var middle: some View {
        switch state.middle(slot) {
        case .live(let points):
            Text(points)
                .font(.system(size: pointsSize ?? boxSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(LiveScoreColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .pause:
            Text("pauze")
                .font(.system(size: boxSize - 1, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
                .lineLimit(1)
        case .decided(let end):
            Text(end ?? "–")
                .font(.system(size: boxSize - 1, weight: end == nil ? .bold : .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
                .lineLimit(1)
        case .none:
            Text("–")
                .font(.system(size: boxSize, weight: .medium, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
        }
    }
}

/// A number in a small box: home orange, away blue; the winner's box is
/// filled in its colour. No number (no partij yet): "–", greyed.
struct TeamScoreGamesBox: View {
    let games: Int?
    let side: Int
    let won: Bool
    let size: CGFloat
    /// What the number counts, for VoiceOver
    var unit: String = "games"

    var body: some View {
        let colour = LiveScoreColors.playerText(side)
        let line = side == 1 ? LiveScoreColors.line : LiveScoreColors.player2Line
        Text(games.map { value in "\(value)" } ?? "–")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(won ? colour : (games == nil ? LiveScoreColors.textSecondary.opacity(0.6) : LiveScoreColors.textSecondary))
            // Room for two digits, so both boxes stay equally wide around the centre
            .frame(minWidth: size * 1.3)
            .padding(.horizontal, size * 0.3)
            .padding(.vertical, size * 0.08)
            .background(won ? colour.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.45))
            .overlay(RoundedRectangle(cornerRadius: size * 0.45)
                .stroke(won ? colour : (games == nil ? LiveScoreColors.border : line), lineWidth: 1))
            .accessibilityLabel(games.map { value in "\(value) \(unit)" } ?? String(localized: "nog niet begonnen"))
    }
}

/// A round partij photo with a ring in the team colour, or the first letter
struct TeamScoreAvatar: View {
    let initial: String
    let side: Int
    let photo: UIImage?
    let size: CGFloat
    let empty: Bool

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initial)
                    .font(.system(size: size * 0.48, weight: .bold, design: .rounded))
                    .foregroundColor(LiveScoreColors.playerText(side))
            }
        }
        .frame(width: size, height: size)
        .background(LiveScoreColors.card)
        .clipShape(Circle())
        .overlay(Circle().stroke(empty ? LiveScoreColors.border : LiveScoreColors.ring(side), lineWidth: 1.5))
        .accessibilityHidden(true)
    }
}
