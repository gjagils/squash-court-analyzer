import SwiftUI

/// The icons of the tour and the home tiles (and the medal of the badges),
/// drawn by the app itself so iOS
/// and Android show exactly the same picture (choice 11 October 2026; before,
/// Apple used SF Symbols and Android the Material icons, which differ in
/// shape). Every icon is an outline on a 24×24 grid in the spirit of the
/// sticker, scaled to the size it is shown at. `AppSymbol` draws these for
/// the SF Symbol names in `named`, so every screen gets them.
enum OutlineIcon {
    case whistle
    case clipboard
    case people
    case trophy
    case share
    case medal

    /// The icon for an SF Symbol name used in the shared screens, if it is one of ours
    static func named(_ name: String) -> OutlineIcon? {
        switch name {
        case "whistle": return .whistle
        case "list.bullet.clipboard", "list.bullet.clipboard.fill": return .clipboard
        case "person.2", "person.2.fill": return .people
        case "trophy", "trophy.fill": return .trophy
        case "square.and.arrow.up": return .share
        case "medal", "medal.fill": return .medal
        default: return nil
        }
    }

    /// The icon's lines on a 24×24 grid, multiplied by `scale`
    func path(scale: CGFloat) -> Path {
        let grid = IconGrid(scale: scale)
        var path = Path()
        switch self {
        case .whistle: OutlineIcon.drawWhistle(&path, grid)
        case .clipboard: OutlineIcon.drawClipboard(&path, grid)
        case .people: OutlineIcon.drawPeople(&path, grid)
        case .trophy: OutlineIcon.drawTrophy(&path, grid)
        case .share: OutlineIcon.drawShare(&path, grid)
        case .medal: OutlineIcon.drawMedal(&path, grid)
        }
        return path
    }

    /// A referee's whistle: a round body with the mouthpiece to the right,
    /// the air hole, and the ring for the cord at the top left
    private static func drawWhistle(_ path: inout Path, _ g: IconGrid) {
        // One outline: along the top of the mouthpiece, down its end, back
        // to the body, then round the body back to the top
        path.move(to: g.pt(9, 9.5))
        path.addLine(to: g.pt(20.3, 9.5))
        path.addQuadCurve(to: g.pt(21.5, 10.7), control: g.pt(21.5, 9.5))
        path.addLine(to: g.pt(21.5, 12.8))
        path.addQuadCurve(to: g.pt(20.3, 14), control: g.pt(21.5, 14))
        path.addLine(to: g.pt(14.41, 14))
        path.addArc(center: g.pt(9, 15), radius: g.len(5.5), startAngle: .degrees(-10.47), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        path.addEllipse(in: g.rect(6.7, 13.6, 3.2, 3.2))
        path.addEllipse(in: g.rect(1.87, 7.87, 3.8, 3.8))
    }

    /// A clipboard with three bulleted lines, the clip at the top
    private static func drawClipboard(_ path: inout Path, _ g: IconGrid) {
        // The board, with a gap in the top edge under the clip
        path.move(to: g.pt(15.5, 4))
        path.addLine(to: g.pt(18, 4))
        path.addQuadCurve(to: g.pt(20, 6), control: g.pt(20, 4))
        path.addLine(to: g.pt(20, 19))
        path.addQuadCurve(to: g.pt(18, 21), control: g.pt(20, 21))
        path.addLine(to: g.pt(6, 21))
        path.addQuadCurve(to: g.pt(4, 19), control: g.pt(4, 21))
        path.addLine(to: g.pt(4, 6))
        path.addQuadCurve(to: g.pt(6, 4), control: g.pt(4, 4))
        path.addLine(to: g.pt(8.5, 4))
        path.addRoundedRect(in: g.rect(8.5, 2.5, 7, 4), cornerSize: g.size(1.5, 1.5))
        for row in [10.5, 14.0, 17.5] {
            path.move(to: g.pt(8, row))
            path.addLine(to: g.pt(8.4, row))
            path.move(to: g.pt(11, row))
            path.addLine(to: g.pt(16, row))
        }
    }

    /// Two players side by side, the second a little behind the first
    private static func drawPeople(_ path: inout Path, _ g: IconGrid) {
        path.addEllipse(in: g.rect(5.7, 5, 6.6, 6.6))
        path.move(to: g.pt(3.5, 20.5))
        path.addLine(to: g.pt(3.5, 17.5))
        path.addQuadCurve(to: g.pt(9, 13.5), control: g.pt(3.5, 13.5))
        path.addQuadCurve(to: g.pt(14.5, 17.5), control: g.pt(14.5, 13.5))
        path.addLine(to: g.pt(14.5, 20.5))
        path.closeSubpath()
        path.addEllipse(in: g.rect(14.8, 5.9, 5.4, 5.4))
        path.move(to: g.pt(14.5, 17.5))
        path.addQuadCurve(to: g.pt(17.5, 13.3), control: g.pt(14.5, 13.3))
        path.addQuadCurve(to: g.pt(20.5, 17.5), control: g.pt(20.5, 13.3))
        path.addLine(to: g.pt(20.5, 20.5))
        path.addLine(to: g.pt(14.5, 20.5))
    }

    /// A cup with two handles on a foot
    private static func drawTrophy(_ path: inout Path, _ g: IconGrid) {
        path.move(to: g.pt(6, 3.5))
        path.addLine(to: g.pt(18, 3.5))
        path.addLine(to: g.pt(18, 9))
        path.addCurve(to: g.pt(12, 15), control1: g.pt(18, 13.5), control2: g.pt(15, 15))
        path.addCurve(to: g.pt(6, 9), control1: g.pt(9, 15), control2: g.pt(6, 13.5))
        path.closeSubpath()
        path.move(to: g.pt(6, 5.5))
        path.addCurve(to: g.pt(6, 10.5), control1: g.pt(1.5, 5.5), control2: g.pt(1.5, 10.5))
        path.move(to: g.pt(18, 5.5))
        path.addCurve(to: g.pt(18, 10.5), control1: g.pt(22.5, 5.5), control2: g.pt(22.5, 10.5))
        path.move(to: g.pt(12, 15))
        path.addLine(to: g.pt(12, 18))
        path.move(to: g.pt(9, 18))
        path.addLine(to: g.pt(15, 18))
        path.addLine(to: g.pt(16.5, 20.5))
        path.addLine(to: g.pt(7.5, 20.5))
        path.closeSubpath()
    }

    /// A box with an arrow leaving through the top
    private static func drawShare(_ path: inout Path, _ g: IconGrid) {
        path.move(to: g.pt(9, 9.5))
        path.addLine(to: g.pt(8, 9.5))
        path.addQuadCurve(to: g.pt(6, 11.5), control: g.pt(6, 9.5))
        path.addLine(to: g.pt(6, 18.5))
        path.addQuadCurve(to: g.pt(8, 20.5), control: g.pt(6, 20.5))
        path.addLine(to: g.pt(16, 20.5))
        path.addQuadCurve(to: g.pt(18, 18.5), control: g.pt(18, 20.5))
        path.addLine(to: g.pt(18, 11.5))
        path.addQuadCurve(to: g.pt(16, 9.5), control: g.pt(18, 9.5))
        path.addLine(to: g.pt(15, 9.5))
        path.move(to: g.pt(12, 15.5))
        path.addLine(to: g.pt(12, 3.5))
        path.move(to: g.pt(8.5, 7))
        path.addLine(to: g.pt(12, 3.5))
        path.addLine(to: g.pt(15.5, 7))
    }

    /// A medal: a disc with a star, hanging from a ribbon that splits in two
    private static func drawMedal(_ path: inout Path, _ g: IconGrid) {
        path.addEllipse(in: g.rect(6.5, 10, 11, 11))
        // The two bands of the ribbon meet at the top of the disc
        path.move(to: g.pt(8.46, 11.29))
        path.addLine(to: g.pt(5, 3))
        path.addLine(to: g.pt(9.5, 3))
        path.addLine(to: g.pt(12, 10))
        path.move(to: g.pt(15.54, 11.29))
        path.addLine(to: g.pt(19, 3))
        path.addLine(to: g.pt(14.5, 3))
        path.addLine(to: g.pt(12, 10))
        // A five-pointed star (outer radius 3, inner 1.25) round the disc's centre
        path.move(to: g.pt(12, 12.5))
        path.addLine(to: g.pt(12.73, 14.49))
        path.addLine(to: g.pt(14.85, 14.57))
        path.addLine(to: g.pt(13.19, 15.89))
        path.addLine(to: g.pt(13.76, 17.93))
        path.addLine(to: g.pt(12, 16.75))
        path.addLine(to: g.pt(10.24, 17.93))
        path.addLine(to: g.pt(10.81, 15.89))
        path.addLine(to: g.pt(9.15, 14.57))
        path.addLine(to: g.pt(11.27, 14.49))
        path.closeSubpath()
    }
}

/// Grid coordinates (24×24) to points at the drawn size
struct IconGrid {
    let scale: CGFloat

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }

    func len(_ value: CGFloat) -> CGFloat {
        value * scale
    }

    func size(_ width: CGFloat, _ height: CGFloat) -> CGSize {
        CGSize(width: width * scale, height: height * scale)
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }
}

/// One outline icon in a colour at a size; the line keeps the weight of the
/// 24-grid design (1.8 at 24, never thinner than 1.2)
struct OutlineIconView: View {
    let icon: OutlineIcon
    let color: Color
    let size: CGFloat

    var body: some View {
        let scale = size / 24
        let line = max(1.2, 1.8 * scale)
        icon.path(scale: scale)
            .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
