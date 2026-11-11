import Foundation

/// The user manual on the website, one page per platform (website/handleiding).
/// Instellingen links to the page for the platform it runs on.
public enum UserManual {
    public static let iPhone = URL(string: "https://www.squashanalyzer.com/handleiding/iphone.html")!
    public static let android = URL(string: "https://www.squashanalyzer.com/handleiding/android.html")!
    /// "Waar vind ik mijn teamlink?" in the manual
    public static let iPhoneTeamLink = URL(string: "https://www.squashanalyzer.com/handleiding/iphone.html#teamlink-vinden")!
    public static let androidTeamLink = URL(string: "https://www.squashanalyzer.com/handleiding/android.html#teamlink-vinden")!

    /// "Stel een vraag" at the top of the manual (the speech bubble on the home screen, 11 November 2026)
    public static func question(android: Bool, english: Bool) -> URL {
        let page = english ? (android ? "en/guide/android.html" : "en/guide/iphone.html")
            : (android ? "handleiding/android.html" : "handleiding/iphone.html")
        return URL(string: "https://www.squashanalyzer.com/" + page + "#vraag")!
    }
}
