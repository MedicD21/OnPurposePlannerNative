import SwiftUI

struct StickyNoteView: View {
    @ObservedObject var store: PlannerStore
    let noteId: UUID

    private var note: StickyNote? {
        store.stickyNotes.first { $0.id == noteId }
    }

    var body: some View {
        if let note = note {
            VStack(spacing: 0) {
                headerBar(note: note)
                if !note.isCollapsed {
                    DrawingCanvasView(pageId: note.drawingPageId, store: store)
                        .frame(width: note.width, height: note.height - StickyNote.headerHeight)
                        .background(note.colorKey.face)
                }
            }
            // No .offset(dragOffset) — dragging is handled by the UIKit
            // UIPanGestureRecognizer in PlannerSpreadContainerView.Coordinator,
            // which directly updates note.x / note.y in the store.
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 3)
        }
    }

    // MARK: - Header bar (colour picker + collapse + delete)
    // Drag gesture removed — the UIKit gesture recogniser in the scroll-view
    // coordinator detects header-area touches and drives the drag.

    @ViewBuilder
    private func headerBar(note: StickyNote) -> some View {
        HStack(spacing: 4) {
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

            // Drag-handle indicator (visual only)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))

            Spacer()

            Button {
                store.mutateStickyNote(id: noteId) { $0.isCollapsed.toggle() }
            } label: {
                Image(systemName: note.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 22, height: 22)
            }

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
    }
}
