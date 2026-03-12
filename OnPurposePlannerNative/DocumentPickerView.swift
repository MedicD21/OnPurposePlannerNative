import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Data, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data, String) -> Void

        init(onPick: @escaping (Data, String) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  let data = try? Data(contentsOf: url) else { return }
            let filename = url.lastPathComponent
            DispatchQueue.main.async {
                self.onPick(data, filename)
            }
        }
    }
}
