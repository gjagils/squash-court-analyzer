import Foundation

// The shared screens in Dutch and English (3.0). Dutch is the source: every
// key in Resources/Localizable.xcstrings is the Dutch text itself, so a key
// without a translation shows the Dutch as before. Text("…", bundle: .module)
// for a text view; loc("…") for everything that takes a String (ActionButton,
// SettingsRow, pageTitle, Button, alert, accessibilityLabel, messages in
// @State). Interpolations become %@ (String) or %lld (Int) in the key, the same
// on Apple and in SkipFoundation. Never for stored, sent or parsed values.

/// The Dutch text in the phone's language, from this module's string catalog
func loc(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: .module)
}

/// Dates and month names in the language of the texts: nl_NL as before, and
/// the catalog's English gives en_GB. Through the catalog so the date never
/// disagrees with the words around it.
var displayLocale: Locale {
    Locale(identifier: loc("nl_NL"))
}
