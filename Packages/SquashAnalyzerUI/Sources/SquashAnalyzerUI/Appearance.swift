import SwiftUI
import SquashAnalyzerCore
#if os(iOS) && !SKIP
import UIKit
#endif

/// Applies Instellingen → Weergave (Systeem, Licht, Donker) to everything
/// below: the palette of `SharedColors` (through `AppTheme.shared`) and the
/// system parts (alerts, menus, keyboard, status bar). Put on the app's root
/// view once; iOS and Android both do.
struct AppearanceRoot<Content: View>: View {
    let content: Content
    @AppStorage(AppAppearance.storageKey) private var stored = AppAppearance.standard.rawValue
    @Environment(\.colorScheme) private var system

    var body: some View {
        let appearance = AppAppearance.from(stored: stored)
        let key = stored + (system == ColorScheme.dark ? "-dark" : "-light")
        return content
            // Systeem: nothing forced, so the phone's own setting comes through
            .preferredColorScheme(appearance == AppAppearance.system ? nil : (appearance == AppAppearance.light ? ColorScheme.light : ColorScheme.dark))
            .task(id: key) {
                AppTheme.shared.followsSystem = appearance == AppAppearance.system
                AppTheme.shared.isLight = appearance.isLight(systemIsDark: system == ColorScheme.dark)
                AppearanceRoot.applyToWindows(appearance)
            }
    }

    /// iOS: every full-screen cover is its own presentation with its own status
    /// bar and system controls; the window's style reaches all of them at once
    static func applyToWindows(_ appearance: AppAppearance) {
        #if os(iOS) && !SKIP
        let style: UIUserInterfaceStyle
        switch appearance {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
        #endif
    }
}

extension View {
    /// The chosen look (Systeem, Licht, Donker) for the whole app; on the root view
    public func appAppearance() -> some View {
        AppearanceRoot(content: self)
    }
}

/// The choice itself, for Instellingen on iOS and Android
public struct AppearancePicker: View {
    @AppStorage(AppAppearance.storageKey) private var stored = AppAppearance.standard.rawValue

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weergave")
                .font(SharedFonts.system(16, weight: .semibold))
                .foregroundColor(SharedColors.textPrimary)
            Picker("Weergave", selection: $stored) {
                Text(AppAppearance.system.title).tag(AppAppearance.system.rawValue)
                Text(AppAppearance.light.title).tag(AppAppearance.light.rawValue)
                Text(AppAppearance.dark.title).tag(AppAppearance.dark.rawValue)
            }
            .pickerStyle(.segmented)
            // Drawn anew after a change: the segmented control keeps its old colours otherwise
            .id(stored)
            Text("Systeem volgt de instelling van je telefoon. Een uitslag die je als plaatje deelt, blijft donker.")
                .font(SharedFonts.system(12))
                .foregroundColor(SharedColors.textMuted)
        }
    }
}
