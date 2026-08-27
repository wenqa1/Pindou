import Foundation
import XCTest
@testable import PindouApp

final class InventoryLedgerTests: XCTestCase {
    private let f22 = BeadSKU(brandID: "perler", seriesID: "standard", colorCode: "F22")
    private let c15 = BeadSKU(brandID: "perler", seriesID: "standard", colorCode: "C15")

    func testBalanceIsDerivedFromInboundAndOutboundMovements() throws {
        var ledger = InventoryLedger()
        try ledger.record(StockMovement(sku: f22, kind: .inbound, quantity: 100))
        try ledger.record(StockMovement(sku: f22, kind: .outbound, quantity: 28))

        let balance = try ledger.balance(for: f22)

        XCTAssertEqual(balance.onHand, 72)
        XCTAssertEqual(balance.available, 72)
        XCTAssertEqual(balance.inTransit, 0)
    }

    func testReservationReducesAvailabilityWithoutChangingOnHand() throws {
        var ledger = InventoryLedger()
        try ledger.record(StockMovement(sku: f22, kind: .inbound, quantity: 100))
        let reservation = try InventoryReservation(sku: f22, quantity: 35, status: .active)

        let balance = try ledger.balance(for: f22, reservations: [reservation])

        XCTAssertEqual(balance.onHand, 100)
        XCTAssertEqual(balance.reserved, 35)
        XCTAssertEqual(balance.available, 65)
    }

    func testInTransitQuantityComesFromUnreceivedPurchaseLines() throws {
        let purchase = try PurchaseLine(
            sku: f22,
            orderedQuantity: 100,
            receivedQuantity: 25
        )

        let balance = try InventoryLedger().balance(for: f22, purchaseLines: [purchase])

        XCTAssertEqual(balance.onHand, 0)
        XCTAssertEqual(balance.inTransit, 75)
        XCTAssertEqual(balance.expectedAvailable, 75)
    }

    func testReleasedReservationNoLongerReducesAvailability() throws {
        var ledger = InventoryLedger()
        try ledger.record(StockMovement(sku: f22, kind: .inbound, quantity: 50))
        let reservation = try InventoryReservation(sku: f22, quantity: 20, status: .released)

        XCTAssertEqual(try ledger.balance(for: f22, reservations: [reservation]).available, 50)
    }

    func testAvailabilityNeverDropsBelowZeroWhenOutboundExceedsOnHand() throws {
        var ledger = InventoryLedger()
        try ledger.record(StockMovement(sku: f22, kind: .outbound, quantity: 8))

        let balance = try ledger.balance(for: f22)

        XCTAssertEqual(balance.onHand, -8)
        XCTAssertEqual(balance.available, 0)
    }

    func testDuplicateIdempotencyKeyRejectsSecondMovement() throws {
        var ledger = InventoryLedger()
        try ledger.record(
            StockMovement(
                sku: f22,
                kind: .outbound,
                quantity: 10,
                idempotencyKey: "build-session-123"
            )
        )

        XCTAssertThrowsError(
            try ledger.record(
                StockMovement(
                    sku: f22,
                    kind: .outbound,
                    quantity: 10,
                    idempotencyKey: "build-session-123"
                )
            )
        ) { error in
            XCTAssertEqual(error as? InventoryLedgerError, .duplicateIdempotencyKey("build-session-123"))
        }
    }

    func testBalanceKeepsSKUsIndependent() throws {
        var ledger = InventoryLedger()
        try ledger.record(StockMovement(sku: f22, kind: .inbound, quantity: 10))
        try ledger.record(StockMovement(sku: c15, kind: .inbound, quantity: 30))

        XCTAssertEqual(try ledger.balance(for: f22).onHand, 10)
        XCTAssertEqual(try ledger.balance(for: c15).onHand, 30)
    }

    func testNonPositiveQuantitiesAreRejected() {
        XCTAssertThrowsError(try StockMovement(sku: f22, kind: .inbound, quantity: 0)) { error in
            XCTAssertEqual(error as? InventoryLedgerError, .nonPositiveQuantity(0))
        }
    }
}
