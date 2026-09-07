import Foundation

/// The one place a quote turns into digits.
///
/// Every surface used to carry its own rule, which is how the pairs list ended
/// up printing `398.348,0000` next to `5,9713` — the same column, one number
/// twice the width of the other and three of its decimals meaningless.
public enum QuoteFormat {
    private static let locale = Locale(identifier: "pt_BR")

    /// Below this, cents still carry movement; above it they are noise.
    private static let decimalCeiling = Decimal(1000)

    /// Below this, movement lives in the fourth decimal. An FX pair shown to
    /// two places looks frozen.
    private static let precisionCeiling = Decimal(10)

    /// Above this the full number stops fitting in the menu bar.
    private static let abbreviationFloor = Decimal(100_000)

    /// Decimals by magnitude: four below ten, two below a thousand, none above.
    /// Used by the panel, the pairs list and the alerts — everywhere the width
    /// is not disputed and precision is what the reader came for.
    public static func value(_ value: Decimal) -> String {
        fixed(value, fractionDigits: fractionDigits(for: value))
    }

    /// The menu bar's variant, which differs from `value` in two ways, both
    /// paid for by the ~22pt of width it shares with every other menu bar item:
    ///
    /// - it abbreviates above 100.000 (`398k`), and
    /// - it stops at two decimals, where the panel would show four.
    ///
    /// The second is a real divergence, not an oversight: a fourth decimal
    /// costs about as much width as the currency symbol, and the menu bar is
    /// the glance surface — the panel is a click away when the digit matters.
    public static func menuBar(_ value: Decimal) -> String {
        if value >= abbreviationFloor {
            return "\(fixed(value / 1000, fractionDigits: 0))k"
        }

        return fixed(value, fractionDigits: value >= decimalCeiling ? 0 : 2)
    }

    /// Range bounds may abbreviate where the main value may not: the range is
    /// context, and `403k – 409k` reads faster than the full figures.
    public static func rangeBound(_ value: Decimal) -> String {
        if value >= decimalCeiling {
            return "\(fixed(value / 1000, fractionDigits: 0))k"
        }

        return fixed(value, fractionDigits: 2)
    }

    /// Signed percentage, for surfaces where the sign is the only marker.
    public static func percent(_ change: Decimal) -> String {
        "\(change < 0 ? "-" : "+")\(percentMagnitude(change))"
    }

    /// Unsigned percentage, for surfaces that already carry a ▲/▼ — a sign
    /// beside an arrow says the same thing twice.
    public static func percentMagnitude(_ change: Decimal) -> String {
        "\(fixed(abs(change), fractionDigits: 2))%"
    }

    /// Parses a threshold the way the alerts field is typed: pt-BR grouping
    /// and a decimal comma, plus a plain `6.02`. Zero and below are rejected
    /// — they are not prices anyone would alert on.
    public static func parseThreshold(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lastComma = trimmed.lastIndex(of: ",")
        let lastDot = trimmed.lastIndex(of: ".")

        let normalized: String
        if let comma = lastComma, let dot = lastDot {
            if comma > dot {
                normalized =
                    trimmed
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = trimmed.replacingOccurrences(of: ",", with: "")
            }
        } else if lastComma != nil {
            normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        } else if let dot = lastDot {
            let fraction = trimmed[trimmed.index(after: dot)...]
            if fraction.count == 3, fraction.allSatisfy(\.isNumber) {
                normalized = trimmed.replacingOccurrences(of: ".", with: "")
            } else if trimmed.filter({ $0 == "." }).count > 1 {
                return nil
            } else {
                normalized = trimmed
            }
        } else {
            normalized = trimmed
        }

        // Validated before parsing, not after: `Decimal(string:)` accepts a
        // prefix and discards the rest, so `5abc` came back as a perfectly
        // valid 5 and `1e5` as 100.000. A threshold nobody typed is worse than
        // a rejected one — the Add button lit up either way.
        guard isPlainNumber(normalized), let value = Decimal(string: normalized), value > 0
        else {
            return nil
        }
        return value
    }

    /// Digits, at most one dot, and a digit on either side of it.
    private static func isPlainNumber(_ text: String) -> Bool {
        var seenDot = false
        var digitsBeforeDot = 0
        var digitsAfterDot = 0

        for character in text {
            if character.isASCII, character.isNumber {
                if seenDot {
                    digitsAfterDot += 1
                } else {
                    digitsBeforeDot += 1
                }
            } else if character == ".", !seenDot {
                seenDot = true
            } else {
                return false
            }
        }

        return digitsBeforeDot > 0 && (!seenDot || digitsAfterDot > 0)
    }

    private static func fractionDigits(for value: Decimal) -> Int {
        if value >= decimalCeiling { return 0 }
        return value >= precisionCeiling ? 2 : 4
    }

    private static func fixed(_ value: Decimal, fractionDigits: Int) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .locale(locale)
        )
    }
}
