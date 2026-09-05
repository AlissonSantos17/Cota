import Foundation

/// How each pair is labelled in the menu bar.
///
/// There is deliberately no `symbol` option. Most symbols are shared — `$`
/// alone covers USD, CAD, AUD, ARS and more — so a manual choice of symbol
/// fails silently: `$ 5,19` looks correct while naming the wrong currency, in
/// a surface nobody revisits after configuring it. `auto` gives the same
/// compactness in the common case and falls back to codes when it cannot.
public enum MenuBarFormat: String, CaseIterable, Identifiable, Sendable {
    case auto
    case code
    case flag
    case value

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .auto: return "Automatic"
        case .code: return "Currency code"
        case .flag: return "Flag"
        case .value: return "Value only"
        }
    }
}

/// What follows the number: nothing, a direction, or the percentage itself.
public enum ChangeIndicator: String, CaseIterable, Identifiable, Sendable {
    case none
    case arrow
    case percent

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return "None"
        case .arrow: return "Arrow"
        case .percent: return "Percent"
        }
    }
}

/// Direction of the change across the selected period.
public enum Trend: Equatable, Sendable {
    case up
    case down
    case flat

    public init(_ change: Decimal) {
        if change > 0 {
            self = .up
        } else if change < 0 {
            self = .down
        } else {
            self = .flat
        }
    }
}
