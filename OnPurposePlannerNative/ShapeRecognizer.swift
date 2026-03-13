import PencilKit
import CoreGraphics

// MARK: - Recognized shape types

enum RecognizedShape {
    case line(from: CGPoint, to: CGPoint)
    case circle(center: CGPoint, radius: CGFloat)
    case rectangle(minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat)
    case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint)
}

// MARK: - Shape recognizer

struct ShapeRecognizer {

    // MARK: - Public API

    /// Returns a recognized shape if the stroke ended with a held pause, nil otherwise.
    static func recognize(_ stroke: PKStroke) -> RecognizedShape? {
        let pts = collectPoints(stroke)
        guard pts.count >= 10 else { return nil }
        guard wasHeld(pts)        else { return nil }

        if let s = tryLine(pts)       { return s }
        if let s = tryCircle(pts)     { return s }
        if let s = tryRectangle(pts)  { return s }
        if let s = tryTriangle(pts)   { return s }
        return nil
    }

    /// Generate replacement PKStroke(s) for a recognized shape.
    static func makeStrokes(_ shape: RecognizedShape, template: PKStroke) -> [PKStroke] {
        switch shape {
        case .line(let a, let b):
            return [stroke(through: lerp(a, b, steps: 40), template: template)]

        case .circle(let center, let radius):
            let pts = (0...80).map { i -> CGPoint in
                let θ = 2 * CGFloat.pi * CGFloat(i) / 80
                return CGPoint(x: center.x + radius * cos(θ),
                               y: center.y + radius * sin(θ))
            }
            return [stroke(through: pts, template: template)]

        case .rectangle(let x0, let y0, let x1, let y1):
            let corners: [(CGPoint, CGPoint)] = [
                (CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y0)),
                (CGPoint(x: x1, y: y0), CGPoint(x: x1, y: y1)),
                (CGPoint(x: x1, y: y1), CGPoint(x: x0, y: y1)),
                (CGPoint(x: x0, y: y1), CGPoint(x: x0, y: y0)),
            ]
            return corners.map { stroke(through: lerp($0.0, $0.1, steps: 30), template: template) }

        case .triangle(let p1, let p2, let p3):
            return [
                stroke(through: lerp(p1, p2, steps: 30), template: template),
                stroke(through: lerp(p2, p3, steps: 30), template: template),
                stroke(through: lerp(p3, p1, steps: 30), template: template),
            ]
        }
    }

    static func previewPath(for shape: RecognizedShape) -> CGPath {
        let path = CGMutablePath()

        switch shape {
        case .line(let a, let b):
            path.move(to: a)
            path.addLine(to: b)

        case .circle(let center, let radius):
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        case .rectangle(let x0, let y0, let x1, let y1):
            path.addRect(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))

        case .triangle(let p1, let p2, let p3):
            path.move(to: p1)
            path.addLine(to: p2)
            path.addLine(to: p3)
            path.closeSubpath()
        }

        return path
    }

    static func averageStrokeWidth(_ stroke: PKStroke) -> CGFloat {
        var sum: CGFloat = 0
        var count = 0

        for point in stroke.path {
            sum += max(point.size.width, point.size.height)
            count += 1
        }

        guard count > 0 else { return 2 }
        return sum / CGFloat(count)
    }

    // MARK: - Point collection

    private static func collectPoints(_ stroke: PKStroke) -> [CGPoint] {
        var pts: [CGPoint] = []
        for pt in stroke.path { pts.append(pt.location) }
        return pts
    }

    // MARK: - Hold detection

    /// True if the last cluster of points are tightly grouped (pencil held still).
    private static func wasHeld(_ pts: [CGPoint]) -> Bool {
        let n    = min(12, pts.count)
        let tail = Array(pts.suffix(n))
        let cx   = tail.map(\.x).reduce(0, +) / CGFloat(n)
        let cy   = tail.map(\.y).reduce(0, +) / CGFloat(n)
        let maxSpread = tail.map { hypot($0.x - cx, $0.y - cy) }.max() ?? 0
        return maxSpread < 18          // within 18 pt → held
    }

    // MARK: - Shape classifiers

    private static func tryLine(_ pts: [CGPoint]) -> RecognizedShape? {
        guard let a = pts.first, let b = pts.last else { return nil }
        let len = hypot(b.x - a.x, b.y - a.y)
        guard len > 40 else { return nil }
        let maxPerp = pts.map { perpDist($0, a: a, b: b) }.max() ?? 0
        guard maxPerp < len * 0.12 else { return nil }
        return .line(from: a, to: b)
    }

    private static func tryCircle(_ pts: [CGPoint]) -> RecognizedShape? {
        let cx  = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
        let cy  = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
        let rs  = pts.map { hypot($0.x - cx, $0.y - cy) }
        let r   = rs.reduce(0, +) / CGFloat(rs.count)
        guard r > 20 else { return nil }
        let σ   = sqrt(rs.map { pow($0 - r, 2) }.reduce(0, +) / CGFloat(rs.count))
        guard σ / r < 0.20 else { return nil }
        // Must be roughly closed
        guard let a = pts.first, let b = pts.last,
              hypot(b.x - a.x, b.y - a.y) < r * 0.55 else { return nil }
        return .circle(center: CGPoint(x: cx, y: cy), radius: r)
    }

    private static func tryRectangle(_ pts: [CGPoint]) -> RecognizedShape? {
        let xs = pts.map(\.x), ys = pts.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(),
              let y0 = ys.min(), let y1 = ys.max() else { return nil }
        let w = x1 - x0, h = y1 - y0
        guard w > 30, h > 30 else { return nil }
        // Most points must lie near one of the 4 edges
        let tol  = min(w, h) * 0.18
        let near = pts.filter { p in
            abs(p.x - x0) < tol || abs(p.x - x1) < tol ||
            abs(p.y - y0) < tol || abs(p.y - y1) < tol
        }
        guard Double(near.count) / Double(pts.count) > 0.78 else { return nil }
        // Must be roughly closed
        guard let a = pts.first, let b = pts.last,
              hypot(b.x - a.x, b.y - a.y) < min(w, h) * 0.35 else { return nil }
        return .rectangle(minX: x0, minY: y0, maxX: x1, maxY: y1)
    }

    private static func tryTriangle(_ pts: [CGPoint]) -> RecognizedShape? {
        let corners = findCorners(pts, minSharpnessDeg: 55)
        guard corners.count >= 3 else { return nil }
        let c = corners.prefix(3)
        // Must be roughly closed
        guard let a = pts.first, let b = pts.last else { return nil }
        let span = pts.map { hypot($0.x - a.x, $0.y - a.y) }.max() ?? 1
        guard hypot(b.x - a.x, b.y - a.y) < span * 0.30 else { return nil }
        return .triangle(p1: c[0], p2: c[1], p3: c[2])
    }

    // MARK: - Corner finder (high-curvature points)

    private static func findCorners(_ pts: [CGPoint], minSharpnessDeg: CGFloat) -> [CGPoint] {
        guard pts.count > 8 else { return [] }
        let win = max(3, pts.count / 12)
        var corners: [CGPoint] = []
        for i in win ..< pts.count - win {
            let angle = angleDeg(a: pts[i - win], vertex: pts[i], c: pts[i + win])
            if angle < (180 - minSharpnessDeg) {
                if let last = corners.last {
                    guard hypot(pts[i].x - last.x, pts[i].y - last.y) > 20 else { continue }
                }
                corners.append(pts[i])
            }
        }
        return corners
    }

    // MARK: - Geometry helpers

    private static func perpDist(_ p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = hypot(dx, dy)
        guard len > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        return abs(dx * (a.y - p.y) - (a.x - p.x) * dy) / len
    }

    private static func angleDeg(a: CGPoint, vertex v: CGPoint, c: CGPoint) -> CGFloat {
        let u = CGPoint(x: a.x - v.x, y: a.y - v.y)
        let w = CGPoint(x: c.x - v.x, y: c.y - v.y)
        let dot = u.x * w.x + u.y * w.y
        let mag = hypot(u.x, u.y) * hypot(w.x, w.y)
        guard mag > 0 else { return 180 }
        return acos(max(-1, min(1, dot / mag))) * 180 / .pi
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, steps: Int) -> [CGPoint] {
        (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    // MARK: - Stroke builder

    private static func stroke(through locs: [CGPoint], template: PKStroke) -> PKStroke {
        let averageWidth = averageStrokeWidth(template)
        let avgSize = CGSize(width: averageWidth, height: averageWidth)

        let pts = locs.enumerated().map { i, loc in
            PKStrokePoint(
                location:   loc,
                timeOffset: TimeInterval(i) / TimeInterval(max(locs.count - 1, 1)),
                size:       avgSize,
                opacity:    1,
                force:      1,
                azimuth:    0,
                altitude:   0
            )
        }
        let path = PKStrokePath(controlPoints: pts, creationDate: Date())
        return PKStroke(ink: template.ink, path: path)
    }
}
