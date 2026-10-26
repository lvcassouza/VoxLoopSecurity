import CryptoKit
import Foundation

enum VaultChunkFormat {
    static let chunkSize = 1_048_576

    static func nonce(prefix: UInt32, counter: UInt64) -> Data {
        var prefix = prefix.bigEndian
        var counter = counter.bigEndian
        return withUnsafeBytes(of: &prefix) { prefixBytes in
            withUnsafeBytes(of: &counter) { counterBytes in
                Data(prefixBytes) + Data(counterBytes)
            }
        }
    }

    static func aad(id: UUID, counter: UInt64, length: UInt32) -> Data {
        var counter = counter.bigEndian
        var length = length.bigEndian
        return Data("vox.chunk.v1.\(id.uuidString)".utf8)
            + withUnsafeBytes(of: &counter) { Data($0) }
            + withUnsafeBytes(of: &length) { Data($0) }
    }
}

/// Authenticated, bounded range access to one encrypted item.
/// The DEK and file handle live only for the lifetime of this session.
public final class VaultMediaReadSession: @unchecked Sendable {
    public static let maximumReadSize = 1_048_576
    public let sessionID = UUID()
    public let item: ItemDoCofre
    public var size: Int64 { item.tamanhoBytes }

    private let lock = NSLock()
    private let encryptedURL: URL
    private let noncePrefix: UInt32
    private let chunkCount: UInt64
    private var dataKey: Data
    private var fileHandle: FileHandle?
    private var valid = true

    init(
        encryptedURL: URL,
        item: ItemDoCofre,
        noncePrefix: UInt32,
        chunkCount: UInt64,
        dataKey: Data
    ) throws {
        self.encryptedURL = encryptedURL
        self.item = item
        self.noncePrefix = noncePrefix
        self.chunkCount = chunkCount
        self.dataKey = Data(dataKey)

        guard item.tamanhoBytes >= 0,
              chunkCount <= UInt64(Int64.max),
              dataKey.count == VaultCrypto.keyLength else {
            throw VaultError.dadoAdulterado
        }
        let expectedChunkCount = item.tamanhoBytes == 0
            ? 0
            : UInt64((item.tamanhoBytes - 1) / Int64(VaultChunkFormat.chunkSize) + 1)
        guard expectedChunkCount == chunkCount else { throw VaultError.dadoAdulterado }

        let attributes = try FileManager.default.attributesOfItem(atPath: encryptedURL.path)
        let encryptedSize = (attributes[.size] as? NSNumber)?.int64Value
        let (overhead, overheadOverflow) = Int64(chunkCount).multipliedReportingOverflow(by: 20)
        let (expectedSize, sizeOverflow) = item.tamanhoBytes.addingReportingOverflow(overhead)
        guard !overheadOverflow, !sizeOverflow, encryptedSize == expectedSize else {
            throw VaultError.dadoAdulterado
        }
        self.fileHandle = try FileHandle(forReadingFrom: encryptedURL)
    }

    /// Returns authenticated plaintext for no more than one 1 MiB interval.
    /// Larger consumers must request bounded pieces with `copyBytes(in:to:)`.
    public func read(range: Range<Int64>) throws -> Data {
        guard range.lowerBound >= 0,
              range.upperBound >= range.lowerBound,
              range.upperBound <= size else {
            throw VaultError.intervaloDeLeituraInvalido
        }
        let length = range.upperBound - range.lowerBound
        guard length <= Int64(VaultChunkFormat.chunkSize) else {
            throw VaultError.intervaloDeLeituraInvalido
        }
        guard length > 0 else { return Data() }

        lock.lock()
        defer { lock.unlock() }
        guard valid, let fileHandle, dataKey.count == VaultCrypto.keyLength else {
            throw VaultError.cofreBloqueado
        }

        var plaintext = Data()
        plaintext.reserveCapacity(Int(length))
        var cursor = range.lowerBound

        while cursor < range.upperBound {
            let chunkIndex = UInt64(cursor / Int64(VaultChunkFormat.chunkSize))
            guard chunkIndex < chunkCount,
                  chunkIndex <= UInt64(Int64.max / Int64(VaultChunkFormat.chunkSize)) else {
                throw VaultError.dadoAdulterado
            }
            let chunkStart = Int64(chunkIndex) * Int64(VaultChunkFormat.chunkSize)
            let expectedLength = Int(min(Int64(VaultChunkFormat.chunkSize), size - chunkStart))
            let (fileOffset, offsetOverflow) = chunkIndex.multipliedReportingOverflow(by: UInt64(VaultChunkFormat.chunkSize + 20))
            guard !offsetOverflow, expectedLength > 0 else { throw VaultError.dadoAdulterado }

            try fileHandle.seek(toOffset: fileOffset)
            let header = try readExactly(4, from: fileHandle)
            let storedLength = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard storedLength == UInt32(expectedLength) else { throw VaultError.dadoAdulterado }

            let encryptedChunk = try readExactly(expectedLength + 16, from: fileHandle)
            let box = VaultCrypto.SealedValue(
                nonce: VaultChunkFormat.nonce(prefix: noncePrefix, counter: chunkIndex),
                ciphertext: Data(encryptedChunk.prefix(expectedLength)),
                tag: Data(encryptedChunk.suffix(16))
            )
            let clearChunk: Data
            do {
                clearChunk = try VaultCrypto.open(
                    box,
                    key: dataKey,
                    authenticating: VaultChunkFormat.aad(
                        id: item.id,
                        counter: chunkIndex,
                        length: storedLength
                    )
                )
            } catch {
                throw VaultError.dadoAdulterado
            }
            guard clearChunk.count == expectedLength else { throw VaultError.dadoAdulterado }

            let lowerInChunk = Int(cursor - chunkStart)
            let bytesAvailable = min(Int64(expectedLength - lowerInChunk), range.upperBound - cursor)
            let upperInChunk = lowerInChunk + Int(bytesAvailable)
            plaintext.append(clearChunk[lowerInChunk..<upperInChunk])
            cursor += bytesAvailable
        }

        guard plaintext.count == Int(length) else { throw VaultError.dadoAdulterado }
        return plaintext
    }

    /// Copies a possibly large interval to a caller-owned buffer in bounded pieces.
    @discardableResult
    public func copyBytes(in range: Range<Int64>, to buffer: UnsafeMutableRawBufferPointer) throws -> Int {
        guard range.lowerBound >= 0,
              range.upperBound >= range.lowerBound,
              range.upperBound <= size else {
            throw VaultError.intervaloDeLeituraInvalido
        }
        let length = range.upperBound - range.lowerBound
        guard length <= Int64(buffer.count) else { throw VaultError.intervaloDeLeituraInvalido }
        guard length > 0 else { return 0 }
        guard let destination = buffer.baseAddress else { throw VaultError.intervaloDeLeituraInvalido }

        var cursor = range.lowerBound
        var copied = 0
        while cursor < range.upperBound {
            let amount = min(range.upperBound - cursor, Int64(VaultChunkFormat.chunkSize))
            let end = cursor + amount
            let bytes = try read(range: cursor..<end)
            _ = bytes.copyBytes(
                to: UnsafeMutableBufferPointer(
                    start: destination.advanced(by: copied).assumingMemoryBound(to: UInt8.self),
                    count: bytes.count
                )
            )
            copied += bytes.count
            cursor = end
        }
        return copied
    }

    /// Streams authenticated plaintext to a protected, backup-excluded temporary file.
    public func exportDecryptedFile(to destinationURL: URL) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw VaultError.exportacaoTemporariaJaExiste
        }
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard fileManager.createFile(atPath: destinationURL.path, contents: nil) else {
            throw VaultError.falhaNaExportacao
        }

        do {
            try VaultTemporaryStorageProtection.apply(to: destinationURL)
            let output = try FileHandle(forWritingTo: destinationURL)
            do {
                var offset: Int64 = 0
                while offset < size {
                    let amount = min(size - offset, Int64(VaultChunkFormat.chunkSize))
                    let end = offset + amount
                    let bytes = try read(range: offset..<end)
                    try output.write(contentsOf: bytes)
                    offset = end
                }
                try output.synchronize()
                try output.close()
            } catch {
                try? output.close()
                throw error
            }
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    /// Invalidates future reads, closes the file descriptor, and clears the owned key buffer best-effort.
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        guard valid else { return }
        valid = false
        let count = dataKey.count
        if count > 0 {
            dataKey.resetBytes(in: 0..<count)
        }
        dataKey = Data()
        try? fileHandle?.close()
        fileHandle = nil
    }

    deinit {
        invalidate()
    }

    private func readExactly(_ count: Int, from fileHandle: FileHandle) throws -> Data {
        var bytes = Data()
        bytes.reserveCapacity(count)
        while bytes.count < count {
            guard let next = try fileHandle.read(upToCount: count - bytes.count), !next.isEmpty else {
                throw VaultError.dadoAdulterado
            }
            bytes.append(next)
        }
        return bytes
    }
}
