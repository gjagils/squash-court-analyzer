import Foundation
import Observation

// Licht of donker (docs/style/README.md, "Lichte modus — warm licht"). The
// choice is stored per device; the default for everyone is dark, the look the
// app always had (decision Gerd-Jan, 11 October 2026).

/// The choice in Instellingen → Weergave
public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public static let storageKey = "appearance"
    public static let standard = AppAppearance.dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Systeem"
        case .light: return "Licht"
        case .dark: return "Donker"
        }
    }

    /// The stored value; anything unknown (or nothing) is the default
    public static func from(stored raw: String?) -> AppAppearance {
        for candidate in AppAppearance.allCases where candidate.rawValue == raw {
            return candidate
        }
        return AppAppearance.standard
    }

    /// Whether the screens are light, given what the phone itself is set to
    public func isLight(systemIsDark: Bool) -> Bool {
        switch self {
        case .system: return !systemIsDark
        case .light: return true
        case .dark: return false
        }
    }
}

/// The palette the screens draw with right now. `SharedColors` reads it, so a
/// screen draws again when it changes; the app's root view sets it.
@MainActor
@Observable
public final class AppTheme {
    public static let shared = AppTheme()

    /// Starts from the stored choice, so a light app does not open dark for a
    /// moment ("Systeem" is settled by the root view once it knows the phone's setting)
    public var isLight: Bool
    /// "Systeem": screens force no colour scheme, so the phone's own setting comes through
    public var followsSystem: Bool

    public init(defaults: UserDefaults = UserDefaults.standard) {
        let appearance = AppAppearance.from(stored: defaults.string(forKey: AppAppearance.storageKey))
        isLight = appearance == AppAppearance.light
        followsSystem = appearance == AppAppearance.system
    }
}
