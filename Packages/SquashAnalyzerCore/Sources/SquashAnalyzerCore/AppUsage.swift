import Foundation

// The anonymous daily usage count (3.1, docs/voorstel-gebruikstelling-app.md):
// at most once a day the app tells the live service that it was used, with the
// platform, the version, the language and the parts used that day. No device
// id, no names, no time finer than a day; the phone only remembers on which day
// it last reported. Off with Instellingen → "Anoniem gebruik tellen".

/// A part of the app whose use is counted, once a day each
public enum AppUsagePart: String, CaseIterable, Sendable {
    /// A coach session started
    case coach
    /// A referee match started
    case referee
    /// A finished match or a player profile opened
    case analysis
    /// The Competitie screen opened
    case competition
}

/// The body of POST /api/app/day
public struct AppUsageReport: Codable, Equatable, Sendable {
    public var platform: String
    public var version: String
    public var lang: String
    /// The parts used today that were not reported yet
    public var parts: [String]
    /// False when "opened" was already reported today and only a new part goes
    /// (JSON `open`; not the Swift name, `open` breaks the Kotlin enum of the keys)
    public var opened: Bool
    /// The first report of this installation
    public var first: Bool

    enum CodingKeys: String, CodingKey {
        case platform
        case version
        case lang
        case parts
        case opened = "open"
        case first
    }

    public init(platform: String, version: String, lang: String, parts: [String], opened: Bool, first: Bool) {
        self.platform = platform
        self.version = version
        self.lang = lang
        self.parts = parts
        self.opened = opened
        self.first = first
    }
}

/// What the phone remembers between reports
public struct AppUsageMemory: Equatable, Sendable {
    /// The day (yyyy-MM-dd) "opened" was last reported, "" before the first report
    public var day: String
    /// The parts already reported on `day`
    public var parts: [String]
    /// Whether this installation ever reported
    public var firstSent: Bool

    public init(day: String = "", parts: [String] = [], firstSent: Bool = false) {
        self.day = day
        self.parts = parts
        self.firstSent = firstSent
    }

    /// The report due on `today` for the parts used so far (`used`), or nil when nothing is new
    public func report(today: String, used: [String], platform: String, version: String, lang: String) -> AppUsageReport? {
        let opened = day != today
        let reported: [String] = opened ? [] : parts
        var fresh: [String] = []
        for part in AppUsagePart.allCases {
            let name = part.rawValue
            if used.contains(name) && !reported.contains(name) { fresh.append(name) }
        }
        if !opened && fresh.isEmpty { return nil }
        return AppUsageReport(platform: platform, version: version, lang: lang, parts: fresh, opened: opened, first: !firstSent)
    }

    /// The memory after `report` was sent on `today`
    public func after(_ report: AppUsageReport, today: String) -> AppUsageMemory {
        var known: [String] = day == today ? parts : []
        for part in report.parts where !known.contains(part) { known.append(part) }
        return AppUsageMemory(day: today, parts: known, firstSent: true)
    }
}

/// Sends the daily report. The app sets `transport` and `version` at start (only in
/// release builds) and calls `appOpened()` when it comes to the front and
/// `used(_:)` where a part starts.
@MainActor
public final class AppUsage {
    /// Instellingen switch "Anoniem gebruik tellen" (on by default)
    public static let enabledKey = "usageCountingEnabled"
    static let dayKey = "usageDay"
    static let partsKey = "usageParts"
    static let firstSentKey = "usageFirstSent"

    public static let shared = AppUsage()

    /// Nil (debug builds, tests, screenshots): nothing is sent
    public var transport: (any LiveTransport)? = nil
    /// The marketing version, "3.1" (`AppUsage.marketingVersion(from:)`)
    public var version = "unknown"
    /// Set by tests; otherwise the live server's address
    public var baseURL: String? = nil
    private let defaults: UserDefaults
    /// Parts used since the last successful report, kept until they are sent
    private var pendingParts: [String] = []
    private var sending = false

    public init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// The switch in Instellingen; on when never set
    public var isEnabled: Bool {
        if defaults.object(forKey: AppUsage.enabledKey) == nil { return true }
        return defaults.bool(forKey: AppUsage.enabledKey)
    }

    /// The app came to the front: report "opened" if that did not happen today
    public func appOpened(now: Date = Date()) async {
        await flush(now: now)
    }

    /// A part of the app was used: report it if it was not reported today
    public func used(_ part: AppUsagePart, now: Date = Date()) async {
        if !pendingParts.contains(part.rawValue) { pendingParts.append(part.rawValue) }
        await flush(now: now)
    }

    /// The "3.1" of "3.1 (4)" (Android's versionName) or "3.1" (iOS)
    public static func marketingVersion(from text: String) -> String {
        var result = ""
        for character in text.trimmingCharacters(in: .whitespacesAndNewlines) {
            if character == " " { break }
            result += String(character)
        }
        return result.isEmpty ? "unknown" : result
    }

    /// The day on this phone as yyyy-MM-dd
    public static func dayText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var memory: AppUsageMemory {
        get {
            let stored = defaults.string(forKey: AppUsage.partsKey) ?? ""
            let parts: [String] = stored.isEmpty ? [] : stored.components(separatedBy: ",")
            return AppUsageMemory(day: defaults.string(forKey: AppUsage.dayKey) ?? "", parts: parts,
                                  firstSent: defaults.bool(forKey: AppUsage.firstSentKey))
        }
        set {
            defaults.set(newValue.day, forKey: AppUsage.dayKey)
            defaults.set(newValue.parts.joined(separator: ","), forKey: AppUsage.partsKey)
            defaults.set(newValue.firstSent, forKey: AppUsage.firstSentKey)
        }
    }

    /// Sends what is due, one request at a time; stops at the first failure (the next opening tries again)
    private func flush(now: Date) async {
        guard isEnabled else {
            pendingParts = []
            return
        }
        guard let transport, !sending else { return }
        sending = true
        let today = AppUsage.dayText(now)
        while isEnabled {
            guard let report = memory.report(today: today, used: pendingParts, platform: AppPlatform.current,
                                             version: version, lang: AppLanguage.current.code) else { break }
            let sent = await send(report, transport: transport)
            if !sent { break }
            let updated = memory.after(report, today: today)
            memory = updated
            // Parts used while this request was under way stay for the next round
            pendingParts = pendingParts.filter { part in !updated.parts.contains(part) }
        }
        sending = false
    }

    private func send(_ report: AppUsageReport, transport: any LiveTransport) async -> Bool {
        let base = baseURL ?? LiveShare.defaultBaseURL
        guard let url = URL(string: "\(base)/api/app/day"), let body = try? JSONEncoder().encode(report) else { return false }
        do {
            let response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: body)
            // 404: a server without this path (the NAS reserve) need not hear it again today
            return (response.status >= 200 && response.status < 300) || response.status == 404
        } catch {
            return false
        }
    }
}
