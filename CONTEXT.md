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
Senha ou padrão de pontos definido pela pessoa para criar e desbloquear seu cofre.
_Evitar_: login, conta, biometria obrigatória

**Armazenamento soberano 100% local**:
Todo o conteúdo e as chaves residem estritamente no sandbox deste aparelho. Não há servidores, telemetria, nuvem ou login. Não existe backup em nuvem nem suporte remoto para recuperar arquivos: esqueceu a credencial, o acesso é irrecuperável ("perdeu, perdeu").
_Evitar_: nuvem, sync, backup remoto, conta Voxloop.
