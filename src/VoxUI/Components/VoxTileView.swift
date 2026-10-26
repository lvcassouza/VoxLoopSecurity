import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Miniatura da grade de fotos e vídeos (seção 6.5 de ui-visual-spec.md).
/// Proporção quadrada 1:1, raio 6pt, badge de duração para vídeos e indicador de seleção.
public struct VoxTileView: View {
    public let item: ItemDoCofre
    public let isSelecionado: Bool
    public let modoSelecao: Bool
    public let aoTocar: () -> Void

    public init(
        item: ItemDoCofre,
        isSelecionado: Bool = false,
        modoSelecao: Bool = false,
        aoTocar: @escaping () -> Void
    ) {
        self.item = item
        self.isSelecionado = isSelecionado
        self.modoSelecao = modoSelecao
        self.aoTocar = aoTocar
    }

    public var body: some View {
        Button(action: aoTocar) {
            ZStack(alignment: .bottomTrailing) {
                // Fundo sintético ilustrativo simulando foto com cor gradiente suave
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

                // Se o dado estiver adulterado/corrompido, exibe aviso
                if item.status == .adulterado {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(VoxColors.danger)
                                .font(.system(size: 20))
                            Text("Corrompido")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Duração do vídeo (se for vídeo)
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

                // Indicador de seleção
                if modoSelecao {
                    VStack {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(isSelecionado ? VoxColors.brand : Color.black.opacity(0.35))
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
            "\(item.tipo == .video ? "Vídeo" : "Foto"), \(item.status == .adulterado ? "Corrompido" : "Íntegro")"
        )
    }
}
