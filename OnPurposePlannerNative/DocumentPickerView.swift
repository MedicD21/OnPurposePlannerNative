import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    var allowedContentTypes: [UTType] = [.item]
    var allowedFileExtensions: Set<String>? = nil
    var maxFileSizeBytes: Int = 25 * 1024 * 1024
    let onPick: (Data, String) -> Void
    var onError: ((String) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            allowedFileExtensions: allowedFileExtensions,
            maxFileSizeBytes: maxFileSizeBytes,
            onPick: onPick,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let allowedFileExtensions: Set<String>?
        let maxFileSizeBytes: Int
        let onPick: (Data, String) -> Void
        let onError: ((String) -> Void)?

        init(
            allowedFileExtensions: Set<String>?,
            maxFileSizeBytes: Int,
            onPick: @escaping (Data, String) -> Void,
            onError: ((String) -> Void)?
        ) {
            self.allowedFileExtensions = allowedFileExtensions?.map { $0.lowercased() }.reduce(into: Set<String>()) { partialResult, item in
                partialResult.insert(item)
            }
            self.maxFileSizeBytes = maxFileSizeBytes
            self.onPick = onPick
            self.onError = onError
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            let started = url.startAccessingSecurityScopedResource()
            defer {
                if started {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let ext = url.pathExtension.lowercased()
            if let allowedFileExtensions, !allowedFileExtensions.contains(ext) {
                DispatchQueue.main.async {
                    self.onError?("This file type is not supported here. Please choose a supported format.")
                }
                return
            }

            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if fileSize > maxFileSizeBytes {
                DispatchQueue.main.async {
                    self.onError?("File is too large. Please choose a file under \(self.maxFileSizeBytes / 1_048_576) MB.")
                }
                return
            }

            guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
                DispatchQueue.main.async {
                    self.onError?("Could not read this file. Please try another file.")
                }
                return
            }
            let filename = url.lastPathComponent
            DispatchQueue.main.async {
                self.onPick(data, filename)
            }
        }
    }
}
