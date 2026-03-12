import SwiftUI
import PencilKit

struct PlanningSpreadView: View {
    @ObservedObject var store: PlannerStore

    private var leftWidth:  CGFloat { PlannerTheme.leftPaperWidth }
    private var rightWidth: CGFloat { PlannerTheme.rightPaperWidth }
    private var height:     CGFloat { PlannerTheme.spreadHeight }

    var body: some View {
        HStack(spacing: 0) {
            planningLeft
            divider
            planningRight
        }
        .frame(width: PlannerTheme.spreadWidth, height: height)
    }

    // MARK: - Left paper: weekly intentions

    private var planningLeft: some View {
        ZStack(alignment: .topLeading) {
            PlannerTheme.paper

            VStack(alignment: .leading, spacing: 0) {
                // Header
                Text("PLANNING")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .tracking(4)
                    .foregroundStyle(PlannerTheme.ink)
                    .padding(.top, 32)
                    .padding(.leading, 32)

                // Month label
                let cal = generateCalendar(year: store.currentYear, month: store.currentMonth)
                Text("\(cal.monthName) \(store.currentYear)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(PlannerTheme.line)
                    .padding(.top, 4)
                    .padding(.leading, 32)

                // Divider
                Rectangle()
                    .fill(PlannerTheme.line)
                    .frame(height: 1)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                // "THIS WEEK" label
                Text("THIS WEEK")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(PlannerTheme.line)
                    .padding(.leading, 32)
                    .padding(.top, 16)

                // 7 intention rows (one per day)
                intentionRows
                    .padding(.top, 8)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .frame(width: leftWidth, height: height)

            DrawingCanvasView(
                pageId: store.pageId(for: .planning, side: .left),
                store:  store
            )
            .frame(width: leftWidth, height: height)
        }
        .frame(width: leftWidth, height: height)
        .clipped()
    }

    private var intentionRows: some View {
        let dayAbbrevs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let rowHeight: CGFloat = (height - 240) / 7

        return VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                intentionRow(dayAbbrev: dayAbbrevs[i], rowHeight: rowHeight)
            }
        }
    }

    private func intentionRow(dayAbbrev: String, rowHeight: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Day abbreviation
            Text(dayAbbrev)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PlannerTheme.line)
                .frame(width: 28, alignment: .leading)

            // Checkbox circle
            Circle()
                .stroke(PlannerTheme.line, lineWidth: 1)
                .frame(width: 14, height: 14)

            // Lined space
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(PlannerTheme.hairline)
                    .frame(height: 0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight * 0.8)
        }
        .frame(height: rowHeight)
    }

    // MARK: - Right paper: to-do / dot grid

    private var planningRight: some View {
        ZStack(alignment: .topLeading) {
            PlannerTheme.paper

            VStack(alignment: .leading, spacing: 0) {
                Text("TO DO THIS MONTH")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(PlannerTheme.ink)
                    .padding(.top, 32)
                    .padding(.leading, 24)

                Rectangle()
                    .fill(PlannerTheme.line)
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Dot grid fills remaining space
                dotGrid
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .frame(width: rightWidth, height: height)

            DrawingCanvasView(
                pageId: store.pageId(for: .planning, side: .right),
                store:  store
            )
            .frame(width: rightWidth, height: height)
        }
        .frame(width: rightWidth, height: height)
        .clipped()
    }

    private var dotGrid: some View {
        let spacing: CGFloat = 20
        return Canvas { ctx, size in
            let cols = Int(size.width  / spacing)
            let rows = Int(size.height / spacing)
            for row in 0...rows {
                for col in 0...cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let dot = Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                    ctx.fill(dot, with: .color(PlannerTheme.dot))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(PlannerTheme.line)
            .frame(width: 1, height: height)
    }
}
