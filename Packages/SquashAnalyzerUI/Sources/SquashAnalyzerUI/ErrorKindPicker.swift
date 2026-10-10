import SwiftUI
import SquashAnalyzerCore

/// After "Unforced error": what kind of error it was, the same way the shots
/// follow a winner (iOS and Android). Four tiles, Down · Out · Service ·
/// Grond, and "Weet niet" for an error of unknown kind. Service is greyed out
/// when the player who made the error was not serving.
public struct ErrorKindPicker: View {
    let available: [ErrorKind]
    let color: Color
    let onSelect: (ErrorKind?) -> Void

    public init(available: [ErrorKind], color: Color, onSelect: @escaping (ErrorKind?) -> Void) {
        self.available = available
        self.color = color
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Two plain rows, not a nested ForEach (Skip, docs/android-port.md)
            HStack(spacing: 12) {
                tile(ErrorKind.down)
                tile(ErrorKind.outOfCourt)
            }
            HStack(spacing: 12) {
                tile(ErrorKind.service)
                tile(ErrorKind.viaFloor)
            }
            Button { onSelect(nil) } label: {
                Text("Weet niet")
                    .font(SharedFonts.system(13, weight: .medium, design: .rounded))
                    .foregroundColor(color)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Soort fout onbekend")
        }
    }

    private func tile(_ kind: ErrorKind) -> some View {
        let isAvailable = available.contains(kind)
        let tint = isAvailable ? color : color.opacity(0.3)
        return Button {
            guard isAvailable else { return }
            onSelect(kind)
        } label: {
            VStack(spacing: 6) {
                AppSymbol(kind.icon, size: 24, color: tint)
                    .frame(height: 30.0)
                Text(kind.title.uppercased())
                    .font(SharedFonts.system(13, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(isAvailable ? SharedColors.ink.opacity(0.9) : SharedColors.ink.opacity(0.3))
                Text(kind.description)
                    .font(SharedFonts.system(10, weight: .medium, design: .rounded))
                    .foregroundColor(isAvailable ? SharedColors.ink.opacity(0.55) : SharedColors.ink.opacity(0.2))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    // Room for two lines on every tile, so all four are the same height
                    .frame(height: 28.0, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            // .background(colour) + clipShape, not a filled shape (Android, docs/android-port.md)
            .background(color.opacity(isAvailable ? 0.08 : 0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(kind.description + (isAvailable ? "" : ", niet mogelijk"))
    }
}
