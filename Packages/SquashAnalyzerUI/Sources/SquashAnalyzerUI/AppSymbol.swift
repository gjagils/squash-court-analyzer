import SwiftUI
#if SKIP
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.outlined.Undo
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.KeyboardArrowDown
import androidx.compose.material.icons.outlined.KeyboardArrowUp
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.SportsScore
import androidx.compose.material.icons.outlined.FrontHand
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.MilitaryTech
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.FastForward
import androidx.compose.material.icons.outlined.HourglassBottom
import androidx.compose.material.icons.outlined.Psychology
import androidx.compose.material.icons.automirrored.outlined.DirectionsWalk
import androidx.compose.material.icons.outlined.ArrowCircleUp
import androidx.compose.material.icons.outlined.Error
import androidx.compose.material.icons.automirrored.outlined.DirectionsRun
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material.icons.outlined.GpsFixed
import androidx.compose.material.icons.outlined.ArrowCircleDown
import androidx.compose.material.icons.outlined.CenterFocusStrong
import androidx.compose.material.icons.outlined.OfflineBolt
import androidx.compose.material.icons.outlined.PieChart
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Place
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Replay
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.SportsTennis
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.SwapHoriz
import androidx.compose.material.icons.outlined.Timer
import androidx.compose.material.icons.outlined.Sync
import androidx.compose.material.icons.outlined.VerticalAlignBottom
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Icon
import androidx.compose.ui.unit.dp
#endif

/// An SF Symbol on Apple and the matching Material icon on Android, always
/// as an outline (Material "Outlined"; on Apple the symbol without ".fill").
/// The tour and home-tile icons (whistle, clipboard, players, cup, share) are
/// drawn by the app itself on both platforms (`OutlineIcon`). Skip's
/// `Image(systemName:)` only knows a small set of SF Symbols and draws a
/// warning triangle for the rest (forced/unforced error, service point,
/// undo, medal, cross, volley, drop…), so every symbol the shared screens use
/// is mapped here. The colour is passed in because Compose cannot read the
/// SwiftUI foreground colour around it.
struct AppSymbol: View {
    let name: String
    let size: CGFloat
    let color: Color
    /// Stroke weight of the SF Symbol (Apple only; Material icons have one weight)
    let weight: Font.Weight

    init(_ name: String, size: CGFloat, color: Color, weight: Font.Weight = .regular) {
        self.name = name
        self.size = size
        self.color = color
        self.weight = weight
    }

    /// Decoration: the button or text next to it says what it means, so
    /// VoiceOver/TalkBack never read out a symbol name like "chevron.right"
    var body: some View {
        symbol.accessibilityHidden(true)
    }

    @ViewBuilder
    private var symbol: some View {
        if let icon = OutlineIcon.named(name) {
            OutlineIconView(icon: icon, color: color, size: size)
        } else {
            platformSymbol
        }
    }

    @ViewBuilder
    private var platformSymbol: some View {
        #if SKIP
        if let vector = AppSymbol.material(name) {
            ComposeView { context in
                Icon(imageVector: vector, contentDescription: nil, modifier: context.modifier.size(size.dp), tint: color.colorImpl())
            }
        } else {
            Image(systemName: name)
                .font(SharedFonts.system(size, weight: weight))
                .foregroundColor(color)
        }
        #else
        Image(systemName: AppSymbol.outlined(name))
            .font(SharedFonts.system(size, weight: weight))
            .foregroundColor(color)
        #endif
    }

    #if !SKIP
    /// The app draws every symbol as an outline, like the sticker (decision
    /// 12 October 2026): "medal.fill" becomes "medal" when that symbol exists
    static func outlined(_ name: String) -> String {
        guard name.hasSuffix(".fill") else { return name }
        let plain = String(name.dropLast(5))
        #if canImport(UIKit)
        return UIImage(systemName: plain) != nil ? plain : name
        #else
        return NSImage(systemSymbolName: plain, accessibilityDescription: nil) != nil ? plain : name
        #endif
    }
    #endif

    #if SKIP
    static func material(_ name: String) -> androidx.compose.ui.graphics.vector.ImageVector? {
        switch name {
        case "star.fill": return Icons.Outlined.StarBorder
        case "arrow.triangle.2.circlepath": return Icons.Outlined.Sync
        case "xmark.circle": return Icons.Outlined.Cancel
        case "hand.raised.fill": return Icons.Outlined.FrontHand
        case "figure.tennis": return Icons.Outlined.SportsTennis
        case "pin.fill": return Icons.Outlined.PushPin
        case "medal", "medal.fill": return Icons.Outlined.MilitaryTech
        case "arrow.uturn.backward": return Icons.AutoMirrored.Outlined.Undo
        case "arrow.counterclockwise": return Icons.Outlined.Replay
        case "clock.arrow.circlepath": return Icons.Outlined.History
        case "arrow.left.and.right": return Icons.Outlined.SwapHoriz
        case "bolt.fill": return Icons.Outlined.Bolt
        case "arrow.down.to.line": return Icons.Outlined.VerticalAlignBottom
        case "xmark": return Icons.Outlined.Close
        case "square.and.arrow.down": return Icons.Outlined.Download
        case "trash": return Icons.Outlined.Delete
        case "pencil": return Icons.Outlined.Edit
        case "plus": return Icons.Outlined.Add
        case "person.crop.circle": return Icons.Outlined.AccountCircle
        case "chart.bar.fill", "chart.bar.xaxis": return Icons.Outlined.BarChart
        case "crown.fill": return Icons.Outlined.EmojiEvents
        case "flag.checkered": return Icons.Outlined.SportsScore
        case "gearshape": return Icons.Outlined.Settings
        case "timer": return Icons.Outlined.Timer
        case "camera.fill": return Icons.Outlined.PhotoCamera
        case "hare.fill": return Icons.Outlined.FastForward
        case "tortoise.fill": return Icons.Outlined.HourglassBottom
        case "brain.head.profile", "brain": return Icons.Outlined.Psychology
        case "figure.walk": return Icons.AutoMirrored.Outlined.DirectionsWalk
        case "arrow.up.circle": return Icons.Outlined.ArrowCircleUp
        case "exclamationmark.circle": return Icons.Outlined.Error
        case "figure.run": return Icons.AutoMirrored.Outlined.DirectionsRun
        case "exclamationmark.triangle": return Icons.Outlined.Warning
        case "star": return Icons.Outlined.StarBorder
        case "target": return Icons.Outlined.GpsFixed
        case "arrow.down.right.circle": return Icons.Outlined.ArrowCircleDown
        case "scope": return Icons.Outlined.CenterFocusStrong
        case "bolt.circle": return Icons.Outlined.OfflineBolt
        case "chart.pie.fill": return Icons.Outlined.PieChart
        case "lightbulb.fill": return Icons.Outlined.Lightbulb
        case "person.badge.plus": return Icons.Outlined.PersonAdd
        case "person.2.circle": return Icons.Outlined.Groups
        case "mappin": return Icons.Outlined.Place
        case "sparkles": return Icons.Outlined.AutoAwesome
        case "chevron.down": return Icons.Outlined.KeyboardArrowDown
        case "chevron.up": return Icons.Outlined.KeyboardArrowUp
        case "chevron.left": return Icons.AutoMirrored.Outlined.KeyboardArrowLeft
        case "chevron.right": return Icons.AutoMirrored.Outlined.KeyboardArrowRight
        case "person.fill": return Icons.Outlined.Person
        case "arrow.right": return Icons.AutoMirrored.Outlined.ArrowForward
        case "arrow.left": return Icons.AutoMirrored.Outlined.ArrowBack
        case "play.fill": return Icons.Outlined.PlayArrow
        case "magnifyingglass": return Icons.Outlined.Search
        default: return nil
        }
    }
    #endif
}
