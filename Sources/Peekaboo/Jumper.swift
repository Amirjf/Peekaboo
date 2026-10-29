import AppKit
import PeekabooCore

/// Brings the window and tab that runs a Claude session to the front.
enum Jumper {
    static let editors: Set<String> = [
        "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf", "dev.zed.Zed", "com.vscodium",
    ]

    static func bundleId(for r: SessionRecord) -> String? {
        if let b = r.bundleId { return b }
        switch r.termProgram {
        case "Apple_Terminal": return "com.apple.Terminal"
        case "iTerm.app": return "com.googlecode.iterm2"
        case "vscode": return "com.microsoft.VSCode"
        case "WarpTerminal": return "dev.warp.Warp-Stable"
        case "ghostty": return "com.mitchellh.ghostty"
        default: return nil
        }
    }

    static func appName(for r: SessionRecord) -> String? {
        guard let id = bundleId(for: r) else { return nil }
        switch id {
        case "com.apple.Terminal": return "Terminal"
        case "com.googlecode.iterm2": return "iTerm"
        case "com.microsoft.VSCode": return "VS Code"
        case "com.todesktop.230313mzl4w4u92": return "Cursor"
        case "dev.warp.Warp-Stable": return "Warp"
        case "com.mitchellh.ghostty": return "Ghostty"
        default:
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
    }

    static func jump(to r: SessionRecord) {
        let id = bundleId(for: r)
        if let tty = r.tty, let script = tabScript(bundleId: id, tty: tty) {
            DispatchQueue.global(qos: .userInitiated).async {
                let ok = runAppleScript(script)
                if !ok { DispatchQueue.main.async { activate(id, cwd: r.cwd) } }
            }
            return
        }
        activate(id, cwd: r.cwd)
    }

    private static func activate(_ id: String?, cwd: String?) {
        guard let id else { return }
        if editors.contains(id), let cwd, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            // Opening the folder focuses the editor window that already has it open.
            NSWorkspace.shared.open([URL(fileURLWithPath: cwd)], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
            app.activate()
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func tabScript(bundleId: String?, tty: String) -> String? {
        let safeTTY = tty.filter { $0.isLetter || $0.isNumber || $0 == "/" }
        switch bundleId {
        case "com.apple.Terminal":
            return """
            tell application "Terminal"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(safeTTY)" then
                            set selected of t to true
                            set index of w to 1
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """
        case "com.googlecode.iterm2":
            return """
            tell application "iTerm2"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(safeTTY)" then
                                select w
                                tell t to select
                                tell s to select
                                return
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
            """
        default:
            return nil
        }
    }

    private static func runAppleScript(_ source: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }
}
