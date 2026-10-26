import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela de oferta opcional de biometria (seção 6.4 de ui-visual-spec.md).
public struct BiometriaOptInView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onConcluir: () -> Void

    public init(accessManager: VaultAccessManager, onConcluir: @escaping () -> Void) {
        self.accessManager = accessManager
        self.onConcluir = onConcluir
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 72, weight: .light))
                    .foregroundColor(VoxColors.brand)

                VStack(spacing: 12) {
                    Text("Biometria ainda não disponível")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(VoxColors.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("O cofre usa a credencial principal nesta versão. A biometria só será oferecida quando o envelope de chave protegido pela Keychain estiver implementado e validado.")
                        .font(.system(size: 16))
                        .foregroundColor(VoxColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }

            Spacer()

            VStack(spacing: 14) {
                VoxButton("Continuar com a credencial", variante: .primary) {
                    accessManager.definirBiometria(ativa: false)
                    onConcluir()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(VoxColors.canvas.ignoresSafeArea())
    }
}
