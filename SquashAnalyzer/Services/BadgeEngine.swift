import Foundation

/// A badge a player can earn during a match. The raw value is the stable id that
/// is stored and shared on player cards, so it must never change once shipped.
enum BadgeKind: String, CaseIterable, Identifiable, Codable {
    case fiveInARow = "five-in-a-row"
    case elevenNil = "eleven-nil"
    case dropIt = "drop-it"
    case krissCross = "kriss-cross"
    case backFromTheDeath = "back-from-the-death"
    case goingTheDistance = "going-the-distance"
    case aceOfPace = "ace-of-pace"
    case lobStory = "lob-story"
    case volleywood = "volleywood"
    case cleanSweep = "clean-sweep"
    case coolUnderPressure = "cool-under-pressure"
    case driveMeCrazy = "drive-me-crazy"
    case boastBuster = "boast-buster"
    case fullHouse = "full-house"
    case hatTrick = "hat-trick"
    case houdini = "houdini"
    case marathonMan = "marathon-man"
    case offTheMark = "off-the-mark"
    case centurion = "centurion"
    case doubleTrouble = "double-trouble"
    case tenOutOfTen = "ten-out-of-ten"
    case brickWall = "brick-wall"
    case frontRowKing = "front-row-king"
    case endurance = "endurance"
    case perfectTen = "perfect-ten"
    case unbreakable = "unbreakable"
    case photoFinish = "photo-finish"
    case strokeOfGenius = "stroke-of-genius"
    case ironMan = "iron-man"
    case nemesis = "nemesis"
    case veteran = "veteran"

    var id: String { rawValue }

    var title: String {
        switch self {
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
        case .perfectTen: return "Perfect ten"
        case .unbreakable: return "Unbreakable"
        case .photoFinish: return "Photo finish"
        case .strokeOfGenius: return "Stroke of genius"
        case .ironMan: return "Iron man"
        case .nemesis: return "Nemesis"
        case .veteran: return "Veteran"
        }
    }

    var detail: String {
        switch self {
        case .fiveInARow: return "5 punten achter elkaar"
        case .elevenNil: return "Win een game met 11-0"
        case .dropIt: return "4 drops in één game"
        case .krissCross: return "4 crosses in één game"
        case .backFromTheDeath: return "Win een game na 5 punten achterstand"
        case .goingTheDistance: return "Win de wedstrijd na 0-2 in games"
        case .aceOfPace: return "4 servicewinners in één game"
        case .lobStory: return "4 lobwinners in één game"
        case .volleywood: return "4 volleywinners in één game"
        case .cleanSweep: return "Win de wedstrijd met 3-0"
        case .coolUnderPressure: return "Win een game na 10-10"
        case .driveMeCrazy: return "4 drivewinners in één game"
        case .boastBuster: return "4 boastwinners in één game"
        case .fullHouse: return "Scoor met alle 6 slagtypes in één wedstrijd"
        case .hatTrick: return "Win 3 wedstrijden op rij"
        case .houdini: return "Werk 3 matchpoints weg en win de wedstrijd"
        case .marathonMan: return "Win een game met minstens 20 punten"
        case .offTheMark: return "Win je eerste wedstrijd"
        case .centurion: return "Scoor in totaal 100 punten"
        case .doubleTrouble: return "Win 2 games na 10-10 in één wedstrijd"
        case .tenOutOfTen: return "Win in totaal 10 wedstrijden"
        case .brickWall: return "Win een game zonder unforced errors"
        case .frontRowKing: return "5 winners vanuit de voorste zones in één game"
        case .endurance: return "Win een rally van minstens 60 seconden"
        case .perfectTen: return "10 punten achter elkaar"
        case .unbreakable: return "Win een game zonder ooit achter te staan"
        case .photoFinish: return "Win een wedstrijd met 3-2"
        case .strokeOfGenius: return "Krijg 3 strokes toegekend in één game"
        case .ironMan: return "Speel een wedstrijd van minstens 60 minuten uit"
        case .nemesis: return "Win 5 keer van dezelfde tegenstander"
        case .veteran: return "Speel 25 wedstrijden, gewonnen of niet"
        }
    }

    /// Asset catalog image (the same file lives on the website under badges/)
    var imageName: String { "badge-\(rawValue)" }

    /// Needs the shot or the kind of point, which only coach mode records
    var coachOnly: Bool {
        switch self {
        case .dropIt, .krissCross, .aceOfPace, .lobStory, .volleywood, .driveMeCrazy, .boastBuster, .fullHouse,
             .brickWall, .frontRowKing, .endurance: return true
        default: return false
        }
    }

    /// Counted over all the player's matches on this device rather than one match
    var isCareer: Bool {
        switch self {
        case .hatTrick, .offTheMark, .centurion, .tenOutOfTen, .nemesis, .veteran: return true
        default: return false
        }
    }

    enum Category: String, CaseIterable {
        case game = "In één game"
        case match = "In één wedstrijd"
        case career = "Over al je wedstrijden"
    }

    var category: Category {
        switch self {
        case .goingTheDistance, .cleanSweep, .houdini, .doubleTrouble, .fullHouse, .photoFinish, .ironMan: return .match
        case .hatTrick, .offTheMark, .centurion, .tenOutOfTen, .nemesis, .veteran: return .career
        default: return .game
        }
    }

    /// Earned once per player card; the others can be earned again in every match
    var isOnce: Bool {
        switch self {
        case .offTheMark, .centurion, .tenOutOfTen, .veteran: return true
        default: return false
        }
    }
}

/// One rally as the badge rules see it
struct BadgeRally: Equatable {
    let winner: Player
    var shot: ShotType? = nil
    var pointType: PointType? = nil
    var zone: CourtZone? = nil
    /// Seconds since the previous rally (coach mode), including the time before the serve
    var duration: TimeInterval? = nil
}

/// One tracked game: its rallies in play order and who won it (nil while unfinished)
struct BadgeGame: Equatable {
    let rallies: [BadgeRally]
    let winner: Player?
}

/// Everything the badge rules look at for one match
struct BadgeMatchInput: Equatable {
    var games: [BadgeGame]
    /// Games won before tracking started ("later instappen")
    var player1GamesBefore = 0
    var player2GamesBefore = 0
    /// Games each player won in the end, filled-in games included
    var player1GamesWon = 0
    var player2GamesWon = 0
    /// nil while the match is not decided
    var matchWinner: Player? = nil
    var gamesToWin = 3
    /// Coach mode records how every point was won (so "no unforced errors" means something)
    var recordsPointTypes = false
    /// Whole match, first serve to last rally
    var duration: TimeInterval = 0

    func gamesBefore(_ player: Player) -> Int { player == .player1 ? player1GamesBefore : player2GamesBefore }
    func gamesWon(_ player: Player) -> Int { player == .player1 ? player1GamesWon : player2GamesWon }
}

/// Pure badge rules. Like `ScoringEngine` this knows nothing about SwiftUI or
/// SwiftData: coach and referee mode turn their match into a `BadgeMatchInput`
/// and get the badges per player back.
struct BadgeEngine {
    static let rowLength = 5
    static let shotsPerGame = 4
    static let comebackDeficit = 5
    static let longRowLength = 10
    static let frontWinners = 5
    /// 60 seconds of rally plus the 10-15 seconds before the serve the timer also counts
    static let enduranceSeconds: TimeInterval = 75
    static let strokesPerGame = 3
    static let ironManSeconds: TimeInterval = 60 * 60

    func badges(for input: BadgeMatchInput) -> [Player: Set<BadgeKind>] {
        var earned: [Player: Set<BadgeKind>] = [:]
        func award(_ badge: BadgeKind, to player: Player) { earned[player, default: []].insert(badge) }

        // 5 points in a row: runs carry over from one game into the next,
        // because the rallies are one continuous sequence on court
        var current: Player?
        var run = 0
        for rally in input.games.flatMap(\.rallies) {
            run = rally.winner == current ? run + 1 : 1
            current = rally.winner
            if run >= Self.rowLength { award(.fiveInARow, to: rally.winner) }
            if run >= Self.longRowLength { award(.perfectTen, to: rally.winner) }
        }

        var tenAllGamesWon: [Player: Int] = [:]
        for game in input.games {
            for player in Player.allCases {
                let won = game.rallies.filter { $0.winner == player }
                func count(_ shot: ShotType) -> Int { won.filter { $0.shot == shot }.count }
                if count(.drop) >= Self.shotsPerGame { award(.dropIt, to: player) }
                if count(.cross) >= Self.shotsPerGame { award(.krissCross, to: player) }
                if count(.lob) >= Self.shotsPerGame { award(.lobStory, to: player) }
                if count(.volley) >= Self.shotsPerGame { award(.volleywood, to: player) }
                if count(.drive) >= Self.shotsPerGame { award(.driveMeCrazy, to: player) }
                if count(.boast) >= Self.shotsPerGame { award(.boastBuster, to: player) }
                if won.filter({ $0.pointType == .servicePoint }).count >= Self.shotsPerGame { award(.aceOfPace, to: player) }
                if won.filter({ $0.pointType == .stroke }).count >= Self.strokesPerGame { award(.strokeOfGenius, to: player) }
                let front: Set<CourtZone> = [.frontLeft, .frontMiddle, .frontRight]
                if won.filter({ $0.pointType == .winner && $0.zone.map(front.contains) == true }).count >= Self.frontWinners {
                    award(.frontRowKing, to: player)
                }
                // The first rally's time is unreliable (it runs from the start of the game)
                let timed = game.rallies.dropFirst().filter { $0.winner == player }
                if timed.contains(where: { ($0.duration ?? 0) >= Self.enduranceSeconds }) { award(.endurance, to: player) }
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
            if worstDeficit >= Self.comebackDeficit { award(.backFromTheDeath, to: winner) }
            if worstDeficit == 0 && !game.rallies.isEmpty { award(.unbreakable, to: winner) }
            if input.recordsPointTypes && unforcedErrors == 0 && !game.rallies.isEmpty { award(.brickWall, to: winner) }
            if reachedTenAll {
                award(.coolUnderPressure, to: winner)
                tenAllGamesWon[winner, default: 0] += 1
            }
            if own >= 20 { award(.marathonMan, to: winner) }
        }
        for (player, count) in tenAllGamesWon where count >= 2 { award(.doubleTrouble, to: player) }

        // Full house: points won with every kind of shot in one match
        for player in Player.allCases {
            let shots = Set(input.games.flatMap(\.rallies).filter { $0.winner == player }.compactMap(\.shot))
            if shots.count == ShotType.allCases.count { award(.fullHouse, to: player) }
        }

        if let winner = input.matchWinner {
            let loser = winner.opponent
            if input.gamesWon(loser) == 0 { award(.cleanSweep, to: winner) }
            if input.gamesToWin > 1 && input.gamesWon(loser) == input.gamesToWin - 1 { award(.photoFinish, to: winner) }
            if input.duration >= Self.ironManSeconds {
                award(.ironMan, to: winner)
                award(.ironMan, to: loser)
            }

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
        }
        return earned
    }

    /// Rallies won by `player` while the opponent stood at match point
    func matchPointsSaved(by player: Player, in input: BadgeMatchInput) -> Int {
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
    struct CareerMatch: Equatable {
        let matchId: UUID
        let date: Date
        let won: Bool
        let pointsWon: Int
        /// The opponent's player id, or the typed-in name, for Nemesis
        var opponentKey: String = ""
    }

    /// Career badges earned in `matchId`, given the player's finished matches on
    /// this device. `earnedElsewhere` are once-only badges already on the card for
    /// another match, which are not awarded a second time.
    func careerBadges(in matchId: UUID, history: [CareerMatch], earnedElsewhere: Set<BadgeKind>) -> Set<BadgeKind> {
        let ordered = history.sorted { $0.date < $1.date }
        guard let index = ordered.firstIndex(where: { $0.matchId == matchId }) else { return [] }
        let match = ordered[index]
        let before = ordered[..<index]
        var earned: Set<BadgeKind> = []
        let winsBefore = before.filter(\.won).count
        if match.won && winsBefore == 0 { earned.insert(.offTheMark) }
        if match.won && winsBefore == 9 { earned.insert(.tenOutOfTen) }
        if match.won && before.count >= 2 && before.suffix(2).allSatisfy(\.won) { earned.insert(.hatTrick) }
        if match.won && !match.opponentKey.isEmpty
            && before.filter({ $0.won && $0.opponentKey == match.opponentKey }).count == 4 {
            earned.insert(.nemesis)
        }
        if before.count == 24 { earned.insert(.veteran) }
        let pointsBefore = before.reduce(0) { $0 + $1.pointsWon }
        if pointsBefore < 100 && pointsBefore + match.pointsWon >= 100 { earned.insert(.centurion) }
        return earned.subtracting(earnedElsewhere)
    }

    /// Only the rally winners, as one run of play (for the 5-in-a-row rule)
    func badges(forRallyWinners winners: [Player]) -> [Player: Set<BadgeKind>] {
        badges(for: BadgeMatchInput(games: [BadgeGame(rallies: winners.map { BadgeRally(winner: $0) }, winner: nil)]))
    }
}

extension Match {
    var badgeInput: BadgeMatchInput {
        BadgeMatchInput(
            games: games.map { game in
                BadgeGame(rallies: game.points.map {
                              BadgeRally(winner: $0.scorer, shot: $0.shotType, pointType: $0.pointType, zone: $0.zone, duration: $0.duration)
                          },
                          winner: game.winner)
            },
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore,
            player1GamesWon: player1GamesWon,
            player2GamesWon: player2GamesWon,
            matchWinner: matchWinner,
            gamesToWin: gamesToWin,
            recordsPointTypes: true,
            duration: totalMatchDuration()
        )
    }

    /// Rally winners in play order across the tracked games
    var rallyWinners: [Player] {
        games.flatMap { $0.points.map(\.scorer) }
    }
}

extension RefereeMatch {
    var badgeInput: BadgeMatchInput {
        func rallies(_ entries: [RefereePointEntry]) -> [BadgeRally] {
            entries.map { BadgeRally(winner: $0.scorer, pointType: $0.isStroke ? .stroke : nil) }
        }
        var games = completedGames.map { BadgeGame(rallies: rallies($0.points), winner: $0.winner) }
        if !pointHistory.isEmpty {
            games.append(BadgeGame(rallies: rallies(pointHistory), winner: ScoringEngine().winner(for: SquashScore(player1: player1Score, player2: player2Score))))
        }
        return BadgeMatchInput(
            games: games,
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore,
            player1GamesWon: player1TotalGames,
            player2GamesWon: player2TotalGames,
            matchWinner: matchWinner,
            gamesToWin: gamesToWin,
            duration: matchDuration
        )
    }

    /// Rally winners in play order: completed games, then the game on the board
    var rallyWinners: [Player] {
        completedGames.flatMap { $0.points.map(\.scorer) } + pointHistory.map(\.scorer)
    }
}

/// Badges one picked player earned in one match, for the "Badges verdiend" strip
struct MatchBadgeEarning: Identifiable, Equatable {
    let player: Player
    let playerId: UUID
    let name: String
    let badges: [BadgeKind]

    var id: UUID { playerId }
}

extension BadgeEngine {
    /// Earnings of the players picked from "Kies speler", player 1 first
    func earnings(for input: BadgeMatchInput, playerIds: [Player: UUID], names: [Player: String]) -> [MatchBadgeEarning] {
        let earned = badges(for: input)
        return Player.allCases.compactMap { player in
            guard let playerId = playerIds[player], let kinds = earned[player], !kinds.isEmpty else { return nil }
            return MatchBadgeEarning(player: player, playerId: playerId, name: names[player] ?? "",
                                     badges: BadgeKind.allCases.filter(kinds.contains))
        }
    }
}
