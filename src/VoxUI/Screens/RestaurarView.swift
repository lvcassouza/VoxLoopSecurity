import SwiftUI
import UniformTypeIdentifiers
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Restores a verified backup only into an installation without a configured vault.
public struct RestaurarView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onVoltar: () -> Void

    @State private var mostrarSeletor = false
    @State private var urlBackup: URL?
    @State private var codigoBackup = ""
    @State private var tipoSelecionado: TipoCredencial = .texto
    @State private var novaCredencial = ""
    @State private var confirmacaoCredencial = ""
    @State private var primeiroPadrao: [Int]?
    @State private var etapaConfirmacaoPadrao = false
    @State private var padraoErro = false
    @State private var restauracaoPreparada: RestauracaoPreparada?
    @State private var confirmacaoNovoCodigo = ""
    @State private var preparando = false
    @State private var tarefaRestauracao: Task<Void, Never>?
    @State private var concluida = false
    @State private var erro: String?

    public init(accessManager: VaultAccessManager, onVoltar: @escaping () -> Void) {
        self.accessManager = accessManager
        self.onVoltar = onVoltar
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VoxPrototypeDisclosureView()

                    if accessManager.isConfigurado {
                        bloqueioPorCofreExistente
                    } else if concluida {
                        sucesso
                    } else if let restauracaoPreparada {
                        confirmarNovoCodigo(restauracaoPreparada)
                    } else {
                        formularioDeRestauracao
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .navigationTitle("Restaurar backup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", action: cancelarOuVoltar)
                        .foregroundColor(VoxColors.brand)
                }
            }
            .fileImporter(isPresented: $mostrarSeletor, allowedContentTypes: [VoxBackupFileType.package]) { result in
                switch result {
                case .success(let url):
                    urlBackup = url
                    erro = nil
                case .failure(let error):
                    erro = error.localizedDescription
                }
            }
            .onDisappear {
                tarefaRestauracao?.cancel()
                if let pending = restauracaoPreparada {
                    Task { await accessManager.cancelarRestauracao(id: pending.id) }
                }
            }
            .onChange(of: accessManager.cortinaPrivacidadeAtiva) { _, ativa in
                if !ativa, let pending = restauracaoPreparada, !accessManager.isConfigurado {
                    restauracaoPreparada = nil
                    confirmacaoNovoCodigo = ""
                    erro = "A restauração foi cancelada quando o app foi para segundo plano. Inicie novamente."
                    Task { await accessManager.cancelarRestauracao(id: pending.id) }
                }
            }
        }
    }

    private var formularioDeRestauracao: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(VoxColors.brand)
                .accessibilityHidden(true)

            Text("Restaurar de um backup")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(VoxColors.ink)
            Text("Escolha o pacote cifrado, informe o código usado quando ele foi criado e defina uma credencial nova para este aparelho.")
                .font(.system(size: 15))
                .foregroundColor(VoxColors.inkSecondary)

            VoxButton(urlBackup == nil ? "Escolher pacote .voxbackup" : "Escolher outro pacote", icone: "folder", variante: .secondary) {
                mostrarSeletor = true
            }
            if let urlBackup {
                Label(urlBackup.lastPathComponent, systemImage: "doc.zipper")
                    .font(.system(size: 13))
                    .foregroundColor(VoxColors.inkSecondary)
                    .lineLimit(2)
            }

            campoSeguro("Código de recuperação do backup", placeholder: "8 caracteres por grupo", texto: $codigoBackup)

            Picker("Tipo de credencial", selection: $tipoSelecionado) {
                Text(TipoCredencial.texto.titulo).tag(TipoCredencial.texto)
                Text(TipoCredencial.padrao.titulo).tag(TipoCredencial.padrao)
            }
            .pickerStyle(.segmented)
            .onChange(of: tipoSelecionado) { _, _ in
                novaCredencial = ""
                confirmacaoCredencial = ""
                primeiroPadrao = nil
                etapaConfirmacaoPadrao = false
                padraoErro = false
                erro = nil
            }

            if tipoSelecionado == .texto {
                campoSeguro("Nova senha (mínimo 12 caracteres)", placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO", texto: $novaCredencial)
                campoSeguro("Confirme a nova senha", placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO", texto: $confirmacaoCredencial)

                VoxButton("Validar e preparar restauração", icone: "checkmark.shield", isLoading: preparando) {
                    iniciarPreparacaoRestauracao()
                }
                .disabled(urlBackup == nil || codigoBackup.isEmpty || novaCredencial.count < 12 || preparando)
            } else {
                VStack(spacing: 12) {
                    Text(etapaConfirmacaoPadrao ? "Confirme o novo padrão para este aparelho" : "Desenhe o novo padrão de pontos para este aparelho")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VoxColors.ink)

                    VoxPatternLockView(
                        isError: padraoErro,
                        isEnabled: !preparando && urlBackup != nil && !codigoBackup.isEmpty
                    ) { pontos in
                        tratarPadraoRestauracao(pontos)
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

                    if urlBackup == nil || codigoBackup.isEmpty {
                        Text("Selecione o pacote de backup e informe o código antes de desenhar o padrão.")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.warning)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            if preparando {
                Button("Cancelar restauração", role: .cancel, action: cancelarOuVoltar)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VoxColors.danger)
            }

            Text("O cofre só será instalado depois de validar os dados e confirmar um novo código de recuperação. O arquivo de backup escolhido permanece intacto.")
                .font(.system(size: 13))
                .foregroundColor(VoxColors.inkSecondary)

            if let erro {
                Text(erro).font(.system(size: 14)).foregroundColor(VoxColors.danger)
            }
        }
    }

    private var bloqueioPorCofreExistente: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundColor(VoxColors.warning)
            Text("Este aparelho já tem um cofre")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(VoxColors.ink)
            Text("A restauração só está disponível quando não há cofre configurado. Nenhum conteúdo será substituído ou mesclado.")
                .font(.system(size: 15))
                .foregroundColor(VoxColors.inkSecondary)
            VoxButton("Voltar", variante: .primary, acao: onVoltar)
        }
    }

    private func confirmarNovoCodigo(_ prepared: RestauracaoPreparada) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 42))
                .foregroundColor(VoxColors.brand)
            Text("Guarde o novo código")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(VoxColors.ink)
            Text("Este código foi gerado para o cofre restaurado. Anote-o em um local seguro; ele não substitui o código do arquivo original.")
                .font(.system(size: 15))
                .foregroundColor(VoxColors.inkSecondary)

            Text(prepared.codigoRecuperacao)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(VoxColors.ink)
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(VoxColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Novo código de recuperação, quatro grupos de oito caracteres")

            Text("Backup verificado: \(prepared.resumo.contagemItens) itens · \(ByteCountFormatter.string(fromByteCount: prepared.resumo.tamanhoBytes, countStyle: .file))")
                .font(.system(size: 13))
                .foregroundColor(VoxColors.inkSecondary)

            TextField("Digite os últimos 8 caracteres", text: $confirmacaoNovoCodigo)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .autocorrectionDisabled()
                .font(.system(size: 17, weight: .regular, design: .monospaced))
                .padding(14)
                .background(VoxColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(VoxColors.border, lineWidth: 1))

            VoxButton("Confirmar e instalar cofre", icone: "checkmark", isLoading: preparando) {
                iniciarConfirmacaoNovoCodigo(prepared)
            }
            .disabled(confirmacaoNovoCodigo.isEmpty || preparando)
            if preparando {
                Button("Cancelar restauração", role: .cancel, action: cancelarOuVoltar)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VoxColors.danger)
            }

            Button("Cancelar restauração", role: .cancel, action: cancelarOuVoltar)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            if let erro {
                Text(erro).font(.system(size: 14)).foregroundColor(VoxColors.danger)
            }
        }
    }

    private var sucesso: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(VoxColors.success)
            Text("Cofre restaurado")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(VoxColors.ink)
            Text("A nova credencial e o novo código de recuperação já protegem este cofre. O arquivo de origem não foi alterado.")
                .font(.system(size: 15))
                .foregroundColor(VoxColors.inkSecondary)
            VoxButton("Continuar", variante: .primary, acao: onVoltar)
        }
    }

    private func campoSeguro(
        _ titulo: String,
        placeholder: String = ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO",
        texto: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VoxColors.inkSecondary)
            SecureField(placeholder, text: texto)
                .textContentType(.password)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .padding(14)
                .background(VoxColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(VoxColors.border, lineWidth: 1))
        }
    }

    private func tratarPadraoRestauracao(_ pontos: [Int]) {
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
                novaCredencial = credencialStr
                confirmacaoCredencial = credencialStr
                iniciarPreparacaoRestauracao()
            } else {
                padraoErro = true
                erro = "Os padrões não coincidem. Tente desenhar novamente."
                primeiroPadrao = nil
                etapaConfirmacaoPadrao = false
            }
        }
    }

    @MainActor
    private func iniciarPreparacaoRestauracao() {
        guard let urlBackup, !preparando else { return }
        preparando = true
        erro = nil
        tarefaRestauracao = Task { @MainActor in
            defer { preparando = false; tarefaRestauracao = nil }
            do {
                let prepared = try await accessManager.prepararRestauracao(
                    de: urlBackup,
                    codigoRecuperacao: codigoBackup,
                    novaCredencial: novaCredencial,
                    confirmacao: confirmacaoCredencial
                )
                if Task.isCancelled {
                    await accessManager.cancelarRestauracao(id: prepared.id)
                    return
                }
                restauracaoPreparada = prepared
                codigoBackup = ""
                novaCredencial = ""
                confirmacaoCredencial = ""
            } catch {
                if !Task.isCancelled { erro = error.localizedDescription }
            }
        }
    }

    @MainActor
    private func iniciarConfirmacaoNovoCodigo(_ prepared: RestauracaoPreparada) {
        guard !preparando else { return }
        preparando = true
        erro = nil
        tarefaRestauracao = Task { @MainActor in
            defer { preparando = false; tarefaRestauracao = nil }
            do {
                try await accessManager.confirmarNovoCodigoRecuperacao(
                    id: prepared.id,
                    trechoDigitado: confirmacaoNovoCodigo
                )
                restauracaoPreparada = nil
                concluida = true
            } catch {
                if !Task.isCancelled { erro = error.localizedDescription }
            }
        }
    }

    private func cancelarOuVoltar() {
        if let pending = restauracaoPreparada {
            Task { await accessManager.cancelarRestauracao(id: pending.id) }
            restauracaoPreparada = nil
        }
        onVoltar()
    }
}
