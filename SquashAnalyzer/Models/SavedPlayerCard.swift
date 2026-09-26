import Foundation
import SwiftData

/// A player card that lives in CloudKit: one record zone per card, shared with
/// other coaches through a CKShare. Only cards that were shared or joined have
/// one; the badges of every other player stay on this device.
@Model
final class SavedPlayerCard {
    var cardId: UUID
    /// Name as it appears on the card (the owner's name for the player)
    var name: String
    /// True in the owner's private database, false for a card joined through a share
    var isOwner: Bool
    /// `CKRecordZone.ID.ownerName` of the card's zone
    var zoneOwnerName: String
    /// Invitation link (the CKShare URL), when known
    var shareURL: String? = nil
    /// Encoded system fields of the card record (change tag), for conflict-free saves
    var systemFields: Data? = nil

    init(cardId: UUID, name: String, isOwner: Bool, zoneOwnerName: String, shareURL: String? = nil) {
        self.cardId = cardId
        self.name = name
        self.isOwner = isOwner
        self.zoneOwnerName = zoneOwnerName
        self.shareURL = shareURL
    }
}
