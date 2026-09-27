import Foundation

public enum CoachingFocusTag: String, CaseIterable {
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

/// Editable profile values; platform stores retain photo/card metadata separately.
public struct PlayerProfile: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var coachingFocusAreas: [String]
    public var coachingNotes: String
    public var createdAt: Double

    public init(id: String = UUID().uuidString, name: String = "",
                coachingFocusAreas: [String] = [], coachingNotes: String = "",
                createdAt: Double = Date().timeIntervalSince1970) {
        self.id = id
        self.name = name
        self.coachingFocusAreas = coachingFocusAreas
        self.coachingNotes = coachingNotes
        self.createdAt = createdAt
    }

    public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var isValid: Bool { !trimmedName.isEmpty }
}

/// Shared async boundary. Storage implementations may differ per platform.
public protocol PlayerProfileStore: Sendable {
    func loadPlayers() async throws -> [PlayerProfile]
    func savePlayer(_ player: PlayerProfile) async throws
    func deletePlayer(_ id: String) async throws
}
