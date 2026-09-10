import Foundation

/// The load-(find-or-create)-mutate-save operation shared by the Stop and Snooze
/// intents. Kept separate from the intents themselves (`AlarmSessionIntents.swift`)
/// so it's usable — and testable — independent of AppIntents/AlarmKit.
///
/// A daily-repeating `AlarmDefinition` is scheduled with AlarmKit exactly once; its
/// id stays the same across every day's firing. So the intents only ever know that
/// stable `AlarmDefinition.id`, not a fresh per-firing session id — there's no
/// AlarmKit callback we've found that runs exactly at fire time, before any button
/// is tapped, where a new id could be minted. Instead: the first Snooze/Dismiss tap
/// after the previous session closed starts a new one. This is what makes each
/// day's firing bill independently instead of one session accumulating forever.
enum AlarmSessionRecorder {
    static func recordSnoozeStarted(
        alarmDefinitionID: String,
        at date: Date = Date(),
        sessionStore: AlarmSessionStore = .shared,
        definitionStore: AlarmDefinitionStore = .shared
    ) {
        mutateCurrentSession(
            alarmDefinitionID: alarmDefinitionID,
            firedAt: date,
            sessionStore: sessionStore,
            definitionStore: definitionStore
        ) { $0.recordSnoozeStarted(at: date) }
    }

    static func recordDismissed(
        alarmDefinitionID: String,
        at date: Date = Date(),
        sessionStore: AlarmSessionStore = .shared,
        definitionStore: AlarmDefinitionStore = .shared
    ) {
        mutateCurrentSession(
            alarmDefinitionID: alarmDefinitionID,
            firedAt: date,
            sessionStore: sessionStore,
            definitionStore: definitionStore
        ) { $0.recordDismissed(at: date) }
    }

    /// Stores default to `.shared` for real call sites (the intents); tests inject
    /// temp-directory-backed stores instead so they don't touch the app's real
    /// Application Support directory or depend on test execution order.
    ///
    /// Failures here (a malformed id, a missing definition, a disk error) are
    /// swallowed rather than surfaced — there's no user-facing way to report an
    /// error from inside a system-invoked intent callback, and `AlarmSession`'s own
    /// mutating methods are already no-ops against invalid transitions (see its
    /// doc comment). Silently failing to record an event can only ever
    /// under-charge, never over-charge, which is the safe direction to fail in.
    private static func mutateCurrentSession(
        alarmDefinitionID: String,
        firedAt: Date,
        sessionStore: AlarmSessionStore,
        definitionStore: AlarmDefinitionStore,
        change: (inout AlarmSession) -> Void
    ) {
        guard let definitionID = UUID(uuidString: alarmDefinitionID) else { return }

        var session: AlarmSession

        if let openSession = (try? sessionStore.loadAll())?.first(where: {
            $0.alarmDefinitionId == definitionID && !$0.isDismissed
        }) {
            session = openSession
        } else {
            guard let definition = try? definitionStore.load(id: definitionID) else { return }
            session = AlarmSession(
                alarmDefinitionId: definitionID,
                firedAt: firedAt,
                ratePerSecond: definition.ratePerSecond,
                maxChargeAmount: definition.maxChargeAmount
            )
        }

        change(&session)
        try? sessionStore.save(session)
    }
}
