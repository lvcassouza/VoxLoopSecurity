# Arquitetura criptográfica e hierarquia de chaves

Estado: aprovado pelo proprietário em 26 de outubro de 2026 para implementação experimental da Fase 3. A aprovação não é auditoria nem gate de lançamento.

## Contexto

O Vox precisa cifrar conteúdo e metadados locais. Um adversário com uma cópia do contêiner pode tentar credenciais offline; um aparelho comprometido enquanto o cofre está aberto fica fora do limite de proteção. A biometria é uma conveniência local e não substitui a credencial nem o código de recuperação.

## Decisão

1. **Chave de Cifra do Cofre (VK):** gerar 32 bytes com o gerador criptográfico do sistema. Nunca gravar VK em claro. A VK cifra o índice e embrulha uma chave de dados aleatória por item.

2. **Envelope da credencial (MK):** derivar 32 bytes por Argon2id v1.3 (`crypto_pwhash_ALG_ARGON2ID13`) usando libsodium. O perfil experimental inicial é `opslimit=3`, `memlimit=64 MiB`, salt aleatório de 16 bytes. Persistir algoritmo, versão e parâmetros no cabeçalho. Medir em todos os aparelhos mínimos suportados antes de beta; se faltar memória, falhar fechado. Não usar PBKDF2 como fallback silencioso. Mudança de parâmetros exige migração versionada.

3. **Envelope de recuperação (RK):** o código de recuperação contém 128 bits aleatórios codificados em 32 dígitos hexadecimais, apresentados em quatro grupos de oito. Derivar RK com HKDF-SHA256, salt aleatório de 16 bytes e contexto `vox-recovery-v1`. O código só abre o envelope da VK e permite trocar a credencial; não recupera arquivo ausente.

4. **Cifra autenticada:** usar apenas `CryptoKit.AES.GCM`, chave de 256 bits e tag de 128 bits. Para cada arquivo, gerar uma DEK de 32 bytes e embrulhá-la com VK em um envelope GCM. Para conteúdo em blocos, usar nonce de 96 bits formado por prefixo aleatório de 32 bits por arquivo e contador crescente de 64 bits sob aquela DEK; não reiniciar o contador durante uma escrita. Os blocos autenticam por AAD a versão, UUID e contador. O índice registra tamanho e quantidade esperada de blocos para detectar truncamento/reordenação.

5. **Biometria:** não faz parte da Fase 3. Quando implementada, o envelope local deverá usar Keychain `WhenPasscodeSetThisDeviceOnly` e `biometryCurrentSet`, com credencial principal como alternativa. Biometria não exportável não pode ser o único meio de recuperação.

6. **Troca de credencial/código:** desembrulhar VK com o meio atual e substituir apenas o envelope correspondente, em arquivo temporário e renomeação atômica. Dados e backups anteriores continuam cifrados com as chaves neles contidas.

## Consequências e limites

- A rotação de envelope evita recifrar vídeos grandes.
- A força contra ataque offline continua dependendo da qualidade da credencial e dos parâmetros medidos no aparelho mínimo.
- Nonces aleatórios do índice têm risco de colisão muito baixo, não matematicamente zero; cada item usa DEK independente e contador monotônico.
- Esta decisão é uma base experimental. Exige revisão independente, testes de migração e validação de restauração física antes de qualquer promessa ou lançamento público.
