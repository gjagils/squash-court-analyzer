import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Represents the zones on a squash court (9 zones - 3x3 grid)
public enum CourtZone: String, CaseIterable, Identifiable, Codable {
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

    public var shortName: String {
        switch self {
        case .frontLeft: return "VL"
        case .frontMiddle: return "VM"
        case .frontRight: return "VR"
        case .middleLeft: return "ML"
        case .middleMiddle: return "MM"
        case .middleRight: return "MR"
        case .backLeft: return "AL"
        case .backMiddle: return "AM"
        case .backRight: return "AR"
        }
    }

    // Note for phase 2 (Skip/Android build of this package): CGFloat comes
    // from CoreGraphics, which is Apple-only. If Skip cannot transpile this,
    // swap the parameter type to Double here (CourtView, the only caller, can
    // convert) rather than special-casing this one function per platform.

    /// Returns the zone for a given normalized position (0-1 range)
    public static func from(x: CGFloat, y: CGFloat) -> CourtZone {
        // x: 0 = left, 1 = right (divided into 3 columns)
        let column: Int
        if x < 0.33 {
            column = 0 // Left
        } else if x < 0.66 {
            column = 1 // Middle
        } else {
            column = 2 // Right
        }

        // y: 0 = top (front wall), 1 = bottom (back wall)
        if y < 0.33 {
            // Front area
            switch column {
            case 0: return .frontLeft
            case 1: return .frontMiddle
            default: return .frontRight
            }
        } else if y < 0.66 {
            // Middle area
            switch column {
            case 0: return .middleLeft
            case 1: return .middleMiddle
            default: return .middleRight
            }
        } else {
            // Back area
            switch column {
            case 0: return .backLeft
            case 1: return .backMiddle
            default: return .backRight
            }
        }
    }
}
