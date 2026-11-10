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

/// "Nieuw in 4.0": at the first start of a new version, for everyone (choice
/// Gerd-Jan, 20 October 2026). Since 4.0 a carousel like the tour (Gerd-Jan,
/// 10 November 2026): the more teammates have the app and an account, the more
/// of your own matches reach you, so two pages ask for exactly that. The
/// badge reset and the cleanup question follow as before.
public enum WhatsNew {
    /// The what's-new version this device has seen (0 = none)
    public static let storageKey = "whatsNewVersion"
    /// 1 = 3.0, 2 = 3.1, 3 = 3.2, 4 = 4.0; raise it with new pages for a later version
    public static let currentVersion = 4
    public static var title: String { L10n.text("Nieuw in 4.0") }

    /// What a page's button does
    public enum Action: Equatable, Sendable {
        case none
        /// Opens Mijn account (signing in or making the account)
        case account
        /// Shares the app with the team (`AppLinks.teamShareText`)
        case shareWithTeam
    }

    /// The page with "Account maken" and the one with "Deel met je team"
    public static let accountPage = 1
    public static let sharePage = 2

    public static func action(onPage page: Int) -> Action {
        if page == accountPage { return Action.account }
        if page == sharePage { return Action.shareWithTeam }
        return Action.none
    }

    public static func shouldShow(seenVersion: Int) -> Bool {
        seenVersion < currentVersion
    }

    /// During a test round the carousel comes back once with every new build,
    /// so testers see what it says (Gerd-Jan, 10 November 2026). Set to false
    /// for the build that goes to production: then it shows once per version,
    /// like "Nieuw in 3.2". Check the pages before every release.
    public static let perBuild = true
    /// The build (app version text) the carousel was last seen in
    public static let buildStorageKey = "whatsNewBuild"

    public static func shouldShow(seenVersion: Int, seenBuild: String, build: String) -> Bool {
        if seenVersion < currentVersion { return true }
        return perBuild && !build.isEmpty && seenBuild != build
    }

    /// The symbols are the home screen's outline icons (AppSymbol names)
    public static var items: [Onboarding.Page] { [
        Onboarding.Page(symbol: "medal", title: L10n.text("Jouw wedstrijden, jouw badges"),
                        text: L10n.text("Houdt een teamgenoot of coach jouw partij bij, dan komt die wedstrijd nu bij jou terecht. Hij telt mee voor je eigen badges, je kaart en je vorm.")),
        Onboarding.Page(symbol: "person.crop.circle", title: L10n.text("Maak je account"),
                        text: L10n.text("Het kost een minuut: je e-mailadres en je kiest jezelf uit je SBN-team. Een account is niet verplicht; zonder werkt alles zoals je gewend bent.")),
        Onboarding.Page(symbol: "person.2", title: L10n.text("Hoe meer teamgenoten, hoe meer badges"),
                        text: L10n.text("Elke teamgenoot met de app kan jouw partijen fluiten of coachen. Deel de app met je team, dan krijg je na elke competitieavond je eigen wedstrijden.")),
        Onboarding.Page(symbol: "trophy", title: L10n.text("Teamwedstrijd zonder gedoe"),
                        text: L10n.text("Maakt iemand uit je team een teamwedstrijd, dan staat hij op je beginscherm. Eén tik en je doet mee, en je krijgt een melding bij elke uitslag.")),
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

    /// What "Deel met je team" sends (Nieuw in 4.0, the account reminder): why
    /// teammates should have the app too, and both stores
    public static var teamShareText: String {
        L10n.text("Ik houd onze squashwedstrijden bij met Squash Analyzer. Zet hem ook op je telefoon en maak een account: dan tellen de partijen die we van elkaar bijhouden mee voor je eigen badges.") + "\n"
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
