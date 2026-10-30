import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Ponto de entrada raiz da interface Vox.
/// Arquitetura 100% local, offline, sem login, sem nuvem e sem backup externo ("perdeu, perdeu").
/// O aplicativo entra mostrando a lista de cofres locais (`ListaCofresView`).
/// Ao selecionar um cofre, o usuário digita a credencial daquele cofre e obtém acesso ao seu conteúdo.
public struct AppRootView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var mostrarCriarCofre: Bool = false

    public init(accessManager: VaultAccessManager) {
        self.accessManager = accessManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            VoxPrototypeDisclosureView()

            ZStack {
                if accessManager.estadoAcesso == .desbloqueado {
                    MainTabView(
                        accessManager: accessManager,
                        onBloquearManualmente: {
                            accessManager.bloquearCofre()
                        },
                        onVoltarAosCofres: {
                            accessManager.bloquearCofre()
                        },
                        onCriarNovoCofre: {
                            mostrarCriarCofre = true
                        }
                    )
                } else {
                    ListaCofresView(
                        accessManager: accessManager,
                        onAbrirCriarCofre: {
                            mostrarCriarCofre = true
                        }
                    )
                }

                // Oculta o conteúdo no snapshot do seletor de apps
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
        .sheet(isPresented: $mostrarCriarCofre) {
            NavigationStack {
                CriarCredencialView(
                    accessManager: accessManager,
                    onConcluido: {
                        mostrarCriarCofre = false
                    },
                    onVoltar: {
                        mostrarCriarCofre = false
                    }
                )
            }
        }
    }
}
