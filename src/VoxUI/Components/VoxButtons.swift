import SwiftUI

public enum VoxButtonVariant {
    case primary
    case secondary
    case destructive
}

/// Botão customizado padrão do Vox respeitando acessibilidade, Dynamic Type e áreas de toque mínimas.
public struct VoxButton: View {
    public let titulo: String
    public let icone: String?
    public let variante: VoxButtonVariant
    public let isLoading: Bool
    public let acao: () -> Void

    public init(
        _ titulo: String,
        icone: String? = nil,
        variante: VoxButtonVariant = .primary,
        isLoading: Bool = false,
        acao: @escaping () -> Void
    ) {
        self.titulo = titulo
        self.icone = icone
        self.variante = variante
        self.isLoading = isLoading
        self.acao = acao
    }

    public var body: some View {
        Button(action: acao) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundCor)
                } else if let icone {
                    Image(systemName: icone)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(titulo)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .disabled(isLoading)
        .background(backgroundCor)
        .foregroundColor(foregroundCor)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(bordaCor, lineWidth: bordaLargura)
        )
        .frame(minHeight: 44) // Tap target mínimo
    }

    private var backgroundCor: Color {
        switch variante {
        case .primary:
            return VoxColors.brand
        case .secondary:
            return VoxColors.surface
        case .destructive:
            return VoxColors.danger.opacity(0.12)
        }
    }

    private var foregroundCor: Color {
        switch variante {
        case .primary:
            return VoxColors.brandText
        case .secondary:
            return VoxColors.ink
        case .destructive:
            return VoxColors.danger
        }
    }

    private var bordaCor: Color {
        switch variante {
        case .primary:
            return Color.clear
        case .secondary:
            return VoxColors.border
        case .destructive:
            return VoxColors.danger.opacity(0.3)
        }
    }

    private var bordaLargura: CGFloat {
        switch variante {
        case .primary:
            return 0
        case .secondary, .destructive:
            return 1
        }
    }
}
