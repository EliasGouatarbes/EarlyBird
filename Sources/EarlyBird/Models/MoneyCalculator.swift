import Foundation

/// Pure functions turning an `AlarmSession`'s event log into a duration and an
/// amount owed. No I/O, no stored state — the same logic is meant to run unmodified
/// on-device (for the instant receipt) and on the backend (for the actual Stripe
/// capture), so the two can never disagree about what's owed.
enum MoneyCalculator {
    /// Sums every snoozeStarted→dismissed interval in the log. `autoReAlerted`
    /// events (the AlarmKit safety-net re-ring while the user is mid-snooze) don't
    /// end an interval — the user is still snoozing, just being reminded. If the
    /// log ends with an open snooze (no closing `dismissed` yet), that interval is
    /// measured up to `now`, which is what drives a live ticking counter.
    ///
    /// Malformed/duplicate input is handled defensively rather than asserted
    /// against, since events can arrive from more than one process: a second
    /// `snoozeStarted` while one is already open is ignored (the earlier start
    /// wins), and anything after a `dismissed` is ignored.
    static func elapsedSnoozeSeconds(events: [AlarmSessionEvent], asOf now: Date) -> TimeInterval {
        var total: TimeInterval = 0
        var openSnoozeStart: Date?
        var isDismissed = false

        for event in events.sorted(by: { $0.at < $1.at }) {
            guard !isDismissed else { break }

            switch event.kind {
            case .fired:
                continue
            case .snoozeStarted:
                if openSnoozeStart == nil {
                    openSnoozeStart = event.at
                }
            case .autoReAlerted:
                continue
            case .dismissed:
                if let start = openSnoozeStart {
                    total += max(0, event.at.timeIntervalSince(start))
                    openSnoozeStart = nil
                }
                isDismissed = true
            }
        }

        if !isDismissed, let start = openSnoozeStart {
            total += max(0, now.timeIntervalSince(start))
        }

        return total
    }

    /// `elapsedSnoozeSeconds × ratePerSecond`, clamped to `maxChargeAmount` and
    /// rounded to the currency's minor unit (2 decimal places) — rounding happens
    /// only at this final step so intermediate math stays exact.
    static func amountOwed(
        events: [AlarmSessionEvent],
        ratePerSecond: Decimal,
        maxChargeAmount: Decimal,
        asOf now: Date = Date()
    ) -> Decimal {
        let seconds = elapsedSnoozeSeconds(events: events, asOf: now)
        let rawAmount = Decimal(seconds) * ratePerSecond
        let capped = min(rawAmount, maxChargeAmount)
        return capped.roundedToCurrency()
    }
}

extension Decimal {
    /// Rounds to 2 decimal places. EarlyBird only targets currencies with a
    /// 2-digit minor unit (EUR, USD, ...) for now; a currency-aware minor-unit
    /// lookup can replace this if that changes.
    func roundedToCurrency() -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }
}
