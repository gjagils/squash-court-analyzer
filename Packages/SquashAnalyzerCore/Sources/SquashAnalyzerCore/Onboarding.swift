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

    /// Page 5 offers "Zoek je club"; page 6 is the last one
    public static let competitionPage = 4

    /// The first page shows the three themes in the sticker's order (scheidsen, coachen, delen) instead of one symbol
    public static let welcomePage = 0

    /// The symbols are the home screen's outline icons (AppSymbol names)
    public static var pages: [Page] { [
        Page(symbol: "", title: L10n.text("Welkom bij Squash Analyzer"),
             text: L10n.text("Jouw spel scherp in beeld. Fluit een wedstrijd, coach je teamgenoot en deel de stand met je team.")),
        Page(symbol: "whistle", title: L10n.text("Scheidsrechter"),
             text: L10n.text("Tik op de score van wie de rally wint. LET, STROKE, undo en de servicekant zitten erbij; de app houdt games en tijd bij.")),
        Page(symbol: "list.bullet.clipboard", title: "Coach",
             text: L10n.text("Om je teamgenoot beter te coachen. Leg per punt vast wie scoorde, hoe, waar op de baan en met welke slag, of coach eenvoudig: alleen wie en waar. Na elke game zie je de analyse, en de coachkaart laat je speler in één scherm zien waar het om draait.")),
        Page(symbol: "person.2", title: L10n.text("Kies speler"),
             text: L10n.text("Sla spelers op en kies ze bij het starten via Kies speler. Alleen dan verdienen ze badges en groeit hun profiel over de wedstrijden.")),
        Page(symbol: "trophy", title: L10n.text("Competitie"),
             text: L10n.text("Speel je bij SBN? Zoek je club en kies je team, dan zie je je programma en de stand. Op de wedstrijdavond houd je de teamwedstrijd bij, van E1 tot E4.")),
        Page(symbol: "square.and.arrow.up", title: L10n.text("Delen"),
             text: L10n.text("Houd je teamgenoten en supporters op de hoogte van de wedstrijden en de competitie. Met LIVE kijken ze mee via een link of op hun vergrendelscherm. Alles staat op je eigen telefoon: maak af en toe een back-up in Instellingen.")),
    ] }
}

/// "Nieuw in 3.2": one sheet at the first start of a new version, for
/// everyone (choice Gerd-Jan, 20 October 2026). "Rondleiding" opens the tour
/// from there, "Aan de slag" skips it; either way the badge reset and the
/// cleanup question follow.
public enum WhatsNew {
    /// The what's-new version this device has seen (0 = none)
    public static let storageKey = "whatsNewVersion"
    /// 1 = 3.0, 2 = 3.1, 3 = 3.2; raise it with new items for a later version
    public static let currentVersion = 3
    public static var title: String { L10n.text("Nieuw in 3.2") }
    public static var intro: String { L10n.text("Squash Analyzer is weer een stap verder, op de baan en op de competitieavond. Dit is wat je merkt.") }

    public static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < currentVersion
    }

    /// The symbols are the home screen's outline icons (AppSymbol names).
    /// 3.2 (Gerd-Jan, 7 November 2026): five items, in this order
    public static var items: [Onboarding.Page] { [
        Onboarding.Page(symbol: "trophy", title: L10n.text("Teamwedstrijd op je beginscherm"),
                        text: L10n.text("Doe je mee aan een teamwedstrijd, dan staat die op je beginscherm, met de stand en E1 t/m E4. Eén tik en je fluit of coacht je partij.")),
        Onboarding.Page(symbol: "whistle", title: L10n.text("Officiële timers"),
                        text: L10n.text("Inspelen, 1 minuut tot de start en 2 minuten tussen de games. Je telefoon trilt bij het wisselen, bij 15 seconden en bij Time.")),
        Onboarding.Page(symbol: "list.bullet.clipboard", title: L10n.text("Makkelijker coachen"),
                        text: L10n.text("Ging het even te snel? Tik op wie scoort en dan op Niet gezien: de score loopt door. Uitgebreid of Eenvoudig kies je nu ook tussen de punten door.")),
        Onboarding.Page(symbol: "person.2", title: L10n.text("Ken je tegenstander"),
                        text: L10n.text("Bekijk het profiel van je tegenstander en zie bij Kies speler de onderlinge stand. Met een SquashLevels-link open je ook de ranglijst.")),
        Onboarding.Page(symbol: "sparkles", title: L10n.text("Kleine verbeteringen"),
                        text: L10n.text("Op sommige Android-toestellen is de weergave verbeterd, tegenstanders worden beter opgehaald bij competitiewedstrijden en je team toevoegen gaat makkelijker.")),
    ] }
}

/// The store pages and the feedback address, for "Deel de app" and "Feedback sturen"
public enum AppLinks {
    public static let playStore = URL(string: "https://play.google.com/store/apps/details?id=com.squashanalyzer.android")!
    public static let appStore = URL(string: "https://apps.apple.com/app/squash-analyzer/id6758676921")!
    public static let feedbackAddress = "info@squashanalyzer.com"

    /// What "Deel de app" sends: both stores, so it works for every phone
    public static var shareText: String {
        L10n.text("Squash Analyzer: houd squashwedstrijden bij als coach of scheidsrechter.") + "\n"
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
