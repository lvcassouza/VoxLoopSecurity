# Vox — especificação de UI/UX e identidade visual

**Versão:** 1.0, 24 de outubro de 2026
**Status:** proposta de produto baseada nas decisões da descoberta. Requisitos visuais aprovados podem orientar protótipo; promessas de segurança continuam condicionadas à revisão independente.

## 1. Nomenclatura e arquitetura da marca

- **Marca do site e da organização:** Voxloop
- **Nome curto do aplicativo e assinatura visual:** Vox
- **Descritor do produto:** Cofre privado
- **Nome sugerido para a ficha da App Store:** **Vox — Cofre Privado**
- **Subtítulo sugerido:** **Fotos e vídeos no iPhone**
- **Apresentação no site:** **Vox, o cofre privado da Voxloop**
- **Endereço:** `voxloop.com.br`
- **Assinatura curta:** **Seus arquivos. No seu controle.**

Assim, “Vox” fica no ícone, na tela inicial e na conversa cotidiana; “Voxloop” identifica o site e a marca responsável. Não usar “VoxLoop” como nome do app: já há um app chamado “VoxLoop: Fale Inglês e mais” na App Store. A Apple recomenda nomes distintos, e reserva o mesmo nome por localização no App Store Connect. A disponibilidade de “Vox — Cofre Privado” ainda precisa ser conferida ao criar o registro da loja. A busca de marca no INPI e a análise de marca devem ocorrer antes de fechar o lançamento.

## 2. Posicionamento visual

Vox deve parecer um espaço pessoal, calmo e confiável. A interface dá prioridade às fotos e aos controles que ajudam a entender cópias, backup e recuperação. Não usar estética de “hacker”, cofres metálicos, cadeados grandes, escudos, neon, ruído ou telas cheias de avisos vermelhos.

Princípios de produto:

1. **Privacidade visível:** mostrar quando o cofre está bloqueado e explicar quando uma ação cria uma cópia externa.
2. **Controle sem surpresa:** importar, exportar, apagar e fazer backup são ações distintas, cada uma com explicação clara.
3. **Pouca fricção no caminho principal:** abrir o cofre, localizar fotos e importar são os primeiros elementos da hierarquia.
4. **Tom discreto:** textos curtos, precisos e sem promessas absolutas.
5. **iOS reconhecível:** usar controles nativos, SF Symbols, gesto de voltar, folhas e alertas do sistema quando apropriado.

## 3. Logo e uso da marca

### Conceito

O símbolo combina um **V** com um ciclo aberto. O V nomeia Vox; o ciclo sugere continuidade e restauração. A abertura representa um fluxo controlado pela pessoa. O desenho evita cadeados e escudos genéricos.

### Arquivos entregues

- [Símbolo vetorial](../assets/brand/vox-mark.svg): versão transparente para fundos claros.
- [Símbolo inverso](../assets/brand/vox-mark-inverse.svg): versão transparente para fundos escuros.
- [Ícone quadrado mestre](../assets/brand/vox-app-icon.svg): fundo azul petróleo e símbolo central.
- [Assinatura Vox](../assets/brand/vox-lockup.svg): símbolo e wordmark para site e documentos.

### Regras de uso

- Usar o ícone quadrado sem texto no iPhone; manter área livre equivalente a 12% da largura em volta do símbolo.
- Não desenhar máscara de cantos por cima do ícone final. Preparar o mestre para as aparências atuais do iOS e derivar variantes no fluxo de assets da Apple.
- Na versão clara, usar símbolo em azul petróleo sobre fundo marfim; na versão escura, usar símbolo marfim/mint sobre azul profundo.
- No site, preferir assinatura horizontal `vox` e posicionar “by Voxloop” ou “da Voxloop” apenas em rodapé, onboarding ou página institucional.
- Não deformar, inclinar, aplicar contorno, adicionar brilho, sombra, gradiente, textura ou slogan dentro do ícone.
- O wordmark é sempre minúsculo (`vox`), com peso semibold e espaçamento compacto. Em texto corrido, escrever `Vox` com inicial maiúscula.

## 4. Sistema visual

### Cores — modo claro

| Token | Hex | Uso |
|---|---|---|
| `canvas` | `#F6F8F6` | Fundo principal |
| `surface` | `#FFFFFF` | Folhas, áreas elevadas e campos |
| `surface-muted` | `#EDF2EF` | Blocos de informação e seleção secundária |
| `ink` | `#173238` | Texto principal, wordmark e ícones fortes |
| `ink-secondary` | `#52656A` | Texto auxiliar |
| `brand` | `#087D70` | Ação primária, item selecionado, links |
| `brand-text` | `#FFFFFF` | Texto sobre `brand` no modo claro |
| `brand-pressed` | `#06665C` | Estado pressionado |
| `brand-soft` | `#DDF7EE` | Seleção, foco e fundos ilustrativos |
| `border` | `#D9E3DF` | Divisores e contornos de campo |
| `success` | `#176B50` | Backup verificado, operação concluída |
| `warning` | `#8A5A00` | Backup desatualizado, espaço baixo |
| `danger` | `#B42318` | Falha, apagar cofre ou item |

### Cores — modo escuro

| Token | Hex | Uso |
|---|---|---|
| `canvas` | `#101A1C` | Fundo principal |
| `surface` | `#182528` | Folhas, áreas elevadas e campos |
| `surface-muted` | `#223236` | Blocos de informação |
| `ink` | `#F2F7F4` | Texto principal |
| `ink-secondary` | `#B5C4C0` | Texto auxiliar |
| `brand` | `#70D9BE` | Ação primária e seleção |
| `brand-text` | `#101A1C` | Texto sobre `brand` no modo escuro |
| `brand-pressed` | `#A3EBD7` | Estado pressionado |
| `brand-soft` | `#193D38` | Seleção e fundos ilustrativos |
| `border` | `#34484A` | Divisores e campos |
| `success` | `#75D6A7` | Confirmação |
| `warning` | `#F1C56E` | Atenção |
| `danger` | `#FF8C82` | Falha e ação destrutiva |

O app acompanha a aparência do sistema desde a primeira abertura. Evitar cor como único indicador: estados de backup devem ter ícone, rótulo e texto além da cor. Validar combinações finais em contraste WCAG AA; para texto comum, alvo mínimo de 4,5:1 e 3:1 para texto grande ou negrito, como a Apple orienta.

Combinações principais calculadas a partir dos tokens atuais: `brand`/texto branco no modo claro **5,03:1**; `ink`/`canvas` **12,70:1**; `ink-secondary`/`canvas` **5,74:1**; aviso âmbar/fundo de aviso **5,38:1**; `brand` mint/`brand-text` no modo escuro **10,41:1**. Recalcular se qualquer cor mudar.

### Tipografia

- Usar San Francisco / fonte de sistema do iOS; não embutir fonte decorativa.
- Construir os estilos com Dynamic Type, não com tamanhos fixos.
- Referências em tamanho padrão: título de tela 28 pt semibold; título grande 34 pt bold; seção 20 pt semibold; corpo e botões 17 pt; legenda 13–15 pt.
- Texto auxiliar não deve carregar informação crítica de segurança sozinho.
- Não reduzir texto de instrução essencial abaixo do estilo footnote do sistema. A interface deve acomodar o maior tamanho de texto sem cortar botões ou mensagens.

### Espaçamento, formas e elevação

- Escala base de 4 pt: 4, 8, 12, 16, 24, 32 e 40 pt.
- Margem horizontal padrão: 20 pt; telas de autenticação e confirmação: 24 pt.
- Áreas tocáveis: pelo menos 44 × 44 pt; ícones visuais podem ser menores dentro da área.
- Botões primários: altura visual 52 pt, raio 15 pt, texto 17 pt semibold.
- Campos: altura mínima 52 pt, raio 13 pt, contorno de 1 pt.
- Cartões: raio 16 pt, sem sombra forte; usar fundo e espaçamento para separar grupos.
- Folhas: cantos superiores 24 pt e conteúdo respeitando safe areas.
- Miniaturas: grade com raio 6 pt e espaçamento de 3 pt, sem moldura decorativa.
- Divisores de 1 pt só quando a hierarquia não puder ser comunicada por espaço.

### Ícones, fotografia e movimento

- SF Symbols como família principal; usar símbolo preenchido para estado selecionado e rótulo nos controles importantes.
- Não criar símbolo de cadeado customizado para navegação. O logo é o único ícone de marca.
- Miniaturas preservam o enquadramento; usar aspect-fill no grid e aspect-fit quando a pessoa abrir a foto completa.
- Não aplicar moldura, filtro ou tratamento às fotos privadas.
- Transições discretas de 180–240 ms; respeitar “Reduzir Movimento”. Sem animação pulsante para estados de segurança.
- Ao entrar em segundo plano, ocultar conteúdo imediatamente na captura do seletor de apps. Ao voltar, mostrar a tela bloqueada antes de mostrar qualquer miniatura.

## 5. Arquitetura de informação

Barra inferior nativa com três destinos, sempre rotulados:

| Destino | Símbolo sugerido | Conteúdo |
|---|---|---|
| **Cofre** | `square.grid.2x2` | Fotos e vídeos, seleção, busca |
| **Backup** | `externaldrive` | Estado, criar, verificar e restaurar backup |
| **Ajustes** | `gearshape` | Desbloqueio, recuperação, privacidade e ajuda |

Não ocultar ou desativar abas. Em telas modais, a barra pode ser coberta pela folha nativa. A aba Cofre é a inicial após desbloqueio.

## 6. Telas e comportamento

### 6.1 Boas-vindas

- Logo central pequeno; título “Um espaço privado para suas fotos e vídeos.”
- Texto de apoio: “O Vox guarda uma cópia dentro do cofre. A foto na Fototeca continua onde está.”
- Ação primária: **Criar meu cofre**.
- Ação secundária: **Restaurar de um backup**.
- Link discreto: **Como funciona a recuperação**.
- Não pedir permissão de Fotos, notificações ou biometria nesta tela.

### 6.2 Criar credencial

- Uma tela curta com campo de senha/frase e confirmação.
- Mostrar/ocultar o campo, botão claro e acessível.
- Orientação acima do teclado: “Use uma frase longa e exclusiva. Você vai precisar dela para abrir o Vox.”
- A regra final de tamanho/força depende do desenho criptográfico aprovado; não mostrar um medidor de força arbitrário.
- Erros aparecem abaixo do campo, com foco e anúncio por VoiceOver.

### 6.3 Código de recuperação

- Explicar primeiro: “Este código ajuda a recuperar o acesso se você esquecer sua senha. Ele não recupera arquivos sem um backup.”
- Mostrar código isolado, com botão **Copiar código** e **Salvar nos Arquivos** quando implementado com segurança.
- Pedir confirmação digitando um trecho aleatório, sem exigir que a pessoa revele o código em suporte.
- Avisar para guardar separado do iPhone; não sugerir salvar em Fotos ou enviar por mensagem.
- CTA: **Guardei meu código**; não prosseguir sem a confirmação.
- O fluxo e o formato finais dependem da revisão criptográfica.

### 6.4 Biometria

- Depois de confirmar a credencial e o código, oferecer Face ID como opção: “Desbloqueie mais rápido neste iPhone.”
- Ações: **Ativar Face ID** e **Agora não**.
- A senha continua disponível. Se biometria falhar ou não estiver disponível, abrir o campo de senha sem bloquear a pessoa.
- Solicitar a autorização do sistema no contexto do gesto, não antes.

### 6.5 Cofre — grade principal

- Título de navegação: **Cofre**; botão de busca e botão de ajustes na barra superior.
- Grid de três colunas, miniaturas quadradas, sem nomes de arquivo.
- Vídeos recebem pequeno símbolo de reprodução e duração no canto inferior, com fundo translúcido de contraste.
- Seções por mês/ano só dentro do cofre desbloqueado; a privacidade exige esconder o grid ao bloquear.
- Botão de ação primária fixo acima da barra inferior: **Importar fotos**.
- Ao selecionar itens, mostrar contador e toolbar contextual com **Exportar** e **Apagar do cofre**. A ação de apagar fica em cor semântica destrutiva e nunca é a ação primária.
- Não usar swipe como único meio para exportar/apagar.

**Estado vazio:** ilustração simples do símbolo Vox, título “Seu cofre está vazio”, explicação de que importar cria uma cópia e botão **Importar fotos**.

**Busca:** busca local por metadados disponíveis no cofre; campo não deve revelar termos buscados em notificações ou analytics. Se a busca por nome não for suportada, não mostrar o affordance.

**Permissão de Fotos:** pedir acesso apenas quando a pessoa tocar em importar. Explicar por que o acesso é necessário antes do diálogo nativo. Tratar acesso limitado sem bloquear a tela; oferecer **Selecionar mais fotos**.

**Fluxo de importação:** usar o seletor nativo de fotos. Após a seleção, mostrar “X itens selecionados”, botão **Importar X itens** e lembrete “As fotos originais continuam na Fototeca”. Mostrar progresso e contagem; se a pessoa cancelar, identificar itens concluídos e interrompidos. Não anunciar sucesso para itens não confirmados como gravados.

### 6.6 Visualização de item

- Fundo escuro no modo de visualização para destacar a foto; chrome mínimo e estado do sistema respeitado.
- Voltar no canto superior; botão **Mais opções** com rótulo acessível.
- Ações: **Exportar**, **Apagar do cofre**, **Detalhes**.
- Exportar abre uma confirmação curta: “Uma cópia será criada fora do Vox. O destino controla o que acontece com ela.” Botões **Continuar** e **Cancelar**.
- Apagar pergunta “Apagar esta cópia do cofre?” e explica que a foto original e backups anteriores permanecem. CTA destrutivo **Apagar do cofre**.
- Se um vídeo estiver sendo processado ou não puder ser aberto, mostrar estado com texto e opção de tentar de novo.

### 6.7 Aba Backup

Sempre mostrar um de três estados, em texto e símbolo:

1. **Nunca criado:** “Você ainda não criou um backup.” CTA **Criar backup**.
2. **Atualizado:** data e horário do último backup, quantidade incluída e estado **Atualizado**.
3. **Desatualizado:** “Há itens que ainda não estão no backup.” Mostrar data do backup anterior e CTA **Criar novo backup**.

Bloco fixo de esclarecimento: “Um backup guardado apenas neste iPhone pode ser perdido junto com ele.”

**Criar backup:** confirmar que será preparado um arquivo criptografado; então abrir seletor de destino nativo. Progresso informa etapa e número/percentual, permite cancelar com confirmação. Nunca indicar sucesso se a escrita foi interrompida.

**Verificar backup:** selecionar um arquivo via interface nativa; não substituir o cofre atual. Resultado usa ícone + texto:

- **Backup legível:** data e contagem reconhecidas; nota “A verificação não substitui um teste de restauração.”
- **Não foi possível verificar:** explique o erro conhecido, mantenha o arquivo intacto e ofereça tentar outro arquivo.
- **Formato não compatível:** orientar atualização do app sem prometer migração até ela existir.

### 6.8 Restaurar em aparelho novo

- Entrada na boas-vindas e em Ajustes: **Restaurar de um backup**.
- Abrir o seletor de Arquivos; mostrar nome, data e tamanho do arquivo selecionado antes de continuar.
- Explicar que o processo cria um novo cofre a partir do backup e não faz sincronização contínua.
- Pedir o código de recuperação conforme o fluxo aprovado; nunca pedir que seja enviado a suporte.
- Mostrar progresso, permitir cancelar antes da confirmação final e tratar espaço insuficiente sem descartar o backup original.
- Conclusão: “Restauração concluída” com contagem dos itens. Avisar que itens adicionados depois da criação do backup não estarão presentes.
- Mensagens específicas devem diferenciar arquivo inválido, código incorreto, versão incompatível e falta de espaço sem revelar detalhes que ajudem tentativa offline.
- Se já houver itens no aparelho de destino, não sobrescrever nem mesclar automaticamente. Interromper e explicar que a restauração foi desenhada para configurar um cofre vazio até existir uma regra de migração aprovada.

### 6.9 Ajustes

Grupos nesta ordem:

1. **Desbloqueio:** Face ID ligado/desligado e ação para trocar credencial.
2. **Recuperação:** ver estado do código e criar novo código; alertar que backups antigos não são revogados pela troca.
3. **Privacidade:** explicação do que o app protege e dos limites, com acesso à política de privacidade.
4. **Armazenamento:** espaço usado pelo cofre e instruções para originais na Fototeca.
5. **Sobre:** versão, Voxloop, site e contato.
6. **Apagar este cofre:** ação destrutiva separada no fim, com autenticação e confirmação digitada.

Não colocar `Sair` como substituto de bloqueio automático. O app bloqueia ao ir para segundo plano conforme decisão do produto.

### 6.10 Bloqueio e falhas

- Ao retornar do segundo plano, cobrir a tela com a marca e “Seu cofre está bloqueado”. Nunca congelar um frame com fotos visíveis.
- CTA Face ID se disponível; alternativa sempre visível **Usar senha**.
- Incluir a ação secundária **Perdi o acesso**. Primeiro explicar onde encontrar o código/backup; se ambos os segredos foram perdidos, oferecer apagar o cofre inacessível e começar um vazio após uma confirmação destrutiva explícita.
- Mensagem de falha de autenticação é neutra e não sugere que o cofre foi apagado.
- Ao detectar dado alterado/corrompido, não mostrar conteúdo parcial como se estivesse íntegro. Exibir “Não foi possível abrir este item” e **Tentar novamente**.
- Sem espaço: preservar itens já confirmados, identificar qual ação parou e oferecer liberar espaço/retentar; não indicar que o item foi salvo se o commit falhou.

## 7. Componentes e estados

- **Botão primário:** uma ação principal por tela; fundo `brand`, texto branco/claro; estado carregando mantém largura e rótulo anunciado.
- **Botão secundário:** superfície com contorno `border`; sempre nomeado por verbo.
- **Botão destrutivo:** vermelho sem preenchimento em contexto comum; preenchimento vermelho só na confirmação final.
- **Campo secreto:** rótulo persistente, teclado adequado, sem auto-correção ou preenchimento de terceiros não solicitado; mostrar/ocultar; VoiceOver descreve estado.
- **Linha de estado:** símbolo, título, detalhe e ação. Cor não é a única diferença.
- **Folha de confirmação:** resumo do efeito, consequência sobre originais/backup e dois botões explicitamente nomeados.
- **Indicador de progresso:** rótulo da tarefa e progresso; não usar spinner infinito sem texto.
- **Seleção de grade:** checkmark e contorno em mint; anunciar “Selecionado” para VoiceOver.
- **Sem conexão:** nenhuma tela de erro para uso local; indicar “Disponível offline” em Ajuda, não como banner persistente.

## 8. Linguagem de interface

- Português brasileiro natural, frases curtas e voz ativa.
- Usar “cofre”, “arquivo de origem”, “cópia no cofre”, “backup”, “verificar” e “restaurar” de forma consistente.
- Evitar “sincronizar” para a experiência de backup e restauração.
- Evitar “invulnerável”, “impossível de acessar”, “100% seguro”, “criptografia militar” e “apagamento definitivo”.
- Exemplo de aviso de origem: “A importação cria uma cópia no Vox. A foto original continua na Fototeca.”
- Exemplo de estado desatualizado: “Este backup não inclui tudo o que está no cofre.”
- Exemplo de exportação: “A exportação cria uma cópia fora do Vox.”

## 9. Acessibilidade e privacidade visual

- Dynamic Type em todos os fluxos, incluindo folhas, alertas próprios e textos de erro.
- VoiceOver: rótulos para ações, tamanho e estado de seleção; miniaturas anunciadas com o tipo de mídia e data, sem depender apenas do ícone.
- Foco não fica preso atrás de folhas. Ordem de leitura segue a ordem visual.
- Contraste AA nos dois temas; suportar Aumentar Contraste, Negrito, Reduzir Movimento, Formas dos Botões e Diferenciar sem Cor.
- Não usar texto embutido em imagens funcionais.
- Tap targets mínimos de 44 × 44 pt.
- Nas notificações do app, não mostrar nomes, miniaturas, quantidade de itens ou conteúdo pessoal.
- Na captura do seletor de apps, cobrir conteúdo privado sem atraso; testar ao alternar entre apps com VoiceOver e Dynamic Type.
- Não prometer bloqueio de captura de tela do iOS. A interface deve evitar exibir conteúdo sensível em superfícies do sistema que possa controlar.

## 10. Referências para implementação

- Seguir componentes e navegação nativos do iOS; usar abas para as três áreas de topo, com rótulos visíveis.
- Usar SF Symbols para funções de sistema e estilos preenchidos em estados selecionados.
- Usar SF Pro / fonte de sistema e Dynamic Type.
- Nome no App Store Connect limitado a 30 caracteres; confirmar nome disponível por localidade antes da submissão.
- HIG atual da Apple orienta ícones escaláveis e variantes de aparência; manter o símbolo simples e preparar camadas deriváveis para as aparências do iOS.

### Referências

- [Apple Human Interface Guidelines: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)
- [Apple Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple Human Interface Guidelines: Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Apple Human Interface Guidelines: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Apple Human Interface Guidelines: App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Apple: Creating your App Store product page](https://developer.apple.com/app-store/product-page/)
- [App VoxLoop: Fale Inglês e mais na App Store](https://apps.apple.com/pt/app/voxloop-fale-ingl%C3%AAs-e-mais/id6787014579)
- [Busca de marcas do INPI](https://servicos.busca.inpi.gov.br/marcas)

A busca de marca no INPI e a disponibilidade do nome na conta de desenvolvedor continuam pendentes.
