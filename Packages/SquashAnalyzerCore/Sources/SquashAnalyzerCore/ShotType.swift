import Foundation

/// Types of shots in squash. `volley` is kept only so older points still
/// read: a volley is now a switch ("Uit de lucht", `Point.isVolley`) on top of
/// the shot. The raw values are stored, never renamed.
public enum ShotType: String, CaseIterable, Identifiable, Codable, Sendable {
    case drive = "Drive"
    case cross = "Cross"
    case volley = "Volley"
    case drop = "Drop"
    case lob = "Lob"
    case boast = "Boast"
    case kill = "Kill"

    public var id: String { rawValue }

    /// Icon for the shot type
    public var icon: String {
        switch self {
        case .drive: return "arrow.right"
        case .cross: return "arrow.left.and.right"
        case .volley: return "bolt.fill"
        case .drop: return "arrow.down.to.line"
        case .lob: return "arrow.up.forward"
        case .boast: return "arrow.turn.up.right"
        case .kill: return "arrow.down.right"
        }
    }

    /// Description of the shot
    public var description: String {
        switch self {
        case .drive: return "Rechte slag langs de muur"
        case .cross: return "Diagonale slag"
        case .volley: return "Slag uit de lucht"
        case .drop: return "Korte bal naar voren (ook cross drop)"
        case .lob: return "Hoge bal naar achteren"
        case .boast: return "Slag via de zijmuur"
        case .kill: return "Hard en laag, sterft snel"
        }
    }

    /// Only for points entered before the volley switch
    public var isLegacy: Bool { self == ShotType.volley }

    /// The shots offered when entering a point
    public static let selectableCases: [ShotType] = [ShotType.drive, ShotType.cross, ShotType.drop,
                                                     ShotType.lob, ShotType.boast, ShotType.kill]

    /// The shots that make sense from `zone`, by its row (the trainer's
    /// table): front Drop · Boast · Kill, middle Kill · Drive · Cross · Boast,
    /// back Drive · Cross · Lob. Without a zone, all selectable shots.
    public static func options(for zone: CourtZone?) -> [ShotType] {
        guard let zone else { return selectableCases }
        switch zone.row {
        case .front: return [ShotType.drop, ShotType.boast, ShotType.kill]
        case .middle: return [ShotType.kill, ShotType.drive, ShotType.cross, ShotType.boast]
        case .back: return [ShotType.drive, ShotType.cross, ShotType.lob]
        }
    }

    /// Buttons per row for the shot step: 4 as 2×2, otherwise rows of 3
    public static func rows(_ shots: [ShotType]) -> [[ShotType]] {
        let perRow = shots.count == 4 ? 2 : 3
        var rows: [[ShotType]] = []
        var index = 0
        while index < shots.count {
            rows.append(Array(shots[index..<min(index + perRow, shots.count)]))
            index += perRow
        }
        return rows
    }

    /// Whether "Uit de lucht" can go with this shot (a lob is never a volley)
    public var allowsVolley: Bool { self != ShotType.lob && self != ShotType.volley }

    /// "Drop", "Volley drop", or "Volley (oud)" for a point from before the switch
    public func displayName(isVolley: Bool) -> String {
        if self == ShotType.volley { return "Volley (oud)" }
        return isVolley ? "Volley " + rawValue.lowercased() : rawValue
    }
}
