import Foundation

/// The one place a quote turns into digits.
///
/// Every surface used to carry its own rule, which is how the pairs list ended
/// up printing `398.348,0000` next to `5,9713` — the same column, one number
/// twice the width of the other and three of its decimals meaningless.
///
/// The locale follows the app's language — `5,6480` in Portuguese, `5.6480` in
/// English — and only the separators change with it. The rules for how many
/// decimals a magnitude gets are the same in every language.
public enum QuoteFormat {
    /// Below this, cents still carry movement; above it they are noise.
    private static let decimalCeiling = Decimal(1000)

    /// Below this, movement lives in the fourth decimal. An FX pair shown to
    /// two places looks frozen.
    private static let precisionCeiling = Decimal(10)

    /// Below this, four decimals stop carrying movement: CLP/BRL sits at
    /// 0,0051, and the fourth decimal is its first significant digit.
    private static let smallValueCeiling = Decimal(string: "0.1")!

    /// Above this the full number stops fitting in the menu bar.
    private static let abbreviationFloor = Decimal(100_000)

    /// Decimals by magnitude: six below 0,1, four below ten, two below a
    /// thousand, none above.
    /// Used by the panel, the pairs list and the alerts — everywhere the width
    /// is not disputed and precision is what the reader came for.
    public static func value(_ value: Decimal, locale: Locale = L10n.language.locale) -> String {
        fixed(value, fractionDigits: fractionDigits(for: value), locale: locale)
    }

    /// The menu bar's variant, which differs from `value` in two ways, both
    /// paid for by the ~22pt of width it shares with every other menu bar item:
    ///
    /// - it abbreviates above 100.000 (`398k`), and
    /// - it stops at two decimals, where the panel would show four — except
    ///   below one, where two decimals would print JPY/BRL as `0,04` and
    ///   CLP/BRL as `0,01`, a value that never moves.
    ///
    /// The second is a real divergence, not an oversight: a fourth decimal
    /// costs about as much width as the currency symbol, and the menu bar is
    /// the glance surface — the panel is a click away when the digit matters.
    public static func menuBar(_ value: Decimal, locale: Locale = L10n.language.locale) -> String {
        if value >= abbreviationFloor {
            return "\(fixed(value / 1000, fractionDigits: 0, locale: locale))k"
        }

        if value < 1 {
            return fixed(
                value, fractionDigits: value < smallValueCeiling ? 5 : 4, locale: locale)
        }

        return fixed(value, fractionDigits: value >= decimalCeiling ? 0 : 2, locale: locale)
    }

    /// Range bounds may abbreviate where the main value may not: the range is
    /// context, and `403k – 409k` reads faster than the full figures.
    public static func rangeBound(_ value: Decimal, locale: Locale = L10n.language.locale) -> String
    {
        if value >= decimalCeiling {
            return "\(fixed(value / 1000, fractionDigits: 0, locale: locale))k"
        }

        // Two decimals would collapse a CLP/BRL range to `0,01 – 0,01`.
        if value < 1 {
            return Self.value(value, locale: locale)
        }

        return fixed(value, fractionDigits: 2, locale: locale)
    }

    /// An amount with its currency in front: `R$ 5,6480`.
    public static func money(
        _ value: Decimal, currency: String, locale: Locale = L10n.language.locale
    ) -> String {
        "\(Currency.named(currency).moneySymbol) \(Self.value(value, locale: locale))"
    }

    /// An alert threshold as the person set it: `5,70`, not `5,7000`.
    ///
    /// Two decimals from one up, none from a thousand, four below one — but
    /// never fewer than the value carries, so a typed `5,6931` is not shown
    /// back as a rounded `5,69` it will not fire at.
    public static func threshold(_ value: Decimal, locale: Locale = L10n.language.locale) -> String
    {
        let floor: Int
        if value >= decimalCeiling {
            floor = 0
        } else if value >= 1 {
            floor = 2
        } else {
            floor = 4
        }
        return fixed(
            value, fractionDigits: min(max(floor, ownFractionDigits(value)), 6), locale: locale)
    }

    private static func ownFractionDigits(_ value: Decimal) -> Int {
        max(-value.exponent, 0)
    }

    /// Signed percentage, for surfaces where the sign is the only marker.
    public static func percent(_ change: Decimal, locale: Locale = L10n.language.locale) -> String {
        "\(change < 0 ? "-" : "+")\(percentMagnitude(change, locale: locale))"
    }

    /// Unsigned percentage, for surfaces that already carry a ▲/▼ — a sign
    /// beside an arrow says the same thing twice.
    public static func percentMagnitude(
        _ change: Decimal, locale: Locale = L10n.language.locale
    ) -> String {
        "\(fixed(abs(change), fractionDigits: 2, locale: locale))%"
    }

    /// Parses a number the way the alert and converter fields are typed, in
    /// either language: pt-BR grouping and a decimal comma (`1.000,50`), en
    /// grouping and a decimal point (`1,000.50`), or a plain `6.02`. Zero and below are rejected
    /// — they are not prices anyone would alert on.
    ///
    /// A lone separator followed by exactly three digits is ambiguous, and the
    /// language decides: in Portuguese `5.123` is grouping and `5,123` a
    /// decimal; in English, the other way round.
    public static func parseThreshold(
        _ text: String, locale: Locale = L10n.language.locale
    ) -> Decimal? {
        let groupsWithDot = locale.decimalSeparator != "."
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
        } else if let comma = lastComma {
            let fraction = trimmed[trimmed.index(after: comma)...]
            if !groupsWithDot, fraction.count == 3, fraction.allSatisfy(\.isNumber) {
                normalized = trimmed.replacingOccurrences(of: ",", with: "")
            } else if trimmed.filter({ $0 == "," }).count > 1 {
                return nil
            } else {
                normalized = trimmed.replacingOccurrences(of: ",", with: ".")
            }
        } else if let dot = lastDot {
            let fraction = trimmed[trimmed.index(after: dot)...]
            if groupsWithDot, fraction.count == 3, fraction.allSatisfy(\.isNumber) {
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
        if value < smallValueCeiling { return 6 }
        if value >= decimalCeiling { return 0 }
        return value >= precisionCeiling ? 2 : 4
    }

    private static func fixed(_ value: Decimal, fractionDigits: Int, locale: Locale) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .locale(locale)
        )
    }
}
