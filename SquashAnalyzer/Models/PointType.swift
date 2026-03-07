import Foundation

/// The manner in which a point was won
enum PointType: String, CaseIterable, Identifiable, Codable {
    case winner = "Winner"
    case forcedError = "Forced Error"
    case unforcedError = "Unforced Error"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .winner: return "W"
        case .forcedError: return "FE"
        case .unforcedError: return "UE"
        }
    }

    var icon: String {
        switch self {
        case .winner: return "star.fill"
        case .forcedError: return "arrow.triangle.2.circlepath"
        case .unforcedError: return "xmark.circle"
        }
    }

    var description: String {
        switch self {
        case .winner: return "Winnende slag"
        case .forcedError: return "Fout door jouw druk"
        case .unforcedError: return "Fout zonder jouw druk"
        }
    }

    /// Whether this point type requires zone and shot type selection
    var requiresZoneAndShot: Bool {
        switch self {
        case .winner, .forcedError: return true
        case .unforcedError: return false
        }
    }
}
