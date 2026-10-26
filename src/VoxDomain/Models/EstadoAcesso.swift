import Foundation

/// Estados explícitos de acesso ao cofre conforme a especificação.
public enum EstadoAcesso: Equatable, Sendable {
    case naoConfigurado
    case bloqueado
    case desbloqueado
    case recuperando
}

/// Estados do backup exibidos na aba Backup (conforme seção 6.7 de ui-visual-spec.md).
public enum EstadoBackup: Equatable, Sendable {
    case nuncaCriado
    case atualizado(data: Date, contagemItens: Int)
    case desatualizado(dataUltimo: Date?, itensPendentes: Int)

    public var rotulo: String {
        switch self {
        case .nuncaCriado:
            return "Nunca criado"
        case .atualizado:
            return "Atualizado"
        case .desatualizado:
            return "Backup desatualizado"
        }
    }

    public var descricao: String {
        switch self {
        case .nuncaCriado:
            return "Você ainda não criou um backup."
        case .atualizado(let data, let contagem):
            let formatador = DateFormatter()
            formatador.dateStyle = .short
            formatador.timeStyle = .short
            return "Último backup em \(formatador.string(from: data)) com \(contagem) itens."
        case .desatualizado:
            return "Há itens que ainda não estão no backup."
        }
    }
}

/// Resultado da verificação de backup sem modificar o cofre atual.
public enum ResultadoVerificacaoBackup: Equatable, Sendable {
    case legivel(data: Date, contagemItens: Int)
    case impossivelVerificar(motivo: String)
    case formatoIncompativel(versaoEncontrada: String)
}

/// Modos de simulação para testes e verificação na Casca da Fase 2.
public enum ModoSimulacaoBackup: Sendable {
    case integro
    case adulterado
    case versaoIncompativel
}
