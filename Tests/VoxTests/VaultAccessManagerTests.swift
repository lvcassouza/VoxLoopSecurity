import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import VoxDomain
@testable import VoxUI

@MainActor
final class VaultAccessManagerTests: XCTestCase {
    private var manager: VaultAccessManager!
    private var vaultDirectory: URL!

    override func setUp() async throws {
        vaultDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxVaultTests-\(UUID().uuidString)", isDirectory: true)
        manager = VaultAccessManager(storageDirectory: vaultDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: vaultDirectory)
        manager = nil
    }

    func testSetupCodeAndCredentialValidation() async throws {
        do {
            let curta = credencialAmbiente("PADRAO_DESBLOQUEIO_CURTO", indicativo: "PADRAO")
            _ = try await manager.configurarCofre(credencial: curta, confirmacao: curta)
            XCTFail("Short credentials must be rejected")
        } catch let error as VaultError {
            XCTAssertEqual(error, .credencialMuitoCurta)
        }

        do {
            let credencial = credencialAmbientePadrao()
            let divergente = credencialAmbiente("PADRAO_DESBLOQUEIO_DIVERGENTE", indicativo: "PADRAO_DESBLOQUEIO_DIVERGENTE")
            _ = try await manager.configurarCofre(credencial: credencial, confirmacao: divergente)
            XCTFail("Mismatched credentials must be rejected")
        } catch let error as VaultError {
            XCTAssertEqual(error, .credenciaisNaoCoincidem)
        }

        let code = try await configureVault(credencialAmbientePadrao())
        let rawCode = code.replacingOccurrences(of: "-", with: "")
        XCTAssertEqual(rawCode.count, 32)
        XCTAssertEqual(code.split(separator: "-").map(\.count), [8, 8, 8, 8])
        XCTAssertTrue(manager.isConfigurado)
        XCTAssertEqual(manager.estadoAcesso, .desbloqueado)
    }

    func testEncryptedImportSurvivesLockAndRelaunch() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)

        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxSource-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }
        let source = sourceDirectory.appendingPathComponent("original_test_file.mov")
        var sourceBytes = Data("synthetic-only-video-fixture".utf8)
        sourceBytes.append(Data(repeating: 0x5A, count: 1_500_000))
        try sourceBytes.write(to: source)

        let item = try await manager.importarArquivo(em: source, nome: source.lastPathComponent, tipo: .video, duracao: 2.5)
        XCTAssertEqual(try Data(contentsOf: source), sourceBytes, "Import must preserve the source file")
        XCTAssertEqual(manager.itens, [item])

        let readSession = try await manager.abrirSessaoDeLeitura(id: item.id)
        var recoveredBytes = Data()
        var readOffset: Int64 = 0
        let chunkSize: Int64 = 1_048_576
        while readOffset < Int64(sourceBytes.count) {
            let end = min(Int64(sourceBytes.count), readOffset + chunkSize)
            recoveredBytes.append(try readSession.read(range: readOffset..<end))
            readOffset = end
        }
        XCTAssertEqual(recoveredBytes, sourceBytes, "Authenticated bounded reads must reproduce the source bytes")

        let boundaryRange = Int64(chunkSize - 7)..<Int64(chunkSize + 11)
        XCTAssertEqual(
            try readSession.read(range: boundaryRange),
            Data(sourceBytes[Int(boundaryRange.lowerBound)..<Int(boundaryRange.upperBound)]),
            "A range crossing a chunk boundary must authenticate and reproduce both pieces"
        )
        let finalRange = Int64(sourceBytes.count - 97)..<Int64(sourceBytes.count)
        XCTAssertEqual(
            try readSession.read(range: finalRange),
            Data(sourceBytes[Int(finalRange.lowerBound)..<Int(finalRange.upperBound)]),
            "The final partial chunk must be readable"
        )
        XCTAssertThrowsError(try readSession.read(range: Int64(sourceBytes.count)..<Int64(sourceBytes.count + 1))) {
            XCTAssertEqual($0 as? VaultError, .intervaloDeLeituraInvalido)
        }

        let encryptedFiles = try FileManager.default.contentsOfDirectory(
            at: vaultDirectory.appendingPathComponent("items"),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(encryptedFiles.count, 1)
        XCTAssertTrue(encryptedFiles[0].lastPathComponent.hasSuffix(".enc"))
        let encryptedBytes = try Data(contentsOf: encryptedFiles[0])
        XCTAssertNotEqual(encryptedBytes, sourceBytes)

        let encryptedIndex = try Data(contentsOf: vaultDirectory.appendingPathComponent("vault.index"))
        let indexText = String(decoding: encryptedIndex, as: UTF8.self)
        XCTAssertFalse(indexText.contains("original_test_file.mov"))
        XCTAssertFalse(indexText.contains(passphrase))

        manager.bloquearCofre()
        XCTAssertTrue(manager.itens.isEmpty, "Metadata must be removed from the visible locked state")
        XCTAssertThrowsError(try readSession.read(range: 0..<1)) {
            XCTAssertEqual($0 as? VaultError, .cofreBloqueado)
        }

        let relaunched = VaultAccessManager(storageDirectory: vaultDirectory)
        XCTAssertEqual(relaunched.estadoAcesso, .bloqueado)
        let reopened = await relaunched.desbloquearComCredencial(passphrase)
        XCTAssertTrue(reopened)
        XCTAssertEqual(relaunched.itens.count, 1)
        XCTAssertEqual(relaunched.itens.first?.nomeOriginal, "original_test_file.mov")
        XCTAssertEqual(relaunched.itens.first?.tamanhoBytes, Int64(sourceBytes.count))
    }

    func testWrongCredentialAndTamperedItemFailClosed() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)
        _ = try await manager.importarItensSinteticos(quantidade: 1, tipo: .foto)
        manager.bloquearCofre()

        let wrongCredentialManager = VaultAccessManager(storageDirectory: vaultDirectory)
        let wrongPassAccepted = await wrongCredentialManager.desbloquearComCredencial(
            credencialAmbiente("PADRAO_DESBLOQUEIO_INCORRETO", indicativo: "PADRAO_DESBLOQUEIO_INCORRETO")
        )
        XCTAssertFalse(wrongPassAccepted)
        XCTAssertEqual(wrongCredentialManager.erroAcesso, VaultError.credencialIncorreta.localizedDescription)

        let itemsDirectory = vaultDirectory.appendingPathComponent("items")
        let encryptedFile = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: itemsDirectory, includingPropertiesForKeys: nil).first)
        var tampered = try Data(contentsOf: encryptedFile)
        tampered[tampered.count - 1] ^= 0x01
        try tampered.write(to: encryptedFile, options: .atomic)

        let tamperedManager = VaultAccessManager(storageDirectory: vaultDirectory)
        let tamperedAccepted = await tamperedManager.desbloquearComCredencial(passphrase)
        XCTAssertFalse(tamperedAccepted)
        XCTAssertEqual(tamperedManager.erroAcesso, VaultError.dadoAdulterado.localizedDescription)
        XCTAssertTrue(tamperedManager.itens.isEmpty)
    }

    func testRecoveryReplacesPasswordEnvelopeWithoutChangingRecoveryCode() async throws {
        let oldPassphrase = credencialAmbientePadrao()
        let newPassphrase = credencialAmbiente("PADRAO_DESBLOQUEIO_NOVO", indicativo: "PADRAO_DESBLOQUEIO_NOVO")
        let code = try await configureVault(oldPassphrase)
        _ = try await manager.importarItensSinteticos(quantidade: 1, tipo: .foto)
        manager.bloquearCofre()
        manager.iniciarRecuperacao()

        try await manager.redefinirCredencialComCodigo(
            codigo: code,
            novaCredencial: newPassphrase,
            confirmacao: newPassphrase
        )
        XCTAssertEqual(manager.estadoAcesso, .desbloqueado)
        XCTAssertEqual(manager.itens.count, 1)

        manager.bloquearCofre()
        let relaunched = VaultAccessManager(storageDirectory: vaultDirectory)
        let oldPassAccepted = await relaunched.desbloquearComCredencial(oldPassphrase)
        XCTAssertFalse(oldPassAccepted)
        let newPassAccepted = await relaunched.desbloquearComCredencial(newPassphrase)
        XCTAssertTrue(newPassAccepted)
        XCTAssertEqual(relaunched.itens.count, 1)

        relaunched.bloquearCofre()
        let recoveredAgain = VaultAccessManager(storageDirectory: vaultDirectory)
        let outraCredencial = credencialAmbiente("PADRAO_DESBLOQUEIO_OUTRO", indicativo: "PADRAO_DESBLOQUEIO_OUTRO")
        try await recoveredAgain.redefinirCredencialComCodigo(
            codigo: code,
            novaCredencial: outraCredencial,
            confirmacao: outraCredencial
        )
        XCTAssertEqual(recoveredAgain.itens.count, 1)
    }

    func testInterruptedCommitIsRecoveredAfterRelaunch() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)
        await manager.simularFalhaDeTransacaoParaTeste(.afterFileMove)

        do {
            _ = try await manager.importarItensSinteticos(quantidade: 1, tipo: .foto)
            XCTFail("Injected interruption should stop the import")
        } catch let error as VaultError {
            XCTAssertEqual(error, .operacaoInterrompida)
        }
        XCTAssertTrue(manager.itens.isEmpty, "The manager must not publish a partial item")

        let relaunched = VaultAccessManager(storageDirectory: vaultDirectory)
        let recovered = await relaunched.desbloquearComCredencial(passphrase)
        XCTAssertTrue(recovered)
        XCTAssertEqual(relaunched.itens.count, 1, "A verified journaled item should be completed on reopen")

        for point in [VaultTransactionFailurePoint.afterStagingVerification, .afterJournal, .afterIndexWrite] {
            let nextRoot = FileManager.default.temporaryDirectory.appendingPathComponent("VoxTxn-\(UUID().uuidString)", isDirectory: true)
            let nextManager = VaultAccessManager(storageDirectory: nextRoot)
            let nextCode = try await configureVault(nextManager, passphrase: passphrase)
            await nextManager.simularFalhaDeTransacaoParaTeste(point)
            do {
                _ = try await nextManager.importarItensSinteticos(quantidade: 1, tipo: .video)
                XCTFail("Injected interruption should stop the import")
            } catch let error as VaultError {
                XCTAssertEqual(error, .operacaoInterrompida)
            }
            let restored = VaultAccessManager(storageDirectory: nextRoot)
            let restoredOk = await restored.desbloquearComCredencial(passphrase)
            XCTAssertTrue(restoredOk)
            let expectedCount = point == .afterStagingVerification ? 0 : 1
            XCTAssertEqual(restored.itens.count, expectedCount)
            XCTAssertEqual(nextCode.replacingOccurrences(of: "-", with: "").count, 32)
            try? FileManager.default.removeItem(at: nextRoot)
        }
    }

    func testDeletePersistsOnlyToVaultAndSpaceFailurePublishesNothing() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("VoxSource-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: source) }
        let bytes = Data("synthetic photo fixture".utf8)
        try bytes.write(to: source)
        let item = try await manager.importarArquivo(em: source, nome: "synthetic_photo.jpg", tipo: .foto)
        let readSession = try await manager.abrirSessaoDeLeitura(id: item.id)
        XCTAssertEqual(try readSession.read(range: 0..<Int64(bytes.count)), bytes)
        manager.fecharSessaoDeLeitura(id: readSession.sessionID)
        XCTAssertThrowsError(try readSession.read(range: 0..<1)) {
            XCTAssertEqual($0 as? VaultError, .cofreBloqueado)
        }

        let exportBatch = try await manager.prepararExportacao(ids: [item.id])
        let export = try XCTUnwrap(exportBatch.arquivos.first)
        XCTAssertEqual(try Data(contentsOf: export.url), bytes)
        XCTAssertEqual(export.nomeArquivo, "synthetic_photo.jpg")
        manager.concluirExportacao(id: exportBatch.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: export.url.path), "The prepared plaintext copy must be removed after export completes")

        do {
            _ = try await manager.importarItensSinteticos(quantidade: 2, tipo: .foto, simularEspacoInsuficiente: true)
            XCTFail("Simulated low space should fail")
        } catch let error as VaultError {
            XCTAssertEqual(error, .espacoInsuficiente)
        }
        XCTAssertEqual(manager.itens.count, 1)

        try await manager.apagarItemDoCofre(id: item.id)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        manager.bloquearCofre()
        let relaunched = VaultAccessManager(storageDirectory: vaultDirectory)
        let reopened = await relaunched.desbloquearComCredencial(passphrase)
        XCTAssertTrue(reopened)
        XCTAssertTrue(relaunched.itens.isEmpty)
    }

    func testRangeReadAndExportFailClosedWhenCiphertextChangesAfterUnlock() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)
        let fixture = Data("synthetic authenticated fixture".utf8)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("VoxTamper-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: source) }
        try fixture.write(to: source)
        let item = try await manager.importarArquivo(em: source, nome: "synthetic_tamper.jpg", tipo: .foto)
        let session = try await manager.abrirSessaoDeLeitura(id: item.id)

        let itemURL = vaultDirectory
            .appendingPathComponent("items", isDirectory: true)
            .appendingPathComponent("\(item.id.uuidString).enc")
        let encrypted = try Data(contentsOf: itemURL)
        let lastByteOffset = UInt64(encrypted.count - 1)
        let tamperedByte = (encrypted.last ?? 0) ^ 0x01
        let tamperHandle = try FileHandle(forWritingTo: itemURL)
        try tamperHandle.seek(toOffset: lastByteOffset)
        try tamperHandle.write(contentsOf: Data([tamperedByte]))
        try tamperHandle.close()

        XCTAssertThrowsError(try session.read(range: 0..<Int64(fixture.count))) {
            XCTAssertEqual($0 as? VaultError, .dadoAdulterado)
        }
        do {
            _ = try await manager.prepararExportacao(ids: [item.id])
            XCTFail("Tampered ciphertext must never produce an exportable file")
        } catch let error as VaultError {
            XCTAssertEqual(error, .dadoAdulterado)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "The source must remain untouched on export failure")
    }

    func testThumbnailRejectsImageIOPartialResultWhenLaterChunkIsTampered() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)

        let fixture = try makeLargePNGFixture()
        let chunkSize = 1_048_576
        XCTAssertGreaterThan(fixture.count, chunkSize * 2, "The fixture must span multiple authenticated chunks")
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxThumbnailTamper-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: source) }
        try fixture.write(to: source)

        let item = try await manager.importarArquivo(em: source, nome: source.lastPathComponent, tipo: .foto)
        let session = try await manager.abrirSessaoDeLeitura(id: item.id)
        defer { manager.fecharSessaoDeLeitura(id: session.sessionID) }

        let encryptedURL = vaultDirectory
            .appendingPathComponent("items", isDirectory: true)
            .appendingPathComponent("\(item.id.uuidString).enc")
        let tamperOffset = UInt64(chunkSize + 20 + 4 + 128)
        let readHandle = try FileHandle(forReadingFrom: encryptedURL)
        try readHandle.seek(toOffset: tamperOffset)
        let originalByte = try XCTUnwrap(readHandle.read(upToCount: 1)?.first)
        try readHandle.close()
        let encryptedFile = try FileHandle(forWritingTo: encryptedURL)
        try encryptedFile.seek(toOffset: tamperOffset)
        try encryptedFile.write(contentsOf: Data([originalByte ^ 0x01]))
        try encryptedFile.close()

        XCTAssertThrowsError(try VaultImageDecoder.thumbnail(from: session, maximumPixelSize: 256)) {
            XCTAssertEqual($0 as? VaultError, .dadoAdulterado)
        }
    }

    func testBackupSnapshotVerifiesWithoutChangingTheCurrentVault() async throws {
        let passphrase = credencialAmbientePadrao()
        let recoveryCode = try await configureVault(passphrase)
        let payload = Data("synthetic backup fixture".utf8) + Data(repeating: 0x6D, count: 1_100_000)
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxBackupFixture-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: source) }
        try payload.write(to: source)
        let item = try await manager.importarArquivo(em: source, nome: source.lastPathComponent, tipo: .foto)
        let itemsBeforeVerification = manager.itens

        let backup = try await manager.prepararBackup()
        let packageNames = Set(try FileManager.default.contentsOfDirectory(atPath: backup.url.path))
        XCTAssertEqual(packageNames, ["backup.manifest", "items", "vault.header", "vault.index"])
        XCTAssertEqual(
            try Data(contentsOf: backup.url.appendingPathComponent("items/\(item.id.uuidString).enc")),
            try Data(contentsOf: vaultDirectory.appendingPathComponent("items/\(item.id.uuidString).enc")),
            "The backup package must preserve the authenticated ciphertext without creating plaintext media"
        )

        let summary = try await manager.verificarBackup(em: backup.url, codigoRecuperacao: recoveryCode)
        XCTAssertEqual(summary.contagemItens, 1)
        XCTAssertGreaterThan(summary.tamanhoBytes, Int64(payload.count))
        XCTAssertEqual(manager.itens, itemsBeforeVerification, "Verification must not modify the current vault")
        XCTAssertEqual(try Data(contentsOf: source), payload, "Backup creation must preserve the source file")

        do {
            _ = try await manager.verificarBackup(em: backup.url, codigoRecuperacao: "00000000-00000000-00000000-00000000")
            XCTFail("A wrong recovery code must not verify a backup")
        } catch let error as VaultError {
            XCTAssertEqual(error, .codigoRecuperacaoInvalido)
        }

        let corruptedBackup = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxCorruptedBackup-\(UUID().uuidString).voxbackup", isDirectory: true)
        try FileManager.default.copyItem(at: backup.url, to: corruptedBackup)
        defer { try? FileManager.default.removeItem(at: corruptedBackup) }
        let manifestURL = corruptedBackup.appendingPathComponent("backup.manifest")
        var manifest = try Data(contentsOf: manifestURL)
        manifest[manifest.startIndex] ^= 0x01
        try manifest.write(to: manifestURL, options: .atomic)
        do {
            _ = try await manager.verificarBackup(em: corruptedBackup, codigoRecuperacao: recoveryCode)
            XCTFail("A modified manifest must fail authentication")
        } catch let error as VaultError {
            XCTAssertEqual(error, .dadoAdulterado)
        }
        XCTAssertEqual(manager.itens, itemsBeforeVerification, "Failed verification must not alter the active vault")
        manager.cancelarBackup(id: backup.id)
    }

    func testBackupCheckpointPersistsAndChangesBecomeStaleAfterRelaunch() async throws {
        let passphrase = credencialAmbientePadrao()
        _ = try await configureVault(passphrase)
        let prepared = try await manager.prepararBackup()
        try await manager.confirmarBackupExportado(id: prepared.id)
        guard case .atualizado(_, let count) = manager.estadoBackup else {
            return XCTFail("A confirmed export should persist the current backup checkpoint")
        }
        XCTAssertEqual(count, 0)

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxCheckpointFixture-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: source) }
        try Data(repeating: 0x31, count: 4_096).write(to: source)
        _ = try await manager.importarArquivo(em: source, nome: source.lastPathComponent, tipo: .foto)
        guard case .desatualizado(_, let pending) = manager.estadoBackup else {
            return XCTFail("A content change after export must stale the backup")
        }
        XCTAssertEqual(pending, 1)

        manager.bloquearCofre()
        let reopened = VaultAccessManager(storageDirectory: vaultDirectory)
        let reopenedSuccessfully = await reopened.desbloquearComCredencial(passphrase)
        XCTAssertTrue(reopenedSuccessfully)
        guard case .desatualizado(_, let pendingAfterRelaunch) = reopened.estadoBackup else {
            return XCTFail("The stale status must survive locking and reopening")
        }
        XCTAssertEqual(pendingAfterRelaunch, 1)
    }

    func testRestoreRotatesCredentialsAndPreservesTheBackupPackage() async throws {
        let oldPassphrase = credencialAmbientePadrao()
        let oldRecoveryCode = try await configureVault(oldPassphrase)
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxRestoreFixture-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: source) }
        let sourceBytes = Data("synthetic restore payload".utf8) + Data(repeating: 0xA3, count: 300_000)
        try sourceBytes.write(to: source)
        let originalItem = try await manager.importarArquivo(em: source, nome: source.lastPathComponent, tipo: .foto)

        let preparedBackup = try await manager.prepararBackup()
        let externalBackup = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxRestoreSource-\(UUID().uuidString).voxbackup", isDirectory: true)
        try FileManager.default.copyItem(at: preparedBackup.url, to: externalBackup)
        defer { try? FileManager.default.removeItem(at: externalBackup) }
        let sourceSnapshot = try backupPackageBytes(at: externalBackup)
        manager.cancelarBackup(id: preparedBackup.id)

        let restoredDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxRestoredVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: restoredDirectory) }
        let restoredManager = VaultAccessManager(storageDirectory: restoredDirectory)
        let newPassphrase = credencialAmbiente("PADRAO_DESBLOQUEIO_NOVO", indicativo: "PADRAO_DESBLOQUEIO_NOVO")
        let restore = try await restoredManager.prepararRestauracao(
            de: externalBackup,
            codigoRecuperacao: oldRecoveryCode,
            novaCredencial: newPassphrase,
            confirmacao: newPassphrase
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoredDirectory.path))

        do {
            try await restoredManager.confirmarNovoCodigoRecuperacao(id: restore.id, trechoDigitado: "00000000")
            XCTFail("The new recovery code must be confirmed before installation")
        } catch let error as VaultError {
            XCTAssertEqual(error, .confirmacaoInvalida)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: restoredDirectory.path))

        let newRecoveryCode = restore.codigoRecuperacao
        try await restoredManager.confirmarNovoCodigoRecuperacao(
            id: restore.id,
            trechoDigitado: String(newRecoveryCode.filter(\.isHexDigit).suffix(8))
        )
        XCTAssertTrue(restoredManager.isConfigurado)
        XCTAssertEqual(restoredManager.itens.map(\.id), [originalItem.id])
        XCTAssertEqual(try backupPackageBytes(at: externalBackup), sourceSnapshot)
        XCTAssertEqual(try Data(contentsOf: source), sourceBytes)

        restoredManager.bloquearCofre()
        let restoredSuccessfully = await restoredManager.desbloquearComCredencial(newPassphrase)
        XCTAssertTrue(restoredSuccessfully)

        let outraCredencial = credencialAmbiente("PADRAO_DESBLOQUEIO_OUTRO", indicativo: "PADRAO_DESBLOQUEIO_OUTRO")
        do {
            try await restoredManager.redefinirCredencialComCodigo(
                codigo: oldRecoveryCode,
                novaCredencial: outraCredencial,
                confirmacao: outraCredencial
            )
            XCTFail("The recovery code from the old backup must not open the restored vault")
        } catch let error as VaultError {
            XCTAssertEqual(error, .codigoRecuperacaoInvalido)
        }

        let credencialDepois = credencialAmbiente("PADRAO_DESBLOQUEIO_RESTORE", indicativo: "PADRAO_DESBLOQUEIO_RESTORE")
        try await restoredManager.redefinirCredencialComCodigo(
            codigo: newRecoveryCode,
            novaCredencial: credencialDepois,
            confirmacao: credencialDepois
        )
        XCTAssertEqual(restoredManager.estadoAcesso, .desbloqueado)
    }

    func testHardwareBenchmarkExecution() async throws {
        let resultado = try await HardwareBenchmarkService.shared.executarDiagnosticoCompleto()
        XCTAssertGreaterThan(resultado.tempoDerivacaoArgon2idMs, 0)
        XCTAssertGreaterThan(resultado.memoriaResidenteMB, 0)
        XCTAssertGreaterThan(resultado.taxaCriptografiaAESMBs, 0)
        XCTAssertFalse(resultado.statusHardware.isEmpty)
    }

    func testInterDeviceRestoreSimulation() async throws {
        // Simulação do Aparelho A (origem)
        let dirAparelhoA = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxDeviceA-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dirAparelhoA) }
        let managerA = VaultAccessManager(storageDirectory: dirAparelhoA)

        let credencialA = credencialAmbiente("PADRAO_DESBLOQUEIO_APARELHO_A", indicativo: "PADRAO_DESBLOQUEIO_APARELHO_A")
        let codigoRecuperacaoA = try await configureVault(managerA, passphrase: credencialA)

        // Criar fixtures de mídia (uma imagem e um vídeo sintético)
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxFixtures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let fotoURL = sourceDir.appendingPathComponent("foto_teste.png")
        let fotoBytes = try makeLargePNGFixture()
        try fotoBytes.write(to: fotoURL)

        let videoURL = sourceDir.appendingPathComponent("video_teste.mov")
        var videoBytes = Data("synthetic-video-header".utf8)
        videoBytes.append(Data(repeating: 0x7E, count: 500_000))
        try videoBytes.write(to: videoURL)

        let itemFoto = try await managerA.importarArquivo(em: fotoURL, nome: "foto_teste.png", tipo: .foto)
        let itemVideo = try await managerA.importarArquivo(em: videoURL, nome: "video_teste.mov", tipo: .video, duracao: 12.0)

        XCTAssertEqual(managerA.itens.count, 2)
        XCTAssertEqual(try Data(contentsOf: fotoURL), fotoBytes, "Origem da foto deve permanecer intacta")
        XCTAssertEqual(try Data(contentsOf: videoURL), videoBytes, "Origem do vídeo deve permanecer intacta")

        // Aparelho A prepara pacote .voxbackup para exportação (AirDrop / Compartilhamento de arquivos)
        let backupPreparado = try await managerA.prepararBackup()
        let pacoteTransferido = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxSharedPackage-\(UUID().uuidString).voxbackup", isDirectory: true)
        try FileManager.default.copyItem(at: backupPreparado.url, to: pacoteTransferido)
        defer { try? FileManager.default.removeItem(at: pacoteTransferido) }
        managerA.cancelarBackup(id: backupPreparado.id)

        // Validar integridade do pacote transferido: zero texto claro
        let packageNames = Set(try FileManager.default.contentsOfDirectory(atPath: pacoteTransferido.path))
        XCTAssertTrue(packageNames.contains("backup.manifest"))
        XCTAssertTrue(packageNames.contains("vault.header"))
        XCTAssertTrue(packageNames.contains("vault.index"))
        XCTAssertTrue(packageNames.contains("items"))

        let encryptedFiles = try FileManager.default.contentsOfDirectory(
            at: pacoteTransferido.appendingPathComponent("items"),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(encryptedFiles.count, 2)
        for itemURL in encryptedFiles {
            XCTAssertTrue(itemURL.lastPathComponent.hasSuffix(".enc"), "Todos os itens no backup devem ser cifras .enc")
            let data = try Data(contentsOf: itemURL)
            XCTAssertFalse(data.contains(Data("synthetic-video-header".utf8)), "Cifra do item não pode vazar texto claro")
        }

        // Simulação do Aparelho B (destino independente)
        let dirAparelhoB = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxDeviceB-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dirAparelhoB) }
        let managerB = VaultAccessManager(storageDirectory: dirAparelhoB)

        XCTAssertFalse(managerB.isConfigurado)
        XCTAssertEqual(managerB.estadoAcesso, .naoConfigurado)

        // Aparelho B verifica o pacote antes de restaurar
        let resumo = try await managerB.verificarBackup(em: pacoteTransferido, codigoRecuperacao: codigoRecuperacaoA)
        XCTAssertEqual(resumo.contagemItens, 2)
        XCTAssertFalse(managerB.isConfigurado, "Verificação não deve configurar o cofre")

        // Aparelho B falha com código de recuperação incorreto
        do {
            _ = try await managerB.prepararRestauracao(
                de: pacoteTransferido,
                codigoRecuperacao: "00000000-00000000-00000000-00000000",
                novaCredencial: credencialAmbiente("PADRAO_DESBLOQUEIO_APARELHO_B", indicativo: "PADRAO_DESBLOQUEIO_APARELHO_B"),
                confirmacao: credencialAmbiente("PADRAO_DESBLOQUEIO_APARELHO_B", indicativo: "PADRAO_DESBLOQUEIO_APARELHO_B")
            )
            XCTFail("Restauração com código incorreto deve falhar")
        } catch let error as VaultError {
            XCTAssertEqual(error, .codigoRecuperacaoInvalido)
        }

        // Aparelho B restaura com nova credencial independente
        let credencialB = credencialAmbiente("PADRAO_DESBLOQUEIO_APARELHO_B", indicativo: "PADRAO_DESBLOQUEIO_APARELHO_B")
        let restauracao = try await managerB.prepararRestauracao(
            de: pacoteTransferido,
            codigoRecuperacao: codigoRecuperacaoA,
            novaCredencial: credencialB,
            confirmacao: credencialB
        )

        let codigoRecuperacaoB = restauracao.codigoRecuperacao
        XCTAssertNotEqual(codigoRecuperacaoB, codigoRecuperacaoA, "O código de recuperação do Aparelho B deve ser novo e rotacionado")

        try await managerB.confirmarNovoCodigoRecuperacao(
            id: restauracao.id,
            trechoDigitado: String(codigoRecuperacaoB.filter(\.isHexDigit).suffix(8))
        )

        XCTAssertTrue(managerB.isConfigurado)
        XCTAssertEqual(managerB.estadoAcesso, .desbloqueado)
        XCTAssertEqual(managerB.itens.count, 2)

        // Validar leitura fiel dos itens no Aparelho B
        let readSessionFoto = try await managerB.abrirSessaoDeLeitura(id: itemFoto.id)
        var recoveredFoto = Data()
        var offsetFoto: Int64 = 0
        let chunkSize: Int64 = 1_048_576
        while offsetFoto < Int64(fotoBytes.count) {
            let end = min(Int64(fotoBytes.count), offsetFoto + chunkSize)
            recoveredFoto.append(try readSessionFoto.read(range: offsetFoto..<end))
            offsetFoto = end
        }
        XCTAssertEqual(recoveredFoto, fotoBytes, "Bytes da foto restaurada devem ser idênticos aos originais")

        let readSessionVideo = try await managerB.abrirSessaoDeLeitura(id: itemVideo.id)
        var recoveredVideo = Data()
        var offsetVideo: Int64 = 0
        while offsetVideo < Int64(videoBytes.count) {
            let end = min(Int64(videoBytes.count), offsetVideo + chunkSize)
            recoveredVideo.append(try readSessionVideo.read(range: offsetVideo..<end))
            offsetVideo = end
        }
        XCTAssertEqual(recoveredVideo, videoBytes, "Bytes do vídeo restaurado devem ser idênticos aos originais")

        // Validar isolamento de credenciais no Aparelho B
        managerB.bloquearCofre()
        let desbloqueouComCredencialAntiga = await managerB.desbloquearComCredencial(credencialA)
        XCTAssertFalse(desbloqueouComCredencialAntiga, "Credencial do Aparelho A não pode desbloquear o Aparelho B")

        let desbloqueouComNovaCredencial = await managerB.desbloquearComCredencial(credencialB)
        XCTAssertTrue(desbloqueouComNovaCredencial, "Aparelho B deve desbloquear com sua nova credencial")
    }


    private func backupPackageBytes(at directory: URL) throws -> [String: Data] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
        var files: [String: Data] = [:]
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let relativePath = String(url.path.dropFirst(directory.path.count + 1))
            files[relativePath] = try Data(contentsOf: url)
        }
        return files
    }

    private func makeLargePNGFixture() throws -> Data {
        let width = 1_024
        let height = 1_024
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var state: UInt32 = 0x1234_5678
            for pixel in 0..<(width * height) {
                state = state &* 1_664_525 &+ 1_013_904_223
                let offset = pixel * 4
                bytes[offset] = UInt8(truncatingIfNeeded: state >> 16)
                bytes[offset + 1] = UInt8(truncatingIfNeeded: state >> 8)
                bytes[offset + 2] = UInt8(truncatingIfNeeded: state)
                bytes[offset + 3] = 0xFF
            }
        }
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw VaultError.formatoDeMidiaNaoSuportado
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw VaultError.formatoDeMidiaNaoSuportado
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw VaultError.formatoDeMidiaNaoSuportado
        }
        return output as Data
    }

    private func configureVault(_ passphrase: String) async throws -> String {
        try await configureVault(manager, passphrase: passphrase)
    }

    private func configureVault(_ target: VaultAccessManager, passphrase: String) async throws -> String {
        let code = try await target.configurarCofre(credencial: passphrase, confirmacao: passphrase)
        try await target.confirmarCodigoRecuperacao(trechoDigitado: String(code.suffix(8)))
        return code
    }

    private func credencialAmbiente(_ variavel: String, indicativo: String) -> String {
        ProcessInfo.processInfo.environment[variavel] ?? indicativo
    }

    private func credencialAmbientePadrao() -> String {
        ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO"
    }
}
