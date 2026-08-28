import XCTest
@testable import PindouApp

@MainActor
final class InventoryDashboardModelTests: XCTestCase {
    func testInboundIsSavedAndShownInOverview() {
        let repository = InMemoryInventoryLedgerRepository()
        let model = InventoryDashboardModel(repository: repository, lowStockThreshold: 50)
        let draft = InventoryEntryDraft(
            brandID: "Perler",
            seriesID: "Standard",
            colorCode: "F22",
            quantity: 100
        )

        XCTAssertTrue(model.record(kind: .inbound, draft: draft, idempotencyKey: "inbound-1"))
        XCTAssertEqual(repository.storedMovements.count, 1)
        XCTAssertEqual(model.skuOverviews.count, 1)
        XCTAssertEqual(model.skuOverviews[0].balance.onHand, 100)
        XCTAssertEqual(model.skuOverviews[0].balance.available, 100)
    }

    func testOutboundAboveAvailableIsRejectedBeforePersistence() {
        let repository = InMemoryInventoryLedgerRepository()
        let model = InventoryDashboardModel(repository: repository)
        let draft = InventoryEntryDraft(
            brandID: "Perler",
            seriesID: "Standard",
            colorCode: "F22",
            quantity: 20
        )
        XCTAssertTrue(model.record(kind: .inbound, draft: draft, idempotencyKey: "inbound-1"))

        let tooLargeOutbound = InventoryEntryDraft(
            brandID: "Perler",
            seriesID: "Standard",
            colorCode: "F22",
            quantity: 21
        )

        XCTAssertFalse(model.record(kind: .outbound, draft: tooLargeOutbound, idempotencyKey: "outbound-1"))
        XCTAssertEqual(repository.storedMovements.count, 1)
        XCTAssertEqual(model.skuOverviews[0].balance.available, 20)
        XCTAssertEqual(model.errorMessage, "可用库存仅 20 颗，无法出库 21 颗。")
    }

    func testDuplicateSubmissionKeyDoesNotCreateSecondMovement() {
        let repository = InMemoryInventoryLedgerRepository()
        let model = InventoryDashboardModel(repository: repository)
        let draft = InventoryEntryDraft(
            brandID: "Perler",
            seriesID: "Standard",
            colorCode: "F22",
            quantity: 50
        )

        XCTAssertTrue(model.record(kind: .inbound, draft: draft, idempotencyKey: "inbound-1"))
        XCTAssertFalse(model.record(kind: .inbound, draft: draft, idempotencyKey: "inbound-1"))
        XCTAssertEqual(repository.storedMovements.count, 1)
        XCTAssertEqual(model.skuOverviews[0].balance.onHand, 50)
    }
}

@MainActor
private final class InMemoryInventoryLedgerRepository: InventoryLedgerRepository {
    private(set) var storedMovements: [StockMovement] = []

    func fetchMovements() throws -> [StockMovement] {
        storedMovements
    }

    func save(_ movement: StockMovement) throws {
        storedMovements.append(movement)
    }
}
