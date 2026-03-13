import PencilKit
import CoreGraphics

struct ScratchOutRecognizer {
    static func targetStrokeIndices(for scratchStroke: PKStroke, in strokes: [PKStroke]) -> [Int] {
        let scratchPoints = collectPoints(scratchStroke)
        guard isScratchOutStroke(scratchPoints) else { return [] }

        let scratchBounds = bounds(for: scratchPoints).insetBy(dx: -14, dy: -14)
        let scratchSegments = segments(from: scratchPoints)
        guard !scratchSegments.isEmpty else { return [] }

        return strokes.enumerated().compactMap { index, stroke in
            guard stroke.renderBounds.insetBy(dx: -14, dy: -14).intersects(scratchBounds) else { return nil }

            let targetPoints = samplePoints(collectPoints(stroke), maxPoints: 80)
            guard !targetPoints.isEmpty else { return nil }

            let threshold = max(8, ShapeRecognizer.averageStrokeWidth(stroke) * 1.8 + 4)
            let closeCount = targetPoints.filter {
                pointDistanceToSegments($0, segments: scratchSegments) <= threshold
            }.count
            let required = max(3, Int(ceil(Double(targetPoints.count) * 0.22)))

            return closeCount >= required ? index : nil
        }
    }

    private static func isScratchOutStroke(_ points: [CGPoint]) -> Bool {
        guard points.count >= 18 else { return false }

        let rect = bounds(for: points)
        guard rect.width > 18, rect.height > 12 else { return false }

        let diagonal = max(hypot(rect.width, rect.height), 1)
        let length = polylineLength(points)
        guard length / diagonal > 4.2 else { return false }

        guard let first = points.first, let last = points.last else { return false }
        guard hypot(last.x - first.x, last.y - first.y) > diagonal * 0.28 else { return false }

        let reversals = axisReversals(points)
        guard reversals.horizontal + reversals.vertical >= 6 else { return false }

        return sharpTurnCount(points) >= 8
    }

    private static func collectPoints(_ stroke: PKStroke) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(64)
        for point in stroke.path {
            points.append(point.location)
        }
        return points
    }

    private static func samplePoints(_ points: [CGPoint], maxPoints: Int) -> [CGPoint] {
        guard points.count > maxPoints, maxPoints > 0 else { return points }

        let stride = max(1, points.count / maxPoints)
        var sampled: [CGPoint] = []
        sampled.reserveCapacity(maxPoints + 1)

        for index in Swift.stride(from: 0, to: points.count, by: stride) {
            sampled.append(points[index])
        }

        if let last = points.last, sampled.last != last {
            sampled.append(last)
        }

        return sampled
    }

    private static func bounds(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }

        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func polylineLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { length, pair in
            length + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
        }
    }

    private static func axisReversals(_ points: [CGPoint]) -> (horizontal: Int, vertical: Int) {
        let threshold: CGFloat = 3
        var horizontal = 0
        var vertical = 0
        var lastXSign = 0
        var lastYSign = 0

        for pair in zip(points, points.dropFirst()) {
            let dx = pair.1.x - pair.0.x
            let dy = pair.1.y - pair.0.y

            let xSign = directionSign(dx, threshold: threshold)
            if xSign != 0, lastXSign != 0, xSign != lastXSign {
                horizontal += 1
            }
            if xSign != 0 {
                lastXSign = xSign
            }

            let ySign = directionSign(dy, threshold: threshold)
            if ySign != 0, lastYSign != 0, ySign != lastYSign {
                vertical += 1
            }
            if ySign != 0 {
                lastYSign = ySign
            }
        }

        return (horizontal, vertical)
    }

    private static func sharpTurnCount(_ points: [CGPoint]) -> Int {
        guard points.count > 4 else { return 0 }

        var count = 0
        let stride = max(1, points.count / 24)

        for index in stride ..< points.count - stride {
            let a = points[index - stride]
            let b = points[index]
            let c = points[index + stride]

            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let bc = CGPoint(x: c.x - b.x, y: c.y - b.y)
            let mag = hypot(ab.x, ab.y) * hypot(bc.x, bc.y)
            guard mag > 0 else { continue }

            let dot = max(-1 as CGFloat, min(1 as CGFloat, (ab.x * bc.x + ab.y * bc.y) / mag))
            let angle = acos(dot) * 180 / .pi
            if angle < 120 {
                count += 1
            }
        }

        return count
    }

    private static func segments(from points: [CGPoint]) -> [(CGPoint, CGPoint)] {
        zip(points, points.dropFirst()).map { ($0.0, $0.1) }
    }

    private static func pointDistanceToSegments(_ point: CGPoint, segments: [(CGPoint, CGPoint)]) -> CGFloat {
        segments.reduce(.greatestFiniteMagnitude) { best, segment in
            min(best, pointDistanceToSegment(point, start: segment.0, end: segment.1))
        }
    }

    private static func pointDistanceToSegment(_ point: CGPoint, start: CGPoint, end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0 as CGFloat, min(1 as CGFloat,
            ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        ))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private static func directionSign(_ value: CGFloat, threshold: CGFloat) -> Int {
        if value > threshold { return 1 }
        if value < -threshold { return -1 }
        return 0
    }
}
