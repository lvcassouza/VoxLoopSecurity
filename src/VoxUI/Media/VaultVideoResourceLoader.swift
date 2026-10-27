#if os(iOS)
import AVFoundation
import CoreGraphics
import Foundation
import UniformTypeIdentifiers
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Feeds AVFoundation authenticated byte ranges without materializing a clear video file.
final class VaultVideoResourceLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    let delegateQueue = DispatchQueue(label: "com.voxloop.vox.vault-video-loader", qos: .userInitiated)
    let resourceURL: URL

    private let session: VaultMediaReadSession
    private let contentType: String
    private let stateLock = NSLock()
    private let requestQueue = DispatchQueue(label: "com.voxloop.vox.vault-video-reads", qos: .userInitiated, attributes: .concurrent)
    private var isValid = true
    private var activeRequests: [ObjectIdentifier: RequestCancellation] = [:]

    private final class RequestCancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }

    init(session: VaultMediaReadSession) {
        self.session = session
        let extensionName = URL(fileURLWithPath: session.item.nomeOriginal).pathExtension
        let inferredType = UTType(filenameExtension: extensionName)
        if let inferredType, inferredType.conforms(to: .movie) {
            self.contentType = inferredType.identifier
        } else {
            self.contentType = UTType.movie.identifier
        }

        var components = URLComponents()
        components.scheme = "voxvault"
        components.host = "item"
        let safeExtension = extensionName.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let fileExtension = safeExtension.isEmpty ? "mov" : safeExtension
        components.path = "/\(session.item.id.uuidString)/\(UUID().uuidString).\(fileExtension)"
        self.resourceURL = components.url ?? URL(string: "voxvault://item/\(session.item.id.uuidString).mov")!
        super.init()
    }

    static func thumbnail(from session: VaultMediaReadSession) async throws -> CGImage {
        let loader = VaultVideoResourceLoader(session: session)
        defer { loader.invalidate() }
        let asset = AVURLAsset(url: loader.resourceURL)
        asset.resourceLoader.setDelegate(loader, queue: loader.delegateQueue)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let (image, _) = try await generator.image(at: CMTime(seconds: 0, preferredTimescale: 600))
        return image
    }

    func invalidate() {
        stateLock.lock()
        isValid = false
        let requests = Array(activeRequests.values)
        activeRequests.removeAll(keepingCapacity: false)
        stateLock.unlock()
        requests.forEach { $0.cancel() }
        session.invalidate()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard valid else {
            finish(loadingRequest, with: VaultError.cofreBloqueado)
            return true
        }
        let cancellation = RequestCancellation()
        let requestID = ObjectIdentifier(loadingRequest)
        stateLock.lock()
        activeRequests[requestID] = cancellation
        stateLock.unlock()
        requestQueue.async { [weak self, loadingRequest, cancellation] in
            guard let self else { return }
            defer { self.removeRequest(requestID) }
            do {
                guard !cancellation.isCancelled, self.valid else { throw VaultError.cofreBloqueado }
                if let information = loadingRequest.contentInformationRequest {
                    information.contentType = self.contentType
                    information.contentLength = self.session.size
                    information.isByteRangeAccessSupported = true
                }
                if let dataRequest = loadingRequest.dataRequest {
                    try self.fulfill(dataRequest, cancellation: cancellation)
                }
                guard !cancellation.isCancelled, self.valid else { throw VaultError.cofreBloqueado }
                loadingRequest.finishLoading()
            } catch {
                if !cancellation.isCancelled { self.finish(loadingRequest, with: error) }
            }
        }
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        stateLock.lock()
        let token = activeRequests[ObjectIdentifier(loadingRequest)]
        stateLock.unlock()
        token?.cancel()
    }

    private var valid: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isValid
    }

    private func fulfill(_ request: AVAssetResourceLoadingDataRequest, cancellation: RequestCancellation) throws {
        guard request.requestedOffset >= 0, request.requestedLength >= 0 else {
            throw VaultError.intervaloDeLeituraInvalido
        }
        var cursor = request.currentOffset == 0 && request.requestedOffset > 0
            ? request.requestedOffset
            : request.currentOffset
        guard cursor >= 0, cursor <= session.size else { throw VaultError.intervaloDeLeituraInvalido }

        let end: Int64
        if request.requestsAllDataToEndOfResource {
            end = session.size
        } else {
            let alreadyProvided = max(0, cursor - request.requestedOffset)
            let remaining = max(0, Int64(request.requestedLength) - alreadyProvided)
            let (requestedEnd, overflow) = cursor.addingReportingOverflow(remaining)
            guard !overflow else { throw VaultError.intervaloDeLeituraInvalido }
            end = min(session.size, requestedEnd)
        }

        while cursor < end {
            guard !cancellation.isCancelled, valid else { throw VaultError.cofreBloqueado }
            let amount = min(end - cursor, Int64(VaultMediaReadSession.maximumReadSize))
            let next = cursor + amount
            let bytes = try session.read(range: cursor..<next)
            request.respond(with: bytes)
            cursor = next
        }
    }

    private func finish(_ request: AVAssetResourceLoadingRequest, with error: Error) {
        let safeError = NSError(
            domain: "VoxVaultMedia",
            code: (error as? VaultError) == .cofreBloqueado ? 1 : 2,
            userInfo: [NSLocalizedDescriptionKey: "Não foi possível carregar este vídeo."]
        )
        request.finishLoading(with: safeError)
    }

    private func removeRequest(_ id: ObjectIdentifier) {
        stateLock.lock()
        activeRequests.removeValue(forKey: id)
        stateLock.unlock()
    }
}
#endif
