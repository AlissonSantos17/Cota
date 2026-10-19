import Foundation

/// The pairs Cota offers, and nothing the API would refuse.
///
/// AwesomeAPI serves a fixed list of pairs, not every combination of the
/// currencies it knows: `GBP-JPY` exists, `JPY-GBP` does not. Worse, one
/// unknown pair in a `last` request fails the whole batch with a 404, so a
/// single bad choice would blank every quote in the panel. Offering only pairs
/// taken from `/json/available` keeps that request from ever being built.
///
/// Kept in the binary rather than fetched: the list changes rarely, and a
/// fetch would add a request, a failure mode and a loading state to a menu
/// that has to open instantly.
public enum PairCatalog {
    /// Origin currencies in the order the Add pair menu shows them: the
    /// currencies most people follow first, crypto last.
    public static let currencies = [
        "BRL", "USD", "EUR", "GBP", "JPY",
        "CHF", "CAD", "AUD", "CNY", "ARS",
        "MXN", "CLP", "BTC", "ETH", "XRP",
    ]

    /// Destinations per origin, as listed by `/json/available` on 2026-10-16.
    private static let destinations: [String: [String]] = [
        "BRL": ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "CNY", "ARS", "MXN", "CLP"],
        "USD": ["BRL", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "CNY", "ARS", "MXN", "CLP"],
        "EUR": ["BRL", "USD", "GBP", "JPY", "CHF", "CAD", "AUD", "CNY", "ARS", "MXN", "CLP"],
        "GBP": ["BRL", "USD", "EUR", "JPY", "CHF", "AUD"],
        "JPY": ["BRL", "USD", "EUR"],
        "CHF": ["BRL", "USD", "EUR", "JPY"],
        "CAD": ["BRL", "USD", "EUR", "JPY"],
        "AUD": ["BRL", "USD", "EUR", "JPY", "CHF"],
        "CNY": ["BRL", "USD", "EUR", "JPY"],
        "ARS": ["BRL", "USD", "EUR", "CLP"],
        "MXN": ["BRL", "USD", "EUR"],
        "CLP": ["BRL", "USD", "EUR"],
        "BTC": ["BRL", "USD", "EUR"],
        "ETH": ["BRL", "USD", "EUR"],
        "XRP": ["BRL", "USD", "EUR"],
    ]

    public static func destinations(from origin: String) -> [String] {
        destinations[origin] ?? []
    }

    /// Every offered pair, origin by origin.
    public static var pairs: [String] {
        currencies.flatMap { origin in
            destinations(from: origin).map { "\(origin)-\($0)" }
        }
    }

    public static func contains(_ pair: String) -> Bool {
        let display = PairDisplay(id: pair)
        return destinations(from: display.base).contains(display.quote)
    }
}
