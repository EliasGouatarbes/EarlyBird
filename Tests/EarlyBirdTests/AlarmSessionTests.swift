import XCTest
@testable import EarlyBird

final class AlarmSessionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let rate = Decimal(string: "0.10")!
    private let max = Decimal(string: "20.00")!

    private func makeSession() -> AlarmSession {
        AlarmSession(alarmDefinitionId: UUID(), firedAt: t0, ratePerSecond: rate, maxChargeAmount: max)
    }

    func testNewSessionStartsInFiringStateWithZeroOwed() {
        let session = makeSession()
        XCTAssertEqual(session.state, .firing)
        XCTAssertFalse(session.isDismissed)
        XCTAssertEqual(session.amountOwed(asOf: t0), Decimal(0))
    }

    func testRecordingSnoozeMovesStateToSnoozing() {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0.addingTimeInterval(2))
        XCTAssertEqual(session.state, .snoozing)
    }

    func testRecordingDismissMovesStateToDismissedAndComputesAmount() {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0.addingTimeInterval(0))
        session.recordDismissed(at: t0.addingTimeInterval(30))

        XCTAssertEqual(session.state, .dismissed)
        XCTAssertTrue(session.isDismissed)
        XCTAssertEqual(session.amountOwed(), Decimal(string: "3.00")!)
    }

    func testDismissingWithoutEverSnoozingOwesNothing() {
        var session = makeSession()
        session.recordDismissed(at: t0.addingTimeInterval(60))
        XCTAssertEqual(session.amountOwed(), Decimal(0))
    }

    func testDoubleDismissIsIdempotentAndDoesNotChangeAmountOwed() {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0)
        session.recordDismissed(at: t0.addingTimeInterval(10))
        let amountAfterFirstDismiss = session.amountOwed()

        // Simulates a race: e.g. the user double-taps Dismiss, or a retried intent
        // callback replays the same action.
        session.recordDismissed(at: t0.addingTimeInterval(999))

        XCTAssertEqual(session.events.filter { $0.kind == .dismissed }.count, 1)
        XCTAssertEqual(session.amountOwed(), amountAfterFirstDismiss)
    }

    func testSnoozingAfterDismissalIsIgnored() {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0)
        session.recordDismissed(at: t0.addingTimeInterval(5))
        let amountAfterDismiss = session.amountOwed()

        session.recordSnoozeStarted(at: t0.addingTimeInterval(10))

        XCTAssertTrue(session.isDismissed)
        XCTAssertEqual(session.amountOwed(), amountAfterDismiss)
    }

    func testAutoReAlertWhileSnoozingDoesNotEndTheSession() {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0)
        session.recordAutoReAlerted(at: t0.addingTimeInterval(60))
        XCTAssertEqual(session.state, .snoozing)
        XCTAssertFalse(session.isDismissed)
    }

    func testAmountOwedIsClampedAtSessionMaxCharge() {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0)
        session.recordDismissed(at: t0.addingTimeInterval(600)) // 600s * EUR0.10 = EUR60, capped to EUR20
        XCTAssertEqual(session.amountOwed(), max)
    }

    func testSessionRoundTripsThroughCodable() throws {
        var session = makeSession()
        session.recordSnoozeStarted(at: t0.addingTimeInterval(1))
        session.recordDismissed(at: t0.addingTimeInterval(31))

        let data = try JSONEncoder.earlyBird.encode(session)
        let decoded = try JSONDecoder.earlyBird.decode(AlarmSession.self, from: data)

        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.amountOwed(), session.amountOwed())
    }
}
