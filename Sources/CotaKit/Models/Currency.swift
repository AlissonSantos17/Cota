import Foundation

/// What a label needs to know about a currency in order to name it.
///
/// Kept apart from `Quote`, which mirrors the API payload: a menu bar label has
/// to be buildable for a pair the user just selected but that no fetch has
/// returned yet.
public struct Currency: Equatable, Sendable {
    public let code: String

    /// Nil when the currency has no glyph of its own. Absence is a fixed
    /// property of the currency, not of the current selection, so a label may
    /// fall back for one pair while the others keep their glyph.
    public let symbol: String?

    /// Nil for crypto and anything else without an issuing country.
    public let flag: String?

    public init(code: String, symbol: String? = nil, flag: String? = nil) {
        self.code = code
        self.symbol = symbol
        self.flag = flag
    }
}

extension Currency {
    public static func named(_ code: String) -> Currency {
        table[code] ?? Currency(code: code)
    }

    /// Symbols are shared here exactly where the real world shares them: the
    /// `auto` format finds its collisions in this table, so mapping CAD to
    /// anything other than "$" would hide the very ambiguity the lookup exists
    /// to catch.
    private static let table: [String: Currency] = [
        "BRL": Currency(code: "BRL", symbol: "R$", flag: "🇧🇷"),
        "EUR": Currency(code: "EUR", symbol: "€", flag: "🇪🇺"),
        "USD": Currency(code: "USD", symbol: "$", flag: "🇺🇸"),
        "CAD": Currency(code: "CAD", symbol: "$", flag: "🇨🇦"),
        "AUD": Currency(code: "AUD", symbol: "$", flag: "🇦🇺"),
        "ARS": Currency(code: "ARS", symbol: "$", flag: "🇦🇷"),
        "GBP": Currency(code: "GBP", symbol: "£", flag: "🇬🇧"),
        "JPY": Currency(code: "JPY", symbol: "¥", flag: "🇯🇵"),
        "CNY": Currency(code: "CNY", symbol: "¥", flag: "🇨🇳"),
        "CHF": Currency(code: "CHF", symbol: "₣", flag: "🇨🇭"),
        "BTC": Currency(code: "BTC", symbol: "₿"),
        "ETH": Currency(code: "ETH", symbol: "Ξ"),
        // No glyph: "✕" is a multiplication sign, and passing it off as a
        // currency symbol would put a wrong label in the menu bar.
        "XRP": Currency(code: "XRP"),
    ]
}
