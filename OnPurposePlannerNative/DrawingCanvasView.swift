import SwiftUI
import PencilKit

struct MonthCellPosition: Hashable {
    let row: Int
    let column: Int
}

/// Describes the month-calendar grid so the paint-bucket fill can be
/// restricted to a single day cell. Nil on non-month canvases.
struct MonthFillGrid {
    let cellFrames: [MonthCellPosition: CGRect]

    func cellRect(containing point: CGPoint) -> CGRect? {
        cellFrames.values.first { $0.contains(point) }
    }

    func cellFrame(at position: MonthCellPosition) -> CGRect? {
        cellFrames[position]
    }
}

struct DrawingCanvasView: UIViewRepresentable {
    var pageId: String
    @ObservedObject var store: PlannerStore
    /// When non-nil, fill is enabled and clamped to the tapped day cell.
    var monthGrid: MonthFillGrid? = nil

    private let monthFillInset: CGFloat = 2
    private let monthFillOpacity: CGFloat = 0.22

    func makeCoordinator() -> Coordinator {
        Coordinator(
            pageId: pageId,
            store: store,
            fillInset: monthFillInset,
            fillOpacity: monthFillOpacity
        )
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds   = true

        // Fill image layer sits below the drawing canvas
        let fillView = UIImageView()
        fillView.frame = container.bounds
        fillView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fillView.contentMode      = .scaleToFill
        fillView.backgroundColor  = .clear
        fillView.isHidden         = monthGrid != nil
        container.addSubview(fillView)

        // PencilKit canvas on top
        let canvas = PKCanvasView()
        canvas.frame = container.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.drawingPolicy    = .pencilOnly
        canvas.isScrollEnabled  = false
        canvas.backgroundColor  = .clear
        canvas.isOpaque         = false
        canvas.drawing          = store.drawing(forPageId: pageId)
        canvas.delegate         = context.coordinator
        // Disable PKCanvasView's internal pan gesture (it extends UIScrollView) so that
        // finger swipes propagate to the parent scroll view's navigation gesture recognizers.
        canvas.panGestureRecognizer.isEnabled = false
        container.addSubview(canvas)

        let previewView = UIView(frame: container.bounds)
        previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        previewView.backgroundColor = .clear
        previewView.isUserInteractionEnabled = false
        let previewLayer = CAShapeLayer()
        previewLayer.frame = previewView.bounds
        previewLayer.fillColor = UIColor.clear.cgColor
        previewLayer.strokeColor = UIColor.clear.cgColor
        previewLayer.lineJoin = .round
        previewLayer.lineCap = .round
        previewLayer.opacity = 0
        previewView.layer.addSublayer(previewLayer)
        container.addSubview(previewView)

        context.coordinator.canvas    = canvas
        context.coordinator.fillView  = fillView
        context.coordinator.monthGrid = monthGrid
        context.coordinator.previewLayer = previewLayer
        context.coordinator.drawingGestureRecognizer = canvas.drawingGestureRecognizer

        fillView.image = store.fillImage(forPageId: pageId)

        store.activateCanvas(canvas)
        canvas.drawingGestureRecognizer.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleDrawingGesture(_:))
        )

        // Tap gesture for paint-bucket fill — only registered when a grid is provided
        if monthGrid != nil {
            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleFillTap(_:)))
            tap.delegate = context.coordinator
            canvas.addGestureRecognizer(tap)
        }

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        context.coordinator.monthGrid = monthGrid
        context.coordinator.fillView?.isHidden = monthGrid != nil
        context.coordinator.fillView?.image = store.fillImage(forPageId: pageId)
        context.coordinator.previewLayer?.frame = container.bounds
        guard context.coordinator.pageId != pageId else { return }
        context.coordinator.pageId = pageId
        context.coordinator.clearStrokeProcessing()
        if let canvas = context.coordinator.canvas {
            canvas.drawing = store.drawing(forPageId: pageId)
            store.activateCanvas(canvas)
        }
    }

    static func dismantleUIView(_ container: UIView, coordinator: Coordinator) {
        coordinator.clearStrokeProcessing()
        coordinator.drawingGestureRecognizer?.removeTarget(
            coordinator,
            action: #selector(Coordinator.handleDrawingGesture(_:))
        )
        if let canvas = coordinator.canvas {
            coordinator.store.toolPicker.removeObserver(canvas)
            coordinator.store.unregisterCanvas(canvas)
        }
        coordinator.canvas = nil
        coordinator.fillView = nil
        coordinator.previewLayer = nil
        coordinator.drawingGestureRecognizer = nil
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
        var pageId:    String
        var store:     PlannerStore
        var monthGrid: MonthFillGrid?
        weak var canvas:   PKCanvasView?
        weak var fillView: UIImageView?
        weak var drawingGestureRecognizer: UIGestureRecognizer?
        var previewLayer: CAShapeLayer?
        private let fillInset: CGFloat
        private let fillOpacity: CGFloat

        private var isApplyingDrawingMutation = false
        private var processingTimer: Timer?
        private var shapeCommitTimer: Timer?
        private var livePreviewTimer: Timer?
        private var liveStrokePoints: [CGPoint] = []
        private var previewedShape: RecognizedShape?
        private var pendingHeldShape: RecognizedShape?
        private var previewAnchorLocation: CGPoint = .zero
        private var toolInteractionActive = false

        init(pageId: String, store: PlannerStore, fillInset: CGFloat, fillOpacity: CGFloat) {
            self.pageId = pageId
            self.store  = store
            self.fillInset = fillInset
            self.fillOpacity = fillOpacity
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            store.saveDrawing(canvasView.drawing, forPageId: pageId)
            guard !isApplyingDrawingMutation else { return }

             if let pendingHeldShape,
                let lastStroke = canvasView.drawing.strokes.last {
                self.pendingHeldShape = nil
                commitRecognizedShape(pendingHeldShape, template: lastStroke, in: canvasView)
                return
            }

            clearStrokeProcessing()
            processingTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self, weak canvasView] _ in
                guard let self, let canvasView else { return }
                self.handlePostStrokeProcessing(in: canvasView)
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            toolInteractionActive = true
            liveStrokePoints.removeAll(keepingCapacity: true)
            previewedShape = nil
            pendingHeldShape = nil
            previewAnchorLocation = .zero
            livePreviewTimer?.invalidate()
            livePreviewTimer = nil
            hideShapePreview()
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            toolInteractionActive = false
            livePreviewTimer?.invalidate()
            livePreviewTimer = nil
            if previewedShape == nil {
                hideShapePreview()
            } else {
                pendingHeldShape = previewedShape
            }
        }

        // MARK: - Post-stroke processing

        func clearStrokeProcessing() {
            processingTimer?.invalidate()
            processingTimer = nil
            shapeCommitTimer?.invalidate()
            shapeCommitTimer = nil
            livePreviewTimer?.invalidate()
            livePreviewTimer = nil
            previewedShape = nil
            hideShapePreview()
        }

        private func handlePostStrokeProcessing(in canvas: PKCanvasView) {
            guard !store.fillModeActive,
                  let lastStroke = canvas.drawing.strokes.last else { return }

            if tryScratchOut(lastStroke, in: canvas) {
                return
            }

            guard let shape = ShapeRecognizer.recognize(lastStroke) else { return }
            showShapePreview(shape, template: lastStroke)

            shapeCommitTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { [weak self, weak canvas] _ in
                guard let self, let canvas else { return }
                self.commitRecognizedShape(shape, template: lastStroke, in: canvas)
            }
        }

        private func tryScratchOut(_ scratchStroke: PKStroke, in canvas: PKCanvasView) -> Bool {
            var drawing = canvas.drawing
            guard drawing.strokes.count > 1 else { return false }

            let targetIndices = ScratchOutRecognizer.targetStrokeIndices(
                for: scratchStroke,
                in: Array(drawing.strokes.dropLast())
            )
            guard !targetIndices.isEmpty else { return false }

            drawing.strokes.removeLast()
            for index in targetIndices.sorted(by: >) {
                drawing.strokes.remove(at: index)
            }

            applyDrawingChange(drawing, to: canvas, actionName: "Scratch Out")
            return true
        }

        private func commitRecognizedShape(_ shape: RecognizedShape, template: PKStroke, in canvas: PKCanvasView) {
            hideShapePreview()
            previewedShape = nil

            var drawing = canvas.drawing
            guard !drawing.strokes.isEmpty else { return }

            drawing.strokes.removeLast()
            drawing.strokes.append(contentsOf: ShapeRecognizer.makeStrokes(shape, template: template))
            applyDrawingChange(drawing, to: canvas, actionName: "Shape Correction")
        }

        private func applyDrawingChange(_ drawing: PKDrawing, to canvas: PKCanvasView, actionName: String) {
            clearStrokeProcessing()

            let previous = canvas.drawing
            isApplyingDrawingMutation = true
            canvas.drawing = drawing
            store.saveDrawing(drawing, forPageId: pageId)
            isApplyingDrawingMutation = false

            canvas.undoManager?.registerUndo(withTarget: self) { [weak canvas] coordinator in
                guard let canvas else { return }
                coordinator.applyDrawingChange(previous, to: canvas, actionName: actionName)
            }
            canvas.undoManager?.setActionName(actionName)
        }

        @objc func handleDrawingGesture(_ recognizer: UIGestureRecognizer) {
            guard !store.fillModeActive,
                  let canvas,
                  let inkTool = canvas.tool as? PKInkingTool else { return }

            let location = recognizer.location(in: canvas)

            switch recognizer.state {
            case .began:
                toolInteractionActive = true
                liveStrokePoints = [location]
                previewedShape = nil
                pendingHeldShape = nil
                hideShapePreview()
                scheduleLivePreview()

            case .changed:
                recordLivePoint(location)
                if previewedShape != nil {
                    // Only dismiss the preview when the pencil moves significantly away from
                    // where it was when the preview appeared — ignore normal hold jitter.
                    let dist = hypot(location.x - previewAnchorLocation.x,
                                     location.y - previewAnchorLocation.y)
                    if dist > 8 {
                        hideShapePreview()
                        previewedShape = nil
                        pendingHeldShape = nil
                    }
                }
                scheduleLivePreview()

            case .ended:
                recordLivePoint(location)
                if let shape = previewedShape {
                    showShapePreview(
                        shape,
                        inkColor: inkTool.color,
                        lineWidth: inkTool.width,
                        fromPath: ShapeRecognizer.rawPreviewPath(through: liveStrokePoints)
                    )
                    pendingHeldShape = shape
                }
                toolInteractionActive = false
                livePreviewTimer?.invalidate()
                livePreviewTimer = nil

            case .cancelled, .failed:
                toolInteractionActive = false
                livePreviewTimer?.invalidate()
                livePreviewTimer = nil
                liveStrokePoints.removeAll(keepingCapacity: true)
                previewedShape = nil
                pendingHeldShape = nil
                hideShapePreview()

            default:
                break
            }
        }

        private func recordLivePoint(_ point: CGPoint) {
            guard let last = liveStrokePoints.last else {
                liveStrokePoints = [point]
                return
            }

            if hypot(point.x - last.x, point.y - last.y) >= 1 {
                liveStrokePoints.append(point)
            }
        }

        private func scheduleLivePreview() {
            livePreviewTimer?.invalidate()
            guard liveStrokePoints.count >= 10 else { return }

            livePreviewTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: false) { [weak self] _ in
                self?.evaluateLiveShapePreview()
            }
        }

        private func evaluateLiveShapePreview() {
            guard toolInteractionActive,
                  previewedShape == nil,          // already showing — don't re-trigger
                  let canvas,
                  let inkTool = canvas.tool as? PKInkingTool,
                  let shape = ShapeRecognizer.recognize(points: liveStrokePoints, requireHold: true)
            else { return }

            previewedShape = shape
            pendingHeldShape = shape
            previewAnchorLocation = liveStrokePoints.last ?? .zero
            showShapePreview(
                shape,
                inkColor: inkTool.color,
                lineWidth: inkTool.width,
                fromPath: ShapeRecognizer.rawPreviewPath(through: liveStrokePoints)
            )
        }

        private func showShapePreview(_ shape: RecognizedShape, template: PKStroke) {
            showShapePreview(
                shape,
                inkColor: template.ink.color,
                lineWidth: max(1.5, ShapeRecognizer.averageStrokeWidth(template)),
                fromPath: ShapeRecognizer.rawPreviewPath(through: collectPoints(template))
            )
        }

        private func showShapePreview(
            _ shape: RecognizedShape,
            inkColor: UIColor,
            lineWidth: CGFloat,
            fromPath: CGPath
        ) {
            guard let previewLayer else { return }

            let targetPath = ShapeRecognizer.previewPath(for: shape)
            previewLayer.removeAllAnimations()
            previewLayer.path = targetPath
            previewLayer.strokeColor = inkColor.cgColor
            previewLayer.fillColor = ShapeRecognizer.previewFillColor(for: shape, inkColor: inkColor).cgColor
            previewLayer.lineWidth = lineWidth
            previewLayer.lineDashPattern = nil
            previewLayer.opacity = 1

            let morph = CABasicAnimation(keyPath: "path")
            morph.fromValue = fromPath
            morph.toValue = targetPath
            morph.duration = 0.16
            morph.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = previewLayer.presentation()?.opacity ?? 0
            fade.toValue = 1
            fade.duration = 0.08
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)

            previewLayer.add(morph, forKey: "shapePreviewMorph")
            previewLayer.add(fade, forKey: "shapePreviewFade")
        }

        private func hideShapePreview() {
            previewLayer?.removeAllAnimations()
            previewLayer?.path = nil
            previewLayer?.opacity = 0
        }

        private func collectPoints(_ stroke: PKStroke) -> [CGPoint] {
            stroke.path.map(\.location)
        }

        // MARK: - Paint bucket fill

        @objc func handleFillTap(_ recognizer: UITapGestureRecognizer) {
            guard store.fillModeActive,
                  recognizer.state == .ended,
                  let canvas   = canvas,
                  let fillView = fillView,
                  let grid     = monthGrid else { return }

            let location = recognizer.location(in: canvas)

            guard let cellRect = grid.cellRect(containing: location) else { return }

            let drawing  = canvas.drawing
            let existing = fillView.image
            let size     = canvas.bounds.size

            let fillColor = styledFillColor(from: store.lastSelectedInkColor)

            DispatchQueue.global(qos: .userInitiated).async { [weak self, weak canvas] in
                guard let self else { return }
                let result = self.computeFill(
                    drawing: drawing,
                    existingFill: existing,
                    canvasSize: size,
                    at: location,
                    color: fillColor,
                    clampRect: cellRect)
                DispatchQueue.main.async {
                    guard let result else { return }
                    let previous = fillView.image   // capture for undo
                    fillView.image = result
                    self.store.saveFillImage(result, forPageId: self.pageId)
                    // Register with the canvas UndoManager so 3-finger undo works
                    canvas?.undoManager?.registerUndo(withTarget: self) { [weak fillView] coord in
                        fillView?.image = previous
                        coord.store.saveFillImage(previous, forPageId: coord.pageId)
                    }
                    canvas?.undoManager?.setActionName("Fill")
                }
            }
        }

        private func styledFillColor(from color: UIColor) -> UIColor {
            color.withAlphaComponent(fillOpacity)
        }

        // Only intercept taps when fill mode is active; otherwise let them
        // fall through to SwiftUI views (e.g. event pill buttons above the canvas).
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UITapGestureRecognizer {
                return store.fillModeActive
            }
            return true
        }

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
            color: UIColor,
            clampRect: CGRect
        ) -> UIImage? {
            let scale = UIScreen.main.scale
            let w  = Int(canvasSize.width  * scale)
            let h  = Int(canvasSize.height * scale)
            let px = Int(point.x * scale)
            let py = Int(point.y * scale)
            guard w > 0, h > 0,
                  px >= 0, px < w,
                  py >= 0, py < h else { return nil }

            let fillBounds = clampRect.insetBy(dx: fillInset, dy: fillInset)

            // Pixel bounds of the day cell interior — BFS is clamped to this region
            let clampX0 = max(0, Int(floor(fillBounds.minX * scale)))
            let clampY0 = max(0, Int(floor(fillBounds.minY * scale)))
            let clampX1 = min(w - 1, Int(ceil(fillBounds.maxX * scale)) - 1)
            let clampY1 = min(h - 1, Int(ceil(fillBounds.maxY * scale)) - 1)
            guard clampX0 <= clampX1, clampY0 <= clampY1 else { return nil }

            guard px >= max(0, Int(clampRect.minX * scale)),
                  px <= min(w - 1, Int(ceil(clampRect.maxX * scale)) - 1),
                  py >= max(0, Int(clampRect.minY * scale)),
                  py <= min(h - 1, Int(ceil(clampRect.maxY * scale)) - 1)
            else { return nil }

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

            let seedX = min(max(px, clampX0), clampX1)
            let seedY = min(max(py, clampY0), clampY1)

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

            // BFS flood fill — stop at stroke pixels or cell boundary
            var visited = [Bool](repeating: false, count: w * h)
            var queue   = [(Int, Int)]()
            queue.reserveCapacity(min((clampX1 - clampX0) * (clampY1 - clampY0), 256_000))
            queue.append((seedX, seedY))
            visited[seedY * w + seedX] = true
            var qi = 0

            while qi < queue.count {
                let (x, y) = queue[qi]; qi += 1
                let oi = y * bpr + x * bpp
                outputPx[oi]   = fR
                outputPx[oi+1] = fG
                outputPx[oi+2] = fB
                outputPx[oi+3] = fA

                for (nx, ny) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] {
                    // Hard-clamp to the day cell rect
                    guard nx >= clampX0, nx <= clampX1,
                          ny >= clampY0, ny <= clampY1 else { continue }
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
