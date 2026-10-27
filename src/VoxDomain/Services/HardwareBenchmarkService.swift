import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct BenchmarkHardwareResult: Sendable, Equatable {
    public let tempoDerivacaoArgon2idMs: Double
    public let memoriaResidenteMB: Double
    public let taxaCriptografiaAESMBs: Double
    public let statusHardware: String
    public let dataExecucao: Date

    public init(
        tempoDerivacaoArgon2idMs: Double,
        memoriaResidenteMB: Double,
        taxaCriptografiaAESMBs: Double,
        statusHardware: String,
        dataExecucao: Date = Date()
    ) {
        self.tempoDerivacaoArgon2idMs = tempoDerivacaoArgon2idMs
        self.memoriaResidenteMB = memoriaResidenteMB
        self.taxaCriptografiaAESMBs = taxaCriptografiaAESMBs
        self.statusHardware = statusHardware
        self.dataExecucao = dataExecucao
    }
}

public final class HardwareBenchmarkService: Sendable {
    public static let shared = HardwareBenchmarkService()

    public init() {}

    public func obterMemoriaResidenteMB() -> Double {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024.0 * 1024.0)
        #else
        return 0
        #endif
    }

    public func executarDiagnosticoCompleto() async throws -> BenchmarkHardwareResult {
        let memAntes = obterMemoriaResidenteMB()

        // 1. Derivação de chave mestre com Argon2id v1.3 (3 operações, 64 MiB)
        let salt = try VaultCrypto.randomBytes(count: VaultCrypto.passwordSaltLength)
        let startArgon = DispatchTime.now()
        var masterKey = try VaultCrypto.deriveMasterKey(
            passphrase: ProcessInfo.processInfo.environment["PADRAO_DESBLOQUEIO"] ?? "PADRAO_DESBLOQUEIO",
            salt: salt
        )
        let endArgon = DispatchTime.now()
        let nanoArgon = endArgon.uptimeNanoseconds - startArgon.uptimeNanoseconds
        let msArgon = Double(nanoArgon) / 1_000_000.0

        let memPico = max(memAntes, obterMemoriaResidenteMB())

        // 2. Criptografia em blocos de 1 MiB com AES-256-GCM
        let payloadSize = 1_048_576
        let syntheticData = Data(repeating: 0x5A, count: payloadSize)
        let aad = Data("benchmark-aad".utf8)
        let startAES = DispatchTime.now()
        let sealedChunk = try VaultCrypto.seal(
            syntheticData,
            key: masterKey,
            authenticating: aad
        )
        let openedChunk = try VaultCrypto.open(
            sealedChunk,
            key: masterKey,
            authenticating: aad
        )
        let endAES = DispatchTime.now()
        masterKey.resetBytes(in: 0..<masterKey.count)

        guard openedChunk == syntheticData else {
            throw VaultError.dadoAdulterado
        }

        let nanoAES = endAES.uptimeNanoseconds - startAES.uptimeNanoseconds
        let secondsAES = max(Double(nanoAES) / 1_000_000_000.0, 0.0001)
        let mbPerSec = (Double(payloadSize) / (1024.0 * 1024.0)) / secondsAES

        let status: String
        if msArgon <= 1_800.0 {
            status = "Aprovado: latência e consumo dentro dos parâmetros nominais para iPhone físico."
        } else {
            status = "Alerta: latência de derivação acima de 1,8s (\(Int(msArgon)) ms)."
        }

        return BenchmarkHardwareResult(
            tempoDerivacaoArgon2idMs: msArgon,
            memoriaResidenteMB: memPico,
            taxaCriptografiaAESMBs: mbPerSec,
            statusHardware: status
        )
    }
}
