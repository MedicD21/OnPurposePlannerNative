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

@MainActor
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

    // MARK: - Tab Markers
    @Published var tabMarkers: [TabMarker] = []

    // MARK: - Attachments
    @Published var attachments: [PageAttachment] = []

    // MARK: - Calendar
    let calendarManager = EventKitManager()
    @Published var enabledCalendarIDs: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") ?? []
        return Set(saved)
    }() {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs")
        }
    }

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
        loadTabMarkers()
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
        // Stagger placement so consecutive notes don't stack on top of each other
        let offset = CGFloat(stickyNotes.filter { $0.pageId == spreadId }.count) * 30
        let x = min(120 + offset, PlannerTheme.spreadWidth  - StickyNote.defaultSize.width  - 40)
        let y = min(120 + offset, PlannerTheme.spreadHeight - StickyNote.defaultSize.height - 40)
        let note = StickyNote(pageId: spreadId, x: x, y: y)
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

    // MARK: - Tab Markers Persistence

    private var tabMarkersURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("tab-markers.json")
    }

    func loadTabMarkers() {
        guard let data = try? Data(contentsOf: tabMarkersURL),
              let items = try? JSONDecoder().decode([TabMarker].self, from: data)
        else { return }
        tabMarkers = items
    }

    private func saveTabMarkers() {
        guard let data = try? JSONEncoder().encode(tabMarkers) else { return }
        try? data.write(to: tabMarkersURL, options: .atomic)
    }

    func addTabMarker(spreadId: String) {
        let count  = tabMarkers.filter { $0.pageId == spreadId }.count
        let offset = CGFloat(count) * 28
        let x = min(200 + offset, PlannerTheme.spreadWidth  - TabMarker.width  - 20)
        let y = min(200 + offset, PlannerTheme.spreadHeight - TabMarker.height - 20)
        let colors = TabColor.allCases
        let color  = colors[count % colors.count]
        let marker = TabMarker(pageId: spreadId, x: x, y: y, colorKey: color)
        tabMarkers.append(marker)
        saveTabMarkers()
    }

    func mutateTabMarker(id: UUID, transform: (inout TabMarker) -> Void) {
        guard let idx = tabMarkers.firstIndex(where: { $0.id == id }) else { return }
        transform(&tabMarkers[idx])
        saveTabMarkers()
    }

    func deleteTabMarker(id: UUID) {
        guard let marker = tabMarkers.first(where: { $0.id == id }) else { return }
        let pid = marker.drawingPageId
        drawingsCache.removeValue(forKey: pid)
        let url = drawingsDirectory.appendingPathComponent("\(pid).drawing")
        try? FileManager.default.removeItem(at: url)
        tabMarkers.removeAll { $0.id == id }
        saveTabMarkers()
    }

    // MARK: - Fill Mode

    @Published var fillModeActive = false

    // MARK: - Fill Image Persistence

    private var fillImagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("fills", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func fillImage(forPageId pageId: String) -> UIImage? {
        let url = fillImagesDirectory.appendingPathComponent("\(pageId).png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func saveFillImage(_ image: UIImage, forPageId pageId: String) {
        let url = fillImagesDirectory.appendingPathComponent("\(pageId).png")
        if let data = image.pngData() {
            try? data.write(to: url, options: .atomic)
        }
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

    // MARK: - Export / Import

    struct PlannerExportData: Codable {
        var exportDate: Date
        var stickyNotes: [StickyNote]
        var tabMarkers:  [TabMarker]
        var attachments: [PageAttachment]
        var drawings: [String: Data]   // pageId → PKDrawing.dataRepresentation()
        var fills: [String: Data]?     // pageId → fill image PNG (optional for backwards compat)
    }

    func exportAllData() throws -> URL {
        // Gather all drawing files from the drawings directory
        var drawingMap: [String: Data] = [:]
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: drawingsDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "drawing" {
                let key = file.deletingPathExtension().lastPathComponent
                if let data = try? Data(contentsOf: file) {
                    drawingMap[key] = data
                }
            }
        }

        // Gather fill images
        var fillMap: [String: Data] = [:]
        if let fills = try? fm.contentsOfDirectory(at: fillImagesDirectory, includingPropertiesForKeys: nil) {
            for file in fills where file.pathExtension == "png" {
                let key = file.deletingPathExtension().lastPathComponent
                if let data = try? Data(contentsOf: file) {
                    fillMap[key] = data
                }
            }
        }

        let export = PlannerExportData(
            exportDate: Date(),
            stickyNotes: stickyNotes,
            tabMarkers:  tabMarkers,
            attachments: attachments,
            drawings: drawingMap,
            fills: fillMap
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url  = docs.appendingPathComponent("OnPurposePlanner-export.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func importAllData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(PlannerExportData.self, from: data)

        // Restore drawings
        let fm = FileManager.default
        try? fm.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        for (pageId, drawingData) in export.drawings {
            let url = drawingsDirectory.appendingPathComponent("\(pageId).drawing")
            try? drawingData.write(to: url, options: .atomic)
        }
        drawingsCache.removeAll()

        // Restore fill images
        if let fills = export.fills {
            try? fm.createDirectory(at: fillImagesDirectory, withIntermediateDirectories: true)
            for (pageId, fillData) in fills {
                let url = fillImagesDirectory.appendingPathComponent("\(pageId).png")
                try? fillData.write(to: url, options: .atomic)
            }
        }

        // Restore sticky notes, tab markers, and attachments
        stickyNotes = export.stickyNotes
        saveStickyNotes()
        tabMarkers = export.tabMarkers
        saveTabMarkers()
        attachments = export.attachments
        saveAttachments()
    }
}
