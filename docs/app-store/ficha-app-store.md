# Ficha do Produto na App Store — Vox

**Versão do aplicativo:** 1.0.0
**Data:** 26 de outubro de 2026
**Status:** Material aprovado para cadastro no App Store Connect
**Referências normativas:** [docs/ui-visual-spec.md](../ui-visual-spec.md), [docs/discovery.md](../discovery.md), [docs/adr/0003-arquitetura-da-marca.md](../adr/0003-arquitetura-da-marca.md).

---

## 1. Metadados Principais da Loja

| Campo | Conteúdo | Limite / Regra da Apple |
|---|---|---|
| **Nome do aplicativo (Title)** | `Vox — Cofre Privado` | 20 caracteres (limite máximo: 30) |
| **Subtítulo (Subtitle)** | `Fotos e vídeos no iPhone` | 25 caracteres (limite máximo: 30) |
| **Categoria Principal** | Utilitários (*Utilities*) | Categoria oficial da App Store |
| **Categoria Secundária** | Foto e Vídeo (*Photo & Video*) | Categoria oficial da App Store |
| **Classificação Indicativa (Age Rating)** | 4+ (Livre para todas as idades) | Sem violência, sem nudez, sem compras, sem acesso irrestrito à web |
| **Classificação de Conteúdo** | Não contém conteúdo contestável | Questionário padrão da Apple |
| **Modelo de Monetização** | Gratuito | Sem compras no app, sem assinaturas, sem anúncios |
| **Idiomas Suportados** | Português (Brasil) — idioma principal | Localização padrão configurada |
| **Direitos Autorais (Copyright)** | `© 2026 Voxloop. Todos os direitos reservados.` | Titularidade jurídica Voxloop |

---

## 2. Textos de Apresentação e Marketing

### Texto Promocional (Promotional Text)
*Exibido acima da descrição no App Store Connect; pode ser atualizado sem nova versão do binário (máximo 170 caracteres).*

> Seus arquivos. No seu controle. Guarde fotos e vídeos em um cofre privado local no seu iPhone, com backup portátil e sem depender de nuvem de terceiros.

*(Total: 153 caracteres — dentro do limite de 170).*

---

### Palavras-chave (Keywords)
*Termos de busca separados estritamente por vírgula, sem espaços desnecessários (máximo 100 caracteres).*

`cofre,fotos,privacidade,segurança,privado,vídeos,backup,criptografia,álbum,off-line,galeria,esconder`

*(Total: 98 caracteres — dentro do limite de 100).*

---

### Descrição Completa (Description)
*Formatada para leitura limpa em telas móveis da App Store (máximo 4.000 caracteres).*

```text
Vox é o cofre privado da Voxloop para guardar fotos e vídeos pessoais no iPhone com clareza, tranquilidade e total autonomia.

Sem contas obrigatórias, sem servidores da Voxloop e sem nuvem de terceiros. Todo o conteúdo é guardado no armazenamento local do seu aparelho, sob controle exclusivo da sua credencial principal.

POR QUE ESCOLHER O VOX?

• CONTROLE TRANSPARENTE DE CÓPIAS
Ao importar fotos e vídeos da Fototeca, o Vox cria uma cópia protegida dentro do cofre. A foto original continua onde sempre esteve no seu app Fotos. Você decide o que fazer com cada cópia, sem exclusões automáticas ou surpresas.

• PRIVACIDADE VISÍVEL EM REPOUSO
Com o cofre fechado, nomes de arquivos, metadados, durações e miniaturas permanecem inacessíveis. Ao alternar entre aplicativos ou colocar o Vox em segundo plano, a tela é imediatamente oculta para proteger suas mídias no seletor de multitarefa do iOS.

• DESBLOQUEIO DIRETO E CONVENIENTE
Defina uma frase longa e exclusiva para abrir seu cofre. Se você esquecer sua senha, um código de recuperação exclusivo gerado no seu aparelho ajuda a restabelecer o acesso. Perder ambos torna o cofre permanentemente inacessível — por desenho de segurança, não existem portas dos fundos nem contas recuperáveis por suporte.

• BACKUP CRIPTOGRAFADO SOB SEU CONTROLE
Exporte quando quiser um pacote completo de backup (.voxbackup) para o destino que você escolher: um drive externo, o app Arquivos ou seu armazenamento de confiança. O Vox permite verificar a integridade de qualquer backup sem alterar seu cofre atual e restaurar seus arquivos em uma nova instalação de forma previsível.

• 100% INDEPENDENTE E PRIVADO
O Vox não possui anúncios, não oferece compras no aplicativo e não contém qualquer rastreador ou ferramenta de análise de terceiros (analytics). O cofre funciona de forma totalmente autônoma e off-line.

Seus arquivos. No seu controle.
```

*(Total: 1.890 caracteres — respeita com folga o limite de 4.000 caracteres).*

---

## 3. URLs e Suporte Institucional

- **URL de Suporte (Support URL):** `https://voxloop.com.br/suporte`
- **URL de Marketing (Marketing URL):** `https://voxloop.com.br`
- **URL da Política de Privacidade (Privacy Policy URL):** `https://voxloop.com.br/privacidade`

---

## 4. Informações para a Equipe de Revisão da Apple (App Review Information)

*Instruções para o revisor humano da App Store Connect poder testar o aplicativo plenamente:*

- **Requer login ou conta:** Não.
- **Funcionamento:** O Vox não requer registro nem conta de usuário. Toda a inicialização e configuração acontecem localmente no iPhone.
- **Instruções para teste do cofre:**
  1. Ao abrir o aplicativo pela primeira vez, toque em "Criar meu cofre".
  2. Defina uma frase de teste (exemplo: `FraseDeTesteApple2026!`).
  3. O aplicativo exibirá o código de recuperação gerado localmente. Anote ou copie o código e redigite o último bloco para confirmação.
  4. O cofre abrirá no estado desbloqueado. O revisor pode tocar em "Importar fotos" para escolher fotos ou vídeos de teste da Fototeca, verificar a grade de itens, testar o bloqueio manual em Ajustes e desbloquear novamente com a credencial definida.
  5. Para testar o fluxo de backup e verificação, acesse a aba "Backup" e utilize o seletor nativo de Arquivos.
- **Uso de Criptografia:** Em conformidade com as regras de exportação de criptografia dos EUA (EAR / BIS) e da Apple, o aplicativo faz uso de criptografia padrão autenticada para proteção de dados em repouso do usuário (AES-256-GCM e Argon2id v1.3 via CryptoKit e libsodium). Declaração `ITSAppUsesNonExemptEncryption = NO` documentada.
