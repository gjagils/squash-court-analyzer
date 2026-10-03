import Foundation

/// How an unforced error went wrong (test feedback, October 2026). Where on
/// court does not matter for an unforced error, so it records this instead of
/// a zone. Optional: an error without a kind is "onbekend", as is every error
/// recorded before this existed. The raw values are stored, never renamed.
public enum ErrorKind: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Into the tin
    case down = "Down"
    /// Out of court, above the out line
    /// Named outOfCourt because `out` is a Kotlin keyword (enum entry syntax error)
    case outOfCourt = "Out"
    /// Fault on the serve
    case service = "Service"
    /// The ball hit the floor before the front wall
    case viaFloor = "Via de grond"

    public var id: String { rawValue }

    /// Label on the switch, short so four fit next to each other
    public var title: String {
        switch self {
        case .down: return "Down"
        case .outOfCourt: return "Out"
        case .service: return "Service"
        case .viaFloor: return "Grond"
        }
    }

    /// SF Symbol; each has a Material icon in `AppSymbol` for Android
    public var icon: String {
        switch self {
        case .down: return "arrow.down.to.line"
        case .outOfCourt: return "arrow.up.circle"
        case .service: return "figure.tennis"
        case .viaFloor: return "arrow.down.right.circle"
        }
    }

    public var description: String {
        switch self {
        case .down: return "Bal in de tin"
        case .outOfCourt: return "Bal buiten de baan of boven de outlijn"
        case .service: return "Servicefout"
        case .viaFloor: return "Bal raakt eerst de vloer voor de frontwand"
        }
    }

    /// The stored value back; nil for "" or anything unknown. Looked up through
    /// `allCases` because Skip mistranslates `ErrorKind(rawValue:)` in some places.
    public static func from(stored raw: String?) -> ErrorKind? {
        guard let raw, !raw.isEmpty else { return nil }
        return ErrorKind.allCases.first { $0.rawValue == raw }
    }

    /// The kinds that fit an error: a service fault only when the player who
    /// made the error was serving
    public static func options(errorByServer: Bool) -> [ErrorKind] {
        if errorByServer { return ErrorKind.allCases }
        return ErrorKind.allCases.filter { $0 != ErrorKind.service }
    }

    /// "Down 2 · Out 1" in a fixed order; nil when nothing was recorded
    public static func summary(_ counts: [ErrorKind: Int]) -> String? {
        var parts: [String] = []
        for kind in ErrorKind.allCases {
            let count = counts[kind] ?? 0
            if count > 0 { parts.append("\(kind.title) \(count)") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
