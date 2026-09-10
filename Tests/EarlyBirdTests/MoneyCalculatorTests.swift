import XCTest
@testable import EarlyBird

final class MoneyCalculatorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let rate = Decimal(string: "0.10")!

    private func event(_ kind: AlarmSessionEventKind, _ offsetSeconds: TimeInterval) -> AlarmSessionEvent {
        AlarmSessionEvent(kind: kind, at: t0.addingTimeInterval(offsetSeconds))
    }

    // MARK: - elapsedSnoozeSeconds

    func testNoEventsHaveZeroElapsedTime() {
        XCTAssertEqual(MoneyCalculator.elapsedSnoozeSeconds(events: [], asOf: t0), 0)
    }

    func testImmediateDismissWithoutSnoozingHasZeroElapsedTime() {
        let events = [event(.fired, 0), event(.dismissed, 5)]
        XCTAssertEqual(MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(5)), 0)
    }

    func testSingleSnoozeIntervalIsMeasuredExactly() {
        let events = [event(.fired, 0), event(.snoozeStarted, 0), event(.dismissed, 30)]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(30)),
            30,
            accuracy: 0.001
        )
    }

    func testAutoReAlertDoesNotEndOrResetTheSnoozeInterval() {
        let events = [
            event(.fired, 0),
            event(.snoozeStarted, 0),
            event(.autoReAlerted, 10),
            event(.autoReAlerted, 20),
            event(.dismissed, 30),
        ]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(30)),
            30,
            accuracy: 0.001
        )
    }

    func testASecondSnoozeDismissPairAfterTheFirstDismissIsIgnored() {
        // AlarmSession.recordDismissed is terminal (a no-op once already dismissed),
        // so a real session's log can never contain a second snoozeStarted/dismissed
        // pair — but MoneyCalculator is fed a raw array, so it must not be fooled by
        // one anyway. Only the first (snoozeStarted, dismissed) pair should count.
        let events = [
            event(.fired, 0),
            event(.snoozeStarted, 0), event(.dismissed, 10), // counted: 10s
            event(.snoozeStarted, 20), event(.dismissed, 25), // ignored: after dismissal
        ]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(25)),
            10,
            accuracy: 0.001
        )
    }

    func testDuplicateSnoozeStartedKeepsTheEarlierStart() {
        let events = [
            event(.fired, 0),
            event(.snoozeStarted, 0),
            event(.snoozeStarted, 5), // stray duplicate, e.g. a retried intent callback
            event(.dismissed, 30),
        ]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(30)),
            30,
            accuracy: 0.001
        )
    }

    func testEventsOutOfArrayOrderAreSortedByTimestampBeforeComputing() {
        let events = [event(.dismissed, 30), event(.snoozeStarted, 0), event(.fired, 0)]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(30)),
            30,
            accuracy: 0.001
        )
    }

    func testEventsAfterDismissedAreIgnored() {
        let events = [
            event(.fired, 0),
            event(.snoozeStarted, 0),
            event(.dismissed, 10),
            event(.snoozeStarted, 20), // stray/late event arriving after dismissal
        ]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(60)),
            10,
            accuracy: 0.001
        )
    }

    func testOpenSnoozeIsMeasuredUpToNowForLiveCounter() {
        let events = [event(.fired, 0), event(.snoozeStarted, 0)]
        XCTAssertEqual(
            MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: t0.addingTimeInterval(7)),
            7,
            accuracy: 0.001
        )
    }

    // MARK: - amountOwed

    func testSpecExampleThirtySecondsAtTenCentsIsThreeEuros() {
        let events = [event(.fired, 0), event(.snoozeStarted, 0), event(.dismissed, 30)]
        let amount = MoneyCalculator.amountOwed(
            events: events,
            ratePerSecond: rate,
            maxChargeAmount: Decimal(100),
            asOf: t0.addingTimeInterval(30)
        )
        XCTAssertEqual(amount, Decimal(string: "3.00")!)
    }

    func testSpecExampleReceiptFourMinutesTwelveSecondsIsTwentyFiveTwenty() {
        // From CLAUDE.md's example receipt: 04:12 snoozed at EUR0.10/sec => EUR25.20.
        let events = [event(.fired, 0), event(.snoozeStarted, 0), event(.dismissed, 252)]
        let amount = MoneyCalculator.amountOwed(
            events: events,
            ratePerSecond: rate,
            maxChargeAmount: Decimal(100),
            asOf: t0.addingTimeInterval(252)
        )
        XCTAssertEqual(amount, Decimal(string: "25.20")!)
    }

    func testAmountIsClampedAtMaxChargeAndStopsIncreasing() {
        let events = [event(.fired, 0), event(.snoozeStarted, 0), event(.dismissed, 300)]
        let max = Decimal(string: "20.00")!
        let amount = MoneyCalculator.amountOwed(
            events: events,
            ratePerSecond: rate,
            maxChargeAmount: max,
            asOf: t0.addingTimeInterval(300)
        )
        XCTAssertEqual(amount, max)
    }

    func testAmountOwedForOpenSessionGrowsWithNow() {
        let events = [event(.fired, 0), event(.snoozeStarted, 0)]
        let early = MoneyCalculator.amountOwed(
            events: events, ratePerSecond: rate, maxChargeAmount: Decimal(100), asOf: t0.addingTimeInterval(5)
        )
        let later = MoneyCalculator.amountOwed(
            events: events, ratePerSecond: rate, maxChargeAmount: Decimal(100), asOf: t0.addingTimeInterval(10)
        )
        XCTAssertEqual(early, Decimal(string: "0.50")!)
        XCTAssertEqual(later, Decimal(string: "1.00")!)
        XCTAssertLessThan(early, later)
    }

    func testAmountOwedRoundsToTwoDecimalPlaces() {
        // 3 seconds at EUR0.005/sec = EUR0.015 raw, rounds to EUR0.02.
        let events = [event(.fired, 0), event(.snoozeStarted, 0), event(.dismissed, 3)]
        let amount = MoneyCalculator.amountOwed(
            events: events,
            ratePerSecond: Decimal(string: "0.005")!,
            maxChargeAmount: Decimal(100),
            asOf: t0.addingTimeInterval(3)
        )
        XCTAssertEqual(amount, Decimal(string: "0.02")!)
    }
}
