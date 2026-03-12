import SwiftUI
import PhotosUI
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data) -> Void

        init(onPick: @escaping (Data) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }

            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self = self,
                      let image = object as? UIImage,
                      let compressed = self.compressImage(image) else { return }
                DispatchQueue.main.async {
                    self.onPick(compressed)
                }
            }
        }

        /// Compress to max 800×800, JPEG 80% quality.
        private func compressImage(_ image: UIImage) -> Data? {
            let maxDim: CGFloat = 800
            let size = image.size
            let scale: CGFloat
            if size.width > maxDim || size.height > maxDim {
                scale = min(maxDim / size.width, maxDim / size.height)
            } else {
                scale = 1.0
            }
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            return resized.jpegData(compressionQuality: 0.8)
        }
    }
}
