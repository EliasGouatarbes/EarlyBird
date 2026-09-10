import Foundation

/// The kind of thing that happened during a firing of an alarm. Append-only: a
/// session's history is the full list of these, in the order they were recorded.
enum AlarmSessionEventKind: String, Codable {
    case fired
    case snoozeStarted
    case autoReAlerted
    case dismissed
}

struct AlarmSessionEvent: Codable, Equatable {
    let kind: AlarmSessionEventKind
    let at: Date
}

/// Derived, display-only status — never the source of truth for billing. The event
/// log is; this is just a convenient projection of it.
enum AlarmSessionState: String, Codable {
    case firing
    case snoozing
    case dismissed
}

/// One firing of an `AlarmDefinition`. Owns the append-only event log that is the
/// sole source of truth for how much is owed — `amountOwed` is always recomputed
/// from `events`, never tracked as separate mutable state, so there is nothing to
/// get out of sync and nothing a crash mid-session can corrupt beyond the last
/// successfully persisted event.
///
/// Mutations are deliberately idempotent/no-ops against invalid transitions (e.g.
/// snoozing an already-dismissed session) rather than trapping — once the AlarmKit
/// intent extension exists (step 3), events can arrive from two different processes,
/// and a stray duplicate or late-arriving event must never crash the app.
struct AlarmSession: Codable, Identifiable, Equatable {
    let id: UUID
    let alarmDefinitionId: UUID
    let ratePerSecond: Decimal
    let maxChargeAmount: Decimal
    private(set) var events: [AlarmSessionEvent]
    var paymentIntentId: String?
    var captureStatus: String?

    init(
        id: UUID = UUID(),
        alarmDefinitionId: UUID,
        firedAt: Date,
        ratePerSecond: Decimal,
        maxChargeAmount: Decimal
    ) {
        self.id = id
        self.alarmDefinitionId = alarmDefinitionId
        self.ratePerSecond = ratePerSecond
        self.maxChargeAmount = maxChargeAmount
        self.events = [AlarmSessionEvent(kind: .fired, at: firedAt)]
        self.paymentIntentId = nil
        self.captureStatus = nil
    }

    var firedAt: Date {
        events.first(where: { $0.kind == .fired })?.at ?? events.first?.at ?? .distantPast
    }

    var isDismissed: Bool {
        events.contains { $0.kind == .dismissed }
    }

    var state: AlarmSessionState {
        if isDismissed { return .dismissed }
        if events.contains(where: { $0.kind == .snoozeStarted }) { return .snoozing }
        return .firing
    }

    mutating func recordSnoozeStarted(at date: Date = Date()) {
        guard !isDismissed else { return }
        events.append(AlarmSessionEvent(kind: .snoozeStarted, at: date))
    }

    mutating func recordAutoReAlerted(at date: Date = Date()) {
        guard !isDismissed else { return }
        events.append(AlarmSessionEvent(kind: .autoReAlerted, at: date))
    }

    mutating func recordDismissed(at date: Date = Date()) {
        guard !isDismissed else { return }
        events.append(AlarmSessionEvent(kind: .dismissed, at: date))
    }

    /// Seconds actually spent snoozing so far. For an open (not yet dismissed)
    /// session this measures up to `now` — what drives the live ticking-meter UI.
    func elapsedSnoozeSeconds(asOf now: Date = Date()) -> TimeInterval {
        MoneyCalculator.elapsedSnoozeSeconds(events: events, asOf: now)
    }

    /// The authoritative amount owed for this session so far, clamped to
    /// `maxChargeAmount`. Identical logic runs on-device (instant receipt) and on
    /// the backend (actual capture) — see `MoneyCalculator`.
    func amountOwed(asOf now: Date = Date()) -> Decimal {
        MoneyCalculator.amountOwed(
            events: events,
            ratePerSecond: ratePerSecond,
            maxChargeAmount: maxChargeAmount,
            asOf: now
        )
    }
}
