# Múltiplos cofres locais e independentes (Multi-Cofre)

Estado: aprovado pelo proprietário em 28 de outubro de 2026.

## Contexto

A pessoa usuária pode desejar separar conteúdos com diferentes propósitos ou sensibilidades (por exemplo, "Pessoal", "Trabalho", "Projetos"), cada um protegido por sua própria senha ou padrão de desenho exclusivo.
O produto deve operar com privacidade total: 100% local no iPhone, sem sincronização em nuvem, sem contas e sem qualquer visibilidade do que é armazenado pela Voxloop.

## Decisão

1. **Isolamento Criptográfico Completo por Cofre:**
   Cada cofre é armazenado em um diretório isolado (`vox-vaults/<UUID>/`), com seu próprio cabeçalho (`vault.header`), seus próprios sais Argon2id independentes, seu próprio envelope de chave mestre (VK), seu próprio catálogo cifrado (`vault.index`) e sua própria pasta de itens criptografados (`items/`).
   A senha de um cofre não consegue derivar ou acessar nenhum dado de outro cofre.

2. **Zero Nuvem e Armazenamento Local Estrito:**
   Todos os cofres, chaves, miniaturas e dados transitórios residem exclusivamente no contêiner local do aplicativo no aparelho. O aplicativo não possui conexões com servidores externos, telemetria de mídia ou provedores de armazenamento em nuvem. A Voxloop não mantém nem acessa nenhum dado de usuário.

3. **Registro Local de Cofres:**
   Um manifesto local (`vaults-manifest.json`) mantém apenas metadados públicos necessários para a interface apresentar os cofres disponíveis no aparelho:
   - Identificador único (`UUID`);
   - Nome visível definido pelo usuário (ex: "Pessoal", "Trabalho");
   - Tipo de credencial configurada (`.texto` ou `.padrao`);
   - Datas de criação e de último acesso;
   - Estado de backup individual.
   Nenhum segredo, chave ou metadado de mídia reside no manifesto.

4. **Ciclo de Vida e Segurança em Memória:**
   Apenas um cofre pode estar desbloqueado em memória de cada vez. Ao alternar de cofre, bloquear o aparelho ou enviar o aplicativo para segundo plano, a chave em memória (VK) é imediatamente sobrescrita (`resetBytes`), o índice é limpo da memória e a cortina de privacidade é ativada.

5. **Backups e Recuperação Individuais:**
   Cada cofre possui seu próprio código de recuperação independente gerado no momento da sua configuração. A exportação e a restauração de pacotes `.voxbackup` operam por cofre, permitindo restaurar um backup como um novo cofre independente na lista.

6. **Migração Transparente:**
   Instalações que possuam um cofre anterior no caminho legada (`vox-vault/`) são automaticamente migradas para a nova estrutura de múltiplos cofres sob o nome "Cofre Principal", preservando todos os itens, envelopes e códigos intactos.

## Consequências

- O usuário pode criar quantos cofres desejar, cada um com sua própria credencial (senha alfanumérica ou padrão na grade 3x3).
- O comprometimento da senha de um cofre específico não compromete os demais cofres locais do dispositivo.
- A exclusão de um cofre afeta estritamente o cofre selecionado, mantendo os outros íntegros.
