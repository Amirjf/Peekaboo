import AppKit
import Combine
import PeekabooCore
import SwiftUI

/// Size of the hardware notch (or a stand-in on screens without one).
struct NotchGeometry: Equatable {
    var hasNotch: Bool
    var width: CGFloat
    var height: CGFloat

    init(screen: NSScreen) {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            hasNotch = true
            height = top
            width = screen.frame.width - left.width - right.width
        } else {
            hasNotch = false
            height = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            width = 190
        }
    }

    init(hasNotch: Bool, width: CGFloat, height: CGFloat) {
        self.hasNotch = hasNotch
        self.width = width
        self.height = height
    }
}

enum Presentation: Equatable {
    case hidden          // no notch on this screen and nothing to say
    case closed          // looks exactly like the hardware notch
    case wings           // small live activity either side of the camera
    case card(String)    // one session, expanded
    case list            // several sessions, expanded

    var isExpanded: Bool {
        switch self {
        case .card, .list: true
        default: false
        }
    }
}

@MainActor
final class NotchModel: ObservableObject {
    static let welcomeId = "peekaboo.welcome"

    let store: SessionStore
    let settings: Settings
    @Published var geometry = NotchGeometry(hasNotch: true, width: 185, height: 32)
    @Published private(set) var hovering = false
    @Published private(set) var now = Date()
    @Published private var acknowledged: [String: Date] = [:]
    @Published private var extras: [SessionRecord] = []

    private var bag = Set<AnyCancellable>()
    private var clock: Timer?
    private var demoTimers: [Timer] = []

    /// How long a fresh "done" stays open before tucking into the wings.
    let doneOpenFor: TimeInterval = 6
    /// "Needs you" stays open this long, then re-peeks briefly every minute.
    let needsOpenFor: TimeInterval = 15

    init(store: SessionStore, settings: Settings) {
        self.store = store
        self.settings = settings
        store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        store.onTransition = { [weak self] record, previous in self?.handleTransition(record, from: previous) }
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
    }

    var buddy: Buddy { settings.buddy }
    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    var sessions: [SessionRecord] {
        let ids = Set(extras.map(\.id))
        return store.records.filter { !ids.contains($0.id) } + extras
    }

    // MARK: State rules

    func isAcknowledged(_ r: SessionRecord) -> Bool {
        acknowledged[r.id] == r.updatedAt
    }

    /// Sessions that should show up in the notch at all.
    var active: [SessionRecord] {
        sessions.filter { r in
            switch r.state {
            case .working: true
            case .needs, .done: !isAcknowledged(r)
            case .waiting: false
            }
        }
    }

    func wantsToBeOpen(_ r: SessionRecord) -> Bool {
        guard !isAcknowledged(r) else { return false }
        let age = now.timeIntervalSince(r.updatedAt)
        switch r.state {
        case .done: return age < doneOpenFor
        case .needs: return age < needsOpenFor || age.truncatingRemainder(dividingBy: 60) < 4
        default: return false
        }
    }

    /// Everything, sorted the way the list shows it: needs you, done, working, then idle.
    var sorted: [SessionRecord] {
        func rank(_ r: SessionRecord) -> Int {
            switch r.state {
            case .needs: isAcknowledged(r) ? 3 : 0
            case .done: isAcknowledged(r) ? 3 : 1
            case .working: 2
            case .waiting: 3
            }
        }
        return sessions.sorted { rank($0) != rank($1) ? rank($0) < rank($1) : $0.updatedAt > $1.updatedAt }
    }

    var presentation: Presentation {
        let all = sessions
        if hovering && !all.isEmpty {
            return all.count == 1 ? .card(all[0].id) : .list
        }
        let open = active.filter(wantsToBeOpen)
        if open.count == 1 { return .card(open[0].id) }
        if open.count > 1 { return .list }
        if !active.isEmpty { return .wings }
        return geometry.hasNotch ? .closed : .hidden
    }

    func record(_ id: String) -> SessionRecord? {
        sessions.first { $0.id == id }
    }

    func mood(for r: SessionRecord) -> Mood {
        switch r.state {
        case .working: .working
        case .needs: isAcknowledged(r) ? .idle : .alert
        case .done: isAcknowledged(r) ? .idle : .happy
        case .waiting: .idle
        }
    }

    // MARK: Layout

    var wingWidth: CGFloat { geometry.height + 14 }
    var flare: CGFloat { presentation.isExpanded ? 14 : 6 }

    /// Size of the notch body (without the flared top corners).
    func bodySize(_ p: Presentation) -> CGSize {
        let g = geometry
        switch p {
        case .hidden, .closed:
            return CGSize(width: g.width, height: g.height)
        case .wings:
            return CGSize(width: g.width + wingWidth * 2, height: g.height)
        case .card(let id):
            let needs = record(id)?.state == .needs && !(record(id).map(isAcknowledged) ?? true)
            return CGSize(width: max(g.width + 190, 380), height: g.height + (needs ? 104 : 80))
        case .list:
            let rows = min(sorted.count, 5)
            return CGSize(width: max(g.width + 210, 400), height: g.height + 34 + CGFloat(rows) * 50 + 10)
        }
    }

    /// The area that reacts to the mouse, in the panel's coordinate space (top-centered).
    var hitSize: CGSize {
        let p = presentation
        let s = bodySize(p)
        return CGSize(width: s.width + flare * 2, height: s.height)
    }

    // MARK: Hover and clicks

    private var hoverTarget = false
    private var hoverChangedAt = Date.distantPast

    /// Called ~30× a second with whether the mouse is over the notch. Adds small delays so
    /// passing the cursor across the top of the screen doesn't make the notch flicker open.
    func updateMouse(inside: Bool) {
        if inside != hoverTarget {
            hoverTarget = inside
            hoverChangedAt = Date()
        }
        let delay: TimeInterval = hoverTarget ? 0.12 : 0.35
        if hoverTarget != hovering, Date().timeIntervalSince(hoverChangedAt) >= delay {
            if hoverTarget && sessions.isEmpty { return }
            hovering = hoverTarget
        }
    }

    func open(_ r: SessionRecord) {
        acknowledge(r)
        hovering = false
        hoverTarget = false
        guard !r.id.hasPrefix("peekaboo.") else { return }
        Jumper.jump(to: r)
    }

    func acknowledge(_ r: SessionRecord) {
        if r.state == .done || r.state == .needs {
            acknowledged[r.id] = r.updatedAt
        }
    }

    // MARK: Sounds

    private var lastSound: [String: Date] = [:]

    /// Plays a sound only when a task really finishes or really gets blocked, and never twice
    /// in a row for the same session within a short window.
    private func handleTransition(_ r: SessionRecord, from previous: SessionState) {
        guard settings.soundsOn else { return }
        let name: String
        switch (previous, r.state) {
        case (.working, .done), (.needs, .done): name = buddy.doneSound
        case (.working, .needs): name = buddy.needsSound
        default: return
        }
        let key = "\(r.id)|\(r.state.rawValue)"
        if let last = lastSound[key], Date().timeIntervalSince(last) < 20 { return }
        lastSound[key] = Date()
        NSSound(named: NSSound.Name(name))?.play()
    }

    // MARK: Welcome and demo

    func welcome() {
        extras.removeAll { $0.id == Self.welcomeId }
        var r = SessionRecord(id: Self.welcomeId, state: .done)
        r.title = "I'll peek out when Claude finishes or needs you"
        extras.append(r)
        after(5) { [weak self] in self?.extras.removeAll { $0.id == Self.welcomeId } }
    }

    func playDemo() {
        demoTimers.forEach { $0.invalidate() }
        demoTimers = []
        let base = Date()
        func make(_ id: String, _ title: String, _ cwd: String, _ app: String) -> SessionRecord {
            var r = SessionRecord(id: "peekaboo.demo.\(id)", state: .working, now: base)
            r.title = title
            r.cwd = cwd
            r.bundleId = app
            return r
        }
        extras = [
            make("a", "fix flaky tests", "/Users/you/code/peekaboo", "com.apple.Terminal"),
            make("b", "migrate orders table", "/Users/you/code/shop-api", "com.googlecode.iterm2"),
            make("c", "refactor auth flow", "/Users/you/code/web", "com.microsoft.VSCode"),
        ]
        demoTimers.append(after(2.5) { [weak self] in self?.updateExtra("a") { $0.state = .done } })
        demoTimers.append(after(9) { [weak self] in
            self?.updateExtra("b") {
                $0.state = .needs
                $0.message = "Claude needs your permission to use Bash"
            }
        })
        demoTimers.append(after(12) { [weak self] in self?.updateExtra("c") { $0.state = .done } })
        demoTimers.append(after(30) { [weak self] in self?.extras.removeAll { $0.id.hasPrefix("peekaboo.demo.") } })
    }

    private func updateExtra(_ id: String, _ change: (inout SessionRecord) -> Void) {
        guard let i = extras.firstIndex(where: { $0.id == "peekaboo.demo.\(id)" }) else { return }
        let previous = extras[i].state
        change(&extras[i])
        extras[i].updatedAt = Date()
        handleTransition(extras[i], from: previous)
    }

    @discardableResult
    private func after(_ seconds: TimeInterval, _ block: @escaping @MainActor () -> Void) -> Timer {
        Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated { block() }
        }
    }
}
