import Foundation

/// The manner in which a point was won
public enum PointType: String, CaseIterable, Identifiable, Codable {
    case winner = "Winner"
    case forcedError = "Forced Error"
    case unforcedError = "Unforced Error"
    /// Point awarded by the referee after obstruction; recorded with the zone but no shot
    case stroke = "Stroke"
    /// Point straight from the serve (ace or unreturnable); the zone follows from the service box
    case servicePoint = "Service Point"
    /// Simple coaching (Instellingen → Coachen: Eenvoudig): only who won the
    /// rally and where it ended, no winner/error and no shot. Counts as a point
    /// made at that zone, like a winner, but not as a winner.
    case rally = "Rally"

    public var id: String { rawValue }

    /// Label on the point-type buttons
    public var title: String {
        switch self {
        case .winner: return "Winner"
        case .forcedError: return "Forced error"
        case .unforcedError: return "Unforced error"
        case .stroke: return "Stroke"
        case .servicePoint: return L10n.text("Servicepunt")
        case .rally: return L10n.text("Punt")
        }
    }

    public var icon: String {
        switch self {
        case .winner: return "star.fill"
        case .forcedError: return "arrow.triangle.2.circlepath"
        case .unforcedError: return "xmark.circle"
        case .stroke: return "hand.raised.fill"
        case .servicePoint: return "figure.tennis"
        case .rally: return "mappin"
        }
    }

    public var description: String {
        switch self {
        case .winner: return L10n.text("Winnende slag")
        case .forcedError: return L10n.text("Fout door jouw druk")
        case .unforcedError: return L10n.text("Fout zonder jouw druk")
        case .stroke: return L10n.text("Punt na obstructie")
        case .servicePoint: return L10n.text("Direct uit de service")
        case .rally: return L10n.text("Alleen wie en waar")
        }
    }

    /// Whether the coach marks where on the court the point was decided
    public var requiresZone: Bool {
        switch self {
        case .winner, .forcedError, .stroke, .rally: return true
        case .unforcedError, .servicePoint: return false
        }
    }

    /// Whether the winning shot is recorded after the zone
    public var requiresShot: Bool {
        switch self {
        case .winner, .forcedError: return true
        case .unforcedError, .stroke, .servicePoint, .rally: return false
        }
    }

    /// Only the server can win a point straight from the serve
    public var serverOnly: Bool { self == .servicePoint }

    /// The choices after tapping a score in full coaching (not `.rally`)
    public static var detailed: [PointType] {
        allCases.filter { type in type != PointType.rally }
    }

    /// A point that ended at a zone through play: winners, forced errors and
    /// simple-coaching points. Strokes and service points say nothing about
    /// where the ball went, and own errors are the opponent's.
    public var isAttacking: Bool {
        self == PointType.winner || self == PointType.forcedError || self == PointType.rally
    }
}

/// Coachen: Uitgebreid (who, how, where, which shot) or Eenvoudig (who and
/// where). A setting, asked once when Coach is first opened (31 October 2026).
public enum CoachInputMode: String, CaseIterable {
    case detailed
    case simple

    public static let storageKey = "coachInputMode"
    /// Set once the choice was offered in Coach, so it is asked only once
    public static let askedKey = "coachInputModeAsked"

    /// Unknown or missing values give the detailed mode, as before
    public static func from(stored: String) -> CoachInputMode {
        CoachInputMode(rawValue: stored) ?? CoachInputMode.detailed
    }

    public var title: String {
        switch self {
        case .detailed: return L10n.text("Uitgebreid")
        case .simple: return L10n.text("Eenvoudig")
        }
    }

    public var explanation: String {
        switch self {
        case .detailed: return L10n.text("Per punt: wie, hoe (winner, fout, stroke), waar op de baan en welke slag. De volledige analyse.")
        case .simple: return L10n.text("Per punt alleen wie en waar op de baan: twee tikken. De analyse toont waar punten gemaakt en verloren worden, service en rallytijd.")
        }
    }
}
