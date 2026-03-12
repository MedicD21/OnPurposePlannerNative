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

    // MARK: - Sticky Notes
    @Published var stickyNotes: [StickyNote] = []

    // MARK: - Attachments
    @Published var attachments: [PageAttachment] = []

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

        loadStickyNotes()
        loadAttachments()
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

    // MARK: - Spread-level Page ID (coarser — for sticky notes + attachments)

    var currentSpreadId: String {
        switch activeSpread {
        case .monthWeek: return "y\(currentYear)-month-\(currentMonth)"
        case .planning:  return "y\(currentYear)-month-\(currentMonth)-planning"
        case .notes:     return "y\(currentYear)-month-\(currentMonth)-notes"
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

    func navigateToToday() {
        let today = Date()
        let cal   = Calendar(identifier: .gregorian)
        let year  = cal.component(.year,  from: today)
        let month = cal.component(.month, from: today)
        let calMonth = generateCalendar(year: year, month: month)
        currentYear  = year
        currentMonth = month
        currentWeekIndex = weekIndex(for: today, in: calMonth)
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

    // MARK: - Sticky Notes Persistence

    private var stickyNotesURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("sticky-notes.json")
    }

    func loadStickyNotes() {
        guard let data = try? Data(contentsOf: stickyNotesURL),
              let notes = try? JSONDecoder().decode([StickyNote].self, from: data)
        else { return }
        stickyNotes = notes
    }

    private func saveStickyNotes() {
        guard let data = try? JSONEncoder().encode(stickyNotes) else { return }
        try? data.write(to: stickyNotesURL, options: .atomic)
    }

    func addStickyNote(spreadId: String) {
        let note = StickyNote(pageId: spreadId, x: 100, y: 100)
        stickyNotes.append(note)
        saveStickyNotes()
    }

    func mutateStickyNote(id: UUID, transform: (inout StickyNote) -> Void) {
        guard let idx = stickyNotes.firstIndex(where: { $0.id == id }) else { return }
        transform(&stickyNotes[idx])
        saveStickyNotes()
    }

    func deleteStickyNote(id: UUID) {
        guard let note = stickyNotes.first(where: { $0.id == id }) else { return }
        // Delete the drawing file and cache entry
        let drawingPageId = note.drawingPageId
        drawingsCache.removeValue(forKey: drawingPageId)
        let url = drawingsDirectory.appendingPathComponent("\(drawingPageId).drawing")
        try? FileManager.default.removeItem(at: url)
        stickyNotes.removeAll { $0.id == id }
        saveStickyNotes()
    }

    // MARK: - Attachments Persistence

    private var attachmentsURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("attachments.json")
    }

    func loadAttachments() {
        guard let data = try? Data(contentsOf: attachmentsURL),
              let items = try? JSONDecoder().decode([PageAttachment].self, from: data)
        else { return }
        attachments = items
    }

    private func saveAttachments() {
        guard let data = try? JSONEncoder().encode(attachments) else { return }
        try? data.write(to: attachmentsURL, options: .atomic)
    }

    func addAttachment(_ attachment: PageAttachment) {
        attachments.append(attachment)
        saveAttachments()
    }

    func mutateAttachment(id: UUID, transform: (inout PageAttachment) -> Void) {
        guard let idx = attachments.firstIndex(where: { $0.id == id }) else { return }
        transform(&attachments[idx])
        saveAttachments()
    }

    func deleteAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
        saveAttachments()
    }
}
