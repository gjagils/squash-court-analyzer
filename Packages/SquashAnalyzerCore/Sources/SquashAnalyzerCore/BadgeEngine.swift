import Foundation

/// The tier of a badge with tiers; the rim of the artwork shows it.
public enum BadgeTier: String, CaseIterable, Codable, Sendable {
    case bronze, silver, gold

    public var title: String {
        switch self {
        case .bronze: return "Brons"
        case .silver: return "Zilver"
        case .gold: return "Goud"
        }
    }

    /// 0 for bronze, 1 for silver, 2 for gold: the position in `BadgeKind.thresholds(of:)`
    public var index: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        }
    }
}

/// A badge a player can earn during a match. The raw value is the stable id that
/// is stored and shared on player cards, so it must never change once shipped.
///
/// Seventeen badges come in three tiers. The bronze tier keeps the id the badge
/// had before tiers existed (so every award earned back then stays bronze); the
/// silver and gold tiers are badges of their own with `-silver` / `-gold` ids.
/// The gold tier of "5 points in a row" is the old "Perfect ten", under its old
/// id. `family` is the bronze badge of a series (or the badge itself), which
/// the screens group by.
public enum BadgeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case fiveInARow = "five-in-a-row"
    case fiveInARowSilver = "five-in-a-row-silver"
    case perfectTen = "perfect-ten"
    case elevenNil = "eleven-nil"
    case dropIt = "drop-it"
    case dropItSilver = "drop-it-silver"
    case dropItGold = "drop-it-gold"
    case krissCross = "kriss-cross"
    case krissCrossSilver = "kriss-cross-silver"
    case krissCrossGold = "kriss-cross-gold"
    case backFromTheDeath = "back-from-the-death"
    case backFromTheDeathSilver = "back-from-the-death-silver"
    case backFromTheDeathGold = "back-from-the-death-gold"
    case goingTheDistance = "going-the-distance"
    case aceOfPace = "ace-of-pace"
    case aceOfPaceSilver = "ace-of-pace-silver"
    case aceOfPaceGold = "ace-of-pace-gold"
    case lobStory = "lob-story"
    case lobStorySilver = "lob-story-silver"
    case lobStoryGold = "lob-story-gold"
    case volleywood = "volleywood"
    case volleywoodSilver = "volleywood-silver"
    case volleywoodGold = "volleywood-gold"
    case cleanSweep = "clean-sweep"
    case coolUnderPressure = "cool-under-pressure"
    case driveMeCrazy = "drive-me-crazy"
    case driveMeCrazySilver = "drive-me-crazy-silver"
    case driveMeCrazyGold = "drive-me-crazy-gold"
    case boastBuster = "boast-buster"
    case boastBusterSilver = "boast-buster-silver"
    case boastBusterGold = "boast-buster-gold"
    case fullHouse = "full-house"
    case hatTrick = "hat-trick"
    case hatTrickSilver = "hat-trick-silver"
    case hatTrickGold = "hat-trick-gold"
    case houdini = "houdini"
    case marathonMan = "marathon-man"
    case offTheMark = "off-the-mark"
    case centurion = "centurion"
    case centurionSilver = "centurion-silver"
    case centurionGold = "centurion-gold"
    case doubleTrouble = "double-trouble"
    case tenOutOfTen = "ten-out-of-ten"
    case tenOutOfTenSilver = "ten-out-of-ten-silver"
    case tenOutOfTenGold = "ten-out-of-ten-gold"
    case brickWall = "brick-wall"
    case frontRowKing = "front-row-king"
    case frontRowKingSilver = "front-row-king-silver"
    case frontRowKingGold = "front-row-king-gold"
    case endurance = "endurance"
    case enduranceSilver = "endurance-silver"
    case enduranceGold = "endurance-gold"
    case unbreakable = "unbreakable"
    case photoFinish = "photo-finish"
    case strokeOfGenius = "stroke-of-genius"
    case ironMan = "iron-man"
    case ironManSilver = "iron-man-silver"
    case ironManGold = "iron-man-gold"
    case nemesis = "nemesis"
    case nemesisSilver = "nemesis-silver"
    case nemesisGold = "nemesis-gold"
    case veteran = "veteran"
    case veteranSilver = "veteran-silver"
    case veteranGold = "veteran-gold"
    case rockSolid = "rock-solid"
    case backWallBoss = "back-wall-boss"
    case sneltrein = "sneltrein"
    case vetteWinst = "vette-winst"
    case clubicoon = "clubicoon"
    case rivalen = "rivalen"
    case handOutHeld = "hand-out-held"

    public var id: String { rawValue }

    // MARK: - Tiers

    /// The bronze badge of this badge's series, or the badge itself when it has no tiers
    public var family: BadgeKind {
        switch self {
        case .fiveInARowSilver, .perfectTen: return .fiveInARow
        case .dropItSilver, .dropItGold: return .dropIt
        case .krissCrossSilver, .krissCrossGold: return .krissCross
        case .backFromTheDeathSilver, .backFromTheDeathGold: return .backFromTheDeath
        case .aceOfPaceSilver, .aceOfPaceGold: return .aceOfPace
        case .lobStorySilver, .lobStoryGold: return .lobStory
        case .volleywoodSilver, .volleywoodGold: return .volleywood
        case .driveMeCrazySilver, .driveMeCrazyGold: return .driveMeCrazy
        case .boastBusterSilver, .boastBusterGold: return .boastBuster
        case .hatTrickSilver, .hatTrickGold: return .hatTrick
        case .centurionSilver, .centurionGold: return .centurion
        case .tenOutOfTenSilver, .tenOutOfTenGold: return .tenOutOfTen
        case .frontRowKingSilver, .frontRowKingGold: return .frontRowKing
        case .enduranceSilver, .enduranceGold: return .endurance
        case .ironManSilver, .ironManGold: return .ironMan
        case .nemesisSilver, .nemesisGold: return .nemesis
        case .veteranSilver, .veteranGold: return .veteran
        default: return self
        }
    }

    /// Bronze, silver and gold of a badge with tiers; just the badge itself otherwise
    public static func series(of family: BadgeKind) -> [BadgeKind] {
        switch family {
        case .fiveInARow: return [BadgeKind.fiveInARow, BadgeKind.fiveInARowSilver, BadgeKind.perfectTen]
        case .dropIt: return [BadgeKind.dropIt, BadgeKind.dropItSilver, BadgeKind.dropItGold]
        case .krissCross: return [BadgeKind.krissCross, BadgeKind.krissCrossSilver, BadgeKind.krissCrossGold]
        case .backFromTheDeath: return [BadgeKind.backFromTheDeath, BadgeKind.backFromTheDeathSilver, BadgeKind.backFromTheDeathGold]
        case .aceOfPace: return [BadgeKind.aceOfPace, BadgeKind.aceOfPaceSilver, BadgeKind.aceOfPaceGold]
        case .lobStory: return [BadgeKind.lobStory, BadgeKind.lobStorySilver, BadgeKind.lobStoryGold]
        case .volleywood: return [BadgeKind.volleywood, BadgeKind.volleywoodSilver, BadgeKind.volleywoodGold]
        case .driveMeCrazy: return [BadgeKind.driveMeCrazy, BadgeKind.driveMeCrazySilver, BadgeKind.driveMeCrazyGold]
        case .boastBuster: return [BadgeKind.boastBuster, BadgeKind.boastBusterSilver, BadgeKind.boastBusterGold]
        case .hatTrick: return [BadgeKind.hatTrick, BadgeKind.hatTrickSilver, BadgeKind.hatTrickGold]
        case .centurion: return [BadgeKind.centurion, BadgeKind.centurionSilver, BadgeKind.centurionGold]
        case .tenOutOfTen: return [BadgeKind.tenOutOfTen, BadgeKind.tenOutOfTenSilver, BadgeKind.tenOutOfTenGold]
        case .frontRowKing: return [BadgeKind.frontRowKing, BadgeKind.frontRowKingSilver, BadgeKind.frontRowKingGold]
        case .endurance: return [BadgeKind.endurance, BadgeKind.enduranceSilver, BadgeKind.enduranceGold]
        case .ironMan: return [BadgeKind.ironMan, BadgeKind.ironManSilver, BadgeKind.ironManGold]
        case .nemesis: return [BadgeKind.nemesis, BadgeKind.nemesisSilver, BadgeKind.nemesisGold]
        case .veteran: return [BadgeKind.veteran, BadgeKind.veteranSilver, BadgeKind.veteranGold]
        default: return [family]
        }
    }

    /// The tiers of this badge's series, bronze first (one entry for a badge without tiers)
    public var series: [BadgeKind] { BadgeKind.series(of: family) }

    /// The bronze, silver and gold thresholds of a badge with tiers; nil otherwise
    public static func thresholds(of family: BadgeKind) -> [Int]? {
        switch family {
        case .fiveInARow: return [5, 7, 10]
        case .dropIt, .krissCross, .driveMeCrazy, .boastBuster, .lobStory, .volleywood, .aceOfPace: return [4, 6, 8]
        case .frontRowKing: return [5, 7, 9]
        case .backFromTheDeath: return [5, 7, 9]
        case .endurance: return [60, 90, 120]
        case .ironMan: return [60, 75, 90]
        case .hatTrick: return [3, 5, 7]
        case .nemesis: return [5, 10, 20]
        case .tenOutOfTen: return [10, 25, 50]
        case .centurion: return [100, 500, 1000]
        case .veteran: return [25, 50, 100]
        default: return nil
        }
    }

    public var hasTiers: Bool { BadgeKind.thresholds(of: family) != nil }

    public var tier: BadgeTier? {
        guard hasTiers else { return nil }
        let tiers = series
        if tiers.count > 1 && tiers[1] == self { return BadgeTier.silver }
        if tiers.count > 2 && tiers[2] == self { return BadgeTier.gold }
        return BadgeTier.bronze
    }

    /// The number in the artwork: what this tier asks for
    public var threshold: Int? {
        guard let tier = tier, let thresholds = BadgeKind.thresholds(of: family) else { return nil }
        return thresholds[tier.index]
    }

    /// The bronze badge of every series plus the badges without tiers, in
    /// catalogue order (computed, not stored: a stored static that reads
    /// `allCases` would depend on Kotlin's companion initialisation order)
    public static var families: [BadgeKind] { BadgeKind.allCases.filter { kind in kind.family == kind } }

    /// Per series the highest tier among `kinds`, in catalogue order (badges
    /// without tiers as they are), for a strip or card that shows one medallion per badge
    public static func highestTiers(among kinds: Set<BadgeKind>) -> [BadgeKind] {
        var result: [BadgeKind] = []
        for family in BadgeKind.families {
            if let best = BadgeKind.highestTier(of: family, among: kinds) { result.append(best) }
        }
        return result
    }

    /// The highest tier of `family` among `kinds`; nil when none of its tiers is there
    public static func highestTier(of family: BadgeKind, among kinds: Set<BadgeKind>) -> BadgeKind? {
        var best: BadgeKind? = nil
        for kind in BadgeKind.series(of: family) where kinds.contains(kind) {
            best = kind
        }
        return best
    }

    // MARK: - Texts

    /// The badge's name, the same for every tier of a series
    public var title: String {
        switch family {
        case .fiveInARow: return "5 points in a row"
        case .elevenNil: return "Alles is voor Bassie"
        case .dropIt: return "Drop it like it's hot"
        case .krissCross: return "Kriss Kross"
        case .backFromTheDeath: return "Back from the dead"
        case .goingTheDistance: return "Going the distance"
        case .aceOfPace: return "Ace of pace"
        case .lobStory: return "Lob story"
        case .volleywood: return "Volleywood"
        case .cleanSweep: return "Clean sweep"
        case .coolUnderPressure: return "Cool under pressure"
        case .driveMeCrazy: return "Drive me crazy"
        case .boastBuster: return "Boast buster"
        case .fullHouse: return "Full house"
        case .hatTrick: return "Hat trick"
        case .houdini: return "Houdini"
        case .marathonMan: return "Marathon man"
        case .offTheMark: return "Off the mark"
        case .centurion: return "Centurion"
        case .doubleTrouble: return "Double trouble"
        case .tenOutOfTen: return "Ten out of ten"
        case .brickWall: return "Brick wall"
        case .frontRowKing: return "Front row king"
        case .endurance: return "Endurance"
        case .unbreakable: return "Unbreakable"
        case .photoFinish: return "Photo finish"
        case .strokeOfGenius: return "Stroke of genius"
        case .ironMan: return "Iron man"
        case .nemesis: return "Nemesis"
        case .veteran: return "Veteran"
        case .rockSolid: return "Rock solid"
        case .backWallBoss: return "Back wall boss"
        case .sneltrein: return "Sneltrein"
        case .vetteWinst: return "Vette winst"
        case .clubicoon: return "Clubicoon"
        case .rivalen: return "Rivalen"
        case .handOutHeld: return "Hand-out held"
        default: return rawValue
        }
    }

    /// "Drop it like it's hot · Goud"; the plain title for a badge without tiers
    public var tieredTitle: String {
        guard let tier = tier else { return title }
        return title + " · " + tier.title
    }

    /// How to earn this badge (this tier of it)
    public var detail: String {
        let n = threshold ?? 0
        switch family {
        case .fiveInARow: return "\(n) punten achter elkaar"
        case .elevenNil: return "Win een game met 11-0"
        case .dropIt: return "\(n) drops in één game"
        case .krissCross: return "\(n) crosses in één game"
        case .backFromTheDeath: return "Win een game na \(n) punten achterstand"
        case .goingTheDistance: return "Win de wedstrijd na 0-2 in games"
        case .aceOfPace: return "\(n) servicewinners in één game"
        case .lobStory: return "\(n) lobwinners in één game"
        case .volleywood: return "\(n) volleywinners in één game"
        case .cleanSweep: return "Win de wedstrijd met 3-0"
        case .coolUnderPressure: return "Win een game na 10-10"
        case .driveMeCrazy: return "\(n) drivewinners in één game"
        case .boastBuster: return "\(n) boastwinners in één game"
        case .fullHouse: return "Scoor met alle 6 slagtypes in één wedstrijd"
        case .hatTrick: return "Win \(n) wedstrijden op rij"
        case .houdini: return "Werk 3 matchpoints weg en win de wedstrijd"
        case .marathonMan: return "Win een game met minstens 20 punten"
        case .offTheMark: return "Win je eerste wedstrijd"
        case .centurion: return "Scoor in totaal \(n) punten"
        case .doubleTrouble: return "Win 2 games na 10-10 in één wedstrijd"
        case .tenOutOfTen: return "Win in totaal \(n) wedstrijden"
        case .brickWall: return "Win een game zonder unforced errors"
        case .frontRowKing: return "\(n) winners vanuit de voorste zones in één game"
        case .endurance: return "Win een rally van minstens \(n) seconden"
        case .unbreakable: return "Win een game zonder ooit achter te staan"
        case .photoFinish: return "Win een wedstrijd met 3-2"
        case .strokeOfGenius: return "Krijg 3 strokes toegekend in één game"
        case .ironMan: return "Speel een wedstrijd van minstens \(n) minuten uit"
        case .nemesis: return "Win \(n) keer van dezelfde tegenstander"
        case .veteran: return "Speel \(n) wedstrijden, gewonnen of niet"
        case .rockSolid: return "Win de wedstrijd zonder één unforced error"
        case .backWallBoss: return "5 winners vanuit de achterste zones in één game"
        case .sneltrein: return "Win een game in minder dan 6 minuten"
        case .vetteWinst: return "Win de wedstrijd zonder dat de tegenstander in een game boven de 5 komt"
        case .clubicoon: return "Speel tegen 10 verschillende tegenstanders"
        case .rivalen: return "Speel 10 wedstrijden tegen dezelfde tegenstander"
        case .handOutHeld: return "Win 5 rally's achter elkaar op de service van de ander"
        default: return rawValue
        }
    }

    /// "Brons 4 · Zilver 6 · Goud 8" for a badge with tiers; nil otherwise
    public var tierSummary: String? {
        guard let thresholds = BadgeKind.thresholds(of: family) else { return nil }
        let unit: String
        switch family {
        case .endurance: unit = " s"
        case .ironMan: unit = " min"
        default: unit = ""
        }
        var parts: [String] = []
        for tier in BadgeTier.allCases {
            parts.append(tier.title + " \(thresholds[tier.index])" + unit)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Artwork and classification

    /// Asset catalog image (the same file lives on the website under badges/).
    /// A tier has its own artwork, named after the series and the tier.
    public var imageName: String {
        if let tier = tier { return "badge-" + family.rawValue + "-" + tier.rawValue }
        return "badge-" + rawValue
    }

    /// Needs the shot, the zone, the kind of point or the rally clock, which only coach mode records.
    /// Not Sneltrein: referee mode times its games too (decision Gerd-Jan, 9 October 2026)
    public var coachOnly: Bool {
        switch family {
        case .dropIt, .krissCross, .aceOfPace, .lobStory, .volleywood, .driveMeCrazy, .boastBuster, .fullHouse,
             .brickWall, .frontRowKing, .endurance, .rockSolid, .backWallBoss: return true
        default: return false
        }
    }

    /// Counted over all the player's matches on this device rather than one match
    public var isCareer: Bool {
        switch family {
        case .hatTrick, .offTheMark, .centurion, .tenOutOfTen, .nemesis, .veteran, .clubicoon, .rivalen: return true
        default: return false
        }
    }

    public enum Category: String, CaseIterable {
        case game = "In één game"
        case match = "In één wedstrijd"
        case career = "Over al je wedstrijden"
    }

    public var category: Category {
        switch family {
        case .goingTheDistance, .cleanSweep, .houdini, .doubleTrouble, .fullHouse, .photoFinish, .ironMan,
             .rockSolid, .vetteWinst: return .match
        case .hatTrick, .offTheMark, .centurion, .tenOutOfTen, .nemesis, .veteran, .clubicoon, .rivalen: return .career
        default: return .game
        }
    }

    /// Earned once per player card (each tier once); the others can be earned again in every match
    public var isOnce: Bool {
        switch family {
        case .offTheMark, .centurion, .tenOutOfTen, .veteran, .clubicoon: return true
        default: return false
        }
    }
}

/// One rally as the badge rules see it
public struct BadgeRally: Equatable {
    public let winner: Player
    public var shot: ShotType?
    public var pointType: PointType?
    public var zone: CourtZone?
    /// Seconds since the previous rally (coach mode), including the time before the serve
    public var duration: TimeInterval?
    /// The winning shot was a volley ("Uit de lucht")
    public var isVolley: Bool
    /// Who served this rally; nil when not known (the first rally of a referee game)
    public var server: Player?

    public init(winner: Player, shot: ShotType? = nil, pointType: PointType? = nil,
                zone: CourtZone? = nil, duration: TimeInterval? = nil, isVolley: Bool = false, server: Player? = nil) {
        self.winner = winner
        self.shot = shot
        self.pointType = pointType
        self.zone = zone
        self.duration = duration
        self.isVolley = isVolley
        self.server = server
    }
}

/// One tracked game: its rallies in play order and who won it (nil while unfinished)
public struct BadgeGame: Equatable {
    public let rallies: [BadgeRally]
    public let winner: Player?
    /// Seconds from the first serve to the last rally; nil when the game was not timed
    public var duration: TimeInterval?

    public init(rallies: [BadgeRally], winner: Player?, duration: TimeInterval? = nil) {
        self.rallies = rallies
        self.winner = winner
        self.duration = duration
    }
}

/// Everything the badge rules look at for one match
public struct BadgeMatchInput: Equatable {
    public var games: [BadgeGame]
    /// Games won before tracking started ("later instappen")
    public var player1GamesBefore: Int
    public var player2GamesBefore: Int
    /// Games each player won in the end, filled-in games included
    public var player1GamesWon: Int
    public var player2GamesWon: Int
    /// nil while the match is not decided
    public var matchWinner: Player?
    public var gamesToWin: Int
    /// Coach mode records how every point was won (so "no unforced errors" means something)
    public var recordsPointTypes: Bool
    /// Whole match, first serve to last rally
    public var duration: TimeInterval

    public init(games: [BadgeGame], player1GamesBefore: Int = 0, player2GamesBefore: Int = 0,
                player1GamesWon: Int = 0, player2GamesWon: Int = 0, matchWinner: Player? = nil,
                gamesToWin: Int = 3, recordsPointTypes: Bool = false, duration: TimeInterval = 0) {
        self.games = games
        self.player1GamesBefore = player1GamesBefore
        self.player2GamesBefore = player2GamesBefore
        self.player1GamesWon = player1GamesWon
        self.player2GamesWon = player2GamesWon
        self.matchWinner = matchWinner
        self.gamesToWin = gamesToWin
        self.recordsPointTypes = recordsPointTypes
        self.duration = duration
    }

    public func gamesBefore(_ player: Player) -> Int { player == .player1 ? player1GamesBefore : player2GamesBefore }
    public func gamesWon(_ player: Player) -> Int { player == .player1 ? player1GamesWon : player2GamesWon }

    /// Every game of the match was tracked rally by rally: no head start and no
    /// filled-in games, so rules about "the whole match" can be judged
    public var isFullyTracked: Bool {
        guard player1GamesBefore == 0 && player2GamesBefore == 0 else { return false }
        let decided = games.filter { game in game.winner != nil }.count
        return decided > 0 && decided == player1GamesWon + player2GamesWon
    }
}

/// Pure badge rules. Like `ScoringEngine` this knows nothing about SwiftUI or
/// SwiftData: coach and referee mode turn their match into a `BadgeMatchInput`
/// and get the badges per player back. A badge with tiers awards every tier
/// whose threshold was reached (8 drops give bronze, silver and gold), so a
/// player's card always holds the lower tiers of a higher one.
public struct BadgeEngine {
    /// The rally clock also counts the 10-15 seconds before the serve, so a
    /// 60-second rally shows as about 75 on the clock
    public static let enduranceMargin: TimeInterval = 15.0
    public static let strokesPerGame = 3
    public static let backWinners = 5
    public static let sneltreinSeconds: TimeInterval = 6.0 * 60.0
    public static let vetteWinstMaxPoints = 5
    public static let handOutRallies = 5

    public init() {}

    public func badges(for input: BadgeMatchInput) -> [Player: Set<BadgeKind>] {
        var earned: [Player: Set<BadgeKind>] = [:]
        func award(_ badge: BadgeKind, to player: Player) { earned[player, default: []].insert(badge) }
        /// Every tier of `family` whose threshold `value` reaches
        func awardTiers(_ family: BadgeKind, _ value: Int, to player: Player) {
            for kind in BadgeKind.series(of: family) {
                guard let threshold = kind.threshold, value >= threshold else { continue }
                award(kind, to: player)
            }
        }

        // Points in a row: runs carry over from one game into the next,
        // because the rallies are one continuous sequence on court
        var current: Player? = nil
        var run = 0
        for rally in input.games.flatMap({ game in game.rallies }) {
            run = rally.winner == current ? run + 1 : 1
            current = rally.winner
            awardTiers(.fiveInARow, run, to: rally.winner)
        }

        var tenAllGamesWon: [Player: Int] = [:]
        for game in input.games {
            for player in Player.allCases {
                let won = game.rallies.filter { rally in rally.winner == player }
                func count(_ shot: ShotType) -> Int { won.filter { rally in rally.shot == shot }.count }
                awardTiers(.dropIt, count(.drop), to: player)
                awardTiers(.krissCross, count(.cross), to: player)
                awardTiers(.lobStory, count(.lob), to: player)
                // The volley switch, or an older point with "Volley" as its shot
                awardTiers(.volleywood, won.filter { rally in rally.isVolley || rally.shot == .volley }.count, to: player)
                awardTiers(.driveMeCrazy, count(.drive), to: player)
                awardTiers(.boastBuster, count(.boast), to: player)
                awardTiers(.aceOfPace, won.filter { rally in rally.pointType == .servicePoint }.count, to: player)
                if won.filter({ rally in rally.pointType == .stroke }).count >= Self.strokesPerGame { award(.strokeOfGenius, to: player) }
                // Front and back row in either layout (6 or 9 zones)
                awardTiers(.frontRowKing, won.filter { rally in rally.pointType == .winner && rally.zone?.row == CourtRow.front }.count, to: player)
                if won.filter({ rally in rally.pointType == .winner && rally.zone?.row == CourtRow.back }).count >= Self.backWinners {
                    award(.backWallBoss, to: player)
                }
                // The first rally's time is unreliable (it runs from the start of the game)
                var longest = 0.0
                for rally in game.rallies.dropFirst() where rally.winner == player {
                    longest = max(longest, rally.duration ?? 0.0)
                }
                if longest > 0.0 { awardTiers(.endurance, Int(longest - Self.enduranceMargin), to: player) }
                // Hand-outs in a row: every rally on the opponent's serve won, five times running
                var handOuts = 0
                for rally in game.rallies {
                    guard let server = rally.server, server == player.opponent else { continue }
                    handOuts = rally.winner == player ? handOuts + 1 : 0
                    if handOuts >= Self.handOutRallies { award(.handOutHeld, to: player) }
                }
            }

            guard let winner = game.winner else { continue }
            var own = 0, other = 0
            var worstDeficit = 0
            var reachedTenAll = false
            var unforcedErrors = 0
            for rally in game.rallies {
                if rally.winner == winner { own += 1 } else { other += 1 }
                if rally.winner != winner && rally.pointType == .unforcedError { unforcedErrors += 1 }
                worstDeficit = max(worstDeficit, other - own)
                if own >= 10 && other >= 10 { reachedTenAll = true }
            }
            if own >= 11 && other == 0 { award(.elevenNil, to: winner) }
            awardTiers(.backFromTheDeath, worstDeficit, to: winner)
            if worstDeficit == 0 && !game.rallies.isEmpty { award(.unbreakable, to: winner) }
            if input.recordsPointTypes && unforcedErrors == 0 && !game.rallies.isEmpty { award(.brickWall, to: winner) }
            if reachedTenAll {
                award(.coolUnderPressure, to: winner)
                tenAllGamesWon[winner, default: 0] += 1
            }
            if own >= 20 { award(.marathonMan, to: winner) }
            if let seconds = game.duration, seconds > 0.0, seconds < Self.sneltreinSeconds, !game.rallies.isEmpty {
                award(.sneltrein, to: winner)
            }
        }
        for (player, count) in tenAllGamesWon where count >= 2 { award(.doubleTrouble, to: player) }

        // Full house: points won with all 6 shots in one match. Today's six
        // (with Kill, volley being a switch), or for older matches the old six
        // (with Volley), so a full house from before the change still counts.
        let oldSix: Set<ShotType> = [.drive, .cross, .volley, .drop, .lob, .boast]
        for player in Player.allCases {
            let shots = Set(input.games.flatMap({ game in game.rallies }).filter { rally in rally.winner == player }.compactMap { rally in rally.shot })
            if Set(ShotType.selectableCases).isSubset(of: shots) || oldSix.isSubset(of: shots) {
                award(.fullHouse, to: player)
            }
        }

        if let winner = input.matchWinner {
            let loser = winner.opponent
            if input.gamesWon(loser) == 0 { award(.cleanSweep, to: winner) }
            if input.gamesToWin > 1 && input.gamesWon(loser) == input.gamesToWin - 1 { award(.photoFinish, to: winner) }
            let minutes = Int(input.duration / 60.0)
            awardTiers(.ironMan, minutes, to: winner)
            awardTiers(.ironMan, minutes, to: loser)

            // The stand after the head start and after every tracked game
            var own = input.gamesBefore(winner), other = input.gamesBefore(loser)
            var wasZeroTwo = own == 0 && other >= 2
            for game in input.games {
                guard let gameWinner = game.winner else { continue }
                if gameWinner == winner { own += 1 } else { other += 1 }
                if own == 0 && other >= 2 { wasZeroTwo = true }
            }
            if wasZeroTwo { award(.goingTheDistance, to: winner) }
            if matchPointsSaved(by: winner, in: input) >= 3 { award(.houdini, to: winner) }

            // Rules about the whole match need every game rally by rally
            if input.isFullyTracked {
                var errors = 0
                var loserBest = 0
                for game in input.games where game.winner != nil {
                    var loserPoints = 0
                    for rally in game.rallies {
                        if rally.winner == loser {
                            loserPoints += 1
                            if rally.pointType == .unforcedError { errors += 1 }
                        }
                    }
                    loserBest = max(loserBest, loserPoints)
                }
                if input.recordsPointTypes && errors == 0 { award(.rockSolid, to: winner) }
                if loserBest <= Self.vetteWinstMaxPoints { award(.vetteWinst, to: winner) }
            }
        }
        return earned
    }

    /// Rallies won by `player` while the opponent stood at match point
    public func matchPointsSaved(by player: Player, in input: BadgeMatchInput) -> Int {
        let opponent = player.opponent
        var opponentGames = input.gamesBefore(opponent)
        var saved = 0
        for game in input.games {
            var own = 0, other = 0
            for rally in game.rallies {
                let atMatchPoint = opponentGames == input.gamesToWin - 1 && other >= 10 && other > own
                if rally.winner == player {
                    own += 1
                    if atMatchPoint { saved += 1 }
                } else {
                    other += 1
                }
            }
            if game.winner == opponent { opponentGames += 1 }
        }
        return saved
    }

    /// One finished match of a player, for the badges counted over several matches
    public struct CareerMatch: Equatable {
        public let matchId: UUID
        public let date: Date
        public let won: Bool
        public let pointsWon: Int
        /// The opponent's player id, or the typed-in name, for Nemesis, Rivalen and Clubicoon
        public var opponentKey: String

        public init(matchId: UUID, date: Date, won: Bool, pointsWon: Int, opponentKey: String = "") {
            self.matchId = matchId
            self.date = date
            self.won = won
            self.pointsWon = pointsWon
            self.opponentKey = opponentKey
        }
    }

    /// Career badges earned in `matchId`, given the player's finished matches on
    /// this device. `earnedElsewhere` are once-only badges already on the card for
    /// another match, which are not awarded a second time.
    public func careerBadges(in matchId: UUID, history: [CareerMatch], earnedElsewhere: Set<BadgeKind>) -> Set<BadgeKind> {
        let ordered = history.sorted { a, b in a.date < b.date }
        guard let index = ordered.firstIndex(where: { entry in entry.matchId == matchId }) else { return [] }
        let match = ordered[index]
        let before = Array(ordered[..<index])
        var earned: Set<BadgeKind> = []
        func insertReaching(_ family: BadgeKind, _ value: Int) {
            for kind in BadgeKind.series(of: family) {
                guard let threshold = kind.threshold, value >= threshold else { continue }
                earned.insert(kind)
            }
        }
        /// Exactly the tier's number, so a badge that can be earned again (against
        /// someone else) is not repeated on every match past the mark
        func insertExactly(_ family: BadgeKind, _ value: Int) {
            for kind in BadgeKind.series(of: family) {
                guard let threshold = kind.threshold, value == threshold else { continue }
                earned.insert(kind)
            }
        }

        let winsBefore = before.filter { entry in entry.won }.count
        if match.won && winsBefore == 0 { earned.insert(.offTheMark) }
        // ">=": a player who reached the mark without the badge (missed earlier,
        // or deleted and earned again) still gets it; earnedElsewhere stops a second one
        if match.won { insertReaching(.tenOutOfTen, winsBefore + 1) }
        if match.won {
            var streak = 1
            for entry in before.reversed() {
                if entry.won { streak += 1 } else { break }
            }
            // Exactly 3, 5 and 7 in a row (decision Gerd-Jan, 6 October 2026): a long
            // streak is not awarded again with every further win, a new streak can
            // earn the badge again
            insertExactly(.hatTrick, streak)
        }
        let sameOpponent = before.filter { entry in !match.opponentKey.isEmpty && entry.opponentKey == match.opponentKey }
        // The 5th, 10th and 20th win against this opponent: Nemesis can be earned
        // again against someone else, so it is not a once-badge and ">=" would repeat it
        if match.won && !match.opponentKey.isEmpty {
            insertExactly(.nemesis, sameOpponent.filter { entry in entry.won }.count + 1)
        }
        // The 10th match against the same opponent, won or lost
        if !match.opponentKey.isEmpty && sameOpponent.count + 1 == 10 { earned.insert(.rivalen) }
        insertReaching(.veteran, before.count + 1)
        let pointsBefore = before.reduce(0) { total, entry in total + entry.pointsWon }
        for kind in BadgeKind.series(of: .centurion) {
            guard let threshold = kind.threshold else { continue }
            if pointsBefore < threshold && pointsBefore + match.pointsWon >= threshold { earned.insert(kind) }
        }
        // Opponents played so far, this one included; a typed-in empty name is nobody
        var opponents = Set(before.map { entry in entry.opponentKey })
        opponents.insert(match.opponentKey)
        opponents.remove("")
        if opponents.count >= 10 { earned.insert(.clubicoon) }
        return earned.subtracting(earnedElsewhere)
    }

    /// Only the rally winners, as one run of play (for the 5-in-a-row rule)
    public func badges(forRallyWinners winners: [Player]) -> [Player: Set<BadgeKind>] {
        badges(for: BadgeMatchInput(games: [BadgeGame(rallies: winners.map { winner in BadgeRally(winner: winner) }, winner: nil)]))
    }
}

/// Badges one picked player earned in one match, for the "Badges verdiend" strip:
/// one entry per badge, the highest tier reached
public struct MatchBadgeEarning: Identifiable, Equatable {
    public let player: Player
    public let playerId: UUID
    public let name: String
    public let badges: [BadgeKind]

    public init(player: Player, playerId: UUID, name: String, badges: [BadgeKind]) {
        self.player = player
        self.playerId = playerId
        self.name = name
        self.badges = badges
    }

    public var id: UUID { playerId }
}

extension BadgeEngine {
    /// Earnings of the players picked from "Kies speler", player 1 first
    public func earnings(for input: BadgeMatchInput, playerIds: [Player: UUID], names: [Player: String]) -> [MatchBadgeEarning] {
        let earned = badges(for: input)
        return Player.allCases.compactMap { player in
            guard let playerId = playerIds[player], let kinds = earned[player], !kinds.isEmpty else { return nil }
            return MatchBadgeEarning(player: player, playerId: playerId, name: names[player] ?? "",
                                     badges: BadgeKind.highestTiers(among: kinds))
        }
    }
}

extension MatchBadgeEarning {
    /// What each picked player earned in this match, for the result card;
    /// typed-in players (no id) and players without a badge are left out
    public static func earnings(player1Id: UUID?, player1Name: String, player2Id: UUID?, player2Name: String,
                                badgeInput: BadgeMatchInput) -> [MatchBadgeEarning] {
        let earnedByPlayer = BadgeEngine().badges(for: badgeInput)
        var result: [MatchBadgeEarning] = []
        if let id = player1Id, let earned = earnedByPlayer[Player.player1], !earned.isEmpty {
            result.append(MatchBadgeEarning(player: Player.player1, playerId: id, name: player1Name, badges: BadgeKind.highestTiers(among: earned)))
        }
        if let id = player2Id, let earned = earnedByPlayer[Player.player2], !earned.isEmpty {
            result.append(MatchBadgeEarning(player: Player.player2, playerId: id, name: player2Name, badges: BadgeKind.highestTiers(among: earned)))
        }
        return result
    }
}
