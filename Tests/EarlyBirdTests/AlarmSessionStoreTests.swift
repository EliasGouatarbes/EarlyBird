import XCTest
@testable import EarlyBird

final class AlarmSessionStoreTests: XCTestCase {
    private var directory: URL!
    private var store: AlarmSessionStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EarlyBirdTests-\(UUID().uuidString)")
        store = AlarmSessionStore(directory: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    private func makeSession() -> AlarmSession {
        var session = AlarmSession(
            alarmDefinitionId: UUID(),
            firedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ratePerSecond: Decimal(string: "0.10")!,
            maxChargeAmount: Decimal(string: "20.00")!
        )
        session.recordSnoozeStarted(at: Date(timeIntervalSince1970: 1_700_000_000))
        session.recordDismissed(at: Date(timeIntervalSince1970: 1_700_000_030))
        return session
    }

    func testSavingCreatesTheDirectoryIfNeeded() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        try store.save(makeSession())
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    func testSaveThenLoadRoundTrips() throws {
        let session = makeSession()
        try store.save(session)

        let loaded = try store.load(sessionId: session.id)

        XCTAssertEqual(loaded, session)
        XCTAssertEqual(loaded?.amountOwed(), Decimal(string: "3.00")!)
    }

    func testLoadingUnknownSessionReturnsNil() throws {
        let loaded = try store.load(sessionId: UUID())
        XCTAssertNil(loaded)
    }

    func testSavingTwiceOverwritesRatherThanDuplicates() throws {
        var session = makeSession()
        try store.save(session)

        session.recordAutoReAlerted(at: Date(timeIntervalSince1970: 1_700_000_040))
        try store.save(session)

        let loaded = try store.load(sessionId: session.id)
        XCTAssertEqual(loaded?.events.count, session.events.count)

        let all = try store.loadAll()
        XCTAssertEqual(all.count, 1)
    }

    func testLoadAllReturnsEverySavedSession() throws {
        let sessions = [makeSession(), makeSession(), makeSession()]
        for session in sessions {
            try store.save(session)
        }

        let loaded = try store.loadAll()

        XCTAssertEqual(Set(loaded.map(\.id)), Set(sessions.map(\.id)))
    }

    func testDeleteRemovesTheSession() throws {
        let session = makeSession()
        try store.save(session)

        try store.delete(sessionId: session.id)

        XCTAssertNil(try store.load(sessionId: session.id))
        XCTAssertEqual(try store.loadAll().count, 0)
    }

    func testDeletingUnknownSessionDoesNotThrow() throws {
        XCTAssertNoThrow(try store.delete(sessionId: UUID()))
    }
}
