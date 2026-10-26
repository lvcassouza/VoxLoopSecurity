import SwiftUI

/// Disclosure fixa para builds internos; não sugere auditoria ou prontidão para uso pessoal.
public struct VoxPrototypeDisclosureView: View {
    @State private var mostrarDetalhes = false

    public init() {}

    public var body: some View {
        Button {
            mostrarDetalhes = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(VoxColors.warning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Protótipo interno · use mídia de teste")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(VoxColors.ink)
                    Text("Toque para ver os limites desta versão.")
                        .font(.system(size: 12))
                        .foregroundColor(VoxColors.inkSecondary)
                }

                Spacer(minLength: 4)

                Image(systemName: "info.circle")
                    .foregroundColor(VoxColors.inkSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VoxColors.warning.opacity(0.12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre os limites deste protótipo interno.")
        .alert("Limites do protótipo", isPresented: $mostrarDetalhes) {
            Button("Entendi", role: .cancel) {}
        } message: {
            Text("Este protótipo interno importa arquivos escolhidos, cria cópias cifradas no sandbox e mantém os originais na Fototeca. O seletor aceita qualquer foto ou vídeo e o app não consegue distinguir mídia de teste da pessoal: escolha somente arquivos de teste e use uma credencial exclusiva. O cabeçalho persiste envelopes de chaves cifrados; o desenho e a implementação ainda não foram auditados, e contagem/tamanhos aproximados podem vazar. Não descreva o app como seguro, auditado ou pronto para produção. Testes de restauração entre iPhones físicos e auditoria independente continuam obrigatórios antes de qualquer lançamento público.")
        }
    }
}
