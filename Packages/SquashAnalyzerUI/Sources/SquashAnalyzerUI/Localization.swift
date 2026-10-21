import Foundation
import SquashAnalyzerCore

// The shared screens in Dutch and English (3.0). Dutch is the source: every
// key in Resources/Localizable.xcstrings is the Dutch text itself, so a key
// without a translation shows the Dutch as before. Text("…", bundle: textBundle)
// for a text view; loc("…") for everything that takes a String (ActionButton,
// SettingsRow, pageTitle, Button, alert, accessibilityLabel, messages in
// @State). Interpolations become %@ (String) or %lld (Int) in the key, the same
// on Apple and in SkipFoundation. Never for stored, sent or parsed values.

/// Dutch when the phone's first language is Dutch, English for every other
/// language (German, French…), decided here rather than by the system: a
/// missing language would otherwise fall back to the development language
/// (Dutch in this package, English in the iOS app) and differ per platform.
/// Gerd-Jan, 21 October 2026.
/// The same choice as Core (`AppLanguage.current`), so Core's texts and the
/// screens never disagree.
var textLanguage: String {
    AppLanguage.current.rawValue
}

/// The language folder of this module's catalog for `textLanguage`; the
/// module itself (key = Dutch) when the folder cannot be found
var textBundle: Bundle {
    #if SKIP
    return Bundle.module.localizedBundle(locale: Locale(identifier: textLanguage))
    #else
    guard let path = Bundle.module.path(forResource: textLanguage, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return Bundle.module }
    return bundle
    #endif
}

/// The Dutch text in the app's language, from this module's string catalog
func loc(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: textBundle)
}

/// Dates and month names in the language of the texts: nl_NL as before, and
/// the catalog's English gives en_GB. Through the catalog so the date never
/// disagrees with the words around it.
var displayLocale: Locale {
    Locale(identifier: loc("nl_NL"))
}
