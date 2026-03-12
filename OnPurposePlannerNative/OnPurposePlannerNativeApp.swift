import SwiftUI

@main
struct OnPurposePlannerNativeApp: App {
    @StateObject private var store    = PlannerStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(settings)
        }
    }
}
