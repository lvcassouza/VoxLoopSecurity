import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela para criar um novo cofre local no aparelho (seção 6.2 de ui-visual-spec.md).
/// Permite escolher entre senha escrita (texto) ou padrão de pontos 3x3.
/// Exibe aviso claro e destacado de que o armazenamento é 100% local e sem backup ("perdeu, perdeu").
public struct CriarCredencialView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onConcluido: () -> Void
    public let onVoltar: () -> Void
    public let onAvancarComCodigo: ((String) -> Void)?

    @State private var nomeCofre: String = ""
    @State private var tipoCredencial: TipoCredencial = .texto

    // Estado da senha escrita
    @State private var credencialTexto: String = ""
    @State private var confirmacaoTexto: String = ""

    // Estado do padrão de pontos
    @State private var primeiroPadrao: [Int]?
    @State private var padraoErro: Bool = false
    @State private var etapaConfirmacaoPadrao: Bool = false

    // Confirmação explícita de ausência de backup
    @State private var cienteSemBackup: Bool = false

    @State private var mensagemErro: String?
    @State private var processando = false

    public init(
        accessManager: VaultAccessManager,
        onConcluido: @escaping () -> Void = {},
        onAvancarComCodigo: ((String) -> Void)? = nil,
        onVoltar: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onConcluido = onConcluido
        self.onAvancarComCodigo = onAvancarComCodigo
        self.onVoltar = onVoltar
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Barra superior com voltar
            HStack {
                Button(action: onVoltar) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Voltar")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VoxColors.brand)
                    .frame(height: 44)
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Criar cofre local")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        Text("Dê um nome ao cofre e defina a credencial exclusiva para desbloqueá-lo neste aparelho.")
                            .font(.system(size: 15))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    // Nome do cofre
                    VoxTextField("Nome do cofre", placeholder: "Ex: Pessoal, Trabalho, Projetos", texto: $nomeCofre)

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

                    // Card de aviso sem backup (o momento mais oportuno)
                    cardAvisoSemBackup

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
                        Spacer(minLength: 16)
                        VoxButton("Criar cofre", variante: .primary, isLoading: processando) {
                            Task { await processarCriacaoTexto() }
                        }
                        .disabled(!cienteSemBackup || credencialTexto.isEmpty || confirmacaoTexto.isEmpty)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .background(VoxColors.canvas.ignoresSafeArea())
        .onAppear {
            if nomeCofre.isEmpty {
                nomeCofre = accessManager.listaCofres.isEmpty ? "Cofre Principal" : "Cofre \(accessManager.listaCofres.count + 1)"
            }
        }
    }

    // MARK: - Subviews

    private var cardAvisoSemBackup: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(VoxColors.warning)
                    .font(.system(size: 18))
                Text("Aviso importante: sem backup")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(VoxColors.ink)
            }

            Text("Este aplicativo é 100% local e não possui nuvem nem servidores. Não existe backup e não existe recuperação de senha.")
                .font(.system(size: 13))
                .foregroundColor(VoxColors.ink)

            Text("Se você esquecer a credencial deste cofre, o acesso aos arquivos será perdido para sempre. Não teremos nada a ver com o que está salvo e não podemos recuperá-lo.")
                .font(.system(size: 13))
                .foregroundColor(VoxColors.ink)

            Text("Perdeu a senha, perdeu o cofre.")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(VoxColors.danger)

            Toggle(isOn: $cienteSemBackup) {
                Text("Estou ciente: não há recuperação se eu esquecer a credencial.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VoxColors.ink)
            }
            .toggleStyle(SwitchToggleStyle(tint: VoxColors.brand))
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(hex: "#FFF4E5"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#FFD099"), lineWidth: 1)
        )
    }

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

        guard cienteSemBackup else {
            padraoErro = true
            mensagemErro = "Confirme que está ciente do aviso sem backup abaixo antes de desenhar seu padrão."
            return
        }

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
                primeiroPadrao = nil
                etapaConfirmacaoPadrao = false
            }
        }
    }

    @MainActor
    private func processarCriacaoTexto() async {
        guard cienteSemBackup else {
            mensagemErro = "Confirme que está ciente do aviso sem backup antes de continuar."
            return
        }
        await processarComCredenciais(credencial: credencialTexto, confirmacao: confirmacaoTexto)
    }

    @MainActor
    private func processarComCredenciais(credencial: String, confirmacao: String) async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        mensagemErro = nil
        let nomeFinal = nomeCofre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (accessManager.listaCofres.isEmpty ? "Cofre Principal" : "Cofre \(accessManager.listaCofres.count + 1)")
            : nomeCofre.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let onAvancarComCodigo {
                let code = try await accessManager.criarNovoCofre(nome: nomeFinal, credencial: credencial, confirmacao: confirmacao)
                onAvancarComCodigo(code)
            } else {
                try await accessManager.criarEAtivarNovoCofre(nome: nomeFinal, credencial: credencial, confirmacao: confirmacao)
                onConcluido()
            }
        } catch let erro as VaultError {
            mensagemErro = erro.localizedDescription
            padraoErro = true
        } catch {
            mensagemErro = "Ocorreu um erro ao definir sua credencial."
            padraoErro = true
        }
    }
}
