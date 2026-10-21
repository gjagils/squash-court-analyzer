import ActivityKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Live score op het vergrendelscherm: the Live Activity of a followed match
// (updated by the live server through APNs) or of the match this phone is
// scoring (updated locally). Compiled into both the app and the widget
// extension SquashLiveActivity, which does not link SquashAnalyzerCore: the
// content state mirrors Core's `LiveSnapshot` field by field. The texts shown
// go through widgetText() (Dutch keys, English in the String Catalogs).

struct LiveScoreAttributes: ActivityAttributes {
    /// Exactly the snapshot JSON of the live server (`aps.content-state` of a
    /// liveactivity push): {p1,p2,bestOf,games,score,gamesWon,server,side,status,lastPoint?,winner?}.
    /// Property names must stay identical; `status` is a String so an unknown
    /// value from a newer server does not break decoding.
    struct ContentState: Codable, Hashable {
        var p1: String
        var p2: String
        var bestOf: Int
        /// Finished games as [player 1, player 2]
        var games: [[Int]]
        /// The game under way (or just finished) as [player 1, player 2]
        var score: [Int]
        /// Games won, head start included, as [player 1, player 2]
        var gamesWon: [Int]
        /// 1 or 2
        var server: Int
        /// "L" or "R"
        var side: String
        /// "warmup", "playing", "between" or "finished"
        var status: String
        var lastPoint: String?
        var winner: Int?
    }

    /// The live session id (followed match) or the match UUID (own match)
    var matchId: String
    /// "https://live.squashanalyzer.com"; empty for an own match
    var server: String
    /// The match this phone is scoring (no pushes, updated locally)
    var isOwnMatch: Bool
    /// Start of the match timer in the header, when known
    var startedAt: Date?
}

/// The badge on the right of the header
enum LiveScoreBadge: Equatable {
    case gameBall
    case matchBall
    case pause
    case finished

    var title: String {
        switch self {
        case .gameBall: return widgetText("GAMEBAL")
        case .matchBall: return widgetText("MATCHBAL")
        case .pause: return widgetText("PAUZE")
        case .finished: return widgetText("AFGELOPEN")
        }
    }
}

/// Everything the lock screen and the Dynamic Island show, worked out from
/// the content state (unit tested in SquashAnalyzerTests/LiveScoreAttributesTests)
extension LiveScoreAttributes.ContentState {
    var isFinished: Bool { status == "finished" }
    var isBetween: Bool { status == "between" }
    var isWarmup: Bool { status == "warmup" }
    var isPlaying: Bool { !isFinished && !isBetween && !isWarmup }

    func value(_ list: [Int], _ player: Int) -> Int {
        let index = player - 1
        return index >= 0 && index < list.count ? list[index] : 0
    }

    func name(_ player: Int) -> String { player == 1 ? p1 : p2 }

    /// Games needed to win the match: 3 in a best of 5
    var gamesToWin: Int { max(1, bestOf / 2 + 1) }

    /// Games played so far, head start included
    var gamesPlayed: Int { value(gamesWon, 1) + value(gamesWon, 2) }

    /// The game the header names: the one under way, or the one just finished
    /// during the break and at the end
    var gameNumber: Int {
        if isBetween || isFinished { return max(1, gamesPlayed) }
        return gamesPlayed + 1
    }

    /// The player who wins the game with the next rally (PAR-11, win by 2)
    var gameBallPlayer: Int? {
        guard isPlaying else { return nil }
        for player in [1, 2] {
            let own = value(score, player)
            let other = value(score, 3 - player)
            if own + 1 >= 11 && own + 1 - other >= 2 { return player }
        }
        return nil
    }

    /// Game ball that would also win the match
    var isMatchBall: Bool {
        guard let player = gameBallPlayer else { return false }
        return value(gamesWon, player) + 1 == gamesToWin
    }

    var badge: LiveScoreBadge? {
        if isFinished { return .finished }
        if isBetween { return .pause }
        if gameBallPlayer != nil { return isMatchBall ? .matchBall : .gameBall }
        return nil
    }

    /// The server dot shows only while rallies are played
    func isServing(_ player: Int) -> Bool {
        (isPlaying || isWarmup) && server == player
    }

    /// Minimal Dynamic Island: "9·7" (games won during the break and at the end)
    var minimalText: String { "\(islandScore(1))·\(islandScore(2))" }

    // MARK: - The website ticker's look (live.html)

    /// The orange line above the rows, as on the viewer page (shown in
    /// capitals): "Game 3 · best of 5", "Inspelen", "Pauze", "Jan wint 3-1"
    var statusLine: String {
        if isFinished {
            let high = max(value(gamesWon, 1), value(gamesWon, 2))
            let low = min(value(gamesWon, 1), value(gamesWon, 2))
            if let winner, winner == 1 || winner == 2 { return widgetText("\(name(winner)) wint \(high)-\(low)") }
            return widgetText("Afgelopen")
        }
        if isBetween { return widgetText("Pauze") }
        if isWarmup { return widgetText("Inspelen") }
        return widgetText("Game \(gameNumber) · best of \(bestOf)")
    }

    /// GAMEBAL or MATCHBAL next to the status line; the pause and the result
    /// are in the status line itself
    var ballBadge: LiveScoreBadge? {
        guard let badge, badge == .gameBall || badge == .matchBall else { return nil }
        return badge
    }

    /// The points per player, as on the viewer page: the rally score (at the
    /// end the score of the last game)
    func points(_ player: Int) -> Int { value(score, player) }

    /// Games won per player (head start included), in the bordered box
    func games(_ player: Int) -> Int { value(gamesWon, player) }

    /// "serveert rechts" under the server's name, while rallies are played
    func serveLine(_ player: Int) -> String? {
        guard isServing(player) else { return nil }
        return side == "L" ? widgetText("serveert links") : widgetText("serveert rechts")
    }

    /// The compact Dynamic Island: the rally score while playing, the games
    /// won during the break and at the end
    func islandScore(_ player: Int) -> Int {
        isPlaying || isWarmup ? value(score, player) : value(gamesWon, player)
    }

    /// The first letter of the name, in the circle when there is no photo
    func initial(_ player: Int) -> String {
        let trimmed = name(player).trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    /// The finished games for the chips: "11-7" and who won it (0: nobody)
    var gameChips: [LiveScoreGameChip] {
        var chips: [LiveScoreGameChip] = []
        for (index, game) in games.enumerated() where game.count == 2 {
            let winner = game[0] > game[1] ? 1 : (game[1] > game[0] ? 2 : 0)
            chips.append(LiveScoreGameChip(id: index, text: "\(game[0])-\(game[1])", winner: winner))
        }
        return chips
    }
}

/// One finished game under the rows, coloured by its winner
struct LiveScoreGameChip: Hashable, Identifiable {
    let id: Int
    let text: String
    let winner: Int
}

/// The players' photos for the Live Activity. Pushes cannot carry images, so
/// the app stores small thumbnails in the App Group container, named by the
/// activity's match id, and the widget extension reads them from there.
enum LiveScorePhotoStore {
    static let appGroup = "group.com.squashanalyzer.app"
    /// Pixels per side of a stored thumbnail (32 pt avatars at 3x)
    static let side: CGFloat = 96

    static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("live-photos", isDirectory: true)
    }

    /// live-photos/<matchId>-<player>.jpg
    static func url(matchId: String, player: Int) -> URL? {
        let safe = String(matchId.filter { character in character.isLetter || character.isNumber || character == "-" })
        guard !safe.isEmpty else { return nil }
        return directory?.appendingPathComponent("\(safe)-\(player).jpg")
    }

    #if canImport(UIKit)
    static func image(matchId: String, player: Int) -> UIImage? {
        guard let url = url(matchId: matchId, player: player) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Stores a photo as a small square JPEG; no (readable) photo removes it
    @discardableResult
    static func store(_ data: Data?, matchId: String, player: Int) -> Bool {
        guard let url = url(matchId: matchId, player: player), let directory else { return false }
        guard let data, let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        let crop = min(image.size.width, image.size.height)
        let size = min(side, crop)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let square = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { _ in
            // Centred square crop, scaled to `size`
            let scale = size / crop
            let width = image.size.width * scale
            let height = image.size.height * scale
            image.draw(in: CGRect(x: (size - width) / 2, y: (size - height) / 2, width: width, height: height))
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.8) else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try jpeg.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    #endif

    static func remove(matchId: String) {
        for player in [1, 2] {
            if let url = url(matchId: matchId, player: player) { try? FileManager.default.removeItem(at: url) }
        }
    }

    /// Removes the photos of every match not in `keep` (the activities still shown)
    static func removeAll(except keep: Set<String>) {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            // "<matchId>-<player>": the match id is everything before the last dash
            guard let dash = name.lastIndex(of: "-") else { continue }
            if !keep.contains(String(name[..<dash])) { try? FileManager.default.removeItem(at: file) }
        }
    }
}

/// The language of the lock screen texts: the same rule as the app (Core's
/// `AppLanguage`, which the widget does not link): Dutch when the phone's first
/// language is Dutch, English for every other language. Tests force Dutch.
enum WidgetLanguage {
    static var forced: String? = nil

    /// The app group the app shares the choice of Instellingen → Taal with
    static let group = "group.com.squashanalyzer.app"
    /// The same key as Core's `AppLanguage.storageKey`
    static let storageKey = "appLanguage"

    static var code: String {
        if let forced { return forced }
        // The choice in Instellingen: the app mirrors it into the app group for the widget
        for defaults in [UserDefaults(suiteName: group), UserDefaults.standard] {
            if let chosen = defaults?.string(forKey: storageKey), chosen == "nl" || chosen == "en" { return chosen }
        }
        return (Locale.preferredLanguages.first ?? "nl").lowercased().hasPrefix("nl") ? "nl" : "en"
    }

    /// The language folder of the app's or the widget's catalog; the bundle itself when it is missing
    static var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
}

/// A text of the iOS app itself (Dutch key) in the app's language, as `widgetText`
func appText(_ key: String.LocalizationValue) -> String {
    widgetText(key)
}

/// A lock screen text (the Dutch is the key) in `WidgetLanguage`
func widgetText(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: WidgetLanguage.bundle)
}
