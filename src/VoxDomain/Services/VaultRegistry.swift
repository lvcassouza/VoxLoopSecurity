import Foundation

/// Registro de manifesto de múltiplos cofres locais.
public struct ManifestCofres: Codable, Sendable {
    public var versao: Int = 1
    public var idCofreAtivo: UUID?
    public var cofres: [DescritorCofre]

    public init(versao: Int = 1, idCofreAtivo: UUID? = nil, cofres: [DescritorCofre] = []) {
        self.versao = versao
        self.idCofreAtivo = idCofreAtivo
        self.cofres = cofres
    }
}

/// Serviço responsável pelo registro e catálogo local de múltiplos cofres no aparelho.
/// Não armazena segredos, chaves ou metadados de arquivos.
public actor VaultRegistry {
    public let baseDirectory: URL
    private let manifestURL: URL
    public let vaultsDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
        self.manifestURL = baseDirectory.appendingPathComponent("vaults-manifest.json")
        self.vaultsDirectory = baseDirectory.appendingPathComponent("vaults", isDirectory: true)
    }

    public func carregarManifesto() throws -> ManifestCofres {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return ManifestCofres()
        }
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(ManifestCofres.self, from: data)
    }

    public func salvarManifesto(_ manifesto: ManifestCofres) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(manifesto)
        let tempURL = baseDirectory.appendingPathComponent(".manifest-\(UUID().uuidString).tmp")
        try data.write(to: tempURL, options: .atomic)
        _ = try? FileManager.default.removeItem(at: manifestURL)
        try FileManager.default.moveItem(at: tempURL, to: manifestURL)
    }

    public func diretorioDoCofre(id: UUID) -> URL {
        vaultsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public func listarCofres() throws -> [DescritorCofre] {
        try carregarManifesto().cofres
    }

    public func obterCofreAtivoID() throws -> UUID? {
        try carregarManifesto().idCofreAtivo
    }

    public func registrarCofre(_ descritor: DescritorCofre, tornarAtivo: Bool = true) throws {
        var manifesto = try carregarManifesto()
        if let idx = manifesto.cofres.firstIndex(where: { $0.id == descritor.id }) {
            manifesto.cofres[idx] = descritor
        } else {
            manifesto.cofres.append(descritor)
        }
        if tornarAtivo || manifesto.idCofreAtivo == nil {
            manifesto.idCofreAtivo = descritor.id
        }
        try salvarManifesto(manifesto)
    }

    public func atualizarNomeCofre(id: UUID, novoNome: String) throws {
        var manifesto = try carregarManifesto()
        guard let idx = manifesto.cofres.firstIndex(where: { $0.id == id }) else { return }
        manifesto.cofres[idx].nome = novoNome
        try salvarManifesto(manifesto)
    }

    public func atualizarUltimoAcesso(id: UUID, data: Date = Date()) throws {
        var manifesto = try carregarManifesto()
        guard let idx = manifesto.cofres.firstIndex(where: { $0.id == id }) else { return }
        manifesto.cofres[idx].ultimoAcesso = data
        try salvarManifesto(manifesto)
    }

    public func definirCofreAtivo(id: UUID?) throws {
        var manifesto = try carregarManifesto()
        manifesto.idCofreAtivo = id
        try salvarManifesto(manifesto)
    }

    public func removerCofre(id: UUID) throws {
        var manifesto = try carregarManifesto()
        manifesto.cofres.removeAll { $0.id == id }
        if manifesto.idCofreAtivo == id {
            manifesto.idCofreAtivo = manifesto.cofres.first?.id
        }
        try salvarManifesto(manifesto)
        let dir = diretorioDoCofre(id: id)
        if FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    /// Migra cofre legado do diretório único para a estrutura de múltiplos cofres, se existir.
    public func migrarCofreLegadoSeNecessario(legadoURL: URL) throws {
        let legacyHeader = legadoURL.appendingPathComponent("vault.header")
        guard FileManager.default.fileExists(atPath: legacyHeader.path) else { return }

        var manifesto = try carregarManifesto()
        guard manifesto.cofres.isEmpty else { return }

        let novoID = UUID()
        let novoDir = diretorioDoCofre(id: novoID)
        try FileManager.default.createDirectory(at: vaultsDirectory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: legadoURL, to: novoDir)

        var tipo: TipoCredencial = .texto
        if let data = try? Data(contentsOf: novoDir.appendingPathComponent("vault.header")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let rawTipo = json["credentialType"] as? String,
           let parsed = TipoCredencial(rawValue: rawTipo) {
            tipo = parsed
        }

        let descritor = DescritorCofre(
            id: novoID,
            nome: "Cofre Principal",
            tipoCredencial: tipo,
            criadoEm: Date()
        )
        manifesto.cofres.append(descritor)
        manifesto.idCofreAtivo = novoID
        try salvarManifesto(manifesto)
    }
}
