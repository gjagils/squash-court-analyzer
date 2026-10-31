import Foundation

/// Work for a later major release that already lives on `main` but stays off
/// in the store builds of the current one (docs/releaseplan-3x-4.0.md). The app
/// sets these once at launch from its build configuration; a 3.x store build
/// leaves them off.
public final class Features: @unchecked Sendable {
    public static let shared = Features()

    /// 4.0: the player account with central badges
    /// (docs/voorstel-spelersaccount-4.0.md). On only in 4.0 test builds:
    /// iOS `xcodebuild … SQUASH_PLAYER_ACCOUNT=YES`, Android
    /// `./gradlew … -PsquashPlayerAccount=true`.
    public var playerAccount = false

    public init() {}

    /// The value of a build setting as the app reads it: "YES"/"true"/"1" is on,
    /// anything else (missing, "NO", an unexpanded "$(…)") is off
    public static func isOn(_ setting: String?) -> Bool {
        guard let setting else { return false }
        let value = setting.trimmingCharacters(in: .whitespaces).lowercased()
        return value == "yes" || value == "true" || value == "1"
    }
}
