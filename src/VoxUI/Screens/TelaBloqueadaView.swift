import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela Bloqueada (seção 6.10 de ui-visual-spec.md).
/// Apresentada ao abrir o app ou ao retornar de segundo plano.
public struct TelaBloqueadaView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onPerdiAcesso: () -> Void

    @State private var credencialDigitada: String = ""
    @State private var erroAutenticacao: Bool = false
    @State private var processando: Bool = false

    public init(
        accessManager: VaultAccessManager,
        onPerdiAcesso: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onPerdiAcesso = onPerdiAcesso
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VoxLogoView(size: 88)

                VStack(spacing: 8) {
                    Text("Cofre bloqueado")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(VoxColors.ink)

                    Text("Digite sua credencial de teste para abrir o cofre local")
                        .font(.system(size: 15))
                        .foregroundColor(VoxColors.inkSecondary)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    VoxSecureField("Credencial principal", placeholder: "Digite sua frase ou senha", texto: $credencialDigitada)

                    if erroAutenticacao {
                        Text(accessManager.erroAcesso ?? "Não foi possível desbloquear. Verifique a credencial e o arquivo do cofre.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VoxColors.danger)
                            .accessibilityElement(children: .combine)
                    }

                    VoxButton("Desbloquear", variante: .primary, isLoading: processando) {
                        Task { await tentarCredencial() }
                    }
                }

                Button(action: onPerdiAcesso) {
                    Text("Perdi o acesso")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(VoxColors.inkSecondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(VoxColors.canvas.ignoresSafeArea())
    }

    @MainActor
    private func tentarCredencial() async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        erroAutenticacao = false
        let sucesso = await accessManager.desbloquearComCredencial(credencialDigitada)
        if !sucesso {
            erroAutenticacao = true
        }
    }
}
