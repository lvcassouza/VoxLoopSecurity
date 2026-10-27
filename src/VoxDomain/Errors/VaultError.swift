import Foundation

/// Erros de domínio do cofre privado Vox.
public enum VaultError: LocalizedError, Equatable, Sendable {
    case credenciaisNaoCoincidem
    case credencialMuitoCurta
    case padraoMuitoCurto
    case credencialIncorreta
    case codigoRecuperacaoInvalido
    case confirmacaoInvalida
    case espacoInsuficiente
    case operacaoInterrompida
    case dadoAdulterado
    case cofreJaConfigurado
    case cofreNaoVazioParaRestauracao
    case itemNaoEncontrado
    case quantidadeDeItensInvalida
    case intervaloDeLeituraInvalido
    case exportacaoTemporariaJaExiste
    case falhaNaExportacao
    case falhaNoBackup
    case falhaNaLimpezaDaExclusao
    case formatoDeMidiaNaoSuportado
    case formatoCofreIncompativel
    case cofreBloqueado

    public var errorDescription: String? {
        switch self {
        case .credenciaisNaoCoincidem:
            return "As credenciais informadas não coincidem."
        case .credencialMuitoCurta:
            return "A credencial deve conter pelo menos 12 caracteres."
        case .padraoMuitoCurto:
            return "O padrão de desbloqueio deve ligar pelo menos 4 pontos."
        case .credencialIncorreta:
            return "Credencial incorreta. Tente novamente."
        case .codigoRecuperacaoInvalido:
            return "Código de recuperação inválido ou não reconhecido."
        case .confirmacaoInvalida:
            return "O trecho digitado não corresponde ao código exibido."
        case .espacoInsuficiente:
            return "Espaço em disco insuficiente para concluir a operação."
        case .operacaoInterrompida:
            return "A operação foi interrompida antes de ser concluída."
        case .dadoAdulterado:
            return "Não foi possível abrir este item. Os dados parecem alterados ou corrompidos."
        case .cofreJaConfigurado:
            return "Este aparelho já possui um cofre configurado."
        case .cofreNaoVazioParaRestauracao:
            return "A restauração só pode ser feita em um aparelho sem cofre ativo."
        case .itemNaoEncontrado:
            return "O item solicitado não foi encontrado no cofre."
        case .quantidadeDeItensInvalida:
            return "Adicione entre 1 e 12 itens sintéticos."
        case .intervaloDeLeituraInvalido:
            return "Não foi possível ler este trecho do item."
        case .exportacaoTemporariaJaExiste:
            return "Não foi possível preparar o arquivo para exportação."
        case .falhaNaExportacao:
            return "Não foi possível concluir a exportação."
        case .falhaNoBackup:
            return "Não foi possível preparar ou verificar este backup."
        case .falhaNaLimpezaDaExclusao:
            return "O item foi removido do cofre, mas um arquivo cifrado residual não pôde ser limpo agora. Bloqueie e abra o cofre novamente para tentar a limpeza."
        case .formatoDeMidiaNaoSuportado:
            return "Este formato de mídia não pode ser exibido pelo Vox."
        case .formatoCofreIncompativel:
            return "O formato deste cofre não é compatível com esta versão do Vox."
        case .cofreBloqueado:
            return "Desbloqueie o cofre antes de continuar."
        }
    }
}
