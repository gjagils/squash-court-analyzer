import SwiftUI
#if SKIP
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.FrontHand
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SportsTennis
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.VerticalAlignBottom
import androidx.compose.material3.Icon
import androidx.compose.ui.unit.dp
#endif

/// An SF Symbol on Apple and the matching Material icon on Android. Skip's
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

    var body: some View {
        #if SKIP
        if let vector = AppSymbol.material(name) {
            ComposeView { context in
                Icon(imageVector: vector, contentDescription: nil, modifier: context.modifier.size(size.dp), tint: color.colorImpl())
            }
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
        }
        #else
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
        #endif
    }

    #if SKIP
    static func material(_ name: String) -> androidx.compose.ui.graphics.vector.ImageVector? {
        switch name {
        case "star.fill": return Icons.Filled.Star
        case "arrow.triangle.2.circlepath": return Icons.Filled.Sync
        case "xmark.circle": return Icons.Filled.Cancel
        case "hand.raised.fill": return Icons.Filled.FrontHand
        case "figure.tennis": return Icons.Filled.SportsTennis
        case "pin.fill": return Icons.Filled.PushPin
        case "medal", "medal.fill": return Icons.Filled.MilitaryTech
        case "arrow.uturn.backward": return Icons.AutoMirrored.Filled.Undo
        case "arrow.counterclockwise": return Icons.Filled.Replay
        case "clock.arrow.circlepath": return Icons.Filled.History
        case "arrow.left.and.right": return Icons.Filled.SwapHoriz
        case "bolt.fill": return Icons.Filled.Bolt
        case "arrow.down.to.line": return Icons.Filled.VerticalAlignBottom
        case "xmark": return Icons.Filled.Close
        case "square.and.arrow.down": return Icons.Filled.Download
        case "trash": return Icons.Filled.Delete
        case "chart.bar.fill": return Icons.Filled.BarChart
        case "gearshape": return Icons.Filled.Settings
        case "timer": return Icons.Filled.Timer
        case "square.and.arrow.up": return Icons.Filled.Share
        case "chevron.left": return Icons.AutoMirrored.Filled.KeyboardArrowLeft
        case "chevron.right": return Icons.AutoMirrored.Filled.KeyboardArrowRight
        case "person.fill": return Icons.Filled.Person
        case "arrow.right": return Icons.AutoMirrored.Filled.ArrowForward
        case "arrow.left": return Icons.AutoMirrored.Filled.ArrowBack
        default: return nil
        }
    }
    #endif
}
