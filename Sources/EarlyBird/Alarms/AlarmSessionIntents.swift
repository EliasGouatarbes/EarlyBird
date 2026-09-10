import AppIntents
import AlarmKit

/// Runs when the user taps the alarm's secondary ("Snooze") button. Wired as
/// `secondaryIntent` in `AlarmKitScheduler`, paired with
/// `secondaryButtonBehavior: .custom` — that combination is what makes AlarmKit
/// call this instead of running its own fixed-length `postAlert` snooze cycle
/// (see CLAUDE.md STATUS on why that native cycle doesn't fit "bill the exact
/// second the user dismisses").
///
/// `openAppWhenRun = true` because the whole point of the Hybrid model is that our
/// own in-app ticking-meter screen takes over from here.
struct EarlyBirdSnoozeIntent: LiveActivityIntent {
    // `let`, not `var`: under Swift 6 strict concurrency, a `static var` is
    // flagged as unsynchronized global mutable state. These are never actually
    // mutated, and the AppIntents protocol requirements are get-only, so `let`
    // satisfies them while also being Sendable-safe.
    static let title: LocalizedStringResource = "Snooze"
    static let description = IntentDescription("Starts a billed snooze session.")
    static let openAppWhenRun = true

    @Parameter(title: "Alarm Definition ID")
    var alarmDefinitionID: String

    init(alarmDefinitionID: String) {
        self.alarmDefinitionID = alarmDefinitionID
    }

    init() {
        self.alarmDefinitionID = ""
    }

    func perform() async throws -> some IntentResult {
        AlarmSessionRecorder.recordSnoozeStarted(alarmDefinitionID: alarmDefinitionID)
        return .result()
    }
}

/// Runs when the user taps Stop. Wired as `stopIntent` in `AlarmKitScheduler` —
/// that parameter is what lets us capture an exact dismiss timestamp, rather than
/// only finding out later (from `AlarmManager.shared.alarms`) that the alarm went
/// away sometime in between. Also opens the app so the receipt — the whole point
/// of the product — is something the user actually sees, and so the app gets a
/// reliable foreground moment to kick off the backend capture call (step 6/8).
struct EarlyBirdDismissIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Dismiss"
    static let description = IntentDescription("Ends the alarm session and shows the receipt.")
    static let openAppWhenRun = true

    @Parameter(title: "Alarm Definition ID")
    var alarmDefinitionID: String

    init(alarmDefinitionID: String) {
        self.alarmDefinitionID = alarmDefinitionID
    }

    init() {
        self.alarmDefinitionID = ""
    }

    func perform() async throws -> some IntentResult {
        AlarmSessionRecorder.recordDismissed(alarmDefinitionID: alarmDefinitionID)
        return .result()
    }
}
