import CoreData
import SwiftUI
import UIKit

@main
struct ScoutTrackEmployeeApp: App {
    @AppStorage("sessionActive") private var sessionActive: Bool = false
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            if sessionActive {
                NavigationView {
                    DashboardView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            } else {
                LoginView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .navigationViewStyle(StackNavigationViewStyle()) // Force full screen
            }
        }
    }
}
