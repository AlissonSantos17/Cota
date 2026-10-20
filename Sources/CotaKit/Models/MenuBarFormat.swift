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
        // `auto` is presented as "Symbol": it shows symbols whenever they are
        // unambiguous and falls back to codes, with a note, when they are not.
        case .auto: return L10n.t("menuBar.format.symbol")
        case .code: return L10n.t("menuBar.format.code")
        case .flag: return L10n.t("menuBar.format.flag")
        case .value: return L10n.t("menuBar.format.valueOnly")
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
        case .none: return L10n.t("menuBar.change.none")
        case .arrow: return L10n.t("menuBar.change.arrow")
        case .percent: return L10n.t("menuBar.change.percent")
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
