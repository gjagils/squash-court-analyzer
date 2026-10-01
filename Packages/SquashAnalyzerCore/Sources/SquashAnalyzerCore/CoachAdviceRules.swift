import Foundation

// The building blocks of the local advice (CoachAdvice.local): where on the
// court a player wins, loses and errs, per row (voor/midden/achter) and side
// (links/rechts). Shared by iOS and Android. Plan: docs/plan-lokaal-advies.md.

public enum CourtSide: String, CaseIterable, Sendable {
    case left, right
}

extension CourtZone {
    /// Left or right; nil for the middle column of the 9-zone layout
    public var side: CourtSide? {
        switch self {
        case .frontLeft, .middleLeft, .backLeft: return CourtSide.left
        case .frontRight, .middleRight, .backRight: return CourtSide.right
        default: return nil
        }
    }
}

/// Points per row and per side. "Vaak" (`dominantRow`/`dominantSide`) needs
/// enough points and a clear share, so one rally never makes a pattern.
public struct AreaTally: Equatable, Sendable {
    public var front = 0
    public var middle = 0
    public var back = 0
    public var left = 0
    public var right = 0

    public init() {}

    public static let minimumTotal = 5
    public static let minimumCount = 3
    /// Of three rows a third is normal; half is "vaak"
    public static let rowShare = 0.5
    /// Of two sides half is normal; 70% is "vaak"
    public static let sideShare = 0.7

    public var total: Int { front + middle + back }
    public var sideTotal: Int { left + right }

    public func count(_ row: CourtRow) -> Int {
        switch row {
        case .front: return front
        case .middle: return middle
        case .back: return back
        }
    }

    public func count(_ side: CourtSide) -> Int {
        side == CourtSide.left ? left : right
    }

    public mutating func add(_ zone: CourtZone) {
        switch zone.row {
        case .front: front += 1
        case .middle: middle += 1
        case .back: back += 1
        }
        if let side = zone.side {
            if side == CourtSide.left { left += 1 } else { right += 1 }
        }
    }

    /// The row with most points, if at least 5 in total, 3 there, half of
    /// them, and no other row as high
    public var dominantRow: CourtRow? {
        guard total >= AreaTally.minimumTotal else { return nil }
        var best: CourtRow? = nil
        var most = 0
        var tied = false
        for row in [CourtRow.front, CourtRow.middle, CourtRow.back] {
            let value = count(row)
            if value > most {
                most = value
                best = row
                tied = false
            } else if value == most {
                tied = true
            }
        }
        guard !tied, most >= AreaTally.minimumCount, Double(most) >= AreaTally.rowShare * Double(total) else { return nil }
        return best
    }

    /// The side with most points, if at least 5 on both sides together, 3
    /// there and 70% of them
    public var dominantSide: CourtSide? {
        guard sideTotal >= AreaTally.minimumTotal else { return nil }
        let side = left > right ? CourtSide.left : CourtSide.right
        let most = count(side)
        guard most >= AreaTally.minimumCount, Double(most) >= AreaTally.sideShare * Double(sideTotal) else { return nil }
        return side
    }
}

/// Where a player wins (own winners and forced errors), loses (the
/// opponent's) and errs (own unforced errors). Strokes and service points do
/// not count: they say nothing about where the ball went.
public struct ZoneProfile: Equatable, Sendable {
    public var won = AreaTally()
    public var lost = AreaTally()
    public var errors = AreaTally()

    public init() {}

    public static func of(_ game: Game, for player: Player) -> ZoneProfile {
        var profile = ZoneProfile()
        for point in game.points {
            guard let zone = point.zone else { continue }
            let attacking = point.pointType == PointType.winner || point.pointType == PointType.forcedError
            if attacking && point.scorer == player {
                profile.won.add(zone)
            } else if attacking {
                profile.lost.add(zone)
            } else if point.pointType == PointType.unforcedError && point.scorer == player.opponent {
                // The opponent scored on the player's error
                profile.errors.add(zone)
            }
        }
        return profile
    }

    /// One line for the AI prompt: "voor 5, midden 1, achter 2; links 6, rechts 2"
    public static func describe(_ tally: AreaTally) -> String {
        "voor \(tally.front), midden \(tally.middle), achter \(tally.back); links \(tally.left), rechts \(tally.right)"
    }
}

extension CourtRow {
    /// "voorin", "in het midden", "achterin"
    public var inWords: String {
        switch self {
        case .front: return "voorin"
        case .middle: return "in het midden"
        case .back: return "achterin"
        }
    }
}

extension CourtSide {
    /// "aan de linkerkant", "aan de rechterkant"
    public var inWords: String {
        self == CourtSide.left ? "aan de linkerkant" : "aan de rechterkant"
    }
}
