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

        // Two-finger swipe recognizer
        let swipe = TwoFingerSwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerSwipe(_:)))
        swipe.delegate = context.coordinator
        scrollView.addGestureRecognizer(swipe)

        // One-finger swipe: vertical on month paper → months, horizontal on week paper → weeks
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleOneFingerPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        scrollView.addGestureRecognizer(pan)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = SpreadHostView(store: store)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var store: PlannerStore
        weak var scrollView: UIScrollView?
        var hostingController: UIHostingController<SpreadHostView>?

        init(store: PlannerStore) {
            self.store = store
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(scrollView)
        }

        func centerContent(_ scrollView: UIScrollView) {
            guard let content = hostingController?.view else { return }
            let offsetX = max((scrollView.bounds.width  - content.frame.width)  * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - content.frame.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }

        // MARK: - One-finger swipe (paper-zone navigation)

        private var panStartLocation: CGPoint = .zero

        @objc func handleOneFingerPan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView = scrollView,
                  let contentView = hostingController?.view else { return }

            switch recognizer.state {
            case .began:
                panStartLocation = recognizer.location(in: scrollView)
            case .ended, .cancelled:
                let end = recognizer.location(in: scrollView)
                let dx  = end.x - panStartLocation.x
                let dy  = end.y - panStartLocation.y
                guard sqrt(dx*dx + dy*dy) > 60 else { return }

                // Determine which paper the swipe started on
                let contentStart = scrollView.convert(panStartLocation, to: contentView)
                let isLeftPaper  = contentStart.x < PlannerTheme.leftPaperWidth

                DispatchQueue.main.async {
                    if isLeftPaper {
                        // Vertical swipe on month paper → navigate months
                        guard abs(dy) > abs(dx) else { return }
                        if dy < 0 { self.store.goToNextMonth() }
                        else      { self.store.goToPreviousMonth() }
                    } else {
                        // Horizontal swipe on week paper → navigate weeks
                        guard abs(dx) > abs(dy),
                              self.store.activeSpread == .monthWeek else { return }
                        if dx < 0 { self.store.goToNextWeek() }
                        else      { self.store.goToPreviousWeek() }
                    }
                }
            default:
                break
            }
        }

        @objc func handleTwoFingerSwipe(_ recognizer: TwoFingerSwipeGestureRecognizer) {
            guard recognizer.state == .recognized else { return }
            DispatchQueue.main.async {
                switch recognizer.recognizedDirection {
                case .left:
                    if self.store.activeSpread == .monthWeek {
                        self.store.goToNextWeek()
                    }
                case .right:
                    if self.store.activeSpread == .monthWeek {
                        self.store.goToPreviousWeek()
                    }
                case .up:
                    self.store.goToNextMonth()
                case .down:
                    self.store.goToPreviousMonth()
                case .none:
                    break
                }
            }
        }

        // Allow the swipe gesture alongside the scroll view's own pan
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
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
                    .frame(width: note.width, height: note.isCollapsed ? StickyNote.headerHeight : note.height)
                    .offset(x: note.x, y: note.y)
                    .zIndex(1)
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
