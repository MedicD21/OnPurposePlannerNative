import SwiftUI
import UIKit

struct ZoomableView<Content: View>: UIViewRepresentable {
    var contentSize: CGSize
    var minScale: CGFloat = 0.25
    var maxScale: CGFloat = 4.0
    @Binding var zoomScale: CGFloat
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate                       = context.coordinator
        scrollView.minimumZoomScale               = minScale
        scrollView.maximumZoomScale               = maxScale
        scrollView.zoomScale                      = zoomScale
        scrollView.bouncesZoom                    = true
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor                = UIColor(PlannerTheme.paper)

        // Host the SwiftUI content
        let hostingController = UIHostingController(rootView: content())
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.widthAnchor.constraint(equalToConstant:  contentSize.width),
            hostingController.view.heightAnchor.constraint(equalToConstant: contentSize.height),
            hostingController.view.topAnchor.constraint(equalTo:  scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor)
        ])

        context.coordinator.hostingController = hostingController
        context.coordinator.scrollView        = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self

        // Update content if needed
        if let hc = context.coordinator.hostingController {
            hc.rootView = content()
        }

        // Keep scroll view scale in sync if externally changed
        if abs(scrollView.zoomScale - zoomScale) > 0.001 {
            scrollView.setZoomScale(zoomScale, animated: false)
        }

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = maxScale
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableView
        weak var scrollView: UIScrollView?
        var hostingController: UIHostingController<Content>?

        init(parent: ZoomableView) {
            self.parent = parent
        }

        // Required for zoom to work
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
            DispatchQueue.main.async {
                self.parent.zoomScale = scrollView.zoomScale
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            DispatchQueue.main.async {
                self.parent.zoomScale = scale
            }
        }

        private func centerContent(in scrollView: UIScrollView) {
            guard let contentView = hostingController?.view else { return }
            let offsetX = max((scrollView.bounds.width  - contentView.frame.width  * scrollView.zoomScale) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - contentView.frame.height * scrollView.zoomScale) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }
    }
}
