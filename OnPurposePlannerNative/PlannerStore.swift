import SwiftUI
import PencilKit

enum SpreadType: String, CaseIterable {
    case monthWeek = "Month / Week"
    case planning  = "Planning"
    case notes     = "Notes"
}

enum PaperSide: String {
    case left  = "left"
    case right = "right"
}

class PlannerStore: ObservableObject {
    @Published var currentYear:      Int
    @Published var currentMonth:     Int
    @Published var currentWeekIndex: Int
    @Published var activeSpread:     SpreadType

    // Shared PKToolPicker — one instance for the whole app.
    // Each PKCanvasView registers as an observer; the picker appears whenever
    // any registered canvas is first responder.  This gives the user Apple's
    // native tool UI with ALL built-in tools:
    //   • Pen, pencil, marker, monoline, fountain pen, watercolor, crayon
    //   • Eraser (pixel and object modes)
    //   • Lasso (select / move / resize / delete strokes)
    //   • Ruler
    //   • Full colour picker with opacity
    //   • Stroke-width slider
    //   • Tool favourites
    //   • Built-in undo / redo
    let toolPicker = PKToolPicker()

    // MARK: - Init

    init() {
        let today = Date()
        let cal   = Calendar(identifier: .gregorian)
        let year  = cal.component(.year,  from: today)
        let month = cal.component(.month, from: today)

        self.currentYear  = year
        self.currentMonth = month

        let calMonth = generateCalendar(year: year, month: month)
        self.currentWeekIndex = weekIndex(for: today, in: calMonth)

        self.activeSpread = .monthWeek

        // Start with the pen selected.
        toolPicker.selectedTool = PKInkingTool(
            .pen,
            color: UIColor(PlannerTheme.defaultPalette[0]),
            width: 2.0
        )
    }

    // MARK: - Page ID Scheme

    func pageId(for spread: SpreadType, side: PaperSide) -> String {
        switch spread {
        case .monthWeek:
            return side == .left
                ? "y\(currentYear)-month-\(currentMonth)-left"
                : "y\(currentYear)-month-\(currentMonth)-week-\(currentWeekIndex)"
        case .planning:
            return "y\(currentYear)-month-\(currentMonth)-planning-\(side.rawValue)"
        case .notes:
            return "y\(currentYear)-month-\(currentMonth)-notes-\(side.rawValue)"
        }
    }

    // MARK: - Drawing Persistence

    private var drawingsCache: [String: PKDrawing] = [:]

    private var drawingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("drawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func drawing(forPageId pageId: String) -> PKDrawing {
        if let cached = drawingsCache[pageId] { return cached }
        let url = drawingsDirectory.appendingPathComponent("\(pageId).drawing")
        if let data    = try? Data(contentsOf: url),
           let drawing = try? PKDrawing(data: data) {
            drawingsCache[pageId] = drawing
            return drawing
        }
        return PKDrawing()
    }

    func saveDrawing(_ drawing: PKDrawing, forPageId pageId: String) {
        drawingsCache[pageId] = drawing
        let url  = drawingsDirectory.appendingPathComponent("\(pageId).drawing")
        let data = drawing.dataRepresentation()
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Navigation

    func navigateToWeek(_ index: Int) {
        let cal     = generateCalendar(year: currentYear, month: currentMonth)
        currentWeekIndex = max(0, min(index, cal.weeks.count - 1))
    }

    func navigateToMonth(_ month: Int, year: Int) {
        currentYear  = year
        currentMonth = month
        currentWeekIndex = 0
    }

    func goToPreviousWeek() {
        let cal = generateCalendar(year: currentYear, month: currentMonth)
        if currentWeekIndex > 0 {
            currentWeekIndex -= 1
        } else {
            let (y, m) = shiftMonth(year: currentYear, month: currentMonth, by: -1)
            currentYear  = y
            currentMonth = m
            let prevCal  = generateCalendar(year: y, month: m)
            currentWeekIndex = prevCal.weeks.count - 1
        }
    }

    func goToNextWeek() {
        let cal = generateCalendar(year: currentYear, month: currentMonth)
        if currentWeekIndex < cal.weeks.count - 1 {
            currentWeekIndex += 1
        } else {
            let (y, m) = shiftMonth(year: currentYear, month: currentMonth, by: 1)
            currentYear  = y
            currentMonth = m
            currentWeekIndex = 0
        }
    }

    func goToPreviousMonth() {
        let (y, m) = shiftMonth(year: currentYear, month: currentMonth, by: -1)
        navigateToMonth(m, year: y)
    }

    func goToNextMonth() {
        let (y, m) = shiftMonth(year: currentYear, month: currentMonth, by: 1)
        navigateToMonth(m, year: y)
    }
}
