import Foundation
import PeekabooCore

/// Watches ~/.peekaboo/sessions and keeps an up-to-date list of Claude sessions.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []

    /// Called when a known session moves into a new state, with the state it left.
    var onTransition: ((SessionRecord, SessionState) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var loadedOnce = false

    init() {
        try? FileManager.default.createDirectory(at: PeekabooPaths.sessions, withIntermediateDirectories: true)
        reload()
        watch()
        // Backstop for missed file events, and to notice sessions whose terminal was closed.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func watch() {
        let fd = open(PeekabooPaths.sessions.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func reload() {
        let now = Date()
        var fresh: [SessionRecord] = []
        for var r in SessionIO.readAll() {
            // Records written by older hooks may still carry raw markup.
            r.title = r.title.map(TextCleaner.clean).flatMap { $0.isEmpty ? nil : $0 }
            r.message = r.message.map(TextCleaner.clean)
            let stale = now.timeIntervalSince(r.updatedAt) > 24 * 3600
            let gone = r.pid.map { !ProcessTree.isAlive($0) } ?? false
            if stale || gone {
                SessionIO.remove(id: r.id)
            } else {
                fresh.append(r)
            }
        }
        fresh.sort { $0.startedAt < $1.startedAt }

        if loadedOnce {
            let old = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for r in fresh {
                if let previous = old[r.id]?.state, previous != r.state {
                    onTransition?(r, previous)
                }
            }
        }
        loadedOnce = true
        if fresh != records { records = fresh }
    }
}
