import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif

/// Backup and cross-device restoration are deliberately not represented as working features yet.
public struct RestaurarView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let onVoltar: () -> Void

    public init(accessManager: VaultAccessManager, onVoltar: @escaping () -> Void) {
        self.accessManager = accessManager
        self.onVoltar = onVoltar
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VoxPrototypeDisclosureView()

                Image(systemName: "externaldrive.badge.xmark")
                    .font(.system(size: 48))
                    .foregroundColor(VoxColors.warning)
                    .accessibilityHidden(true)

                Text("Restauração ainda indisponível")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(VoxColors.ink)

                Text("Esta fase implementa o cofre local e a importação cifrada. O Vox ainda não cria, verifica nem restaura arquivos de backup; esta ação não modifica o cofre.")
                    .font(.system(size: 16))
                    .foregroundColor(VoxColors.inkSecondary)

                Spacer()

                VoxButton("Voltar", variante: .primary) { onVoltar() }
            }
            .padding(24)
            .background(VoxColors.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", action: onVoltar)
                        .foregroundColor(VoxColors.brand)
                }
            }
        }
    }
}
