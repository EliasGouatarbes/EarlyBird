import AlarmKit

/// AlarmKit requires a metadata type for every alarm's `AlarmAttributes`, even
/// when there's nothing extra to attach. We don't need custom Live Activity data
/// here — the ticking-meter UI lives entirely in our own app screen once the user
/// taps in, not in AlarmKit's own Live Activity presentation.
struct EarlyBirdAlarmMetadata: AlarmMetadata {
    init() {}
}
