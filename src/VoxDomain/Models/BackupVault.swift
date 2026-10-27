import Foundation

/// Authenticated information read from a Vox backup package.
public struct ResumoBackup: Equatable, Sendable {
    public let dataCriacao: Date
    public let contagemItens: Int
    public let tamanhoBytes: Int64
    public let revisaoConteudo: UInt64

    public init(dataCriacao: Date, contagemItens: Int, tamanhoBytes: Int64, revisaoConteudo: UInt64) {
        self.dataCriacao = dataCriacao
        self.contagemItens = contagemItens
        self.tamanhoBytes = tamanhoBytes
        self.revisaoConteudo = revisaoConteudo
    }
}

/// A protected local package prepared for the native document picker to export as a copy.
public struct BackupPreparado: Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let resumo: ResumoBackup

    public init(id: UUID, url: URL, resumo: ResumoBackup) {
        self.id = id
        self.url = url
        self.resumo = resumo
    }
}

/// A restore is staged locally until the newly generated recovery code is confirmed.
public struct RestauracaoPreparada: Equatable, Sendable {
    public let id: UUID
    public let codigoRecuperacao: String
    public let resumo: ResumoBackup

    public init(id: UUID, codigoRecuperacao: String, resumo: ResumoBackup) {
        self.id = id
        self.codigoRecuperacao = codigoRecuperacao
        self.resumo = resumo
    }
}
