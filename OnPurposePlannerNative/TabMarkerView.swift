import SwiftUI

// MARK: - Flag shape: rounded-left rectangle + chevron right

struct TabFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tip = max(10, rect.width * 0.12)
        let r = min(rect.height * 0.24, 8)

        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,       y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r,   y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Tab marker view

struct TabMarkerView: View {
    @ObservedObject var store: PlannerStore
    let markerId: UUID

    @State private var showControls = false

    private var marker: TabMarker? {
        store.tabMarkers.first { $0.id == markerId }
    }

    var body: some View {
        if let marker = marker {
            ZStack(alignment: .top) {
                // Controls bar — floats above the tab when visible
                if showControls {
                    controlsBar(marker: marker)
                        .offset(y: -(22))
                        .zIndex(10)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                // Tab flag
                ZStack {
                    TabFlagShape()
                        .fill(marker.colorKey.fill)
                    TabFlagShape()
                        .stroke(marker.colorKey.border, lineWidth: 1)

                    // Drawing canvas — pencil writing on the tab
                    DrawingCanvasView(pageId: marker.drawingPageId, store: store)
                        .frame(
                            width: TabMarker.width * 0.72,
                            height: TabMarker.height * 0.72
                        )
                        .offset(x: -(TabMarker.width * 0.07))
                        .clipShape(Rectangle())
                }
                .frame(width: TabMarker.width, height: TabMarker.height)
                .clipShape(TabFlagShape())
                .shadow(color: .black.opacity(0.14), radius: 3, x: 1, y: 2)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showControls.toggle()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: showControls)
        }
    }

    // MARK: - Controls bar

    private func controlsBar(marker: TabMarker) -> some View {
        HStack(spacing: 8) {
            // Color picker dots
            ForEach(TabColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.fill)
                    .overlay(
                        Circle().stroke(
                            marker.colorKey == color ? color.border : Color.clear,
                            lineWidth: 2)
                    )
                    .frame(width: 18, height: 18)
                    .onTapGesture {
                        store.mutateTabMarker(id: markerId) { $0.colorKey = color }
                    }
            }

            Divider().frame(height: 16)

            // Delete
            Button {
                store.deleteTabMarker(id: markerId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.red.opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }
}
