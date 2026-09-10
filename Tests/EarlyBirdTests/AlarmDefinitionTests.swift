import XCTest
@testable import EarlyBird

final class AlarmDefinitionTests: XCTestCase {
    private func makeValidDefinition(
        ratePerSecond: Decimal = Decimal(string: "0.10")!,
        maxChargeAmount: Decimal = Decimal(string: "20.00")!,
        currencyCode: String = "EUR"
    ) throws -> AlarmDefinition {
        try AlarmDefinition(
            time: .init(hour: 7, minute: 0),
            ratePerSecond: ratePerSecond,
            maxChargeAmount: maxChargeAmount,
            currencyCode: currencyCode
        )
    }

    func testValidDefinitionConstructsSuccessfully() throws {
        let definition = try makeValidDefinition()
        XCTAssertEqual(definition.time.hour, 7)
        XCTAssertEqual(definition.time.minute, 0)
        XCTAssertFalse(definition.isRealMoneyModeEnabled) // opt-in, never defaults to on
    }

    func testZeroRateIsRejected() {
        XCTAssertThrowsError(try makeValidDefinition(ratePerSecond: Decimal(0))) { error in
            XCTAssertEqual(error as? AlarmDefinition.ValidationError, .rateMustBePositive)
        }
    }

    func testNegativeRateIsRejected() {
        XCTAssertThrowsError(try makeValidDefinition(ratePerSecond: Decimal(-1))) { error in
            XCTAssertEqual(error as? AlarmDefinition.ValidationError, .rateMustBePositive)
        }
    }

    func testZeroMaxChargeIsRejected() {
        // A zero (or missing) max would mean "no cap" is representable — CLAUDE.md
        // requires a hard, positive maximum, so this must be impossible to construct.
        XCTAssertThrowsError(try makeValidDefinition(maxChargeAmount: Decimal(0))) { error in
            XCTAssertEqual(error as? AlarmDefinition.ValidationError, .maxChargeMustBePositive)
        }
    }

    func testNegativeMaxChargeIsRejected() {
        XCTAssertThrowsError(try makeValidDefinition(maxChargeAmount: Decimal(-5))) { error in
            XCTAssertEqual(error as? AlarmDefinition.ValidationError, .maxChargeMustBePositive)
        }
    }

    func testInvalidCurrencyCodeIsRejected() {
        XCTAssertThrowsError(try makeValidDefinition(currencyCode: "euro")) { error in
            XCTAssertEqual(error as? AlarmDefinition.ValidationError, .invalidCurrencyCode)
        }
    }

    func testOutOfRangeTimeIsRejected() {
        XCTAssertThrowsError(try AlarmDefinition(
            time: .init(hour: 24, minute: 0),
            ratePerSecond: Decimal(string: "0.10")!,
            maxChargeAmount: Decimal(string: "20.00")!,
            currencyCode: "EUR"
        )) { error in
            XCTAssertEqual(error as? AlarmDefinition.ValidationError, .invalidTime)
        }
    }
}
