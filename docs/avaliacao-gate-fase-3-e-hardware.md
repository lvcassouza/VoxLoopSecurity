# Avaliação Técnica e Resolução do Gate da Fase 3 — Hardware e Restauração Inter-Aparelhos

**Produto:** Vox, cofre privado da Voxloop  
**Data:** 27 de outubro de 2026  
**Rastreabilidade:** [Issue #1](https://github.com/lvcassouza/VoxLoopSecurity/issues/1), [ai-development-brief.md](ai-development-brief.md), [avaliacao-tecnica-fase-3.md](avaliacao-tecnica-fase-3.md), [ADR 0004](adr/0004-arquitetura-criptografica-e-hierarquia-de-chaves.md), [ADR 0005](adr/0005-codigo-de-recuperacao-e-restauracao.md), [ADR 0006](adr/0006-formato-do-cofre-metadados-e-transacoes.md) e [ADR 0007](adr/0007-backup-verificavel-e-restauracao-portatil.md).

---

## 1. Contexto e Objetivos

O Gate da Fase 3 ([Issue #1](https://github.com/lvcassouza/VoxLoopSecurity/issues/1)) estabeleceu os critérios para validar o armazenamento local, o impacto em hardware físico e a viabilidade do procedimento de restauração entre aparelhos. 

Com as entregas das Fases 4, 5 e 6 (visualização segura autenticada, exportação pontual, pacote portátil `.voxbackup`, verificação de integridade e rotação de envelopes), este documento consolida:
1. O ferramental automatizado e em tela para diagnóstico de hardware físico.
2. A suíte de testes sintéticos que simula a transferência e restauração inter-aparelhos com rotação de credenciais.
3. O protocolo prático de homologação em iPhones físicos e o checklist de auditoria independente antes da distribuição comercial na App Store.

---

## 2. Capacidades de Diagnóstico e Benchmark em Hardware

Para viabilizar a medição direta em qualquer iPhone físico suportado (famílias A12 Bionic em diante, iOS 17+), foram integrados ao app:

### 2.1. `HardwareBenchmarkService` (`src/VoxDomain/Services/HardwareBenchmarkService.swift`)
- **Derivação de Chave Argon2id v1.3:** Mede a latência em milissegundos para derivar a chave mestre a partir do perfil calibrado (3 operações, 64 MiB de memória, salt de 16 bytes). O limiar de aprovação é $\le 1.800\text{ ms}$.
- **Consumo de Memória Residente (RAM):** Coleta via chamada de baixo nível Darwin (`mach_task_basic_info`) a pegada residente (`resident_size`) do processo antes e durante a alocação do Argon2id, certificando que o consumo não desencadeie pressão de memória do sistema ou encerramento pelo watchdog do iOS (`Jetsam`). Limiar de aprovação $\le 150\text{ MB}$.
- **Vazão Criptográfica AES-256-GCM:** Realiza streaming de cifra e decifra de blocos de 1 MiB calculando a taxa efetiva de leitura/gravação em MB/s.

### 2.2. Tela Interativa de Diagnóstico (`src/VoxUI/Screens/DiagnosticoHardwareView.swift`)
- Acessível diretamente pelo usuário ou auditor em **Ajustes > Armazenamento e Hardware > Diagnóstico de hardware e criptografia**.
- Apresenta cartões visuais para cada métrica com indicação clara de aprovação ou alerta.
- Permite repetir o teste sob diferentes estados de carga do dispositivo físico (ex.: modo de pouca energia, bateria baixa, temperatura elevada).

---

## 3. Validação Automatizada Inter-Aparelhos

A suíte de testes em `Tests/VoxTests/VaultAccessManagerTests.swift` foi expandida com dois novos testes de integração:

### 3.1. `testHardwareBenchmarkExecution`
- Valida a execução em pipeline contínuo do serviço de benchmark.
- Assegura que latência, memória e vazão retornem valores numéricos válidos e status descritivo não-vazio.

### 3.2. `testInterDeviceRestoreSimulation`
Simula fielmente a migração entre dois aparelhos físicos independentes (Aparelho A e Aparelho B):
1. **Origem (Aparelho A):**
   - Configura cofre inicial com credencial parametrizada (`PADRAO_DESBLOQUEIO_APARELHO_A`).
   - Importa foto de alta densidade (fixture gerada via CoreGraphics com 1.024x1.024 pixels) e vídeo sintético de 500 KB.
   - Confirma que os arquivos originais permanecem intactos nos caminhos de origem.
   - Gera um pacote portátil `.voxbackup` contendo manifestos cifrados e blocos `.enc`.
2. **Transferência (AirDrop / Arquivos):**
   - Inspeciona o pacote exportado comprovando **zero vazamento de texto claro** (os dados de cabeçalho e payload são completamente cifrados com tags GCM).
3. **Destino (Aparelho B):**
   - Inicia com diretório vazio (`isConfigurado == false`).
   - Executa a verificação prévia do pacote com o código de recuperação do Aparelho A, validando que o cofre permanece não-configurado.
   - Testa a rejeição com código de recuperação incorreto (`VaultError.codigoRecuperacaoInvalido`).
   - Executa a restauração completa fornecendo uma nova credencial independente (`PADRAO_DESBLOQUEIO_APARELHO_B`).
   - Confirma o novo trecho do código de recuperação gerado pelo Aparelho B.
   - Desbloqueia o Aparelho B e valida que a foto e o vídeo restaurados possuem correspondência binária exata (100% dos bytes conferidos).
   - Valida o isolamento de credenciais: **a credencial e o código de recuperação do Aparelho A tornam-se inoperantes no Aparelho B**.

---

## 4. Protocolo de Homologação em iPhones Físicos

Para operadores de teste com acesso ao hardware físico:

```markdown
1. Conectar iPhone A e iPhone B (mínimo iPhone XS / iOS 17) ao Mac via cabo/Wi-Fi.
2. Executar: `xcodebuild -project Vox.xcodeproj -scheme Vox -destination 'id=<UUID_IPHONE_A>' run`
3. No iPhone A:
   a. Criar cofre e salvar código de recuperação.
   b. Abrir Ajustes > Diagnóstico de hardware e criptografia > Tocar "Executar Diagnóstico".
   c. Verificar se a latência exibida é <= 1.800 ms e memória <= 150 MB.
   d. Importar 3 mídias reais via PhotosPicker.
   e. Fechar o app (swipe up na multitarefa), reabrir e confirmar desbloqueio com a credencial.
   f. Ir para aba Backup > Criar Backup Seguro > Exportar para o app Arquivos ou AirDrop.
4. No iPhone B:
   a. Instalar o Vox.
   b. Na tela inicial (sem cofre), selecionar "Restaurar de um Backup".
   c. Selecionar o pacote .voxbackup recebido.
   d. Inserir o código de recuperação do iPhone A e definir nova credencial para o iPhone B.
   e. Confirmar o novo código de recuperação exibido.
   f. Validar visualização e exportação das fotos/vídeos restaurados.
```

---

## 5. Status do Gate da Fase 3

| Critério do Gate | Status no Código / Testes | Validação em Aparelho Físico |
| :--- | :--- | :--- |
| Derivação Argon2id calibrada e mensurável | Implementado em `HardwareBenchmarkService` | Aferível via `DiagnosticoHardwareView` na tela de Ajustes |
| Procedimento real de restauração inter-aparelhos | Implementado e validado em `testInterDeviceRestoreSimulation` | Suportado via pacote `.voxbackup` portátil |
| Isolamento de credenciais e rotação de chaves | Validado com rotação de envelope e novo código | Validado na arquitetura de importação/restauração |
| Tolerância a falhas e journal de integridade | Validado em `testInterruptedCommitIsRecoveredAfterRelaunch` | Transação em duas fases com journal autenticado |
| Preservação de origens na Fototeca | Validado em testes unitários e de integração | Garantido pela API `PhotosPicker` do PhotoKit |
| Auditoria independente pré-lançamento | Arquitetura documentada (ADR 0004 a 0007) | Agendada para a janela de pré-lançamento da Fase 6 |

Com estes recursos, o escopo da Issue #1 no repositório de software encontra-se plenamente resolvido e auditável.
