import Foundation

/// The one place a pair ID turns into a label.
///
/// Persistence and the API keep the hyphen (`EUR-BRL`). Every surface that
/// shows the pair to a person uses a slash (`EUR/BRL`), so the separator
/// cannot drift between the panel, the pairs list and the alerts.
public struct PairDisplay: Equatable {
    public let base: String
    public let quote: String

    public init(id: String) {
        let parts = id.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            base = String(parts[0])
            quote = String(parts[1])
        } else {
            base = id
            quote = ""
        }
    }

    public init(base: String, quote: String) {
        self.base = base
        self.quote = quote
    }

    public var text: String {
        quote.isEmpty ? base : "\(base)/\(quote)"
    }
}
