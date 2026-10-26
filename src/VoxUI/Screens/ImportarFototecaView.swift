import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Picker-based import. The picker grants access only to selections and leaves originals in Photos.
@MainActor
struct ImportarFototecaView: View {
    @ObservedObject var accessManager: VaultAccessManager
    @State private var selections: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importar arquivos de teste")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VoxColors.ink)

            Text("Escolha somente fotos e vídeos de teste. O seletor também permite mídia pessoal e o Vox não consegue distingui-la. Uma cópia cifrada é gravada no cofre; o original permanece na Fototeca.")
                .font(.system(size: 14))
                .foregroundColor(VoxColors.inkSecondary)

            PhotosPicker(
                selection: $selections,
                maxSelectionCount: 12,
                matching: .any(of: [.images, .videos]),
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                    Text("Escolher na Fototeca")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(VoxColors.brandText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(VoxColors.brand)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(importing)
            .onChange(of: selections) { _, newSelection in
                guard !newSelection.isEmpty else { return }
                Task { await importSelected(newSelection) }
            }

            if importing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Importando e verificando a cópia cifrada…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VoxColors.inkSecondary)
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(statusIsError ? VoxColors.danger : VoxColors.success)
                    .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(VoxColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VoxColors.border, lineWidth: 1))
    }

    @MainActor
    private func importSelected(_ selected: [PhotosPickerItem]) async {
        importing = true
        statusMessage = nil
        var importedCount = 0
        var failure: String?

        for item in selected {
            var temporaryCopy: URL?
            do {
                guard let file = try await item.loadTransferable(type: PickedMediaFile.self) else {
                    throw ImportError.unavailable
                }
                temporaryCopy = file.url
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                let mediaType: TipoDeMidia = isVideo ? .video : .foto
                let displayName = file.displayName.isEmpty
                    ? (mediaType == .video ? "Vídeo importado" : "Foto importada")
                    : file.displayName
                let duration = try await videoDuration(url: file.url, mediaType: mediaType)
                _ = try await accessManager.importarArquivo(
                    em: file.url,
                    nome: displayName,
                    tipo: mediaType,
                    duracao: duration
                )
                importedCount += 1
            } catch {
                failure = failure ?? error.localizedDescription
            }
            if let temporaryCopy { try? FileManager.default.removeItem(at: temporaryCopy) }
        }

        if let failure {
            statusIsError = true
            statusMessage = importedCount > 0
                ? "\(importedCount) item(ns) foram importados; o restante falhou: \(failure)"
                : "Não foi possível importar a seleção: \(failure)"
        } else if importedCount > 0 {
            statusIsError = false
            statusMessage = "\(importedCount) item(ns) foram cifrados e adicionados ao cofre. A origem continua na Fototeca."
        }
        selections = []
        importing = false
    }

    private func videoDuration(url: URL, mediaType: TipoDeMidia) async throws -> Double? {
        guard mediaType == .video else { return nil }
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(try await asset.load(.duration))
        return seconds.isFinite ? seconds : nil
    }

    private enum ImportError: LocalizedError {
        case unavailable
        var errorDescription: String? { "O item selecionado não ficou disponível para leitura." }
    }
}

private struct PickedMediaFile: Transferable, Sendable {
    let url: URL
    let displayName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            let suffix = received.file.pathExtension
            let name = UUID().uuidString + (suffix.isEmpty ? ".import" : ".\(suffix)")
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try FileManager.default.copyItem(at: received.file, to: destination)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
            #endif
            return PickedMediaFile(url: destination, displayName: received.file.lastPathComponent)
        }
    }
}
