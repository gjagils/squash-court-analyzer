import Foundation

/// Types of shots in squash
enum ShotType: String, CaseIterable, Identifiable, Codable {
    case drive = "Drive"
    case cross = "Cross"
    case volley = "Volley"
    case drop = "Drop"
    case lob = "Lob"
    case boast = "Boast"
    case ace = "Ace"
    case stroke = "Stroke"

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
        case .ace: return "ACE"
        case .stroke: return "STR"
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
        case .ace: return "star.fill"
        case .stroke: return "hand.raised.fill"
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
        case .ace: return "Service die niet wordt teruggeslagen"
        case .stroke: return "Punt door obstructie van tegenstander"
        }
    }
}
