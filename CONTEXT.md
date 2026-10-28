# Cofre privado de arquivos

Vocabulário do único contexto de domínio do projeto. Decisões de produto e pendências de validação estão em [docs/discovery.md](docs/discovery.md).

## Linguagem

**Vox**:
Nome curto do aplicativo de cofre privado.

**Voxloop**:
Marca do site e identidade responsável pelo aplicativo Vox.

**Cofre**:
Coleção privada de itens que a pessoa escolheu guardar no aplicativo. O aplicativo suporta múltiplos cofres locais independentes, cada um com sua própria credencial e isolamento criptográfico estrito.
_Evitar_: pasta, conta, perfil na nuvem.

**Arquivo de origem**:
Foto, vídeo ou arquivo selecionado para importação, que continua no local de onde foi escolhido após a importação.
_Evitar_: original protegido

**Item do cofre**:
Cópia de um arquivo de origem incorporada ao cofre, independente do arquivo de origem.
_Evitar_: original

**Credencial principal**:
Senha ou frase definida pela pessoa para criar e desbloquear seu cofre.
_Evitar_: padrão visual, biometria

**Código de recuperação**:
Segredo separado da credencial principal, guardado pela pessoa para recuperar o acesso quando esquecer essa credencial.

**Backup do cofre**:
Cópia dos itens do cofre destinada à restauração em outro aparelho.
_Evitar_: sincronização

**Verificação de backup**:
Conferência de que um backup pode ser lido sem substituir os itens do cofre atual.
_Evitar_: restauração

**Restauração**:
Criação de um cofre a partir dos itens presentes em um backup disponível.
_Evitar_: recuperação de arquivos sem backup
