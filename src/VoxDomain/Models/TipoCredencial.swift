import Foundation

/// Tipos de credencial suportados para desbloqueio do cofre.
public enum TipoCredencial: String, Codable, Sendable, CaseIterable {
    case texto = "texto"
    case padrao = "padrao"

    public var titulo: String {
        switch self {
        case .texto:
            return "Senha escrita"
        case .padrao:
            return "Padrão de pontos"
        }
    }

    public var descricao: String {
        switch self {
        case .texto:
            return "Senha alfanumérica ou frase secreta de pelo menos 12 caracteres."
        case .padrao:
            return "Desenho contínuo ligando os pontos na grade 3x3 (mínimo de 4 pontos)."
        }
    }
}

/// Helpers para serialização, validação e manipulação do padrão de pontos (grade 3x3).
public struct PadraoDesbloqueio: Sendable, Equatable {
    public static let prefixo = "padrao:"
    public static let minimoPontos = 4
    public static let maximoPontos = 9

    /// Converte a sequência ordenada de pontos (índices 0 a 8) na representação canônica da credencial.
    public static func serializar(pontos: [Int]) -> String {
        prefixo + pontos.map(String.init).joined(separator: "-")
    }

    /// Deserializa a representação canônica de volta para a lista de pontos, se for válida.
    public static func deserializar(credencial: String) -> [Int]? {
        guard credencial.hasPrefix(prefixo) else { return nil }
        let resto = credencial.dropFirst(prefixo.count)
        let partes = resto.split(separator: "-")
        guard !partes.isEmpty else { return nil }
        let pontos = partes.compactMap { Int($0) }
        guard pontos.count == partes.count else { return nil }
        guard pontos.allSatisfy({ (0...8).contains($0) }) else { return nil }
        guard Set(pontos).count == pontos.count else { return nil }
        return pontos
    }

    /// Retorna verdadeiro se a string de credencial representar um padrão de pontos.
    public static func ehPadrao(credencial: String) -> Bool {
        credencial.hasPrefix(prefixo)
    }

    /// Detecta o tipo de credencial a partir da representação em texto.
    public static func tipo(de credencial: String) -> TipoCredencial {
        ehPadrao(credencial: credencial) ? .padrao : .texto
    }
}
