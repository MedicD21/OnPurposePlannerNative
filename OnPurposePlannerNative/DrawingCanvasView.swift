import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    var pageId: String
    @ObservedObject var store: PlannerStore

    func makeCoordinator() -> Coordinator {
        Coordinator(pageId: pageId, store: store)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy   = .pencilOnly   // OS-level palm rejection — fingers pan/zoom
        canvas.isScrollEnabled = false          // ZoomableView owns scrolling
        canvas.backgroundColor = .clear
        canvas.isOpaque        = false

        canvas.drawing  = store.drawing(forPageId: pageId)
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas

        store.toolPicker.setVisible(true, forFirstResponder: canvas)
        store.toolPicker.addObserver(canvas)

        DispatchQueue.main.async { canvas.becomeFirstResponder() }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if context.coordinator.pageId != pageId {
            context.coordinator.pageId = pageId
            canvas.drawing = store.drawing(forPageId: pageId)
            store.toolPicker.setVisible(true, forFirstResponder: canvas)
            store.toolPicker.addObserver(canvas)
            DispatchQueue.main.async { canvas.becomeFirstResponder() }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var pageId: String
        var store:  PlannerStore
        weak var canvas: PKCanvasView?

        /// Guards against re-entrant shape replacement triggering another recognition pass.
        private var isApplyingShape = false
        private var shapeTimer: Timer?

        init(pageId: String, store: PlannerStore) {
            self.pageId = pageId
            self.store  = store
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            store.saveDrawing(canvasView.drawing, forPageId: pageId)
            guard !isApplyingShape else { return }

            // Schedule shape recognition: fires 0.8 s after the last stroke change.
            shapeTimer?.invalidate()
            shapeTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self, weak canvasView] _ in
                guard let self, let canvasView else { return }
                self.tryRecognizeLastStroke(in: canvasView)
            }
        }

        // MARK: - Shape recognition

        private func tryRecognizeLastStroke(in canvas: PKCanvasView) {
            guard let lastStroke = canvas.drawing.strokes.last,
                  let shape = ShapeRecognizer.recognize(lastStroke) else { return }

            let newStrokes = ShapeRecognizer.makeStrokes(shape, template: lastStroke)

            var drawing = canvas.drawing
            drawing.strokes.removeLast()
            drawing.strokes.append(contentsOf: newStrokes)

            isApplyingShape = true
            canvas.drawing  = drawing
            store.saveDrawing(drawing, forPageId: pageId)
            isApplyingShape = false
        }
    }
}
