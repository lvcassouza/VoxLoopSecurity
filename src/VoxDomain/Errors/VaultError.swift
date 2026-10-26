import Foundation

/// Erros de domínio do cofre privado Vox.
public enum VaultError: LocalizedError, Equatable, Sendable {
    case credenciaisNaoCoincidem
    case credencialMuitoCurta
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
    case exportacaoIndisponivelNestaVersao
    case formatoCofreIncompativel
    case cofreBloqueado
    case restauracaoIndisponivelNestaVersao

    public var errorDescription: String? {
        switch self {
        case .credenciaisNaoCoincidem:
            return "As senhas digitadas não coincidem."
        case .credencialMuitoCurta:
            return "A credencial deve conter pelo menos 12 caracteres."
        case .credencialIncorreta:
            return "Credencial incorreta. Tente novamente."
        case .codigoRecuperacaoInvalido:
            return "Código de recuperação inválido ou não reconhecido."
        case .confirmacaoInvalida:
            return "O trecho digitado não corresponde ao código exibido."
        case .espacoInsuficiente:
            return "Espaço em disco insuficiente para concluir a importação."
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
        case .exportacaoIndisponivelNestaVersao:
            return "A exportação de arquivos reais não está disponível nesta versão demonstrativa."
        case .formatoCofreIncompativel:
            return "O formato deste cofre não é compatível com esta versão do Vox."
        case .cofreBloqueado:
            return "Desbloqueie o cofre antes de continuar."
        case .restauracaoIndisponivelNestaVersao:
            return "A restauração de arquivos de backup ainda não está disponível nesta versão."
        }
    }
}
