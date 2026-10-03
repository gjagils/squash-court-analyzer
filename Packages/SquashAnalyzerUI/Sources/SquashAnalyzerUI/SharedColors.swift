import SwiftUI

/// Every colour of the shared screens, from the style guide
/// (docs/style/tokens.json and docs/style/README.md). Screens use these, not
/// their own `Color(red:green:blue:)` values (T17); iOS' `AppColors` points
/// here for the same tokens.
public enum SharedColors {
    // MARK: Base

    /// True black screen background
    public static let background = Color.black
    /// Titles and button names (#F2EDE6)
    public static let textPrimary = Color(red: 0.95, green: 0.93, blue: 0.90)
    /// Descriptions, metadata (#B3ADA6)
    public static let textSecondary = Color(red: 0.70, green: 0.68, blue: 0.65)
    /// Small labels, disabled text
    public static let textMuted = Color(red: 0.50, green: 0.48, blue: 0.45)

    // MARK: Accents

    /// Brand orange (#F28C26), also player 1
    public static let accent = Color(red: 0.95, green: 0.55, blue: 0.15)
    /// Gold for statistics, badges and highlights
    public static let gold = Color(red: 0.90, green: 0.72, blue: 0.35)
    /// Player 2 (#59738C)
    public static let steelBlue = Color(red: 0.35, green: 0.45, blue: 0.55)
    /// Player 2 for small text and lines on black, where steel blue is too dark
    public static let steelBlueLight = Color(red: 0.50, green: 0.58, blue: 0.68)

    // MARK: Referee actions and states

    /// LET CALL of the right-hand player
    public static let coolBlue = Color(red: 0.42, green: 0.58, blue: 0.82)
    /// STROKE of the right-hand player
    public static let coolIndigo = Color(red: 0.55, green: 0.47, blue: 0.90)
    /// STROKE of the left-hand player, errors and warnings
    public static let warmRed = Color(red: 0.85, green: 0.30, blue: 0.30)
    /// Good news: strengths in the analysis, "opgeslagen", a key that is set
    public static let positive = Color(red: 0.40, green: 0.78, blue: 0.45)
    /// Error messages and "Niet opslaan"
    public static let error = Color(red: 0.95, green: 0.40, blue: 0.35)
    /// The dot on the serving player's score
    public static let serverIndicator = Color(red: 1.0, green: 0.60, blue: 0.15)
    /// The court floor (heatmap)
    public static let courtSand = Color(red: 0.82, green: 0.72, blue: 0.60)

    // MARK: Surfaces

    /// Panels, chips and cards on the scoring screens
    public static let surface = Color(red: 0.12, green: 0.10, blue: 0.08)
    /// A card that stands out a little more (Mijn team)
    public static let surfaceRaised = Color(red: 0.14, green: 0.12, blue: 0.10)
    /// Accent at 10% on black, pre-mixed so SwiftUI and Compose match (home tiles)
    public static let brandCard = Color(red: 0.095, green: 0.055, blue: 0.015)
    /// A faint white tint for cards in the analysis
    public static let cardTint = Color.white.opacity(0.05)

    // MARK: The shared result picture (ResultCardPreview, iOS ResultCardImage, Android ResultImage)

    public static let pictureBackground = Color(red: 0.12, green: 0.105, blue: 0.09)
    public static let pictureMuted = Color(red: 0.56, green: 0.54, blue: 0.52)
    public static let pictureChip = Color(red: 0.17, green: 0.165, blue: 0.17)
}
