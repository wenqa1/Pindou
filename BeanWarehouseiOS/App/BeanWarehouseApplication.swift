import SwiftUI

@main
struct BeanWarehouseApplication: App {
    private let persistenceController: PindouPersistenceController
    @StateObject private var inventoryDashboardModel: InventoryDashboardModel

    init() {
        let persistenceController = PindouPersistenceController(storeName: "BeanWarehouse")
        self.persistenceController = persistenceController
        let repository = CoreDataInventoryLedgerRepository(
            context: persistenceController.container.viewContext
        )
        _inventoryDashboardModel = StateObject(
            wrappedValue: InventoryDashboardModel(repository: repository)
        )
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                InventoryDashboardView(model: inventoryDashboardModel)
            }
        }
    }
}
