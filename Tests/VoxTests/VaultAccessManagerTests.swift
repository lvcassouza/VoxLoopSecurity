import Foundation
import XCTest
@testable import VoxDomain

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
            _ = try await manager.configurarCofre(credencial: "curta", confirmacao: "curta")
            XCTFail("Short credentials must be rejected")
        } catch let error as VaultError {
            XCTAssertEqual(error, .credencialMuitoCurta)
        }

        do {
            _ = try await manager.configurarCofre(credencial: "SenhaForte123", confirmacao: "outraSenha123")
            XCTFail("Mismatched credentials must be rejected")
        } catch let error as VaultError {
            XCTAssertEqual(error, .credenciaisNaoCoincidem)
        }

        let code = try await configureVault("FraseDeTesteLonga123")
        let rawCode = code.replacingOccurrences(of: "-", with: "")
        XCTAssertEqual(rawCode.count, 32)
        XCTAssertEqual(code.split(separator: "-").map(\.count), [8, 8, 8, 8])
        XCTAssertTrue(manager.isConfigurado)
        XCTAssertEqual(manager.estadoAcesso, .desbloqueado)
    }

    func testEncryptedImportSurvivesLockAndRelaunch() async throws {
        let passphrase = "FraseDeTesteMuitoLonga123"
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

        let relaunched = VaultAccessManager(storageDirectory: vaultDirectory)
        XCTAssertEqual(relaunched.estadoAcesso, .bloqueado)
        let reopened = await relaunched.desbloquearComCredencial(passphrase)
        XCTAssertTrue(reopened)
        XCTAssertEqual(relaunched.itens.count, 1)
        XCTAssertEqual(relaunched.itens.first?.nomeOriginal, "original_test_file.mov")
        XCTAssertEqual(relaunched.itens.first?.tamanhoBytes, Int64(sourceBytes.count))
    }

    func testWrongCredentialAndTamperedItemFailClosed() async throws {
        let passphrase = "FraseDeTesteMuitoLonga456"
        _ = try await configureVault(passphrase)
        _ = try await manager.importarItensSinteticos(quantidade: 1, tipo: .foto)
        manager.bloquearCofre()

        let wrongCredentialManager = VaultAccessManager(storageDirectory: vaultDirectory)
        let wrongPassAccepted = await wrongCredentialManager.desbloquearComCredencial("senha-incorreta")
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
        let oldPassphrase = "CredencialDeTesteAntiga123"
        let newPassphrase = "CredencialDeTesteNova456"
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
        try await recoveredAgain.redefinirCredencialComCodigo(
            codigo: code,
            novaCredencial: "CredencialDeTesteOutra789",
            confirmacao: "CredencialDeTesteOutra789"
        )
        XCTAssertEqual(recoveredAgain.itens.count, 1)
    }

    func testInterruptedCommitIsRecoveredAfterRelaunch() async throws {
        let passphrase = "CredencialDeTesteTransacao123"
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
        let passphrase = "CredencialDeTesteExclusao123"
        _ = try await configureVault(passphrase)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("VoxSource-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: source) }
        let bytes = Data("synthetic photo fixture".utf8)
        try bytes.write(to: source)
        let item = try await manager.importarArquivo(em: source, nome: "synthetic_photo.jpg", tipo: .foto)
        XCTAssertThrowsError(try manager.exportarItem(id: item.id)) { error in
            XCTAssertEqual(error as? VaultError, .exportacaoIndisponivelNestaVersao)
        }

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

    private func configureVault(_ passphrase: String) async throws -> String {
        try await configureVault(manager, passphrase: passphrase)
    }

    private func configureVault(_ target: VaultAccessManager, passphrase: String) async throws -> String {
        let code = try await target.configurarCofre(credencial: passphrase, confirmacao: passphrase)
        try await target.confirmarCodigoRecuperacao(trechoDigitado: String(code.suffix(8)))
        return code
    }
}
