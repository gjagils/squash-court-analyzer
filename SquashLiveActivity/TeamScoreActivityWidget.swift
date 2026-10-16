import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// The Live Activity of a team match (Competitie): one card with the team
/// names and the games per team, and a row per partij E1–E4 with both players
/// (photo or first letter), their games and in the middle the points of a
/// partij under way. Home orange, away steel blue, as on the team page.
/// Design: canvas "Live score op vergrendelscherm", row "Teamwedstrijd · iPhone".
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
                    TeamScoreIslandTeam(state: state, side: 1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamScoreIslandTeam(state: state, side: 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.isFinished ? "AFGELOPEN" : state.progressText.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundColor(LiveScoreColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        ForEach(TeamScoreAttributes.ContentState.slots, id: \.self) { slot in
                            TeamScoreRow(state: state, slot: slot, photos: photos, height: 19, avatar: 16, nameSize: 12,
                                         boxSize: 11)
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

/// The lock screen card. The system clips a Live Activity at about 160 pt:
/// header 16, team line 22 and four rows of 24 make about 156 with the padding
struct TeamScoreLockScreenView: View {
    let state: TeamScoreAttributes.ContentState
    let photos: TeamScorePhotos

    var body: some View {
        VStack(spacing: 0) {
            header
            teamLine
                .padding(.top, 3)
                .padding(.bottom, 3)
            ForEach(TeamScoreAttributes.ContentState.slots, id: \.self) { slot in
                TeamScoreRow(state: state, slot: slot, photos: photos, height: 24, avatar: 20, nameSize: 14, boxSize: 12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(
            ContainerRelativeShape()
                .stroke(LiveScoreColors.line, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            if state.isFinished {
                LiveScorePill(text: "AFGELOPEN", live: false)
                LiveScoreStatusText(text: state.resultTitle, size: 11)
            } else {
                LiveScorePill(text: "LIVE", live: true)
                LiveScoreStatusText(text: "Competitie", size: 11)
                Spacer(minLength: 6)
                Text(state.progressText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(LiveScoreColors.textSecondary)
                    .lineLimit(1)
            }
            if state.isFinished { Spacer(minLength: 0) }
        }
        .frame(height: 16)
    }

    private var teamLine: some View {
        HStack(spacing: 6) {
            Text(state.home)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.player1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            TeamScoreGamesBox(games: state.games(1), side: 1, won: state.isFinished && state.teamWinner == 1, size: 15)
            Text("–")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
            TeamScoreGamesBox(games: state.games(2), side: 2, won: state.isFinished && state.teamWinner == 2, size: 15)
            Text(state.away)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(LiveScoreColors.player2Text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 22)
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
        let partij = state.partij(slot)
        HStack(spacing: 5) {
            Text("E\(slot)")
                .font(.system(size: boxSize - 1, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.textSecondary)
                .frame(width: boxSize * 1.6, alignment: .leading)
            TeamScoreAvatar(initial: state.initial(slot: slot, side: 1), side: 1, photo: photos.photo(slot: slot, side: 1),
                            size: avatar, empty: partij == nil)
            name(1, partij: partij)
                .frame(maxWidth: .infinity, alignment: .leading)
            centre(partij)
            name(2, partij: partij)
                .frame(maxWidth: .infinity, alignment: .trailing)
            TeamScoreAvatar(initial: state.initial(slot: slot, side: 2), side: 2, photo: photos.photo(slot: slot, side: 2),
                            size: avatar, empty: partij == nil)
        }
        .frame(height: height)
    }

    private func name(_ side: Int, partij: TeamScorePartij?) -> some View {
        let won = partij?.winnerSide == side
        let colour = partij == nil ? LiveScoreColors.textSecondary.opacity(0.6) : LiveScoreColors.playerText(side)
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

    @ViewBuilder
    private var middle: some View {
        switch state.middle(slot) {
        case .live(let points):
            HStack(spacing: 3) {
                Circle()
                    .fill(LiveScoreColors.live)
                    .frame(width: 5, height: 5)
                Text(points)
                    .font(.system(size: boxSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(LiveScoreColors.live)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
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
            .frame(minWidth: size * 1.1)
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

/// Team name and games in the expanded Dynamic Island
struct TeamScoreIslandTeam: View {
    let state: TeamScoreAttributes.ContentState
    let side: Int

    var body: some View {
        let leading = side == 1
        VStack(alignment: leading ? .leading : .trailing, spacing: 2) {
            Text(state.teamName(side))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(LiveScoreColors.playerText(side))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(state.games(side))")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(LiveScoreColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}
