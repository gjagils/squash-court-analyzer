import SwiftUI

/// The one way the app picks a font: a fixed size in points (sp on Android),
/// with an optional weight and design. Every screen goes through here, so a
/// later step (letting text grow with the system text size) is one change.
/// `scripts/lint.sh` keeps `.system(size:)` out of the other files.
public enum SharedFonts {
    public static func system(_ size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font {
        return Font.system(size: size, weight: weight, design: design)
    }
}

/// A section title in capitals in the accent colour ("PARTIJEN", "LIVE"),
/// as on the Competitie screens
public struct SectionHeader: View {
    let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(SharedFonts.system(11, weight: .semibold))
            .tracking(1.4)
            .foregroundColor(SharedColors.accent)
    }
}

/// A small label in a tinted capsule: a coaching focus tag. No ChoiceChip next to it on
/// purpose: there is only one selectable chip (focus at Spelers), see docs/bewuste-keuzes.md.
public struct TagChip: View {
    let text: String
    let color: Color
    let size: CGFloat
    let fillOpacity: Double

    public init(_ text: String, color: Color, size: CGFloat = 11, fillOpacity: Double = 0.12) {
        self.text = text
        self.color = color
        self.size = size
        self.fillOpacity = fillOpacity
    }

    public var body: some View {
        Text(text)
            .font(SharedFonts.system(size, weight: .medium, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            // .background(colour) + clipShape: filled shapes behind text misbehave on Android
            .background(color.opacity(fillOpacity))
            .clipShape(Capsule())
    }
}
