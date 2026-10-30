import Foundation
import XCTest
@testable import VoxDomain
@testable import VoxUI

@MainActor
final class MultiVaultTests: XCTestCase {
    private var baseDirectory: URL!

    override func setUp() async throws {
        baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoxMultiVaultTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: baseDirectory)
    }

    private func credencialAmbiente(_ chave: String, fallback: String) -> String {
        ProcessInfo.processInfo.environment[chave] ?? fallback
    }

    func testCreateMultipleVaultsWithDifferentCredentials() async throws {
        let manager = VaultAccessManager(multiVaultDirectory: baseDirectory)
        XCTAssertTrue(manager.listaCofres.isEmpty)
        XCTAssertNil(manager.cofreAtivo)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.naoConfigurado)

        // 1. Cria o primeiro cofre (Pessoal) com senha escrita
        let senha1 = credencialAmbiente("PADRAO_DESBLOQUEIO_1", fallback: "senha-longa-exclusiva-pessoal-123")
        let code1 = try await manager.criarNovoCofre(nome: "Pessoal", credencial: senha1, confirmacao: senha1)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code1)

        XCTAssertEqual(manager.listaCofres.count, 1)
        XCTAssertEqual(manager.cofreAtivo?.nome, "Pessoal")
        XCTAssertEqual(manager.cofreAtivo?.tipoCredencial, TipoCredencial.texto)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)

        // 2. Cria o segundo cofre (Trabalho) com padrão de pontos
        let pontos = [0, 1, 2, 5, 8]
        let padraoSerializado = PadraoDesbloqueio.serializar(pontos: pontos)
        let code2 = try await manager.criarNovoCofre(nome: "Trabalho", credencial: padraoSerializado, confirmacao: padraoSerializado)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code2)

        XCTAssertEqual(manager.listaCofres.count, 2)
        XCTAssertEqual(manager.cofreAtivo?.nome, "Trabalho")
        XCTAssertEqual(manager.cofreAtivo?.tipoCredencial, TipoCredencial.padrao)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)
    }

    func testVaultIsolationAndIndependentUnlocking() async throws {
        let manager = VaultAccessManager(multiVaultDirectory: baseDirectory)

        let senhaPessoal = credencialAmbiente("PADRAO_DESBLOQUEIO_PESSOAL", fallback: "senha-longa-exclusiva-pessoal-123")
        let code1 = try await manager.criarNovoCofre(nome: "Pessoal", credencial: senhaPessoal, confirmacao: senhaPessoal)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code1)

        let pontosTrabalho = [0, 3, 6, 7, 8]
        let padraoTrabalho = PadraoDesbloqueio.serializar(pontos: pontosTrabalho)
        let code2 = try await manager.criarNovoCofre(nome: "Trabalho", credencial: padraoTrabalho, confirmacao: padraoTrabalho)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code2)

        // Importa item no cofre Trabalho
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let arquivo = tempDir.appendingPathComponent("documento_trabalho.jpg")
        let dadosFixture = Data(repeating: 0x42, count: 2048)
        try dadosFixture.write(to: arquivo)

        let itemTrabalho = try await manager.importarArquivo(em: arquivo, nome: "documento_trabalho.jpg", tipo: TipoDeMidia.foto, duracao: nil)
        XCTAssertEqual(manager.itens.count, 1)
        XCTAssertEqual(manager.itens.first?.id, itemTrabalho.id)

        // Alterna para o cofre Pessoal
        guard let cofrePessoal = manager.listaCofres.first(where: { $0.nome == "Pessoal" }) else {
            XCTFail("Cofre Pessoal não encontrado")
            return
        }
        await manager.selecionarCofre(id: cofrePessoal.id)

        XCTAssertEqual(manager.cofreAtivo?.id, cofrePessoal.id)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.bloqueado)
        XCTAssertTrue(manager.itens.isEmpty, "Memória de itens deve ser esvaziada ao trocar de cofre")

        // Tentar desbloquear Pessoal com o padrão de Trabalho deve falhar
        let desbloqueouErrado = await manager.desbloquearComCredencial(padraoTrabalho)
        XCTAssertFalse(desbloqueouErrado, "Desbloqueio com credencial de outro cofre deve retornar false")
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.bloqueado)
        XCTAssertEqual(manager.tentativasFalhas, 1)

        // Desbloquear com a senha correta de Pessoal deve ter sucesso
        let desbloqueouPessoal = await manager.desbloquearComCredencial(senhaPessoal)
        XCTAssertTrue(desbloqueouPessoal, "Desbloqueio com credencial correta deve retornar true")
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)
        XCTAssertTrue(manager.itens.isEmpty, "Cofre Pessoal não deve conter itens do cofre Trabalho")

        // Alterna de volta para Trabalho e desbloqueia com o padrão
        guard let cofreTrabalho = manager.listaCofres.first(where: { $0.nome == "Trabalho" }) else {
            XCTFail("Cofre Trabalho não encontrado")
            return
        }
        await manager.selecionarCofre(id: cofreTrabalho.id)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.bloqueado)

        let desbloqueouTrabalho = await manager.desbloquearComCredencial(padraoTrabalho)
        XCTAssertTrue(desbloqueouTrabalho)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)
        XCTAssertEqual(manager.itens.count, 1)
        XCTAssertEqual(manager.itens.first?.id, itemTrabalho.id)
    }

    func testRenameVault() async throws {
        let manager = VaultAccessManager(multiVaultDirectory: baseDirectory)
        let senha = credencialAmbiente("PADRAO_DESBLOQUEIO_RENAME", fallback: "senha-longa-exclusiva-rename-123")
        let code = try await manager.criarNovoCofre(nome: "Original", credencial: senha, confirmacao: senha)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code)

        guard let cofre = manager.cofreAtivo else {
            XCTFail("Cofre ativo deve existir")
            return
        }

        try await manager.renomearCofre(id: cofre.id, novoNome: "Renomeado")
        XCTAssertEqual(manager.cofreAtivo?.nome, "Renomeado")
        XCTAssertEqual(manager.listaCofres.first?.nome, "Renomeado")

        // Nome inválido (vazio) deve ser rejeitado
        do {
            try await manager.renomearCofre(id: cofre.id, novoNome: "   ")
            XCTFail("Nome em branco deve ser rejeitado")
        } catch let erro as VaultError {
            XCTAssertEqual(erro, .nomeCofreInvalido)
        }

        // Recria manager a partir do mesmo diretório para testar persistência
        let manager2 = VaultAccessManager(multiVaultDirectory: baseDirectory)
        XCTAssertEqual(manager2.listaCofres.first?.nome, "Renomeado")
    }

    func testDeleteVaultPreservesOtherVaults() async throws {
        let manager = VaultAccessManager(multiVaultDirectory: baseDirectory)

        let senha1 = credencialAmbiente("PADRAO_DESBLOQUEIO_DEL1", fallback: "senha-longa-exclusiva-del1-123")
        let code1 = try await manager.criarNovoCofre(nome: "CofreA", credencial: senha1, confirmacao: senha1)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code1)

        let senha2 = credencialAmbiente("PADRAO_DESBLOQUEIO_DEL2", fallback: "senha-longa-exclusiva-del2-123")
        let code2 = try await manager.criarNovoCofre(nome: "CofreB", credencial: senha2, confirmacao: senha2)
        try await manager.confirmarCodigoRecuperacao(trechoDigitado: code2)

        XCTAssertEqual(manager.listaCofres.count, 2)
        guard let cofreA = manager.listaCofres.first(where: { $0.nome == "CofreA" }) else {
            XCTFail("CofreA não encontrado")
            return
        }

        // Apaga CofreA
        await manager.apagarCofre(id: cofreA.id)

        XCTAssertEqual(manager.listaCofres.count, 1)
        XCTAssertEqual(manager.listaCofres.first?.nome, "CofreB")
        XCTAssertEqual(manager.cofreAtivo?.nome, "CofreB")

        // CofreB continua funcionando normalmente
        manager.bloquearCofre()
        let desbloqueouB = await manager.desbloquearComCredencial(senha2)
        XCTAssertTrue(desbloqueouB)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)
    }

    func testDirectAtomicVaultCreationWithoutRecoveryCode() async throws {
        let manager = VaultAccessManager(multiVaultDirectory: baseDirectory)
        let senha = credencialAmbiente("PADRAO_DESBLOQUEIO_ATOMIC", fallback: "senha-longa-exclusiva-atomic-123")
        let cofre = try await manager.criarEAtivarNovoCofre(nome: "Finanças", credencial: senha, confirmacao: senha)

        XCTAssertEqual(cofre.nome, "Finanças")
        XCTAssertEqual(manager.cofreAtivo?.nome, "Finanças")
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)
        XCTAssertEqual(manager.listaCofres.count, 1)

        // Bloquear e voltar
        manager.bloquearCofre()
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.bloqueado)
        XCTAssertTrue(manager.itens.isEmpty)

        // Desbloquear com senha definida
        let desbloqueou = await manager.desbloquearComCredencial(senha)
        XCTAssertTrue(desbloqueou)
        XCTAssertEqual(manager.estadoAcesso, EstadoAcesso.desbloqueado)
    }
}
