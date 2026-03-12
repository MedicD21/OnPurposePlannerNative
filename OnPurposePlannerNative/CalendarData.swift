import Foundation

// MARK: - Models

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let isInMonth: Bool
    let month: Int
    let year: Int
}

struct CalendarWeek: Identifiable {
    let id = UUID()
    let days: [CalendarDay]  // always 7 days, Sunday first
}

struct CalendarMonth {
    let year: Int
    let month: Int
    let monthName: String
    let weeks: [CalendarWeek]  // always 6 weeks
}

// MARK: - Constants

let monthNames: [String] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

let weekdayInitials: [String] = ["S", "M", "T", "W", "T", "F", "S"]

// MARK: - Calendar generation

func generateCalendar(year: Int, month: Int) -> CalendarMonth {
    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 1  // Sunday = 1

    var components = DateComponents()
    components.year  = year
    components.month = month
    components.day   = 1

    guard let firstOfMonth = cal.date(from: components) else {
        return CalendarMonth(year: year, month: month, monthName: monthNames[month - 1], weeks: [])
    }

    // Weekday of first day (0 = Sunday)
    let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1  // 0-based Sunday

    let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)!.count

    // Previous month days to pad
    let (prevYear, prevMonth) = shiftMonth(year: year, month: month, by: -1)
    var prevComponents = DateComponents()
    prevComponents.year  = prevYear
    prevComponents.month = prevMonth
    prevComponents.day   = 1
    let prevFirstOfMonth = cal.date(from: prevComponents)!
    let daysInPrevMonth  = cal.range(of: .day, in: .month, for: prevFirstOfMonth)!.count

    var cells: [CalendarDay] = []

    // Leading days from previous month
    for i in 0..<firstWeekday {
        let dayNum = daysInPrevMonth - firstWeekday + 1 + i
        var dc = DateComponents()
        dc.year  = prevYear
        dc.month = prevMonth
        dc.day   = dayNum
        let d = cal.date(from: dc) ?? Date()
        cells.append(CalendarDay(date: d, dayNumber: dayNum, isInMonth: false, month: prevMonth, year: prevYear))
    }

    // Current month days
    for day in 1...daysInMonth {
        var dc = DateComponents()
        dc.year  = year
        dc.month = month
        dc.day   = day
        let d = cal.date(from: dc) ?? Date()
        cells.append(CalendarDay(date: d, dayNumber: day, isInMonth: true, month: month, year: year))
    }

    // Trailing days from next month
    let (nextYear, nextMonth) = shiftMonth(year: year, month: month, by: 1)
    let totalTarget = 42
    var nextDay = 1
    while cells.count < totalTarget {
        var dc = DateComponents()
        dc.year  = nextYear
        dc.month = nextMonth
        dc.day   = nextDay
        let d = cal.date(from: dc) ?? Date()
        cells.append(CalendarDay(date: d, dayNumber: nextDay, isInMonth: false, month: nextMonth, year: nextYear))
        nextDay += 1
    }

    // Build 6 weeks
    var weeks: [CalendarWeek] = []
    for w in 0..<6 {
        let slice = Array(cells[(w * 7)..<(w * 7 + 7)])
        weeks.append(CalendarWeek(days: slice))
    }

    return CalendarMonth(year: year, month: month, monthName: monthNames[month - 1], weeks: weeks)
}

func shiftMonth(year: Int, month: Int, by delta: Int) -> (year: Int, month: Int) {
    var m = month - 1 + delta  // 0-based
    var y = year
    while m < 0  { m += 12; y -= 1 }
    while m > 11 { m -= 12; y += 1 }
    return (y, m + 1)
}

func formatWeekRange(_ week: CalendarWeek) -> String {
    guard let first = week.days.first, let last = week.days.last else { return "" }
    let startName = monthNames[first.month - 1]
    let endName   = monthNames[last.month  - 1]
    return "\(startName) \(first.dayNumber) – \(endName) \(last.dayNumber)"
}

/// Returns the week index (0-based) within the month that contains the given date.
/// Returns 0 if not found.
func weekIndex(for date: Date, in calendarMonth: CalendarMonth) -> Int {
    let cal = Calendar(identifier: .gregorian)
    let targetDay = cal.component(.day, from: date)
    let targetMonth = cal.component(.month, from: date)
    let targetYear  = cal.component(.year, from: date)
    for (idx, week) in calendarMonth.weeks.enumerated() {
        for day in week.days {
            if day.isInMonth && day.dayNumber == targetDay
                && day.month == targetMonth && day.year == targetYear {
                return idx
            }
        }
    }
    return 0
}
