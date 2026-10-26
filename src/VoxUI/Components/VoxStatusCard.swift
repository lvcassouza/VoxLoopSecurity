import SwiftUI

/// Cartão informativo com símbolo de estado, título e descrição (seção 6.7 e 7 de ui-visual-spec.md).
public struct VoxStatusCard: View {
    public let icone: String
    public let iconeCor: Color
    public let iconeFundo: Color
    public let titulo: String
    public let descricao: String

    public init(
        icone: String,
        iconeCor: Color = VoxColors.brand,
        iconeFundo: Color = VoxColors.brandSoft,
        titulo: String,
        descricao: String
    ) {
        self.icone = icone
        self.iconeCor = iconeCor
        self.iconeFundo = iconeFundo
        self.titulo = titulo
        self.descricao = descricao
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconeFundo)
                    .frame(width: 38, height: 38)
                Image(systemName: icone)
                    .foregroundColor(iconeCor)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titulo)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VoxColors.ink)

                Text(descricao)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(VoxColors.inkSecondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(VoxColors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VoxColors.border, lineWidth: 1)
        )
    }
}
