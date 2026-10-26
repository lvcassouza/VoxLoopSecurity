import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela do fluxo "Perdi o acesso" (seção 6.10 de ui-visual-spec.md).
public struct PerdiAcessoView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onVoltarAoBloqueio: () -> Void

    @State private var modoRedefinir: Bool = false
    @State private var codigoRecuperacao: String = ""
    @State private var novaSenha: String = ""
    @State private var confirmacaoSenha: String = ""
    @State private var mensagemErro: String?
    @State private var confirmacaoApagarCofre: Bool = false
    @State private var processando: Bool = false

    public init(
        accessManager: VaultAccessManager,
        onVoltarAoBloqueio: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onVoltarAoBloqueio = onVoltarAoBloqueio
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recuperar acesso ao cofre")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        Text("O código de recuperação redefine a credencial e abre o cofre local. Ele não recupera arquivos sem backup; backups ainda não estão disponíveis nesta fase.")
                            .font(.system(size: 15))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    if !modoRedefinir {
                        // Orientações iniciais
                        VStack(alignment: .leading, spacing: 14) {
                            ElementoDica(
                                icone: "key.fill",
                                titulo: "Tem o código de recuperação?",
                                texto: "Digite o código que guardou na configuração do cofre para redefinir a credencial."
                            )

                            ElementoDica(
                                icone: "externaldrive.fill",
                                titulo: "Precisa recuperar arquivos em outro aparelho?",
                                texto: "A restauração de backup ainda não está implementada."
                            )
                        }
                        .padding(16)
                        .background(VoxColors.surface)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VoxColors.border, lineWidth: 1))

                        VoxButton("Digitar código de recuperação", variante: .primary) {
                            modoRedefinir = true
                        }

                        // Ação quando ambos foram perdidos
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Limpar dados e recomeçar?")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(VoxColors.ink)

                            Text("Esta ação apaga permanentemente os arquivos cifrados deste cofre de teste. A Fototeca não será alterada.")
                                .font(.system(size: 13))
                                .foregroundColor(VoxColors.inkSecondary)

                            VoxButton("Apagar cofre de teste", variante: .destructive) {
                                confirmacaoApagarCofre = true
                            }
                        }
                        .padding(16)
                        .background(VoxColors.surfaceMuted)
                        .cornerRadius(16)

                    } else {
                        // Formulário de redefinição com o código
                        VStack(spacing: 16) {
                            VoxTextField("Código de recuperação", placeholder: "8 caracteres por grupo", texto: $codigoRecuperacao)
                            VoxSecureField("Nova credencial de teste", placeholder: "Mínimo 12 caracteres", texto: $novaSenha)
                            VoxSecureField("Confirme a credencial", placeholder: "Repita a credencial", texto: $confirmacaoSenha)
                        }

                        if let erro = mensagemErro {
                            Text(erro)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(VoxColors.danger)
                        }

                        VoxButton("Redefinir credencial", variante: .primary, isLoading: processando) {
                            Task { await redefinirComCodigo() }
                        }

                        Button("Voltar às orientações") {
                            modoRedefinir = false
                            mensagemErro = nil
                        }
                        .font(.system(size: 15))
                        .foregroundColor(VoxColors.inkSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Voltar ao bloqueio") { onVoltarAoBloqueio() }
                        .foregroundColor(VoxColors.brand)
                }
            }
            .confirmationDialog(
                "Apagar o cofre de teste?",
                isPresented: $confirmacaoApagarCofre,
                titleVisibility: .visible
            ) {
                Button("Apagar cofre", role: .destructive) {
                    Task { await accessManager.apagarCofreInacessivel() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta ação apaga as cópias cifradas locais. Os arquivos originais na Fototeca permanecem.")
            }
        }
    }

    @MainActor
    private func redefinirComCodigo() async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        mensagemErro = nil
        do {
            try await accessManager.redefinirCredencialComCodigo(
                codigo: codigoRecuperacao,
                novaCredencial: novaSenha,
                confirmacao: confirmacaoSenha
            )
            // Desbloqueia automaticamente e volta
        } catch let erro as VaultError {
            mensagemErro = erro.localizedDescription
        } catch {
            mensagemErro = "Código de recuperação inválido."
        }
    }
}

struct ElementoDica: View {
    let icone: String
    let titulo: String
    let texto: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icone)
                .foregroundColor(VoxColors.brand)
                .font(.system(size: 18))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VoxColors.ink)
                Text(texto)
                    .font(.system(size: 13))
                    .foregroundColor(VoxColors.inkSecondary)
            }
        }
    }
}
