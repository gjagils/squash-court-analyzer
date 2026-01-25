import Foundation

/// Represents the zones on a squash court (6 zones)
enum CourtZone: String, CaseIterable, Identifiable {
    case frontLeft = "Voor Links"
    case frontRight = "Voor Rechts"
    case middleLeft = "Midden Links"
    case middleRight = "Midden Rechts"
    case backLeft = "Achter Links"
    case backRight = "Achter Rechts"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .frontLeft: return "VL"
        case .frontRight: return "VR"
        case .middleLeft: return "ML"
        case .middleRight: return "MR"
        case .backLeft: return "AL"
        case .backRight: return "AR"
        }
    }

    /// Returns the zone for a given normalized position (0-1 range)
    static func from(x: CGFloat, y: CGFloat) -> CourtZone {
        let isLeft = x < 0.5

        // y: 0 = top (front wall), 1 = bottom (back wall)
        if y < 0.33 {
            // Front area
            return isLeft ? .frontLeft : .frontRight
        } else if y < 0.66 {
            // Middle area
            return isLeft ? .middleLeft : .middleRight
        } else {
            // Back area
            return isLeft ? .backLeft : .backRight
        }
    }
}
