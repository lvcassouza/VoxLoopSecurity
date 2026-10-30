import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela inicial do aplicativo Vox.
/// Exibe diretamente a lista de cofres locais criados no aparelho.
/// Não há login, não há nuvem e não há backup externo.
public struct ListaCofresView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onAbrirCriarCofre: () -> Void

    @State private var cofreParaDesbloquear: DescritorCofre?
    @State private var cofreParaRenomear: DescritorCofre?
    @State private var cofreParaExcluir: DescritorCofre?
    @State private var novoNome: String = ""

    public init(
        accessManager: VaultAccessManager,
        onAbrirCriarCofre: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onAbrirCriarCofre = onAbrirCriarCofre
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Banner informativo de soberania local e ausência de backup
                    bannerInformativoLocal

                    if accessManager.listaCofres.isEmpty {
                        estadoVazioView
                    } else {
                        secaoCofresDisponiveis
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(VoxColors.canvas.ignoresSafeArea())
            .navigationTitle("Meus cofres")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onAbrirCriarCofre) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Criar cofre")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VoxColors.brand)
                    }
                }
            }
            .sheet(item: $cofreParaDesbloquear) { cofre in
                NavigationStack {
                    TelaBloqueadaView(
                        accessManager: accessManager,
                        onVoltarAosCofres: {
                            cofreParaDesbloquear = nil
                        }
                    )
                }
            }
            .alert("Renomear cofre", isPresented: Binding(
                get: { cofreParaRenomear != nil },
                set: { if !$0 { cofreParaRenomear = nil } }
            )) {
                TextField("Novo nome do cofre", text: $novoNome)
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
                Text("Digite o novo nome para este cofre local.")
            }
            .confirmationDialog(
                "Apagar cofre permanentemente?",
                isPresented: Binding(
                    get: { cofreParaExcluir != nil },
                    set: { if !$0 { cofreParaExcluir = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Apagar cofre e arquivos", role: .destructive) {
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
                    Text("O cofre \"\(cofre.nome)\" e todos os seus arquivos cifrados serão apagados deste aparelho. Não há backup nem recuperação. Seus outros cofres e a Fototeca não serão alterados.")
                }
            }
        }
    }

    // MARK: - Subviews

    private var bannerInformativoLocal: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(VoxColors.brand)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                Text("100% Local · Sem Login · Sem Nuvem")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Seus arquivos ficam armazenados exclusivamente neste aparelho com criptografia de ponta a ponta. Não existe backup: perdeu a senha, perdeu o cofre.")
                    .font(.system(size: 12))
                    .foregroundColor(VoxColors.inkSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(VoxColors.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VoxColors.border, lineWidth: 1))
    }

    private var estadoVazioView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(VoxColors.brandSoft)
                    .frame(width: 88, height: 88)

                Image(systemName: "lock.badge.plus")
                    .foregroundColor(VoxColors.brand)
                    .font(.system(size: 38))
            }

            VStack(spacing: 8) {
                Text("Nenhum cofre criado")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Crie seu primeiro cofre local. Você pode criar quantos cofres quiser, cada um com sua própria senha ou padrão de pontos.")
                    .font(.system(size: 14))
                    .foregroundColor(VoxColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VoxButton("Criar meu primeiro cofre", icone: "plus", variante: .primary) {
                onAbrirCriarCofre()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer(minLength: 40)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(VoxColors.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(VoxColors.border, lineWidth: 1))
    }

    private var secaoCofresDisponiveis: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Cofres neste aparelho (\(accessManager.listaCofres.count))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VoxColors.inkSecondary)
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(accessManager.listaCofres) { cofre in
                    cardCofre(cofre)
                }
            }

            Button(action: onAbrirCriarCofre) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("Criar outro cofre")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(VoxColors.brand)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(VoxColors.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(VoxColors.brand.opacity(0.3), lineWidth: 1))
            }
            .padding(.top, 6)
        }
    }

    private func cardCofre(_ cofre: DescritorCofre) -> some View {
        Button(action: {
            Task {
                await accessManager.selecionarCofre(id: cofre.id)
                cofreParaDesbloquear = cofre
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(VoxColors.brandSoft)
                        .frame(width: 50, height: 50)

                    Image(systemName: cofre.tipoCredencial == .padrao ? "grid.circle.fill" : "lock.fill")
                        .foregroundColor(VoxColors.brand)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(cofre.nome)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        if cofre.id == accessManager.cofreAtivo?.id {
                            Text("Último usado")
                                .font(.system(size: 10, weight: .bold))
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

                HStack(spacing: 4) {
                    Text("Abrir")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VoxColors.brand)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(VoxColors.brand)
                }
            }
            .padding(16)
            .background(VoxColors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(VoxColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                cofreParaRenomear = cofre
                novoNome = cofre.nome
            } label: {
                Label("Renomear cofre", systemImage: "pencil")
            }

            Button(role: .destructive) {
                cofreParaExcluir = cofre
            } label: {
                Label("Apagar cofre", systemImage: "trash")
            }
        }
    }

    private func formatarData(_ data: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        return "Criado em \(df.string(from: data))"
    }
}
