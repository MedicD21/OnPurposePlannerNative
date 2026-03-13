import SwiftUI
import PencilKit
import EventKit

struct MonthPaperView: View {
    @ObservedObject var store: PlannerStore

    private let maxVisibleEventPills = 2
    private let eventPillTopInset: CGFloat = 30
    private let eventPillSideInset: CGFloat = 4
    private let eventPillHeight: CGFloat = 16
    private let eventPillSpacing: CGFloat = 3

    private var calendarMonth: CalendarMonth {
        generateCalendar(year: store.currentYear, month: store.currentMonth)
    }

    private var paperWidth:  CGFloat { PlannerTheme.leftPaperWidth }
    private var paperHeight: CGFloat { PlannerTheme.spreadHeight }
    private var monthPageId: String { store.pageId(for: .monthWeek, side: .left) }

    // Today's components for highlight
    private let today    = Date()
    private let todayCal = Calendar(identifier: .gregorian)

    // Measured at runtime from the actual laid-out day cells.
    @State private var monthCellFrames: [MonthCellPosition: CGRect] = [:]

    private var monthFillGrid: MonthFillGrid {
        MonthFillGrid(cellFrames: monthCellFrames)
    }

    // Calendar events for the displayed month, keyed by "YYYY-MM-DD"
    @State private var monthEvents:      [String: [EKEvent]] = [:]
    @State private var selectedDayEvents: [EKEvent] = []
    @State private var showEventsSheet = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Paper background
            PlannerTheme.paper.ignoresSafeArea()

            monthFillUnderlay

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
                pageId:    store.pageId(for: .monthWeek, side: .left),
                store:     store,
                monthGrid: monthFillGrid
            )
            .frame(width: paperWidth, height: paperHeight)

            // Invisible hit targets sit above the canvas so the visible pills,
            // which are laid out inside each day cell, remain tappable.
            eventTapOverlay
                .allowsHitTesting(!store.fillModeActive)
        }
        .coordinateSpace(name: "monthPaper")
        .onPreferenceChange(MonthCellFramePreferenceKey.self) { frames in
            monthCellFrames = frames
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
        .onChange(of: store.enabledCalendarIDs) { _, _ in
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
                ForEach(weekdayInitials.indices, id: \.self) { i in
                    Text(weekdayInitials[i])
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
            ForEach(weekdayInitials.indices, id: \.self) { i in
                Text(weekdayInitials[i])
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
            ForEach(Array(calendarMonth.weeks.enumerated()), id: \.offset) { row, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.days.enumerated()), id: \.offset) { column, day in
                        dayCell(
                            day: day,
                            row: row,
                            column: column,
                            cellWidth: cellWidth,
                            cellHeight: cellHeight
                        )
                    }
                }
                Rectangle()
                    .fill(PlannerTheme.hairline)
                    .frame(height: 0.5)
            }
        }
    }

    private func dayCell(
        day: CalendarDay,
        row: Int,
        column: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
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
        .overlay(alignment: .topLeading) {
            if !events.isEmpty && day.isInMonth {
                dayEventPills(events, maxWidth: cellWidth - (eventPillSideInset * 2))
                    .padding(.top, eventPillTopInset)
                    .padding(.leading, eventPillSideInset)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MonthCellFramePreferenceKey.self,
                    value: [
                        MonthCellPosition(row: row, column: column): geo.frame(in: .named("monthPaper"))
                    ]
                )
            }
        )
    }

    // MARK: - Event tap overlay

    /// A transparent layer above the canvas with tappable hit targets for the
    /// event pill area in each day cell.
    private var eventTapOverlay: some View {
        let pillAreaHeight = (eventPillHeight * 3) + (eventPillSpacing * 2)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(calendarMonth.weeks.enumerated()), id: \.offset) { rowIdx, week in
                ForEach(Array(week.days.enumerated()), id: \.offset) { colIdx, day in
                    let events = eventsForDay(day)
                    let position = MonthCellPosition(row: rowIdx, column: colIdx)
                    if !events.isEmpty,
                       day.isInMonth,
                       let frame = monthFillGrid.cellFrame(at: position) {
                        let pillAreaWidth = max(0, frame.width - (eventPillSideInset * 2))
                        Button {
                            selectedDayEvents = events
                            showEventsSheet   = true
                        } label: {
                            Color.clear
                        }
                        .buttonStyle(.plain)
                        .frame(width: pillAreaWidth, height: pillAreaHeight, alignment: .topLeading)
                        .offset(
                            x: frame.minX + eventPillSideInset,
                            y: frame.minY + eventPillTopInset)
                    }
                }
            }
        }
        .frame(width: paperWidth, height: paperHeight)
    }

    private var monthFillUnderlay: some View {
        let _ = store.fillRefreshTick

        return Group {
            if let image = store.fillImage(forPageId: monthPageId) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: paperWidth, height: paperHeight)
            }
        }
        .frame(width: paperWidth, height: paperHeight)
        .allowsHitTesting(false)
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

    private func dayEventPills(_ events: [EKEvent], maxWidth: CGFloat) -> some View {
        let visibleEvents = Array(events.prefix(maxVisibleEventPills))
        let remainingCount = max(0, events.count - visibleEvents.count)

        return VStack(alignment: .leading, spacing: eventPillSpacing) {
            ForEach(visibleEvents, id: \.eventIdentifier) { event in
                eventPill(event, maxWidth: maxWidth)
            }

            if remainingCount > 0 {
                moreEventsPill(remainingCount: remainingCount, maxWidth: maxWidth)
            }
        }
        .frame(maxWidth: maxWidth, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func eventPill(_ event: EKEvent, maxWidth: CGFloat) -> some View {
        let color = Color(cgColor: event.calendar.cgColor)

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(eventTitle(event))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PlannerTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: maxWidth, minHeight: eventPillHeight, alignment: .leading)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay {
            Capsule()
                .stroke(color.opacity(0.35), lineWidth: 0.5)
        }
    }

    private func moreEventsPill(remainingCount: Int, maxWidth: CGFloat) -> some View {
        Text("+\(remainingCount) more")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(PlannerTheme.line)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .frame(maxWidth: maxWidth, minHeight: eventPillHeight, alignment: .leading)
            .background(
                Capsule()
                    .fill(PlannerTheme.tab)
            )
            .overlay {
                Capsule()
                    .stroke(PlannerTheme.hairline, lineWidth: 0.5)
            }
    }

    private func eventTitle(_ event: EKEvent) -> String {
        let trimmed = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func sortEvents(_ events: [EKEvent]) -> [EKEvent] {
        events.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay {
                return lhs.isAllDay && !rhs.isAllDay
            }
            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }
            return eventTitle(lhs).localizedCaseInsensitiveCompare(eventTitle(rhs)) == .orderedAscending
        }
    }

    private func loadMonthEvents() async {
        guard store.calendarManager.isAuthorized else {
            monthEvents = [:]
            return
        }

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
        monthEvents = dict.mapValues(sortEvents)
    }
}

// MARK: - PreferenceKeys

private struct MonthCellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [MonthCellPosition: CGRect] = [:]

    static func reduce(
        value: inout [MonthCellPosition: CGRect],
        nextValue: () -> [MonthCellPosition: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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
