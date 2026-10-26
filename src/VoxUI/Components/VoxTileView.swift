import CoreGraphics
import SwiftUI
#if os(iOS)
import AVFoundation
#endif
#if canImport(VoxDomain)
import VoxDomain
#endif

/// In-memory thumbnail tile. It opens an authenticated read session only while the vault is unlocked.
public struct VoxTileView: View {
    public let item: ItemDoCofre
    public let accessManager: VaultAccessManager
    public let isSelecionado: Bool
    public let modoSelecao: Bool
    public let aoTocar: () -> Void

    @State private var thumbnail: CGImage?
    @State private var thumbnailFailed = false

    public init(
        item: ItemDoCofre,
        accessManager: VaultAccessManager,
        isSelecionado: Bool = false,
        modoSelecao: Bool = false,
        aoTocar: @escaping () -> Void
    ) {
        self.item = item
        self.accessManager = accessManager
        self.isSelecionado = isSelecionado
        self.modoSelecao = modoSelecao
        self.aoTocar = aoTocar
    }

    public var body: some View {
        Button(action: aoTocar) {
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: item.corSinteticaHex),
                                Color(hex: item.corSinteticaHex).opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fill)

                if let thumbnail {
                    Image(decorative: thumbnail, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                } else {
                    Image(systemName: thumbnailFailed ? "exclamationmark.triangle" : (item.tipo == .video ? "play.fill" : "photo"))
                        .font(.system(size: thumbnailFailed ? 20 : 28, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }

                if item.status == .adulterado {
                    ZStack {
                        Color.black.opacity(0.72)
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(VoxColors.danger)
                                .font(.system(size: 20))
                            Text("Indisponível")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }

                if item.tipo == .video, let duracao = item.duracaoFormatada {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text(duracao)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.72))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .padding(5)
                }

                if modoSelecao {
                    VStack {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(isSelecionado ? VoxColors.brand : Color.black.opacity(0.45))
                                    .frame(width: 24, height: 24)
                                if isSelecionado {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(VoxColors.brandText)
                                }
                            }
                            .padding(6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelecionado ? VoxColors.brand : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(item.tipo == .video ? "Vídeo" : "Foto"), \(item.dataCriacao.formatted(date: .abbreviated, time: .omitted)), \(thumbnailFailed ? "prévia indisponível" : "item do cofre")\(modoSelecao ? (isSelecionado ? ", selecionado" : ", não selecionado") : "")"
        )
        .accessibilityAddTraits(modoSelecao && isSelecionado ? .isSelected : [])
        .task(id: accessManager.estadoAcesso) {
            await carregarMiniatura()
        }
        .onChange(of: accessManager.estadoAcesso) { _, novoEstado in
            if novoEstado != .desbloqueado {
                thumbnail = nil
                thumbnailFailed = false
            }
        }
        .onDisappear {
            thumbnail = nil
        }
    }

    @MainActor
    private func carregarMiniatura() async {
        guard accessManager.estadoAcesso == .desbloqueado,
              !accessManager.cortinaPrivacidadeAtiva,
              item.status != .adulterado else { return }
        do {
            let session = try await accessManager.abrirSessaoDeLeitura(id: item.id)
            defer { accessManager.fecharSessaoDeLeitura(id: session.sessionID) }
            let image = try await Task.detached(priority: .utility) {
                let cgImage: CGImage
                #if os(iOS)
                if session.item.tipo == .video {
                    cgImage = try await VaultVideoResourceLoader.thumbnail(from: session)
                } else {
                    cgImage = try VaultImageDecoder.thumbnail(from: session, maximumPixelSize: 512)
                }
                #else
                guard session.item.tipo == .foto else { throw VaultError.formatoDeMidiaNaoSuportado }
                cgImage = try VaultImageDecoder.thumbnail(from: session, maximumPixelSize: 512)
                #endif
                return SendableCGImage(image: cgImage)
            }.value.image
            guard !Task.isCancelled,
                  accessManager.estadoAcesso == .desbloqueado,
                  !accessManager.cortinaPrivacidadeAtiva else { return }
            thumbnail = image
            thumbnailFailed = false
        } catch {
            guard !Task.isCancelled, accessManager.estadoAcesso == .desbloqueado else { return }
            thumbnail = nil
            thumbnailFailed = true
        }
    }
}

private struct SendableCGImage: @unchecked Sendable {
    let image: CGImage
}
