import CoreData
import Foundation

@MainActor
final class CoreDataInventoryLedgerRepository: InventoryLedgerRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchMovements() throws -> [StockMovement] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "InventoryMovementRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "occurredAt", ascending: true)]

        return try context.fetch(request).map(Self.movement(from:))
    }

    func save(_ movement: StockMovement) throws {
        let record = NSEntityDescription.insertNewObject(
            forEntityName: "InventoryMovementRecord",
            into: context
        )
        record.setValue(movement.id, forKey: "id")
        record.setValue(movement.sku.brandID, forKey: "brandID")
        record.setValue(movement.sku.seriesID, forKey: "seriesID")
        record.setValue(movement.sku.colorCode, forKey: "colorCode")
        record.setValue(movement.kind.rawCode, forKey: "kind")
        record.setValue(movement.quantity, forKey: "quantity")
        record.setValue(movement.occurredAt, forKey: "occurredAt")
        record.setValue(movement.idempotencyKey, forKey: "idempotencyKey")

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func movement(from record: NSManagedObject) throws -> StockMovement {
        guard let id = record.value(forKey: "id") as? UUID,
              let brandID = record.value(forKey: "brandID") as? String,
              let seriesID = record.value(forKey: "seriesID") as? String,
              let colorCode = record.value(forKey: "colorCode") as? String,
              let rawKind = record.value(forKey: "kind") as? String,
              let kind = StockMovementKind(rawCode: rawKind),
              let occurredAt = record.value(forKey: "occurredAt") as? Date else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }

        let quantity = record.value(forKey: "quantity") as? Int64 ?? 0
        let key = record.value(forKey: "idempotencyKey") as? String
        return try StockMovement(
            id: id,
            sku: BeadSKU(brandID: brandID, seriesID: seriesID, colorCode: colorCode),
            kind: kind,
            quantity: quantity,
            occurredAt: occurredAt,
            idempotencyKey: key
        )
    }
}
