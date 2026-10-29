import Foundation

/// Adds Peekaboo's hook to Claude Code's user settings (~/.claude/settings.json).
/// Safe to run on every launch: it replaces its own entries and leaves everything else alone.
enum HookInstaller {
    static let events = ["SessionStart", "UserPromptSubmit", "PostToolUse", "Notification", "Stop", "SessionEnd"]
    static let marker = "peekaboo-hook"

    enum InstallError: LocalizedError {
        case notInAppBundle
        case unreadableSettings

        var errorDescription: String? {
            switch self {
            case .notInAppBundle: "Run Peekaboo from Peekaboo.app to install the Claude Code hooks."
            case .unreadableSettings: "~/.claude/settings.json isn't valid JSON, so Peekaboo left it alone."
            }
        }
    }

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static var hookBinary: URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/peekaboo-hook")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    /// Returns true when the settings file was changed.
    @discardableResult
    static func install() throws -> Bool {
        guard let bin = hookBinary else { throw InstallError.notInAppBundle }
        let fm = FileManager.default
        let url = settingsURL

        var root: [String: Any] = [:]
        var original = Data()
        if fm.fileExists(atPath: url.path) {
            original = try Data(contentsOf: url)
            if !original.isEmpty {
                guard let obj = try? JSONSerialization.jsonObject(with: original) as? [String: Any] else {
                    throw InstallError.unreadableSettings
                }
                root = obj
            }
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in Array(hooks.keys) {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            let kept: [[String: Any]] = groups.compactMap { group in
                var g = group
                var list = g["hooks"] as? [[String: Any]] ?? []
                list.removeAll { ($0["command"] as? String)?.contains(marker) == true }
                if list.isEmpty { return nil }
                g["hooks"] = list
                return g
            }
            hooks[event] = kept.isEmpty ? nil : kept
        }

        let command = "\"\(bin.path)\""
        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            var group: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 5]]]
            if event == "PostToolUse" { group["matcher"] = "*" }
            groups.append(group)
            hooks[event] = groups
        }
        root["hooks"] = hooks

        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let updated = try JSONSerialization.data(withJSONObject: root, options: options)
        if let old = try? JSONSerialization.jsonObject(with: original),
           let oldNormalized = try? JSONSerialization.data(withJSONObject: old, options: options),
           oldNormalized == updated {
            return false
        }

        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.peekaboo-backup")
        if !original.isEmpty && !fm.fileExists(atPath: backup.path) {
            try original.write(to: backup)
        }
        try updated.write(to: url, options: .atomic)
        return true
    }
}
