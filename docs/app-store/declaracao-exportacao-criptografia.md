# Declaração de Conformidade de Exportação de Criptografia — Vox

**Data:** 26 de outubro de 2026
**Produto:** Vox — Cofre Privado (iOS)
**Entidade:** Voxloop
**Classificação ECCN:** 5D992.c (Software com criptografia para mercado de massa / *Mass Market*)
**Status no App Store Connect:** Isento (*Exempt under Note 4 to Category 5, Part 2*)

---

## 1. Visão Geral e Justificativa Regulatória

O aplicativo **Vox** implementa primitivas criptográficas padrão para proteger fotos, vídeos e metadados pessoais armazenados localmente no dispositivo iOS do usuário.

De acordo com as **Export Administration Regulations (EAR)** dos Estados Unidos, administradas pelo Bureau of Industry and Security (BIS), e as diretrizes de conformidade de exportação da Apple no App Store Connect, o software classifica-se como isento de relatórios anuais e de registro formal de número ERN (*Encryption Registration Number*) por enquadrar-se na **Nota 4 da Categoria 5, Parte 2 do EAR** (*Cryptography Note*):

1. **Software de Mercado de Massa (*Mass Market*):** O aplicativo é distribuído publicamente através da App Store para o público geral, sem restrições de venda direta ou distribuição personalizada.
2. **Uso de Criptografia Padrão:** O aplicativo não implementa algoritmos criptográficos proprietários, experimentais ou modificados. Ele utiliza unicamente implementações consolidadas e abertas da indústria.
3. **Finalidade Estrita de Proteção de Dados e Autenticação:** A criptografia destina-se exclusivamente a assegurar a confidencialidade e integridade dos arquivos e metadados em repouso no aparelho do usuário e nos backups exportados pelo próprio usuário. O app não oferece canais de comunicação cifrada ponto a ponto (ex.: mensagens instantâneas ou VoIP), tunelamento VPN customizado ou funções governamentais/militares.

---

## 2. Inventário de Primitivas Criptográficas Utilizadas

| Componente | Primitiva | Biblioteca / Provedor | Finalidade |
|---|---|---|---|
| **Cifra Autenticada de Mídia e Metadados** | AES-256-GCM (Chave de 256 bits, Tag de 128 bits, Nonce de 96 bits) | Apple `CryptoKit` nativo do iOS | Cifragem e verificação de integridade de blocos de fotos e vídeos, índice de metadados (`vault.index`) e manifesto de backup. |
| **Derivação de Chaves de Senha (KDF)** | Argon2id v1.3 (`opslimit=3`, `memlimit=64 MiB`, Salt de 16 bytes) | `libsodium` (via pacote `swift-sodium` v0.11.0) | Derivação de Master Key (MK) a partir da credencial principal escolhida pelo usuário para proteção contra ataques offline de força bruta. |
| **Derivação de Chaves de Recuperação** | HKDF-SHA256 (Saída de 256 bits) | Apple `CryptoKit` nativo do iOS | Derivação de Recovery Key (RK) a partir do código de recuperação de 128 bits gerado localmente. |
| **Geração de Segredos Aleatórios** | CSPRNG (`SecRandomCopyBytes`) | Apple `Security.framework` | Geração da chave mestra do cofre (VK), DEKs por arquivo, salts aleatórios e nonces. |

---

## 3. Configuração no `Info.plist` do Projeto

No arquivo `Vox-Info.plist` incluído no pacote da aplicação, a seguinte chave foi configurada:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Ao definir `ITSAppUsesNonExemptEncryption` como `false`, o App Store Connect reconhece automaticamente que o aplicativo se enquadra nas isenções regulatórias, dispensando o preenchimento manual do questionário de conformidade de exportação a cada novo upload de build.

---

## 4. Guia de Respostas para o Questionário do App Store Connect

Caso a chave automática seja reavaliada pela Apple em auditorias manuais, as respostas padronizadas para o questionário de exportação são:

1. **Seu aplicativo usa criptografia?**
   *Resposta:* **Sim** (*Yes*).
2. **Seu aplicativo é qualificado para alguma das isenções fornecidas na Categoria 5, Parte 2 do EAR?**
   *Resposta:* **Sim** (*Yes*).
   *Justificativa:* O aplicativo utiliza apenas criptografia padrão da indústria para autenticação e proteção de dados em repouso do usuário no dispositivo local, qualificando-se sob a Nota 4 da Categoria 5, Parte 2.
3. **O aplicativo implementa criptografia não isenta?**
   *Resposta:* **Não** (*No*).
4. **O aplicativo está sujeito à declaração de exportação para a França (ANSSI)?**
   *Resposta:* **Não** (*No*). O uso destina-se a fins estritamente pessoais de proteção de arquivos locais do consumidor.
