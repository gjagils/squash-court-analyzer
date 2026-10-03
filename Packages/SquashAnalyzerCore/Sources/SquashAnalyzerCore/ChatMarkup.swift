import Foundation

/// One stretch of a chat line with its WhatsApp styling
public struct ChatSegment: Identifiable, Equatable {
    public let id: Int
    public let text: String
    public let bold: Bool
    public let italic: Bool

    public init(id: Int, text: String, bold: Bool, italic: Bool) {
        self.id = id
        self.text = text
        self.bold = bold
        self.italic = italic
    }
}

/// One line of the preview, or a ``` monospace block
public struct ChatBlock: Identifiable, Equatable {
    public let id: Int
    public let segments: [ChatSegment]
    public let mono: String?

    public init(id: Int, segments: [ChatSegment], mono: String?) {
        self.id = id
        self.segments = segments
        self.mono = mono
    }
}

/// WhatsApp markup split into styled pieces for the share preview
/// (`WhatsAppPreview`): *bold*, _italic_ and ``` monospace``` blocks.
public enum ChatMarkup {
    public static func blocks(_ text: String) -> [ChatBlock] {
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
    public static func segments(_ line: String) -> [ChatSegment] {
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
