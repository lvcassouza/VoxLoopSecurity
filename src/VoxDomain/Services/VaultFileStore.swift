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

    private let rootURL: URL
    private var vaultKey: Data?
    private var records: [Record] = []
    private var pendingSetup: PendingSetup?
    private var simulatedFailurePoint: VaultTransactionFailurePoint?

    private var headerURL: URL { rootURL.appendingPathComponent("vault.header") }
    private var indexURL: URL { rootURL.appendingPathComponent("vault.index") }
    private var journalURL: URL { rootURL.appendingPathComponent("transaction.journal") }
    private var itemsURL: URL { rootURL.appendingPathComponent("items", isDirectory: true) }
    private var stagingURL: URL { rootURL.appendingPathComponent("staging", isDirectory: true) }
    private let chunkSize = 1_048_576

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
            recoveryEnvelope: try VaultCrypto.seal(key, key: recoveryKey, authenticating: Data("vox.header.recovery.v1".utf8))
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
        try writeIndex([], key: pendingSetup.key, to: setupURL.appendingPathComponent("vault.index"))
        try Self.applyDataProtection(to: setupURL)
        try FileManager.default.moveItem(at: setupURL, to: rootURL)
        self.vaultKey = pendingSetup.key
        self.records = []
        self.pendingSetup = nil
    }

    func cancelPendingSetup() {
        if let count = pendingSetup?.key.count {
            pendingSetup?.key.resetBytes(in: 0..<count)
        }
        pendingSetup = nil
    }

    func unlock(passphrase: String) throws -> [ItemDoCofre] {
        let header = try readHeader()
        guard header.kdf == "argon2id13", header.kdfVersion == 19,
              header.operations == VaultCrypto.argonOperations,
              header.memoryBytes == VaultCrypto.argonMemoryBytes else {
            throw VaultError.formatoCofreIncompativel
        }
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
        guard newPassphrase.count >= 12 else { throw VaultError.credencialMuitoCurta }
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
            try writeIndex(records + [record], key: key, to: indexURL)
            try injectFailureIfRequested(.afterIndexWrite)
            records.append(record)
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
        var updated = records
        let record = updated.remove(at: index)
        try writeIndex(updated, key: key, to: indexURL)
        records = updated
        try? FileManager.default.removeItem(at: itemURL(for: record))
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
            records = try readIndex(key: key).items
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
                    records.append(journal.record)
                    try writeIndex(records, key: key, to: indexURL)
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
            guard lengthBytes.count == 4 else { throw VaultError.dadoAdulterado }
            let length = lengthBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length <= chunkSize else { throw VaultError.dadoAdulterado }
            guard let authenticatedBytes = try file.read(upToCount: Int(length) + 16), authenticatedBytes.count == Int(length) + 16 else {
                throw VaultError.dadoAdulterado
            }
            let ciphertext = authenticatedBytes.prefix(Int(length))
            let tag = authenticatedBytes.suffix(16)
            let nonce = Self.chunkNonce(prefix: record.noncePrefix, counter: counter)
            let box = VaultCrypto.SealedValue(nonce: nonce, ciphertext: Data(ciphertext), tag: Data(tag))
            let plaintext = try VaultCrypto.open(box, key: key, authenticating: Self.chunkAAD(id: record.id, counter: counter, length: length))
            guard plaintext.count == Int(length) else { throw VaultError.dadoAdulterado }
            total += Int64(plaintext.count)
            counter += 1
        }
        guard total == record.size, counter == record.chunkCount else { throw VaultError.dadoAdulterado }
    }

    private func writeChunk(_ bytes: Data, counter: UInt64, noncePrefix: UInt32, id: UUID, key: Data, to output: FileHandle) throws {
        let length = UInt32(bytes.count)
        let nonceData = Self.chunkNonce(prefix: noncePrefix, counter: counter)
        let sealed = try VaultCrypto.sealWithNonce(
            bytes,
            key: key,
            nonce: nonceData,
            authenticating: Self.chunkAAD(id: id, counter: counter, length: length)
        )
        var header = length.bigEndian
        let headerData = withUnsafeBytes(of: &header) { Data($0) }
        try output.write(contentsOf: headerData)
        try output.write(contentsOf: sealed.ciphertext)
        try output.write(contentsOf: sealed.tag)
    }

    // MARK: - Encoded metadata and filesystem helpers

    private func readHeader() throws -> Header {
        do {
            let header = try Self.readJSON(Header.self, from: headerURL)
            guard header.version == 1 else { throw VaultError.formatoCofreIncompativel }
            return header
        } catch let error as VaultError { throw error }
        catch { throw VaultError.formatoCofreIncompativel }
    }

    private func readIndex(key: Data) throws -> Index {
        let sealed = try Self.readJSON(VaultCrypto.SealedValue.self, from: indexURL)
        let plaintext = try VaultCrypto.open(sealed, key: key, authenticating: Data("vox.index.v1".utf8))
        let index = try JSONDecoder().decode(Index.self, from: plaintext)
        guard index.version == 1 else { throw VaultError.formatoCofreIncompativel }
        return index
    }

    private func writeIndex(_ items: [Record], key: Data, to url: URL) throws {
        let index = Index(version: 1, items: items)
        let sealed = try VaultCrypto.seal(Self.encode(index), key: key, authenticating: Data("vox.index.v1".utf8))
        try Self.writeJSON(sealed, to: url)
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

    private static func chunkNonce(prefix: UInt32, counter: UInt64) -> Data {
        var prefix = prefix.bigEndian
        var counter = counter.bigEndian
        return withUnsafeBytes(of: &prefix) { p in
            withUnsafeBytes(of: &counter) { c in Data(p) + Data(c) }
        }
    }

    private static func chunkAAD(id: UUID, counter: UInt64, length: UInt32) -> Data {
        var counter = counter.bigEndian
        var length = length.bigEndian
        return Data("vox.chunk.v1.\(id.uuidString)".utf8)
            + withUnsafeBytes(of: &counter) { Data($0) }
            + withUnsafeBytes(of: &length) { Data($0) }
    }

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
