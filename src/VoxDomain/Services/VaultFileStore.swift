import CryptoKit
import Foundation

enum VaultTransactionFailurePoint: Sendable, Equatable {
    case afterStagingVerification
    case afterJournal
    case afterFileMove
    case afterIndexWrite
}

/// Single-writer local vault store. All expensive crypto and disk I/O run on this actor.
actor VaultFileStore {
    private struct Header: Codable, Sendable {
        var version: Int
        var kdf: String
        var kdfVersion: Int
        var operations: UInt64
        var memoryBytes: Int
        var passwordSalt: Data
        var recoverySalt: Data
        var passwordEnvelope: VaultCrypto.SealedValue
        var recoveryEnvelope: VaultCrypto.SealedValue
        var credentialType: String?
    }

    private struct Record: Codable, Sendable {
        let id: UUID
        let name: String
        let mediaType: TipoDeMidia
        let size: Int64
        let createdAt: Date
        let duration: Double?
        let syntheticColor: String
        let noncePrefix: UInt32
        let chunkCount: UInt64
        let wrappedDataKey: VaultCrypto.SealedValue

        var item: ItemDoCofre {
            ItemDoCofre(
                id: id,
                nomeOriginal: name,
                tipo: mediaType,
                tamanhoBytes: size,
                dataCriacao: createdAt,
                duracaoSegundos: duration,
                status: .pendenteBackup,
                corSinteticaHex: syntheticColor
            )
        }
    }

    private struct Index: Codable, Sendable {
        var version: Int
        var items: [Record]
        var contentRevision: UInt64
        var lastBackupRevision: UInt64?
        var lastBackupAt: Date?
        var lastBackupItemCount: Int?

        init(
            version: Int,
            items: [Record],
            contentRevision: UInt64 = 0,
            lastBackupRevision: UInt64? = nil,
            lastBackupAt: Date? = nil,
            lastBackupItemCount: Int? = nil
        ) {
            self.version = version
            self.items = items
            self.contentRevision = contentRevision
            self.lastBackupRevision = lastBackupRevision
            self.lastBackupAt = lastBackupAt
            self.lastBackupItemCount = lastBackupItemCount
        }

        private enum CodingKeys: String, CodingKey {
            case version
            case items
            case contentRevision
            case lastBackupRevision
            case lastBackupAt
            case lastBackupItemCount
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            version = try values.decode(Int.self, forKey: .version)
            items = try values.decode([Record].self, forKey: .items)
            contentRevision = try values.decodeIfPresent(UInt64.self, forKey: .contentRevision) ?? 0
            lastBackupRevision = try values.decodeIfPresent(UInt64.self, forKey: .lastBackupRevision)
            lastBackupAt = try values.decodeIfPresent(Date.self, forKey: .lastBackupAt)
            lastBackupItemCount = try values.decodeIfPresent(Int.self, forKey: .lastBackupItemCount)
        }
    }

    private struct BackupManifest: Codable, Sendable {
        let version: Int
        let vaultVersion: Int
        let createdAt: Date
        let contentRevision: UInt64
        let itemCount: Int
    }

    private struct Journal: Codable, Sendable {
        let version: Int
        let record: Record
        let stagingName: String
        let finalName: String
    }

    private struct PendingSetup: Sendable {
        let header: Header
        var key: Data
        let code: String
    }

    private struct PendingRestore: Sendable {
        let id: UUID
        let stagingURL: URL
        let recoveryCode: String
        var key: Data
    }

    private let rootURL: URL
    private var vaultKey: Data?
    private var records: [Record] = []
    private var currentIndex = Index(version: 2, items: [])
    private var pendingSetup: PendingSetup?
    private var pendingRestore: PendingRestore?
    private var simulatedFailurePoint: VaultTransactionFailurePoint?

    private var headerURL: URL { rootURL.appendingPathComponent("vault.header") }
    private var indexURL: URL { rootURL.appendingPathComponent("vault.index") }
    private var journalURL: URL { rootURL.appendingPathComponent("transaction.journal") }
    private var itemsURL: URL { rootURL.appendingPathComponent("items", isDirectory: true) }
    private var stagingURL: URL { rootURL.appendingPathComponent("staging", isDirectory: true) }
    private let chunkSize = VaultChunkFormat.chunkSize

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func prepareVault(passphrase: String) throws -> String {
        guard !FileManager.default.fileExists(atPath: headerURL.path), pendingSetup == nil else {
            throw VaultError.cofreJaConfigurado
        }
        var code = try VaultCrypto.recoveryCode()
        let key = try VaultCrypto.randomBytes(count: VaultCrypto.keyLength)
        let passwordSalt = try VaultCrypto.randomBytes(count: VaultCrypto.passwordSaltLength)
        let recoverySalt = try VaultCrypto.randomBytes(count: VaultCrypto.recoverySaltLength)
        var masterKey = try VaultCrypto.deriveMasterKey(passphrase: passphrase, salt: passwordSalt)
        defer { masterKey.resetBytes(in: 0..<masterKey.count) }
        var recoveryKey = try VaultCrypto.deriveRecoveryKey(secret: code.secret, salt: recoverySalt)
        defer {
            recoveryKey.resetBytes(in: 0..<recoveryKey.count)
            code.secret.resetBytes(in: 0..<code.secret.count)
        }
        let header = Header(
            version: 1,
            kdf: "argon2id13",
            kdfVersion: 19,
            operations: VaultCrypto.argonOperations,
            memoryBytes: VaultCrypto.argonMemoryBytes,
            passwordSalt: passwordSalt,
            recoverySalt: recoverySalt,
            passwordEnvelope: try VaultCrypto.seal(key, key: masterKey, authenticating: Data("vox.header.password.v1".utf8)),
            recoveryEnvelope: try VaultCrypto.seal(key, key: recoveryKey, authenticating: Data("vox.header.recovery.v1".utf8)),
            credentialType: PadraoDesbloqueio.tipo(de: passphrase).rawValue
        )
        pendingSetup = PendingSetup(header: header, key: key, code: code.display)
        return code.display
    }

    func confirmSetup(code: String) throws {
        guard let pendingSetup else { throw VaultError.confirmacaoInvalida }
        let entered = Self.normalizeRecoveryCode(code)
        let full = Self.normalizeRecoveryCode(pendingSetup.code)
        guard entered == full || entered == String(full.suffix(8)) else {
            throw VaultError.confirmacaoInvalida
        }
        let parent = rootURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let setupURL = parent.appendingPathComponent(".vox-setup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: setupURL) }
        let setupItemsURL = setupURL.appendingPathComponent("items", isDirectory: true)
        let setupStagingURL = setupURL.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: setupItemsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: setupStagingURL, withIntermediateDirectories: true)
        try Self.writeJSON(pendingSetup.header, to: setupURL.appendingPathComponent("vault.header"))
        let initialIndex = Index(version: 2, items: [])
        try writeIndex(initialIndex, key: pendingSetup.key, to: setupURL.appendingPathComponent("vault.index"))
        try Self.applyDataProtection(to: setupURL)
        try FileManager.default.moveItem(at: setupURL, to: rootURL)
        self.vaultKey = pendingSetup.key
        self.records = []
        self.currentIndex = initialIndex
        self.pendingSetup = nil
    }

    func cancelPendingSetup() {
        if let count = pendingSetup?.key.count {
            pendingSetup?.key.resetBytes(in: 0..<count)
        }
        pendingSetup = nil
    }

    private func cancelPendingRestore() {
        guard var pending = pendingRestore else { return }
        pending.key.resetBytes(in: 0..<pending.key.count)
        pendingRestore = nil
        try? FileManager.default.removeItem(at: pending.stagingURL)
    }

    func unlock(passphrase: String) throws -> [ItemDoCofre] {
        let header = try readHeader()
        try validateKDF(header)
        var master = try VaultCrypto.deriveMasterKey(passphrase: passphrase, salt: header.passwordSalt)
        defer { master.resetBytes(in: 0..<master.count) }
        let key: Data
        do {
            key = try VaultCrypto.open(header.passwordEnvelope, key: master, authenticating: Data("vox.header.password.v1".utf8))
        } catch {
            throw VaultError.credencialIncorreta
        }
        try openIndexAndRecover(with: key)
        vaultKey = key
        return records.map(\.item)
    }

    func recover(code: String, newPassphrase: String, confirmation: String) throws -> [ItemDoCofre] {
        try validarPassphrase(newPassphrase)
        guard newPassphrase == confirmation else { throw VaultError.credenciaisNaoCoincidem }
        guard var secret = VaultCrypto.recoverySecret(from: code) else { throw VaultError.codigoRecuperacaoInvalido }
        defer { secret.resetBytes(in: 0..<secret.count) }
        var header = try readHeader()
        var recoveryKey = try VaultCrypto.deriveRecoveryKey(secret: secret, salt: header.recoverySalt)
        defer { recoveryKey.resetBytes(in: 0..<recoveryKey.count) }
        let key: Data
        do {
            key = try VaultCrypto.open(header.recoveryEnvelope, key: recoveryKey, authenticating: Data("vox.header.recovery.v1".utf8))
        } catch {
            throw VaultError.codigoRecuperacaoInvalido
        }
        let newSalt = try VaultCrypto.randomBytes(count: VaultCrypto.passwordSaltLength)
        var newMaster = try VaultCrypto.deriveMasterKey(passphrase: newPassphrase, salt: newSalt)
        defer { newMaster.resetBytes(in: 0..<newMaster.count) }
        try openIndexAndRecover(with: key)
        header.passwordSalt = newSalt
        header.passwordEnvelope = try VaultCrypto.seal(key, key: newMaster, authenticating: Data("vox.header.password.v1".utf8))
        header.credentialType = PadraoDesbloqueio.tipo(de: newPassphrase).rawValue
        try Self.writeJSON(header, to: headerURL)
        vaultKey = key
        return records.map(\.item)
    }

    func lock() {
        if let count = vaultKey?.count {
            vaultKey?.resetBytes(in: 0..<count)
            vaultKey = nil
        }
        records.removeAll(keepingCapacity: false)
        currentIndex = Index(version: 2, items: [])
        cancelPendingRestore()
    }

    func importFile(
        at sourceURL: URL,
        name: String,
        mediaType: TipoDeMidia,
        duration: Double? = nil,
        syntheticColor: String = "#087D70"
    ) throws -> ItemDoCofre {
        guard let key = vaultKey else { throw VaultError.cofreBloqueado }
        let id = UUID()
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let sourceSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        try ensureSpace(for: sourceSize)

        var dataKey = try VaultCrypto.randomBytes(count: VaultCrypto.keyLength)
        defer { dataKey.resetBytes(in: 0..<dataKey.count) }
        let noncePrefix = try VaultCrypto.randomBytes(count: 4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let wrappedKey = try VaultCrypto.seal(dataKey, key: key, authenticating: Self.itemKeyAAD(id))
        let stagingName = "\(id.uuidString).stage"
        let finalName = "\(id.uuidString).enc"
        let stagingFile = stagingURL.appendingPathComponent(stagingName)
        let finalFile = itemsURL.appendingPathComponent(finalName)
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: itemsURL, withIntermediateDirectories: true)

        do {
            let written = try encryptFile(at: sourceURL, to: stagingFile, key: dataKey, id: id, noncePrefix: noncePrefix)
            guard written.bytes == sourceSize else { throw VaultError.dadoAdulterado }
            let record = Record(
                id: id,
                name: name,
                mediaType: mediaType,
                size: written.bytes,
                createdAt: Date(),
                duration: duration,
                syntheticColor: syntheticColor,
                noncePrefix: noncePrefix,
                chunkCount: written.chunks,
                wrappedDataKey: wrappedKey
            )
            try verifyFile(at: stagingFile, record: record, key: dataKey)
            try injectFailureIfRequested(.afterStagingVerification)
            let journal = Journal(version: 1, record: record, stagingName: stagingName, finalName: finalName)
            let journalData = try Self.encode(journal)
            let sealedJournal = try VaultCrypto.seal(journalData, key: key, authenticating: Data("vox.journal.v1".utf8))
            try Self.writeJSON(sealedJournal, to: journalURL)
            try injectFailureIfRequested(.afterJournal)
            try FileManager.default.moveItem(at: stagingFile, to: finalFile)
            try injectFailureIfRequested(.afterFileMove)
            let revision = try nextContentRevision()
            var updatedIndex = currentIndex
            updatedIndex.version = 2
            updatedIndex.items = records + [record]
            updatedIndex.contentRevision = revision
            try writeIndex(updatedIndex, key: key, to: indexURL)
            currentIndex = updatedIndex
            records = updatedIndex.items
            try injectFailureIfRequested(.afterIndexWrite)
            try? FileManager.default.removeItem(at: journalURL)
            return ItemDoCofre(
                id: id,
                nomeOriginal: name,
                tipo: mediaType,
                tamanhoBytes: written.bytes,
                dataCriacao: record.createdAt,
                duracaoSegundos: duration,
                status: .pendenteBackup,
                corSinteticaHex: syntheticColor
            )
        } catch {
            // Once the encrypted journal exists, leave artifacts for unlock-time recovery.
            if !FileManager.default.fileExists(atPath: journalURL.path) {
                try? FileManager.default.removeItem(at: stagingFile)
            }
            throw error
        }
    }

    func deleteItem(id: UUID) throws {
        guard let key = vaultKey else { throw VaultError.cofreBloqueado }
        guard let index = records.firstIndex(where: { $0.id == id }) else { throw VaultError.itemNaoEncontrado }
        var updatedIndex = currentIndex
        let record = updatedIndex.items.remove(at: index)
        updatedIndex.version = 2
        updatedIndex.contentRevision = try nextContentRevision()
        try writeIndex(updatedIndex, key: key, to: indexURL)
        currentIndex = updatedIndex
        records = updatedIndex.items
        do {
            try FileManager.default.removeItem(at: itemURL(for: record))
        } catch {
            // The catalog commit is authoritative; unlock-time orphan cleanup can retry.
            throw VaultError.falhaNaLimpezaDaExclusao
        }
    }

    func prepareBackup(stagingRoot: URL) throws -> BackupPreparado {
        guard let key = vaultKey else { throw VaultError.cofreBloqueado }
        guard !FileManager.default.fileExists(atPath: journalURL.path) else {
            throw VaultError.operacaoInterrompida
        }
        let backupID = UUID()
        let packageURL = stagingRoot.appendingPathComponent("\(backupID.uuidString).voxbackup", isDirectory: true)
        let itemsDirectory = packageURL.appendingPathComponent("items", isDirectory: true)
        do {
            let approximateEncryptedSize = try encryptedContentSize()
            try ensureSpace(for: approximateEncryptedSize)
            try FileManager.default.createDirectory(at: itemsDirectory, withIntermediateDirectories: true)
            try VaultTemporaryStorageProtection.apply(to: packageURL)
            try VaultTemporaryStorageProtection.apply(to: itemsDirectory)
            try FileManager.default.copyItem(at: headerURL, to: packageURL.appendingPathComponent("vault.header"))
            try VaultTemporaryStorageProtection.apply(to: packageURL.appendingPathComponent("vault.header"))
            let snapshotDate = Date()
            var snapshotIndex = currentIndex
            snapshotIndex.version = 2
            snapshotIndex.lastBackupRevision = snapshotIndex.contentRevision
            snapshotIndex.lastBackupAt = snapshotDate
            snapshotIndex.lastBackupItemCount = snapshotIndex.items.count
            try writeIndex(snapshotIndex, key: key, to: packageURL.appendingPathComponent("vault.index"))

            for record in currentIndex.items {
                try Task.checkCancellation()
                let source = itemURL(for: record)
                let destination = itemsDirectory.appendingPathComponent("\(record.id.uuidString).enc")
                try copyFileInChunks(from: source, to: destination)
                try VaultTemporaryStorageProtection.apply(to: destination)
            }

            let manifest = BackupManifest(
                version: 1,
                vaultVersion: 1,
                createdAt: snapshotDate,
                contentRevision: snapshotIndex.contentRevision,
                itemCount: snapshotIndex.items.count
            )
            let manifestData = try Self.encode(manifest)
            let sealedManifest = try VaultCrypto.seal(
                manifestData,
                key: key,
                authenticating: Data("vox.backup.manifest.v1".utf8)
            )
            try Self.writeJSON(sealedManifest, to: packageURL.appendingPathComponent("backup.manifest"))

            let summary = try validateBackupPackage(at: packageURL, key: key)
            return BackupPreparado(id: backupID, url: packageURL, resumo: summary)
        } catch {
            try? FileManager.default.removeItem(at: packageURL)
            throw Self.backupError(error)
        }
    }

    func verifyBackup(at packageURL: URL, recoveryCode: String) throws -> ResumoBackup {
        guard var secret = VaultCrypto.recoverySecret(from: recoveryCode) else {
            throw VaultError.codigoRecuperacaoInvalido
        }
        defer { secret.resetBytes(in: 0..<secret.count) }
        do {
            return try coordinatedRead(at: packageURL) { coordinatedURL in
                let header = try readHeader(at: coordinatedURL.appendingPathComponent("vault.header"))
                try validateKDF(header)
                var recoveryKey = try VaultCrypto.deriveRecoveryKey(secret: secret, salt: header.recoverySalt)
                defer { recoveryKey.resetBytes(in: 0..<recoveryKey.count) }
                var key: Data
                do {
                    key = try VaultCrypto.open(
                        header.recoveryEnvelope,
                        key: recoveryKey,
                        authenticating: Data("vox.header.recovery.v1".utf8)
                    )
                } catch {
                    throw VaultError.codigoRecuperacaoInvalido
                }
                defer { key.resetBytes(in: 0..<key.count) }
                return try validateBackupPackage(at: coordinatedURL, key: key)
            }
        } catch {
            throw Self.backupError(error)
        }
    }

    func backupState() -> EstadoBackup {
        if let checkpoint = currentIndex.lastBackupRevision,
           checkpoint == currentIndex.contentRevision,
           let date = currentIndex.lastBackupAt {
            return .atualizado(data: date, contagemItens: currentIndex.lastBackupItemCount ?? records.count)
        }
        if currentIndex.items.isEmpty, currentIndex.lastBackupAt == nil {
            return .nuncaCriado
        }
        let previousCount = currentIndex.lastBackupItemCount ?? 0
        let pending = max(1, abs(records.count - previousCount))
        return .desatualizado(dataUltimo: currentIndex.lastBackupAt, itensPendentes: pending)
    }

    func confirmBackupExported(revision: UInt64, date: Date, itemCount: Int) throws {
        guard let key = vaultKey else { throw VaultError.cofreBloqueado }
        guard revision <= currentIndex.contentRevision, itemCount >= 0 else { throw VaultError.dadoAdulterado }
        var updatedIndex = currentIndex
        updatedIndex.lastBackupRevision = revision
        updatedIndex.lastBackupAt = date
        updatedIndex.lastBackupItemCount = itemCount
        try writeIndex(updatedIndex, key: key, to: indexURL)
        currentIndex = updatedIndex
        records = updatedIndex.items
    }

    func prepareRestore(
        from packageURL: URL,
        recoveryCode: String,
        newPassphrase: String,
        confirmation: String
    ) throws -> RestauracaoPreparada {
        guard pendingRestore == nil else { throw VaultError.operacaoInterrompida }
        guard !FileManager.default.fileExists(atPath: rootURL.path) else { throw VaultError.cofreNaoVazioParaRestauracao }
        try validarPassphrase(newPassphrase)
        guard newPassphrase == confirmation else { throw VaultError.credenciaisNaoCoincidem }
        guard var secret = VaultCrypto.recoverySecret(from: recoveryCode) else { throw VaultError.codigoRecuperacaoInvalido }
        defer { secret.resetBytes(in: 0..<secret.count) }

        let restoreID = UUID()
        let parentURL = rootURL.deletingLastPathComponent()
        let stagingURL = parentURL.appendingPathComponent(".vox-restore-\(restoreID.uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
            let prepared = try coordinatedRead(at: packageURL) { coordinatedURL -> RestauracaoPreparada in
                let originalHeader = try readHeader(at: coordinatedURL.appendingPathComponent("vault.header"))
                try validateKDF(originalHeader)
                var recoveryKey = try VaultCrypto.deriveRecoveryKey(secret: secret, salt: originalHeader.recoverySalt)
                defer { recoveryKey.resetBytes(in: 0..<recoveryKey.count) }
                var key: Data
                do {
                    key = try VaultCrypto.open(
                        originalHeader.recoveryEnvelope,
                        key: recoveryKey,
                        authenticating: Data("vox.header.recovery.v1".utf8)
                    )
                } catch {
                    throw VaultError.codigoRecuperacaoInvalido
                }
                defer { key.resetBytes(in: 0..<key.count) }

                let summary = try validateBackupPackage(at: coordinatedURL, key: key)
                var newCode = try VaultCrypto.recoveryCode()
                defer { newCode.secret.resetBytes(in: 0..<newCode.secret.count) }
                let passwordSalt = try VaultCrypto.randomBytes(count: VaultCrypto.passwordSaltLength)
                let recoverySalt = try VaultCrypto.randomBytes(count: VaultCrypto.recoverySaltLength)
                var masterKey = try VaultCrypto.deriveMasterKey(passphrase: newPassphrase, salt: passwordSalt)
                defer { masterKey.resetBytes(in: 0..<masterKey.count) }
                var newRecoveryKey = try VaultCrypto.deriveRecoveryKey(secret: newCode.secret, salt: recoverySalt)
                defer { newRecoveryKey.resetBytes(in: 0..<newRecoveryKey.count) }

                var restoredHeader = originalHeader
                restoredHeader.passwordSalt = passwordSalt
                restoredHeader.recoverySalt = recoverySalt
                restoredHeader.passwordEnvelope = try VaultCrypto.seal(
                    key,
                    key: masterKey,
                    authenticating: Data("vox.header.password.v1".utf8)
                )
                restoredHeader.recoveryEnvelope = try VaultCrypto.seal(
                    key,
                    key: newRecoveryKey,
                    authenticating: Data("vox.header.recovery.v1".utf8)
                )
                restoredHeader.credentialType = PadraoDesbloqueio.tipo(de: newPassphrase).rawValue

                try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: stagingURL.appendingPathComponent("items", isDirectory: true), withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: stagingURL.appendingPathComponent("staging", isDirectory: true), withIntermediateDirectories: true)
                try Self.writeJSON(restoredHeader, to: stagingURL.appendingPathComponent("vault.header"))
                try copyFileInChunks(
                    from: coordinatedURL.appendingPathComponent("vault.index"),
                    to: stagingURL.appendingPathComponent("vault.index")
                )
                try Self.applyDataProtection(to: stagingURL.appendingPathComponent("vault.index"))
                let sourceItems = coordinatedURL.appendingPathComponent("items", isDirectory: true)
                let destinationItems = stagingURL.appendingPathComponent("items", isDirectory: true)
                for record in try readIndex(key: key, from: coordinatedURL.appendingPathComponent("vault.index")).items {
                    try Task.checkCancellation()
                    try copyFileInChunks(
                        from: sourceItems.appendingPathComponent("\(record.id.uuidString).enc"),
                        to: destinationItems.appendingPathComponent("\(record.id.uuidString).enc")
                    )
                    try Self.applyDataProtection(to: destinationItems.appendingPathComponent("\(record.id.uuidString).enc"))
                }
                try Self.applyDataProtection(to: destinationItems)
                try Self.applyDataProtection(to: stagingURL.appendingPathComponent("staging", isDirectory: true))
                try Self.applyDataProtection(to: stagingURL)
                _ = try validateRestoredDirectory(at: stagingURL, key: key)

                pendingRestore = PendingRestore(
                    id: restoreID,
                    stagingURL: stagingURL,
                    recoveryCode: newCode.display,
                    key: key
                )
                return RestauracaoPreparada(id: restoreID, codigoRecuperacao: newCode.display, resumo: summary)
            }
            return prepared
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            throw Self.backupError(error)
        }
    }

    func confirmRestore(id: UUID, recoveryCodeConfirmation: String) throws -> [ItemDoCofre] {
        try Task.checkCancellation()
        guard let pendingRestore, pendingRestore.id == id else { throw VaultError.operacaoInterrompida }
        let entered = Self.normalizeRecoveryCode(recoveryCodeConfirmation)
        let full = Self.normalizeRecoveryCode(pendingRestore.recoveryCode)
        guard entered == full || entered == String(full.suffix(8)) else { throw VaultError.confirmacaoInvalida }
        guard !FileManager.default.fileExists(atPath: rootURL.path) else { throw VaultError.cofreNaoVazioParaRestauracao }

        let restoredIndex = try validateRestoredDirectory(at: pendingRestore.stagingURL, key: pendingRestore.key)
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: pendingRestore.stagingURL, to: rootURL)
        var restoredKey = pendingRestore.key
        vaultKey = restoredKey
        currentIndex = restoredIndex
        records = restoredIndex.items
        restoredKey.resetBytes(in: 0..<restoredKey.count)
        var consumedRestore = pendingRestore
        consumedRestore.key.resetBytes(in: 0..<consumedRestore.key.count)
        self.pendingRestore = nil
        return records.map(\.item)
    }

    func cancelRestore(id: UUID) {
        guard pendingRestore?.id == id else { return }
        cancelPendingRestore()
    }

    func makeMediaReadSession(id: UUID) throws -> VaultMediaReadSession {
        guard let key = vaultKey else { throw VaultError.cofreBloqueado }
        guard let record = records.first(where: { $0.id == id }) else { throw VaultError.itemNaoEncontrado }
        var dataKey = try VaultCrypto.open(record.wrappedDataKey, key: key, authenticating: Self.itemKeyAAD(record.id))
        defer { dataKey.resetBytes(in: 0..<dataKey.count) }
        return try VaultMediaReadSession(
            encryptedURL: itemURL(for: record),
            item: record.item,
            noncePrefix: record.noncePrefix,
            chunkCount: record.chunkCount,
            dataKey: dataKey
        )
    }

    func eraseVault() throws {
        lock()
        pendingSetup = nil
        try? FileManager.default.removeItem(at: rootURL)
    }

    func setSimulatedFailure(_ point: VaultTransactionFailurePoint?) {
        simulatedFailurePoint = point
    }

    // MARK: - Startup and journal recovery

    private func openIndexAndRecover(with key: Data) throws {
        do {
            currentIndex = try readIndex(key: key)
            records = currentIndex.items
        } catch {
            throw VaultError.dadoAdulterado
        }

        if FileManager.default.fileExists(atPath: journalURL.path) {
            do {
                let sealed = try Self.readJSON(VaultCrypto.SealedValue.self, from: journalURL)
                let plaintext = try VaultCrypto.open(sealed, key: key, authenticating: Data("vox.journal.v1".utf8))
                let journal = try JSONDecoder().decode(Journal.self, from: plaintext)
                guard journal.version == 1,
                      journal.stagingName == "\(journal.record.id.uuidString).stage",
                      journal.finalName == "\(journal.record.id.uuidString).enc" else {
                    throw VaultError.dadoAdulterado
                }

                if records.contains(where: { $0.id == journal.record.id }) {
                    try? FileManager.default.removeItem(at: stagingURL.appendingPathComponent(journal.stagingName))
                    try? FileManager.default.removeItem(at: journalURL)
                } else {
                    let stage = stagingURL.appendingPathComponent(journal.stagingName)
                    let final = itemsURL.appendingPathComponent(journal.finalName)
                    let wrapped = try VaultCrypto.open(journal.record.wrappedDataKey, key: key, authenticating: Self.itemKeyAAD(journal.record.id))
                    let source = FileManager.default.fileExists(atPath: final.path) ? final : stage
                    try verifyFile(at: source, record: journal.record, key: wrapped)
                    if source == stage { try FileManager.default.moveItem(at: stage, to: final) }
                    var recoveredIndex = currentIndex
                    recoveredIndex.version = 2
                    recoveredIndex.items.append(journal.record)
                    recoveredIndex.contentRevision = try nextContentRevision()
                    try writeIndex(recoveredIndex, key: key, to: indexURL)
                    currentIndex = recoveredIndex
                    records = recoveredIndex.items
                    try? FileManager.default.removeItem(at: journalURL)
                }
            } catch {
                throw VaultError.dadoAdulterado
            }
        }

        try removeOrphans()
        for record in records {
            do {
                let wrapped = try VaultCrypto.open(record.wrappedDataKey, key: key, authenticating: Self.itemKeyAAD(record.id))
                try verifyFile(at: itemURL(for: record), record: record, key: wrapped)
            } catch {
                throw VaultError.dadoAdulterado
            }
        }
    }

    private func removeOrphans() throws {
        let known = Set(records.map { "\($0.id.uuidString).enc" })
        if FileManager.default.fileExists(atPath: itemsURL.path) {
            for url in try FileManager.default.contentsOfDirectory(at: itemsURL, includingPropertiesForKeys: nil) {
                if !known.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at: url) }
            }
        }
        if FileManager.default.fileExists(atPath: stagingURL.path) {
            for url in try FileManager.default.contentsOfDirectory(at: stagingURL, includingPropertiesForKeys: nil) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Chunked authenticated file format

    private func encryptFile(at sourceURL: URL, to destinationURL: URL, key: Data, id: UUID, noncePrefix: UInt32) throws -> (bytes: Int64, chunks: UInt64) {
        _ = FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        try Self.applyDataProtection(to: destinationURL)
        let input = try FileHandle(forReadingFrom: sourceURL)
        let output = try FileHandle(forWritingTo: destinationURL)
        defer { try? input.close(); try? output.close() }
        var total: Int64 = 0
        var counter: UInt64 = 0
        while let bytes = try input.read(upToCount: chunkSize), !bytes.isEmpty {
            try writeChunk(bytes, counter: counter, noncePrefix: noncePrefix, id: id, key: key, to: output)
            total += Int64(bytes.count)
            counter += 1
        }
        try output.synchronize()
        return (total, counter)
    }

    private func verifyFile(at url: URL, record: Record, key: Data) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var total: Int64 = 0
        var counter: UInt64 = 0
        while let lengthBytes = try file.read(upToCount: 4), !lengthBytes.isEmpty {
            try Task.checkCancellation()
            guard lengthBytes.count == 4 else { throw VaultError.dadoAdulterado }
            let length = lengthBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length <= chunkSize else { throw VaultError.dadoAdulterado }
            guard let authenticatedBytes = try file.read(upToCount: Int(length) + 16), authenticatedBytes.count == Int(length) + 16 else {
                throw VaultError.dadoAdulterado
            }
            let ciphertext = authenticatedBytes.prefix(Int(length))
            let tag = authenticatedBytes.suffix(16)
            let nonce = VaultChunkFormat.nonce(prefix: record.noncePrefix, counter: counter)
            let box = VaultCrypto.SealedValue(nonce: nonce, ciphertext: Data(ciphertext), tag: Data(tag))
            let plaintext = try VaultCrypto.open(box, key: key, authenticating: VaultChunkFormat.aad(id: record.id, counter: counter, length: length))
            guard plaintext.count == Int(length) else { throw VaultError.dadoAdulterado }
            total += Int64(plaintext.count)
            counter += 1
        }
        guard total == record.size, counter == record.chunkCount else { throw VaultError.dadoAdulterado }
    }

    private func writeChunk(_ bytes: Data, counter: UInt64, noncePrefix: UInt32, id: UUID, key: Data, to output: FileHandle) throws {
        let length = UInt32(bytes.count)
        let nonceData = VaultChunkFormat.nonce(prefix: noncePrefix, counter: counter)
        let sealed = try VaultCrypto.sealWithNonce(
            bytes,
            key: key,
            nonce: nonceData,
            authenticating: VaultChunkFormat.aad(id: id, counter: counter, length: length)
        )
        var header = length.bigEndian
        let headerData = withUnsafeBytes(of: &header) { Data($0) }
        try output.write(contentsOf: headerData)
        try output.write(contentsOf: sealed.ciphertext)
        try output.write(contentsOf: sealed.tag)
    }

    func obterTipoCredencial() -> TipoCredencial {
        guard let header = try? readHeader() else { return .texto }
        if let typeStr = header.credentialType, let tipo = TipoCredencial(rawValue: typeStr) {
            return tipo
        }
        return .texto
    }

    private func validarPassphrase(_ passphrase: String) throws {
        if PadraoDesbloqueio.ehPadrao(credencial: passphrase) {
            guard let pontos = PadraoDesbloqueio.deserializar(credencial: passphrase),
                  pontos.count >= PadraoDesbloqueio.minimoPontos else {
                throw VaultError.padraoMuitoCurto
            }
        } else {
            guard passphrase.count >= 12 else {
                throw VaultError.credencialMuitoCurta
            }
        }
    }

    private func readHeader() throws -> Header {
        try readHeader(at: headerURL)
    }

    private func readHeader(at url: URL) throws -> Header {
        do {
            let header = try Self.readJSON(Header.self, from: url)
            guard header.version == 1 else { throw VaultError.formatoCofreIncompativel }
            return header
        } catch let error as VaultError { throw error }
        catch { throw VaultError.formatoCofreIncompativel }
    }

    private func validateKDF(_ header: Header) throws {
        guard header.kdf == "argon2id13", header.kdfVersion == 19,
              header.operations == VaultCrypto.argonOperations,
              header.memoryBytes == VaultCrypto.argonMemoryBytes else {
            throw VaultError.formatoCofreIncompativel
        }
    }

    private func validateBackupPackage(at packageURL: URL, key: Data) throws -> ResumoBackup {
        let fileManager = FileManager.default
        let rootValues = try packageURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard packageURL.pathExtension == "voxbackup",
              rootValues.isDirectory == true,
              rootValues.isSymbolicLink != true else {
            throw VaultError.dadoAdulterado
        }

        let rootEntries = try fileManager.contentsOfDirectory(at: packageURL, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard Set(rootEntries.map(\.lastPathComponent)) == ["backup.manifest", "items", "vault.header", "vault.index"] else {
            throw VaultError.dadoAdulterado
        }
        let headerURL = packageURL.appendingPathComponent("vault.header")
        let indexURL = packageURL.appendingPathComponent("vault.index")
        let manifestURL = packageURL.appendingPathComponent("backup.manifest")
        let itemsURL = packageURL.appendingPathComponent("items", isDirectory: true)
        for fileURL in [headerURL, indexURL, manifestURL] {
            guard Self.isRegularNonSymlink(fileURL) else { throw VaultError.dadoAdulterado }
        }
        let itemsValues = try itemsURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard itemsValues.isDirectory == true, itemsValues.isSymbolicLink != true else {
            throw VaultError.dadoAdulterado
        }

        let header = try readHeader(at: headerURL)
        try validateKDF(header)
        let index = try readIndex(key: key, from: indexURL)
        let sealedManifest = try Self.readJSON(VaultCrypto.SealedValue.self, from: manifestURL)
        let manifestBytes: Data
        do {
            manifestBytes = try VaultCrypto.open(
                sealedManifest,
                key: key,
                authenticating: Data("vox.backup.manifest.v1".utf8)
            )
        } catch {
            throw VaultError.dadoAdulterado
        }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestBytes)
        guard manifest.version == 1,
              manifest.vaultVersion == 1,
              manifest.itemCount == index.items.count,
              manifest.contentRevision == index.contentRevision else {
            throw VaultError.formatoCofreIncompativel
        }

        let itemFiles = try fileManager.contentsOfDirectory(
            at: itemsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        let expectedNames = Set(index.items.map { "\($0.id.uuidString).enc" })
        guard Set(itemFiles.map(\.lastPathComponent)) == expectedNames,
              itemFiles.allSatisfy(Self.isRegularNonSymlink) else {
            throw VaultError.dadoAdulterado
        }

        for record in index.items {
            let encryptedURL = itemsURL.appendingPathComponent("\(record.id.uuidString).enc")
            var dataKey: Data
            do {
                dataKey = try VaultCrypto.open(
                    record.wrappedDataKey,
                    key: key,
                    authenticating: Self.itemKeyAAD(record.id)
                )
            } catch {
                throw VaultError.dadoAdulterado
            }
            defer { dataKey.resetBytes(in: 0..<dataKey.count) }
            try verifyFile(at: encryptedURL, record: record, key: dataKey)
        }

        return ResumoBackup(
            dataCriacao: manifest.createdAt,
            contagemItens: manifest.itemCount,
            tamanhoBytes: try Self.directorySize(at: packageURL),
            revisaoConteudo: manifest.contentRevision
        )
    }

    private func encryptedContentSize() throws -> Int64 {
        try currentIndex.items.reduce(Int64(0)) { total, record in
            let (overhead, overheadOverflow) = Int64(record.chunkCount).multipliedReportingOverflow(by: 20)
            let (itemSize, itemOverflow) = record.size.addingReportingOverflow(overhead)
            let (newTotal, totalOverflow) = total.addingReportingOverflow(itemSize)
            guard !overheadOverflow, !itemOverflow, !totalOverflow else { throw VaultError.dadoAdulterado }
            return newTotal
        }
    }

    private func validateRestoredDirectory(at directoryURL: URL, key: Data) throws -> Index {
        let expectedRootNames: Set<String> = ["items", "staging", "vault.header", "vault.index"]
        let rootNames = Set(try FileManager.default.contentsOfDirectory(atPath: directoryURL.path))
        guard rootNames == expectedRootNames else { throw VaultError.dadoAdulterado }
        guard Self.isRegularNonSymlink(directoryURL.appendingPathComponent("vault.header")),
              Self.isRegularNonSymlink(directoryURL.appendingPathComponent("vault.index")) else {
            throw VaultError.dadoAdulterado
        }
        let header = try readHeader(at: directoryURL.appendingPathComponent("vault.header"))
        try validateKDF(header)

        let itemsURL = directoryURL.appendingPathComponent("items", isDirectory: true)
        let itemsValues = try itemsURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard itemsValues.isDirectory == true, itemsValues.isSymbolicLink != true else { throw VaultError.dadoAdulterado }
        let index = try readIndex(key: key, from: directoryURL.appendingPathComponent("vault.index"))
        let itemFiles = try FileManager.default.contentsOfDirectory(
            at: itemsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        let expectedItemNames = Set(index.items.map { "\($0.id.uuidString).enc" })
        guard Set(itemFiles.map(\.lastPathComponent)) == expectedItemNames,
              itemFiles.allSatisfy(Self.isRegularNonSymlink) else {
            throw VaultError.dadoAdulterado
        }
        for record in index.items {
            var dataKey: Data
            do {
                dataKey = try VaultCrypto.open(
                    record.wrappedDataKey,
                    key: key,
                    authenticating: Self.itemKeyAAD(record.id)
                )
            } catch {
                throw VaultError.dadoAdulterado
            }
            defer { dataKey.resetBytes(in: 0..<dataKey.count) }
            try verifyFile(
                at: itemsURL.appendingPathComponent("\(record.id.uuidString).enc"),
                record: record,
                key: dataKey
            )
        }
        return index
    }

    private func coordinatedRead<T>(at url: URL, body: (URL) throws -> T) throws -> T {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

        var coordinatedResult: Result<T, Error>?
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: url,
            options: .withoutChanges,
            error: &coordinationError
        ) { coordinatedURL in
            coordinatedResult = Result { try body(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let coordinatedResult else { throw VaultError.falhaNoBackup }
        return try coordinatedResult.get()
    }

    private func copyFileInChunks(from sourceURL: URL, to destinationURL: URL) throws {
        guard Self.isRegularNonSymlink(sourceURL) else { throw VaultError.dadoAdulterado }
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: destinationURL.path, contents: nil) else {
            throw VaultError.falhaNoBackup
        }
        try Self.applyDataProtection(to: destinationURL)
        let input = try FileHandle(forReadingFrom: sourceURL)
        let output = try FileHandle(forWritingTo: destinationURL)
        defer { try? input.close(); try? output.close() }
        while let bytes = try input.read(upToCount: chunkSize), !bytes.isEmpty {
            try Task.checkCancellation()
            try output.write(contentsOf: bytes)
        }
        try output.synchronize()
    }

    private static func isRegularNonSymlink(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func directorySize(at url: URL) throws -> Int64 {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        )
        guard let enumerator else { throw VaultError.dadoAdulterado }
        var total: Int64 = 0
        while let child = enumerator.nextObject() as? URL {
            let values = try child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw VaultError.dadoAdulterado }
            if values.isRegularFile == true {
                let (next, overflow) = total.addingReportingOverflow(Int64(values.fileSize ?? 0))
                guard !overflow else { throw VaultError.dadoAdulterado }
                total = next
            }
        }
        return total
    }

    private static func backupError(_ error: Error) -> VaultError {
        if let error = error as? VaultError { return error }
        if error is CancellationError { return .operacaoInterrompida }
        let nsError = error as NSError
        if nsError.code == NSFileWriteOutOfSpaceError ||
            (nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC)) {
            return .espacoInsuficiente
        }
        return .dadoAdulterado
    }

    private func readIndex(key: Data) throws -> Index {
        try readIndex(key: key, from: indexURL)
    }

    private func readIndex(key: Data, from url: URL) throws -> Index {
        let sealed = try Self.readJSON(VaultCrypto.SealedValue.self, from: url)
        let plaintext = try VaultCrypto.open(sealed, key: key, authenticating: Data("vox.index.v1".utf8))
        var index = try JSONDecoder().decode(Index.self, from: plaintext)
        guard index.version == 1 || index.version == 2 else { throw VaultError.formatoCofreIncompativel }
        index.version = 2
        return index
    }

    private func writeIndex(_ index: Index, key: Data, to url: URL) throws {
        let sealed = try VaultCrypto.seal(Self.encode(index), key: key, authenticating: Data("vox.index.v1".utf8))
        try Self.writeJSON(sealed, to: url)
    }

    private func nextContentRevision() throws -> UInt64 {
        let (next, overflow) = currentIndex.contentRevision.addingReportingOverflow(1)
        guard !overflow else { throw VaultError.dadoAdulterado }
        return next
    }

    private func ensureSpace(for fileSize: Int64) throws {
        guard fileSize >= 0,
              let fileSystem = try? FileManager.default.attributesOfFileSystem(forPath: rootURL.deletingLastPathComponent().path),
              let available = (fileSystem[.systemFreeSize] as? NSNumber)?.int64Value else { return }
        let (doubled, overflow) = fileSize.multipliedReportingOverflow(by: 2)
        let addition = doubled.addingReportingOverflow(16 * 1024 * 1024)
        let estimate = overflow || addition.overflow ? Int64.max : addition.partialValue
        guard estimate <= available else { throw VaultError.espacoInsuficiente }
    }

    private func injectFailureIfRequested(_ point: VaultTransactionFailurePoint) throws {
        if simulatedFailurePoint == point {
            simulatedFailurePoint = nil
            throw VaultError.operacaoInterrompida
        }
    }

    private func itemURL(for record: Record) -> URL {
        itemsURL.appendingPathComponent("\(record.id.uuidString).enc")
    }

    private static func itemKeyAAD(_ id: UUID) -> Data { Data("vox.item.key.v1.\(id.uuidString)".utf8) }

    private static func normalizeRecoveryCode(_ code: String) -> String {
        code.uppercased().filter(\.isHexDigit)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encode(value).write(to: url, options: .atomic)
        try applyDataProtection(to: url)
    }

    private static func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func applyDataProtection(to url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try? mutableURL.setResourceValues(values)
    }
}

private extension VaultCrypto {
    static func sealWithNonce(_ plaintext: Data, key: Data, nonce nonceData: Data, authenticating aad: Data) throws -> SealedValue {
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), nonce: nonce, authenticating: aad)
        return SealedValue(nonce: nonceData, ciphertext: sealed.ciphertext, tag: sealed.tag)
    }
}
