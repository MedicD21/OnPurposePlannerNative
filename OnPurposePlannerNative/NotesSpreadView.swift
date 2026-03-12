import SwiftUI
import PencilKit

struct NotesSpreadView: View {
    @ObservedObject var store: PlannerStore

    private var leftWidth:  CGFloat { PlannerTheme.leftPaperWidth }
    private var rightWidth: CGFloat { PlannerTheme.rightPaperWidth }
    private var height:     CGFloat { PlannerTheme.spreadHeight }

    var body: some View {
        HStack(spacing: 0) {
            notesLeft
            divider
            notesRight
        }
        .frame(width: PlannerTheme.spreadWidth, height: height)
    }

    // MARK: - Left paper: ruled lines

    private var notesLeft: some View {
        ZStack(alignment: .topLeading) {
            PlannerTheme.paper

            VStack(alignment: .leading, spacing: 0) {
                Text("NOTES")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(PlannerTheme.ink)
                    .padding(.top, 32)
                    .padding(.leading, 32)

                Rectangle()
                    .fill(PlannerTheme.line)
                    .frame(height: 1)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                // 24 ruled lines
                ruledLines(count: 24)
                    .padding(.top, 16)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .frame(width: leftWidth, height: height)

            DrawingCanvasView(
                pageId: store.pageId(for: .notes, side: .left),
                store:  store
            )
            .frame(width: leftWidth, height: height)
        }
        .frame(width: leftWidth, height: height)
        .clipped()
    }

    private func ruledLines(count: Int) -> some View {
        let lineSpacing: CGFloat = 36
        let totalHeight = CGFloat(count) * lineSpacing
        return Canvas { ctx, size in
            for i in 0..<count {
                let y    = CGFloat(i) * lineSpacing + lineSpacing
                let path = Path { p in
                    p.move(to:    CGPoint(x: 0,          y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(path, with: .color(PlannerTheme.line), lineWidth: 0.5)
            }
        }
        .frame(height: totalHeight)
    }

    // MARK: - Right paper: dot grid

    private var notesRight: some View {
        ZStack(alignment: .topLeading) {
            PlannerTheme.paper

            VStack(alignment: .leading, spacing: 0) {
                Text("IDEAS")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(PlannerTheme.ink)
                    .padding(.top, 32)
                    .padding(.leading, 24)

                Rectangle()
                    .fill(PlannerTheme.line)
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                dotGrid
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .frame(width: rightWidth, height: height)

            DrawingCanvasView(
                pageId: store.pageId(for: .notes, side: .right),
                store:  store
            )
            .frame(width: rightWidth, height: height)
        }
        .frame(width: rightWidth, height: height)
        .clipped()
    }

    private var dotGrid: some View {
        let spacing: CGFloat = 20
        return Canvas { ctx, size in
            let cols = Int(size.width  / spacing)
            let rows = Int(size.height / spacing)
            for row in 0...rows {
                for col in 0...cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let dot = Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                    ctx.fill(dot, with: .color(PlannerTheme.dot))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(PlannerTheme.line)
            .frame(width: 1, height: height)
    }
}
