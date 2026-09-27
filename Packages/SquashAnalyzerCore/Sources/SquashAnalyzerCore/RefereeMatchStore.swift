import Foundation

/// The live UI owns mutable matches on the main actor. Implementations must
/// capture values before suspending and finish each write before returning.
@MainActor
public protocol RefereeMatchStore {
    func loadInProgress() async throws -> RefereeMatch?
    func save(_ match: RefereeMatch) async throws
    func abandon(_ match: RefereeMatch) async throws
}
