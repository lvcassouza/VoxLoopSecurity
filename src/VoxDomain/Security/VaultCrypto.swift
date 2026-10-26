import CryptoKit
import Foundation
import Security
import Clibsodium

/// Primitive layer for the experimental on-device vault format.
/// Password derivation is delegated to libsodium; file encryption uses CryptoKit.
enum VaultCrypto {
    static let keyLength = 32
    static let recoverySaltLength = 16
    static let passwordSaltLength = 16
    static let argonMemoryBytes = 64 * 1024 * 1024
    static let argonOperations: UInt64 = 3
    static let argonAlgorithm = Int32(crypto_pwhash_ALG_ARGON2ID13)

    struct SealedValue: Codable, Sendable {
        let nonce: Data
        let ciphertext: Data
        let tag: Data
    }

    static func randomBytes(count: Int) throws -> Data {
        guard count > 0 else { return Data() }
        var bytes = Data(count: count)
        let result = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard result == errSecSuccess else { throw VaultCryptoError.randomGenerationFailed }
        return bytes
    }

    static func deriveMasterKey(passphrase: String, salt: Data) throws -> Data {
        guard salt.count == passwordSaltLength else { throw VaultCryptoError.invalidFormat }
        guard sodium_init() >= 0 else { throw VaultCryptoError.cryptographicOperationFailed }

        var password = Data(passphrase.precomposedStringWithCanonicalMapping.utf8)
        defer { password.resetBytes(in: 0..<password.count) }
        guard !password.isEmpty, password.count <= 1_024 else { throw VaultCryptoError.invalidFormat }
        var output = Data(count: keyLength)
        let outputLength = keyLength
        let result = output.withUnsafeMutableBytes { outputBuffer in
            password.withUnsafeBytes { passwordBuffer in
                salt.withUnsafeBytes { saltBuffer in
                    crypto_pwhash(
                        outputBuffer.bindMemory(to: UInt8.self).baseAddress!,
                        UInt64(outputLength),
                        passwordBuffer.bindMemory(to: CChar.self).baseAddress!,
                        UInt64(password.count),
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress!,
                        argonOperations,
                        argonMemoryBytes,
                        argonAlgorithm
                    )
                }
            }
        }

        guard result == 0 else { throw VaultCryptoError.keyDerivationFailed }
        return output
    }

    static func deriveRecoveryKey(secret: Data, salt: Data) throws -> Data {
        guard secret.count == 16, salt.count == recoverySaltLength else {
            throw VaultCryptoError.invalidFormat
        }
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: secret),
            salt: salt,
            info: Data("vox-recovery-v1".utf8),
            outputByteCount: keyLength
        )
        return key.withUnsafeBytes { Data($0) }
    }

    static func seal(_ plaintext: Data, key: Data, authenticating aad: Data) throws -> SealedValue {
        let nonceData = try randomBytes(count: 12)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: nonce,
            authenticating: aad
        )
        return SealedValue(nonce: nonceData, ciphertext: sealed.ciphertext, tag: sealed.tag)
    }

    static func open(_ sealed: SealedValue, key: Data, authenticating aad: Data) throws -> Data {
        guard sealed.nonce.count == 12, sealed.tag.count == 16 else {
            throw VaultCryptoError.invalidFormat
        }
        let box = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )
        do {
            return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
        } catch {
            throw VaultCryptoError.authenticationFailed
        }
    }

    static func recoveryCode() throws -> (display: String, secret: Data) {
        let secret = try randomBytes(count: 16)
        let hex = secret.map { String(format: "%02X", $0) }.joined()
        let groups = stride(from: 0, to: hex.count, by: 8).map { start -> String in
            let lower = hex.index(hex.startIndex, offsetBy: start)
            let upper = hex.index(lower, offsetBy: 8)
            return String(hex[lower..<upper])
        }
        return (groups.joined(separator: "-"), secret)
    }

    static func recoverySecret(from input: String) -> Data? {
        let hex = input.uppercased().filter { $0.isHexDigit }
        guard hex.count == 32, let data = Data(hexString: hex), data.count == 16 else { return nil }
        return data
    }
}

enum VaultCryptoError: LocalizedError, Sendable {
    case randomGenerationFailed
    case cryptographicOperationFailed
    case keyDerivationFailed
    case invalidFormat
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed, .cryptographicOperationFailed:
            return "Não foi possível concluir uma operação criptográfica local."
        case .keyDerivationFailed:
            return "O dispositivo não conseguiu reservar memória para derivar a chave."
        case .invalidFormat:
            return "Os dados criptográficos têm um formato inválido."
        case .authenticationFailed:
            return "A autenticação dos dados cifrados falhou."
        }
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }
        var result = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        self = result
    }
}
