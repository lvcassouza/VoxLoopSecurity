# Roteiro de Auditoria, Testes Físicos e Gates de Lançamento (Fase 6)

**Produto:** Vox — Cofre Privado (iOS)
**Data:** 26 de outubro de 2026
**Rastreabilidade:** [docs/ai-development-brief.md](../ai-development-brief.md), [Issue #1](https://github.com/lvcassouza/VoxLoopSecurity/issues/1), [docs/discovery.md](../discovery.md), [docs/avaliacao-tecnica-fase-3.md](../avaliacao-tecnica-fase-3.md).

---

## 1. Visão Geral dos Gates Bloqueantes

Antes da submissão comercial para a App Store pública, os seguintes gates dependem de hardware físico ou de validação externa independente e **não podem ser substituídos por testes em simulador ou afirmações de IA**:

```
+------------------------------------------------------------------------------------------+
| GATES BLOQUEANTES ANTERIORES AO LANÇAMENTO COMERCIAL                                     |
|                                                                                          |
|  [Gate 1: Hardware Mínimo] ----> [Gate 2: Restauração Física] ----> [Gate 3: Auditoria]   |
|  Medição empírica Argon2id       Exportação e importação real       Revisão externa      |
|  (iPhone SE / XR / XS)           entre 2 iPhones distintos         OWASP MASVS v2.1     |
|              |                                 |                                 |       |
|              v                                 v                                 v       |
|  [Gate 4: Acessibilidade/UI] ------------------------------------> [Gate 5: Submissão]  |
|  VoiceOver + Dynamic Type                                           App Store Connect    |
|  + Snapshot App Switcher                                            + TestFlight Beta    |
+------------------------------------------------------------------------------------------+
```

---

## 2. Gate 1: Medição Empírica do Argon2id no Hardware Mínimo

- **Objetivo:** Garantir que o perfil `opslimit = 3` e `memlimit = 64 MiB` do Argon2id v1.3 não cause encerramento por falta de memória (*jetsam*) nem latência inaceitável no iPhone suportado mais antigo (iPhone XR, XS ou iPhone SE de 2ª geração com iOS 17+).
- **Procedimento no Xcode Instruments:**
  1. Conectar o dispositivo físico ao Mac via cabo USB.
  2. No Xcode, selecionar o esquema `Vox` com o dispositivo físico e abrir o **Instruments** (`Cmd + I`).
  3. Selecionar os perfis **Time Profiler** e **Allocations**.
  4. Executar o fluxo de criação do cofre e desbloqueio com a credencial principal.
  5. **Critérios de Aprovação:**
     - Pico de memória alocada pelo Argon2id deve permanecer estritamente contido no teto de ~64 MiB.
     - Tempo de desbloqueio em processador Apple A12/A13 Bionic deve ser inferior a 1,8 segundo.
     - Não deve haver ocorrência de aviso de memória do sistema operacional (`didReceiveMemoryWarning`).

---

## 3. Gate 2: Demonstração de Restauração entre Dois iPhones Físicos Distintos

- **Objetivo:** Comprovar a portabilidade e a integridade do pacote `.voxbackup` no ecossistema real do iOS, incluindo o comportamento do provedor de arquivos (`UIDocumentPicker` e `NSFileCoordinator`).
- **Procedimento com Dois Dispositivos (iPhone A e iPhone B):**
  1. **No iPhone A:**
     - Criar um cofre e importar 5 fotos e 2 vídeos gravados pela câmera do aparelho.
     - Acessar a aba "Backup", tocar em "Criar backup" e salvar o pacote `.voxbackup` no app Arquivos (ou em pendrive USB-C / iCloud Drive).
     - Conferir que o estado transita para **Atualizado**.
  2. **Transferência:**
     - Enviar o pacote `.voxbackup` para o iPhone B (via AirDrop, compartilhamento de arquivos ou armazenamento externo).
  3. **No iPhone B (sem cofre instalado):**
     - Abrir o Vox, tocar em "Restaurar de um backup".
     - Selecionar o arquivo `.voxbackup` transferido.
     - Fornecer o código de recuperação do backup gerado no iPhone A.
     - Definir uma credencial nova e confirmar o novo código de recuperação no iPhone B.
  4. **Critérios de Aprovação:**
     - Todos os itens (fotos e vídeos) devem abrir com reprodução de áudio/vídeo íntegra no iPhone B.
     - O pacote-fonte no destino de armazenamento permanece inalterado bit a bit.
     - O código antigo do iPhone A não deve conseguir abrir o cofre restaurado no iPhone B após a rotação.

---

## 4. Gate 3: Escopo para Auditoria Independente de Segurança (OWASP MASVS v2.1)

A contratação de uma consultoria ou profissional especializado em segurança móvel deve avaliar o aplicativo contra os requisitos do **OWASP Mobile Application Security Verification Standard**:

| Domínio MASVS | Itens Auditáveis no Vox |
|---|---|
| **MASVS-STORAGE** | Verificação de repouso no APFS: ausência de mídias em claro em `Library/Caches/`, `tmp/` ou snapshots; confirmação de que `vault.index` não vaza nomes originais; confirmação de integridade por blocos com rejeição imediata de arquivos adulterados. |
| **MASVS-CRYPTO** | Auditoria das primitivas: adequação do Argon2id v1.3 (`swift-sodium`), política de nonces do AES-256-GCM (prefixo de 32 bits + contador sequencial de 64 bits), isolamento de chaves (VK, MK, RK) e descarte de buffers de memória em `defer`. |
| **MASVS-AUTH** | Validação da política de bloqueio local, resiliência do código de recuperação de 128 bits contra enumeração e ausência de mecanismos de bypass. |
| **MASVS-PRIVACY** | Confirmação de ausência total de SDKs terceiros, validação de que logs do sistema (`SanitizedLogger`) não registram nomes de arquivos, credenciais ou códigos, e conformidade do `PrivacyInfo.xcprivacy`. |

---

## 5. Gate 4: Teste de Acessibilidade e Proteção Visual em Sistema Real

- **VoiceOver:** Navegar por todo o aplicativo com o VoiceOver ativado. Verificar se botões, miniaturas da grade, campos de senha com alternador de visibilidade e diálogos de confirmação possuem rótulos claros e anunciados corretamente em português.
- **Dynamic Type:** Ajustar o tamanho de texto do iOS no ajuste máximo de acessibilidade (*Tamanhos Maiores de Acessibilidade*). Confirmar que nenhum texto crítico de instrução, aviso de backup ou botão de ação é cortado ou sobreposto.
- **Seletor de Apps (Snapshot Privacy):** Abrir o cofre desbloqueado, arrastar a barra inicial para abrir o seletor de aplicativos multitarefa do iOS. Tirar uma captura de tela do seletor. **Critério:** a cortina opaca (`VoxPrivacyShieldView`) deve cobrir 100% da interface do Vox sem expor nenhum frame visível de foto ou vídeo.

---

## 6. Gate 5: Checklist de Submissão no App Store Connect

- [ ] **Conta Apple Developer:** Conta ativa e em dia na Apple Developer Enterprise ou Apple Developer Program sob a titularidade da Voxloop.
- [ ] **App ID e Bundle ID:** `com.voxloop.vox` registrado com capacidades padrão.
- [ ] **Ficha do Produto:** Preenchida com os textos de [ficha-app-store.md](ficha-app-store.md) (título, subtítulo, descrição, palavras-chave e URLs).
- [ ] **Classificação Indicativa:** Questionário respondido resultando na classificação 4+.
- [ ] **Conformidade de Exportação:** `ITSAppUsesNonExemptEncryption = NO` validado conforme [declaracao-exportacao-criptografia.md](declaracao-exportacao-criptografia.md).
- [ ] **Manifesto de Privacidade:** `PrivacyInfo.xcprivacy` incluído no bundle e validado pelo gerador de relatórios de privacidade do Xcode Organizer.
- [ ] **Build e Assinatura:** Arquivamento gerado com certificado de distribuição da Apple (`xcodebuild archive`) e enviado via Xcode Organizer / altool para o TestFlight.
- [ ] **TestFlight Beta Fechado:** Teste com grupo de usuários convidados em dispositivos reais antes da liberação na loja pública.
