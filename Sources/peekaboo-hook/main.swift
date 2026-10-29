import Foundation
import PeekabooCore

// Claude Code runs this on session events and pipes the event JSON to stdin.
// It records the session's state in ~/.peekaboo/sessions/<id>.json and exits fast.
// It never prints anything and always exits 0, so it can't get in Claude's way.

let input = FileHandle.standardInput.readDataToEndOfFile()
let json = ((try? JSONSerialization.jsonObject(with: input)) as? [String: Any]) ?? [:]
let event = (json["hook_event_name"] as? String) ?? CommandLine.arguments.dropFirst().first ?? ""

guard let sessionId = json["session_id"] as? String, !sessionId.isEmpty else { exit(0) }

let fm = FileManager.default
try? fm.createDirectory(at: PeekabooPaths.sessions, withIntermediateDirectories: true)
let url = PeekabooPaths.file(for: sessionId)
let now = Date()
let existing = SessionIO.read(url)
var record = existing ?? SessionRecord(id: sessionId, state: .waiting, now: now)

func summarize(_ prompt: String) -> String? {
    let line = prompt
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .first { !$0.isEmpty }
    guard let line else { return nil }
    let collapsed = line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return collapsed.count > 60 ? String(collapsed.prefix(59)) + "…" : collapsed
}

switch event {
case "SessionStart":
    if existing != nil { exit(0) }
    record.state = .waiting
case "UserPromptSubmit":
    record.state = .working
    record.message = nil
    record.startedAt = now
    if let prompt = json["prompt"] as? String, let title = summarize(prompt) {
        record.title = title
    }
case "PreToolUse", "PostToolUse":
    // Fires on every tool call, so only write when it actually changes something
    // (for example right after the user answered a permission prompt).
    if existing?.state == .working { exit(0) }
    record.state = .working
    record.message = nil
case "Notification":
    let type = json["notification_type"] as? String
    let message = (json["message"] as? String) ?? "Claude needs your attention"
    if type == "idle_prompt" || message.localizedCaseInsensitiveContains("waiting for your input") {
        exit(0)
    }
    record.state = .needs
    record.message = message
case "Stop":
    record.state = .done
    record.message = nil
case "SessionEnd":
    try? fm.removeItem(at: url)
    exit(0)
default:
    exit(0)
}

if let cwd = json["cwd"] as? String { record.cwd = cwd }
if record.pid == nil || event == "SessionStart" || event == "UserPromptSubmit" {
    let ancestor = ProcessTree.claudeAncestor()
    record.pid = ancestor.pid
    if let tty = ancestor.tty { record.tty = tty }
}
let env = ProcessInfo.processInfo.environment
if let bundle = env["__CFBundleIdentifier"], !bundle.isEmpty { record.bundleId = bundle }
if let term = env["TERM_PROGRAM"], !term.isEmpty { record.termProgram = term }
record.updatedAt = now

try? SessionIO.write(record, to: url)
exit(0)
