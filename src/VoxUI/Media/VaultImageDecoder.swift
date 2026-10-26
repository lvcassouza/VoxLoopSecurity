import CoreGraphics
import Foundation
import ImageIO
#if canImport(VoxDomain)
import VoxDomain
#endif

enum VaultImageDecoder {
    private final class ProviderContext {
        let session: VaultMediaReadSession

        init(session: VaultMediaReadSession) {
            self.session = session
        }
    }

    static func thumbnail(from session: VaultMediaReadSession, maximumPixelSize: Int) throws -> CGImage {
        guard session.size > 0, session.size <= Int64(off_t.max), maximumPixelSize > 0 else {
            throw VaultError.dadoAdulterado
        }

        let context = Unmanaged.passRetained(ProviderContext(session: session))
        var callbacks = CGDataProviderDirectCallbacks(
            version: 0,
            getBytePointer: nil,
            releaseBytePointer: nil,
            getBytesAtPosition: { info, buffer, position, count in
                VaultImageDecoder.copyBytesAtPosition(info, buffer, position, count)
            },
            releaseInfo: { info in
                VaultImageDecoder.releaseContext(info)
            }
        )
        guard let provider = CGDataProvider(
            directInfo: context.toOpaque(),
            size: off_t(session.size),
            callbacks: &callbacks
        ) else {
            context.release()
            throw VaultError.dadoAdulterado
        }
        guard let source = CGImageSourceCreateWithDataProvider(provider, nil) else {
            throw VaultError.formatoDeMidiaNaoSuportado
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: NSNumber(value: true),
            kCGImageSourceCreateThumbnailWithTransform: NSNumber(value: true),
            kCGImageSourceShouldCacheImmediately: NSNumber(value: true),
            kCGImageSourceThumbnailMaxPixelSize: NSNumber(value: maximumPixelSize)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw VaultError.formatoDeMidiaNaoSuportado
        }
        return image
    }

    private static func copyBytesAtPosition(
        _ info: UnsafeMutableRawPointer?,
        _ buffer: UnsafeMutableRawPointer,
        _ position: off_t,
        _ count: Int
    ) -> Int {
        guard let info, position >= 0, count > 0 else { return 0 }
        let (end, overflow) = Int64(position).addingReportingOverflow(Int64(count))
        guard !overflow else { return 0 }
        let context = Unmanaged<ProviderContext>.fromOpaque(info).takeUnretainedValue()
        let target = UnsafeMutableRawBufferPointer(start: buffer, count: count)
        do {
            return try context.session.copyBytes(in: Int64(position)..<end, to: target)
        } catch {
            return 0
        }
    }

    private static func releaseContext(_ info: UnsafeMutableRawPointer?) {
        guard let info else { return }
        Unmanaged<ProviderContext>.fromOpaque(info).release()
    }
}
