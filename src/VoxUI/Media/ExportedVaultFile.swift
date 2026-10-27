import CoreTransferable
import Foundation
import UniformTypeIdentifiers
#if canImport(VoxDomain)
import VoxDomain
#endif

struct ExportedVaultFile: Identifiable, Transferable {
    let prepared: ArquivoPreparadoParaExportacao

    var id: UUID { prepared.id }
    var contentType: UTType {
        let ext = URL(fileURLWithPath: prepared.nomeArquivo).pathExtension
        if let type = UTType(filenameExtension: ext), type.conforms(to: prepared.tipo == .foto ? .image : .movie) {
            return type
        }
        return prepared.tipo == .foto ? .image : .movie
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .image) { item in
            SentTransferredFile(item.prepared.url)
        }
        .exportingCondition { $0.contentType.conforms(to: .image) }

        FileRepresentation(exportedContentType: .movie) { item in
            SentTransferredFile(item.prepared.url)
        }
        .exportingCondition { $0.contentType.conforms(to: .movie) }
    }
}
