import Foundation

/// Represents a player in the game
public enum Player: String, CaseIterable, Identifiable, Codable {
    case player1 = "Speler 1"
    case player2 = "Speler 2"

    public var id: String { rawValue }

    public var opponent: Player {
        switch self {
        case .player1: return .player2
        case .player2: return .player1
        }
    }
}
