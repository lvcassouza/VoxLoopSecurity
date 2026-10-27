import SwiftUI

/// Campo de texto seguro com alternador de visibilidade (mostrar/ocultar senha),
/// sem autocorreção e com teclado acessível (conforme 6.2 e 7 de ui-visual-spec.md).
public struct VoxSecureField: View {
    public let rotulo: String
    public let placeholder: String
    @Binding public var texto: String
    @State private var isVisivel: Bool = false

    public init(
        _ rotulo: String,
        placeholder: String = ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO",
        texto: Binding<String>
    ) {
        self.rotulo = rotulo
        self.placeholder = placeholder
        self._texto = texto
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rotulo)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VoxColors.inkSecondary)

            HStack(spacing: 8) {
                if isVisivel {
                    TextField(placeholder, text: $texto)
                        .autocorrectionDisabled(true)
                        #if canImport(UIKit)
                        .textInputAutocapitalization(.never)
                        #endif
                } else {
                    SecureField(placeholder, text: $texto)
                        .autocorrectionDisabled(true)
                        #if canImport(UIKit)
                        .textInputAutocapitalization(.never)
                        #endif
                }

                Button(action: { isVisivel.toggle() }) {
                    Image(systemName: isVisivel ? "eye.slash" : "eye")
                        .foregroundColor(VoxColors.inkSecondary)
                        .frame(width: 44, height: 44) // Tap target acessível
                }
                .accessibilityLabel(isVisivel ? "Ocultar senha" : "Ver senha em texto")
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(VoxColors.surface)
            .cornerRadius(13)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(VoxColors.border, lineWidth: 1)
            )
        }
    }
}

/// Campo de texto comum com visual padronizado.
public struct VoxTextField: View {
    public let rotulo: String
    public let placeholder: String
    @Binding public var texto: String

    public init(_ rotulo: String, placeholder: String, texto: Binding<String>) {
        self.rotulo = rotulo
        self.placeholder = placeholder
        self._texto = texto
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rotulo)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VoxColors.inkSecondary)

            TextField(placeholder, text: $texto)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(VoxColors.surface)
                .cornerRadius(13)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(VoxColors.border, lineWidth: 1)
                )
        }
    }
}
