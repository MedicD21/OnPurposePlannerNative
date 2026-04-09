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
    @State private var showDayEventsSheet = false
    @State private var selectedEventForDetail: SelectedEventDetail?

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

            monthEventOverlay
                .allowsHitTesting(!store.fillModeActive)
        }
        .coordinateSpace(name: "monthPaper")
        .onPreferenceChange(MonthCellFramePreferenceKey.self) { frames in
            monthCellFrames = frames
        }
        .frame(width: paperWidth, height: paperHeight)
        .clipped()
        .sheet(isPresented: $showDayEventsSheet) {
            CalendarEventSheet(events: selectedDayEvents) { selectedEvent in
                selectedEventForDetail = SelectedEventDetail(event: selectedEvent)
            }
        }
        .sheet(item: $selectedEventForDetail) { selectedEvent in
            CalendarEventDetailSheet(event: selectedEvent.event)
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
        .onChange(of: store.showAllCalendars) { _, _ in
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

    /// Visible event pills rendered above the canvas so finger taps hit the
    /// actual controls instead of the drawing surface underneath.
    private var monthEventOverlay: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(calendarMonth.weeks.enumerated()), id: \.offset) { rowIdx, week in
                ForEach(Array(week.days.enumerated()), id: \.offset) { colIdx, day in
                    dayCellEventPills(rowIdx: rowIdx, colIdx: colIdx, day: day)
                }
            }
        }
        .frame(width: paperWidth, height: paperHeight)
    }

    @ViewBuilder
    private func dayCellEventPills(rowIdx: Int, colIdx: Int, day: CalendarDay) -> some View {
        let events = eventsForDay(day)
        let visibleEvents = Array(events.prefix(maxVisibleEventPills))
        let remainingCount = max(0, events.count - visibleEvents.count)
        let position = MonthCellPosition(row: rowIdx, column: colIdx)
        if !events.isEmpty,
           day.isInMonth,
           let frame = monthFillGrid.cellFrame(at: position) {
            let pillAreaWidth = max(0, frame.width - (eventPillSideInset * 2))
            ForEach(Array(visibleEvents.enumerated()), id: \.offset) { index, event in
                let pillY = frame.minY
                    + eventPillTopInset
                    + CGFloat(index) * (eventPillHeight + eventPillSpacing)
                Button {
                    selectedEventForDetail = SelectedEventDetail(event: event)
                } label: {
                    eventPill(event, maxWidth: pillAreaWidth)
                }
                .buttonStyle(.plain)
                .frame(width: pillAreaWidth, height: eventPillHeight)
                .position(
                    x: frame.minX + eventPillSideInset + (pillAreaWidth / 2),
                    y: pillY + (eventPillHeight / 2)
                )
            }
            if remainingCount > 0 {
                let morePillY = frame.minY
                    + eventPillTopInset
                    + CGFloat(visibleEvents.count) * (eventPillHeight + eventPillSpacing)
                Button {
                    selectedDayEvents = events
                    showDayEventsSheet = true
                } label: {
                    moreEventsPill(remainingCount: remainingCount, maxWidth: pillAreaWidth)
                }
                .buttonStyle(.plain)
                .frame(width: pillAreaWidth, height: eventPillHeight)
                .position(
                    x: frame.minX + eventPillSideInset + (pillAreaWidth / 2),
                    y: morePillY + (eventPillHeight / 2)
                )
            }
        }
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
            enabledIDs: store.enabledCalendarIDs,
            showAll: store.showAllCalendars)
        let gc = Calendar(identifier: .gregorian)
        var dict: [String: [EKEvent]] = [:]
        for event in events {
            let startOfDay = gc.startOfDay(for: event.startDate)
            var endOfDay = gc.startOfDay(for: event.endDate)

            // EventKit all-day events use an exclusive end date.
            if event.isAllDay {
                endOfDay = gc.date(byAdding: .day, value: -1, to: endOfDay) ?? endOfDay
            } else if event.endDate > event.startDate,
                      gc.startOfDay(for: event.endDate) == event.endDate {
                // Timed events ending exactly at midnight should not paint the next day.
                endOfDay = gc.date(byAdding: .day, value: -1, to: endOfDay) ?? endOfDay
            }

            var cursor = startOfDay
            while cursor <= endOfDay {
                let c = gc.dateComponents([.year, .month, .day], from: cursor)
                let key = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
                dict[key, default: []].append(event)
                guard let nextDay = gc.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = nextDay
            }
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
    var onSelectEvent: ((EKEvent) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(events, id: \.eventIdentifier) { event in
                    Button {
                        onSelectEvent?(event)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color(cgColor: event.calendar.cgColor))
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title ?? "Untitled")
                                    .font(.body)
                                    .foregroundStyle(PlannerTheme.ink)
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
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
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

private struct SelectedEventDetail: Identifiable {
    let event: EKEvent
    var id: String { event.eventIdentifier ?? UUID().uuidString }
}

struct CalendarEventDetailSheet: View {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    detailRow(title: "Title", value: readableTitle)
                    detailRow(title: "Calendar", value: event.calendar.title)
                    detailRow(title: "When", value: dateTimeText)

                    if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
                        detailRow(title: "Location", value: location)
                    }

                    if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                        detailRow(title: "Notes", value: notes)
                    }

                    if let url = event.url?.absoluteString, !url.isEmpty {
                        detailRow(title: "URL", value: url)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var readableTitle: String {
        let trimmed = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var dateTimeText: String {
        if event.isAllDay {
            return allDayRangeText(event)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }

    private func allDayRangeText(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let calendar = Calendar(identifier: .gregorian)
        let startDate = event.startDate ?? Date()
        let safeEndDate = event.endDate ?? startDate
        let endDate = calendar.date(byAdding: .day, value: -1, to: safeEndDate) ?? safeEndDate

        let startText = formatter.string(from: startDate)
        let endText = formatter.string(from: endDate)

        if startText == endText {
            return "All Day • \(startText)"
        }
        return "All Day • \(startText) – \(endText)"
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .foregroundStyle(PlannerTheme.ink)
                .textSelection(.enabled)
        }
    }
}
