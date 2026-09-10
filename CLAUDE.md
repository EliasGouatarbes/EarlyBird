I want to build an iOS app called "EarlyBird."

CONCEPT:

EarlyBird is a deliberately ridiculous alarm-clock app.

The user creates an alarm in our app and connects a real payment method. When the alarm goes off, snoozing costs the user real money.

Example:

Alarm: 7:00 AM
Penalty: €0.10/second

User snoozes for 30 seconds:
€3.00 charge

User eventually dismisses the alarm:

"Congratulations. You bought 30 seconds of sleep for €3.00."

The app is intentionally absurd and humorous. The financial penalty is the core product, not a future feature.

REAL MONEY IS REQUIRED FROM THE BEGINNING.

Do NOT design this as a fake-money MVP and postpone payments. The initial product needs to be architected around real financial transactions from day one.

However, we should use safe limits, explicit user consent, clear pricing, and appropriate safeguards. We must not make accidental or ambiguous charges.

CORE PRODUCT:

1. User creates an alarm.
2. User chooses a penalty rate.
3. User connects/configures a real payment method.
4. The alarm fires.
5. User can dismiss the alarm or snooze it.
6. Every second of snoozing increases the amount owed.
7. When the relevant alarm session ends, the app charges the user's configured payment method for the accumulated amount.
8. The app displays a ridiculous receipt showing exactly how much the user paid for additional sleep.

Example receipt:

SNOOZE RECEIPT

Alarm: 07:00
Snooze time: 04:12
Rate: €0.10/sec

TOTAL:
€25.20

Reason:
You couldn't get out of bed.

IMPORTANT:

The app should NOT silently charge users or create unclear financial obligations.

Before a user enables real-money mode, the UI must clearly explain:

* how the charging mechanism works
* the penalty rate
* the maximum possible charge
* when the charge occurs
* how to disable the feature
* what happens if payment fails
* what happens if the user changes/cancels an alarm

There should be a hard user-configurable maximum charge per alarm/session.

For example:

Maximum penalty: €20

Once the maximum is reached, the app must stop increasing the amount owed.

TECHNICAL DIRECTION:

* Native iOS app
* Swift
* SwiftUI
* AlarmKit where appropriate
* Real payment processing from the beginning
* No unnecessary backend functionality
* Local persistence where appropriate
* Backend/payment infrastructure where genuinely required
* Unit tests for important timing, financial, and state-management logic

PAYMENTS:

Do NOT assume that Apple In-App Purchase / StoreKit is automatically the correct solution.

Investigate the appropriate legal and technical payment architecture for this specific use case.

The transaction is NOT the purchase of digital content or a subscription. It is a real-world financial penalty resulting from the user's use of an alarm.

Investigate whether the appropriate architecture is:

* Apple-supported payment APIs
* Stripe
* another payment processor
* a combination of Apple and external payment infrastructure
* preauthorization / authorization holds
* payment-method storage + later capture
* another architecture

Do not guess.

Before implementing payments, determine:

1. Apple's current App Store rules relevant to this business model.
2. Whether external payment processing is permitted for this use case.
3. Whether we can legally/technically save a payment method for later charging.
4. Whether preauthorization is possible and appropriate.
5. How refunds/disputes/failed payments should work.
6. What user-consent requirements apply.
7. What data must be stored securely.
8. What must NEVER be stored by our app.
9. Whether we need a backend/server for payment operations.
10. What geographic/payment-method limitations exist.

If the original payment architecture is not allowed, explain the closest viable architecture rather than quietly replacing real payments with fake money.

SECURITY:

Treat the financial component as production-grade from the beginning.

Never store raw card numbers, CVVs, or other sensitive payment credentials ourselves unless there is an extremely compelling and explicitly supported reason.

Use the payment provider's secure mechanisms/tokenization.

The app must be designed so that:

* duplicate charges are prevented
* retries cannot accidentally create duplicate charges
* app crashes don't corrupt the amount owed
* alarm state survives app termination/relaunch where technically possible
* the user cannot accidentally incur an unlimited charge
* the final amount is auditable
* payment operations are idempotent
* server-side financial calculations are authoritative where appropriate

ALARM EXPERIENCE:

The app should feel like a legitimate alarm clock rather than a normal app notification that happens to play a sound.

Investigate Apple's native alarm functionality, particularly AlarmKit where appropriate.

Do NOT assume that the app can simply keep a background timer running.

Before implementing the alarm system, investigate what happens when:

* the phone is locked
* the app is backgrounded
* the app is force-quit
* the app is terminated
* the phone restarts
* Focus mode is enabled
* Silent Mode is enabled
* the alarm fires
* the user snoozes
* the user dismisses the alarm
* network connectivity disappears
* payment services are unavailable

Most importantly:

Determine exactly what system/API events we can reliably observe when the user interacts with the alarm.

We need to know:
A. Can we reliably detect a snooze?
B. Can we reliably detect dismissal?
C. Can we determine the actual snooze duration?
D. Can we maintain authoritative financial state if the app is not running?
E. Can we safely calculate the final amount?
F. Can we initiate/complete the payment after the alarm session ends?

ARCHITECTURAL FREEDOM:

Do NOT blindly follow my proposed architecture.

You have explicit permission to RE-EVALUATE ANY PART OF THIS PLAN if your investigation shows that another approach is more reliable, secure, idiomatic, maintainable, legally compliant, or compatible with Apple's platform rules.

If you discover a fundamental limitation, tell me immediately.

Do not hide a platform limitation behind a hack.

If you think a different technology, backend architecture, payment provider, or alarm mechanism is better, explain why and recommend the change.

DEVELOPMENT STYLE:

Build incrementally, but real payments are part of the MVP.

For each meaningful feature:

* implement it
* write appropriate tests
* run the tests
* run the compiler/build
* inspect your own changes
* identify failure modes
* fix problems
* then move to the next feature

Do not create a giant implementation in one step.

FIRST TASK:

Do NOT start by building the UI.

First perform a technical feasibility and architecture investigation.

Investigate the current iOS SDK/API capabilities, especially:

* AlarmKit
* relevant notification/alarm APIs
* payment APIs
* App Store requirements
* secure payment-method storage
* background/termination behavior

Then give me:

1. Recommended overall architecture
2. Recommended payment architecture
3. Recommended alarm architecture
4. Minimum supported iOS version
5. Whether a backend is required and why
6. Data model/state machine for an alarm session
7. How the financial calculation should work
8. How to prevent duplicate/incorrect charges
9. Important App Store/legal/payment risks
10. Any parts of my plan you would change
11. A step-by-step implementation plan

IMPORTANT:

Real money is a core requirement.

Do not remove real payments from the plan simply to make implementation easier.

At the same time, do not invent APIs, bypass Apple's rules, or use an unsafe payment architecture just to satisfy the requirement.

You are encouraged to challenge the product/technical plan whenever necessary.

Do not begin substantial implementation until you've completed this investigation and explained your recommendation.

---

STATUS (living log — kept up to date as work progresses; this is the durable summary for future sessions, full detail lives in git history and the session plan that produced it)

Architecture investigation: COMPLETE. Key decisions:

- **Min iOS 26.0** — required by AlarmKit.
- **Payment: Stripe, not StoreKit/IAP.** App Store Guideline 3.1.3(e) actually *requires* external processing for real-world services like this — IAP would be the non-compliant choice here, not the safe default. Flow: `SetupIntent` (on-session, establishes the mandate for later off-session charges) → at alarm-**fire** time, pre-authorize the session's configured max (`PaymentIntent`, `capture_method: manual`, `off_session: true`) → at dismiss, capture `min(computed_amount, max)` → cancel the uncaptured remainder. Idempotency key = `AlarmSession.id` on every Stripe call. Never store raw card data — only Stripe's tokenized `Customer`/`PaymentMethod` IDs, backend-side only.
- **Backend: required, thin.** Only for what can't safely live on-device: Stripe secret-key operations, authoritative capture/idempotency, webhook reconciliation, retry queue for payment-services-down cases. No other app logic lives server-side.
- **Alarm mechanism: AlarmKit + Hybrid snooze model (confirmed with user).** AlarmKit reliably wakes the device (breaks Focus/Silent, survives app force-quit/reboot) but its native snooze (`postAlert`) is a *fixed-length* system-owned cycle — it does not support "dismiss whenever you want, bill the exact second." So: AlarmKit's Snooze button opens the app directly into a fully custom in-app ticking-meter/Snooze/Dismiss screen for true per-second billing; a short AlarmKit re-alert is scheduled as a safety net if the user backgrounds the app mid-snooze without dismissing.
- **Financial state model**: durable, synchronously-written, append-only local event log is the *timing* source of truth (App Group shared container once the widget extension exists in step 3); the backend is the *money/capture* source of truth. `amountOwed` is always a pure function of the event list (never a live in-memory timer) — identical on-device (instant receipt) and server-side (actual capture), and survives crashes/kills mid-session.
- **Dev environment**: this work is done from a Windows session with no Xcode/macOS toolchain — I cannot compile, run `xcodebuild`, or execute *any* Swift code (not just AlarmKit-specific device testing) from here. Project is scaffolded via XcodeGen (`project.yml`, not a hand-edited `.xcodeproj`) and verified via GitHub Actions on a macOS runner (`.github/workflows/ios.yml`) — a free hosted Mac, so no local Mac is needed for compiling/unit tests. Every code step below is written carefully but genuinely unverified until CI (or a real device, for AlarmKit behavior) runs it — treat CI failures as expected/normal iteration, not surprises. User has a physical iPhone on iOS 26 available for step 3's on-device AlarmKit verification matrix (Lock Screen/Focus/Silent/force-quit/reboot) — that step will need a TestFlight or ad-hoc build once we get there.

Progress:
- [x] **Step 1 — Project scaffold.** XcodeGen `project.yml` (EarlyBird app target + EarlyBirdTests target, iOS 26.0 min), minimal SwiftUI shell (`EarlyBirdApp.swift`, `ContentView.swift`), placeholder test, GitHub Actions CI. Widget extension + App Group entitlement deliberately deferred to step 3 (not needed until AlarmKit is wired in — avoided adding them speculatively).
- [x] **Step 2 — Local data model, durable event log, financial calculation. VERIFIED GREEN IN CI.** `AlarmDefinition` (validated at construction: rate/max must be positive, currency code well-formed — no way to represent "unlimited" charge), `AlarmSession` + `AlarmSessionEvent` (append-only, idempotent against duplicate/out-of-order/late events — important since step 3 will have two processes, the app and the AlarmKit intent extension, both able to write; `dismissed` is terminal — a session's log never contains more than one), `MoneyCalculator.amountOwed` (pure function: measures the snoozeStarted→dismissed interval, clamped to `maxChargeAmount`, `Decimal`-based to avoid float error, rounded only at the final currency amount), `AlarmSessionStore` (atomic file-per-session JSON persistence — crash mid-write can never corrupt or half-write a session). Repo pushed to https://github.com/EliasGouatarbes/EarlyBird (public for now, to go private before launch) — GitHub Actions builds/tests on a hosted macOS runner on every push, no local Mac needed. First CI run caught one real bug (a test asserting a two-dismiss scenario the domain model can't actually produce — fixed by correcting the test, not the implementation). Second run: build succeeded, 38/38 tests passed.
- [~] **Step 3 — AlarmKit integration (no billing yet). Code written, compiles unverified, NOT yet confirmed on-device.** `EarlyBirdAlarmMetadata` (empty `AlarmMetadata` conformance), `AlarmDefinitionStore` (mirrors `AlarmSessionStore` — needed because the intents below only have an alarm id, not a whole `AlarmDefinition`, to work with), `AlarmSessionRecorder` (find-the-still-open-session-or-start-a-new-one logic, unit tested), `EarlyBirdSnoozeIntent`/`EarlyBirdDismissIntent` (`LiveActivityIntent`s wired as AlarmKit's `secondaryIntent`/`stopIntent`, both `openAppWhenRun = true`), `AlarmKitScheduler` (the live `AlarmManager` call site), and a temporary debug-harness UI in `ContentView.swift` to actually schedule a test alarm on-device.

  **Design decision worth flagging**: a daily-repeating `AlarmDefinition` is scheduled with AlarmKit *once*; its id doesn't change per day. Since there's no confirmed AlarmKit callback that runs exactly at fire time before a button is tapped, the Stop/Snooze intents only ever know the stable `AlarmDefinition.id` — so `AlarmSessionRecorder` finds the still-open `AlarmSession` for that id, or starts a fresh one if the last one is already closed. This is what makes each day's firing bill independently.

  **Deferred, with reasoning (not oversight)**: no widget extension, no App Group. AlarmKit's countdown/paused presentation — which needs a widget extension — is only used if the alarm has a `countdownDuration` or uses `.countdown` secondary-button behavior; this alarm uses neither (`countdownDuration: nil`, `secondaryButtonBehavior: .custom`), so on paper it should never enter that state. Since there's no separate extension process, the Stop/Snooze intents' `perform()` should run as a background launch of the *same* app target, so `AlarmSessionStore`/`AlarmDefinitionStore`'s plain Application Support storage (no App Group) should be reachable from both. **Both of these are unverified assumptions** — if on-device testing shows otherwise, a widget extension + App Group get added at that point.

  **Not yet implemented**: the safety-net re-alert (re-showing the alert if the user backgrounds the app mid-snooze without dismissing) — deferred until on-device testing shows what state AlarmKit actually leaves the alarm in after a `.custom` secondary-button tap, since the safety-net design depends on that.

  **On-device verification checklist** (needs a physical iPhone on iOS 26 — user has one; needs a way to install a build, which needs an Apple Developer Program account for code signing — TBD, see next question to user):
  - [ ] Does the project even compile against real AlarmKit (first CI run against this code)?
  - [ ] Does scheduling actually work — does `AlarmManager.shared.requestAuthorization()` prompt correctly, does `schedule(id:configuration:)` succeed?
  - [ ] Does the alarm fire reliably: phone locked / app backgrounded / app force-quit / phone rebooted / Focus mode on / Silent mode on?
  - [ ] Does tapping Stop actually invoke `EarlyBirdDismissIntent.perform()` (confirm via a visible side effect, e.g. check the recorded session file after)?
  - [ ] Does tapping Snooze actually invoke `EarlyBirdSnoozeIntent.perform()` **and** open the app?
  - [ ] What state is the alarm left in after a `.custom` secondary-button tap — does it keep ringing, go silent, or something else? (This determines the safety-net design.)
  - [ ] Does a widget extension turn out to be required anyway, even with `countdownDuration: nil`?
  - [ ] Does the app's plain Application Support directory get reached correctly from a background-launched intent, or does it need an App Group after all?
- [ ] **Step 4 — In-app snoozing UI** (ticking meter, custom Snooze/Dismiss, background safety-net re-alert scheduling).
- [ ] **Step 5 — Consent & configuration UI** (rate, hard max, required disclosures gating real-money mode).
- [ ] **Step 6 — Backend** (Stripe customer/SetupIntent, pre-auth-on-fire, capture-on-dismiss, webhooks, reconciliation job for stuck/unsettled sessions).
- [ ] **Step 7 — Payment method setup UI** (Stripe PaymentSheet, on-session card save + mandate).
- [ ] **Step 8 — End-to-end wiring** + failure-path tests (payment services down at fire time, capture fails, app killed mid-snooze, max-cap reached mid-snooze).
- [ ] **Step 9 — Receipt UI** (sourced from the same `amountOwed` function used everywhere else).
- [ ] **Step 10 — Hardening pass** against the full "what happens when..." list, reconciled against real observed behavior from step 3.

Known open follow-up (not a blocker, just not solved yet): once the AlarmKit intent extension exists (step 3), the shared event log will have two writer processes (main app + extension). Step 2's `AlarmSessionStore` is a simple last-write-wins file store — fine for a single writer, but concurrent-write safety across processes needs revisiting in step 3.
