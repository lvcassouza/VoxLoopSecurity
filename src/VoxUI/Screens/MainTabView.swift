import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

public enum DestinoAba: Hashable {
    case cofre
    case ajustes
}

/// Interface interna de um cofre desbloqueado: Grade de itens e Ajustes do cofre.
/// Não há login, não há nuvem e não há aba de backup (100% local, "perdeu, perdeu").
public struct MainTabView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onBloquearManualmente: () -> Void
    public let onVoltarAosCofres: () -> Void
    public let onCriarNovoCofre: () -> Void

    @State private var abaSelecionada: DestinoAba = .cofre
    @State private var itemDetalheAberto: ItemDoCofre?

    public init(
        accessManager: VaultAccessManager,
        onBloquearManualmente: @escaping () -> Void,
        onVoltarAosCofres: @escaping () -> Void = {},
        onCriarNovoCofre: @escaping () -> Void = {}
    ) {
        self.accessManager = accessManager
        self.onBloquearManualmente = onBloquearManualmente
        self.onVoltarAosCofres = onVoltarAosCofres
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
                onVoltarAosCofres: onVoltarAosCofres,
                onCriarNovoCofre: onCriarNovoCofre
            )
            .tabItem {
                Label("Cofre", systemImage: "square.grid.2x2")
            }
            .tag(DestinoAba.cofre)

            AjustesView(
                accessManager: accessManager,
                onBloquearManualmente: onVoltarAosCofres,
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
    }
}
