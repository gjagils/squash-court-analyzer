import SwiftUI
#if SKIP
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

/// Samsung's "groot" font size
private let maxFontScale: Float = Float(1.3)
#endif

/// The scoring screens are full and their numbers already large: on Android
/// the system font size counts up to `maxFontScale` there (Samsung "groot" is
/// 1.3), so a bigger setting no longer breaks "Sluiten", "Rechts" or
/// "TIK = PUNT" in two. iOS uses fixed sizes on these screens, so nothing
/// changes there.
struct FontScaleCap<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if SKIP
        ComposeView { context in
            let density = LocalDensity.current
            let capped = Density(density.density, min(density.fontScale, maxFontScale))
            CompositionLocalProvider(LocalDensity.provides(capped)) {
                content.Compose(context: context)
            }
        }
        #else
        content
        #endif
    }
}
