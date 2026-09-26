import Foundation
import SwiftData

/// Available coaching focus area tags
enum CoachingFocusTag: String, CaseIterable {
    case conditie = "Conditie"
    case voorhand = "Voorhand"
    case backhand = "Backhand"
    case serve = "Serve"
    case volley = "Volley"
    case drop = "Drop"
    case boast = "Boast"
    case beweging = "Beweging"
    case achterwand = "Achterwand"
    case mentaal = "Mentaal"
    case tactiek = "Tactiek"
    case snelheid = "Snelheid"
}

/// Persisted player profile for SwiftData
@Model
final class SavedPlayer {
    var id: UUID
    var name: String
    var coachingFocusAreas: [String]   // CoachingFocusTag rawValues
    var coachingNotes: String
    var createdAt: Date
    /// Square JPEG, at most 512px (see PlayerPhoto); nil when no photo is set
    @Attribute(.externalStorage) var photoData: Data? = nil
    /// Player card this player is linked to; nil means the player's own card (`id`)
    var cardId: UUID? = nil

    init(
        id: UUID = UUID(),
        name: String,
        coachingFocusAreas: [String] = [],
        coachingNotes: String = "",
        createdAt: Date = Date(),
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.coachingFocusAreas = coachingFocusAreas
        self.coachingNotes = coachingNotes
        self.createdAt = createdAt
        self.photoData = photoData
    }

    /// Card the player's badges are recorded on
    var badgeCardId: UUID { cardId ?? id }
}
