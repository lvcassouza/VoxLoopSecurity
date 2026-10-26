import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Visualização de item individual do cofre (seção 6.6 de ui-visual-spec.md).
public struct ItemDetailView: View {
    public let item: ItemDoCofre
    @ObservedObject public var accessManager: VaultAccessManager
    public let onVoltar: () -> Void

    @State private var mostrarConfirmacaoExportar: Bool = false
    @State private var mostrarConfirmacaoApagar: Bool = false
    @State private var mostrarDetalhes: Bool = false

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

                // Barra de navegação superior
                HStack {
                    Button(action: onVoltar) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Menu {
                        Button(action: { mostrarConfirmacaoExportar = true }) {
                            Label("Exportação indisponível", systemImage: "square.and.arrow.up")
                        }
                        Button(action: { mostrarDetalhes = true }) {
                            Label("Detalhes", systemImage: "info.circle")
                        }
                        Button(role: .destructive, action: { mostrarConfirmacaoApagar = true }) {
                            Label("Apagar do cofre", systemImage: "trash")
                        }
                        Divider()
                        // Ação de teste para simular adulteração
                        Button(action: {
                            accessManager.adulterarItemParaTeste(id: item.id)
                        }) {
                            Label("Simular aviso de integridade", systemImage: "ant.fill")
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

                Spacer()

                // Área de visualização de conteúdo
                if itemAtual.status == .adulterado {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(VoxColors.danger)

                        Text("Não foi possível abrir este item")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Este estado simula um item marcado como alterado. Nenhum arquivo real foi analisado.")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button(action: { onVoltar() }) {
                            Text("Voltar ao cofre")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(VoxColors.brand)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(12)
                        }
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: itemAtual.corSinteticaHex), Color.black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .aspectRatio(3/4, contentMode: .fit)
                            .padding(.horizontal, 20)

                        if itemAtual.tipo == .video {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        VStack(spacing: 8) {
                            Image(systemName: itemAtual.tipo == .video ? "video" : "photo")
                                .font(.system(size: 26))
                            Text("Prévia ilustrativa. A visualização do arquivo será implementada na próxima fase.")
                                .font(.system(size: 13, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()

                // Barra de ações inferior
                if itemAtual.status != .adulterado {
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
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .confirmationDialog(
            "Exportação indisponível nesta versão",
            isPresented: $mostrarConfirmacaoExportar,
            titleVisibility: .visible
        ) {
            Button("Entendi", role: .cancel) {}
        } message: {
            Text("Esta demonstração não lê nem cria arquivos externos.")
        }
        .confirmationDialog(
            "Apagar a cópia do cofre?",
            isPresented: $mostrarConfirmacaoApagar,
            titleVisibility: .visible
        ) {
            Button("Apagar do cofre", role: .destructive) {
                Task {
                    try? await accessManager.apagarItemDoCofre(id: itemAtual.id)
                    onVoltar()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A cópia cifrada será apagada do cofre. A origem na Fototeca permanece.")
        }
        .sheet(isPresented: $mostrarDetalhes) {
            DetalhesItemSheet(item: itemAtual)
        }
    }

    private var itemAtual: ItemDoCofre {
        accessManager.itens.first(where: { $0.id == item.id }) ?? item
    }
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
