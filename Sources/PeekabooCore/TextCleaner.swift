import Foundation

/// Turns prompt and notification text into something fit for the notch.
/// Prompts can carry markup that Claude Code or other tools wrap around what the user typed
/// (for example `<system-reminder>` blocks or `<agent-message>` wrappers).
public enum TextCleaner {
    /// Blocks whose contents are machine context rather than something the user wrote.
    static let droppedBlocks = [
        "system-reminder", "local-command-stdout", "local-command-stderr", "local-command-caveat",
    ]

    public static func clean(_ text: String) -> String {
        var s = text
        for name in droppedBlocks {
            s = replace(s, "<\(name)\\b[^>]*>[\\s\\S]*?</\(name)>", with: " ")
        }
        // Keep the words inside any other tag, drop the tag itself.
        s = replace(s, "</?[A-Za-z][\\w:.-]*(\\s[^<>]*)?/?>", with: " ")
        // A tag cut off by earlier truncation, like "<agent-mess".
        s = replace(s, "</?[A-Za-z][\\w:.-]*$", with: "")
        return s
            .split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// First meaningful line of a prompt, shortened for a one-line title.
    public static func title(from prompt: String, limit: Int = 60) -> String? {
        guard let line = clean(prompt).split(separator: "\n").first.map(String.init), !line.isEmpty else { return nil }
        return line.count > limit ? String(line.prefix(limit - 1)) + "…" : line
    }

    private static func replace(_ s: String, _ pattern: String, with template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return s }
        return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
}
