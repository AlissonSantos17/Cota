import Foundation

public struct PriceAlert: Codable, Identifiable, Equatable {
    public var id: UUID
    public var pair: String
    public var threshold: Decimal
    public var isAbove: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        pair: String,
        threshold: Decimal,
        isAbove: Bool,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.pair = pair
        self.threshold = threshold
        self.isAbove = isAbove
        self.isEnabled = isEnabled
    }

    /// "EUR/BRL above R$ 5.70", as the alerts list reads it.
    public var label: String {
        let display = PairDisplay(id: pair)
        let amount =
            "\(Currency.named(display.quote).moneySymbol) \(QuoteFormat.threshold(threshold))"
        return L10n.t(isAbove ? "alerts.row.above" : "alerts.row.below", display.text, amount)
    }

    /// Signed distance from `bid` to the threshold, in percent of `bid`.
    public func distance(from bid: Decimal) -> Decimal {
        guard bid != 0 else { return 0 }
        return (threshold - bid) / bid * 100
    }

    /// Whether `bid` is already on the side the alert waits for, so it would
    /// fire on the next check.
    public func isPast(_ bid: Decimal) -> Bool {
        isAbove ? bid >= threshold : bid <= threshold
    }

    /// The threshold the panel's New alert button proposes: 0,8% above the
    /// current value, rounded to what a person would type — no decimals from a
    /// thousand, two from one, four below.
    public static func suggestedThreshold(for bid: Decimal) -> Decimal {
        let target = bid * Decimal(string: "1.008")!
        let scale: Int
        if bid >= 1000 {
            scale = 0
        } else if bid >= 1 {
            scale = 2
        } else {
            scale = 4
        }
        var input = target
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, scale, .plain)
        return rounded
    }
}
