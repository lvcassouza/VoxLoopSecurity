import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

public enum FluxoOnboarding: Identifiable {
    case criarCofre
    case restaurar

    public var id: String {
        switch self {
        case .criarCofre: return "criarCofre"
        case .restaurar: return "restaurar"
        }
    }
}

/// Fluxo modal contínuo para criação de credencial, exibição do código e biometria.
public struct FluxoCriarCofreView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onConcluir: () -> Void
    public let onCancelar: () -> Void

    private enum Etapa {
        case criarCredencial
        case codigoRecuperacao(String)
        case biometria
    }

    @State private var etapa: Etapa = .criarCredencial

    public init(
        accessManager: VaultAccessManager,
        onConcluir: @escaping () -> Void,
        onCancelar: @escaping () -> Void
    ) {
        self.accessManager = accessManager
        self.onConcluir = onConcluir
        self.onCancelar = onCancelar
    }

    public var body: some View {
        VStack(spacing: 0) {
            VoxPrototypeDisclosureView()

            switch etapa {
            case .criarCredencial:
                CriarCredencialView(
                    accessManager: accessManager,
                    onAvancarComCodigo: { codigo in
                        etapa = .codigoRecuperacao(codigo)
                    },
                    onVoltar: onCancelar
                )

            case .codigoRecuperacao(let codigo):
                CodigoRecuperacaoView(
                    accessManager: accessManager,
                    codigo: codigo,
                    onConfirmado: {
                        etapa = .biometria
                    },
                    onVoltar: {
                        Task { await accessManager.cancelarConfiguracao() }
                        etapa = .criarCredencial
                    }
                )

            case .biometria:
                BiometriaOptInView(
                    accessManager: accessManager,
                    onConcluir: onConcluir
                )
            }
        }
        .background(VoxColors.canvas)
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
                            onboardingAtivo = .criarCofre
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
                        },
                        onCriarNovoCofre: {
                            onboardingAtivo = .criarCofre
                        }
                    )

                case .desbloqueado:
                    MainTabView(
                        accessManager: accessManager,
                        onBloquearManualmente: {
                            accessManager.bloquearCofre()
                        },
                        onCriarNovoCofre: {
                            onboardingAtivo = .criarCofre
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
            switch fluxo {
            case .criarCofre:
                FluxoCriarCofreView(
                    accessManager: accessManager,
                    onConcluir: {
                        onboardingAtivo = nil
                    },
                    onCancelar: {
                        onboardingAtivo = nil
                    }
                )

            case .restaurar:
                VStack(spacing: 0) {
                    VoxPrototypeDisclosureView()
                    RestaurarView(
                        accessManager: accessManager,
                        onVoltar: {
                            onboardingAtivo = nil
                        }
                    )
                }
                .background(VoxColors.canvas)
            }
        }
    }
}
