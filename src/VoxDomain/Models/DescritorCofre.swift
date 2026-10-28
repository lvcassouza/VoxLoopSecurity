import Foundation

/// Metadados descritivos de um cofre local registrado no dispositivo.
/// Não contém senhas, chaves criptográficas ou metadados de itens/arquivos.
public struct DescritorCofre: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var nome: String
    public var tipoCredencial: TipoCredencial
    public let criadoEm: Date
    public var ultimoAcesso: Date?

    public init(
        id: UUID = UUID(),
        nome: String,
        tipoCredencial: TipoCredencial,
        criadoEm: Date = Date(),
        ultimoAcesso: Date? = nil
    ) {
        self.id = id
        self.nome = nome
        self.tipoCredencial = tipoCredencial
        self.criadoEm = criadoEm
        self.ultimoAcesso = ultimoAcesso
    }
}
