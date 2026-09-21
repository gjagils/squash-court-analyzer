import Foundation

/// The manner in which a point was won
enum PointType: String, CaseIterable, Identifiable, Codable {
    case winner = "Winner"
    case forcedError = "Forced Error"
    case unforcedError = "Unforced Error"
    /// Point awarded by the referee after obstruction; recorded with the zone but no shot
    case stroke = "Stroke"
    /// Point straight from the serve (ace or unreturnable); the zone follows from the service box
    case servicePoint = "Service Point"

    var id: String { rawValue }

    /// Label on the point-type buttons
    var title: String {
        switch self {
        case .winner: return "Winner"
        case .forcedError: return "Forced error"
        case .unforcedError: return "Unforced error"
        case .stroke: return "Stroke"
        case .servicePoint: return "Servicepunt"
        }
    }

    var shortName: String {
        switch self {
        case .winner: return "W"
        case .forcedError: return "FE"
        case .unforcedError: return "UE"
        case .stroke: return "STR"
        case .servicePoint: return "SRV"
        }
    }

    var icon: String {
        switch self {
        case .winner: return "star.fill"
        case .forcedError: return "arrow.triangle.2.circlepath"
        case .unforcedError: return "xmark.circle"
        case .stroke: return "hand.raised.fill"
        case .servicePoint: return "figure.tennis"
        }
    }

    var description: String {
        switch self {
        case .winner: return "Winnende slag"
        case .forcedError: return "Fout door jouw druk"
        case .unforcedError: return "Fout zonder jouw druk"
        case .stroke: return "Punt na obstructie"
        case .servicePoint: return "Direct uit de service"
        }
    }

    /// Whether the coach marks where on the court the point was decided
    var requiresZone: Bool {
        switch self {
        case .winner, .forcedError, .stroke: return true
        case .unforcedError, .servicePoint: return false
        }
    }

    /// Whether the winning shot is recorded after the zone
    var requiresShot: Bool {
        switch self {
        case .winner, .forcedError: return true
        case .unforcedError, .stroke, .servicePoint: return false
        }
    }

    /// Only the server can win a point straight from the serve
    var serverOnly: Bool { self == .servicePoint }
}
