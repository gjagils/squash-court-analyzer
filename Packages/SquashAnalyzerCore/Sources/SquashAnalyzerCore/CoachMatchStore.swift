import Foundation

/// The live UI owns mutable matches on the main actor. Implementations must
/// capture values before suspending and finish each write before returning.
@MainActor
public protocol CoachMatchStore {
    func loadInProgress() async throws -> Match?
    func save(_ match: Match) async throws
    func abandon(_ match: Match) async throws
}
