import XCTest
@testable import EarlyBird

final class AlarmDefinitionStoreTests: XCTestCase {
    private var directory: URL!
    private var store: AlarmDefinitionStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EarlyBirdTests-\(UUID().uuidString)")
        store = AlarmDefinitionStore(directory: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    private func makeDefinition() throws -> AlarmDefinition {
        try AlarmDefinition(
            time: .init(hour: 7, minute: 0),
            ratePerSecond: Decimal(string: "0.10")!,
            maxChargeAmount: Decimal(string: "20.00")!,
            currencyCode: "EUR"
        )
    }

    func testSaveThenLoadRoundTrips() throws {
        let definition = try makeDefinition()
        try store.save(definition)

        let loaded = try store.load(id: definition.id)

        XCTAssertEqual(loaded, definition)
    }

    func testLoadingUnknownDefinitionReturnsNil() throws {
        XCTAssertNil(try store.load(id: UUID()))
    }

    func testLoadAllReturnsEverySavedDefinition() throws {
        let definitions = try [makeDefinition(), makeDefinition(), makeDefinition()]
        for definition in definitions {
            try store.save(definition)
        }

        let loaded = try store.loadAll()

        XCTAssertEqual(Set(loaded.map(\.id)), Set(definitions.map(\.id)))
    }

    func testSavingTwiceOverwritesRatherThanDuplicates() throws {
        var definition = try makeDefinition()
        try store.save(definition)

        definition.isRealMoneyModeEnabled = true
        try store.save(definition)

        let all = try store.loadAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.isRealMoneyModeEnabled, true)
    }

    func testDeleteRemovesTheDefinition() throws {
        let definition = try makeDefinition()
        try store.save(definition)

        try store.delete(id: definition.id)

        XCTAssertNil(try store.load(id: definition.id))
    }
}
