import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The Live Activity of a team match (Competitie): a row per partij E1–E4
/// with both players (photo or first letter), their games and in the middle
/// the points of a partij under way, and below a bar with the team names and
/// the games per team. Home orange, away steel blue, as on the team page.
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
                        LiveScorePill(text: state.isFinished ? "AFGELOPEN" : "LIVE", live: !state.isFinished)
                    }
                        .padding(.leading, 6)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.progressText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(LiveScoreColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.trailing, 6)
                        .frame(maxHeight: .infinity)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // The team line and four short rows: the expanded island is about 160 pt high in all
                    VStack(spacing: 1) {
                        TeamScoreTeamLine(state: state, nameSize: 13, boxSize: 13)
                            .frame(height: 20)
                            .padding(.bottom, 1)
                        ForEach(TeamScoreAttributes.ContentState.slots, id: \.self) { slot in
                            TeamScoreRow(state: state, slot: slot, photos: photos, height: 18, avatar: 15, nameSize: 12,
                                         boxSize: 10)
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
                    Text("\(state.games(1))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(LiveScoreColors.player1)
                }
            } compactTrailing: {
                Text("\(state.games(2))")
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

/// The lock screen card: a row per partij E1–E4 (both players, their games,
/// the points of a partij under way), and a bar along the bottom with the
/// mark with a red live dot, the team names and the games per team (design
/// "variant 3b" with proposal B, 18 October 2026). The system clips a Live Activity at about
/// 160 pt: four rows of 25 and the bar of 40 make about 156 with the padding.
struct TeamScoreLockScreenView: View {
    let state: TeamScoreAttributes.ContentState
    let photos: TeamScorePhotos

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(TeamScoreAttributes.ContentState.slots, id: \.self) { slot in
                    TeamScoreRow(state: state, slot: slot, photos: photos, height: 25, avatar: 20, nameSize: 14, boxSize: 12)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 7)
            .padding(.bottom, 5)
            bar
        }
        .overlay(
            ContainerRelativeShape()
                .stroke(LiveScoreColors.line, lineWidth: 1)
        )
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
            TeamScoreTeamLine(state: state, nameSize: 14, boxSize: 15)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(LiveScoreColors.accent.opacity(0.08))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LiveScoreColors.line)
                .frame(height: 1)
        }
    }
}

/// Home name left, the games of both teams exactly in the middle (the same
/// axis as the middle of the partij rows), away name right; long names are cut off
struct TeamScoreTeamLine: View {
    let state: TeamScoreAttributes.ContentState
    let nameSize: CGFloat
    let boxSize: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(state.home)
                .font(.system(size: nameSize, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.player1)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                TeamScoreGamesBox(games: state.games(1), side: 1, won: state.isFinished && state.teamWinner == 1, size: boxSize)
                Text("–")
                    .font(.system(size: boxSize - 1, weight: .bold, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary)
                TeamScoreGamesBox(games: state.games(2), side: 2, won: state.isFinished && state.teamWinner == 2, size: boxSize)
            }
            .fixedSize()
            Text(state.away)
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
struct TeamScoreRow: View {
    let state: TeamScoreAttributes.ContentState
    let slot: Int
    let photos: TeamScorePhotos
    let height: CGFloat
    let avatar: CGFloat
    let nameSize: CGFloat
    let boxSize: CGFloat

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
                // The red live dot leads the row, apart from the serve dots of a single match
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
                .frame(width: boxSize * 3.6)
            if let partij {
                TeamScoreGamesBox(games: partij.games(2), side: 2, won: partij.winnerSide == 2, size: boxSize)
            } else {
                TeamScoreGamesBox(games: nil, side: 2, won: false, size: boxSize)
            }
        }
        .fixedSize()
    }

    private var isLive: Bool {
        if case .live = state.middle(slot) { return true }
        return false
    }

    @ViewBuilder
    private var middle: some View {
        switch state.middle(slot) {
        case .live(let points):
            Text(points)
                .font(.system(size: boxSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(LiveScoreColors.live)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .decided:
            Text("klaar")
                .font(.system(size: boxSize - 1, weight: .medium, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
                .lineLimit(1)
        case .none:
            Text("–")
                .font(.system(size: boxSize, weight: .medium, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
        }
    }
}

/// Games in a small box: home orange, away blue; the winner's box is filled
/// in its colour. No games (no partij yet): "–", greyed.
struct TeamScoreGamesBox: View {
    let games: Int?
    let side: Int
    let won: Bool
    let size: CGFloat

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
            .accessibilityLabel(games.map { value in "\(value) games" } ?? "nog niet begonnen")
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
