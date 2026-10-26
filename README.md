# Vox / Voxloop

Projeto de um cofre privado para fotos e vídeos no iPhone.

- [Descoberta e decisões do produto](docs/discovery.md)
- [Brief para IA desenvolver o app](docs/ai-development-brief.md)
- [Avaliação técnica oficial da Fase 3](docs/avaliacao-tecnica-fase-3.md)
- [Especificação de UI/UX e identidade visual](docs/ui-visual-spec.md)
- [Prancha visual de referência](docs/vox-ui-preview.html)
- [Símbolos e assinaturas em SVG](assets/brand/)

## Executar o protótipo iOS

Abra `Vox.xcodeproj` no Xcode e execute o esquema `Vox` em um simulador iOS ou iPhone conectado. Para compilar sem assinatura:

```sh
xcodebuild -project Vox.xcodeproj -scheme Vox -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

O protótipo interno já cria um cofre local, importa itens escolhidos no `PhotosPicker`, grava cópias cifradas por blocos com AES-256-GCM, cifra o índice de metadados, permite desbloqueio e recuperação por código e retoma transações interrompidas. A implementação experimental da Fase 4 adiciona visualização de mídia autenticada e exportação por seletor nativo; reprodução e exportação ainda precisam de validação em iPhones físicos. Use somente arquivos sintéticos e uma credencial exclusiva de teste: o seletor aceita mídia pessoal e o app não consegue distingui-la. Biometria e arquivos de backup continuam pendentes. A implementação não foi auditada nem deve ser descrita como segura ou pronta para produção. Restauração entre iPhones físicos e auditoria independente são gates obrigatórios antes de qualquer lançamento público.

Para executar os testes de integração do domínio:

```sh
swift test
```
