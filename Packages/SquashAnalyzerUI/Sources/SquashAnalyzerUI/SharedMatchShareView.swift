import SwiftUI
import SquashAnalyzerCore

/// "Deel score" on Android: pick one of the three WhatsApp layouts (Core's
/// `MatchShareReport`, the same text as iOS' `MatchShareSheet`), see how it
/// reads, then hand it to the share sheet. The layout is remembered with the
/// same key as iOS, one setting for coach and referee.
public struct SharedMatchShareView: View {
    let report: MatchShareReport
    let shareText: (String) -> Void
    let onClose: () -> Void

    @AppStorage("refereeShareStyle") private var storedStyle = MatchShareStyle.compact.rawValue

    public init(report: MatchShareReport, shareText: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.report = report
        self.shareText = shareText
        self.onClose = onClose
    }

    private var style: MatchShareStyle { MatchShareStyle(rawValue: storedStyle) ?? MatchShareStyle.compact }

    public var body: some View {
        ZStack {
            DashboardPalette.background.ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    Text("DEEL SCORE")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(DashboardPalette.text)
                        .frame(maxWidth: .infinity)
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(DashboardPalette.secondary)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sluiten")
                }
                HStack(spacing: 8) {
                    ForEach(MatchShareStyle.allCases) { option in
                        Button { storedStyle = option.rawValue } label: {
                            Text(option.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(option == style ? DashboardPalette.background : DashboardPalette.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(option == style ? DashboardPalette.orange : DashboardPalette.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(style.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(DashboardPalette.muted)
                Button { shareText(report.text(style: style)) } label: {
                    Text("DELEN")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(DashboardPalette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(DashboardPalette.orange))
                }
                .buttonStyle(.plain)
                ScrollView {
                    Text(report.text(style: style))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(DashboardPalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))
                        .padding(.bottom, 48)
                }
            }
            .padding(20)
        }
    }
}
