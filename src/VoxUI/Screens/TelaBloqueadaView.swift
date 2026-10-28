import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Tela Bloqueada (seção 6.10 de ui-visual-spec.md).
/// Apresentada ao abrir o app ou ao retornar de segundo plano.
/// Permite desbloquear com senha escrita ou padrão de pontos, adaptando-se ao tipo configurado.
public struct TelaBloqueadaView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onPerdiAcesso: () -> Void
    public let onCriarNovoCofre: (() -> Void)?

    @State private var modoEntrada: TipoCredencial = .texto
    @State private var credencialDigitada: String = ""
    @State private var erroAutenticacao: Bool = false
    @State private var padraoErro: Bool = false
    @State private var processando: Bool = false
    @State private var mostrarSeletorCofres: Bool = false

    public init(
        accessManager: VaultAccessManager,
        onPerdiAcesso: @escaping () -> Void,
        onCriarNovoCofre: (() -> Void)? = nil
    ) {
        self.accessManager = accessManager
        self.onPerdiAcesso = onPerdiAcesso
        self.onCriarNovoCofre = onCriarNovoCofre
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 16) {
                VoxLogoView(size: modoEntrada == .padrao ? 60 : 76)

                VStack(spacing: 6) {
                    Text(accessManager.cofreAtivo?.nome ?? "Cofre bloqueado")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(VoxColors.ink)

                    Text(modoEntrada == .padrao ? "Desenhe o padrão para abrir este cofre" : "Digite sua credencial para abrir este cofre")
                        .font(.system(size: 14))
                        .foregroundColor(VoxColors.inkSecondary)
                        .multilineTextAlignment(.center)
                }

                // Botão para alternar entre múltiplos cofres ou abrir gerenciador
                Button(action: { mostrarSeletorCofres = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.gearshape")
                        Text(accessManager.listaCofres.count > 1 ? "Trocar de cofre (\(accessManager.listaCofres.count))" : "Meus cofres")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VoxColors.brand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(VoxColors.brandSoft)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 12)

            if modoEntrada == .padrao {
                secaoPadrao
            } else {
                secaoTexto
            }

            Spacer(minLength: 12)

            // Ações secundárias
            VStack(spacing: 8) {
                // Alternar modo de entrada
                Button(action: alternarModoEntrada) {
                    HStack(spacing: 6) {
                        Image(systemName: modoEntrada == .padrao ? "keyboard" : "grid.circle")
                        Text(modoEntrada == .padrao ? "Desbloquear com senha escrita" : "Desbloquear com padrão de pontos")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VoxColors.brand)
                    .padding(.vertical, 6)
                }

                Button(action: onPerdiAcesso) {
                    Text("Perdi o acesso")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(VoxColors.inkSecondary)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(VoxColors.canvas.ignoresSafeArea())
        .sheet(isPresented: $mostrarSeletorCofres) {
            SeletorCofresSheet(accessManager: accessManager) {
                onCriarNovoCofre?()
            }
        }
        .onAppear {
            modoEntrada = accessManager.tipoCredencialConfigurada
        }
        .onChange(of: accessManager.tipoCredencialConfigurada) { _, novo in
            modoEntrada = novo
        }
    }

    // MARK: - Modos de entrada

    private var secaoTexto: some View {
        VStack(alignment: .leading, spacing: 12) {
            VoxSecureField(
                "Credencial principal",
                placeholder: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO",
                texto: $credencialDigitada
            )

            if erroAutenticacao {
                Text(accessManager.erroAcesso ?? "Não foi possível desbloquear. Verifique a credencial e o arquivo do cofre.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VoxColors.danger)
                    .accessibilityElement(children: .combine)
            }

            VoxButton("Desbloquear", variante: .primary, isLoading: processando) {
                Task { await tentarDesbloqueio(credencial: credencialDigitada) }
            }
        }
        .padding(.horizontal, 24)
    }

    private var secaoPadrao: some View {
        VStack(spacing: 12) {
            VoxPatternLockView(
                isError: padraoErro,
                isEnabled: !processando
            ) { pontos in
                let credencialStr = PadraoDesbloqueio.serializar(pontos: pontos)
                Task {
                    await tentarDesbloqueio(credencial: credencialStr)
                }
            }
            .frame(maxWidth: 290, maxHeight: 290)

            if erroAutenticacao {
                Text(accessManager.erroAcesso ?? "Padrão incorreto. Tente novamente.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VoxColors.danger)
                    .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func alternarModoEntrada() {
        modoEntrada = (modoEntrada == .padrao) ? .texto : .padrao
        erroAutenticacao = false
        padraoErro = false
        credencialDigitada = ""
    }

    @MainActor
    private func tentarDesbloqueio(credencial: String) async {
        guard !processando else { return }
        processando = true
        defer { processando = false }
        erroAutenticacao = false
        padraoErro = false

        let sucesso = await accessManager.desbloquearComCredencial(credencial)
        if !sucesso {
            erroAutenticacao = true
            padraoErro = true
        }
    }
}
