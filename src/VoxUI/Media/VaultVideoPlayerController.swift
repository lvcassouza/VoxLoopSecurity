#if os(iOS)
import AVFoundation
import AVKit
import Combine
import Foundation
#if canImport(VoxDomain)
import VoxDomain
#endif

@MainActor
final class VaultVideoPlayerController: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var hasError = false

    private var resourceLoader: VaultVideoResourceLoader?
    private var statusObservation: NSKeyValueObservation?

    func prepare(using session: VaultMediaReadSession) {
        invalidate()
        let loader = VaultVideoResourceLoader(session: session)
        let asset = AVURLAsset(url: loader.resourceURL)
        asset.resourceLoader.setDelegate(loader, queue: loader.delegateQueue)

        let item = AVPlayerItem(asset: asset)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                self?.hasError = true
            }
        }
        resourceLoader = loader
        player = AVPlayer(playerItem: item)
        hasError = false
    }

    func invalidate() {
        player?.pause()
        player = nil
        statusObservation = nil
        resourceLoader?.invalidate()
        resourceLoader = nil
        hasError = false
    }

    func encerrarAposFalha() {
        player?.pause()
        player = nil
        statusObservation = nil
        resourceLoader?.invalidate()
        resourceLoader = nil
    }
}
#endif
