import Foundation

/// Server side (left or right service box)
public enum ServerSide: String {
    case left = "Links"
    case right = "Rechts"

    public var icon: String {
        self == .left ? "arrow.left" : "arrow.right"
    }

    /// Single-letter code used in the scoring timeline ("4R", "5L")
    public var shortCode: String {
        self == .left ? "L" : "R"
    }

    public var opposite: ServerSide {
        self == .left ? .right : .left
    }
}
