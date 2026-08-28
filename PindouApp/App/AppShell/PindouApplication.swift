import SwiftUI

@main
struct PindouApplication: App {
    private let persistenceController: PindouPersistenceController
    @StateObject private var inventoryDashboardModel: InventoryDashboardModel

    init() {
        let persistenceController = PindouPersistenceController()
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
            RootView(inventoryDashboardModel: inventoryDashboardModel)
        }
    }
}
