import SwiftUI
import SquashAnalyzerCore

/// Every colour of the shared screens, from the style guide
/// (docs/style/tokens.json and docs/style/README.md). Screens use these, not
/// their own `Color(red:green:blue:)` values (T17); iOS' `AppColors` points
/// here for the same tokens.
///
/// Every token has a dark value (the look the app always had) and a light one
/// ("warm licht", `tokens.json` → `themes.light`); `AppTheme.shared` says which
/// one is drawn, and reading it here makes a screen draw again when it changes.
/// The light values of the functional colours are darker variants with at
/// least 4.5:1 contrast on the light background (3:1 for the server dot).
@MainActor
public enum SharedColors {
    private static var light: Bool { AppTheme.shared.isLight }

    private static func pick(_ dark: Color, _ light: Color) -> Color { SharedColors.light ? light : dark }

    /// #RRGGBB as a colour
    private static func hex(_ red: Int, _ green: Int, _ blue: Int) -> Color {
        Color(red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0)
    }

    // MARK: Base

    /// True black screen background; warm off-white in light (#F7F3ED)
    public static var background: Color { pick(Color.black, hex(0xF7, 0xF3, 0xED)) }
    /// Titles and button names (#F2EDE6; light #26211C)
    public static var textPrimary: Color { pick(Color(red: 0.95, green: 0.93, blue: 0.90), hex(0x26, 0x21, 0x1C)) }
    /// Descriptions, metadata (#B3ADA6; light #71665B)
    public static var textSecondary: Color { pick(Color(red: 0.70, green: 0.68, blue: 0.65), hex(0x71, 0x66, 0x5B)) }
    /// Small labels, disabled text
    public static var textMuted: Color { pick(Color(red: 0.50, green: 0.48, blue: 0.45), hex(0x78, 0x6C, 0x60)) }

    // MARK: Accents

    /// Brand orange (#F28C26), also player 1; in light the deep orange for text and controls (#A94F08)
    public static var accent: Color { pick(Color(red: 0.95, green: 0.55, blue: 0.15), hex(0xA9, 0x4F, 0x08)) }
    /// The bright brand orange in both themes, for decoration and large areas only (never small text on light)
    public static var brandAccent: Color { Color(red: 0.95, green: 0.55, blue: 0.15) }
    /// Gold for statistics, badges and highlights
    public static var gold: Color { pick(Color(red: 0.90, green: 0.72, blue: 0.35), hex(0x8A, 0x64, 0x12)) }
    /// Player 2 (#59738C; light #405A73)
    public static var steelBlue: Color { pick(Color(red: 0.35, green: 0.45, blue: 0.55), hex(0x40, 0x5A, 0x73)) }
    /// Player 2 for small text and lines on black, where steel blue is too dark
    public static var steelBlueLight: Color { pick(Color(red: 0.50, green: 0.58, blue: 0.68), hex(0x40, 0x5A, 0x73)) }

    // MARK: Referee actions and states

    /// LET CALL of the right-hand player
    public static var coolBlue: Color { pick(Color(red: 0.42, green: 0.58, blue: 0.82), hex(0x2E, 0x5F, 0x9E)) }
    /// STROKE of the right-hand player
    public static var coolIndigo: Color { pick(Color(red: 0.55, green: 0.47, blue: 0.90), hex(0x5B, 0x47, 0xC2)) }
    /// STROKE of the left-hand player, errors and warnings
    public static var warmRed: Color { pick(Color(red: 0.85, green: 0.30, blue: 0.30), hex(0xB2, 0x3B, 0x3B)) }
    /// Good news: strengths in the analysis, "opgeslagen", a key that is set
    public static var positive: Color { pick(Color(red: 0.40, green: 0.78, blue: 0.45), hex(0x2E, 0x7A, 0x3A)) }
    /// Error messages and "Niet opslaan"
    public static var error: Color { pick(Color(red: 0.95, green: 0.40, blue: 0.35), hex(0xB2, 0x3A, 0x2E)) }
    /// The dot on the serving player's score
    public static var serverIndicator: Color { pick(Color(red: 1.0, green: 0.60, blue: 0.15), hex(0xC2, 0x62, 0x0A)) }
    /// The court floor (heatmap), the same in both themes
    public static var courtSand: Color { Color(red: 0.82, green: 0.72, blue: 0.60) }

    // MARK: Surfaces

    /// Panels, chips and cards on the scoring screens; white cards in light
    public static var surface: Color { pick(Color(red: 0.12, green: 0.10, blue: 0.08), Color.white) }
    /// A card that stands out a little more (Mijn team)
    public static var surfaceRaised: Color { pick(Color(red: 0.14, green: 0.12, blue: 0.10), Color.white) }
    /// Accent at 10% on black, pre-mixed so SwiftUI and Compose match (home tiles); in light the hover tint (#FFF6EB)
    public static var brandCard: Color { pick(Color(red: 0.095, green: 0.055, blue: 0.015), hex(0xFF, 0xF6, 0xEB)) }
    /// A faint white tint for cards in the analysis; white cards in light
    public static var cardTint: Color { tint(0.05) }

    // MARK: Theme helpers (in place of fixed white and black)

    /// A card or chip fill: white at `opacity` on black; on light a white card
    /// (stronger for the higher values, so pressed and selected still differ)
    public static func tint(_ opacity: Double) -> Color {
        SharedColors.light ? Color.white.opacity(min(1.0, opacity * 14.0)) : Color.white.opacity(opacity)
    }

    /// A card edge or divider: white at `opacity` on black; the warm border (#DEC9B4) on light
    public static func line(_ opacity: Double) -> Color {
        SharedColors.light ? hex(0xDE, 0xC9, 0xB4).opacity(min(1.0, opacity * 8.0)) : Color.white.opacity(opacity)
    }

    /// A player or action colour held back (the option not chosen): faint on
    /// black, stronger on light where a faint deep colour is hard to read
    public static func quiet(_ color: Color) -> Color {
        color.opacity(SharedColors.light ? 0.75 : 0.4)
    }

    /// The text colour itself as ink (white on black, dark on light), for text and icons at a given strength
    public static var ink: Color { pick(Color.white, hex(0x26, 0x21, 0x1C)) }

    /// Text and icons on a filled accent, gold or player colour: dark on the bright
    /// colours of the dark theme, white on the deep colours of the light one
    public static var onAccent: Color { pick(Color.black.opacity(0.8), Color.white) }

    /// The colour scheme for system parts (alerts, menus, keyboards, the status bar)
    public static var colorScheme: ColorScheme { SharedColors.light ? ColorScheme.light : ColorScheme.dark }

    /// For `.preferredColorScheme` on a screen or sheet: nothing forced under
    /// "Systeem" (forcing would hide the phone's own setting from the app)
    public static var preferredScheme: ColorScheme? { AppTheme.shared.followsSystem ? nil : colorScheme }

    // MARK: The shared result picture (ResultCardPreview, iOS ResultCardImage, Android ResultImage)
    // Always dark: a shared picture looks the same whichever theme the sender uses

    public static let pictureBackground = Color(red: 0.12, green: 0.105, blue: 0.09)
    public static let pictureMuted = Color(red: 0.56, green: 0.54, blue: 0.52)
    public static let pictureChip = Color(red: 0.17, green: 0.165, blue: 0.17)
}
