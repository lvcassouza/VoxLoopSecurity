import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif
#if canImport(VoxUI)
import VoxUI
#endif

@main
struct VoxApp: App {
    @StateObject private var accessManager = VaultAccessManager()

    var body: some Scene {
        WindowGroup {
            AppRootView(accessManager: accessManager)
        }
    }
}
