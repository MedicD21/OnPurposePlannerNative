import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: PlannerStore

    var body: some View {
        ZStack(alignment: .trailing) {
            // Full-screen planner spread
            PlannerSpreadContainerView(store: store)
                .ignoresSafeArea()
                .background(PlannerTheme.paper)

            // Month tabs (right edge)
            HStack(spacing: 0) {
                Spacer()
                VStack {
                    Spacer()
                    MonthTabsView(store: store)
                    Spacer()
                }
            }
            .ignoresSafeArea(edges: .trailing)

            // Floating toolbar (right side, draggable)
            HStack(spacing: 0) {
                Spacer()
                VStack {
                    Spacer()
                    FloatingToolbarView()
                        .padding(.trailing, 52)  // offset left of the month tabs
                    Spacer()
                }
            }
        }
        .background(PlannerTheme.paper)
        .statusBar(hidden: true)
    }
}

#Preview {
    ContentView()
        .environmentObject(PlannerStore())
}
