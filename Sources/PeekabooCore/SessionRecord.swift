import Foundation

/// What a Claude Code session is doing right now.
public enum SessionState: String, Codable {
    case waiting   // open, sitting at the prompt
    case working   // running a task
    case needs     // blocked on the user (permission prompt, question)
    case done      // finished its task
}

/// One Claude Code session, written by `peekaboo-hook` and read by the app.
public struct SessionRecord: Codable, Identifiable, Equatable {
    public var id: String
    public var state: SessionState
    public var cwd: String?
    public var title: String?
    public var message: String?
    public var pid: Int32?
    public var tty: String?
    public var bundleId: String?
    public var termProgram: String?
    public var startedAt: Date
    public var updatedAt: Date

    public init(id: String, state: SessionState, now: Date = Date()) {
        self.id = id
        self.state = state
        self.startedAt = now
        self.updatedAt = now
    }

    public var project: String {
        guard let cwd, !cwd.isEmpty else { return "Claude" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}

public enum PeekabooPaths {
    public static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".peekaboo", isDirectory: true)
    }

    public static var sessions: URL {
        root.appendingPathComponent("sessions", isDirectory: true)
    }

    public static func file(for id: String) -> URL {
        let safe = String(id.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
        return sessions.appendingPathComponent(safe + ".json")
    }
}

public enum SessionIO {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }

    public static func read(_ url: URL) -> SessionRecord? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder().decode(SessionRecord.self, from: data)
    }

    public static func write(_ record: SessionRecord, to url: URL) throws {
        let data = try encoder().encode(record)
        try data.write(to: url, options: .atomic)
    }

    public static func readAll() -> [SessionRecord] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: PeekabooPaths.sessions, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }.compactMap(read)
    }

    public static func remove(id: String) {
        try? FileManager.default.removeItem(at: PeekabooPaths.file(for: id))
    }
}
