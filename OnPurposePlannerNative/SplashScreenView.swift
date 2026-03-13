import SwiftUI
import AVFoundation

struct SplashScreenView: View {
    let onFinished: () -> Void

    @StateObject private var controller = SplashScreenController()

    var body: some View {
        GeometryReader { geo in
            let cardSize = min(geo.size.width * 0.28, geo.size.height * 0.42, 340)
            let haloSize = cardSize + 44

            ZStack {
                splashBackground

                VStack(spacing: 28) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .fill(Color.white.opacity(0.34))
                            .frame(width: haloSize, height: haloSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 38, style: .continuous)
                                    .stroke(BrandPalette.indigo.opacity(0.10), lineWidth: 1)
                            )

                        Group {
                            if controller.showsVideo, let player = controller.player {
                                SplashVideoPlayerView(player: player)
                            } else {
                                Image("OnboardingIcon")
                                    .resizable()
                                    .interpolation(.high)
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: cardSize, height: cardSize)
                        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                        .shadow(color: BrandPalette.indigo.opacity(0.12), radius: 18, x: 0, y: 10)
                        .transition(.opacity)
                    }

                    VStack(spacing: 8) {
                        Text("OnPurpose Planner")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandPalette.indigo)
                        Text("Plan with intention. Write naturally.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(BrandPalette.indigo.opacity(0.66))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()
        }
        .task {
            controller.start(onFinished: onFinished)
        }
        .onDisappear {
            controller.stop()
        }
    }

    private var splashBackground: some View {
        ZStack {
            BrandPalette.base

            LinearGradient(
                colors: [
                    BrandPalette.base,
                    BrandPalette.base.opacity(0.96),
                    BrandPalette.paperGlow
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            BrandRibbonShape()
                .fill(BrandPalette.teal.opacity(0.50))
                .frame(width: 540, height: 124)
                .offset(x: -130, y: -250)

            BrandRibbonShape()
                .fill(BrandPalette.sage.opacity(0.52))
                .frame(width: 540, height: 124)
                .offset(x: -130, y: -82)

            BrandRibbonShape()
                .fill(BrandPalette.blush.opacity(0.52))
                .frame(width: 540, height: 124)
                .offset(x: -130, y: 88)

            BrandRibbonShape()
                .fill(BrandPalette.sand.opacity(0.55))
                .frame(width: 540, height: 124)
                .offset(x: -130, y: 258)

            Circle()
                .fill(BrandPalette.indigo.opacity(0.05))
                .frame(width: 520, height: 520)
                .blur(radius: 16)
                .offset(x: 310, y: -260)
        }
    }
}

@MainActor
private final class SplashScreenController: NSObject, ObservableObject {
    @Published var showsVideo = false

    var player: AVPlayer?

    private var started = false
    private var finished = false
    private var allowsVideoPromotion = true
    private var fallbackTask: Task<Void, Never>?
    private var readinessDeadlineTask: Task<Void, Never>?
    private var videoTimeoutTask: Task<Void, Never>?
    private var statusObservation: NSKeyValueObservation?
    private weak var currentItem: AVPlayerItem?
    private var finishHandler: (() -> Void)?

    func start(onFinished: @escaping () -> Void) {
        guard !started else { return }
        started = true
        finishHandler = onFinished

        // If the video is slow to become ready, keep the poster visible and
        // dismiss after the same splash duration instead of swapping late.
        fallbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.finish()
        }

        readinessDeadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.disableVideoPromotionIfNeeded()
        }

        guard let url = Bundle.main.url(forResource: "OPP_Splash", withExtension: "mp4") else { return }

        let item = AVPlayerItem(url: url)
        currentItem = item

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleItemStatus(item.status)
            }
        }
    }

    func stop() {
        cleanup()
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status) {
        guard allowsVideoPromotion, !showsVideo, !finished else { return }

        switch status {
        case .readyToPlay:
            beginVideoPlayback()
        case .failed:
            allowsVideoPromotion = false
        default:
            break
        }
    }

    private func beginVideoPlayback() {
        guard allowsVideoPromotion, let player else { return }

        allowsVideoPromotion = false
        showsVideo = true
        fallbackTask?.cancel()
        player.seek(to: .zero)
        player.play()

        videoTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            self?.finish()
        }
    }

    private func disableVideoPromotionIfNeeded() {
        guard !showsVideo else { return }
        allowsVideoPromotion = false
    }

    @objc private func handleVideoDidFinish() {
        Task { @MainActor [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        cleanup()
        finishHandler?()
    }

    private func cleanup() {
        fallbackTask?.cancel()
        fallbackTask = nil

        readinessDeadlineTask?.cancel()
        readinessDeadlineTask = nil

        videoTimeoutTask?.cancel()
        videoTimeoutTask = nil

        if let item = currentItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
        }

        statusObservation = nil
        currentItem = nil

        player?.pause()
        player = nil
    }
}

private struct SplashVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> SplashPlayerContainerView {
        let view = SplashPlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: SplashPlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class SplashPlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
