import CoreData
import SwiftUI

@main
struct ScoutTrackEmployeeApp: App {
    @AppStorage("sessionActive") private var sessionActive: Bool = false
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if sessionActive {
                DashboardView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                LoginView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
