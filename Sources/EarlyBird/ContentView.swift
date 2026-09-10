import SwiftUI

/// Step 3 debug harness: schedules a real AlarmKit alarm so it can be exercised
/// on-device (Lock Screen, Focus/Silent, force-quit, reboot — see the step 3
/// checklist in CLAUDE.md). No consent screen, no payment method, no billing yet —
/// this view is replaced by the real alarm-creation flow in step 5.
struct ContentView: View {
    @State private var wakeTime = Date()
    @State private var scheduledDefinition: AlarmDefinition?
    @State private var statusMessage: String?
    @State private var isBusy = false

    private let ratePerSecond = Decimal(string: "0.10")!
    private let maxChargeAmount = Decimal(string: "20.00")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Debug harness for step 3 (AlarmKit integration). Schedules a real, repeating alarm at the time below so it can be tested on a physical device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Test alarm") {
                    DatePicker("Fires at", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    Text("Rate \(ratePerSecond as NSDecimalNumber)/sec, max \(maxChargeAmount as NSDecimalNumber) (not yet billed — no payment method connected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(scheduledDefinition == nil ? "Schedule" : "Re-schedule") {
                        Task { await scheduleTestAlarm() }
                    }
                    .disabled(isBusy)

                    if let scheduledDefinition {
                        Button("Cancel test alarm", role: .destructive) {
                            Task { await cancelTestAlarm(scheduledDefinition) }
                        }
                        .disabled(isBusy)
                    }
                }

                if let statusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("EarlyBird")
        }
    }

    @MainActor
    private func scheduleTestAlarm() async {
        isBusy = true
        defer { isBusy = false }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: wakeTime)
        let minute = calendar.component(.minute, from: wakeTime)

        do {
            let definition = try AlarmDefinition(
                id: scheduledDefinition?.id ?? UUID(),
                time: .init(hour: hour, minute: minute),
                ratePerSecond: ratePerSecond,
                maxChargeAmount: maxChargeAmount,
                currencyCode: "EUR",
                isRealMoneyModeEnabled: false
            )
            try await AlarmKitScheduler.shared.scheduleWakeAlarm(for: definition)
            scheduledDefinition = definition
            statusMessage = "Scheduled daily at \(String(format: "%02d:%02d", hour, minute))."
        } catch {
            statusMessage = "Failed to schedule: \(error)"
        }
    }

    @MainActor
    private func cancelTestAlarm(_ definition: AlarmDefinition) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await AlarmKitScheduler.shared.cancelAlarm(id: definition.id)
            scheduledDefinition = nil
            statusMessage = "Cancelled."
        } catch {
            statusMessage = "Failed to cancel: \(error)"
        }
    }
}

#Preview {
    ContentView()
}
