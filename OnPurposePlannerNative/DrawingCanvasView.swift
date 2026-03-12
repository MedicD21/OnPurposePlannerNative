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

        // Load persisted drawing for this page
        canvas.drawing = store.drawing(forPageId: pageId)
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas

        // Connect the shared PKToolPicker to this canvas.
        // setVisible(true, forFirstResponder:) means the picker appears whenever
        // this canvas is first responder — which happens automatically when the
        // user taps/draws on it with the Pencil.
        store.toolPicker.setVisible(true, forFirstResponder: canvas)
        store.toolPicker.addObserver(canvas)

        // Make the canvas first responder so the tool picker appears immediately.
        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Switch page when the store changes (navigating weeks/months).
        if context.coordinator.pageId != pageId {
            context.coordinator.pageId = pageId
            canvas.drawing = store.drawing(forPageId: pageId)

            // Re-register with the tool picker for the new canvas instance.
            store.toolPicker.setVisible(true, forFirstResponder: canvas)
            store.toolPicker.addObserver(canvas)
            DispatchQueue.main.async {
                canvas.becomeFirstResponder()
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var pageId: String
        var store:  PlannerStore
        weak var canvas: PKCanvasView?

        init(pageId: String, store: PlannerStore) {
            self.pageId = pageId
            self.store  = store
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            store.saveDrawing(canvasView.drawing, forPageId: pageId)
        }
    }
}
