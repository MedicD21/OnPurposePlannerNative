import SwiftUI
import PencilKit
import EventKit

struct MonthPaperView: View {
    @ObservedObject var store: PlannerStore

    private var calendarMonth: CalendarMonth {
        generateCalendar(year: store.currentYear, month: store.currentMonth)
    }

    private var paperWidth:  CGFloat { PlannerTheme.leftPaperWidth }
    private var paperHeight: CGFloat { PlannerTheme.spreadHeight }

    // Today's components for highlight
    private let today    = Date()
    private let todayCal = Calendar(identifier: .gregorian)

    // Measured at runtime via PreferenceKey so fill cells align with actual layout
    @State private var gridOriginY: CGFloat = 180

    /// Grid geometry used to clamp paint-bucket fill to individual day cells.
    private var monthFillGrid: MonthFillGrid {
        let cw = (paperWidth - 56) / 7
        let ch = (paperHeight - 240) / 6
        return MonthFillGrid(
            originX: 28,
            originY: gridOriginY,
            cellWidth: cw,
            cellHeight: ch)
    }

    // Calendar events for the displayed month, keyed by "YYYY-MM-DD"
    @State private var monthEvents:      [String: [EKEvent]] = [:]
    @State private var selectedDayEvents: [EKEvent] = []
    @State private var showEventsSheet = false

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
                    // Measure the actual Y of the grid top so fill cells are correct
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: CalendarGridOriginYKey.self,
                                value: geo.frame(in: .named("monthPaper")).minY)
                        }
                    )

                Spacer()
            }
            .frame(width: paperWidth, height: paperHeight)

            // Drawing overlay (pencil-only, transparent)
            DrawingCanvasView(
                pageId:    store.pageId(for: .monthWeek, side: .left),
                store:     store,
                monthGrid: monthFillGrid
            )
            .frame(width: paperWidth, height: paperHeight)

            // Transparent event-dot tap targets sit ABOVE the canvas so they
            // receive finger taps even though the canvas covers the whole page.
            eventTapOverlay
        }
        .coordinateSpace(name: "monthPaper")
        .onPreferenceChange(CalendarGridOriginYKey.self) { y in
            if y > 0 { gridOriginY = y }
        }
        .frame(width: paperWidth, height: paperHeight)
        .clipped()
        .sheet(isPresented: $showEventsSheet) {
            CalendarEventSheet(events: selectedDayEvents)
        }
        // Load calendar events whenever month/year changes
        .task(id: "\(store.currentYear)-\(store.currentMonth)") {
            await loadMonthEvents()
        }
        // Re-load if calendar permissions or enabled IDs change
        .onChange(of: store.calendarManager.authStatus) { _, _ in
            Task { await loadMonthEvents() }
        }
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
            Text(cal.monthName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PlannerTheme.line)

            HStack(spacing: 0) {
                ForEach(weekdayInitials, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(PlannerTheme.line)
                        .frame(width: 16)
                }
            }

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
                Rectangle()
                    .fill(PlannerTheme.hairline)
                    .frame(height: 0.5)
            }
        }
    }

    private func dayCell(day: CalendarDay, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        let isToday = isTodayDay(day)
        let dimmed  = !day.isInMonth
        let events  = eventsForDay(day)

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
        // Event dots at the bottom of the cell
        .overlay(alignment: .bottom) {
            if !events.isEmpty && day.isInMonth {
                HStack(spacing: 3) {
                    ForEach(events.prefix(3), id: \.eventIdentifier) { event in
                        Circle()
                            .fill(Color(cgColor: event.calendar.cgColor))
                            .frame(width: 5, height: 5)
                    }
                    if events.count > 3 {
                        Circle()
                            .fill(PlannerTheme.line)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Event tap overlay

    /// A fully transparent layer above the canvas with invisible buttons
    /// positioned over each day's event-dot area.
    private var eventTapOverlay: some View {
        let cw = monthFillGrid.cellWidth
        let ch = monthFillGrid.cellHeight
        let ox = monthFillGrid.originX
        let oy = gridOriginY
        let dotAreaHeight: CGFloat = 20

        return ZStack(alignment: .topLeading) {
            ForEach(Array(calendarMonth.weeks.enumerated()), id: \.offset) { rowIdx, week in
                ForEach(Array(week.days.enumerated()), id: \.element.id) { colIdx, day in
                    let events = eventsForDay(day)
                    if !events.isEmpty && day.isInMonth {
                        Button {
                            selectedDayEvents = events
                            showEventsSheet   = true
                        } label: {
                            Color.clear
                        }
                        .frame(width: cw, height: dotAreaHeight)
                        .offset(
                            x: ox + CGFloat(colIdx) * cw,
                            y: oy + CGFloat(rowIdx) * ch + ch - dotAreaHeight)
                    }
                }
            }
        }
        .frame(width: paperWidth, height: paperHeight)
    }

    // MARK: - Helpers

    private func isTodayDay(_ day: CalendarDay) -> Bool {
        guard day.isInMonth else { return false }
        let tc = todayCal.dateComponents([.year, .month, .day], from: today)
        return tc.year == day.year && tc.month == day.month && tc.day == day.dayNumber
    }

    private func eventsForDay(_ day: CalendarDay) -> [EKEvent] {
        guard day.isInMonth else { return [] }
        let key = String(format: "%04d-%02d-%02d", day.year, day.month, day.dayNumber)
        return monthEvents[key] ?? []
    }

    private func loadMonthEvents() async {
        guard store.calendarManager.isAuthorized else { return }
        let events = store.calendarManager.events(
            for: store.currentYear,
            month: store.currentMonth,
            enabledIDs: store.enabledCalendarIDs)
        let gc = Calendar(identifier: .gregorian)
        var dict: [String: [EKEvent]] = [:]
        for event in events {
            let c = gc.dateComponents([.year, .month, .day], from: event.startDate)
            let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            dict[key, default: []].append(event)
        }
        monthEvents = dict
    }
}

// MARK: - PreferenceKey for grid origin measurement

private struct CalendarGridOriginYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Event detail sheet

struct CalendarEventSheet: View {
    let events: [EKEvent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(events, id: \.eventIdentifier) { event in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color(cgColor: event.calendar.cgColor))
                            .frame(width: 10, height: 10)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title ?? "Untitled")
                                .font(.body)
                            if event.isAllDay {
                                Text("All Day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(timeRange(event))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(event.calendar.title)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func timeRange(_ event: EKEvent) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }
}
