import SwiftUI

struct StickyNoteView: View {
    @ObservedObject var store: PlannerStore
    let noteId: UUID

    @State private var dragOffset: CGSize = .zero

    private var note: StickyNote? {
        store.stickyNotes.first { $0.id == noteId }
    }

    var body: some View {
        if let note = note {
            VStack(spacing: 0) {
                // Header bar
                headerBar(note: note)

                // Body (drawing canvas) — hidden when collapsed
                if !note.isCollapsed {
                    DrawingCanvasView(pageId: note.drawingPageId, store: store)
                        .frame(width: note.width, height: note.height - StickyNote.headerHeight)
                        .background(note.colorKey.face)
                }
            }
            .offset(dragOffset)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 6, x: 2, y: 3)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerBar(note: StickyNote) -> some View {
        HStack(spacing: 4) {
            // Color dots
            ForEach(StickyColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.face)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    .frame(width: 14, height: 14)
                    .onTapGesture {
                        store.mutateStickyNote(id: noteId) { $0.colorKey = color }
                    }
            }

            Spacer()

            // Collapse / expand button
            Button {
                store.mutateStickyNote(id: noteId) { $0.isCollapsed.toggle() }
            } label: {
                Image(systemName: note.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 22, height: 22)
            }

            // Delete button
            Button {
                store.deleteStickyNote(id: noteId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: StickyNote.headerHeight)
        .background(note.colorKey.header)
        // Drag gesture only on header
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    store.mutateStickyNote(id: noteId) { n in
                        n.x += value.translation.width
                        n.y += value.translation.height
                    }
                    dragOffset = .zero
                }
        )
    }
}
