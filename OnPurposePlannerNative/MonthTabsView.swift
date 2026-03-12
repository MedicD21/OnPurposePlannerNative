import SwiftUI

struct MonthTabsView: View {
    @ObservedObject var store: PlannerStore

    private let tabHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...12, id: \.self) { month in
                monthTab(month: month)
            }
        }
        .background(PlannerTheme.tab)
        .cornerRadius(8, corners: [.topLeft, .bottomLeft])
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: -2, y: 0)
    }

    private func monthTab(month: Int) -> some View {
        let isCurrentMonth = (month == store.currentMonth)
        let currentYear    = store.currentYear

        return Button {
            store.navigateToMonth(month, year: currentYear)
        } label: {
            Text(monthNames[month - 1])
                .font(.system(size: 11, weight: isCurrentMonth ? .semibold : .regular))
                .foregroundStyle(isCurrentMonth ? PlannerTheme.paper : PlannerTheme.ink)
                .frame(width: 36, height: tabHeight)
                .background(isCurrentMonth ? PlannerTheme.cover : Color.clear)
        }
    }
}

// MARK: - Rounded corners helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect:    rect,
            byRoundingCorners: corners,
            cornerRadii:    CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
