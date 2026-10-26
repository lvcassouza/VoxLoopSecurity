# Brief de desenvolvimento para IA — Vox

**Uso:** entregar este documento a uma IA de desenvolvimento para orientar a construção do protótipo e a evolução do app.

**Estado:** ADRs 0004–0006 aprovados pelo proprietário em 26 de outubro de 2026 para implementação experimental da Fase 3; validação física e revisão independente continuam pendentes.

**Produto:** Vox, cofre privado da Voxloop.

**Referência factual da Fase 3:** [Avaliação técnica consolidada](avaliacao-tecnica-fase-3.md) é o registro oficial versionado das evidências de implementação e verificação dessa fase. Os ADRs continuam sendo a fonte de verdade para decisões duradouras; atualize a avaliação quando as evidências mudarem.

## 1. Comece por estas fontes

Antes de planejar ou editar código, leia nesta ordem:

1. [AGENTS.md](../AGENTS.md) e [CONTEXT.md](../CONTEXT.md): regras do repositório e linguagem do domínio.
2. [ADRs](adr/): decisões permanentes já registradas.
3. [Descoberta do produto](discovery.md): público, escopo, ameaças prioritárias, decisões e gates.
4. [Especificação de UI/UX](ui-visual-spec.md): fluxos, conteúdo, componentes e identidade visual.

O documento inicial recebido em `inicio-projeto-cofre-seguro.md` era uma proposta. Use apenas as decisões que foram confirmadas em `docs/discovery.md`; trate o restante como hipótese. Se uma instrução nova do proprietário divergir destes documentos, siga a instrução nova e atualize a fonte de verdade afetada.

## 2. Resultado a construir

Construir primeiro um protótipo **interno, local e sem nuvem**, para iPhone, que usa somente fotos e vídeos de teste. A pessoa cria um cofre, importa arquivos, fecha e reabre o app, autentica e vê os itens; o protótipo detecta dados alterados/corrompidos e trata interrupção e falta de espaço sem apresentar gravações parciais como concluídas.

O protótipo não é um produto pronto para arquivos reais, backup único ou publicação. Não anuncie segurança comprovada. O desenho de segurança, a restauração em outro aparelho e uma revisão independente são gates anteriores ao lançamento público.

## 3. Escopo de produto confirmado

- Público inicial: pessoas que guardam fotos e vídeos pessoais no iPhone.
- Um cofre por instalação; uso local e offline após a configuração.
- Importação pela Fototeca. O app cria uma cópia no cofre e deixa a origem na Fototeca.
- Face ID/Touch ID é uma conveniência opcional. A credencial principal continua disponível como alternativa.
- Ao ir para segundo plano, esconder a prévia e bloquear o app; antes de mostrar miniaturas novamente, pedir autenticação.
- O primeiro lançamento público prevê backup criptografado escolhido pela pessoa, verificação sem sobrescrever o cofre e restauração. Não haverá conta obrigatória, nuvem Voxloop, sincronização, compartilhamento, anúncios ou compras no app.
- Exportar cria cópia externa. Apagar do cofre não apaga a origem, exportações ou backups anteriores.
- A recuperação usa um código separado da credencial principal; o código sozinho não recria arquivos ausentes de um backup.
- Sem analytics de terceiros. Logs e relatórios não contêm mídia, nomes sensíveis, credenciais ou códigos de recuperação.
- Documentos, captura pela câmera dentro do app, iPad, Android e funcionalidades sociais ficam fora do primeiro lançamento.

Consulte `docs/discovery.md` e `docs/ui-visual-spec.md` antes de alterar qualquer um desses limites.

## 4. Direção técnica recomendada

O projeto contém um app SwiftUI nativo para iPhone. Confirme o estado atual antes de novas alterações. Prefira frameworks Apple para seleção de fotos, autenticação local e escolha/importação/exportação de arquivos.

`PhotosPicker`, CryptoKit/AES-256-GCM e Argon2id via libsodium foram escolhidos nos ADRs 0004–0006 para a Fase 3. A implementação ainda é experimental. Keychain/biometria e APIs de documento para backup continuam decisões de fases posteriores. Biometria confirma autenticação local; ela, por si só, não define nem substitui o modelo de chaves do cofre.

Não crie backend, conta, analytics ou dependência de rede para o fluxo principal. Não crie criptografia própria. Escolha primitivas estabelecidas e autenticadas; documente o algoritmo de derivação de chaves, hierarquia de chaves, política de nonces, formato de dados, tratamento de arquivos grandes e rotação/recuperação antes de implementá-los. Qualquer desenho que permita tentativa offline de credenciais precisa modelar e limitar esse risco.

Referências técnicas de partida:

- [Apple SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Apple PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker)
- [Apple LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [Apple CryptoKit AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
- [OWASP MASVS](https://mas.owasp.org/MASVS/)

## 5. Ordem de execução

### Fase 0 — Inspecionar e orientar

1. Leia as fontes da seção 1 e inspecione a estrutura, branches, arquivos, comandos e estado Git existentes.
2. Identifique o que já existe antes de propor substituições ou scaffolding.
3. Consulte/crie o ticket GitHub apropriado segundo `docs/agents/issue-tracker.md`; use os labels definidos em `docs/agents/triage-labels.md`.

**Concluída quando:** o agente apresenta uma leitura curta do estado real do repo, escopo desta entrega e comandos de build/teste disponíveis, sem inventar ferramentas que não encontrou.

### Fase 1 — Fechar arquitetura de segurança antes da criptografia

Produza um modelo de ameaças e ADRs para:

- ativos: conteúdo, metadados, credencial principal, código de recuperação, chaves, arquivos temporários e backups;
- adversários: alguém com o iPhone perdido e bloqueado; alguém com uma cópia do contêiner do app e tempo para tentar credenciais offline;
- limite explícito: aparelho comprometido com o cofre aberto fica fora da promessa de sigilo;
- hierarquia e ciclo de vida das chaves; autenticação local; biometria; tentativas e recuperação;
- criptografia autenticada, derivação da credencial, formato versionado, integridade e migração;
- armazenamento em repouso, metadados, miniaturas, cache, memória, logs e proteção de dados do iOS;
- backup, validação, restauração em outro aparelho, credencial/código novos e backups antigos que permanecem sob controle da pessoa;
- comportamento consistente após encerramento forçado, interrupção, espaço insuficiente e dado corrompido.

Faça revisão de arquitetura com foco em mobile security antes de implementar a criptografia e a recuperação reais. Se não houver informação suficiente para escolher com segurança, implemente apenas uma casca de UI com dados sintéticos e apresente a decisão pendente com alternativas e impacto. Não transforme uma suposição em uma promessa de produto.

ADRs 0004–0006 foram revisados pelo proprietário em 26 de outubro de 2026 para esta implementação interna. Use somente arquivos sintéticos no desenvolvimento e nos testes automatizados; não selecione nem teste mídia pessoal. Essa revisão não é auditoria e não autoriza alegações de segurança ou publicação.

**Estado:** decisões criptográficas para Fase 3 registradas e revisadas; threat model atualizado. Medição de Argon2id no aparelho mínimo e revisão independente seguem pendentes antes de beta/público.

### Fase 2 — Casca de app e estados de acesso

Implemente a navegação e os fluxos da especificação visual com dados falsos: boas-vindas, criação de credencial, confirmação do código de recuperação, oferta opcional de biometria, tela bloqueada, grid, backup e ajustes.

Mantenha estados de acesso explícitos — por exemplo: não configurado, bloqueado, desbloqueado e recuperação em andamento. A transição para segundo plano deve esconder mídia antes de qualquer snapshot visível. Uma falha de biometria deve oferecer a credencial principal.

**Concluída quando:** todos os caminhos principais e estados vazios/erro da UI spec são navegáveis com dados sintéticos, sem mídia ou segredo real persistido.

### Fase 3 — Cofre local e importação transacional

Após a aprovação da fase 1, implemente o formato local e a persistência criptografada sob interfaces pequenas e testáveis. Importe fotos/vídeos selecionados pelo picker do sistema; preserve a origem. A importação deve ser transacional: o item só aparece como concluído após gravação e verificação.

**Estado parcial:** testes sintéticos cobrem importação em blocos, bloqueio, relançamento, desbloqueio, adulteração, recuperação do journal e exclusão. Ainda falta validar o picker e a proteção de arquivos em iPhones físicos, baixa de espaço real e encerramento forçado do processo no dispositivo.

### Fase 4 — Visualização, exportação, exclusão e troca de credencial

Implemente visualização sem cache indevido, exportação com confirmação de cópia externa, exclusão somente da cópia no cofre, e troca de credencial conforme o ADR. A UI sempre declara o efeito sobre origem e backups anteriores.

**Estado parcial (26 de outubro de 2026):** a implementação experimental oferece leitura autenticada por faixa, prévias em memória, reprodução por `AVAssetResourceLoader`, exportação temporária protegida e seleção nativa de destino, além de exclusão com estado de erro explícito. `swift test` (7 testes) e build do esquema `Vox` para iOS Simulator passaram; isso não valida reprodução/exportação em iPhones físicos nem constitui auditoria. O gate humano da [Issue #1](https://github.com/lvcassouza/VoxLoopSecurity/issues/1) permanece aberto.

**Concluída quando:** cada ação apresenta resultado inequívoco e erros deixam o estado anterior consistente; nenhum fluxo sugere apagar cópias que o app não controla.

### Fase 5 — Backup, verificação e restauração

Implemente criação opcional do arquivo de backup e escolha do destino pela interface nativa. Mostre data do último backup e alterações posteriores. A verificação lê o arquivo sem alterar o cofre. A restauração de outro aparelho preserva o arquivo-fonte e não sobrescreve nem mescla silenciosamente um cofre existente.

**Concluída quando:** backup íntegro e backup alterado têm resultados diferentes; operação interrompida não é apresentada como concluída; restauração de um backup em outro aparelho reproduz apenas os itens daquele backup; backup antigo continua explicitamente distinto do atual.

### Fase 6 — Preparar beta e lançamento

Só depois do gate anterior, testar com pessoas e arquivos reais em ambiente controlado. Antes da publicação, executar restauração em outro iPhone, revisar cenários de falha e obter avaliação independente de segurança móvel. Finalizar privacidade, claims, App Store e declaração de uso/exportação de criptografia.

**Concluída quando:** cada gate tem evidência anexada, nenhuma falha crítica fica aberta, e todas as alegações públicas correspondem a resultados verificados.

## 6. Critérios transversais

- Use os termos do `CONTEXT.md` em código de domínio, documentação, labels e testes.
- Preserve a linguagem visual e os fluxos definidos em `docs/ui-visual-spec.md`; mantenha tokens de cor num único lugar no código.
- Trate cada importação, troca de credencial, backup e restauração como operação que pode ser interrompida. O fluxo local de importação usa journal recuperável; backup e restauração continuam fora da implementação.
- Inclua testes unitários para derivação/formato/integração de criptografia aprovados e testes de integração para reabertura, adulteração, interrupção e falta de espaço.
- Teste acessibilidade: VoiceOver, Dynamic Type, contraste, reduzir movimento, botões e telas bloqueadas nos modos claro/escuro.
- Rode os comandos reais de lint/build/teste encontrados no repo; não relate um gate como aprovado sem resultado observável.
- Mantenha ADRs curtos e atualizados. Se o código divergir da decisão registrada, atualize a decisão ou corrija o código no mesmo trabalho.

## 7. Entregas de cada tarefa de desenvolvimento

Ao concluir uma etapa, informe:

1. O que foi implementado e em quais arquivos.
2. Quais critérios de aceite passaram e qual evidência foi obtida.
3. Decisões novas registradas em ADR e documentação atualizada.
4. O que continua pendente e se bloqueia a etapa seguinte.
5. Riscos de segurança ou limitações que ainda impedem beta/publicação.

Não descreva o protótipo como seguro ou pronto para publicação. Use exatamente o alcance de evidência que os testes e a revisão sustentam.
