import SwiftUI

/// Cortina de privacidade para o seletor de aplicativos e segundo plano (seção 4 e 6.10 de ui-visual-spec.md).
/// Cobre a tela imediatamente com o logotipo neutro do Vox, prevenindo snapshots visuais de mídia.
public struct VoxPrivacyShieldView: View {
    public init() {}

    public var body: some View {
        ZStack {
            VoxColors.canvas
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VoxLogoView(size: 80)

                VStack(spacing: 8) {
                    Text("vox")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(VoxColors.ink)

                    Text("Conteúdo demonstrativo oculto.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(VoxColors.inkSecondary)
                }
            }
        }
    }
}
