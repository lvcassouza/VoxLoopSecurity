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
                    Text("O código recupera o acesso local, mas não há criação nem restauração de backup nesta fase.")
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

                // 4. Armazenamento
                Section {
                    LabeledContent("Tamanho dos itens desbloqueados", value: espacoTotalFormatado)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arquivos reais")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(VoxColors.ink)
                        Text("A seleção lê apenas os itens escolhidos e grava uma cópia cifrada. O arquivo de origem permanece na Fototeca. A exportação cria uma cópia externa; backup real ainda não está disponível.")
                            .font(.system(size: 12))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Armazenamento")
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

    @State private var novaSenha = ""
    @State private var confirmacao = ""
    @State private var codigoConfirmacao = ""
    @State private var erro: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trocar credencial principal")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Use uma credencial exclusiva para este cofre de teste. A troca atualiza o envelope local; não altera backups antigos.")
                    .font(.system(size: 14))
                    .foregroundColor(VoxColors.inkSecondary)

                VoxTextField("Código de recuperação", placeholder: "8 caracteres por grupo", texto: $codigoConfirmacao)
                VoxSecureField("Nova credencial de teste", placeholder: "Mínimo 12 caracteres", texto: $novaSenha)
                VoxSecureField("Confirme a credencial", placeholder: "Repita a credencial", texto: $confirmacao)

                if let erro {
                    Text(erro)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(VoxColors.danger)
                }

                Spacer()

                VoxButton("Salvar nova credencial", variante: .primary) {
                    Task {
                    do {
                        try await accessManager.redefinirCredencialComCodigo(
                            codigo: codigoConfirmacao,
                            novaCredencial: novaSenha,
                            confirmacao: confirmacao
                        )
                        dismiss()
                    } catch let e as VaultError {
                        erro = e.localizedDescription
                    } catch {
                        erro = "Falha ao trocar credencial."
                    }
                    }
                }
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }
}
