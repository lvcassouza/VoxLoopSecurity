import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela de Ajustes (seção 6.9 de ui-visual-spec.md).
/// Grupos na ordem estrita especificada.
public struct AjustesView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onBloquearManualmente: () -> Void

    @State private var mostrarTrocarCredencial: Bool = false
    @State private var mostrarNovoCodigo: Bool = false
    @State private var mostrarDiagnosticoHardware: Bool = false
    @State private var mostrarConfirmacaoApagarCofre: Bool = false
    @State private var textoConfirmacaoDigitado: String = ""

    public init(
        accessManager: VaultAccessManager,
        onBloquearManualmente: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onBloquearManualmente = onBloquearManualmente
    }

    public var body: some View {
        NavigationStack {
            List {
                // 1. Desbloqueio
                Section("Desbloqueio") {
                    LabeledContent("Biometria", value: "Ainda não disponível")

                    Button("Trocar credencial com código de recuperação") {
                        mostrarTrocarCredencial = true
                    }
                    .foregroundColor(VoxColors.ink)

                    Button("Bloquear cofre agora") {
                        onBloquearManualmente()
                    }
                    .foregroundColor(VoxColors.brand)
                }

                // 2. Recuperação
                Section {
                    Button("Sobre o código de recuperação") {
                        mostrarNovoCodigo = true
                    }
                    .foregroundColor(VoxColors.ink)
                } header: {
                    Text("Recuperação")
                } footer: {
                    Text("O código recupera o acesso local caso você esqueça sua credencial principal.")
                        .font(.system(size: 12))
                        .foregroundColor(VoxColors.inkSecondary)
                }

                // 3. Privacidade
                Section("Privacidade") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Limites desta versão")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                        Text("Protótipo interno: use somente arquivos de teste e uma credencial exclusiva. O seletor aceita qualquer foto/vídeo e não identifica mídia pessoal. Cópias selecionadas e envelopes de chave ficam cifrados em disco; contagem e tamanhos aproximados ainda podem ser inferidos. Esta implementação não foi auditada nem está pronta para produção.")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                    .padding(.vertical, 4)

                    Link(destination: URL(string: "https://voxloop.com.br/privacidade")!) {
                        HStack {
                            Text("Política de Privacidade")
                                .foregroundColor(VoxColors.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12))
                                .foregroundColor(VoxColors.inkSecondary)
                        }
                    }
                }

                // 4. Armazenamento e Hardware
                Section {
                    LabeledContent("Tamanho dos itens desbloqueados", value: espacoTotalFormatado)

                    Button(action: { mostrarDiagnosticoHardware = true }) {
                        HStack {
                            Label("Diagnóstico de hardware e criptografia", systemImage: "cpu")
                                .foregroundColor(VoxColors.brand)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VoxColors.inkSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Armazenamento soberano")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(VoxColors.ink)
                        Text("A seleção lê os arquivos escolhidos, grava cópias cifradas no sandbox e mantém as origens na Fototeca. O backup portátil (.voxbackup) e a verificação estão disponíveis na aba Backup.")
                            .font(.system(size: 12))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Armazenamento e Hardware")
                }

                // 5. Sobre
                Section("Sobre") {
                    LabeledContent("Aplicativo", value: "Vox — Cofre Privado")
                    LabeledContent("Versão", value: "Protótipo interno · demonstração")
                    LabeledContent("Organização", value: "Voxloop")
                    LabeledContent("Site", value: "voxloop.com.br")
                }

                // 6. Ação destrutiva separada no fim
                Section {
                    Button(role: .destructive, action: { mostrarConfirmacaoApagarCofre = true }) {
                        HStack {
                            Spacer()
                            Text("Apagar cofre de teste")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Esta ação apaga o cofre local de teste e seus envelopes cifrados. As origens na Fototeca não são apagadas.")
                        .font(.system(size: 12))
                        .foregroundColor(VoxColors.inkSecondary)
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle("Ajustes")
            .sheet(isPresented: $mostrarNovoCodigo) {
                StatusRecuperacaoSheet()
            }
            .sheet(isPresented: $mostrarTrocarCredencial) {
                TrocarCredencialSheet(accessManager: accessManager)
            }
            .sheet(isPresented: $mostrarDiagnosticoHardware) {
                DiagnosticoHardwareView()
            }
            .confirmationDialog(
                "Apagar o cofre local?",
                isPresented: $mostrarConfirmacaoApagarCofre,
                titleVisibility: .visible
            ) {
                Button("Apagar cofre local", role: .destructive) {
                    Task { await accessManager.apagarCofreInacessivel() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Serão apagadas as cópias cifradas armazenadas pelo Vox. A Fototeca e os arquivos externos não serão alterados.")
            }
        }
    }

    private var espacoTotalFormatado: String {
        let total = accessManager.itens.reduce(0) { $0 + $1.tamanhoBytes }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
}

struct StatusRecuperacaoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Código de recuperação")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("O código gerado na configuração abre o envelope local da chave e permite redefinir a credencial. Ele não recria arquivos sem um backup. Esta fase ainda não cria nem restaura backups; guarde o código fora do aparelho e não use mídia pessoal neste protótipo.")
                    .font(.system(size: 15))
                    .foregroundColor(VoxColors.inkSecondary)

                Spacer()

                VoxButton("Entendido", variante: .primary) {
                    dismiss()
                }
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }
}

struct TrocarCredencialSheet: View {
    @ObservedObject var accessManager: VaultAccessManager
    @Environment(\.dismiss) private var dismiss

    @State private var tipoSelecionado: TipoCredencial = .texto
    @State private var codigoConfirmacao = ""
    @State private var novaSenha = ""
    @State private var confirmacao = ""
    @State private var primeiroPadrao: [Int]?
    @State private var etapaConfirmacaoPadrao = false
    @State private var padraoErro = false
    @State private var processando = false
    @State private var erro: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Trocar credencial principal")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(VoxColors.ink)

                    Text("Use uma credencial exclusiva para este cofre. A troca atualiza o envelope local sem alterar backups antigos.")
                        .font(.system(size: 14))
                        .foregroundColor(VoxColors.inkSecondary)

                    VoxTextField("Código de recuperação", placeholder: "8 caracteres por grupo", texto: $codigoConfirmacao)

                    Picker("Tipo de credencial", selection: $tipoSelecionado) {
                        Text(TipoCredencial.texto.titulo).tag(TipoCredencial.texto)
                        Text(TipoCredencial.padrao.titulo).tag(TipoCredencial.padrao)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: tipoSelecionado) { _, _ in
                        novaSenha = ""
                        confirmacao = ""
                        primeiroPadrao = nil
                        etapaConfirmacaoPadrao = false
                        padraoErro = false
                        erro = nil
                    }

                    if tipoSelecionado == .texto {
                        VoxSecureField("Nova senha", placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO", texto: $novaSenha)
                        VoxSecureField("Confirme a senha", placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO", texto: $confirmacao)

                        if let erro {
                            Text(erro)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(VoxColors.danger)
                        }

                        VoxButton("Salvar nova credencial", variante: .primary, isLoading: processando) {
                            Task {
                                await salvarCredencial(nova: novaSenha, conf: confirmacao)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text(etapaConfirmacaoPadrao ? "Confirme o novo padrão desenhado" : "Desenhe o novo padrão de pontos")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(VoxColors.ink)

                            VoxPatternLockView(
                                isError: padraoErro,
                                isEnabled: !processando
                            ) { pontos in
                                tratarPadrao(pontos)
                            }
                            .frame(maxWidth: 280, maxHeight: 280)

                            if etapaConfirmacaoPadrao {
                                Button("Recomeçar desenho") {
                                    primeiroPadrao = nil
                                    etapaConfirmacaoPadrao = false
                                    padraoErro = false
                                    erro = nil
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(VoxColors.brand)
                            }

                            if let erro {
                                Text(erro)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(VoxColors.danger)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }

    private func tratarPadrao(_ pontos: [Int]) {
        padraoErro = false
        erro = nil
        if !etapaConfirmacaoPadrao {
            guard pontos.count >= PadraoDesbloqueio.minimoPontos else {
                padraoErro = true
                erro = "O padrão deve ligar pelo menos 4 pontos."
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
                let credencialStr = PadraoDesbloqueio.serializar(pontos: primeiro)
                Task {
                    await salvarCredencial(nova: credencialStr, conf: credencialStr)
                }
            } else {
                padraoErro = true
                erro = "Os padrões não coincidem. Tente desenhar novamente."
                primeiroPadrao = nil
                etapaConfirmacaoPadrao = false
            }
        }
    }

    @MainActor
    private func salvarCredencial(nova: String, conf: String) async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        erro = nil
        do {
            try await accessManager.redefinirCredencialComCodigo(
                codigo: codigoConfirmacao,
                novaCredencial: nova,
                confirmacao: conf
            )
            dismiss()
        } catch let e as VaultError {
            erro = e.localizedDescription
            padraoErro = true
        } catch {
            erro = "Falha ao trocar credencial."
            padraoErro = true
        }
    }
}
