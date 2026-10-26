import CoreGraphics

/// Transfers immutable decoded image data from background decoding tasks to SwiftUI.
struct SendableCGImage: @unchecked Sendable {
    let image: CGImage
}
