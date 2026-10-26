import Combine
import Foundation

/// Owns the visible access state; cryptographic work and disk I/O run in `VaultFileStore`.
@MainActor
public final class VaultAccessManager: ObservableObject {
    @Published public private(set) var estadoAcesso: EstadoAcesso = .naoConfigurado
    @Published public private(set) var isConfigurado = false
    @Published public private(set) var itens: [ItemDoCofre] = []
    @Published public private(set) var estadoBackup: EstadoBackup = .nuncaCriado
    @Published public private(set) var biometriaAtiva = false
    @Published public private(set) var cortinaPrivacidadeAtiva = false
    @Published public private(set) var tentativasFalhas = 0
    @Published public private(set) var codigoRecuperacaoPendente: String?
    @Published public private(set) var ultimoBackupData: Date?
    @Published public private(set) var erroAcesso: String?

    private let store: VaultFileStore
    private var bloqueioEmAndamento: Task<Void, Never>?
    private var sessionEpoch: UInt64 = 0

    public static func diretorioDoCofrePadrao() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("VoxVault", isDirectory: true)
    }

    public init(
        itensIniciais: [ItemDoCofre] = [],
        configuradoInicial: Bool = false,
        storageDirectory: URL? = nil
    ) {
        let directory = storageDirectory ?? Self.diretorioDoCofrePadrao()
        self.store = VaultFileStore(rootURL: directory)
        let exists = FileManager.default.fileExists(atPath: directory.appendingPathComponent("vault.header").path)
        self.isConfigurado = exists
        self.estadoAcesso = exists ? .bloqueado : .naoConfigurado
        // Keep the source-compatible arguments, but never trust caller-supplied access state.
        _ = configuradoInicial
        self.itens = exists ? [] : itensIniciais
    }

    // MARK: - Setup and authentication

    public func configurarCofre(credencial: String, confirmacao: String) async throws -> String {
        guard credencial.count >= 12 else { throw VaultError.credencialMuitoCurta }
        guard credencial == confirmacao else { throw VaultError.credenciaisNaoCoincidem }
        guard !isConfigurado else { throw VaultError.cofreJaConfigurado }
        erroAcesso = nil
        let epoch = sessionEpoch
        let code = try await store.prepareVault(passphrase: credencial)
        guard epoch == sessionEpoch, !isConfigurado else {
            await store.cancelPendingSetup()
            throw VaultError.operacaoInterrompida
        }
        codigoRecuperacaoPendente = code
        return code
    }

    public func confirmarCodigoRecuperacao(trechoDigitado: String) async throws {
        guard let pending = codigoRecuperacaoPendente else { throw VaultError.codigoRecuperacaoInvalido }
        let entered = Self.normalizeRecoveryCode(trechoDigitado)
        let full = Self.normalizeRecoveryCode(pending)
        let lastGroup = String(full.suffix(8))
        guard entered == full || entered == lastGroup else { throw VaultError.confirmacaoInvalida }
        try await store.confirmSetup(code: trechoDigitado)
        codigoRecuperacaoPendente = nil
        isConfigurado = true
        estadoAcesso = .desbloqueado
        tentativasFalhas = 0
        erroAcesso = nil
        SanitizedLogger.shared.log(.cofreConfigurado)
    }

    public func cancelarConfiguracao() async {
        sessionEpoch &+= 1
        await store.cancelPendingSetup()
        codigoRecuperacaoPendente = nil
    }

    /// The face/Touch ID flow is intentionally unavailable until the keychain envelope is implemented.
    public func definirBiometria(ativa: Bool) {
        biometriaAtiva = false
        _ = ativa
    }

    public func desbloquearComCredencial(_ credencial: String) async -> Bool {
        guard isConfigurado, estadoAcesso == .bloqueado else { return false }
        await bloqueioEmAndamento?.value
        let epoch = sessionEpoch
        do {
            let loadedItems = try await store.unlock(passphrase: credencial)
            guard epoch == sessionEpoch, estadoAcesso == .bloqueado, !cortinaPrivacidadeAtiva else {
                await store.lock()
                return false
            }
            itens = loadedItems
            isConfigurado = true
            estadoAcesso = .desbloqueado
            tentativasFalhas = 0
            erroAcesso = nil
            updateBackupStateAfterUnlock()
            SanitizedLogger.shared.log(.cofreDesbloqueado(metodo: "credencial"))
            return true
        } catch {
            tentativasFalhas += 1
            erroAcesso = error.localizedDescription
            SanitizedLogger.shared.log(.falhaAutenticacao)
            return false
        }
    }

    public func desbloquearComBiometria(sucessoSimulado: Bool = true) -> Bool {
        _ = sucessoSimulado
        return false
    }

    public func bloquearCofre() {
        guard isConfigurado else { return }
        estadoAcesso = .bloqueado
        sessionEpoch &+= 1
        itens.removeAll(keepingCapacity: false)
        estadoBackup = .nuncaCriado
        ultimoBackupData = nil
        erroAcesso = nil
        bloqueioEmAndamento = Task { await store.lock() }
        SanitizedLogger.shared.log(.cofreBloqueado)
    }

    public func aplicarCortinaPrivacidade(ativa: Bool) {
        cortinaPrivacidadeAtiva = ativa
        if ativa && isConfigurado { bloquearCofre() }
    }

    // MARK: - Recovery

    public func iniciarRecuperacao() {
        guard isConfigurado else { return }
        estadoAcesso = .recuperando
    }

    public func cancelarRecuperacao() {
        estadoAcesso = isConfigurado ? .bloqueado : .naoConfigurado
    }

    public func redefinirCredencialComCodigo(
        codigo: String,
        novaCredencial: String,
        confirmacao: String
    ) async throws {
        guard isConfigurado else { throw VaultError.codigoRecuperacaoInvalido }
        guard !novaCredencial.isEmpty else { throw VaultError.credencialMuitoCurta }
        let epoch = sessionEpoch
        let restoredItems = try await store.recover(code: codigo, newPassphrase: novaCredencial, confirmation: confirmacao)
        guard epoch == sessionEpoch, !cortinaPrivacidadeAtiva else {
            await store.lock()
            throw VaultError.operacaoInterrompida
        }
        itens = restoredItems
        estadoAcesso = .desbloqueado
        tentativasFalhas = 0
        erroAcesso = nil
        SanitizedLogger.shared.log(.cofreDesbloqueado(metodo: "recuperacao"))
    }

    public func apagarCofreInacessivel() async {
        try? await store.eraseVault()
        itens.removeAll(keepingCapacity: false)
        isConfigurado = false
        codigoRecuperacaoPendente = nil
        ultimoBackupData = nil
        estadoBackup = .nuncaCriado
        biometriaAtiva = false
        tentativasFalhas = 0
        estadoAcesso = .naoConfigurado
        SanitizedLogger.shared.log(.cofreResetado)
    }

    func simularFalhaDeTransacaoParaTeste(_ point: VaultTransactionFailurePoint?) async {
        await store.setSimulatedFailure(point)
    }

    // MARK: - Local encrypted imports

    public func importarArquivo(
        em url: URL,
        nome: String,
        tipo: TipoDeMidia,
        duracao: Double? = nil
    ) async throws -> ItemDoCofre {
        guard estadoAcesso == .desbloqueado else { throw VaultError.cofreBloqueado }
        let epoch = sessionEpoch
        let item = try await store.importFile(at: url, name: nome, mediaType: tipo, duration: duracao)
        guard epoch == sessionEpoch, estadoAcesso == .desbloqueado, !cortinaPrivacidadeAtiva else {
            throw VaultError.cofreBloqueado
        }
        itens.append(item)
        atualizarEstadoBackupAposModificacao()
        SanitizedLogger.shared.log(.importacaoLocalConcluida)
        return item
    }

    /// Creates deterministic, non-viewable fixture bytes and persists them through the real encrypted store.
    public func importarItensSinteticos(
        quantidade: Int,
        tipo: TipoDeMidia,
        simularEspacoInsuficiente: Bool = false,
        simularInterrupcao: Bool = false
    ) async throws -> Int {
        guard estadoAcesso == .desbloqueado else { throw VaultError.cofreBloqueado }
        guard (1...12).contains(quantidade) else { throw VaultError.quantidadeDeItensInvalida }
        SanitizedLogger.shared.log(.importacaoSinteticaIniciada(quantidade: quantidade))
        if simularEspacoInsuficiente { throw VaultError.espacoInsuficiente }
        if simularInterrupcao { throw VaultError.operacaoInterrompida }

        let colors = ["#087D70", "#173238", "#70D9BE", "#326273", "#5C9EAD", "#E39774"]
        let epoch = sessionEpoch
        let fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("VoxFixtures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        for offset in 0..<quantidade {
            let label = "Vox synthetic fixture \(tipo.rawValue) \(offset + 1) — no real media"
            var fixture = Data(label.utf8)
            fixture.append(Data(repeating: UInt8(offset + 1), count: 32 * 1024))
            let fileURL = fixtureDirectory.appendingPathComponent("fixture-\(offset + 1).bin")
            try fixture.write(to: fileURL, options: .atomic)
            let duration = tipo == .video ? Double(15 + offset * 12) : nil
            let item = try await store.importFile(
                at: fileURL,
                name: label,
                mediaType: tipo,
                duration: duration,
                syntheticColor: colors[(itens.count + offset) % colors.count]
            )
            guard epoch == sessionEpoch, estadoAcesso == .desbloqueado, !cortinaPrivacidadeAtiva else {
                throw VaultError.cofreBloqueado
            }
            itens.append(item)
        }
        atualizarEstadoBackupAposModificacao()
        SanitizedLogger.shared.log(.importacaoSinteticaConcluida(quantidade: quantidade))
        return quantidade
    }

    public func exportarItem(id: UUID) throws {
        guard let item = itens.first(where: { $0.id == id }) else { throw VaultError.itemNaoEncontrado }
        guard item.status != .adulterado else { throw VaultError.dadoAdulterado }
        throw VaultError.exportacaoIndisponivelNestaVersao
    }

    public func apagarItemDoCofre(id: UUID) async throws {
        guard estadoAcesso == .desbloqueado else { throw VaultError.cofreBloqueado }
        try await store.deleteItem(id: id)
        itens.removeAll { $0.id == id }
        atualizarEstadoBackupAposModificacao()
        SanitizedLogger.shared.log(.itemLocalExcluido)
    }

    /// Test-only UI affordance; it does not alter ciphertext or the authenticated index.
    public func adulterarItemParaTeste(id: UUID) {
        if let index = itens.firstIndex(where: { $0.id == id }) { itens[index].status = .adulterado }
    }

    // MARK: - Explicitly demonstrative backup flows

    public func criarBackup() throws -> Date {
        let now = Date()
        ultimoBackupData = now
        for index in itens.indices where itens[index].status == .pendenteBackup {
            itens[index].status = .integro
        }
        estadoBackup = .atualizado(data: now, contagemItens: itens.count)
        SanitizedLogger.shared.log(.backupSimulado(contagem: itens.count))
        return now
    }

    public func verificarBackup(modo: ModoSimulacaoBackup = .integro) -> ResultadoVerificacaoBackup {
        switch modo {
        case .integro:
            let date = ultimoBackupData ?? Date()
            SanitizedLogger.shared.log(.verificacaoBackupSimulada(valido: true))
            return .legivel(data: date, contagemItens: itens.count)
        case .adulterado:
            SanitizedLogger.shared.log(.verificacaoBackupSimulada(valido: false))
            return .impossivelVerificar(motivo: "Este cenário simula dados alterados; nenhum arquivo foi verificado.")
        case .versaoIncompativel:
            SanitizedLogger.shared.log(.verificacaoBackupSimulada(valido: false))
            return .formatoIncompativel(versaoEncontrada: "EXEMPLO-v9.9")
        }
    }

    public func restaurarDeBackup(itensRestaurados: [ItemDoCofre], credencial: String, confirmacao: String) throws {
        _ = itensRestaurados
        _ = credencial
        _ = confirmacao
        throw VaultError.restauracaoIndisponivelNestaVersao
    }

    // MARK: - State helpers

    private func updateBackupStateAfterUnlock() {
        if !itens.isEmpty {
            estadoBackup = .desatualizado(dataUltimo: nil, itensPendentes: itens.count)
        } else {
            estadoBackup = .nuncaCriado
        }
    }

    private func atualizarEstadoBackupAposModificacao() {
        let pending = itens.filter { $0.status == .pendenteBackup }.count
        if pending > 0 {
            estadoBackup = .desatualizado(dataUltimo: ultimoBackupData, itensPendentes: pending)
        } else if let latest = ultimoBackupData {
            estadoBackup = .atualizado(data: latest, contagemItens: itens.count)
        } else {
            estadoBackup = itens.isEmpty ? .nuncaCriado : .desatualizado(dataUltimo: nil, itensPendentes: itens.count)
        }
    }

    private static func normalizeRecoveryCode(_ value: String) -> String {
        value.uppercased().filter(\.isHexDigit)
    }
}
