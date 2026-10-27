import Foundation
import os

/// Logger estritamente higienizado para o Vox.
/// Garante que nenhum nome de arquivo, mídia, credencial ou código seja registrado.
public final class SanitizedLogger: Sendable {
    public static let shared = SanitizedLogger()
    private let logger = Logger(subsystem: "com.voxloop.vox", category: "App")

    private init() {}

    public enum Evento: Sendable {
        case cofreConfigurado
        case cofreBloqueado
        case cofreDesbloqueado(metodo: String)
        case falhaAutenticacao
        case importacaoSinteticaIniciada(quantidade: Int)
        case importacaoSinteticaConcluida(quantidade: Int)
        case importacaoLocalConcluida
        case importacaoFalhou(erro: String)
        case exclusaoConcluida
        case itemLocalExcluido
        case backupExportado
        case verificacaoBackupConcluida(valido: Bool)
        case cofreResetado
    }

    public func log(_ evento: Evento) {
        switch evento {
        case .cofreConfigurado:
            logger.info("Cofre configurado com sucesso.")
        case .cofreBloqueado:
            logger.info("Cofre colocado em estado bloqueado.")
        case .cofreDesbloqueado(let metodo):
            logger.info("Cofre desbloqueado via método autorizado: \(metodo, privacy: .public).")
        case .falhaAutenticacao:
            logger.warning("Tentativa de desbloqueio sem sucesso.")
        case .importacaoSinteticaIniciada(quantidade: _):
            logger.info("Iniciando a criação de itens sintéticos de demonstração.")
        case .importacaoSinteticaConcluida(quantidade: _):
            logger.info("Itens sintéticos adicionados à demonstração.")
        case .importacaoLocalConcluida:
            logger.info("Uma cópia local foi importada para o cofre.")
        case .importacaoFalhou(let erro):
            logger.error("Importação cancelada ou falhou: \(erro, privacy: .public).")
        case .exclusaoConcluida:
            logger.info("Item sintético removido da demonstração.")
        case .itemLocalExcluido:
            logger.info("Uma cópia local foi removida do cofre.")
        case .backupExportado:
            logger.info("Cópia de backup cifrado exportada pelo seletor de arquivos.")
        case .verificacaoBackupConcluida(let valido):
            logger.info("Verificação de backup executada: resultado=\(valido).")
        case .cofreResetado:
            logger.notice("Cofre inacessível foi resetado para estado vazio.")
        }
    }
}
