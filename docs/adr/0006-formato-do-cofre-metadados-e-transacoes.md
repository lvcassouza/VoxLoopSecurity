# Formato do cofre, metadados e transações

Estado: aprovado pelo proprietário em 26 de outubro de 2026 para implementação experimental da Fase 3.

## Contexto

Com o cofre fechado, nomes, datas, tipos e demais metadados ficam cifrados. A importação pode sofrer encerramento forçado ou falta de espaço; um arquivo só pode aparecer no índice após validação criptográfica.

## Decisão

1. **Layout:** cabeçalho versionado guarda parâmetros Argon2id e envelopes cifrados da VK. O catálogo completo é codificado em JSON e cifrado com AES-256-GCM sob VK. Cada item usa UUID aleatório no nome `<UUID>.enc`; o catálogo guarda metadados e DEK embrulhada com VK. Aplicar proteção de arquivo completa do iOS e excluir o diretório de backup automático do sistema.

2. **Conteúdo grande:** cifrar por blocos de até 1 MiB, sem carregar o vídeo inteiro em memória. Cada registro contém comprimento seguido de ciphertext e tag GCM; nonce e AAD seguem ADR 0004. O índice autenticado guarda o tamanho e quantidade de blocos esperados. O leitor falha diante de tag inválida, bloco faltante, truncamento, excesso ou ordem incorreta.

3. **Metadados e vazamento residual:** nomes, datas, dimensões, duração, tipo e índice são cifrados. Nomes UUID ocultam nomes originais, mas o número de arquivos, seus tamanhos aproximados, quantidade de blocos, temporização e padrão de atividade podem ser observados pelo contêiner. Não afirmar que a contagem ou o tamanho estão ocultos. Padding para reduzir esses vazamentos fica fora desta fase.

4. **Transação recuperável de um item por vez:** gravar e sincronizar o item cifrado em `staging/`; verificar todos os blocos lendo e autenticando novamente; gravar um journal cifrado com a VK; mover o arquivo para `items/`; gravar o novo índice por escrita atômica; remover journal e temporários. No próximo desbloqueio, reconciliar o journal: se o índice já contém o item, limpar journal; se o arquivo final ou staging existe e autentica, concluir o commit; se nenhum valida, descartar artefatos e manter o índice antigo. Órfãos sem journal nunca entram no índice.

5. **Falta de espaço e erros:** fazer estimativa de espaço antes da escrita e tratar erros durante a operação com rollback/reconciliação. A estimativa não garante que haja espaço até o fim. Espaço insuficiente ou cancelamento nunca pode resultar em item publicado parcialmente.

6. **Bloqueio:** limpar a VK e metadados da memória ao bloquear/ir para segundo plano. Não manter miniaturas em cache claro. Logs contêm apenas códigos de erro e eventos sem nomes, tamanho, conteúdo ou segredos.

## Consequências e limites

- A cópia de staging exige espaço adicional. A escrita atômica do catálogo é por arquivo; o journal dá recuperação lógica entre operações, não uma transação de hardware distribuída.
- A garantia de durabilidade precisa ser validada em iPhones reais, encerramentos forçados e falta de espaço. Crashes e interrupções do sistema de arquivos não são demonstrados por testes unitários comuns.
- Contagem/tamanho aproximado e outros padrões de acesso permanecem visíveis. Não há promessa de sigilo absoluto de metadados.
- Este ADR não constitui auditoria nem autoriza uso com mídia real ou publicação.
