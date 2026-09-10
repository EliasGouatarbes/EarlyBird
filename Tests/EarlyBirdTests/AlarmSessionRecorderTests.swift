import XCTest
@testable import EarlyBird

final class AlarmSessionRecorderTests: XCTestCase {
    private var sessionDirectory: URL!
    private var definitionDirectory: URL!
    private var sessionStore: AlarmSessionStore!
    private var definitionStore: AlarmDefinitionStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EarlyBirdTests-\(UUID().uuidString)")
        sessionDirectory = root.appendingPathComponent("Sessions")
        definitionDirectory = root.appendingPathComponent("Definitions")
        sessionStore = AlarmSessionStore(directory: sessionDirectory)
        definitionStore = AlarmDefinitionStore(directory: definitionDirectory)
    }

    override func tearDownWithError() throws {
        let root = sessionDirectory.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try super.tearDownWithError()
    }

    private func makeDefinition() throws -> AlarmDefinition {
        try AlarmDefinition(
            time: .init(hour: 7, minute: 0),
            ratePerSecond: Decimal(string: "0.10")!,
            maxChargeAmount: Decimal(string: "20.00")!,
            currencyCode: "EUR"
        )
    }

    func testSnoozeWithNoOpenSessionStartsANewOne() throws {
        let definition = try makeDefinition()
        try definitionStore.save(definition)

        AlarmSessionRecorder.recordSnoozeStarted(
            alarmDefinitionID: definition.id.uuidString,
            at: Date(timeIntervalSince1970: 1_700_000_000),
            sessionStore: sessionStore,
            definitionStore: definitionStore
        )

        let sessions = try sessionStore.loadAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.alarmDefinitionId, definition.id)
        XCTAssertEqual(sessions.first?.state, .snoozing)
    }

    func testSnoozeWithUnknownDefinitionIsANoOp() {
        // No definition was ever saved for this id — nothing to attach a session to.
        AlarmSessionRecorder.recordSnoozeStarted(
            alarmDefinitionID: UUID().uuidString,
            sessionStore: sessionStore,
            definitionStore: definitionStore
        )

        XCTAssertEqual(try sessionStore.loadAll().count, 0)
    }

    func testMalformedIdentifierIsANoOp() {
        AlarmSessionRecorder.recordSnoozeStarted(
            alarmDefinitionID: "not-a-uuid",
            sessionStore: sessionStore,
            definitionStore: definitionStore
        )

        XCTAssertEqual(try sessionStore.loadAll().count, 0)
    }

    func testDismissWithNoOpenSessionStartsAndImmediatelyClosesAZeroChargeSession() throws {
        // Tapping Stop straight away (never snoozed) should still be representable
        // and owe nothing, not be silently dropped.
        let definition = try makeDefinition()
        try definitionStore.save(definition)

        AlarmSessionRecorder.recordDismissed(
            alarmDefinitionID: definition.id.uuidString,
            sessionStore: sessionStore,
            definitionStore: definitionStore
        )

        let sessions = try sessionStore.loadAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertTrue(sessions.first?.isDismissed ?? false)
        XCTAssertEqual(sessions.first?.amountOwed(), Decimal(0))
    }

    func testSnoozeThenDismissContinueTheSameOpenSession() throws {
        let definition = try makeDefinition()
        try definitionStore.save(definition)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        AlarmSessionRecorder.recordSnoozeStarted(
            alarmDefinitionID: definition.id.uuidString,
            at: t0,
            sessionStore: sessionStore,
            definitionStore: definitionStore
        )
        AlarmSessionRecorder.recordDismissed(
            alarmDefinitionID: definition.id.uuidString,
            at: t0.addingTimeInterval(30),
            sessionStore: sessionStore,
            definitionStore: definitionStore
        )

        let sessions = try sessionStore.loadAll()
        XCTAssertEqual(sessions.count, 1, "should continue the one open session, not create a second")
        XCTAssertEqual(sessions.first?.amountOwed(), Decimal(string: "3.00")!)
    }

    func testASecondFiringAfterTheFirstIsDismissedStartsAFreshIndependentSession() throws {
        // Simulates the same daily alarm firing on two different days: yesterday's
        // session is closed, so today's snooze must start a brand new one rather
        // than reopening or accumulating onto the old, already-dismissed session.
        let definition = try makeDefinition()
        try definitionStore.save(definition)
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400)

        AlarmSessionRecorder.recordSnoozeStarted(
            alarmDefinitionID: definition.id.uuidString, at: day1,
            sessionStore: sessionStore, definitionStore: definitionStore
        )
        AlarmSessionRecorder.recordDismissed(
            alarmDefinitionID: definition.id.uuidString, at: day1.addingTimeInterval(10),
            sessionStore: sessionStore, definitionStore: definitionStore
        )

        AlarmSessionRecorder.recordSnoozeStarted(
            alarmDefinitionID: definition.id.uuidString, at: day2,
            sessionStore: sessionStore, definitionStore: definitionStore
        )
        AlarmSessionRecorder.recordDismissed(
            alarmDefinitionID: definition.id.uuidString, at: day2.addingTimeInterval(5),
            sessionStore: sessionStore, definitionStore: definitionStore
        )

        let sessions = try sessionStore.loadAll()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(Set(sessions.map { $0.amountOwed() }), [Decimal(string: "1.00")!, Decimal(string: "0.50")!])
    }
}
