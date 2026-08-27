import Foundation

struct BeadSKU: Sendable, Hashable, Equatable {
    let brandID: String
    let seriesID: String
    let colorCode: String

    init(brandID: String, seriesID: String, colorCode: String) {
        self.brandID = brandID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.seriesID = seriesID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorCode = colorCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !brandID.isEmpty && !seriesID.isEmpty && !colorCode.isEmpty
    }
}

enum StockMovementKind: Sendable, Equatable {
    case inbound
    case outbound
    case stocktakeIncrease
    case stocktakeDecrease
    case outboundReversal
    case inboundReversal

    fileprivate var direction: Int64 {
        switch self {
        case .inbound, .stocktakeIncrease, .outboundReversal:
            1
        case .outbound, .stocktakeDecrease, .inboundReversal:
            -1
        }
    }
}

struct StockMovement: Sendable, Equatable, Identifiable {
    let id: UUID
    let sku: BeadSKU
    let kind: StockMovementKind
    let quantity: Int64
    let occurredAt: Date
    let idempotencyKey: String?

    init(
        id: UUID = UUID(),
        sku: BeadSKU,
        kind: StockMovementKind,
        quantity: Int64,
        occurredAt: Date = .now,
        idempotencyKey: String? = nil
    ) throws {
        guard sku.isValid else {
            throw InventoryLedgerError.invalidSKU
        }
        guard quantity > 0 else {
            throw InventoryLedgerError.nonPositiveQuantity(quantity)
        }

        let normalizedKey = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedKey == "" {
            throw InventoryLedgerError.emptyIdempotencyKey
        }

        self.id = id
        self.sku = sku
        self.kind = kind
        self.quantity = quantity
        self.occurredAt = occurredAt
        self.idempotencyKey = normalizedKey
    }
}

enum InventoryReservationStatus: Sendable, Equatable {
    case active
    case released
    case fulfilled
}

struct InventoryReservation: Sendable, Equatable, Identifiable {
    let id: UUID
    let sku: BeadSKU
    let quantity: Int64
    let status: InventoryReservationStatus

    init(
        id: UUID = UUID(),
        sku: BeadSKU,
        quantity: Int64,
        status: InventoryReservationStatus
    ) throws {
        guard sku.isValid else {
            throw InventoryLedgerError.invalidSKU
        }
        guard quantity > 0 else {
            throw InventoryLedgerError.nonPositiveQuantity(quantity)
        }

        self.id = id
        self.sku = sku
        self.quantity = quantity
        self.status = status
    }
}

struct PurchaseLine: Sendable, Equatable, Identifiable {
    let id: UUID
    let sku: BeadSKU
    let orderedQuantity: Int64
    let receivedQuantity: Int64

    init(
        id: UUID = UUID(),
        sku: BeadSKU,
        orderedQuantity: Int64,
        receivedQuantity: Int64 = 0
    ) throws {
        guard sku.isValid else {
            throw InventoryLedgerError.invalidSKU
        }
        guard orderedQuantity > 0 else {
            throw InventoryLedgerError.nonPositiveQuantity(orderedQuantity)
        }
        guard receivedQuantity >= 0 else {
            throw InventoryLedgerError.negativeQuantity(receivedQuantity)
        }
        guard receivedQuantity <= orderedQuantity else {
            throw InventoryLedgerError.receivedQuantityExceedsOrdered(
                received: receivedQuantity,
                ordered: orderedQuantity
            )
        }

        self.id = id
        self.sku = sku
        self.orderedQuantity = orderedQuantity
        self.receivedQuantity = receivedQuantity
    }

    var unreceivedQuantity: Int64 {
        orderedQuantity - receivedQuantity
    }
}

struct InventoryBalance: Sendable, Equatable {
    let onHand: Int64
    let reserved: Int64
    let available: Int64
    let inTransit: Int64
    let expectedAvailable: Int64
}

enum InventoryLedgerError: Error, Equatable {
    case invalidSKU
    case nonPositiveQuantity(Int64)
    case negativeQuantity(Int64)
    case emptyIdempotencyKey
    case receivedQuantityExceedsOrdered(received: Int64, ordered: Int64)
    case duplicateMovementID(UUID)
    case duplicateIdempotencyKey(String)
    case quantityOverflow
}

struct InventoryLedger: Sendable {
    private(set) var movements: [StockMovement] = []
    private var movementIDs = Set<UUID>()
    private var idempotencyKeys = Set<String>()

    mutating func record(_ movement: StockMovement) throws {
        guard movementIDs.insert(movement.id).inserted else {
            throw InventoryLedgerError.duplicateMovementID(movement.id)
        }

        if let key = movement.idempotencyKey {
            guard idempotencyKeys.insert(key).inserted else {
                movementIDs.remove(movement.id)
                throw InventoryLedgerError.duplicateIdempotencyKey(key)
            }
        }

        movements.append(movement)
    }

    func balance(
        for sku: BeadSKU,
        reservations: [InventoryReservation] = [],
        purchaseLines: [PurchaseLine] = []
    ) throws -> InventoryBalance {
        var onHand: Int64 = 0
        for movement in movements where movement.sku == sku {
            onHand = try adding(onHand, signedQuantity(for: movement))
        }
        let reserved = try sum(
            reservations.lazy
                .filter { $0.sku == sku && $0.status == .active }
                .map(\.quantity)
        )
        let inTransit = try sum(
            purchaseLines.lazy
                .filter { $0.sku == sku }
                .map(\.unreceivedQuantity)
        )

        let subtraction = onHand.subtractingReportingOverflow(reserved)
        guard !subtraction.overflow else {
            throw InventoryLedgerError.quantityOverflow
        }
        let available = max(subtraction.partialValue, 0)

        let expected = available.addingReportingOverflow(inTransit)
        guard !expected.overflow else {
            throw InventoryLedgerError.quantityOverflow
        }

        return InventoryBalance(
            onHand: onHand,
            reserved: reserved,
            available: available,
            inTransit: inTransit,
            expectedAvailable: expected.partialValue
        )
    }

    private func signedQuantity(for movement: StockMovement) throws -> Int64 {
        let result = movement.quantity.multipliedReportingOverflow(by: movement.kind.direction)
        guard !result.overflow else {
            throw InventoryLedgerError.quantityOverflow
        }
        return result.partialValue
    }

    private func adding(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow else {
            throw InventoryLedgerError.quantityOverflow
        }
        return result.partialValue
    }

    private func sum<S: Sequence>(_ values: S) throws -> Int64 where S.Element == Int64 {
        try values.reduce(into: Int64.zero) { partialResult, value in
            partialResult = try adding(partialResult, value)
        }
    }
}
