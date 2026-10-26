import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import AVKit
#endif
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Full-screen media viewer for an authenticated item in the unlocked vault.
public struct ItemDetailView: View {
    public let item: ItemDoCofre
    @ObservedObject public var accessManager: VaultAccessManager
    public let onVoltar: () -> Void

    @State private var mostrarConfirmacaoExportar = false
    @State private var mostrarConfirmacaoApagar = false
    @State private var mostrarDetalhes = false
    @State private var mostrarSeletorExportacao = false
    @State private var mostrarErroAcao = false
    @State private var tituloErroAcao = "Não foi possível concluir"
    @State private var mensagemErroAcao = ""
    @State private var voltarDepoisDoErro = false
    @State private var carregando = true
    @State private var erroDeLeitura: String?
    @State private var imagem: CGImage?
    @State private var sessaoDeLeitura: VaultMediaReadSession?
    @State private var loteExportacao: LoteExportacaoPreparado?
    @State private var arquivosExportados: [ExportedVaultFile] = []
    @State private var preparandoExportacao = false
    @State private var recarregar = UUID()
    #if os(iOS)
    @StateObject private var videoController = VaultVideoPlayerController()
    #endif

    public init(
        item: ItemDoCofre,
        accessManager: VaultAccessManager,
        onVoltar: @escaping () -> Void
    ) {
        self.item = item
        self.accessManager = accessManager
        self.onVoltar = onVoltar
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VoxPrototypeDisclosureView()

                HStack {
                    Button(action: onVoltar) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Voltar ao cofre")

                    Spacer()

                    Menu {
                        Button(action: { mostrarConfirmacaoExportar = true }) {
                            Label("Exportar", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { mostrarDetalhes = true }) {
                            Label("Detalhes", systemImage: "info.circle")
                        }
                        Button(role: .destructive, action: { mostrarConfirmacaoApagar = true }) {
                            Label("Apagar do cofre", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Mais opções")
                }
                .padding(.horizontal, 16)

                mediaContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if accessManager.estadoAcesso == .desbloqueado, itemAtual.status != .adulterado {
                    HStack(spacing: 40) {
                        Button(action: { mostrarConfirmacaoExportar = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                Text("Exportar")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(preparandoExportacao)

                        Button(action: { mostrarConfirmacaoApagar = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("Apagar")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(VoxColors.danger)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(preparandoExportacao)
                    }
                    .padding(.bottom, 24)
                }
            }

            if preparandoExportacao {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("Preparando exportação…")
                    .padding(20)
                    .background(VoxColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .task(id: recarregar) {
            await carregarMidia()
        }
        .confirmationDialog(
            "Exportar este item?",
            isPresented: $mostrarConfirmacaoExportar,
            titleVisibility: .visible
        ) {
            Button("Continuar") { Task { await prepararExportacao() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Uma cópia será criada fora do Vox. O destino controla o que acontece com ela. O arquivo de origem, o item do cofre e backups anteriores não são alterados.")
        }
        .confirmationDialog(
            "Apagar esta cópia do cofre?",
            isPresented: $mostrarConfirmacaoApagar,
            titleVisibility: .visible
        ) {
            Button("Apagar do cofre", role: .destructive) { Task { await apagarItem() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Será apagada apenas esta cópia do cofre. O arquivo de origem na Fototeca, exportações e backups anteriores permanecem.")
        }
        .sheet(isPresented: $mostrarDetalhes) {
            DetalhesItemSheet(item: itemAtual)
        }
        .fileExporter(
            isPresented: $mostrarSeletorExportacao,
            items: arquivosExportados,
            contentTypes: [.image, .movie],
            onCompletion: concluirExportacao,
            onCancellation: concluirExportacaoPendente
        )
        .alert(tituloErroAcao, isPresented: $mostrarErroAcao) {
            Button("OK", role: .cancel) {
                if voltarDepoisDoErro { onVoltar() }
                voltarDepoisDoErro = false
            }
        } message: {
            Text(mensagemErroAcao)
        }
        .onChange(of: accessManager.estadoAcesso) { _, novoEstado in
            if novoEstado != .desbloqueado {
                esconderMidia()
                mostrarSeletorExportacao = false
                concluirExportacaoPendente()
            }
        }
        #if os(iOS)
        .onChange(of: videoController.hasError) { _, falhou in
            if falhou {
                videoController.encerrarAposFalha()
                liberarSessaoAtual()
            }
        }
        #endif
        .onDisappear {
            esconderMidia()
            if !mostrarSeletorExportacao { concluirExportacaoPendente() }
        }
    }

    @ViewBuilder
    private var mediaContent: some View {
        if itemAtual.status == .adulterado {
            estadoDeFalha("Não foi possível abrir este item", detalhe: "O Vox não conseguiu validar os dados deste item.")
        } else if accessManager.estadoAcesso != .desbloqueado {
            estadoDeFalha("Cofre bloqueado", detalhe: "Desbloqueie o cofre para ver este item.")
        } else if carregando {
            ProgressView("Abrindo item…")
                .tint(.white)
                .foregroundColor(.white)
        } else if let erroDeLeitura {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(VoxColors.warning)
                Text("Não foi possível abrir este item")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(erroDeLeitura)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button("Tentar novamente") { recarregar = UUID() }
                    .buttonStyle(.borderedProminent)
                    .tint(VoxColors.brand)
            }
            .padding(24)
        } else if itemAtual.tipo == .foto {
            if let imagem {
                Image(decorative: imagem, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Foto do cofre")
            } else {
                estadoDeFalha("Formato não suportado", detalhe: "Este arquivo não pode ser exibido como foto.")
            }
        } else {
            #if os(iOS)
            if videoController.hasError {
                estadoDeFalha(
                    "Não foi possível reproduzir este vídeo",
                    detalhe: "O Vox não conseguiu carregar ou validar os dados do vídeo.",
                    acao: { recarregar = UUID() }
                )
            } else if let player = videoController.player {
                VideoPlayer(player: player)
                    .accessibilityLabel("Reprodutor de vídeo do cofre")
                    .padding(.horizontal, 8)
            } else {
                estadoDeFalha("Formato não suportado", detalhe: "Este arquivo não pode ser reproduzido como vídeo.")
            }
            #else
            estadoDeFalha("Vídeo indisponível", detalhe: "A reprodução está disponível no app para iPhone.")
            #endif
        }
    }

    private func estadoDeFalha(_ titulo: String, detalhe: String, acao: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(VoxColors.warning)
            Text(titulo)
                .font(.headline)
                .foregroundColor(.white)
            Text(detalhe)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if let acao {
                Button("Tentar novamente", action: acao)
                    .buttonStyle(.borderedProminent)
                    .tint(VoxColors.brand)
            }
        }
        .padding(24)
    }

    @MainActor
    private func carregarMidia() async {
        carregando = true
        erroDeLeitura = nil
        imagem = nil
        guard accessManager.estadoAcesso == .desbloqueado, !accessManager.cortinaPrivacidadeAtiva else {
            carregando = false
            return
        }
        do {
            let session = try await accessManager.abrirSessaoDeLeitura(id: item.id)
            sessaoDeLeitura = session
            if item.tipo == .foto {
                let decoded = try await Task.detached(priority: .userInitiated) {
                    SendableCGImage(image: try VaultImageDecoder.thumbnail(from: session, maximumPixelSize: 4096))
                }.value
                guard !Task.isCancelled,
                      accessManager.estadoAcesso == .desbloqueado,
                      !accessManager.cortinaPrivacidadeAtiva else { return }
                imagem = decoded.image
            } else {
                #if os(iOS)
                videoController.prepare(using: session)
                #else
                throw VaultError.formatoDeMidiaNaoSuportado
                #endif
            }
            carregando = false
        } catch let error as VaultError {
            if !Task.isCancelled {
                erroDeLeitura = error.localizedDescription
                carregando = false
                liberarSessaoAtual()
            }
        } catch {
            if !Task.isCancelled {
                erroDeLeitura = "O arquivo está corrompido ou usa um formato incompatível."
                carregando = false
                liberarSessaoAtual()
            }
        }
    }

    @MainActor
    private func prepararExportacao() async {
        guard !preparandoExportacao else { return }
        preparandoExportacao = true
        defer { preparandoExportacao = false }
        do {
            let lote = try await accessManager.prepararExportacao(ids: [itemAtual.id])
            guard accessManager.estadoAcesso == .desbloqueado, !accessManager.cortinaPrivacidadeAtiva else {
                accessManager.concluirExportacao(id: lote.id)
                return
            }
            loteExportacao = lote
            arquivosExportados = lote.arquivos.map { ExportedVaultFile(prepared: $0) }
            mostrarSeletorExportacao = true
        } catch let error as VaultError {
            tituloErroAcao = "Não foi possível exportar"
            mensagemErroAcao = error.localizedDescription
            mostrarErroAcao = true
        } catch {
            tituloErroAcao = "Não foi possível exportar"
            mensagemErroAcao = "O item do cofre permanece intacto. Tente novamente."
            mostrarErroAcao = true
        }
    }

    @MainActor
    private func apagarItem() async {
        do {
            try await accessManager.apagarItemDoCofre(id: itemAtual.id)
            onVoltar()
        } catch let error as VaultError {
            tituloErroAcao = error == .falhaNaLimpezaDaExclusao ? "Item removido do cofre" : "Não foi possível apagar"
            mensagemErroAcao = error.localizedDescription
            voltarDepoisDoErro = error == .falhaNaLimpezaDaExclusao
            if voltarDepoisDoErro { esconderMidia() }
            mostrarErroAcao = true
        } catch {
            tituloErroAcao = "Não foi possível apagar"
            mensagemErroAcao = "O item permanece no cofre. Tente novamente."
            mostrarErroAcao = true
        }
    }

    private func concluirExportacao(_ result: Result<[URL], any Error>) {
        if case .failure = result {
            tituloErroAcao = "Não foi possível exportar"
            mensagemErroAcao = "A gravação no destino escolhido falhou. O item do cofre permanece intacto."
            mostrarErroAcao = true
        }
        concluirExportacaoPendente()
    }

    private func concluirExportacaoPendente() {
        if let loteExportacao {
            accessManager.concluirExportacao(id: loteExportacao.id)
        }
        loteExportacao = nil
        arquivosExportados = []
    }

    private func esconderMidia() {
        imagem = nil
        videoControllerPauseAndInvalidate()
        liberarSessaoAtual()
        carregando = false
    }

    private func videoControllerPauseAndInvalidate() {
        #if os(iOS)
        videoController.invalidate()
        #endif
    }

    private func liberarSessaoAtual() {
        guard let sessaoDeLeitura else { return }
        accessManager.fecharSessaoDeLeitura(id: sessaoDeLeitura.sessionID)
        sessaoDeLeitura.invalidate()
        self.sessaoDeLeitura = nil
    }

    private var itemAtual: ItemDoCofre {
        accessManager.itens.first(where: { $0.id == item.id }) ?? item
    }
}

private struct SendableCGImage: @unchecked Sendable {
    let image: CGImage
}

struct DetalhesItemSheet: View {
    let item: ItemDoCofre
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Metadados do item") {
                    LabeledContent("Tipo", value: item.tipo == .video ? "Vídeo" : "Foto")
                    LabeledContent("Tamanho", value: item.tamanhoFormatado)
                    if let duracao = item.duracaoFormatada {
                        LabeledContent("Duração", value: duracao)
                    }
                    LabeledContent("Status", value: item.status.rawValue.capitalized)
                }
            }
            .navigationTitle("Detalhes do item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }
}
