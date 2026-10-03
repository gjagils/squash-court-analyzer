import SwiftUI
import SquashAnalyzerCore

/// Shown on the match-over screen when a picked player earned a badge this
/// match. Computed live from `BadgeEngine` — no store needed, since a
/// match's badges only depend on its own `badgeInput`. Named `Shared...`,
/// not `MatchBadgesStrip`, for the same reason as `SharedBadgeCatalogView`:
/// the iOS app target already has its own `MatchBadgesStrip`.
public struct SharedMatchBadgesStrip: View {
    let earnings: [MatchBadgeEarning]

    public init(earnings: [MatchBadgeEarning]) {
        self.earnings = earnings
    }

    public var body: some View {
        if !earnings.isEmpty {
            VStack(spacing: 10) {
                Text("BADGES VERDIEND")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(StripPalette.gold)
                ForEach(earnings) { earning in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(earning.name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(StripPalette.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(earning.badges) { badge in
                                    BadgeMedallion(kind: badge, size: 48, showsTitle: false)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Computes this match's badge earnings for its picked players (a typed-in
    /// name with no id earns nothing). Pure and store-free: both `Match` and
    /// `RefereeMatch` already expose `badgeInput`.
    public static func earnings(player1Id: UUID?, player1Name: String, player2Id: UUID?, player2Name: String,
                                 badgeInput: BadgeMatchInput) -> [MatchBadgeEarning] {
        let earnedByPlayer = BadgeEngine().badges(for: badgeInput)
        var result: [MatchBadgeEarning] = []
        if let id = player1Id, let earned = earnedByPlayer[.player1], !earned.isEmpty {
            result.append(MatchBadgeEarning(player: .player1, playerId: id, name: player1Name, badges: Array(earned)))
        }
        if let id = player2Id, let earned = earnedByPlayer[.player2], !earned.isEmpty {
            result.append(MatchBadgeEarning(player: .player2, playerId: id, name: player2Name, badges: Array(earned)))
        }
        return result
    }
}

private enum StripPalette {
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    static let textSecondary = Color(red: 0.70, green: 0.68, blue: 0.65)
}
