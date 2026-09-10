import Foundation

/// Durable local storage for `AlarmSession`s: one JSON file per session.
///
/// Writes use `Data.write(options: .atomic)`, which writes to an auxiliary file and
/// then swaps it into place — a crash or termination mid-write leaves either the
/// old file or the fully-written new one, never a truncated/corrupted one. This is
/// the "app crashes don't corrupt the amount owed" guarantee at the storage layer.
///
/// Deliberately simple (no SQLite/GRDB dependency): session volume is tiny — a
/// handful of events per session, a handful of sessions — so a directory of small
/// JSON files is more than sufficient and keeps this layer easy to reason about and
/// inspect by hand.
///
/// Not yet safe for multiple concurrent writer processes. As of step 3 this isn't
/// needed: the Stop/Snooze `LiveActivityIntent`s (`AlarmSessionIntents.swift`) run
/// as a background launch of this same app target/process (not a separate
/// extension binary — there's no widget extension in this project), so `.shared`
/// below is the one store both the foregrounded app and an intent's `perform()`
/// use. Revisit (App Group + real concurrency handling) if on-device testing shows
/// that assumption is wrong, or if a widget extension is added later.
/// `@unchecked Sendable`: both stored properties are `let` (never mutated after
/// init), so there's no actual shared mutable *memory* state for Swift 6's
/// concurrency checker to worry about — only the underlying *file* is shared,
/// which is a separate, already-documented concern (see the class doc comment
/// above) that Sendable conformance doesn't speak to.
final class AlarmSessionStore: @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func save(_ session: AlarmSession) throws {
        try ensureDirectoryExists()
        let data = try JSONEncoder.earlyBird.encode(session)
        try data.write(to: fileURL(for: session.id), options: .atomic)
    }

    func load(sessionId: UUID) throws -> AlarmSession? {
        let url = fileURL(for: sessionId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.earlyBird.decode(AlarmSession.self, from: data)
    }

    func loadAll() throws -> [AlarmSession] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let files = try fileManager
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try files.map { url in
            let data = try Data(contentsOf: url)
            return try JSONDecoder.earlyBird.decode(AlarmSession.self, from: data)
        }
    }

    func delete(sessionId: UUID) throws {
        let url = fileURL(for: sessionId)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func fileURL(for sessionId: UUID) -> URL {
        directory.appendingPathComponent("\(sessionId.uuidString).json")
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

extension AlarmSessionStore {
    static let shared = AlarmSessionStore(directory: defaultDirectory)

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AlarmSessions", isDirectory: true)
    }
}

extension JSONEncoder {
    static let earlyBird: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let earlyBird: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
