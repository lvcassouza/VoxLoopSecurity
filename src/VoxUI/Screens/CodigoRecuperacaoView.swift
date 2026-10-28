import SwiftUI
#if canImport(VoxDomain)
import VoxDomain
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Tela de exibição e confirmação do código de recuperação (seção 6.3 de ui-visual-spec.md).
public struct CodigoRecuperacaoView: View {
    @ObservedObject public var accessManager: VaultAccessManager
    public let codigo: String
    public let onConfirmado: () -> Void
    public let onVoltar: (() -> Void)?

    @State private var trechoConfirmacao: String = ""
    @State private var mensagemErro: String?
    @State private var copiadoComSucesso: Bool = false

    public init(
        accessManager: VaultAccessManager,
        codigo: String,
        onConfirmado: @escaping () -> Void,
        onVoltar: (() -> Void)? = nil
    ) {
        self.accessManager = accessManager
        self.codigo = codigo
        self.onConfirmado = onConfirmado
        self.onVoltar = onVoltar
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let onVoltar {
                HStack {
                    Button(action: onVoltar) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(VoxColors.ink)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Código de recuperação")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(VoxColors.ink)

                        Text("Este código de teste é um segredo real do cofre experimental: permite recuperar o acesso local, mas não recria arquivos sem backup. Guarde-o fora do aparelho.")
                            .font(.system(size: 16))
                            .foregroundColor(VoxColors.inkSecondary)
                    }

                    // Bloco de exibição isolada do código
                    VStack(spacing: 12) {
                        Text(codigo)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(VoxColors.ink)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(VoxColors.surface)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(VoxColors.border, lineWidth: 1)
                            )

                        Button(action: copiarCodigo) {
                            HStack(spacing: 6) {
                                Image(systemName: copiadoComSucesso ? "checkmark" : "doc.on.doc")
                                Text(copiadoComSucesso ? "Copiado!" : "Copiar código")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(VoxColors.brand)
                        }
                    }

                    // Aviso de armazenamento seguro
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(VoxColors.warning)
                            Text("Aviso importante")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VoxColors.ink)
                        }
                            Text("Não use este protótipo com mídia pessoal. O código abre o envelope de recuperação, mas o mecanismo ainda não passou por auditoria independente.")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.inkSecondary)
                    }
                    .padding(14)
                    .background(VoxColors.surfaceMuted)
                    .cornerRadius(12)

                    // Campo de confirmação
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirmação obrigatória")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(VoxColors.ink)

                        Text("Digite o código completo ou o último grupo de 8 caracteres:")
                            .font(.system(size: 13))
                            .foregroundColor(VoxColors.inkSecondary)

                        VoxTextField(
                            "Verificação",
                            placeholder: "Último grupo de 8 caracteres",
                            texto: $trechoConfirmacao
                        )
                    }

                    if let erro = mensagemErro {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(erro)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(VoxColors.danger)

                            if let onVoltar {
                                Button("Voltar e definir nova credencial") {
                                    onVoltar()
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(VoxColors.brand)
                                .padding(.top, 4)
                            }
                        }
                    }

                    VoxButton("Guardei meu código", variante: .primary) {
                        Task { await validarEAvancar() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
        }
        .background(VoxColors.canvas.ignoresSafeArea())
    }

    private func copiarCodigo() {
        #if canImport(UIKit)
        UIPasteboard.general.string = codigo
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(codigo, forType: .string)
        #endif
        copiadoComSucesso = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiadoComSucesso = false
        }
    }

    @MainActor
    private func validarEAvancar() async {
        mensagemErro = nil
        do {
            try await accessManager.confirmarCodigoRecuperacao(trechoDigitado: trechoConfirmacao)
            onConfirmado()
        } catch let erro as VaultError {
            mensagemErro = erro.localizedDescription
        } catch {
            mensagemErro = "Não foi possível confirmar a configuração do cofre."
        }
    }
}
