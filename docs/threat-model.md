# Modelo de Ameaças — Vox (Threat Model)

**Versão:** 1.0
**Data:** 26 de outubro de 2026
**Status:** Revisado para a implementação experimental da Fase 3; controles ainda não foram auditados nem validados em iPhone físico.
**Referências normativas:** [CONTEXT.md](../CONTEXT.md), [docs/discovery.md](discovery.md), [docs/ai-development-brief.md](ai-development-brief.md), OWASP MASVS v2.1 (Storage, Crypto, Auth).

> [!WARNING]
> O protótipo da Fase 3 agora cifra cópias importadas, metadados e envelopes de chave no armazenamento local. O seletor aceita arquivos pessoais e não os distingue; use somente arquivos sintéticos e uma credencial exclusiva de teste. A implementação e o modelo não foram auditados; isto não comprova segurança ou prontidão para produção. Restauração em iPhone físico e auditoria independente continuam obrigatórias antes de qualquer lançamento público.

---

## 1. Visão Geral e Limites de Confiança

O **Vox** pretende ser um cofre privado para fotos e vídeos pessoais no iPhone. A arquitetura proposta é local e offline após a configuração inicial, sem backend, sem conta obrigatória e sem tráfego de rede para armazenamento ou sincronização de mídia.

### 1.1 Fronteiras do protótipo (parciais)

```
+-----------------------------------------------------------------------------------+
| APARELHO (iPhone)                                                                 |
|                                                                                   |
|  [Fototeca do iOS] ----(Importação / Cópia)----> [Contêiner Sandbox do Vox]        |
|  (Arquivo de origem permanece)                     |                              |
|                                                   v                              |
|  [Interface / Memória Transitória] <====> [Mecanismo de Acesso / State Machine]   |
|  (Ocultada em background)                         |                              |
|                                                   v                              |
|  [Keychain biométrica (fase futura)]      [Cofre Criptografado em Repouso]       |
|  (não implementada nesta versão)          (Metadados + Chunks de Mídia cifrados)  |
|                                                   |                              |
|                                                   v                              |
|  [Exportação / Backup Arquivos] <-----------------+                              |
|  (Arquivo cifrado sob controle da pessoa)                                         |
+-----------------------------------------------------------------------------------+
```

### 1.2 Limite Explícito de Segurança (Non-Goals & Assumptions)

> [!IMPORTANT]
> **Limite fundamental:** Um aparelho desbloqueado em mãos de um invasor ou com o cofre atualmente aberto, assim como um aparelho sob jailbreak / comprometimento de kernel (spyware com privilégios de root/sandbox escape), **está fora da promessa de sigilo**. Se o dispositivo estiver ativamente violado em tempo de execução, a memória do processo pode ser lida.
>
> Este modelo considera como objetivos prioritários:
> 1. iPhone perdido ou apreendido, bloqueado por código do sistema.
> 2. Cópia não autorizada do contêiner do aplicativo extraída via backup não criptografado, extração forense em repouso ou dump de armazenamento, onde o adversário tem tempo ilimitado para ataques offline.
> 3. Observadores casuais ou ataques visuais (shoulder surfing, visualizador de multitarefa / app switcher do iOS).

---

## 2. Inventário de Ativos (Assets)

| Ativo | Classificação | Requisito de Segurança | Descrição |
|---|---|---|---|
| **Itens do cofre (mídia)** | Crítico | Confidencialidade + Integridade | Fotos e vídeos pessoais cifrados em repouso. Gravação parcial nunca deve ser tratada como válida. |
| **Metadados dos itens** | Crítico | Confidencialidade + Integridade | Nomes, dimensões, durações, datas e tamanhos. Com o cofre fechado, metadados têm a mesma proteção dos arquivos. |
| **Miniaturas (thumbnails)** | Crítico | Confidencialidade + Integridade | Caches de renderização. Devem ser cifrados ou gerados dinamicamente em memória e expurgados ao fechar o cofre. |
| **Credencial principal** | Crítico | Confidencialidade | Senha ou frase longa secreta definida pelo usuário. Nunca armazenada em texto plano. |
| **Código de recuperação** | Crítico | Confidencialidade + Integridade | Segredo aleatório de 128 bits em 32 dígitos hexadecimais agrupados, usado para redefinir credencial local. |
| **Chaves criptográficas** | Crítico | Confidencialidade + Integridade | Chave de cifra do cofre (VK), chave derivada da credencial (MK) e chave derivada do código (RK). Chave biométrica ainda não existe no protótipo. |
| **Arquivos temporários** | Alto | Confidencialidade + Destruição | Dados transitórios de importação/exportação. A cópia temporária deve residir em diretório protegido e ser removida após conclusão/cancelamento. `FileManager.removeItem` não comprova sobrescrita nem apagamento físico recuperável em armazenamento flash; não prometer destruição irrecuperável. |
| **Backup do cofre** | Crítico | Confidencialidade + Integridade + Autonomia | Envelope autocontido e cifrado, gravável onde a pessoa desejar via seletor nativo do iOS. |
| **Logs de diagnóstico** | Baixo | Higienização estrita | Registros de erros do sistema. Proibido conter qualquer caminho, nome, credencial, código ou miniatura. |

---

## 3. Atores e Capacidades do Adversário

### Adversário A — Ladrão oportunista / Achador de iPhone bloqueado
- **Cenário:** O iPhone foi perdido ou furtado enquanto bloqueado. O atacante não possui a senha do iOS nem a credencial principal do Vox.
- **Capacidades:** Acesso físico ao dispositivo bloqueado. Pode tentar desbloquear o aparelho, forçar reinício (estado BFU - Before First Unlock) ou conectar a cabos USB.
- **Controles implementados, ainda não validados em aparelho físico:** proteção de arquivo `complete` no iOS, bloqueio ao sair do app e cortina visual ao entrar em segundo plano. O armazenamento zera best-effort o buffer local da VK ao bloquear. Swift/CryptoKit não garantem que todas as cópias temporárias em memória foram apagadas; não prometer limpeza determinística.

### Adversário B — Analista forense / Cópia offline do contêiner
- **Cenário:** O contêiner de dados do Vox foi extraído (ex.: computador com backup local do iOS sem senha, extração física por ferramenta forense tipo Cellebrite/GrayKey). O adversário possui o contêiner bruto em seu laboratório.
- **Capacidades:** Tempo computacional ilimitado, GPUs em cluster, capacidade de alterar bytes no armazenamento, desmontar o binário e inspecionar estruturas de dados.
- **Controles implementados experimentalmente:** Argon2id via libsodium (3 operações, 64 MiB), envelopes independentes de credencial e recuperação, AES-256-GCM, conteúdo em blocos, índice cifrado e proteção de metadados. A versão da dependência está fixada no SwiftPM. Nenhum deles passou por auditoria independente ou validação forense.
- **Risco residual:** nenhuma KDF impede tentativas offline ilimitadas contra uma credencial fraca. O perfil Argon2id é experimental e precisa ser medido no aparelho mínimo suportado; a resistência continua dependendo da força da credencial e do custo do perfil.

### Adversário C — Espião de tela (Shoulder Surfer / Multitarefa)
- **Cenário:** Observador ao lado da pessoa ou visualizador de miniaturas do sistema quando o app transiciona para segundo plano.
- **Controles implementados parcialmente:** a tela é ocultada ao entrar em segundo plano e o cofre é bloqueado; a experiência ainda precisa ser validada com snapshots e alternância de apps em iPhone físico. Não há notificações com conteúdo privado.

---

## 4. Hierarquia e Ciclo de Vida de Chaves

```
+----------------------------------------------------------------------------------------+
| HIERARQUIA DE CHAVES DO VOX                                                            |
|                                                                                        |
|   [Credencial Principal]                  [Código de Recuperação]                      |
|            | (Argon2id / KDF)                       | (HKDF / Argon2id)                |
|            v                                        v                                  |
|   Master Key (MK, 256-bit)                Recovery Key (RK, 256-bit)                   |
|            |                                        |                                  |
|            +---------------\       /----------------+                                  |
|                             v     v                                                    |
|                 [Encrypted Vault Key Envelopes]                                        |
|                 (Slot 1: MK-wrapped | Slot 2: RK-wrapped)                             |
|                                    |                                                   |
|                        (Desembrulha após auth)                                         |
|                                    v                                                   |
|                    Vault Encryption Key (VEK / VK)                                     |
|                               (256-bit)                                                |
|                                    |                                                   |
|                +-------------------+-------------------+                               |
|                |                                       |                               |
|                v                                       v                               |
|   [Metadados Cifrados]                    [Itens de Mídia Cifrados]                    |
|   AES-256-GCM (Índice do Cofre)           AES-256-GCM em Chunks com AAD e Nonce Único |
+----------------------------------------------------------------------------------------+
```

1. **Vault Encryption Key (VK):** chave aleatória de 256 bits gerada pelo CSPRNG do sistema. Nunca é gravada em texto claro.
2. **Master Key (MK):** Argon2id v1.3 via libsodium, com salt aleatório de 16 bytes, 3 operações e 64 MiB no perfil experimental. MK é usada apenas para embrulhar/desembrulhar VK com AES-256-GCM.
3. **Recovery Key (RK):** HKDF-SHA256 sobre o código aleatório de 128 bits, salt aleatório e contexto `vox-recovery-v1`. RK embrulha a mesma VK no slot de recuperação.
4. **Biometria:** não implementada. O desenho futuro está no ADR 0004; não se oferece Face ID nesta versão.
5. **Ciclo de vida em memória:** o store zera best-effort o buffer próprio de VK ao bloquear e a UI remove metadados. Swift/CryptoKit não provam apagamento de cópias temporárias em memória; não alegar limpeza determinística.

---

## 5. Formato em Repouso, Metadados e Integridade

1. **Estrutura de Diretórios no Sandbox:**
   ```
   <App_Sandbox>/Library/Application Support/Vox/
   ├── vault.header          # Salt, parâmetros KDF, envelopes cifrados da VK (Slot MK, Slot RK)
   ├── vault.index           # Banco de metadados cifrado com VK (AES-256-GCM)
   ├── staging/              # Arquivos temporários durante importação (isolados)
   └── items/                # Chunks/arquivos cifrados (nomeados como <UUID>.enc)
   ```
2. **Formato experimental:** cabeçalho e índice são JSON versionados. Catálogo e journal usam AES-GCM. Cada item tem DEK aleatória de 256 bits; blocos de até 1 MiB usam nonce de 96 bits composto por prefixo aleatório de 32 bits e contador de 64 bits sob aquela DEK. AAD inclui versão, UUID, contador e comprimento. O índice autenticado registra tamanho e quantidade de blocos esperados. Nonces aleatórios de índice têm risco de colisão baixo, não zero.
3. **Integridade implementada e testada em fixtures:** cada tag é validada após escrita e todos os arquivos são validados ao desbloquear, antes de apresentar metadados. Os testes de adulteração são automatizados no macOS; falta validação física.

---

## 6. Transacionalidade e Resiliência a Falhas

1. **Journal recuperável de um item por vez:** o item cifrado é gravado em `staging/<UUID>.stage`, verificado bloco a bloco, e um journal autenticado é gravado antes do movimento para `items/<UUID>.enc`. O catálogo cifrado é então substituído atomicamente. No desbloqueio seguinte, um journal válido termina o commit se staging/final autenticar; se o índice já contiver o item, remove o journal. Órfãos não entram no catálogo.
2. **Interrupção e Falta de Espaço:**
   - Testes automatizados injetam falha depois da verificação, do journal, do movimento e da gravação do índice. Encerramento forçado real e baixa de espaço em iPhone ainda não foram testados.
   - Há uma estimativa antecipada de espaço, mas ela não garante disponibilidade até o fim. Antes do journal, falhas removem staging; depois, o journal mantém os arquivos para reconciliação. Itens incompletos não aparecem na interface.

**Limite:** mover arquivo e atualizar catálogo não é transação física única. O journal dá recuperação lógica; durabilidade ainda precisa ser validada em iPhone.

---

## 7. Formato e Autonomia do Backup

1. **Envelope de Backup (`.voxbackup`) ainda pendente:** definir formato versionado, derivação/entrega da chave e autenticação do conteúdo. O termo “assinado” deve ser removido a menos que exista uma assinatura digital com chave e finalidade definidas; criptografia autenticada e assinatura são propriedades distintas.
   - O formato futuro deve conter os itens e metadados necessários para uma restauração offline, sem expor nomes ou conteúdo.
2. **Verificação Segura:**
   - A ação de verificar backup abre o arquivo em modo somente-leitura em sandbox temporário, valida a autenticidade do cabeçalho, decifra os hashes dos itens e confirma a integridade sem alterar o cofre em execução no aparelho.
3. **Restauração em Aparelho Limpo:**
   - A restauração exige que o cofre de destino esteja não-configurado ou vazio.
   - Não há merge silencioso: restaurar substitui o estado inicial por aquele contido no backup.

---

## 8. Conformidade com Decisões de Produto

| Decisão | Mitigação no Threat Model |
|---|---|
| Decisão 6: iPhone perdido e bloqueado | Data Protection `complete` + KDF robusto + envelope cifrado sem chave em disco. |
| Decisão 7/25: Preservação da Fototeca | Importação cria cópia no cofre; app nunca altera ou apaga fotos da Fototeca. |
| Decisão 17: Ocultar em segundo plano | Scene phase listener bloqueia o cofre e substitui UI por tela neutra. |
| Decisão 20/22: Clareza sobre cópias | Avisos explícitos na UI ao exportar ou apagar; operações não afetam cópias externas. |
| Decisão 24: Metadados protegidos | Nomes, datas, tipo e duração ficam no índice cifrado. Contagem, tamanhos aproximados, quantidade de blocos e padrões de atividade vazam pelo sistema de arquivos. |
| Decisão 30: Sem analytics / logs limpos | Nenhum SDK de analytics; logs do sistema filtrados por sanitizador estrito. |
