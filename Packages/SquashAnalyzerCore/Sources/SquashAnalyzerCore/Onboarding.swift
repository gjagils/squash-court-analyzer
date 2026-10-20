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

    /// The first page shows the three themes in the sticker's order (scheidsen, coachen, delen) instead of one symbol
    public static let welcomePage = 0

    /// The symbols are the home screen's outline icons (AppSymbol names)
    public static let pages: [Page] = [
        Page(symbol: "", title: "Welkom bij Squash Analyzer",
             text: "Jouw spel scherp in beeld. Fluit een wedstrijd, coach je teamgenoot en deel de stand met je team."),
        Page(symbol: "whistle", title: "Scheidsrechter",
             text: "Tik op de score van wie de rally wint. LET, STROKE, undo en de servicekant zitten erbij; de app houdt games en tijd bij."),
        Page(symbol: "list.bullet.clipboard", title: "Coach",
             text: "Om je teamgenoot beter te coachen. Leg per punt vast wie scoorde, hoe, waar op de baan en met welke slag. Na elke game zie je de analyse, en de coachkaart laat je speler in één scherm zien waar het om draait."),
        Page(symbol: "person.2", title: "Kies speler",
             text: "Sla spelers op en kies ze bij het starten via Kies speler. Alleen dan verdienen ze badges en groeit hun profiel over de wedstrijden."),
        Page(symbol: "trophy", title: "Competitie",
             text: "Speel je bij SBN? Vul je teamlink in, dan zie je je programma en de stand. Op de wedstrijdavond houd je de teamwedstrijd bij, van E1 tot E4."),
        Page(symbol: "square.and.arrow.up", title: "Delen",
             text: "Houd je teamgenoten en supporters op de hoogte van de wedstrijden en de competitie. Met LIVE kijken ze mee via een link of op hun vergrendelscherm. Alles staat op je eigen telefoon: maak af en toe een back-up in Instellingen."),
    ]
}

/// "Nieuw in 3.0": one sheet at the first start of a new version, for
/// everyone (choice Gerd-Jan, 20 October 2026). "Rondleiding" opens the tour
/// from there, "Aan de slag" skips it; either way the badge reset and the
/// cleanup question follow.
public enum WhatsNew {
    /// The what's-new version this device has seen (0 = none)
    public static let storageKey = "whatsNewVersion"
    /// 1 = 3.0; raise it with new items for a later version
    public static let currentVersion = 1
    public static let title = "Nieuw in 3.0"
    public static let intro = "Squash Analyzer is flink gegroeid. Dit zijn de grootste veranderingen."

    public static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < currentVersion
    }

    /// The symbols are the home screen's outline icons (AppSymbol names)
    public static let items: [Onboarding.Page] = [
        Onboarding.Page(symbol: "trophy", title: "Competitie",
                        text: "Houd een hele teamwedstrijd bij, van E1 tot E4, met de puntentelling van de SBN."),
        Onboarding.Page(symbol: "square.and.arrow.up", title: "Live meekijken",
                        text: "Je team en supporters volgen de stand via een link of op hun vergrendelscherm."),
        Onboarding.Page(symbol: "medal", title: "Badges",
                        text: "Verdien badges in brons, zilver en goud. Vanaf 23 oktober begint iedereen opnieuw."),
        Onboarding.Page(symbol: "list.bullet.clipboard", title: "Coachen",
                        text: "Leg per rally de slag en de plek op de baan vast. Na afloop is er een coachkaart."),
        Onboarding.Page(symbol: "person.2", title: "Mijn team",
                        text: "Stand en programma van je SBN-team. Je teamgenoten staan klaar om te kiezen als je gaat scheidsen of coachen."),
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
