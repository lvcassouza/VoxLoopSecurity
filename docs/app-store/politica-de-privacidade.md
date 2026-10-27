# Política de Privacidade — Vox

**Última atualização:** 26 de outubro de 2026
**Responsável:** Voxloop (`voxloop.com.br`)
**Aplicativo:** Vox — Cofre Privado (iOS)

---

## 1. Nosso Compromisso com a Privacidade

A privacidade não é apenas uma funcionalidade no **Vox**; ela é a arquitetura fundamental do produto. O Vox foi projetado com base no princípio de que seus arquivos pessoais pertencem exclusivamente a você e não devem ser vistos, transmitidos ou analisados por ninguém — nem mesmo pela Voxloop.

Nós **não coletamos, não armazenamos em servidores, não vendemos e não compartilhamos nenhum dado pessoal, mídia ou metadado seu**.

---

## 2. Dados que NÃO Coletamos

Para total transparência:

- **Sem contas de usuário:** Você não precisa informar nome, e-mail, telefone ou documento para usar o Vox.
- **Sem telemetria ou analytics:** O aplicativo não inclui kits de desenvolvimento de terceiros (SDKs) para monitoramento de comportamento, relatórios de falhas de terceiros, anunciantes ou ferramentas de publicidade.
- **Sem servidores ou nuvem operada pelo projeto:** O Vox não possui backend próprio. Seus arquivos nunca transitam por servidores da Voxloop.
- **Sem acesso às suas senhas ou mídias:** A Voxloop não possui chaves mestras, portas dos fundos ou meios técnicos para recuperar sua credencial principal, seu código de recuperação ou o conteúdo do seu cofre.

---

## 3. Como Suas Fotos e Vídeos São Processados

Todo o processamento do Vox ocorre de forma **estritamente local no seu iPhone**:

1. **Importação da Fototeca:** Quando você escolhe importar itens, o aplicativo utiliza o seletor nativo de fotos do sistema iOS (`PhotosPicker`). O Vox tem acesso temporário unicamente aos itens que você seleciona explicitamente. Uma cópia cifrada é gravada dentro do armazenamento sandbox isolado do aplicativo, e o arquivo de origem original permanece na sua Fototeca sem qualquer alteração.
2. **Criptografia em Repouso:** Os itens incorporados ao cofre e seus metadados (como nomes de arquivos, durações e datas) são gravados com criptografia autenticada (AES-256-GCM) e chaves derivadas localmente por algoritmos resistentes (Argon2id).
3. **Proteção Visual:** Quando o aplicativo entra em segundo plano ou é visualizado no seletor de aplicativos do iOS, a exibição de mídia é imediatamente coberta por uma cortina opaca para evitar captura involuntária de tela pelo sistema operacional.
4. **Exportação e Backups:** Quando você decide exportar uma mídia ou criar um arquivo de backup (`.voxbackup`), a ação é solicitada e confirmada por você através da interface do aplicativo Arquivos do iOS. O destino é escolhido por você e fica sob seu controle exclusivo.

---

## 4. Permissões Solicitadas no Dispositivo

O Vox solicita apenas as permissões de sistema estritamente necessárias para as ações solicitadas pelo usuário:

- **Acesso à Fototeca (Fotos):** Solicitado contextualmente apenas no momento em que você toca para importar arquivos. Usado exclusivamente para ler os itens selecionados por você e transferi-los para o cofre.
- **Armazenamento e Arquivos:** Usado através do seletor nativo do sistema operacional (`UIDocumentPicker`) quando você decide salvar ou verificar um backup em locais como o app Arquivos ou unidades externas.

O aplicativo **não solicita** permissões de localização, contatos, microfone, câmera direta, notificações push ou identificadores de publicidade (IDFA).

---

## 5. Responsabilidade sobre Senhas e Recuperação

Por projeto de segurança matemática e ausência de servidores:

- **Credencial Principal e Código de Recuperação:** O cofre é protegido pela senha ou frase que você define e por um código de recuperação aleatório gerado no seu dispositivo.
- **Consequência da Perda de Segredos:** Se você esquecer sua credencial principal e não possuir o código de recuperação, o cofre se tornará permanentemente inacessível. O suporte da Voxloop não tem capacidade técnica de redefinir sua senha nem de resgatar seus arquivos.
- **Backups:** A perda ou avaria do iPhone sem a existência de um backup salvo externamente pode resultar na perda definitiva dos arquivos contidos no cofre. O Vox alerta que um backup salvo apenas no próprio aparelho corre o risco de ser perdido junto com ele.

---

## 6. Conformidade Legal (LGPD e GDPR)

O Vox foi desenvolvido em total conformidade com a Lei Geral de Proteção de Dados (LGPD - Lei nº 13.709/2018) do Brasil e com o Regulamento Geral de Proteção de Dados (GDPR) da União Europeia. Como o aplicativo não realiza coleta nem tratamento de dados em servidores, o princípio da minimização da coleta é cumprido em seu grau máximo: coleta zero.

---

## 7. Contato e Dúvidas

Se você tiver qualquer dúvida sobre esta Política de Privacidade ou sobre as práticas de privacidade do Vox, entre em contato através dos nossos canais oficiais:

- **Website:** [voxloop.com.br](https://voxloop.com.br)
- **Suporte e Privacidade:** `privacidade@voxloop.com.br`
