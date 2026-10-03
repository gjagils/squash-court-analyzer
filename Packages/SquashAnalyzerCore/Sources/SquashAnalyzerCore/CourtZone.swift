import Foundation

/// The zones on a squash court. Nine exist (3×3); the 6-zone layout uses
/// only the left/right ones (`CourtLayout`). The raw values are stored, never
/// renamed.
public enum CourtZone: String, CaseIterable, Identifiable, Codable, Sendable {
    case frontLeft = "Voor Links"
    case frontMiddle = "Voor Midden"
    case frontRight = "Voor Rechts"
    case middleLeft = "Midden Links"
    case middleMiddle = "Midden Midden"
    case middleRight = "Midden Rechts"
    case backLeft = "Achter Links"
    case backMiddle = "Achter Midden"
    case backRight = "Achter Rechts"

    public var id: String { rawValue }

    /// Front, middle or back third of the court
    public var row: CourtRow {
        switch self {
        case .frontLeft, .frontMiddle, .frontRight: return CourtRow.front
        case .middleLeft, .middleMiddle, .middleRight: return CourtRow.middle
        case .backLeft, .backMiddle, .backRight: return CourtRow.back
        }
    }

    /// The middle column, which only the 9-zone layout has
    public var isMiddleColumn: Bool {
        self == .frontMiddle || self == .middleMiddle || self == .backMiddle
    }
}

public enum CourtRow: String, Sendable {
    case front, middle, back
}

/// How the court is divided when entering a point: 6 zones (front/middle/back
/// × left/right, the default) or 9 (with a middle column). A setting on both
/// platforms (`storageKey`), so coaches can try both.
public enum CourtLayout: String, CaseIterable, Sendable {
    case six, nine

    public static let storageKey = "courtZoneLayout"

    /// The stored setting; anything unknown or empty is the default, 6.
    /// (A static function: an `init(stored: String)` clashes in Kotlin with
    /// the generated `init(rawValue: String)`.)
    public static func from(stored: String) -> CourtLayout {
        stored == CourtLayout.nine.rawValue ? CourtLayout.nine : CourtLayout.six
    }

    /// The zones as rows from the front wall back, left to right
    public var rows: [[CourtZone]] {
        switch self {
        case .six:
            return [[CourtZone.frontLeft, CourtZone.frontRight],
                    [CourtZone.middleLeft, CourtZone.middleRight],
                    [CourtZone.backLeft, CourtZone.backRight]]
        case .nine:
            return [[CourtZone.frontLeft, CourtZone.frontMiddle, CourtZone.frontRight],
                    [CourtZone.middleLeft, CourtZone.middleMiddle, CourtZone.middleRight],
                    [CourtZone.backLeft, CourtZone.backMiddle, CourtZone.backRight]]
        }
    }

    public var zones: [CourtZone] {
        var result: [CourtZone] = []
        for row in rows {
            result.append(contentsOf: row)
        }
        return result
    }

    /// The zone at a normalized position: x 0 = left wall, y 0 = front wall
    public func zone(x: Double, y: Double) -> CourtZone {
        let grid = rows
        let rowIndex = min(2, max(0, Int(y * 3.0)))
        let columns = grid[rowIndex]
        let columnIndex = min(columns.count - 1, max(0, Int(x * Double(columns.count))))
        return columns[columnIndex]
    }

    /// The layout that shows every zone in `zones`: 9 as soon as one lies in
    /// the middle column (played with 9 zones, or an older match), else 6
    public static func showing(_ zones: [CourtZone]) -> CourtLayout {
        for zone in zones where zone.isMiddleColumn {
            return CourtLayout.nine
        }
        return CourtLayout.six
    }
}
