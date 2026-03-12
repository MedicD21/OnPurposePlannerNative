import SwiftUI
import PencilKit

struct WeekPaperView: View {
    @ObservedObject var store: PlannerStore
    var onNavigateToPlanning: (() -> Void)?

    private var calendarMonth: CalendarMonth {
        generateCalendar(year: store.currentYear, month: store.currentMonth)
    }

    private var currentWeek: CalendarWeek? {
        guard store.currentWeekIndex < calendarMonth.weeks.count else { return nil }
        return calendarMonth.weeks[store.currentWeekIndex]
    }

    private var paperWidth:  CGFloat { PlannerTheme.rightPaperWidth }
    private var paperHeight: CGFloat { PlannerTheme.spreadHeight }

    private let today     = Date()
    private let todayCal  = Calendar(identifier: .gregorian)

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlannerTheme.paper

            VStack(alignment: .leading, spacing: 0) {
                // Week range header
                if let week = currentWeek {
                    Text(formatWeekRange(week))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PlannerTheme.ink)
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                }

                // Week tab buttons
                weekTabs
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                // Divider
                Rectangle()
                    .fill(PlannerTheme.line)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Daily sections
                if let week = currentWeek {
                    dailySections(week: week)
                        .padding(.top, 4)
                }

                Spacer()

                // Navigate to planning
                HStack {
                    Spacer()
                    Button {
                        onNavigateToPlanning?()
                        store.activeSpread = .planning
                    } label: {
                        HStack(spacing: 4) {
                            Text("Planning")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(PlannerTheme.accent)
                    }
                    .padding(.bottom, 16)
                    .padding(.trailing, 20)
                }
            }
            .frame(width: paperWidth, height: paperHeight)

            // Drawing overlay
            DrawingCanvasView(
                pageId: store.pageId(for: .monthWeek, side: .right),
                store:  store
            )
            .frame(width: paperWidth, height: paperHeight)
        }
        .frame(width: paperWidth, height: paperHeight)
        .clipped()
    }

    // MARK: - Week tabs

    private var weekTabs: some View {
        HStack(spacing: 4) {
            ForEach(Array(calendarMonth.weeks.enumerated()), id: \.offset) { idx, week in
                let isSelected = idx == store.currentWeekIndex
                let label      = weekTabLabel(week)

                Button {
                    store.navigateToWeek(idx)
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? PlannerTheme.paper : PlannerTheme.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? PlannerTheme.cover : PlannerTheme.tab)
                        )
                }
            }
        }
    }

    private func weekTabLabel(_ week: CalendarWeek) -> String {
        guard let first = week.days.first(where: { $0.isInMonth }) ?? week.days.first else {
            return ""
        }
        return "\(monthNames[first.month - 1]) \(first.dayNumber)"
    }

    // MARK: - Daily sections

    private func dailySections(week: CalendarWeek) -> some View {
        let sectionHeight = (paperHeight - 148) / 7

        return VStack(spacing: 0) {
            ForEach(week.days) { day in
                daySection(day: day, height: sectionHeight)
            }
        }
        .padding(.horizontal, 20)
    }

    private func daySection(day: CalendarDay, height: CGFloat) -> some View {
        let isToday = isTodayDay(day)

        return VStack(spacing: 0) {
            // Day label row
            HStack(alignment: .center, spacing: 6) {
                let abbrev = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
                let wdIdx  = dayWeekdayIndex(day)

                ZStack {
                    if isToday {
                        Circle()
                            .fill(PlannerTheme.accent)
                            .frame(width: 28, height: 28)
                    }
                    VStack(spacing: 0) {
                        Text(abbrev[wdIdx])
                            .font(.system(size: 7, weight: .semibold))
                        Text(String(day.dayNumber))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(isToday ? Color.white : PlannerTheme.ink)
                }
                .frame(width: 32)

                Spacer()
            }
            .frame(height: height * 0.3)

            // Ruled lines
            ruledLines(count: 4, height: height * 0.7)

            // Divider between days
            Rectangle()
                .fill(PlannerTheme.line)
                .frame(height: 0.5)
        }
    }

    private func ruledLines(count: Int, height: CGFloat) -> some View {
        let lineSpacing = height / CGFloat(count + 1)
        return Canvas { ctx, size in
            for i in 1...count {
                let y    = lineSpacing * CGFloat(i)
                let path = Path { p in
                    p.move(to:    CGPoint(x: 0,         y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(PlannerTheme.hairline), lineWidth: 0.5)
            }
        }
        .frame(height: height)
    }

    // MARK: - Helpers

    private func isTodayDay(_ day: CalendarDay) -> Bool {
        let tc = todayCal.dateComponents([.year, .month, .day], from: today)
        return tc.year == day.year && tc.month == day.month && tc.day == day.dayNumber
    }

    private func dayWeekdayIndex(_ day: CalendarDay) -> Int {
        let cal   = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.weekday], from: day.date)
        return (comps.weekday ?? 1) - 1   // 0 = Sunday
    }
}
