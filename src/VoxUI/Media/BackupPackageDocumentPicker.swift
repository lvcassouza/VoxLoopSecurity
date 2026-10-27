import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

public enum VoxBackupFileType {
    public static let package = UTType(exportedAs: "com.voxloop.voxbackup", conformingTo: .package)
}

#if os(iOS)
/// Exports the prepared directory as a copy through the system document picker.
struct BackupPackageDocumentPicker: UIViewControllerRepresentable {
    let exporting: URL
    let onCompletion: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCompletion: onCompletion) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [exporting], asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (Bool) -> Void
        private var didComplete = false

        init(onCompletion: @escaping (Bool) -> Void) { self.onCompletion = onCompletion }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            complete(!urls.isEmpty)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            complete(false)
        }

        private func complete(_ success: Bool) {
            guard !didComplete else { return }
            didComplete = true
            onCompletion(success)
        }
    }
}
#else
struct BackupPackageDocumentPicker: View {
    let exporting: URL
    let onCompletion: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.forward")
            Text("A exportação de pacotes está disponível no app iOS.")
        }
        .padding(32)
        .onDisappear { onCompletion(false) }
    }
}
#endif
