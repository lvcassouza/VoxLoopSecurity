# Fase 4 — visualização, exportação, exclusão e troca de credencial

Estado: especificação de implementação experimental. Não é aprovação de segurança nem gate de lançamento.

## Problema

O cofre da Fase 3 importa e cifra fotos e vídeos, mas a grade e a tela de detalhes ainda mostram prévias ilustrativas. Exportação e troca de credencial principal não têm fluxo funcional, e falhas de exclusão em lote podem ser ocultadas pela interface.

## Objetivo

Permitir que a pessoa veja mídia armazenada cifrada no cofre e, após confirmação, exporte cópias decifradas para o destino escolhido; redefina a credencial principal com o código de recuperação conforme os ADRs 0004–0005; e apague somente cópias do cofre. O arquivo de origem e backups antigos permanecem fora dessas operações.

## Comportamento

1. A grade mostra miniaturas geradas em memória a partir de dados autenticados. A tela de detalhes apresenta a imagem ou reproduz o vídeo do item. Fixtures sintéticas sem formato de mídia reconhecido exibem estado de erro recuperável, sem travar o cofre.
2. Cada leitura abre uma sessão de mídia vinculada ao cofre desbloqueado. A sessão desembrulha a DEK do item e autentica os blocos AES-GCM necessários antes de devolver bytes. Leituras por faixa validam limites, tamanho esperado, nonce, AAD e tag. Falha de autenticação encerra a leitura e não mostra bytes daquele bloco.
3. Fotos usam decodificação com acesso direto por blocos e miniaturas limitadas em resolução, sem arquivo claro persistente. Vídeos usam `AVAssetResourceLoader` com esquema de URL privado para atender faixas de bytes diretamente do cofre cifrado; não criar cópia clara em disco para reprodução.
4. Bloqueio, ida para segundo plano, fechamento do detalhe ou erro encerra sessões, pausa o player e descarta referências visuais em memória da melhor forma possível. A limpeza de buffers Swift/CryptoKit permanece best-effort.
5. Exportar exige confirmação com o texto da seção 6.6 de `docs/ui-visual-spec.md`. Depois da confirmação, o Vox decifra o item em fluxo para um arquivo temporário com proteção de dados do iOS e exclusão de backup, e abre o seletor nativo de destino. A gravação verifica todas as tags e sincroniza o arquivo antes de oferecê-lo ao seletor. Remover o temporário após sucesso, cancelamento, erro ou bloqueio; limpar sobras conhecidas na próxima inicialização. Não prometer apagamento físico. A pessoa escolhe o destino, que pode manter uma cópia externa.
6. Apagar pede confirmação e remove apenas o item do cofre. A Fototeca, exportações e backups anteriores permanecem. Erro não é ignorado: a interface preserva/atualiza o estado conforme o resultado e informa falhas sem expor caminhos ou segredos.
7. O fluxo de troca/redefinição de credencial usa o código de recuperação separado, conforme os ADRs 0004–0005 e a UI existente. O store deriva uma nova chave Argon2id e substitui atomicamente apenas o envelope da credencial para a mesma VK. O envelope de recuperação e os itens permanecem válidos. Credenciais anteriores deixam de abrir o cofre; backups externos antigos, quando existirem, não são revogados por essa troca.

## Requisitos não funcionais e segurança

- Não persistir miniaturas ou cache de reprodução em claro; todo acesso ocorre somente enquanto o estado é desbloqueado.
- Manter leitura e exportação em memória limitada por blocos; nunca carregar um vídeo inteiro em memória.
- Rejeitar intervalos negativos, fora do tamanho autenticado, truncados ou com overflow antes de acessar o arquivo.
- Sessões são invalidadas sob bloqueio e podem ser encerradas individualmente. A invalidação impede novas leituras e fecha o descritor.
- Temporários de exportação ficam fora de backups, com proteção de arquivo `complete` quando suportada. O app pode remover o arquivo temporário, sem alegar sobrescrita física em flash.
- O formato persistido da Fase 3 não muda. Usar CryptoKit/AES-GCM e os parâmetros/hierarquia dos ADRs 0004–0006; sem fallback criptográfico.
- Erros apresentados não incluem nome do arquivo, caminho, conteúdo, credencial, código de recuperação nem dados criptográficos.
- Não remover a indicação visível de protótipo interno e uso apenas com arquivos de teste.

## Critérios de aceitação

- Leitura por faixa de um item de teste reproduz exatamente os bytes de origem para faixas dentro de um bloco, cruzando blocos e no bloco final parcial.
- Faixa inválida, arquivo truncado, tag alterada ou sessão invalidada falha sem bytes não autenticados.
- Exportação íntegra cria arquivo byte a byte igual ao arquivo de origem; falha durante a decifragem não oferece arquivo parcial e remove o temporário conhecido.
- O arquivo de origem permanece intacto depois de importação, visualização, exportação e exclusão da cópia no cofre.
- Fotos e vídeos válidos abrem por caminhos próprios no iOS; mídia inválida/fixture tem estado explícito de erro. Grade e detalhe não retêm referências visuais depois de bloqueio.
- Alteração de credencial rejeita credencial atual errada, nova credencial curta e confirmação divergente; depois da alteração, nova credencial funciona, antiga falha, código de recuperação continua funcionando e itens permanecem íntegros.
- Exclusão persistida remove o item do catálogo; uma falha é visível e não é engolida pela UI.
- Exportação e exclusão explicam que arquivo de origem e backups anteriores não são alterados.
- Testes automatizados usam somente bytes/fixtures sintéticos. `swift test` e build do target iOS devem passar; isso não substitui testes de reprodução/exportação em iPhones físicos.

## Fora de escopo

- Backup real, verificação de backup e restauração em outro aparelho (Fase 5).
- Biometria/Keychain, compartilhamento/sincronização, exclusão do arquivo de origem, alegação de apagamento seguro, suporte a documentos, publicação ou auditoria.
- Teste com arquivos pessoais. Testes em iPhone físico permanecem gate humano antes de beta/público.

## Riscos e gates

O fluxo de exportação cria uma cópia clara temporária e o destino escolhido pode retê-la. `removeItem` não garante apagamento físico. A memória transitória não pode ser zerada deterministicamente em Swift/CryptoKit. AVFoundation, ImageIO, Data Protection, cancelamento e recuperação devem ser validados em aparelhos reais; revisão independente segue obrigatória antes da publicação.
