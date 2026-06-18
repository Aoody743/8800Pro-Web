import Foundation

enum ImportParser {
    static func parse(_ source: String) -> [ImportedChannelDraft] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var drafts: [ImportedChannelDraft] = []
        var pendingTitle: String?

        for line in lines {
            if containsFrequency(line) {
                if let draft = parseLine(line, titleHint: pendingTitle) {
                    drafts.append(draft)
                }
                pendingTitle = nil
            } else {
                pendingTitle = line
            }
        }

        if drafts.isEmpty, let draft = parseLine(normalized.replacingOccurrences(of: "\n", with: " "), titleHint: nil) {
            drafts.append(draft)
        }

        return drafts
    }

    private static func parseLine(_ line: String, titleHint: String?) -> ImportedChannelDraft? {
        guard let rx = firstFrequency(in: line) else { return nil }

        let title = buildTitle(line: line, titleHint: titleHint, rx: rx)
        let offset = extractOffset(from: line)
        let tx = txFrequency(from: rx, offset: offset)
        let tone = extractTone(from: line) ?? "OFF"
        let notes = buildNotes(line: line, offset: offset, tone: tone)

        return ImportedChannelDraft(
            title: title,
            sourceText: line,
            rxFreq: rx,
            txFreq: tx,
            tone: tone,
            notes: notes
        )
    }

    private static func containsFrequency(_ line: String) -> Bool {
        firstFrequency(in: line) != nil
    }

    private static func firstFrequency(in line: String) -> String? {
        let pattern = #"\b(1\d{2}|[234]\d{2}|5[0-1]\d)\.\d{3,5}\b"#
        return line.firstMatch(for: pattern)
    }

    private static func extractTone(from line: String) -> String? {
        let patterns = [
            #"(?:亚音|T(?:SQ)?|CTCSS)\s*[:：]?\s*([0-9]{2,3}(?:\.[0-9])?)"#,
            #"([0-9]{2,3}(?:\.[0-9])?)\s*hz"#
        ]

        for pattern in patterns {
            if let value = line.firstCapture(for: pattern) {
                return value
            }
        }
        return nil
    }

    private static func extractOffset(from line: String) -> Double? {
        if let capture = line.firstCapture(for: #"下差\s*([+-]?\d+(?:\.\d+)?)"#), let value = Double(capture) {
            return -abs(value)
        }
        if let capture = line.firstCapture(for: #"上差\s*([+-]?\d+(?:\.\d+)?)"#), let value = Double(capture) {
            return abs(value)
        }
        if let capture = line.firstCapture(for: #"(?:偏移|差值|offset)\s*[:：]?\s*([+-]?\d+(?:\.\d+)?)"#), let value = Double(capture) {
            return value
        }
        if let capture = line.firstCapture(for: #"\b([+-]\d+(?:\.\d+)?)\b"#), let value = Double(capture) {
            return value
        }
        return nil
    }

    private static func txFrequency(from rx: String, offset: Double?) -> String {
        guard let offset, let rxValue = Double(rx) else { return rx }
        return String(format: "%.5f", rxValue + offset)
    }

    private static func buildTitle(line: String, titleHint: String?, rx: String) -> String {
        if let titleHint, !titleHint.isEmpty {
            return cleanedTitle(titleHint)
        }

        let stripped = line.replacingOccurrences(of: rx, with: " ")
        let title = stripped
            .replacingOccurrences(of: "亚音", with: " ")
            .replacingOccurrences(of: "下差", with: " ")
            .replacingOccurrences(of: "上差", with: " ")
            .replacingOccurrences(of: "HT搜索", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty {
            return "导入信道"
        }

        return cleanedTitle(title)
    }

    private static func cleanedTitle(_ value: String) -> String {
        String(
            value
            .replacingOccurrences(of: "：", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .prefix(16)
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func buildNotes(line: String, offset: Double?, tone: String) -> String {
        var parts: [String] = []
        if let offset {
            parts.append(String(format: "频差 %.1f", offset))
        }
        if tone != "OFF" {
            parts.append("亚音 \(tone)")
        }
        let uppercased = line.uppercased()
        if uppercased.contains("C4FM") {
            parts.append("包含 C4FM 标记")
        } else if uppercased.contains("FM") {
            parts.append("包含 FM 标记")
        }
        return parts.joined(separator: " · ")
    }
}

private extension String {
    func firstMatch(for pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let result = Range(match.range(at: 0), in: self)
        else {
            return nil
        }
        return String(self[result])
    }

    func firstCapture(for pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              match.numberOfRanges > 1,
              let result = Range(match.range(at: 1), in: self)
        else {
            return nil
        }
        return String(self[result])
    }
}
