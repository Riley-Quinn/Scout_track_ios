import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // 👇 Must exactly match your .xcdatamodeld file name
        container = NSPersistentContainer(name: "Model")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
