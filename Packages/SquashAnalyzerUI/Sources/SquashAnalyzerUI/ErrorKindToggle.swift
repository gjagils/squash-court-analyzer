import SwiftUI
import SquashAnalyzerCore

/// DOWN · OUT · SERVICE · GROND: how an unforced error went wrong, picked
/// before tapping "Unforced error" (iOS and Android). Looks like the
/// "Uit de lucht" switch (`VolleyToggle`): at most one is on, tapping it again
/// turns it off, nothing picked is saved as "not recorded". Service is greyed
/// out when the player who made the error was not serving.
public struct ErrorKindToggle: View {
    @Binding var selection: ErrorKind?
    let available: [ErrorKind]
    let color: Color

    public init(selection: Binding<ErrorKind?>, available: [ErrorKind], color: Color) {
        _selection = selection
        self.available = available
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(ErrorKind.allCases) { kind in
                chip(kind)
            }
        }
    }

    private func chip(_ kind: ErrorKind) -> some View {
        let isOn = selection == kind
        let isAvailable = available.contains(kind)
        let tint = isAvailable ? color : color.opacity(0.3)
        return Button {
            guard isAvailable else { return }
            selection = isOn ? nil : kind
        } label: {
            // Four equal chips side by side: icon above the word so they fit a small phone
            VStack(spacing: 3) {
                AppSymbol(kind.icon, size: 13, color: isOn ? Color.black.opacity(0.8) : tint)
                Text(kind.title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(isOn ? Color.black.opacity(0.8) : tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            // .background(colour) + clipShape, not a filled shape: on Android dark
            // text on a filled shape came out dark on dark (docs/android-port.md)
            .background(isOn ? color : color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.description + (isOn ? ", aan" : ", uit"))
    }
}
