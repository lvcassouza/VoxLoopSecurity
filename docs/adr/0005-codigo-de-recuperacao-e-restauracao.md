# Código de recuperação e restauração

Estado: aprovado pelo proprietário em 26 de outubro de 2026 para implementação experimental da Fase 3. Restauração entre aparelhos continua pendente.

## Contexto

A pessoa precisa recuperar o acesso quando esquece a credencial principal, sem supor que o código recrie arquivos perdidos. Não existe servidor Voxloop que guarde uma cópia das chaves.

## Decisão

1. Gerar 16 bytes com CSPRNG do sistema; codificar em hexadecimal maiúsculo com separadores apenas visuais (`8-8-8-8`). O código possui 128 bits de entropia. Não persistir em texto claro.
2. Derivar uma RK de 32 bytes com HKDF-SHA256, salt aleatório guardado no cabeçalho e contexto de domínio `vox-recovery-v1`. RK abre somente o envelope da VK no slot de recuperação.
3. Após exibir o código, exigir que a pessoa redigite o último grupo de oito caracteres. Só então gravar o cabeçalho e concluir a configuração. A UI deve orientar guardar o código fora do aparelho e nunca reutilizar senha pessoal durante este protótipo.
4. A recuperação local desembrulha VK com RK e substitui o envelope da credencial; não altera os arquivos. Uma futura restauração em aparelho novo exige um backup válido e o meio de recuperação/credencial associado àquele backup.
5. Restaurar apenas em instalação sem cofre configurado. Não mesclar nem sobrescrever. Preservar o arquivo de backup de origem.
6. Perder credencial e código torna o cofre inacessível. Apagar e começar de novo deve ser uma ação destrutiva separada, confirmada com clareza.

## Consequências e limites

- 128 bits tornam o código adequado como segredo aleatório, mas ainda pode ser fotografado ou copiado por quem vê a tela; ocultá-lo após confirmação.
- O código não recria mídia sem backup. Backups antigos permanecem independentes da troca de credencial ou código.
- O formato, os textos e os fluxos precisam de teste de recuperação e revisão independente antes do beta público.
