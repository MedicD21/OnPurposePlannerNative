import SwiftUI
import UIKit
import QuickLookThumbnailing

struct AttachmentView: View {
    @ObservedObject var store: PlannerStore
    let attachmentId: UUID

    @State private var showControls = false
    @State private var previewURL: URL?

    private var attachment: PageAttachment? {
        store.attachments.first { $0.id == attachmentId }
    }

    var body: some View {
        if let attachment = attachment {
            attachmentContent(attachment)
                .frame(width: attachment.width, height: attachment.height)
                .contentShape(Rectangle())
                // Delete button — top-right, visible only when controls shown
                .overlay(alignment: .topTrailing) {
                    if showControls {
                        Button {
                            store.deleteAttachment(id: attachmentId)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .topLeading) {
                    if showControls,
                       case .file(let data, let filename) = attachment.kind {
                        Button {
                            openFile(data: data, filename: filename)
                        } label: {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: -8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                // Resize handle — bottom-right, visible only when controls shown
                .overlay(alignment: .bottomTrailing) {
                    if showControls {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                // Selection ring when controls are shown
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(showControls ? 0.7 : 0), lineWidth: 2)
                )
                .background(
                    DocumentInteractionRepresentable(url: $previewURL)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showControls.toggle()
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: showControls)
        }
    }

    @ViewBuilder
    private func attachmentContent(_ attachment: PageAttachment) -> some View {
        switch attachment.kind {
        case .photo(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 3)
            }

        case .file(let data, let filename):
            FileAttachmentCardView(
                attachmentId: attachment.id,
                data: data,
                filename: filename
            )
        }
    }

    private func openFile(data: Data, filename: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try? data.write(to: url, options: .atomic)
        previewURL = url
    }
}

// MARK: - File Card View

struct FileAttachmentCardView: View {
    let attachmentId: UUID
    let data: Data
    let filename: String

    @State private var previewImage: UIImage?
    @State private var previewRequestID = UUID()

    private static let previewCache = NSCache<NSString, UIImage>()
    private static let previewDeadline: TimeInterval = 0.25

    var body: some View {
        ZStack {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholderCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(PlannerTheme.tab)
                .shadow(color: .black.opacity(0.14), radius: 5, x: 1, y: 2)
        )
        .task(id: attachmentId) {
            loadPreviewIfFast()
        }
    }

    private var placeholderCard: some View {
        VStack(spacing: 8) {
            Image(systemName: sfSymbol(for: filename))
                .font(.system(size: 40))
                .foregroundStyle(PlannerTheme.cover)

            Text(filename)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PlannerTheme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlannerTheme.tab)
    }

    @MainActor
    private func loadPreviewIfFast() {
        let cacheKey = attachmentId.uuidString
        if let cachedImage = Self.previewCache.object(forKey: cacheKey as NSString) {
            previewImage = cachedImage
            return
        }

        previewImage = nil
        let requestID = UUID()
        previewRequestID = requestID

        let previewURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-preview-\(attachmentId.uuidString)-\(filename)")
        guard (try? data.write(to: previewURL, options: .atomic)) != nil else { return }

        let request = QLThumbnailGenerator.Request(
            fileAt: previewURL,
            size: CGSize(width: 600, height: 600),
            scale: UIScreen.main.scale,
            representationTypes: .thumbnail
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.previewDeadline) {
            guard previewRequestID == requestID,
                  previewImage == nil else { return }
            previewRequestID = UUID()
        }

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            guard let image = thumbnail?.uiImage else { return }

            DispatchQueue.main.async {
                guard previewRequestID == requestID else { return }
                Self.previewCache.setObject(image, forKey: cacheKey as NSString)
                previewImage = image
            }
        }
    }

    private func sfSymbol(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":                           return "doc.richtext"
        case "doc", "docx":                  return "doc.text"
        case "xls", "xlsx":                  return "tablecells"
        case "ppt", "pptx":                  return "rectangle.on.rectangle"
        case "jpg", "jpeg", "png", "gif",
             "heic", "tiff", "webp":         return "photo"
        case "mp4", "mov", "avi":            return "video"
        case "mp3", "m4a", "wav", "aac":     return "music.note"
        case "zip", "tar", "gz":             return "archivebox"
        case "txt":                          return "doc.plaintext"
        case "html", "htm":                  return "globe"
        default:                             return "doc"
        }
    }
}

// MARK: - Document Interaction Representable

private struct DocumentInteractionRepresentable: UIViewControllerRepresentable {
    @Binding var url: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        guard let url = url else { return }
        let controller = UIDocumentInteractionController(url: url)
        controller.delegate = context.coordinator
        context.coordinator.controller = controller
        DispatchQueue.main.async {
            controller.presentPreview(animated: true)
        }
    }

    class Coordinator: NSObject, UIDocumentInteractionControllerDelegate {
        var controller: UIDocumentInteractionController?

        func documentInteractionControllerViewControllerForPreview(
            _ controller: UIDocumentInteractionController
        ) -> UIViewController {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else {
                return UIViewController()
            }
            return root
        }
    }
}
