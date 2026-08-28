import Combine
import Foundation

struct InventoryEntryDraft: Equatable {
    let brandID: String
    let seriesID: String
    let colorCode: String
    let quantity: Int64

    var sku: BeadSKU {
        BeadSKU(brandID: brandID, seriesID: seriesID, colorCode: colorCode)
    }
}

struct InventorySKUOverview: Identifiable, Equatable {
    let sku: BeadSKU
    let balance: InventoryBalance

    var id: BeadSKU { sku }
}

@MainActor
final class InventoryDashboardModel: ObservableObject {
    @Published private(set) var movements: [StockMovement] = []
    @Published private(set) var errorMessage: String?

    let lowStockThreshold: Int64

    private let repository: any InventoryLedgerRepository
    private var ledger = InventoryLedger()

    init(
        repository: any InventoryLedgerRepository,
        lowStockThreshold: Int64 = 7_000
    ) {
        self.repository = repository
        self.lowStockThreshold = lowStockThreshold
        reload()
    }

    var skuOverviews: [InventorySKUOverview] {
        let uniqueSKUs = Set(movements.map(\.sku))

        return uniqueSKUs.compactMap { sku in
            guard let balance = try? ledger.balance(for: sku) else {
                return nil
            }
            return InventorySKUOverview(sku: sku, balance: balance)
        }
        .sorted { lhs, rhs in
            if lhs.sku.brandID != rhs.sku.brandID {
                return lhs.sku.brandID.localizedStandardCompare(rhs.sku.brandID) == .orderedAscending
            }
            if lhs.sku.seriesID != rhs.sku.seriesID {
                return lhs.sku.seriesID.localizedStandardCompare(rhs.sku.seriesID) == .orderedAscending
            }
            return lhs.sku.colorCode.localizedStandardCompare(rhs.sku.colorCode) == .orderedAscending
        }
    }

    var totalOnHand: Int64 {
        skuOverviews.reduce(0) { $0 + max($1.balance.onHand, 0) }
    }

    var totalAvailable: Int64 {
        skuOverviews.reduce(0) { $0 + $1.balance.available }
    }

    var lowStockCount: Int {
        skuOverviews.filter { $0.balance.available < lowStockThreshold }.count
    }

    func overview(for sku: BeadSKU) -> InventorySKUOverview? {
        skuOverviews.first { $0.sku == sku }
    }

    func movements(for sku: BeadSKU) -> [StockMovement] {
        movements
            .filter { $0.sku == sku }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    func preview(kind: StockMovementKind, draft: InventoryEntryDraft) -> InventoryBalance? {
        guard draft.sku.isValid, draft.quantity > 0 else {
            return nil
        }

        var previewLedger = ledger
        guard let movement = try? StockMovement(sku: draft.sku, kind: kind, quantity: draft.quantity) else {
            return nil
        }
        do {
            try previewLedger.record(movement)
            return try previewLedger.balance(for: draft.sku)
        } catch {
            return nil
        }
    }

    @discardableResult
    func record(
        kind: StockMovementKind,
        draft: InventoryEntryDraft,
        idempotencyKey: String
    ) -> Bool {
        do {
            try validate(kind: kind, draft: draft)
            let movement = try StockMovement(
                sku: draft.sku,
                kind: kind,
                quantity: draft.quantity,
                idempotencyKey: idempotencyKey
            )
            var nextLedger = ledger
            try nextLedger.record(movement)
            try repository.save(movement)

            ledger = nextLedger
            movements = nextLedger.movements
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func reload() {
        do {
            let storedMovements = try repository.fetchMovements()
            var rebuiltLedger = InventoryLedger()
            for movement in storedMovements {
                try rebuiltLedger.record(movement)
            }
            ledger = rebuiltLedger
            movements = rebuiltLedger.movements
        } catch {
            errorMessage = "库存流水读取失败，请稍后重试。"
        }
    }

    private func validate(kind: StockMovementKind, draft: InventoryEntryDraft) throws {
        guard draft.sku.isValid else {
            throw InventoryLedgerError.invalidSKU
        }
        guard draft.quantity > 0 else {
            throw InventoryLedgerError.nonPositiveQuantity(draft.quantity)
        }

        guard kind == .outbound else {
            return
        }
        let available = try ledger.balance(for: draft.sku).available
        guard available >= draft.quantity else {
            throw InventoryLedgerError.insufficientAvailable(
                requested: draft.quantity,
                available: available
            )
        }
    }

    private func message(for error: Error) -> String {
        guard let ledgerError = error as? InventoryLedgerError else {
            return "库存操作未保存，请重试。"
        }

        switch ledgerError {
        case .invalidSKU:
            return "请填写品牌、系列和色号。"
        case .nonPositiveQuantity:
            return "数量必须是正整数。"
        case .duplicateIdempotencyKey:
            return "此操作已提交，请勿重复出入库。"
        case let .insufficientAvailable(requested, available):
            return "可用库存仅 (available) 颗，无法出库 (requested) 颗。"
        default:
            return "库存操作未保存，请重试。"
        }
    }
}
