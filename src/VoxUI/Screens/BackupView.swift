import SwiftUI
import UniformTypeIdentifiers
#if canImport(VoxDomain)
import VoxDomain
#endif

/// User-controlled export and verification of an encrypted backup package.
public struct BackupView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onNavegarParaRestauracao: () -> Void

    @State private var preparado: BackupPreparado?
    @State private var mostrarSeletorExportacao = false
    @State private var mostrarVerificacao = false
    @State private var preparando = false
    @State private var tarefaPreparacao: Task<Void, Never>?
    @State private var erro: String?
    @State private var mensagem: String?

    public init(accessManager: VaultAccessManager, onNavegarParaRestauracao: @escaping () -> Void) {
        self.accessManager = accessManager
        self.onNavegarParaRestauracao = onNavegarParaRestauracao
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Backup cifrado")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(VoxColors.ink)
                        Text("Crie uma cópia cifrada e escolha onde guardá-la. O Vox não envia backups para servidores.")
                            .font(.system(size: 15))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    estadoDoBackup

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(VoxColors.inkSecondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Guarde o código de recuperação")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VoxColors.ink)
                            Text("O arquivo contém envelopes de chaves. Quem tiver o arquivo e o código de recuperação poderá restaurar seu conteúdo.")
                                .font(.system(size: 13))
                                .foregroundColor(VoxColors.inkSecondary)
                        }
                    }
                    .padding(14)
                    .background(VoxColors.surfaceMuted)
                    .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Conferir um arquivo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                        VoxButton("Verificar backup", icone: "checkmark.seal", variante: .secondary) {
                            mostrarVerificacao = true
                        }
                    }

                    Button(action: onNavegarParaRestauracao) {
                        HStack(spacing: 14) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(VoxColors.brand)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 40, height: 40)
                                .background(VoxColors.brandSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Restaurar em um aparelho vazio")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(VoxColors.ink)
                                Text("A restauração não substitui nem mescla um cofre existente.")
                                    .font(.system(size: 13))
                                    .foregroundColor(VoxColors.inkSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(VoxColors.inkSecondary)
                        }
                        .padding(16)
                        .background(VoxColors.surface)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VoxColors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .navigationTitle("Backup")
            .alert("Não foi possível concluir", isPresented: Binding(
                get: { erro != nil }, set: { if !$0 { erro = nil } }
            )) {
                Button("OK", role: .cancel) { erro = nil }
            } message: {
                Text(erro ?? "")
            }
            .alert("Backup concluído", isPresented: Binding(
                get: { mensagem != nil }, set: { if !$0 { mensagem = nil } }
            )) {
                Button("OK", role: .cancel) { mensagem = nil }
            } message: {
                Text(mensagem ?? "")
            }
            .sheet(isPresented: $mostrarVerificacao) {
                VerificarBackupView(accessManager: accessManager)
            }
            .sheet(isPresented: $mostrarSeletorExportacao) {
                if let preparado {
                    BackupPackageDocumentPicker(exporting: preparado.url) { copiado in
                        mostrarSeletorExportacao = false
                        guard copiado else {
                            accessManager.cancelarBackup(id: preparado.id)
                            self.preparado = nil
                            return
                        }
                        Task {
                            do {
                                try await accessManager.confirmarBackupExportado(id: preparado.id)
                                mensagem = "O arquivo de backup foi copiado para o destino escolhido. Guarde também o código de recuperação."
                            } catch {
                                erro = error.localizedDescription
                            }
                            self.preparado = nil
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .onChange(of: accessManager.estadoAcesso) { _, state in
                if state != .desbloqueado, let preparado {
                    accessManager.cancelarBackup(id: preparado.id)
                    self.preparado = nil
                    mostrarSeletorExportacao = false
                }
            }
            .onDisappear {
                tarefaPreparacao?.cancel()
                if let preparado { accessManager.cancelarBackup(id: preparado.id) }
            }
        }
    }

    private var estadoDoBackup: some View {
        let (title, detail, icon, tint) = backupStatusPresentation
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(VoxColors.ink)
                    Text(detail).font(.system(size: 13)).foregroundColor(VoxColors.inkSecondary)
                }
            }
            VoxButton(
                accessManager.estadoBackup == .nuncaCriado ? "Criar backup cifrado" : "Exportar nova cópia",
                icone: "externaldrive",
                variante: accessManager.estadoBackup == .nuncaCriado ? .primary : .secondary,
                isLoading: preparando
            ) {
                iniciarCriacaoBackup()
            }
            if preparando {
                HStack {
                    Text("Preparando e verificando os dados cifrados…")
                        .font(.system(size: 13))
                        .foregroundColor(VoxColors.inkSecondary)
                    Spacer()
                    Button("Cancelar") { tarefaPreparacao?.cancel() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VoxColors.danger)
                }
            }
        }
        .padding(18)
        .background(VoxColors.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(VoxColors.border, lineWidth: 1))
    }

    private var backupStatusPresentation: (String, String, String, Color) {
        switch accessManager.estadoBackup {
        case .nuncaCriado:
            return ("Nenhum backup exportado", "Crie um pacote cifrado e escolha um destino no app Arquivos.", "externaldrive.badge.plus", VoxColors.brand)
        case .atualizado(let date, let count):
            return ("Backup atualizado", "Última cópia confirmada: \(date.formatted(date: .abbreviated, time: .shortened)) · \(count) itens.", "checkmark.circle.fill", VoxColors.success)
        case .desatualizado(let date, let pending):
            let detail = date.map { "Há \(pending) alteração(ões) desde a cópia de \($0.formatted(date: .abbreviated, time: .shortened))." }
                ?? "Há \(pending) alteração(ões) sem cópia exportada."
            return ("Backup desatualizado", detail, "arrow.triangle.2.circlepath", VoxColors.warning)
        }
    }

    @MainActor
    private func iniciarCriacaoBackup() {
        guard !preparando else { return }
        preparando = true
        tarefaPreparacao = Task { @MainActor in
            defer { preparando = false; tarefaPreparacao = nil }
            do {
                let result = try await accessManager.prepararBackup()
                if Task.isCancelled {
                    accessManager.cancelarBackup(id: result.id)
                    return
                }
                preparado = result
                mostrarSeletorExportacao = true
            } catch {
                if !Task.isCancelled { erro = error.localizedDescription }
            }
        }
    }

}

private struct VerificarBackupView: View {
    @ObservedObject var accessManager: VaultAccessManager
    @Environment(\.dismiss) private var dismiss
    @State private var mostrarSeletor = false
    @State private var urlBackup: URL?
    @State private var codigoRecuperacao = ""
    @State private var resumo: ResumoBackup?
    @State private var erro: String?
    @State private var verificando = false
    @State private var tarefaVerificacao: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Verificar backup")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(VoxColors.ink)
                Text("A verificação autentica o manifesto, o índice e todos os blocos dos itens. Ela não altera o cofre atual nem o arquivo escolhido.")
                    .font(.system(size: 15))
                    .foregroundColor(VoxColors.inkSecondary)

                VoxButton(urlBackup == nil ? "Escolher arquivo .voxbackup" : "Escolher outro arquivo", icone: "folder", variante: .secondary) {
                    mostrarSeletor = true
                }
                if let urlBackup {
                    Label(urlBackup.lastPathComponent, systemImage: "doc.zipper")
                        .font(.system(size: 13))
                        .foregroundColor(VoxColors.inkSecondary)
                        .lineLimit(2)
                }

                SecureField("Código de recuperação", text: $codigoRecuperacao)
                    .textContentType(.oneTimeCode)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(VoxColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VoxColors.border, lineWidth: 1))

                VoxButton("Verificar integridade", icone: "checkmark.seal", isLoading: verificando) {
                    iniciarVerificacao()
                }
                .disabled(urlBackup == nil || codigoRecuperacao.isEmpty || verificando)
                if verificando {
                    Button("Cancelar verificação") { tarefaVerificacao?.cancel() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VoxColors.danger)
                }

                if let resumo {
                    Label("Backup legível", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VoxColors.success)
                    Text("Criado em \(resumo.dataCriacao.formatted(date: .abbreviated, time: .shortened)) · \(resumo.contagemItens) itens · \(ByteCountFormatter.string(fromByteCount: resumo.tamanhoBytes, countStyle: .file))")
                        .font(.system(size: 14))
                        .foregroundColor(VoxColors.inkSecondary)
                }
                if let erro {
                    Text(erro).font(.system(size: 14)).foregroundColor(VoxColors.danger)
                }
                Spacer()
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } } }
            .fileImporter(isPresented: $mostrarSeletor, allowedContentTypes: [VoxBackupFileType.package]) { result in
                switch result {
                case .success(let url): urlBackup = url; resumo = nil; erro = nil
                case .failure(let error): erro = error.localizedDescription
                }
            }
            .onDisappear { tarefaVerificacao?.cancel() }
        }
    }

    @MainActor
    private func iniciarVerificacao() {
        guard let urlBackup, !verificando else { return }
        verificando = true
        resumo = nil
        erro = nil
        tarefaVerificacao = Task { @MainActor in
            defer { verificando = false; tarefaVerificacao = nil }
            do {
                resumo = try await accessManager.verificarBackup(em: urlBackup, codigoRecuperacao: codigoRecuperacao)
            } catch {
                if !Task.isCancelled { self.erro = error.localizedDescription }
            }
        }
    }
}
