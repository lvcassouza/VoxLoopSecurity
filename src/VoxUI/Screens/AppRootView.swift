import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

public enum FluxoOnboarding: Identifiable {
    case criarCredencial
    case codigoRecuperacao(String)
    case biometria
    case restaurar

    public var id: String {
        switch self {
        case .criarCredencial: return "criarCredencial"
        case .codigoRecuperacao: return "codigoRecuperacao"
        case .biometria: return "biometria"
        case .restaurar: return "restaurar"
        }
    }
}

/// Ponto de entrada raiz da interface Vox.
/// Gerencia os estados explícitos de acesso e a proteção visual de segundo plano.
public struct AppRootView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboardingAtivo: FluxoOnboarding?

    public init(accessManager: VaultAccessManager) {
        self.accessManager = accessManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            VoxPrototypeDisclosureView()

            ZStack {
                switch accessManager.estadoAcesso {
                case .naoConfigurado:
                    BoasVindasView(
                        accessManager: accessManager,
                        onCriarCofre: {
                            onboardingAtivo = .criarCredencial
                        },
                        onRestaurarBackup: {
                            onboardingAtivo = .restaurar
                        }
                    )

                case .bloqueado:
                    TelaBloqueadaView(
                        accessManager: accessManager,
                        onPerdiAcesso: {
                            accessManager.iniciarRecuperacao()
                        }
                    )

                case .desbloqueado:
                    MainTabView(
                        accessManager: accessManager,
                        onBloquearManualmente: {
                            accessManager.bloquearCofre()
                        }
                    )

                case .recuperando:
                    PerdiAcessoView(
                        accessManager: accessManager,
                        onVoltarAoBloqueio: {
                            accessManager.cancelarRecuperacao()
                        }
                    )
                }

                // Oculta o conteúdo demonstrativo no snapshot do seletor de apps.
                if accessManager.cortinaPrivacidadeAtiva {
                    VoxPrivacyShieldView()
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                // Oculta mídia imediatamente antes de qualquer snapshot do iOS
                accessManager.aplicarCortinaPrivacidade(ativa: true)
            case .active:
                accessManager.aplicarCortinaPrivacidade(ativa: false)
            @unknown default:
                break
            }
        }
        .sheet(item: $onboardingAtivo, onDismiss: {
            if !accessManager.isConfigurado {
                Task { await accessManager.cancelarConfiguracao() }
            }
        }) { fluxo in
            VStack(spacing: 0) {
                VoxPrototypeDisclosureView()

                switch fluxo {
                case .criarCredencial:
                    CriarCredencialView(
                        accessManager: accessManager,
                        onAvancarComCodigo: { codigo in
                            onboardingAtivo = .codigoRecuperacao(codigo)
                        },
                        onVoltar: {
                            onboardingAtivo = nil
                        }
                    )

                case .codigoRecuperacao(let codigo):
                    CodigoRecuperacaoView(
                        accessManager: accessManager,
                        codigo: codigo,
                        onConfirmado: {
                            onboardingAtivo = .biometria
                        }
                    )

                case .biometria:
                    BiometriaOptInView(
                        accessManager: accessManager,
                        onConcluir: {
                            onboardingAtivo = nil
                        }
                    )

                case .restaurar:
                    RestaurarView(
                        accessManager: accessManager,
                        onVoltar: {
                            onboardingAtivo = nil
                        }
                    )
                }
            }
            .background(VoxColors.canvas)
        }
    }
}
