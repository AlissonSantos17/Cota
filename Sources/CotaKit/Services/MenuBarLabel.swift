import Foundation

/// One pair as the menu bar sees it: enough to draw a label, and nothing that
/// ties it to a fetch, so the Settings preview can feed it sample values.
public struct MenuBarQuote: Equatable, Sendable {
    public let pair: String
    public let bid: Decimal
    public let change: Decimal?

    public init(pair: String, bid: Decimal, change: Decimal?) {
        self.pair = pair
        self.bid = bid
        self.change = change
    }

    /// Origin currency. The destination is constant (BRL) and never labelled.
    public var code: String {
        pair.split(separator: "-").first.map(String.init) ?? pair
    }

    public var currency: Currency {
        .named(code)
    }
}

/// A run of text in a menu bar label, tagged with what it is rather than how it
/// looks. The menu bar renderer and the Settings preview both read these, which
/// is what keeps the preview honest.
public struct LabelSegment: Equatable, Sendable {
    public enum Role: Equatable, Sendable {
        /// A symbol or flag: stays at the size of the number. It is a single
        /// glyph, and shrinking it makes it illegible.
        case lead
        /// A currency code: one point smaller, secondary colour, so the number
        /// stays the dominant element.
        case code
        case value
        /// The only run that carries colour. A coloured number fights the
        /// system tint and reads badly over a light or busy wallpaper.
        case indicator(Trend)
        case separator
    }

    public let text: String
    public let role: Role

    public init(_ text: String, _ role: Role) {
        self.text = text
        self.role = role
    }
}

/// A symbol claimed by more than one of the selected currencies.
public struct SymbolCollision: Equatable, Sendable {
    public let symbol: String
    public let codes: [String]
}

public enum MenuBarLabel {
    /// Triple space. Two pairs sit comfortably; a comma or a bullet reads as
    /// punctuation belonging to the number next to it.
    public static let pairSeparator = "\u{2007}\u{2007}\u{2007}"

    /// Digit-width space, so padding lines up with tabular figures.
    private static let figureSpace = "\u{2007}"

    /// Tabular digits are not enough on their own: 9,99 going to 10,01 changes
    /// the character count and shoves every icon to its left. Values are padded
    /// to this width so that step costs nothing.
    private static let minimumValueWidth = 5

    // MARK: - Label

    /// How long the bar keeps the app name after launch, even if quotes
    /// arrived sooner. The renderer turns empty segments into "Cota".
    public static let launchHold: Duration = .seconds(2)

    /// Crossfade from the name to the quote. Short enough to read as one
    /// motion, long enough that the two labels do not pop.
    public static let launchReveal: Duration = .milliseconds(350)

    /// Smoothstep. The fade is still at both ends, so neither label pops.
    public static func launchBlend(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    public static func launchWidth(from: Double, to: Double, progress: Double) -> Double {
        from + (to - from) * launchBlend(progress)
    }

    public static func segments(
        for quotes: [MenuBarQuote],
        format: MenuBarFormat,
        indicator: ChangeIndicator,
        holdActive: Bool = false
    ) -> [LabelSegment] {
        if holdActive {
            return []
        }

        let format = effectiveFormat(format, pairCount: quotes.count)
        let useCodes =
            format == .code
            || (format == .auto && firstCollision(among: quotes.map(\.code)) != nil)

        var segments: [LabelSegment] = []

        for quote in quotes {
            if !segments.isEmpty {
                segments.append(LabelSegment(pairSeparator, .separator))
            }

            segments.append(contentsOf: lead(for: quote, format: format, useCodes: useCodes))
            segments.append(LabelSegment(formattedValue(quote.bid), .value))
            segments.append(contentsOf: tail(for: quote, indicator: indicator))
        }

        return segments
    }

    /// One pair rendered the way a given format would render it, judged against
    /// the collisions of the whole selection rather than of that pair alone.
    ///
    /// `effectiveFormat` is deliberately not applied: the example beside "Value
    /// only" has to show what the option would do, including while it is
    /// disabled and explaining why.
    public static func exampleSegments(
        for quote: MenuBarQuote,
        format: MenuBarFormat,
        among codes: [String]
    ) -> [LabelSegment] {
        let useCodes =
            format == .code
            || (format == .auto && firstCollision(among: codes) != nil)

        return lead(for: quote, format: format, useCodes: useCodes)
            + [LabelSegment(formattedValue(quote.bid), .value)]
    }

    private static func lead(
        for quote: MenuBarQuote,
        format: MenuBarFormat,
        useCodes: Bool
    ) -> [LabelSegment] {
        let currency = quote.currency

        func code() -> [LabelSegment] {
            [LabelSegment(currency.code, .code), LabelSegment(" ", .separator)]
        }

        func glyph(_ text: String) -> [LabelSegment] {
            [LabelSegment(text, .lead), LabelSegment(" ", .separator)]
        }

        switch format {
        case .value:
            return []

        case .flag:
            // Crypto has no issuing country. Without this the menu bar shows an
            // empty box and looks broken.
            if let flag = currency.flag {
                return glyph(flag)
            }
            return currency.symbol.map(glyph) ?? code()

        case .code:
            return code()

        case .auto:
            if useCodes {
                return code()
            }
            return currency.symbol.map(glyph) ?? code()
        }
    }

    private static func tail(
        for quote: MenuBarQuote,
        indicator: ChangeIndicator
    ) -> [LabelSegment] {
        guard indicator != .none, let change = quote.change else {
            return []
        }

        let trend = Trend(change)

        switch indicator {
        case .none:
            return []

        case .arrow:
            guard let arrow = arrow(for: trend) else { return [] }
            return [LabelSegment(" ", .separator), LabelSegment(arrow, .indicator(trend))]

        case .percent:
            return [
                LabelSegment(" ", .separator),
                LabelSegment(formattedPercent(change), .indicator(trend)),
            ]
        }
    }

    /// Shape, not just colour: the arrow has to communicate direction to a
    /// colourblind reader and against a tinted menu bar.
    private static func arrow(for trend: Trend) -> String? {
        switch trend {
        case .up: return "▴"
        case .down: return "▾"
        case .flat: return nil
        }
    }

    // MARK: - Rules

    /// `value` needs a single pair: `6,02 5,19` with no labels cannot be told
    /// apart. The option stays visible and explains itself rather than
    /// disappearing from the list.
    public static func effectiveFormat(_ format: MenuBarFormat, pairCount: Int) -> MenuBarFormat {
        format == .value && pairCount > 1 ? .auto : format
    }

    public static func disabledReason(for format: MenuBarFormat, pairCount: Int) -> String? {
        guard format == .value, pairCount > 1 else { return nil }
        return "Available with a single pair — two values with no labels can't be told apart."
    }

    /// The first symbol claimed by two or more of the given currencies.
    ///
    /// Only the first is reported: the help line built from it has to fit in
    /// two lines of text.
    public static func firstCollision(among codes: [String]) -> SymbolCollision? {
        var order: [String] = []
        var claimants: [String: [String]] = [:]

        for code in codes {
            guard let symbol = Currency.named(code).symbol else { continue }
            if claimants[symbol] == nil {
                order.append(symbol)
                claimants[symbol] = []
            }
            if !claimants[symbol]!.contains(code) {
                claimants[symbol]!.append(code)
            }
        }

        for symbol in order where claimants[symbol]!.count > 1 {
            return SymbolCollision(symbol: symbol, codes: claimants[symbol]!)
        }

        return nil
    }

    /// Why `auto` is showing the same thing as `code`. Without it the two rows
    /// look identical and "Automatic" reads as broken; with it the coincidence
    /// becomes information, and the user can see that unchecking one pair
    /// brings the symbol back.
    public static func collisionNote(among codes: [String]) -> String? {
        guard let collision = firstCollision(among: codes) else { return nil }

        let names: String
        if collision.codes.count == 2 {
            names = "\(collision.codes[0]) and \(collision.codes[1]) both"
        } else {
            let head = collision.codes.dropLast().joined(separator: ", ")
            names = "\(head) and \(collision.codes[collision.codes.count - 1]) all"
        }

        return "Using codes — \(names) use the \(collision.symbol) symbol."
    }

    // MARK: - Numbers

    /// The shared rule, plus the padding that only the menu bar needs: nothing
    /// else on screen moves when a value gains a digit.
    public static func formattedValue(_ bid: Decimal) -> String {
        padded(QuoteFormat.menuBar(bid))
    }

    /// Signed here: the percent indicator stands alone, with no arrow beside it
    /// to carry the direction.
    public static func formattedPercent(_ change: Decimal) -> String {
        QuoteFormat.percent(change)
    }

    private static func padded(_ text: String) -> String {
        guard text.count < minimumValueWidth else { return text }
        return String(repeating: figureSpace, count: minimumValueWidth - text.count) + text
    }
}
