import SwiftUI

@main
struct OnPurposePlannerNativeApp: App {
    @StateObject private var store    = PlannerStore()
    @StateObject private var settings = AppSettings()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootContainerView(
                hasCompletedOnboarding: $hasCompletedOnboarding,
                store: store,
                settings: settings
            )
        }
    }
}

private struct RootContainerView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var store: PlannerStore
    @ObservedObject var settings: AppSettings

    @State private var showSplash = true

    var body: some View {
        ZStack {
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

            if showSplash {
                SplashScreenView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}
