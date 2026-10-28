import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

public enum DestinoAba: Hashable {
    case cofre
    case backup
    case ajustes
}

/// Barra inferior nativa com três abas (seção 5 de ui-visual-spec.md).
public struct MainTabView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onBloquearManualmente: () -> Void
    public let onCriarNovoCofre: () -> Void

    @State private var abaSelecionada: DestinoAba = .cofre
    @State private var itemDetalheAberto: ItemDoCofre?
    @State private var abrirRestauracao: Bool = false

    public init(
        accessManager: VaultAccessManager,
        onBloquearManualmente: @escaping () -> Void,
        onCriarNovoCofre: @escaping () -> Void = {}
    ) {
        self.accessManager = accessManager
        self.onBloquearManualmente = onBloquearManualmente
        self.onCriarNovoCofre = onCriarNovoCofre
    }

    public var body: some View {
        TabView(selection: $abaSelecionada) {
            CofrePrincipalView(
                accessManager: accessManager,
                onAbrirItem: { item in
                    itemDetalheAberto = item
                },
                onAbrirAjustes: {
                    abaSelecionada = .ajustes
                },
                onAbrirBackup: {
                    abaSelecionada = .backup
                },
                onCriarNovoCofre: onCriarNovoCofre
            )
            .tabItem {
                Label("Cofre", systemImage: "square.grid.2x2")
            }
            .tag(DestinoAba.cofre)

            BackupView(
                accessManager: accessManager,
                onNavegarParaRestauracao: {
                    abrirRestauracao = true
                }
            )
            .tabItem {
                Label("Backup", systemImage: "externaldrive")
            }
            .tag(DestinoAba.backup)

            AjustesView(
                accessManager: accessManager,
                onBloquearManualmente: onBloquearManualmente,
                onCriarNovoCofre: onCriarNovoCofre
            )
            .tabItem {
                Label("Ajustes", systemImage: "gearshape")
            }
            .tag(DestinoAba.ajustes)
        }
        .tint(VoxColors.brand)
        #if os(iOS)
        .fullScreenCover(item: $itemDetalheAberto) { item in
            ItemDetailView(
                item: item,
                accessManager: accessManager,
                onVoltar: { itemDetalheAberto = nil }
            )
        }
        #else
        .sheet(item: $itemDetalheAberto) { item in
            ItemDetailView(
                item: item,
                accessManager: accessManager,
                onVoltar: { itemDetalheAberto = nil }
            )
        }
        #endif
        .sheet(isPresented: $abrirRestauracao) {
            RestaurarView(
                accessManager: accessManager,
                onVoltar: { abrirRestauracao = false }
            )
        }
    }
}
