import PencilKit
import CoreGraphics

// MARK: - Recognized shape types

enum RecognizedShape {
    case line(from: CGPoint, to: CGPoint)
    case arrow(from: CGPoint, tip: CGPoint, wing1: CGPoint, wing2: CGPoint)
    case circle(center: CGPoint, radius: CGFloat)
    case rectangle(minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat)
    case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint)
}

// MARK: - Shape recognizer

struct ShapeRecognizer {

    // MARK: - Public API

    /// Returns a recognized shape if the stroke ended with a held pause, nil otherwise.
    static func recognize(_ stroke: PKStroke) -> RecognizedShape? {
        recognize(points: collectPoints(stroke), requireHold: true)
    }

    static func recognize(points: [CGPoint], requireHold: Bool) -> RecognizedShape? {
        guard points.count >= 10 else { return nil }
        guard !requireHold || wasHeld(points) else { return nil }

        // Arrow and line first (open shapes)
        if let s = tryArrow(points)      { return s }
        if let s = tryLine(points)       { return s }
        // Polygons before circle — corners disqualify circle candidates
        if let s = tryRectangle(points)  { return s }
        if let s = tryTriangle(points)   { return s }
        if let s = tryCircle(points)     { return s }
        return nil
    }

    /// Generate replacement PKStroke(s) for a recognized shape.
    static func makeStrokes(_ shape: RecognizedShape, template: PKStroke) -> [PKStroke] {
        switch shape {
        case .line(let a, let b):
            return [stroke(through: lerp(a, b, steps: 40), template: template)]

        case .arrow(let from, let tip, let wing1, let wing2):
            return [
                stroke(through: lerp(from, tip, steps: 44), template: template),
                stroke(through: lerp(tip, wing1, steps: 18), template: template),
                stroke(through: lerp(tip, wing2, steps: 18), template: template)
            ]

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

        case .arrow(let from, let tip, let wing1, let wing2):
            path.move(to: from)
            path.addLine(to: tip)
            path.move(to: tip)
            path.addLine(to: wing1)
            path.move(to: tip)
            path.addLine(to: wing2)

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

    static func previewFillColor(for shape: RecognizedShape, inkColor: UIColor) -> UIColor {
        .clear
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

    private static func tryArrow(_ pts: [CGPoint]) -> RecognizedShape? {
        guard pts.count >= 20 else { return nil }
        guard let start = pts.first else { return nil }

        let tipIndex = pts.indices.max {
            hypot(pts[$0].x - start.x, pts[$0].y - start.y)
            < hypot(pts[$1].x - start.x, pts[$1].y - start.y)
        } ?? 0

        guard tipIndex > pts.count / 5, tipIndex < pts.count - 8 else { return nil }

        let tip = pts[tipIndex]
        let shaftLength = hypot(tip.x - start.x, tip.y - start.y)
        guard shaftLength > 60 else { return nil }

        let shaftPoints = Array(pts[...tipIndex])
        let shaftDeviation = shaftPoints.map { perpDist($0, a: start, b: tip) }.max() ?? 0
        guard shaftDeviation < shaftLength * 0.12 else { return nil }

        let tail = Array(pts[tipIndex...])
        let distances = tail.map { hypot($0.x - tip.x, $0.y - tip.y) }
        let wingMin = max(16, shaftLength * 0.08)

        guard let firstPeak = firstTailPeak(in: distances, minimumHeight: wingMin) else { return nil }
        guard let valley = distances[firstPeak...].indices.dropFirst().first(where: {
            distances[$0] < wingMin * 0.45
        }) else { return nil }

        let secondRange = Array((valley + 1)..<distances.count)
        guard let secondPeak = secondRange.max(by: { distances[$0] < distances[$1] }),
              distances[secondPeak] >= wingMin else { return nil }

        let wing1 = tail[firstPeak]
        let wing2 = tail[secondPeak]
        let wing1Length = hypot(wing1.x - tip.x, wing1.y - tip.y)
        let wing2Length = hypot(wing2.x - tip.x, wing2.y - tip.y)
        guard wing1Length < shaftLength * 0.45, wing2Length < shaftLength * 0.45 else { return nil }

        let backward = normalized(CGPoint(x: start.x - tip.x, y: start.y - tip.y))
        let dir1 = normalized(CGPoint(x: wing1.x - tip.x, y: wing1.y - tip.y))
        let dir2 = normalized(CGPoint(x: wing2.x - tip.x, y: wing2.y - tip.y))
        guard magnitude(backward) > 0, magnitude(dir1) > 0, magnitude(dir2) > 0 else { return nil }

        let backwardDot1 = dot(dir1, backward)
        let backwardDot2 = dot(dir2, backward)
        guard backwardDot1 > 0.35, backwardDot2 > 0.35 else { return nil }

        let cross1 = cross(backward, dir1)
        let cross2 = cross(backward, dir2)
        guard cross1 * cross2 < 0 else { return nil }

        let angle1 = angleBetween(backward, dir1)
        let angle2 = angleBetween(backward, dir2)
        guard (18...78).contains(angle1), (18...78).contains(angle2) else { return nil }

        return .arrow(from: start, tip: tip, wing1: wing1, wing2: wing2)
    }

    private static func tryLine(_ pts: [CGPoint]) -> RecognizedShape? {
        guard let a = pts.first, let b = pts.last else { return nil }
        let len = hypot(b.x - a.x, b.y - a.y)
        guard len > 40 else { return nil }
        let maxPerp = pts.map { perpDist($0, a: a, b: b) }.max() ?? 0
        guard maxPerp < len * 0.12 else { return nil }
        return .line(from: a, to: b)
    }

    private static func tryCircle(_ pts: [CGPoint]) -> RecognizedShape? {
        // Reject strokes with multiple sharp corners — those are polygons.
        // (One stray corner is tolerated for noisy pencil input.)
        let corners = findCorners(pts, minSharpnessDeg: 35)
        guard corners.count < 2 else { return nil }

        let cx  = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
        let cy  = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
        let rs  = pts.map { hypot($0.x - cx, $0.y - cy) }
        let r   = rs.reduce(0, +) / CGFloat(rs.count)
        guard r > 20 else { return nil }
        let σ   = sqrt(rs.map { pow($0 - r, 2) }.reduce(0, +) / CGFloat(rs.count))
        // Tighter uniformity threshold — squares can squeak under 0.20
        guard σ / r < 0.17 else { return nil }
        // Must be roughly closed
        guard let a = pts.first, let b = pts.last,
              hypot(b.x - a.x, b.y - a.y) < r * 0.55 else { return nil }
        return .circle(center: CGPoint(x: cx, y: cy), radius: r)
    }

    private static func tryRectangle(_ pts: [CGPoint]) -> RecognizedShape? {
        // Require 3–6 corners — the defining feature of a polygon vs a circle.
        // minSharpnessDeg: 35 catches corners ≤ 145°, covering rounded hand-drawn corners.
        let corners = findCorners(pts, minSharpnessDeg: 35)
        guard corners.count >= 3, corners.count <= 6 else { return nil }

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
        guard Double(near.count) / Double(pts.count) > 0.75 else { return nil }
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

    private static func angleBetween(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let mag = magnitude(a) * magnitude(b)
        guard mag > 0 else { return 180 }
        return acos(max(-1, min(1, dot(a, b) / mag))) * 180 / .pi
    }

    private static func lerp(_ a: CGPoint, _ b: CGPoint, steps: Int) -> [CGPoint] {
        (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    static func rawPreviewPath(through points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private static func firstTailPeak(in values: [CGFloat], minimumHeight: CGFloat) -> Int? {
        guard values.count >= 5 else { return nil }

        for index in 1..<(values.count - 2) {
            if values[index] > minimumHeight,
               values[index] >= values[index - 1],
               values[index] >= values[index + 1] {
                return index
            }
        }

        return nil
    }

    private static func normalized(_ point: CGPoint) -> CGPoint {
        let len = magnitude(point)
        guard len > 0 else { return .zero }
        return CGPoint(x: point.x / len, y: point.y / len)
    }

    private static func magnitude(_ point: CGPoint) -> CGFloat {
        hypot(point.x, point.y)
    }

    private static func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        a.x * b.x + a.y * b.y
    }

    private static func cross(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        a.x * b.y - a.y * b.x
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
