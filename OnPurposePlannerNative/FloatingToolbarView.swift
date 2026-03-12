import SwiftUI

/// Minimal overlay that handles the non-drawing controls: spread navigation
/// and month navigation.  All drawing tools (pen, pencil, marker, eraser,
/// lasso, ruler, colour picker, stroke width, undo/redo) are provided by
/// PKToolPicker — Apple's native floating tool palette — which appears
/// automatically when a PKCanvasView is first responder.
struct FloatingToolbarView: View {
    @EnvironmentObject var store: PlannerStore

    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(PlannerTheme.line.opacity(0.5))
                .frame(width: 32, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 6)

            // Spread selector
            VStack(spacing: 2) {
                ForEach(SpreadType.allCases, id: \.self) { spread in
                    spreadButton(spread)
                }
            }
            .padding(.bottom, 8)

            Divider().frame(width: 44)

            // Month navigation
            VStack(spacing: 4) {
                navButton(systemImage: "chevron.up",   action: store.goToPreviousMonth)
                    .help("Previous month")
                Text(monthLabel)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PlannerTheme.ink)
                    .frame(width: 44)
                navButton(systemImage: "chevron.down", action: store.goToNextMonth)
                    .help("Next month")
            }
            .padding(.vertical, 8)

            // Week navigation (only relevant on month-week spread)
            if store.activeSpread == .monthWeek {
                Divider().frame(width: 44)
                VStack(spacing: 4) {
                    navButton(systemImage: "chevron.left",  action: store.goToPreviousWeek)
                        .help("Previous week")
                    Text("Wk \(store.currentWeekIndex + 1)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(PlannerTheme.line)
                        .frame(width: 44)
                    navButton(systemImage: "chevron.right", action: store.goToNextWeek)
                        .help("Next week")
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 56)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, x: -3, y: 3)
        )
        .offset(offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { value in
                    offset = value.translation
                }
        )
    }

    // MARK: - Components

    private func spreadButton(_ spread: SpreadType) -> some View {
        let isActive = store.activeSpread == spread
        return Button {
            store.activeSpread = spread
        } label: {
            Text(shortLabel(spread))
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? PlannerTheme.paper : PlannerTheme.ink)
                .frame(width: 44, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? PlannerTheme.cover : Color.clear)
                )
        }
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PlannerTheme.ink)
                .frame(width: 36, height: 28)
        }
    }

    private func shortLabel(_ spread: SpreadType) -> String {
        switch spread {
        case .monthWeek: return "Cal"
        case .planning:  return "Plan"
        case .notes:     return "Notes"
        }
    }

    private var monthLabel: String {
        let names = ["Jan","Feb","Mar","Apr","May","Jun",
                     "Jul","Aug","Sep","Oct","Nov","Dec"]
        return names[(store.currentMonth - 1) % 12]
    }
}
