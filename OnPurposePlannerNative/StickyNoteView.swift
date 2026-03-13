import PencilKit
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
                noteBody(note: note)
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
        HStack(spacing: note.isCollapsed ? 6 : 4) {
            if note.isCollapsed {
                Circle()
                    .fill(note.colorKey.face)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    .frame(width: 12, height: 12)
            } else {
                ForEach(StickyColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(color.face)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                        .frame(width: 14, height: 14)
                        .onTapGesture {
                            store.mutateStickyNote(id: noteId) { $0.colorKey = color }
                        }
                }
            }

            Spacer(minLength: 0)

            // Drag-handle indicator (visual only)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.6))

            Spacer(minLength: 0)

            headerButton(systemName: note.isCollapsed ? "chevron.down" : "chevron.up") {
                store.mutateStickyNote(id: noteId) { $0.isCollapsed.toggle() }
            }

            headerButton(systemName: "xmark") {
                store.deleteStickyNote(id: noteId)
            }
        }
        .padding(.horizontal, note.isCollapsed ? 8 : 6)
        .frame(height: StickyNote.headerHeight)
        .background(note.colorKey.header)
    }

    @ViewBuilder
    private func noteBody(note: StickyNote) -> some View {
        if note.isCollapsed {
            collapsedPreview(note: note)
        } else {
            DrawingCanvasView(pageId: note.drawingPageId, store: store)
                .frame(width: note.displayWidth, height: note.bodyHeight)
                .background(note.colorKey.face)
        }
    }

    private func collapsedPreview(note: StickyNote) -> some View {
        let drawing = store.drawing(forPageId: note.drawingPageId)
        let previewRect = collapsedPreviewRect(for: drawing, note: note)
        let previewImage = drawing.image(from: previewRect, scale: UIScreen.main.scale)

        return ZStack {
            note.colorKey.face

            if !drawing.bounds.isEmpty {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
        }
        .frame(width: note.displayWidth, height: note.bodyHeight)
    }

    private func collapsedPreviewRect(for drawing: PKDrawing, note: StickyNote) -> CGRect {
        let noteBodyRect = CGRect(origin: .zero, size: CGSize(width: note.width, height: note.height - StickyNote.headerHeight))
        guard !drawing.bounds.isEmpty else { return noteBodyRect }

        let paddedBounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        let previewRect = paddedBounds.intersection(noteBodyRect)
        return previewRect.isNull || previewRect.isEmpty ? noteBodyRect : previewRect
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 22, height: 22)
        }
    }
}
