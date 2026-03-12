import SwiftUI

@main
struct OnPurposePlannerNativeApp: App {
    @StateObject private var store = PlannerStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
