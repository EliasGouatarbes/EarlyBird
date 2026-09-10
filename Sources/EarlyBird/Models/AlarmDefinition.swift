import Foundation

/// A user-configured alarm: when it rings, and the terms of the financial penalty
/// that applies while the user snoozes it.
struct AlarmDefinition: Codable, Identifiable, Equatable {
    /// A daily wall-clock time, decoupled from AlarmKit's own scheduling types so this
    /// model doesn't have to change shape if the AlarmKit mapping layer (step 3) does.
    struct DailyTime: Codable, Equatable {
        var hour: Int
        var minute: Int
    }

    enum ValidationError: Error, Equatable {
        case invalidTime
        case rateMustBePositive
        case maxChargeMustBePositive
        case invalidCurrencyCode
    }

    let id: UUID
    var time: DailyTime
    var ratePerSecond: Decimal
    var maxChargeAmount: Decimal
    var currencyCode: String
    var paymentMethodReference: String?
    var isRealMoneyModeEnabled: Bool

    /// Validated at construction so an `AlarmDefinition` can never represent an
    /// unlimited or nonsensical charge — there is deliberately no way to build one
    /// with a zero/negative rate or without a positive hard maximum.
    init(
        id: UUID = UUID(),
        time: DailyTime,
        ratePerSecond: Decimal,
        maxChargeAmount: Decimal,
        currencyCode: String,
        paymentMethodReference: String? = nil,
        isRealMoneyModeEnabled: Bool = false
    ) throws {
        guard (0...23).contains(time.hour), (0...59).contains(time.minute) else {
            throw ValidationError.invalidTime
        }
        guard ratePerSecond > 0 else {
            throw ValidationError.rateMustBePositive
        }
        guard maxChargeAmount > 0 else {
            throw ValidationError.maxChargeMustBePositive
        }
        guard currencyCode.count == 3, currencyCode == currencyCode.uppercased() else {
            throw ValidationError.invalidCurrencyCode
        }

        self.id = id
        self.time = time
        self.ratePerSecond = ratePerSecond
        self.maxChargeAmount = maxChargeAmount
        self.currencyCode = currencyCode
        self.paymentMethodReference = paymentMethodReference
        self.isRealMoneyModeEnabled = isRealMoneyModeEnabled
    }
}
