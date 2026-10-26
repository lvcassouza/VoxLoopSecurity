import Foundation

/// Representa o tipo de mídia de um item do cofre.
public enum TipoDeMidia: String, Codable, Sendable {
    case foto
    case video
}

/// Estado de integridade e sincronização do item no cofre.
public enum StatusItem: String, Codable, Sendable {
    case integro
    case pendenteBackup
    case adulterado
}

/// Item do cofre: cópia de um arquivo de origem incorporada ao cofre,
/// independente do arquivo de origem (conforme CONTEXT.md).
public struct ItemDoCofre: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let nomeOriginal: String
    public let tipo: TipoDeMidia
    public let tamanhoBytes: Int64
    public let dataCriacao: Date
    public let duracaoSegundos: Double?
    public var status: StatusItem
    public let corSinteticaHex: String

    public init(
        id: UUID = UUID(),
        nomeOriginal: String,
        tipo: TipoDeMidia,
        tamanhoBytes: Int64,
        dataCriacao: Date = Date(),
        duracaoSegundos: Double? = nil,
        status: StatusItem = .pendenteBackup,
        corSinteticaHex: String = "#087D70"
    ) {
        self.id = id
        self.nomeOriginal = nomeOriginal
        self.tipo = tipo
        self.tamanhoBytes = tamanhoBytes
        self.dataCriacao = dataCriacao
        self.duracaoSegundos = duracaoSegundos
        self.status = status
        self.corSinteticaHex = corSinteticaHex
    }

    /// Formatação amigável de tamanho para a interface.
    public var tamanhoFormatado: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: tamanhoBytes)
    }

    /// Formatação de duração para exibição em vídeos (ex: "0:18").
    public var duracaoFormatada: String? {
        guard let duracaoSegundos else { return nil }
        let totalSegundos = Int(duracaoSegundos)
        let minutos = totalSegundos / 60
        let segundos = totalSegundos % 60
        return String(format: "%d:%02d", minutos, segundos)
    }
}
