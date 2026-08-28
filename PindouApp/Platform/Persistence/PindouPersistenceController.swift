import CoreData
import Foundation

@MainActor
final class PindouPersistenceController {
    let container: NSPersistentContainer

    init(storeName: String = "PindouApp", inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: storeName,
            managedObjectModel: Self.managedObjectModel
        )

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            description.type = NSSQLiteStoreType
            description.url = Self.storeURL(named: storeName)
        }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("无法打开本地数据存储：\(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func storeURL(named storeName: String) -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return directory.appendingPathComponent("\(storeName).sqlite")
    }

    private static var managedObjectModel: NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let movement = NSEntityDescription()
        movement.name = "InventoryMovementRecord"
        movement.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        movement.properties = [
            attribute(name: "id", type: .UUIDAttributeType, optional: false),
            attribute(name: "brandID", type: .stringAttributeType, optional: false),
            attribute(name: "seriesID", type: .stringAttributeType, optional: false),
            attribute(name: "colorCode", type: .stringAttributeType, optional: false),
            attribute(name: "kind", type: .stringAttributeType, optional: false),
            attribute(name: "quantity", type: .integer64AttributeType, optional: false),
            attribute(name: "occurredAt", type: .dateAttributeType, optional: false),
            attribute(name: "idempotencyKey", type: .stringAttributeType, optional: true)
        ]
        model.entities = [movement]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }
}
