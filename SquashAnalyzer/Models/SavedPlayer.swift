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

    init(
        id: UUID = UUID(),
        name: String,
        coachingFocusAreas: [String] = [],
        coachingNotes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.coachingFocusAreas = coachingFocusAreas
        self.coachingNotes = coachingNotes
        self.createdAt = createdAt
    }
}
