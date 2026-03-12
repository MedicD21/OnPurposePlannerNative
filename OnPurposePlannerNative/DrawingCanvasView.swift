import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    var pageId: String
    @ObservedObject var store: PlannerStore

    func makeCoordinator() -> Coordinator {
        Coordinator(pageId: pageId, store: store)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds   = true

        // Fill image layer sits below the drawing canvas
        let fillView = UIImageView()
        fillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fillView.contentMode      = .scaleToFill
        fillView.backgroundColor  = .clear
        container.addSubview(fillView)

        // PencilKit canvas on top
        let canvas = PKCanvasView()
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.drawingPolicy    = .pencilOnly   // OS palm rejection; fingers pan/zoom
        canvas.isScrollEnabled  = false
        canvas.backgroundColor  = .clear
        canvas.isOpaque         = false
        canvas.drawing          = store.drawing(forPageId: pageId)
        canvas.delegate         = context.coordinator
        container.addSubview(canvas)

        context.coordinator.canvas   = canvas
        context.coordinator.fillView = fillView

        fillView.image = store.fillImage(forPageId: pageId)

        store.toolPicker.setVisible(true, forFirstResponder: canvas)
        store.toolPicker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }

        // Tap gesture for paint-bucket fill (finger taps; Pencil goes to drawing engine)
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleFillTap(_:)))
        tap.delegate = context.coordinator
        canvas.addGestureRecognizer(tap)

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard context.coordinator.pageId != pageId else { return }
        context.coordinator.pageId = pageId
        if let canvas = context.coordinator.canvas {
            canvas.drawing = store.drawing(forPageId: pageId)
            store.toolPicker.setVisible(true, forFirstResponder: canvas)
            store.toolPicker.addObserver(canvas)
            DispatchQueue.main.async { canvas.becomeFirstResponder() }
        }
        context.coordinator.fillView?.image = store.fillImage(forPageId: pageId)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var pageId: String
        var store:  PlannerStore
        weak var canvas:   PKCanvasView?
        weak var fillView: UIImageView?

        private var isApplyingShape = false
        private var shapeTimer: Timer?

        init(pageId: String, store: PlannerStore) {
            self.pageId = pageId
            self.store  = store
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            store.saveDrawing(canvasView.drawing, forPageId: pageId)
            guard !isApplyingShape else { return }
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

        // MARK: - Paint bucket fill

        @objc func handleFillTap(_ recognizer: UITapGestureRecognizer) {
            guard store.fillModeActive,
                  recognizer.state == .ended,
                  let canvas   = canvas,
                  let fillView = fillView else { return }

            let location = recognizer.location(in: canvas)
            let drawing  = canvas.drawing
            let existing = fillView.image
            let size     = canvas.bounds.size

            // Use the current ink tool's color
            let fillColor: UIColor
            if let inkTool = store.toolPicker.selectedTool as? PKInkingTool {
                fillColor = inkTool.color
            } else {
                fillColor = UIColor(PlannerTheme.defaultPalette[0])
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let result = self.computeFill(
                    drawing: drawing,
                    existingFill: existing,
                    canvasSize: size,
                    at: location,
                    color: fillColor)
                DispatchQueue.main.async {
                    guard let result else { return }
                    fillView.image = result
                    self.store.saveFillImage(result, forPageId: self.pageId)
                }
            }
        }

        // Allow fill tap alongside PKCanvasView's own gesture recognizers
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        // MARK: - Flood fill

        private func computeFill(
            drawing: PKDrawing,
            existingFill: UIImage?,
            canvasSize: CGSize,
            at point: CGPoint,
            color: UIColor
        ) -> UIImage? {
            let scale = UIScreen.main.scale
            let w  = Int(canvasSize.width  * scale)
            let h  = Int(canvasSize.height * scale)
            let px = Int(point.x * scale)
            let py = Int(point.y * scale)
            guard w > 0, h > 0,
                  px >= 0, px < w,
                  py >= 0, py < h else { return nil }

            let bpp = 4
            let bpr = w * bpp
            let cs  = CGColorSpaceCreateDeviceRGB()
            let bmi = CGImageAlphaInfo.premultipliedLast.rawValue

            // Render PKDrawing to detect stroke boundaries
            let drawingImg = drawing.image(
                from: CGRect(origin: .zero, size: canvasSize), scale: scale)
            guard let drawingCG = drawingImg.cgImage else { return nil }

            var detectPx = [UInt8](repeating: 0, count: h * bpr)
            guard let detectCtx = CGContext(
                data: &detectPx, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: bpr, space: cs, bitmapInfo: bmi
            ) else { return nil }
            detectCtx.draw(drawingCG, in: CGRect(x: 0, y: 0, width: w, height: h))

            // Bail if tap is on a stroke (alpha > 20 = ink boundary)
            guard detectPx[py * bpr + px * bpp + 3] <= 20 else { return nil }

            // Output layer: start from existing fill image
            var outputPx = [UInt8](repeating: 0, count: h * bpr)
            guard let outputCtx = CGContext(
                data: &outputPx, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: bpr, space: cs, bitmapInfo: bmi
            ) else { return nil }
            if let existingCG = existingFill?.cgImage {
                outputCtx.draw(existingCG, in: CGRect(x: 0, y: 0, width: w, height: h))
            }

            // Premultiplied fill color components
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let fA = UInt8(a * 255)
            let fR = UInt8(r * a * 255)
            let fG = UInt8(g * a * 255)
            let fB = UInt8(b * a * 255)

            // BFS flood fill — stop at stroke pixels (alpha > 20 in detectPx)
            var visited = [Bool](repeating: false, count: w * h)
            var queue   = [(Int, Int)]()
            queue.reserveCapacity(min(w * h / 8, 512_000))
            queue.append((px, py))
            visited[py * w + px] = true
            var qi = 0

            while qi < queue.count {
                let (x, y) = queue[qi]; qi += 1
                let oi = y * bpr + x * bpp
                outputPx[oi]   = fR
                outputPx[oi+1] = fG
                outputPx[oi+2] = fB
                outputPx[oi+3] = fA

                for (nx, ny) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] {
                    guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                    let ni = ny * w + nx
                    guard !visited[ni] else { continue }
                    visited[ni] = true
                    guard detectPx[ny * bpr + nx * bpp + 3] <= 20 else { continue }
                    queue.append((nx, ny))
                }
            }

            guard let resultCG = outputCtx.makeImage() else { return nil }
            return UIImage(cgImage: resultCG, scale: scale, orientation: .up)
        }
    }
}
