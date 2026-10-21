import Foundation

// English variant (3.0, docs/i18n.md). Dutch is the source language: every
// text is written in Dutch in the code and that Dutch text is the key into
// `Resources/en.lproj/Localizable.strings`. A Dutch phone never looks
// anything up, so the Dutch app reads exactly as it did before.

/// The language the app's texts are shown in
public enum AppLanguage: String, CaseIterable, Sendable {
    case dutch = "nl"
    case english = "en"

    /// Dutch when the phone's first preferred language is Dutch, English for
    /// every other language
    public static var current: AppLanguage {
        if let forced = AppLanguageOverride.shared.language { return forced }
        return AppLanguage.from(preferredLanguages: Locale.preferredLanguages)
    }

    /// The language for a list such as `Locale.preferredLanguages` ("nl-NL", "en-GB", ...)
    public static func from(preferredLanguages: [String]) -> AppLanguage {
        guard let first = preferredLanguages.first else { return AppLanguage.dutch }
        let code = first.lowercased()
        if code == "nl" || code.hasPrefix("nl-") || code.hasPrefix("nl_") { return AppLanguage.dutch }
        return AppLanguage.english
    }

    /// The value of the optional `lang` field sent to the live server: "nl" or "en"
    public var code: String { rawValue }

    /// The locale for day and month names: Dutch as before, for English the
    /// phone's own locale when that is English (en_US, en_GB, ...), else British English
    public var locale: Locale {
        switch self {
        case .dutch: return Locale(identifier: "nl_NL")
        case .english:
            let current = Locale.current
            if current.identifier.lowercased().hasPrefix("en") { return current }
            return Locale(identifier: "en_GB")
        }
    }
}

/// Forces a language, for tests (and a possible language setting later);
/// nil follows the phone
public final class AppLanguageOverride: @unchecked Sendable {
    public static let shared = AppLanguageOverride()
    public var language: AppLanguage? = nil

    public init() {}
}

/// Core's user-facing texts in the app's language
public enum L10n {
    /// The English strings table; nil when the resource is missing (the Dutch text shows then)
    static let englishBundle: Bundle? = L10n.bundle(for: "en")

    static func bundle(for code: String) -> Bundle? {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: code) else {
            return nil
        }
        return Bundle(url: url.deletingLastPathComponent())
    }

    /// `key` is the Dutch text. Arguments fill its `%@` placeholders in order,
    /// or `%1$@`, `%2$@` by position (a translation may reorder them). Numbers
    /// are passed as text, so every placeholder is `%@`.
    public static func text(_ key: String, _ arguments: String...) -> String {
        return L10n.text(key, arguments: arguments, language: AppLanguage.current)
    }

    public static func text(_ key: String, arguments: [String], language: AppLanguage) -> String {
        var template = key
        if language == AppLanguage.english, let bundle = L10n.englishBundle {
            template = bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return L10n.fill(template, arguments)
    }

    /// Whether the English table has a translation for `key` (for tests)
    public static func hasEnglish(_ key: String) -> Bool {
        guard let bundle = L10n.englishBundle else { return false }
        let missing = "__L10n_missing__"
        return bundle.localizedString(forKey: key, value: missing, table: nil) != missing
    }

    static let digitCharacters: [String] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

    /// Replaces `%@` (in order) and `%1$@`... (by position) with `arguments`,
    /// in one pass so an argument that itself contains "%@" stays as it is.
    /// Plain loop over characters as text, so Skip transpiles it as is.
    static func fill(_ template: String, _ arguments: [String]) -> String {
        if arguments.isEmpty { return template }
        var result = ""
        // What was read of a possible placeholder: "%", "%2" or "%2$"
        var pending = ""
        var digits = ""
        var sawDollar = false
        var next = 0
        for character in template {
            let text = String(character)
            if pending.isEmpty {
                if text == "%" { pending = text } else { result += text }
                continue
            }
            if text == "@" && digits.isEmpty {
                // "%@": the next argument in order
                result += next < arguments.count ? arguments[next] : ""
                next += 1
                pending = ""
                continue
            }
            if text == "@" && sawDollar {
                // "%2$@": the argument at that position
                if let position = Int(digits) {
                    result += position >= 1 && position <= arguments.count ? arguments[position - 1] : ""
                } else {
                    result += pending + text
                }
                pending = ""
                digits = ""
                sawDollar = false
                continue
            }
            if !sawDollar && L10n.digitCharacters.contains(text) {
                pending += text
                digits += text
                continue
            }
            if !sawDollar && !digits.isEmpty && text == "$" {
                pending += text
                sawDollar = true
                continue
            }
            // Not a placeholder after all: keep what was read as it is
            result += pending
            pending = ""
            digits = ""
            sawDollar = false
            if text == "%" { pending = text } else { result += text }
        }
        result += pending
        return result
    }
}
