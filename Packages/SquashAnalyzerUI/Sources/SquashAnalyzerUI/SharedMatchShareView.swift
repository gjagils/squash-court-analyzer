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
            VStack(spacing: 18) {
                header
                styleTabs
                Text(style.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DashboardPalette.muted)
                // The preview reads like the chat: *bold*, _italic_ and ``` blocks, as on iOS
                ScrollView {
                    WhatsAppPreview(text: report.text(style: style))
                        .padding(16)
                        .background(Color.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
                }
                Button { shareText(report.text(style: style)) } label: {
                    Text("DELEN")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(DashboardPalette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DashboardPalette.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
        }
    }

    /// "✕ Sluiten" left, the title centred, as on iOS
    private var header: some View {
        ZStack {
            Text("DEEL SCORE")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(DashboardPalette.text)
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        AppSymbol("xmark", size: 14, color: DashboardPalette.secondary)
                        Text("Sluiten")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(DashboardPalette.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sluiten")
                Spacer()
            }
        }
    }

    private var styleTabs: some View {
        HStack(spacing: 8) {
            ForEach(MatchShareStyle.allCases) { option in
                let active = option == style
                Button { storedStyle = option.rawValue } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(active ? DashboardPalette.background : DashboardPalette.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(active ? DashboardPalette.gold : DashboardPalette.gold.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DashboardPalette.gold.opacity(active ? 0.0 : 0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One stretch of a chat line with its WhatsApp styling
struct ChatSegment: Identifiable, Equatable {
    let id: Int
    let text: String
    let bold: Bool
    let italic: Bool
}

/// One line of the preview, or a ``` monospace block
struct ChatBlock: Identifiable {
    let id: Int
    let segments: [ChatSegment]
    let mono: String?
}

/// WhatsApp markup the way the chat shows it: *bold*, _italic_ and ```
/// monospace``` blocks, like iOS' preview. Without Markdown support on
/// Android, each line is split into styled pieces.
struct WhatsAppPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Self.blocks(text)) { block in
                if let mono = block.mono {
                    Text(mono)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(DashboardPalette.text)
                        .padding(.vertical, 2)
                } else {
                    line(block.segments)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ segments: [ChatSegment]) -> some View {
        HStack(spacing: 0) {
            ForEach(segments) { segment in
                Text(segment.text)
                    .font(.system(size: 15, weight: segment.bold ? .bold : .regular))
                    .italic(segment.italic)
                    .foregroundColor(DashboardPalette.text)
            }
        }
    }

    static func blocks(_ text: String) -> [ChatBlock] {
        var result: [ChatBlock] = []
        var mono: [String]? = nil
        for line in text.components(separatedBy: "\n") {
            if line == "```" {
                if let lines = mono {
                    result.append(ChatBlock(id: result.count, segments: [], mono: lines.joined(separator: "\n")))
                    mono = nil
                } else {
                    mono = []
                }
            } else if mono != nil {
                mono?.append(line)
            } else {
                result.append(ChatBlock(id: result.count, segments: segments(line), mono: nil))
            }
        }
        if let lines = mono {
            result.append(ChatBlock(id: result.count, segments: [], mono: lines.joined(separator: "\n")))
        }
        return result
    }

    /// Pieces between paired * are bold, between paired _ italic
    static func segments(_ line: String) -> [ChatSegment] {
        if line.isEmpty { return [ChatSegment(id: 0, text: " ", bold: false, italic: false)] }
        var result: [ChatSegment] = []
        let boldParts = line.components(separatedBy: "*")
        let boldPaired = boldParts.count >= 3 && boldParts.count % 2 == 1
        for (boldIndex, boldPart) in boldParts.enumerated() {
            let bold = boldPaired && boldIndex % 2 == 1
            let piece = boldPaired ? boldPart : (boldIndex == 0 ? boldPart : "*" + boldPart)
            let italicParts = piece.components(separatedBy: "_")
            let italicPaired = italicParts.count >= 3 && italicParts.count % 2 == 1
            for (italicIndex, italicPart) in italicParts.enumerated() {
                let italic = italicPaired && italicIndex % 2 == 1
                let text = italicPaired ? italicPart : (italicIndex == 0 ? italicPart : "_" + italicPart)
                if !text.isEmpty {
                    result.append(ChatSegment(id: result.count, text: text, bold: bold, italic: italic))
                }
            }
        }
        return result
    }
}
