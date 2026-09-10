import Foundation

/// Durable local storage for `AlarmDefinition`s — same one-JSON-file-per-item,
/// atomic-write pattern as `AlarmSessionStore` (see that file for why atomic
/// writes and per-item files, rather than SQLite/GRDB, are enough here).
///
/// Needed starting in step 3: the Stop/Snooze intents (`AlarmSessionIntents.swift`)
/// run with only an `AlarmDefinition.id` in hand and need to look up its rate/max
/// to start a session — see `AlarmSessionRecorder`.
/// `@unchecked Sendable`: see `AlarmSessionStore`'s identical annotation — both
/// stored properties are `let`, so there's no shared mutable memory state here.
final class AlarmDefinitionStore: @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func save(_ definition: AlarmDefinition) throws {
        try ensureDirectoryExists()
        let data = try JSONEncoder.earlyBird.encode(definition)
        try data.write(to: fileURL(for: definition.id), options: .atomic)
    }

    func load(id: UUID) throws -> AlarmDefinition? {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.earlyBird.decode(AlarmDefinition.self, from: data)
    }

    func loadAll() throws -> [AlarmDefinition] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let files = try fileManager
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        return try files.map { url in
            let data = try Data(contentsOf: url)
            return try JSONDecoder.earlyBird.decode(AlarmDefinition.self, from: data)
        }
    }

    func delete(id: UUID) throws {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectoryExists() throws {
        guard !fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

extension AlarmDefinitionStore {
    static let shared = AlarmDefinitionStore(directory: defaultDirectory)

    private static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AlarmDefinitions", isDirectory: true)
    }
}
