# Descoberta do cofre privado

Estado: entrevista concluída, aguardando confirmação do entendimento compartilhado. Estas decisões orientam a descoberta; ainda não constituem uma especificação de segurança ou aprovação para publicação.

## Base de trabalho

O documento `inicio-projeto-cofre-seguro.md`, fornecido pelo proprietário do projeto em 23 de outubro de 2026, é uma proposta para discussão. Suas demais premissas continuam abertas até confirmação explícita.

## Síntese para confirmação

O primeiro produto é um cofre privado para fotos e vídeos pessoais no iPhone. A pessoa cria um único cofre, importa da Fototeca e usa o conteúdo sem rede. A importação não apaga a origem. O app explica as cópias externas que conhece, deve proteger conteúdo e metadados dos itens enquanto o cofre está fechado e volta a exigir autenticação ao ser retomado.

O primeiro lançamento público funciona sem conta obrigatória, anúncios, compras no app, sincronização, compartilhamento ou nuvem operada pelo projeto. A pessoa escolhe onde guardar um backup criptografado, pode verificá-lo e recebe um código de recuperação separado da credencial principal. O produto alerta sobre mudanças ainda não incluídas no backup e sobre backups guardados apenas no aparelho. A perda do aparelho sem backup pode causar perda dos itens; perder credencial e código pode tornar o cofre inacessível.

Antes do lançamento público, é necessário demonstrar restauração em outro aparelho e obter revisão independente de segurança. O primeiro marco continua sendo um protótipo interno sem nuvem e apenas com arquivos de teste.

## Pendências de engenharia e validação

- Definir e revisar o modelo de ameaças detalhado, o desenho de chaves, a proteção do código de recuperação, o formato versionado dos dados e do backup e a migração entre versões.
- Determinar o comportamento de arquivos temporários, miniaturas, índices e cópias do sistema operacional durante importação, visualização, exportação, backup e restauração.
- Especificar limites práticos de tamanho e espaço, comportamento em falhas e interrupções, e testes para vídeos grandes.
- Projetar a detecção de alterações posteriores ao último backup e a verificação de que um backup pode ser lido, sem prometer que verificá-lo garante restauração em qualquer circunstância.
- Validar textos de privacidade, termos de segurança e exigências das lojas perto da publicação.

## Decisões confirmadas — rodada 1

1. O documento inicial é o ponto de partida, não uma especificação aprovada.
2. O público inicial são pessoas que querem guardar arquivos pessoais sensíveis no celular, com foco em fotos e vídeos.
3. A primeira plataforma é iOS; Android fica para uma etapa posterior.
4. O primeiro marco é um protótipo interno, sem nuvem, usando apenas arquivos de teste e sem prazo de publicação definido nesta etapa.
5. No futuro produto público, perder a credencial sem ter configurado um meio de recuperação pode significar perder o acesso aos arquivos. Essa consequência deve ser explicada com clareza, e uma forma de recuperação testada deve existir antes da publicação.

## Decisões confirmadas — rodada 2

6. A promessa de sigilo prioriza o iPhone perdido e bloqueado e uma cópia dos dados do app. Um aparelho comprometido com o cofre aberto fica fora dessa promessa.
7. Importar uma foto ou vídeo cria uma cópia no cofre e informa que o original continua na Fototeca. O app não apaga o original automaticamente; eventual exclusão é uma ação separada e explícita.
8. Criar o cofre exige senha ou frase forte. A biometria pode facilitar o desbloqueio no mesmo aparelho, mas um padrão visual curto não é a única proteção da chave.
9. O primeiro lançamento público deve oferecer backup criptografado opcional, configurado pelo usuário e com restauração testada em outro aparelho. Backup automático não é requisito desse lançamento.

## Decisões confirmadas — rodada 3

10. O produto público funciona sem conta obrigatória, e o operador do app não pode ler os itens do cofre.
11. A pessoa escolhe onde guardar o backup criptografado, por exemplo via app Arquivos. O primeiro lançamento não depende de nuvem operada pelo projeto.
12. Um código de recuperação guardado pela pessoa permite definir uma nova credencial principal se ela a esquecer. Perder os dois pode impedir a recuperação do acesso. O mecanismo concreto ainda depende de revisão de segurança.
13. O diferencial principal é a clareza sobre as cópias que permanecem fora do cofre e a confiança na restauração de um backup.

## Decisões confirmadas — rodada 4

14. A importação do primeiro lançamento público abrange fotos e vídeos da Fototeca. Documentos e outros arquivos ficam para uma versão posterior.
15. O app informa as cópias externas que conhece pelo fluxo de importação, sem afirmar que localizou todas as cópias existentes em outros apps, serviços ou backups.
16. O primeiro lançamento público não terá sincronização entre aparelhos nem compartilhamento de cofres. A transferência para outro aparelho ocorre por backup e restauração.
17. Ao sair do app ou bloqueá-lo, o conteúdo é ocultado na visualização de apps recentes e o retorno exige novo desbloqueio.
18. O app permite verificar que um backup criado pode ser lido, sem substituir os itens do cofre durante a verificação. A restauração em outro aparelho também deve ser testada antes da publicação.

## Decisões confirmadas — rodada 5

19. O app mostra quando foi feito o último backup e avisa quando há mudanças no cofre ainda não incluídas nele.
20. Exportar um item cria uma cópia fora do cofre; o app explica que ela fica sujeita às regras do destino escolhido.
21. Trocar a credencial principal ou o código de recuperação não revoga backups antigos já distribuídos. O app explica essa limitação e orienta a criar um novo backup e eliminar os antigos nos locais escolhidos pela pessoa.
22. Apagar um item do cofre não apaga o arquivo de origem, exportações nem cópias em backups anteriores; o app deixa isso claro.
23. O primeiro lançamento público é gratuito, sem anúncios e sem compras no app. Planos pagos ficam para decisão posterior.

## Decisões confirmadas — rodada 6

24. Com o cofre fechado, nomes, miniaturas, datas e outros metadados dos itens do cofre recebem a mesma prioridade de proteção que seu conteúdo.
25. No primeiro lançamento, o app orienta a pessoa a revisar e apagar por conta própria o arquivo de origem na Fototeca; não oferece exclusão da origem dentro do cofre.
26. O app explica que o código de recuperação não recria arquivos perdidos: após perda do aparelho, só podem ser restaurados os itens presentes em um backup disponível.
27. Se a pessoa perder a credencial principal e o código de recuperação, pode apagar o cofre inacessível e criar outro vazio, após confirmação clara de que os itens antigos não serão recuperados.
28. O protótipo interno usa arquivos de teste e demonstra importação, fechamento e reabertura com autenticação, detecção de dados alterados e comportamento definido para importação interrompida ou falta de espaço.
29. A primeira versão foca iPhone; uma experiência específica para iPad fica para depois.
30. O primeiro lançamento dispensa analytics de terceiros. Logs e relatórios de falha não podem conter itens, nomes sensíveis, credenciais ou códigos de recuperação.

## Decisões confirmadas — rodada 7

31. A primeira versão oferece um cofre por instalação, sem perfis ou cofres de várias pessoas no mesmo iPhone.
32. Depois de criado, o cofre permite importar, abrir e organizar itens sem conexão com a internet.
33. Se a biometria falhar, for desativada ou ficar indisponível, a credencial principal continua sendo um meio de desbloqueio.
34. O app avisa que um backup salvo apenas no próprio iPhone pode não permitir restauração após perda do aparelho.
35. Captura direta de foto e vídeo pela câmera dentro do app fica fora do primeiro lançamento; a importação é pela Fototeca.
36. Antes da publicação, o desenho e a implementação de segurança passam por revisão independente, além dos testes de restauração e falhas.
