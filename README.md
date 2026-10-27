# Vox / Voxloop

Projeto de um cofre privado para fotos e vídeos no iPhone.

- [Descoberta e decisões do produto](docs/discovery.md)
- [Brief para IA desenvolver o app](docs/ai-development-brief.md)
- [Avaliação técnica oficial da Fase 3](docs/avaliacao-tecnica-fase-3.md)
- [Especificação da Fase 5 — Backup e Restauração](docs/specs/fase-5-backup-verificacao-restauracao.md)
- [ADR 0007 — Formato e ciclo de vida do backup](docs/adr/0007-formato-e-ciclo-de-vida-do-backup.md)
- [Especificação de UI/UX e identidade visual](docs/ui-visual-spec.md)
- [Prancha visual de referência](docs/vox-ui-preview.html)
- [Símbolos e assinaturas em SVG](assets/brand/)

### Preparação para a App Store (Fase 6)
- [Ficha do produto na App Store](docs/app-store/ficha-app-store.md)
- [Política de Privacidade](docs/app-store/politica-de-privacidade.md)
- [Declaração de exportação de criptografia](docs/app-store/declaracao-exportacao-criptografia.md)
- [Roteiro de testes físicos e auditoria independente](docs/app-store/roteiro-auditoria-e-gates-fase-6.md)

## Executar o projeto iOS

Abra `Vox.xcodeproj` no Xcode e execute o esquema `Vox` em um simulador iOS ou iPhone conectado. Para compilar sem assinatura:

```sh
xcodebuild -project Vox.xcodeproj -scheme Vox -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

O aplicativo implementa o cofre local criptografado, importação seletiva pela Fototeca (`PhotosPicker`), cópias cifradas em blocos com AES-256-GCM, índice de metadados cifrado, desbloqueio e recuperação por código de 128 bits, visualização autenticada, exportação por seletor nativo e o ciclo completo de backup portátil (`.voxbackup`), verificação de integridade sem mutação e restauração limpa com rotação de credenciais. Use somente arquivos sintéticos e uma credencial exclusiva de teste: o seletor aceita mídia pessoal e o app não consegue distingui-la. Biometria integrada à Keychain permanece pendente. A implementação não foi auditada por terceiros nem deve ser descrita como segura ou pronta para produção. A validação em hardware físico mínimo, a restauração entre dois iPhones físicos e a auditoria independente de segurança permanecem gates contratuais obrigatórios antes da comercialização pública.

Para executar os testes automatizados do domínio:

```sh
swift test
```
