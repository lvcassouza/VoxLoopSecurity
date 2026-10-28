import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Folha modal para visualização, alternância e gerenciamento dos múltiplos cofres locais.
public struct SeletorCofresSheet: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onCriarNovoCofre: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var cofreParaExcluir: DescritorCofre?
    @State private var cofreParaRenomear: DescritorCofre?
    @State private var novoNome: String = ""

    public init(
        accessManager: VaultAccessManager,
        onCriarNovoCofre: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onCriarNovoCofre = onCriarNovoCofre
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(accessManager.listaCofres) { cofre in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(cofre.id == accessManager.cofreAtivo?.id ? VoxColors.brandSoft : VoxColors.surfaceMuted)
                                    .frame(width: 44, height: 44)

                                Image(systemName: cofre.id == accessManager.cofreAtivo?.id ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(cofre.id == accessManager.cofreAtivo?.id ? VoxColors.brand : VoxColors.inkSecondary)
                                    .font(.system(size: 18))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(cofre.nome)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(VoxColors.ink)

                                    if cofre.id == accessManager.cofreAtivo?.id {
                                        Text("Ativo")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(VoxColors.brand)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(VoxColors.brandSoft)
                                            .cornerRadius(6)
                                    }
                                }

                                Text("\(cofre.tipoCredencial.titulo) · \(formatarData(cofre.criadoEm))")
                                    .font(.system(size: 13))
                                    .foregroundColor(VoxColors.inkSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VoxColors.border)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                await accessManager.selecionarCofre(id: cofre.id)
                                dismiss()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                cofreParaExcluir = cofre
                            } label: {
                                Label("Apagar", systemImage: "trash")
                            }

                            Button {
                                cofreParaRenomear = cofre
                                novoNome = cofre.nome
                            } label: {
                                Label("Renomear", systemImage: "pencil")
                            }
                            .tint(VoxColors.brand)
                        }
                    }
                } header: {
                    Text("Cofres disponíveis neste aparelho")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VoxColors.inkSecondary)
                }

                Section {
                    Button(action: {
                        dismiss()
                        onCriarNovoCofre()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(VoxColors.brand)

                            Text("Criar outro cofre")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(VoxColors.brand)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Meus cofres")
            #if os(iOS)
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            #else
            .listStyle(.inset)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
            .alert("Renomear cofre", isPresented: Binding(
                get: { cofreParaRenomear != nil },
                set: { if !$0 { cofreParaRenomear = nil } }
            )) {
                TextField("Nome do cofre", text: $novoNome)
                Button("Cancelar", role: .cancel) { cofreParaRenomear = nil }
                Button("Salvar") {
                    if let cofre = cofreParaRenomear {
                        Task {
                            try? await accessManager.renomearCofre(id: cofre.id, novoNome: novoNome)
                            cofreParaRenomear = nil
                        }
                    }
                }
            } message: {
                Text("Digite o novo nome para este cofre.")
            }
            .confirmationDialog(
                "Apagar cofre?",
                isPresented: Binding(
                    get: { cofreParaExcluir != nil },
                    set: { if !$0 { cofreParaExcluir = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Apagar permanentemente", role: .destructive) {
                    if let cofre = cofreParaExcluir {
                        Task {
                            await accessManager.apagarCofre(id: cofre.id)
                            cofreParaExcluir = nil
                        }
                    }
                }
                Button("Cancelar", role: .cancel) { cofreParaExcluir = nil }
            } message: {
                if let cofre = cofreParaExcluir {
                    Text("O cofre \"\(cofre.nome)\" e todos os seus arquivos cifrados serão apagados deste aparelho. Seus outros cofres e a Fototeca não serão alterados.")
                }
            }
        }
    }

    private func formatarData(_ data: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        return "Criado em \(df.string(from: data))"
    }
}
