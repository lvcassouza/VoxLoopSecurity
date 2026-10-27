import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela para criar a credencial principal (seção 6.2 de ui-visual-spec.md).
/// Permite escolher entre senha escrita (texto) ou padrão (linhas ligando pontos).
public struct CriarCredencialView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onAvancarComCodigo: (String) -> Void
    public let onVoltar: () -> Void

    @State private var tipoCredencial: TipoCredencial = .texto

    // Estado da senha escrita
    @State private var credencialTexto: String = ""
    @State private var confirmacaoTexto: String = ""

    // Estado do padrão de pontos
    @State private var primeiroPadrao: [Int]?
    @State private var padraoErro: Bool = false
    @State private var etapaConfirmacaoPadrao: Bool = false

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
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Criar credencial principal")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        Text("Escolha como prefere desbloquear seu cofre: digitando uma senha ou desenhando um padrão ligando os pontos.")
                            .font(.system(size: 15))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    // Seletor de tipo de credencial
                    Picker("Tipo de credencial", selection: $tipoCredencial) {
                        Text(TipoCredencial.texto.titulo).tag(TipoCredencial.texto)
                        Text(TipoCredencial.padrao.titulo).tag(TipoCredencial.padrao)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: tipoCredencial) { _, _ in
                        limparCampos()
                    }

                    // Conteúdo conforme a escolha do usuário
                    if tipoCredencial == .texto {
                        secaoSenhaEscrita
                    } else {
                        secaoPadraoPontos
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

                    if tipoCredencial == .texto {
                        Spacer(minLength: 24)
                        VoxButton("Continuar", variante: .primary, isLoading: processando) {
                            Task { await processarCriacaoTexto() }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(VoxColors.canvas.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var secaoSenhaEscrita: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Use uma senha ou frase longa de pelo menos 12 caracteres.")
                .font(.system(size: 14))
                .foregroundColor(VoxColors.inkSecondary)

            VoxSecureField(
                "Senha ou frase",
                placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO",
                texto: $credencialTexto
            )
            VoxSecureField(
                "Confirme a credencial",
                placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO",
                texto: $confirmacaoTexto
            )
        }
    }

    private var secaoPadraoPontos: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(etapaConfirmacaoPadrao ? "Confirme o padrão desenhado" : "Desenhe seu padrão de pontos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VoxColors.ink)

                Text(etapaConfirmacaoPadrao ? "Ligue os mesmos pontos na mesma ordem para confirmar." : "Ligue pelo menos 4 pontos com o dedo.")
                    .font(.system(size: 13))
                    .foregroundColor(VoxColors.inkSecondary)
            }

            VoxPatternLockView(
                isError: padraoErro,
                isEnabled: !processando
            ) { pontosDesenhados in
                tratarPadraoDesenhado(pontosDesenhados)
            }
            .frame(maxWidth: 300, maxHeight: 300)
            .padding(.vertical, 8)

            if etapaConfirmacaoPadrao {
                Button(action: {
                    primeiroPadrao = nil
                    etapaConfirmacaoPadrao = false
                    padraoErro = false
                    mensagemErro = nil
                }) {
                    Text("Recomeçar desenho")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func limparCampos() {
        credencialTexto = ""
        confirmacaoTexto = ""
        primeiroPadrao = nil
        padraoErro = false
        etapaConfirmacaoPadrao = false
        mensagemErro = nil
    }

    private func tratarPadraoDesenhado(_ pontos: [Int]) {
        padraoErro = false
        mensagemErro = nil

        if !etapaConfirmacaoPadrao {
            guard pontos.count >= PadraoDesbloqueio.minimoPontos else {
                padraoErro = true
                mensagemErro = "O padrão deve ligar pelo menos 4 pontos."
                return
            }
            primeiroPadrao = pontos
            etapaConfirmacaoPadrao = true
        } else {
            guard let primeiro = primeiroPadrao else {
                etapaConfirmacaoPadrao = false
                return
            }
            if pontos == primeiro {
                // Confirmação bem-sucedida!
                let credencialStr = PadraoDesbloqueio.serializar(pontos: primeiro)
                Task {
                    await processarComCredenciais(credencial: credencialStr, confirmacao: credencialStr)
                }
            } else {
                padraoErro = true
                mensagemErro = "Os padrões não coincidem. Tente desenhar novamente."
                // Reinicia para etapa inicial para garantir segurança
                primeiroPadrao = nil
                etapaConfirmacaoPadrao = false
            }
        }
    }

    @MainActor
    private func processarCriacaoTexto() async {
        await processarComCredenciais(credencial: credencialTexto, confirmacao: confirmacaoTexto)
    }

    @MainActor
    private func processarComCredenciais(credencial: String, confirmacao: String) async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        mensagemErro = nil
        do {
            let codigo = try await accessManager.configurarCofre(credencial: credencial, confirmacao: confirmacao)
            onAvancarComCodigo(codigo)
        } catch let erro as VaultError {
            mensagemErro = erro.localizedDescription
            padraoErro = true
        } catch {
            mensagemErro = "Ocorreu um erro ao definir sua credencial."
            padraoErro = true
        }
    }
}
