import Foundation

// De rondleiding voor nieuwe gebruikers (docs/voorstel-rondleiding.md) and the
// "Over de app" links in Instellingen. Shared by iOS and Android.

/// When the tour shows by itself, and what it says
public enum Onboarding {
    /// The tour version this device has seen (0 = none)
    public static let storageKey = "onboardingVersion"
    /// Raise this after a big change to show the tour to everyone once more
    public static let currentVersion = 1

    /// The tour shows by itself until this version was seen once (finished or
    /// skipped). Version 1 also goes to the testers who already had the app:
    /// it is new for them as well (choice 11 October 2026).
    public static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < currentVersion
    }

    /// One page of the tour
    public struct Page: Equatable, Sendable {
        public let symbol: String
        public let title: String
        public let text: String

        public init(symbol: String, title: String, text: String) {
            self.symbol = symbol
            self.title = title
            self.text = text
        }
    }

    /// Page 5 offers "Teamlink invullen"; page 6 is the last one
    public static let competitionPage = 4

    public static let pages: [Page] = [
        Page(symbol: "figure.tennis", title: "Welkom bij Squash Analyzer",
             text: "Jouw spel scherp in beeld. Je houdt een wedstrijd bij als coach of als scheidsrechter."),
        Page(symbol: "chart.bar.fill", title: "Coach",
             text: "Leg per punt vast wie scoorde, hoe (winner, druk, fout of servicepunt), waar op de baan en met welke slag. Na elke game zie je de analyse en krijg je advies."),
        Page(symbol: "flag.checkered", title: "Scheidsrechter",
             text: "Tik op de score van wie de rally wint. LET, STROKE, undo en de servicekant zitten erbij; de app houdt games en tijd bij."),
        Page(symbol: "medal.fill", title: "Kies speler",
             text: "Sla spelers op en kies ze bij het starten via Kies speler. Alleen dan verdienen ze badges en groeit hun profiel over de wedstrijden."),
        Page(symbol: "person.2.circle", title: "Competitie",
             text: "Speel je bij SBN? Vul je teamlink in, dan zie je je programma en de stand, en deel je een teamwedstrijd live met je team."),
        Page(symbol: "square.and.arrow.up", title: "Live meekijken en je gegevens",
             text: "Met LIVE deel je de stand met een link. Alles staat op je eigen telefoon: maak af en toe een back-up in Instellingen."),
    ]
}

/// The store pages and the feedback address, for "Deel de app" and "Feedback sturen"
public enum AppLinks {
    public static let playStore = URL(string: "https://play.google.com/store/apps/details?id=com.squashanalyzer.android")!
    public static let appStore = URL(string: "https://apps.apple.com/app/squash-analyzer/id6758676921")!
    public static let feedbackAddress = "info@squashanalyzer.com"

    /// What "Deel de app" sends: both stores, so it works for every phone
    public static var shareText: String {
        "Squash Analyzer: houd squashwedstrijden bij als coach of scheidsrechter.\n"
            + "Android: \(playStore.absoluteString)\n"
            + "iPhone: \(appStore.absoluteString)"
    }

    /// A new mail to the feedback address, with the app version in the subject
    public static func feedbackMail(appVersion: String) -> URL {
        let subject = "Feedback Squash Analyzer " + appVersion
        return URL(string: "mailto:\(feedbackAddress)?subject=\(mailEncoded(subject))")!
    }

    /// Letters, digits and a few safe marks stay; a space becomes %20, anything else is left out
    static func mailEncoded(_ text: String) -> String {
        var result = ""
        for character in text {
            if character == " " {
                result += "%20"
            } else if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_()".contains(character) {
                result += String(character)
            }
        }
        return result
    }
}
