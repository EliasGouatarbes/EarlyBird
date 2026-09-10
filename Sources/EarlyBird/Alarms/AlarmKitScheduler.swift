import AlarmKit
import SwiftUI

/// Thin wrapper around the live `AlarmManager` system API.
///
/// Deliberately small and free of business logic: this file is unverified until it
/// runs against a real Xcode/AlarmKit toolchain (this project is authored without
/// access to one — see CLAUDE.md STATUS), so anything worth unit testing
/// (`AlarmSessionRecorder`, the `MoneyCalculator`/`AlarmSession` model) is kept out
/// of it entirely. Expect this file specifically to need API-surface corrections
/// once CI actually compiles it.
///
/// No widget extension exists in this project (yet). AlarmKit's countdown/paused
/// presentation — which does require one — isn't used here: the alarm is scheduled
/// with no `countdownDuration` and a `.custom` secondary-button behavior, so it
/// should never enter AlarmKit's own countdown/paused state. That assumption needs
/// on-device confirmation (see the step 3 checklist in CLAUDE.md); if it's wrong,
/// a widget extension + App Group gets added at that point.
@MainActor
final class AlarmKitScheduler {
    enum SchedulingError: Error {
        case authorizationDenied
    }

    static let shared = AlarmKitScheduler()

    private init() {}

    /// Must succeed before scheduling. CLAUDE.md requires the alarm to still
    /// function even when payment infrastructure is unreachable, but it cannot
    /// function at all without this OS-level permission.
    func requestAuthorizationIfNeeded() async throws {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return
        case .notDetermined:
            let state = try await AlarmManager.shared.requestAuthorization()
            guard state == .authorized else { throw SchedulingError.authorizationDenied }
        case .denied:
            throw SchedulingError.authorizationDenied
        @unknown default:
            throw SchedulingError.authorizationDenied
        }
    }

    /// Schedules (or re-schedules) the alarm. Uses `definition.id` as the AlarmKit
    /// alarm id and bakes it into the Stop/Snooze intents as the alarm definition
    /// id they operate on — see `AlarmSessionRecorder` for why that id, not a
    /// per-firing session id, is what the intents actually receive.
    func scheduleWakeAlarm(for definition: AlarmDefinition) async throws {
        try await requestAuthorizationIfNeeded()
        try AlarmDefinitionStore.shared.save(definition)

        let schedule = Alarm.Schedule.relative(
            Alarm.Schedule.Relative(
                time: .init(hour: definition.time.hour, minute: definition.time.minute),
                repeats: .weekly([.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
            )
        )

        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .white,
            systemImageName: "xmark.circle.fill"
        )
        let snoozeButton = AlarmButton(
            text: "Snooze (it'll cost you)",
            textColor: .white,
            systemImageName: "moon.zzz.fill"
        )

        let alertPresentation = AlarmPresentation.Alert(
            title: "EarlyBird",
            stopButton: stopButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .custom
        )

        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alertPresentation),
            metadata: EarlyBirdAlarmMetadata(),
            tintColor: .orange
        )

        let alarmDefinitionID = definition.id.uuidString
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes,
            stopIntent: EarlyBirdDismissIntent(alarmDefinitionID: alarmDefinitionID),
            secondaryIntent: EarlyBirdSnoozeIntent(alarmDefinitionID: alarmDefinitionID),
            sound: .default
        )

        _ = try await AlarmManager.shared.schedule(id: definition.id, configuration: configuration)
    }

    /// Cancels the alarm entirely — used when the user deletes/turns off an alarm,
    /// not when a session ends normally (a daily-repeating alarm should keep firing
    /// tomorrow; only Stop/Snooze, handled by the intents, end one day's session).
    func cancelAlarm(id: UUID) async throws {
        try await AlarmManager.shared.stop(id: id)
        try? AlarmDefinitionStore.shared.delete(id: id)
    }
}
