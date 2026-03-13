import SwiftUI
import UIKit

// MARK: - Two-finger swipe gesture recognizer

final class TwoFingerSwipeGestureRecognizer: UIGestureRecognizer {
    enum Direction { case left, right, up, down }
    var recognizedDirection: Direction?
    private var startLocations: [UITouch: CGPoint] = [:]
    private let minimumDistance: CGFloat = 50

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            startLocations[touch] = touch.location(in: view)
        }
        if (event.allTouches?.count ?? 0) > 2 {
            state = .failed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let allTouches = event.allTouches, allTouches.count == 2 else {
            state = .failed
            return
        }
        guard state != .failed else { return }

        let touchArray = Array(allTouches)
        guard
            let start0 = startLocations[touchArray[0]],
            let start1 = startLocations[touchArray[1]]
        else { return }

        let current0 = touchArray[0].location(in: view)
        let current1 = touchArray[1].location(in: view)

        let dx0 = current0.x - start0.x
        let dy0 = current0.y - start0.y
        let dx1 = current1.x - start1.x
        let dy1 = current1.y - start1.y

        // Both fingers must move in the same general direction
        let avgDx = (dx0 + dx1) / 2
        let avgDy = (dy0 + dy1) / 2

        let totalDist = sqrt(avgDx * avgDx + avgDy * avgDy)
        guard totalDist >= minimumDistance else { return }

        // Dominant axis
        if abs(avgDx) > abs(avgDy) {
            recognizedDirection = avgDx < 0 ? .left : .right
        } else {
            recognizedDirection = avgDy < 0 ? .up : .down
        }
        state = .recognized
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        startLocations.removeAll()
        if state == .possible { state = .failed }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        startLocations.removeAll()
        state = .cancelled
    }

    override func reset() {
        super.reset()
        recognizedDirection = nil
        startLocations.removeAll()
    }
}

// MARK: - Spread Container

struct PlannerSpreadContainerView: UIViewRepresentable {
    @ObservedObject var store: PlannerStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale               = 0.25
        scrollView.maximumZoomScale               = 4.0
        scrollView.bouncesZoom                    = true
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor                = UIColor(PlannerTheme.paper)
        scrollView.delegate                       = context.coordinator

        // Host the spread content
        let spreadView   = SpreadHostView(store: store)
        let hc           = UIHostingController(rootView: spreadView)
        hc.view.backgroundColor               = UIColor(PlannerTheme.paper)
        hc.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hc.view)
        NSLayoutConstraint.activate([
            hc.view.widthAnchor.constraint(equalToConstant:   PlannerTheme.spreadWidth),
            hc.view.heightAnchor.constraint(equalToConstant:  PlannerTheme.spreadHeight),
            hc.view.topAnchor.constraint(equalTo:     scrollView.contentLayoutGuide.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hc.view.bottomAnchor.constraint(equalTo:  scrollView.contentLayoutGuide.bottomAnchor),
            hc.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor)
        ])

        context.coordinator.hostingController = hc
        context.coordinator.scrollView        = scrollView

        // Border + shadow around the spread content
        hc.view.layer.borderColor   = UIColor(PlannerTheme.hairline).cgColor
        hc.view.layer.borderWidth   = 1.5
        hc.view.layer.shadowColor   = UIColor.black.cgColor
        hc.view.layer.shadowOpacity = 0.14
        hc.view.layer.shadowRadius  = 20
        hc.view.layer.shadowOffset  = CGSize(width: 0, height: 6)

        // Fit-to-screen initial zoom
        DispatchQueue.main.async {
            let scaleX = scrollView.bounds.width  / PlannerTheme.spreadWidth
            let scaleY = scrollView.bounds.height / PlannerTheme.spreadHeight
            let scale  = min(scaleX, scaleY)
            scrollView.minimumZoomScale = scale * 0.5
            scrollView.setZoomScale(scale, animated: false)
            context.coordinator.centerContent(scrollView)
        }

        // Two-finger swipe recognizer (custom, for same-direction swipe navigation)
        let swipe = TwoFingerSwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerSwipe(_:)))
        swipe.delegate = context.coordinator
        scrollView.addGestureRecognizer(swipe)

        // Two-finger pan: vertical on month paper → months, horizontal on week paper → weeks
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator
        scrollView.addGestureRecognizer(pan)
        context.coordinator.navPanRecognizer = pan

        // One-finger pan exclusively for note-header dragging.
        // scrollView.panGestureRecognizer requires this to fail first so the
        // scroll pan only starts when the touch is NOT on a sticky-note header.
        let noteDrag = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleNoteDrag(_:)))
        noteDrag.minimumNumberOfTouches = 1
        noteDrag.maximumNumberOfTouches = 1
        noteDrag.delegate = context.coordinator
        scrollView.addGestureRecognizer(noteDrag)
        context.coordinator.noteDragRecognizer = noteDrag
        scrollView.panGestureRecognizer.require(toFail: noteDrag)

        // One-finger pan for tab marker dragging.
        let tabDrag = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTabDrag(_:)))
        tabDrag.minimumNumberOfTouches = 1
        tabDrag.maximumNumberOfTouches = 1
        tabDrag.delegate = context.coordinator
        scrollView.addGestureRecognizer(tabDrag)
        context.coordinator.tabDragRecognizer = tabDrag
        scrollView.panGestureRecognizer.require(toFail: tabDrag)

        // One-finger pan for attachment move + resize (same pattern as noteDrag).
        let attachmentDrag = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleAttachmentGesture(_:)))
        attachmentDrag.minimumNumberOfTouches = 1
        attachmentDrag.maximumNumberOfTouches = 1
        attachmentDrag.delegate = context.coordinator
        scrollView.addGestureRecognizer(attachmentDrag)
        context.coordinator.attachmentRecognizer = attachmentDrag
        scrollView.panGestureRecognizer.require(toFail: attachmentDrag)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = SpreadHostView(store: store)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var store: PlannerStore
        weak var scrollView:        UIScrollView?
        var hostingController:      UIHostingController<SpreadHostView>?
        weak var navPanRecognizer:   UIPanGestureRecognizer?   // 2-finger nav pan
        weak var noteDragRecognizer: UIPanGestureRecognizer?  // 1-finger note drag
        weak var tabDragRecognizer:    UIPanGestureRecognizer? // 1-finger tab marker drag
        weak var attachmentRecognizer: UIPanGestureRecognizer? // 1-finger attachment move/resize

        // Note drag state
        private var draggingNoteId:      UUID?
        private var noteDragStartLoc:    CGPoint = .zero
        private var noteDragStartOrigin: CGPoint = .zero

        // Tab drag state
        private var draggingTabId:      UUID?
        private var tabDragStartLoc:    CGPoint = .zero
        private var tabDragStartOrigin: CGPoint = .zero

        // Attachment drag/resize state
        private var draggingAttachmentId: UUID?
        private var isResizingAttachment: Bool   = false
        private var attachStartLoc:       CGPoint = .zero
        private var attachStartOrigin:    CGPoint = .zero
        private var attachStartSize:      CGSize  = .zero
        private let resizeHandleSize:     CGFloat = 44

        // Nav pan state
        private var navPanStartLoc: CGPoint = .zero

        init(store: PlannerStore) { self.store = store }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { hostingController?.view }

        func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent(scrollView) }

        func centerContent(_ scrollView: UIScrollView) {
            guard let content = hostingController?.view else { return }
            let offsetX = max((scrollView.bounds.width  - content.frame.width)  * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - content.frame.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }

        // MARK: - Two-finger pan navigation (left/right paper zones)

        @objc func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView  = scrollView,
                  let contentView = hostingController?.view else { return }
            switch recognizer.state {
            case .began:
                navPanStartLoc = recognizer.location(in: scrollView)
            case .ended, .cancelled:
                let end = recognizer.location(in: scrollView)
                let dx  = end.x - navPanStartLoc.x
                let dy  = end.y - navPanStartLoc.y
                guard sqrt(dx*dx + dy*dy) > 60 else { return }
                let contentStart = scrollView.convert(navPanStartLoc, to: contentView)
                let isLeftPaper  = contentStart.x < PlannerTheme.leftPaperWidth
                DispatchQueue.main.async {
                    if isLeftPaper {
                        guard abs(dy) > abs(dx) else { return }
                        if dy < 0 { self.store.goToNextMonth() }
                        else      { self.store.goToPreviousMonth() }
                    } else {
                        guard abs(dx) > abs(dy),
                              self.store.activeSpread == .monthWeek else { return }
                        if dx < 0 { self.store.goToNextWeek() }
                        else      { self.store.goToPreviousWeek() }
                    }
                }
            default: break
            }
        }

        // MARK: - Two-finger same-direction swipe (TwoFingerSwipeGestureRecognizer)

        @objc func handleTwoFingerSwipe(_ recognizer: TwoFingerSwipeGestureRecognizer) {
            guard recognizer.state == .recognized else { return }
            DispatchQueue.main.async {
                switch recognizer.recognizedDirection {
                case .left:  if self.store.activeSpread == .monthWeek { self.store.goToNextWeek() }
                case .right: if self.store.activeSpread == .monthWeek { self.store.goToPreviousWeek() }
                case .up:    self.store.goToNextMonth()
                case .down:  self.store.goToPreviousMonth()
                case .none:  break
                }
            }
        }

        // MARK: - Note header drag (UIKit-level so it beats the scroll-view pan)

        @objc func handleNoteDrag(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView  = scrollView,
                  let contentView = hostingController?.view else { return }

            switch recognizer.state {
            case .began:
                let loc = scrollView.convert(recognizer.location(in: scrollView), to: contentView)
                for note in store.stickyNotes where note.pageId == store.currentSpreadId {
                    let headerRect = CGRect(x: note.x, y: note.y,
                                           width: note.displayWidth, height: StickyNote.headerHeight)
                    if headerRect.contains(loc) {
                        draggingNoteId    = note.id
                        noteDragStartLoc    = loc
                        noteDragStartOrigin = CGPoint(x: note.x, y: note.y)
                        break
                    }
                }
                // If not on a header the recognizer should have been blocked by shouldBegin,
                // but guard defensively anyway.
                if draggingNoteId == nil { recognizer.state = .cancelled }

            case .changed:
                guard let id = draggingNoteId else { return }
                let loc = scrollView.convert(recognizer.location(in: scrollView), to: contentView)
                let dx  = loc.x - noteDragStartLoc.x
                let dy  = loc.y - noteDragStartLoc.y
                store.mutateStickyNote(id: id) {
                    $0.x = self.noteDragStartOrigin.x + dx
                    $0.y = self.noteDragStartOrigin.y + dy
                }

            case .ended, .cancelled, .failed:
                draggingNoteId = nil

            default: break
            }
        }

        // MARK: - Tab marker drag

        @objc func handleTabDrag(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView  = scrollView,
                  let contentView = hostingController?.view else { return }

            switch recognizer.state {
            case .began:
                let loc = scrollView.convert(recognizer.location(in: scrollView), to: contentView)
                for tab in store.tabMarkers where tab.pageId == store.currentSpreadId {
                    let frame = CGRect(x: tab.x, y: tab.y, width: TabMarker.width, height: TabMarker.height)
                    if frame.contains(loc) {
                        draggingTabId      = tab.id
                        tabDragStartLoc    = loc
                        tabDragStartOrigin = CGPoint(x: tab.x, y: tab.y)
                        break
                    }
                }
                if draggingTabId == nil { recognizer.state = .cancelled }

            case .changed:
                guard let id = draggingTabId else { return }
                let loc = scrollView.convert(recognizer.location(in: scrollView), to: contentView)
                let dx  = loc.x - tabDragStartLoc.x
                let dy  = loc.y - tabDragStartLoc.y
                store.mutateTabMarker(id: id) {
                    $0.x = self.tabDragStartOrigin.x + dx
                    $0.y = self.tabDragStartOrigin.y + dy
                }

            case .ended, .cancelled, .failed:
                draggingTabId = nil

            default: break
            }
        }

        // MARK: - Attachment move / resize (UIKit-level so it beats the scroll-view pan)

        @objc func handleAttachmentGesture(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView  = scrollView,
                  let contentView = hostingController?.view else { return }

            switch recognizer.state {
            case .began:
                let loc = scrollView.convert(recognizer.location(in: scrollView), to: contentView)
                for att in store.attachments where att.pageId == store.currentSpreadId {
                    let frame = CGRect(x: att.x, y: att.y, width: att.width, height: att.height)
                    guard frame.contains(loc) else { continue }
                    draggingAttachmentId = att.id
                    attachStartLoc    = loc
                    attachStartOrigin = CGPoint(x: att.x, y: att.y)
                    attachStartSize   = CGSize(width: att.width, height: att.height)
                    let resizeRect = CGRect(
                        x: att.x + att.width  - resizeHandleSize,
                        y: att.y + att.height - resizeHandleSize,
                        width: resizeHandleSize, height: resizeHandleSize)
                    isResizingAttachment = resizeRect.contains(loc)
                    break
                }
                if draggingAttachmentId == nil { recognizer.state = .cancelled }

            case .changed:
                guard let id = draggingAttachmentId else { return }
                let loc = scrollView.convert(recognizer.location(in: scrollView), to: contentView)
                let dx  = loc.x - attachStartLoc.x
                let dy  = loc.y - attachStartLoc.y
                if isResizingAttachment {
                    store.mutateAttachment(id: id) {
                        $0.width  = max(80, self.attachStartSize.width  + dx)
                        $0.height = max(80, self.attachStartSize.height + dy)
                    }
                } else {
                    store.mutateAttachment(id: id) {
                        $0.x = self.attachStartOrigin.x + dx
                        $0.y = self.attachStartOrigin.y + dy
                    }
                }

            case .ended, .cancelled, .failed:
                draggingAttachmentId = nil
                isResizingAttachment = false

            default: break
            }
        }

        // MARK: - UIGestureRecognizerDelegate

        /// Block custom recognizers from starting unless the touch lands on their target area.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let scrollView  = scrollView,
                  let contentView = hostingController?.view else { return true }

            let loc = scrollView.convert(gestureRecognizer.location(in: scrollView), to: contentView)

            if gestureRecognizer === noteDragRecognizer {
                return store.stickyNotes
                    .filter { $0.pageId == store.currentSpreadId }
                    .contains { note in
                        CGRect(x: note.x, y: note.y,
                               width: note.displayWidth, height: StickyNote.headerHeight)
                            .contains(loc)
                    }
            }

            if gestureRecognizer === tabDragRecognizer {
                return store.tabMarkers
                    .filter { $0.pageId == store.currentSpreadId }
                    .contains { tab in
                        CGRect(x: tab.x, y: tab.y, width: TabMarker.width, height: TabMarker.height)
                            .contains(loc)
                    }
            }

            if gestureRecognizer === attachmentRecognizer {
                return store.attachments
                    .filter { $0.pageId == store.currentSpreadId }
                    .contains { att in
                        CGRect(x: att.x, y: att.y, width: att.width, height: att.height)
                            .contains(loc)
                    }
            }

            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // Note drag and attachment drag are exclusive — never simultaneous
            if gestureRecognizer === noteDragRecognizer   || other === noteDragRecognizer   { return false }
            if gestureRecognizer === tabDragRecognizer    || other === tabDragRecognizer    { return false }
            if gestureRecognizer === attachmentRecognizer || other === attachmentRecognizer { return false }
            return true
        }
    }
}

// MARK: - Inner SwiftUI spread view

struct SpreadHostView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main spread content
            Group {
                switch store.activeSpread {
                case .monthWeek:
                    monthWeekSpread
                case .planning:
                    PlanningSpreadView(store: store)
                case .notes:
                    NotesSpreadView(store: store)
                }
            }

            // Sticky notes overlay — shows notes for current spread
            ForEach(store.stickyNotes.filter { $0.pageId == store.currentSpreadId }) { note in
                StickyNoteView(store: store, noteId: note.id)
                    .frame(width: note.displayWidth, height: note.displayHeight)
                    .offset(x: note.x, y: note.y)
                    .zIndex(1)
            }

            // Tab markers overlay
            ForEach(store.tabMarkers.filter { $0.pageId == store.currentSpreadId }) { tab in
                TabMarkerView(store: store, markerId: tab.id)
                    .offset(x: tab.x, y: tab.y)
                    .zIndex(1.5)
            }

            // Attachments overlay
            ForEach(store.attachments.filter { $0.pageId == store.currentSpreadId }) { att in
                AttachmentView(store: store, attachmentId: att.id)
                    .offset(x: att.x, y: att.y)
                    .zIndex(2)
            }
        }
        .frame(width: PlannerTheme.spreadWidth, height: PlannerTheme.spreadHeight)
        .background(PlannerTheme.paper)
    }

    private var monthWeekSpread: some View {
        HStack(spacing: 0) {
            MonthPaperView(store: store)

            // Spine / divider
            Rectangle()
                .fill(PlannerTheme.line)
                .frame(width: 1, height: PlannerTheme.spreadHeight)

            WeekPaperView(store: store)
        }
        .frame(width: PlannerTheme.spreadWidth, height: PlannerTheme.spreadHeight)
    }
}
