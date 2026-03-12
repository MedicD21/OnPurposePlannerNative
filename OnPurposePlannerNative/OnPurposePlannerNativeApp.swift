import SwiftUI

@main
struct OnPurposePlannerNativeApp: App {
    @StateObject private var store    = PlannerStore()
    @StateObject private var settings = AppSettings()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(settings)
            } else {
                OnboardingView(
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    store: store,
                    settings: settings
                )
            }
        }
    }
}
