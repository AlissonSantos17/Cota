import SwiftUI
import UniformTypeIdentifiers

/// A drag that is only a pair ID, so the drop target does not light up for
/// arbitrary text from other apps.
struct PairPayload: Codable, Transferable {
    let pair: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cotaPair)
    }
}

extension UTType {
    /// Matches the `UTExportedTypeDeclarations` entry in Info.plist, which is
    /// what `exportedAs` expects to find. It also has to sit under the bundle
    /// identifier: a type in someone else's reverse-DNS space is not ours to
    /// export.
    static var cotaPair: UTType {
        UTType(exportedAs: "com.alissonfelp.Cota.pair")
    }
}
