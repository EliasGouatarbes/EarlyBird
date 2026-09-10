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
/// Not yet safe for multiple concurrent writer processes; revisit once the AlarmKit
/// intent extension (step 3) becomes a second writer to the same App Group
/// container.
final class AlarmSessionStore {
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
