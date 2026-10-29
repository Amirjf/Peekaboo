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

switch event {
case "SessionStart":
    if existing != nil { exit(0) }
    record.state = .waiting
case "UserPromptSubmit":
    record.state = .working
    record.message = nil
    record.startedAt = now
    if let prompt = json["prompt"] as? String, let title = TextCleaner.title(from: prompt) {
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
    let message = TextCleaner.clean((json["message"] as? String) ?? "")
    // Only permission prompts and questions mean Claude is blocked on you. Idle reminders
    // ("waiting for your input") and the like arrive after a task is done and must not reopen it.
    let asksUser = type.map { $0 == "permission_prompt" || $0 == "elicitation_dialog" }
        ?? message.localizedCaseInsensitiveContains("permission")
    let running = existing.map { $0.state == .working || $0.state == .needs } ?? true
    guard asksUser, running else { exit(0) }
    if existing?.state == .needs && existing?.message == message { exit(0) }
    record.state = .needs
    record.message = message.isEmpty ? "Claude needs your attention" : message
case "Stop":
    // A repeated Stop must not bump the time, or a done card the user already saw reopens.
    if existing?.state == .done { exit(0) }
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
