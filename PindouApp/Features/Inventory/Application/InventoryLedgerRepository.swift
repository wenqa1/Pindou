import Foundation

@MainActor
protocol InventoryLedgerRepository {
    func fetchMovements() throws -> [StockMovement]
    func save(_ movement: StockMovement) throws
}
