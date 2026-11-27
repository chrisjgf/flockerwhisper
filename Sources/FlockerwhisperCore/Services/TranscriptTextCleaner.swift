import Foundation

public enum TranscriptTextCleaner {
    private static let noisePatterns: [String] = [
        #"\[BLANK_AUDIO\]"#,
        #"\(blank audio\)"#,
        #"\[SILENCE\]"#,
        #"\(silence\)"#,
        #"\[INAUDIBLE\]"#,
        #"\(inaudible\)"#,
        #"\[MUSIC\]"#,
        #"\(music\)"#,
        #"<\|[^|>]+\|>"#
    ]

    public static func clean(_ raw: String) -> String {
        var result = raw
        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
            }
        }

        // Collapse repeated whitespace and trim ends.
        let collapsed = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
