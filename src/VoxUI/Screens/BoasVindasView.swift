import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela de Boas-vindas (seção 6.1 de ui-visual-spec.md).
public struct BoasVindasView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onCriarCofre: () -> Void
    public let onRestaurarBackup: () -> Void
    @State private var mostrarInfoRecuperacao: Bool = false

    public init(
        accessManager: VaultAccessManager,
        onCriarCofre: @escaping () -> Void,
        onRestaurarBackup: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onCriarCofre = onCriarCofre
        self.onRestaurarBackup = onRestaurarBackup
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VoxLogoView(size: 80)

                VStack(spacing: 12) {
                    Text("Um espaço privado para fotos e vídeos de teste.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(VoxColors.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Text("O cofre local cifra cópias de arquivos da Fototeca e mantém as origens. O seletor não distingue mídia pessoal; escolha somente mídia de teste e use uma credencial exclusiva nesta versão interna.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(VoxColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            VStack(spacing: 14) {
                VoxButton("Criar meu cofre", variante: .primary) {
                    onCriarCofre()
                }

                VoxButton("Restaurar de backup (indisponível)", variante: .secondary) {
                    onRestaurarBackup()
                }

                Button(action: { mostrarInfoRecuperacao = true }) {
                    Text("Como funciona a recuperação")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(VoxColors.brand)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .background(VoxColors.canvas.ignoresSafeArea())
        .sheet(isPresented: $mostrarInfoRecuperacao) {
            InfoRecuperacaoSheet()
        }
    }
}

/// Folha informativa sobre como funciona a recuperação sem servidor ou nuvem.
struct InfoRecuperacaoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VoxPrototypeDisclosureView()

                Text("Sobre esta demonstração")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Este protótipo é local e não se conecta a um serviço de armazenamento. Use apenas arquivos de teste.")
                    .font(.system(size: 16))
                    .foregroundColor(VoxColors.inkSecondary)

                VStack(alignment: .leading, spacing: 14) {
                    ElementoExplicativo(
                        titulo: "Código de recuperação",
                        detalhe: "O código pode recuperar o acesso ao cofre local de teste, mas não recria arquivos ausentes sem backup."
                    )
                    ElementoExplicativo(
                        titulo: "Backup sob seu controle",
                        detalhe: "A implementação atual ainda não cria nem restaura backups."
                    )
                }
                .padding()
                .background(VoxColors.surfaceMuted)
                .cornerRadius(16)

                Spacer()

                VoxButton("Entendi", variante: .primary) {
                    dismiss()
                }
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

struct ElementoExplicativo: View {
    let titulo: String
    let detalhe: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VoxColors.ink)
            Text(detalhe)
                .font(.system(size: 14))
                .foregroundColor(VoxColors.inkSecondary)
        }
    }
}
