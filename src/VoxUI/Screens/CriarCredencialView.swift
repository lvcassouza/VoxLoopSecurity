import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela para criar a credencial principal (seção 6.2 de ui-visual-spec.md).
public struct CriarCredencialView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onAvancarComCodigo: (String) -> Void
    public let onVoltar: () -> Void

    @State private var credencial: String = ""
    @State private var confirmacao: String = ""
    @State private var mensagemErro: String?
    @State private var processando = false

    public init(
        accessManager: VaultAccessManager,
        onAvancarComCodigo: @escaping (String) -> Void,
        onVoltar: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onAvancarComCodigo = onAvancarComCodigo
        self.onVoltar = onVoltar
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Barra superior
            HStack {
                Button(action: onVoltar) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(VoxColors.ink)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Criar credencial principal")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        Text("Use uma credencial exclusiva para este protótipo e nunca reutilize uma senha pessoal. O cabeçalho guarda apenas envelopes de chave cifrados; o formato ainda é experimental.")
                            .font(.system(size: 16))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    VStack(spacing: 16) {
                        VoxSecureField("Senha ou frase", placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO", texto: $credencial)
                        VoxSecureField("Confirme a credencial", placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO", texto: $confirmacao)
                    }

                    if let erro = mensagemErro {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(VoxColors.danger)
                            Text(erro)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(VoxColors.danger)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VoxColors.danger.opacity(0.1))
                        .cornerRadius(10)
                        .accessibilityElement(children: .combine)
                    }

                    Spacer(minLength: 40)

                    VoxButton("Continuar", variante: .primary, isLoading: processando) {
                        Task { await processarCriacao() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .background(VoxColors.canvas.ignoresSafeArea())
    }

    @MainActor
    private func processarCriacao() async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        mensagemErro = nil
        do {
            let codigo = try await accessManager.configurarCofre(credencial: credencial, confirmacao: confirmacao)
            onAvancarComCodigo(codigo)
        } catch let erro as VaultError {
            mensagemErro = erro.localizedDescription
        } catch {
            mensagemErro = "Ocorreu um erro ao definir sua credencial."
        }
    }
}
