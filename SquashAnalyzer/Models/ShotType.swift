import Foundation

/// Types of shots in squash
enum ShotType: String, CaseIterable, Identifiable {
    case drive = "Drive"
    case cross = "Cross"
    case volley = "Volley"
    case drop = "Drop"
    case lob = "Lob"
    case boast = "Boast"

    var id: String { rawValue }

    /// Short display name
    var shortName: String {
        switch self {
        case .drive: return "DRV"
        case .cross: return "CRS"
        case .volley: return "VLY"
        case .drop: return "DRP"
        case .lob: return "LOB"
        case .boast: return "BST"
        }
    }

    /// Icon for the shot type
    var icon: String {
        switch self {
        case .drive: return "arrow.right"
        case .cross: return "arrow.left.and.right"
        case .volley: return "bolt.fill"
        case .drop: return "arrow.down.to.line"
        case .lob: return "arrow.up.forward"
        case .boast: return "arrow.turn.up.right"
        }
    }

    /// Description of the shot
    var description: String {
        switch self {
        case .drive: return "Rechte slag langs de muur"
        case .cross: return "Diagonale slag"
        case .volley: return "Slag uit de lucht"
        case .drop: return "Korte bal naar de voorkant"
        case .lob: return "Hoge bal naar achteren"
        case .boast: return "Slag via de zijmuur"
        }
    }
}
