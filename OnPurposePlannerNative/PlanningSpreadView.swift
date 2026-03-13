import SwiftUI

struct PlanningSpreadView: View {
    @ObservedObject var store: PlannerStore

    private let outerPadding: CGFloat = 28
    private let columnSpacing: CGFloat = 28
    private let headerHeight: CGFloat = 58

    private var width: CGFloat { PlannerTheme.spreadWidth }
    private var height: CGFloat { PlannerTheme.spreadHeight }
    private var contentWidth: CGFloat { width - (outerPadding * 2) - (columnSpacing * 2) }
    private var contentHeight: CGFloat { height - (outerPadding * 2) - headerHeight - 18 }
    private var todayWidth: CGFloat { contentWidth * 0.24 }
    private var weekWidth: CGFloat { contentWidth * 0.31 }
    private var monthWidth: CGFloat { contentWidth - todayWidth - weekWidth }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlannerTheme.paper

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: columnSpacing) {
                    columnHeader("to do today", width: todayWidth)
                    columnHeader("to do this week", width: weekWidth)
                    columnHeader("to do this month", width: monthWidth)
                }

                HStack(alignment: .top, spacing: columnSpacing) {
                    todayColumn
                    weekColumn
                    monthColumn
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, outerPadding)
            .padding(.top, outerPadding)

            DrawingCanvasView(
                pageId: store.planningSpreadPageId,
                store: store
            )
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func columnHeader(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold, design: .serif))
            .italic()
            .foregroundStyle(PlannerTheme.ink)
            .frame(width: width, height: headerHeight, alignment: .bottom)
    }

    private var todayColumn: some View {
        let dayInitials = ["S", "M", "T", "W", "T", "F", "S"]
        let rowHeight = contentHeight / CGFloat(dayInitials.count)

        return VStack(spacing: 0) {
            ForEach(Array(dayInitials.enumerated()), id: \.offset) { index, day in
                dayRow(day: day, height: rowHeight)
                    .overlay(alignment: .bottom) {
                        if index < dayInitials.count - 1 {
                            Rectangle()
                                .fill(PlannerTheme.hairline)
                                .frame(height: 1)
                        }
                    }
            }
        }
        .frame(width: todayWidth, height: contentHeight, alignment: .top)
    }

    private func dayRow(day: String, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            Text(day)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundStyle(PlannerTheme.ink)
                .padding(.top, 10)
                .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var weekColumn: some View {
        dotGrid(spacing: 22)
            .frame(width: weekWidth, height: contentHeight)
            .clipped()
    }

    private var monthColumn: some View {
        Color.clear
            .frame(width: monthWidth, height: contentHeight)
    }

    private func dotGrid(spacing: CGFloat) -> some View {
        Canvas { ctx, size in
            let cols = Int(size.width / spacing)
            let rows = Int(size.height / spacing)

            for row in 0...rows {
                for col in 0...cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let dot = Path(
                        ellipseIn: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)
                    )
                    ctx.fill(dot, with: .color(PlannerTheme.dot))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
