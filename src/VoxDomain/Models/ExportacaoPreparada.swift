import Foundation

/// One plaintext file that has been prepared after the person confirmed export.
public struct ArquivoPreparadoParaExportacao: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let nomeArquivo: String
    public let tipo: TipoDeMidia

    public init(
        id: UUID = UUID(),
        url: URL,
        nomeArquivo: String,
        tipo: TipoDeMidia
    ) {
        self.id = id
        self.url = url
        self.nomeArquivo = nomeArquivo
        self.tipo = tipo
    }
}

/// A batch tracks its temporary directory so completion, cancellation, errors, and lock can remove it.
public struct LoteExportacaoPreparado: Equatable, Sendable {
    public let id: UUID
    public let arquivos: [ArquivoPreparadoParaExportacao]

    public init(id: UUID, arquivos: [ArquivoPreparadoParaExportacao]) {
        self.id = id
        self.arquivos = arquivos
    }
}
