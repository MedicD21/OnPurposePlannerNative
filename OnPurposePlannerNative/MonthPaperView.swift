import SwiftUI
import PencilKit

struct MonthPaperView: View {
    @ObservedObject var store: PlannerStore

    private var calendarMonth: CalendarMonth {
        generateCalendar(year: store.currentYear, month: store.currentMonth)
    }

    private var paperWidth:  CGFloat { PlannerTheme.leftPaperWidth }
    private var paperHeight: CGFloat { PlannerTheme.spreadHeight }

    // Today's components for highlight
    private let today = Date()
    private let todayCal = Calendar(identifier: .gregorian)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Paper background
            PlannerTheme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .padding(.top, 28)
                    .padding(.horizontal, 28)

                weekdayHeaderRow
                    .padding(.top, 12)
                    .padding(.horizontal, 28)

                calendarGrid
                    .padding(.horizontal, 28)
                    .padding(.top, 4)

                Spacer()
            }
            .frame(width: paperWidth, height: paperHeight)

            // Drawing overlay (pencil-only, transparent)
            DrawingCanvasView(
                pageId: store.pageId(for: .monthWeek, side: .left),
                store:  store
            )
            .frame(width: paperWidth, height: paperHeight)
        }
        .frame(width: paperWidth, height: paperHeight)
        .clipped()
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top) {
            // Large month name + year
            VStack(alignment: .leading, spacing: 0) {
                Text(monthNames[store.currentMonth - 1].uppercased())
                    .font(PlannerTheme.monthNumberFont)
                    .foregroundStyle(PlannerTheme.ink)
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                Text(String(store.currentYear))
                    .font(PlannerTheme.yearFont)
                    .foregroundStyle(PlannerTheme.line)
            }

            Spacer()

            // Mini calendars: next 2 months
            HStack(alignment: .top, spacing: 16) {
                ForEach(1...2, id: \.self) { offset in
                    miniCalendar(offset: offset)
                }
            }
        }
    }

    // MARK: - Mini calendar

    private func miniCalendar(offset: Int) -> some View {
        let (y, m) = shiftMonth(year: store.currentYear, month: store.currentMonth, by: offset)
        let cal    = generateCalendar(year: y, month: m)
        return VStack(spacing: 1) {
            // Month label
            Text(cal.monthName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PlannerTheme.line)

            // Weekday row
            HStack(spacing: 0) {
                ForEach(weekdayInitials, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(PlannerTheme.line)
                        .frame(width: 16)
                }
            }

            // Weeks
            ForEach(cal.weeks) { week in
                HStack(spacing: 0) {
                    ForEach(week.days) { day in
                        Text(String(day.dayNumber))
                            .font(.system(size: 7))
                            .foregroundStyle(day.isInMonth ? PlannerTheme.ink : PlannerTheme.hairline)
                            .frame(width: 16, height: 14)
                            .background(isTodayDay(day) ? PlannerTheme.accent : Color.clear)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Weekday header

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayInitials, id: \.self) { wd in
                Text(wd)
                    .font(PlannerTheme.weekdayFont)
                    .foregroundStyle(PlannerTheme.line)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let cellWidth  = (paperWidth - 56) / 7
        let cellHeight = (paperHeight - 240) / 6

        return VStack(spacing: 0) {
            ForEach(calendarMonth.weeks) { week in
                HStack(spacing: 0) {
                    ForEach(week.days) { day in
                        dayCell(day: day, cellWidth: cellWidth, cellHeight: cellHeight)
                    }
                }
                // Bottom divider for each row
                Rectangle()
                    .fill(PlannerTheme.hairline)
                    .frame(height: 0.5)
            }
        }
    }

    private func dayCell(day: CalendarDay, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let isToday      = isTodayDay(day)
        let dimmed       = !day.isInMonth

        return ZStack(alignment: .topTrailing) {
            // Cell background + right border
            Rectangle()
                .fill(Color.clear)
                .frame(width: cellWidth, height: cellHeight)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(PlannerTheme.hairline)
                        .frame(width: 0.5)
                }

            // Day number
            ZStack {
                if isToday {
                    Circle()
                        .fill(PlannerTheme.accent)
                        .frame(width: 22, height: 22)
                }
                Text(String(day.dayNumber))
                    .font(PlannerTheme.dayNumberFont)
                    .foregroundStyle(
                        isToday ? Color.white :
                        dimmed  ? PlannerTheme.ink.opacity(0.3) :
                                  PlannerTheme.ink
                    )
            }
            .padding(4)
        }
    }

    // MARK: - Helpers

    private func isTodayDay(_ day: CalendarDay) -> Bool {
        guard day.isInMonth else { return false }
        let tc = todayCal.dateComponents([.year, .month, .day], from: today)
        return tc.year == day.year && tc.month == day.month && tc.day == day.dayNumber
    }
}
