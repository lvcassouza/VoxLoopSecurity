import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Grade principal do cofre (seção 6.5 de ui-visual-spec.md).
public struct CofrePrincipalView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onAbrirItem: (ItemDoCofre) -> Void
    public let onAbrirAjustes: () -> Void
    public let onAbrirBackup: () -> Void

    @State private var modoSelecao: Bool = false
    @State private var itensSelecionados: Set<UUID> = []
    @State private var mostrarFolhaImportacao: Bool = false
    @State private var mostrarConfirmacaoExclusao: Bool = false
    @State private var mostrarConfirmacaoExportacao: Bool = false
    @State private var termoBusca: String = ""
    @State private var exibirCampoBusca: Bool = false

    private let colunasGrade = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    public init(
        accessManager: VaultAccessManager,
        onAbrirItem: @escaping (ItemDoCofre) -> Void,
        onAbrirAjustes: @escaping () -> Void,
        onAbrirBackup: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onAbrirItem = onAbrirItem
        self.onAbrirAjustes = onAbrirAjustes
        self.onAbrirBackup = onAbrirBackup
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Card de status do backup (se desatualizado)
                        if case .desatualizado = accessManager.estadoBackup {
                            Button(action: onAbrirBackup) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(VoxColors.warning)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 30, height: 30)
                                        .background(Color.white)
                                        .cornerRadius(10)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Demonstração de backup desatualizada")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(VoxColors.ink)
                                        Text("Há itens sintéticos ainda não incluídos no estado de exemplo.")
                                            .font(.system(size: 12))
                                            .foregroundColor(VoxColors.inkSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(VoxColors.inkSecondary)
                                }
                                .padding(14)
                                .background(Color(hex: "#FFF3D7"))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "#EFDBAD"), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }

                        // Campo de busca local
                        if exibirCampoBusca {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(VoxColors.inkSecondary)
                                TextField("Buscar no cofre", text: $termoBusca)
                                if !termoBusca.isEmpty {
                                    Button(action: { termoBusca = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(VoxColors.inkSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(VoxColors.surface)
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }

                        // Seção de contagem
                        if !itensFiltrados.isEmpty {
                            HStack {
                                Text("Adicionados")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(VoxColors.ink)
                                Spacer()
                                Text("\(itensFiltrados.count) itens")
                                    .font(.system(size: 13))
                                    .foregroundColor(VoxColors.inkSecondary)
                            }
                            .padding(.horizontal, 20)

                            // Grade 3x3
                            LazyVGrid(columns: colunasGrade, spacing: 4) {
                                ForEach(itensFiltrados) { item in
                                    VoxTileView(
                                        item: item,
                                        isSelecionado: itensSelecionados.contains(item.id),
                                        modoSelecao: modoSelecao
                                    ) {
                                        if modoSelecao {
                                            alternarSelecao(item.id)
                                        } else {
                                            onAbrirItem(item)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 96) // Espaço para o FAB
                        } else {
                            // Estado vazio
                            VStack(spacing: 20) {
                                Spacer(minLength: 60)
                                VoxLogoView(size: 64)

                                VStack(spacing: 8) {
                                    Text("Cofre vazio")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(VoxColors.ink)

                                    Text("Importe somente fotos e vídeos de teste. A Fototeca mantém os originais.")
                                        .font(.system(size: 14))
                                        .foregroundColor(VoxColors.inkSecondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                                Spacer(minLength: 60)
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                // Botão fixo de importação (FAB) ou Toolbar contextual de seleção
                if modoSelecao {
                    HStack(spacing: 12) {
                        Button(action: { mostrarConfirmacaoExportacao = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Exportação (\(itensSelecionados.count))")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(VoxColors.surface)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VoxColors.border, lineWidth: 1))
                        }
                        .disabled(itensSelecionados.isEmpty)

                        Button(action: { mostrarConfirmacaoExclusao = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Apagar (\(itensSelecionados.count))")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(VoxColors.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(VoxColors.danger.opacity(0.1))
                            .cornerRadius(14)
                        }
                        .disabled(itensSelecionados.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                } else {
                    VoxButton("Adicionar fotos e vídeos de teste", icone: "plus", variante: .primary) {
                        mostrarFolhaImportacao = true
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .navigationTitle("Cofre")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !accessManager.itens.isEmpty {
                        Button(modoSelecao ? "Concluído" : "Selecionar") {
                            modoSelecao.toggle()
                            if !modoSelecao { itensSelecionados.removeAll() }
                        }
                        .foregroundColor(VoxColors.brand)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { exibirCampoBusca.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(VoxColors.ink)
                    }

                    Button(action: onAbrirAjustes) {
                        Image(systemName: "gearshape")
                            .foregroundColor(VoxColors.ink)
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    if !accessManager.itens.isEmpty {
                        Button(modoSelecao ? "Concluído" : "Selecionar") {
                            modoSelecao.toggle()
                            if !modoSelecao { itensSelecionados.removeAll() }
                        }
                        .foregroundColor(VoxColors.brand)
                    }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { exibirCampoBusca.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(VoxColors.ink)
                    }

                    Button(action: onAbrirAjustes) {
                        Image(systemName: "gearshape")
                            .foregroundColor(VoxColors.ink)
                    }
                }
            }
            #endif
            .sheet(isPresented: $mostrarFolhaImportacao) {
                FolhaImportacaoSinteticaView(accessManager: accessManager)
            }
            .confirmationDialog(
                "Exportação indisponível nesta versão",
                isPresented: $mostrarConfirmacaoExportacao,
                titleVisibility: .visible
            ) {
                Button("Entendi", role: .cancel) {}
            } message: {
                Text("Esta demonstração não lê nem cria arquivos externos.")
            }
            .confirmationDialog(
                "Remover os exemplos selecionados?",
                isPresented: $mostrarConfirmacaoExclusao,
                titleVisibility: .visible
            ) {
                Button("Apagar cópias do cofre", role: .destructive) {
                    let ids = itensSelecionados
                    Task {
                        for id in ids { try? await accessManager.apagarItemDoCofre(id: id) }
                        itensSelecionados.removeAll()
                        modoSelecao = false
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Serão apagadas apenas as cópias cifradas do cofre. Os originais na Fototeca permanecem.")
            }
        }
    }

    private var itensFiltrados: [ItemDoCofre] {
        if termoBusca.isEmpty {
            return accessManager.itens
        } else {
            return accessManager.itens.filter {
                $0.nomeOriginal.localizedCaseInsensitiveContains(termoBusca)
            }
        }
    }

    private func alternarSelecao(_ id: UUID) {
        if itensSelecionados.contains(id) {
            itensSelecionados.remove(id)
        } else {
            itensSelecionados.insert(id)
        }
    }
}

/// Folha para demonstrar e testar a importação transacional com arquivos sintéticos.
struct FolhaImportacaoSinteticaView: View {
    @ObservedObject var accessManager: VaultAccessManager
    @Environment(\.dismiss) private var dismiss

    @State private var quantidade: Int = 3
    @State private var tipo: TipoDeMidia = .foto
    @State private var simularFaltaEspaco: Bool = false
    @State private var simularInterrupcao: Bool = false
    @State private var mensagemErro: String?

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VoxPrototypeDisclosureView()

                Text("Adicionar arquivos de teste")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Esta versão interna deve ser usada apenas com arquivos de teste. A importação cria uma cópia cifrada e mantém o original na Fototeca.")
                    .font(.system(size: 14))
                    .foregroundColor(VoxColors.inkSecondary)

                ImportarFototecaView(accessManager: accessManager)

                Text("Ou crie bytes de fixture que não são imagens nem vídeos reais:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VoxColors.inkSecondary)

                VStack(spacing: 14) {
                    Picker("Tipo de mídia", selection: $tipo) {
                        Text("Fotos").tag(TipoDeMidia.foto)
                        Text("Vídeos").tag(TipoDeMidia.video)
                    }
                    .pickerStyle(.segmented)

                    Stepper("Quantidade: \(quantidade)", value: $quantidade, in: 1...12)
                        .padding(.horizontal, 8)
                }
                .padding()
                .background(VoxColors.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(VoxColors.border, lineWidth: 1))

                // Seção de testes de robustez transacional da Fase 2/Fase 3
                VStack(alignment: .leading, spacing: 10) {
                    Text("Cenários simulados:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VoxColors.inkSecondary)

                    Toggle("Simular falta de espaço em disco", isOn: $simularFaltaEspaco)
                    Toggle("Simular interrupção abrupta no commit", isOn: $simularInterrupcao)
                }
                .font(.system(size: 14))
                .padding()
                .background(VoxColors.surfaceMuted)
                .cornerRadius(14)

                if let erro = mensagemErro {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(VoxColors.danger)
                        Text(erro)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(VoxColors.danger)
                    }
                }

                Spacer()

                VoxButton("Adicionar \(quantidade) fixture(s)", variante: .primary) {
                    executarImportacao()
                }
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }

    private func executarImportacao() {
        mensagemErro = nil
        Task {
            do {
                _ = try await accessManager.importarItensSinteticos(
                    quantidade: quantidade,
                    tipo: tipo,
                    simularEspacoInsuficiente: simularFaltaEspaco,
                    simularInterrupcao: simularInterrupcao
                )
                dismiss()
            } catch let erro as VaultError {
                mensagemErro = erro.localizedDescription
            } catch {
                mensagemErro = "Ocorreu um erro inesperado."
            }
        }
    }
}
