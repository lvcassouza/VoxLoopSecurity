# Avaliação técnica consolidada — Fase 3

**Produto:** Vox, cofre privado da Voxloop
**Data:** 26 de outubro de 2026
**Rastreabilidade:** [Issue #1](https://github.com/lvcassouza/VoxLoopSecurity/issues/1), [brief de desenvolvimento](ai-development-brief.md), [ADR 0004](adr/0004-arquitetura-criptografica-e-hierarquia-de-chaves.md), [ADR 0005](adr/0005-codigo-de-recuperacao-e-restauracao.md) e [ADR 0006](adr/0006-formato-do-cofre-metadados-e-transacoes.md).

## Escopo das evidências

Esta avaliação separa o comportamento observado em código/testes das validações ainda pendentes. A compilação confirma que os destinos foram compilados; ela não demonstra execução bem-sucedida em simulador nem em iPhone físico.

## Implementado e verificado

- `VaultCrypto` usa `crypto_pwhash_ALG_ARGON2ID13` via libsodium com perfil experimental de 3 operações, 64 MiB e salt aleatório de 16 bytes. O perfil ainda precisa ser medido no modelo mínimo de iPhone suportado.
- A VK tem 256 bits aleatórios e pode ser aberta pelo envelope da credencial ou pelo envelope de recuperação. O código de recuperação tem 128 bits aleatórios, apresentado em 32 dígitos hexadecimais agrupados em quatro blocos.
- Buffers próprios de senha, código e chave são zerados best-effort em caminhos definidos; cópias transitórias do compilador, Swift ou CryptoKit não têm garantia de apagamento determinístico.
- Arquivos são cifrados em blocos de até 1 MiB com CryptoKit AES-256-GCM e DEK aleatória por item. Os nonces dos blocos usam prefixo aleatório de 32 bits e contador de 64 bits; não se afirma risco matematicamente zero em caso de colisão de DEK.
- O índice de metadados e o journal são autenticados e cifrados. Os nomes dos arquivos no cofre usam UUIDs. Contagem de arquivos, tamanhos aproximados, quantidade de blocos e padrões de atividade ainda podem ser inferidos do filesystem.
- `PhotosPicker` aceita até 12 seleções de fotos/vídeos, cria uma cópia local cifrada e preserva a origem na Fototeca. O seletor também aceita mídia pessoal; o app não consegue distingui-la, portanto esta versão deve ser usada somente com arquivos de teste.
- O código calcula duração de vídeo; não extrai dimensões de fotos ou vídeos. A cópia temporária é removida com `FileManager.removeItem`, o que não comprova apagamento físico seguro.
- `swift test` passou com 6 testes. Os testes usam bytes e falhas sintéticas; o arquivo de 1,5 MiB com extensão `.mov` não é um vídeo codificado válido.
- `xcodebuild` compilou o esquema `Vox` para `generic/platform=iOS Simulator` e `generic/platform=iOS`, ambos com código de saída 0. Não houve validação de runtime em aparelho físico.
- Não há implementação de backup nesta fase. Portanto, não existe arquivo `.voxbackup` nem assinatura digital; no futuro, “cifrado/autenticado” não deve ser chamado de “assinado” sem um mecanismo de assinatura assimétrica definido.

## Transação local e limites de durabilidade

A importação escreve o arquivo cifrado em `staging/`, sincroniza e relê os blocos para validar suas tags, grava um journal autenticado, move o arquivo para `items/`, substitui o índice por escrita atômica e remove o journal. No desbloqueio, o app reconcilia um journal válido e verifica os itens referenciados.

Isso é uma **transação local recuperável por journal**, com escritas atômicas individuais. Não é uma transação física única nem prova durabilidade contra encerramento abrupto, perda de energia ou erro real de disco cheio. Os testes injetam falhas em quatro pontos definidos; não simulam essas falhas físicas.

## Biometria

A biometria permanece desativada nesta fase. Se implementada depois, deve seguir o ADR 0004: envelope local no Keychain com `WhenPasscodeSetThisDeviceOnly` e `biometryCurrentSet`, mantendo a credencial principal como alternativa. Este documento não substitui nem altera a decisão do ADR.

## Fora do código atual e gates

- Fase 4: visualização real decifrada e exportação; a tela de detalhes ainda usa prévia ilustrativa.
- Fase 5: criação/verificação de backup e restauração em outro aparelho.
- Antes de beta ou publicação: medir Argon2id no hardware mínimo, validar importação, proteção de arquivos e falhas em iPhones físicos, demonstrar restauração entre dois iPhones e concluir auditoria de segurança independente.

O protótipo continua experimental. Não deve ser descrito como seguro, auditado ou pronto para produção. O issue tracker mantém os gates humanos em aberto.
