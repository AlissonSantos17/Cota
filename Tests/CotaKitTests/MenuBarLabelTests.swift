import Foundation
import Testing

@testable import CotaKit

@Suite
struct MenuBarLabelTests {
    private func quote(_ pair: String, _ bid: String, change: String? = nil) -> MenuBarQuote {
        MenuBarQuote(
            pair: pair,
            bid: Decimal(string: bid)!,
            change: change.flatMap { Decimal(string: $0) }
        )
    }

    private func unpadded(_ bid: String) -> String {
        MenuBarLabel.formattedValue(Decimal(string: bid)!)
            .replacingOccurrences(of: "\u{2007}", with: "")
    }

    private func text(_ segments: [LabelSegment]) -> String {
        segments.map(\.text).joined()
            .replacingOccurrences(of: "\u{2007}", with: "")
    }

    // MARK: - Automatic

    @Test func autoUsesTheSymbolWhenItIsUnique() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02")],
            format: .auto,
            indicator: .none
        )

        #expect(text(segments) == "€ 6,02")
    }

    @Test func autoKeepsSymbolsForDistinctCurrencies() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02"), quote("USD-BRL", "5.19")],
            format: .auto,
            indicator: .none
        )

        #expect(text(segments).contains("€ 6,02"))
        #expect(text(segments).contains("$ 5,19"))
    }

    /// The fallback is global: mixing "USD 5,19" with "€ 6,02" puts two
    /// conventions on one line and reads worse than either one pure.
    @Test func aCollisionSendsEveryPairToItsCode() {
        let segments = MenuBarLabel.segments(
            for: [quote("USD-BRL", "5.19"), quote("CAD-BRL", "3.80"), quote("EUR-BRL", "6.02")],
            format: .auto,
            indicator: .none
        )

        let label = text(segments)
        #expect(label.contains("USD 5,19"))
        #expect(label.contains("CAD 3,80"))
        #expect(label.contains("EUR 6,02"))
        #expect(!label.contains("€"))
    }

    @Test func collisionNoteNamesTheCurrenciesResponsible() {
        #expect(
            MenuBarLabel.collisionNote(among: ["USD", "CAD"])
                == "Using codes — USD and CAD both use the $ symbol."
        )
        #expect(
            MenuBarLabel.collisionNote(among: ["USD", "CAD", "AUD"])
                == "Using codes — USD, CAD and AUD all use the $ symbol."
        )
        #expect(MenuBarLabel.collisionNote(among: ["EUR", "USD"]) == nil)
    }

    @Test func onlyTheFirstCollisionIsReported() {
        let collision = MenuBarLabel.firstCollision(among: ["JPY", "CNY", "USD", "CAD"])
        #expect(collision?.symbol == "¥")
        #expect(collision?.codes == ["JPY", "CNY"])
    }

    /// A currency with no symbol falls back on its own, unlike a collision:
    /// absence is a fixed property of the currency, so it cannot change under
    /// the user without them touching the selection.
    @Test func aCurrencyWithoutASymbolFallsBackAlone() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02"), quote("XRP-BRL", "12.40")],
            format: .auto,
            indicator: .none
        )

        let label = text(segments)
        #expect(label.contains("€ 6,02"))
        #expect(label.contains("XRP 12,40"))
    }

    // MARK: - Flag

    @Test func flagUsesTheOriginCountryOnly() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02")],
            format: .flag,
            indicator: .none
        )

        #expect(text(segments) == "🇪🇺 6,02")
        #expect(!text(segments).contains("🇧🇷"))
    }

    /// Crypto has no issuing country; without the fallback the menu bar shows
    /// an empty box and looks like a bug.
    @Test func cryptoFallsBackToItsSymbol() {
        let segments = MenuBarLabel.segments(
            for: [quote("BTC-BRL", "405884")],
            format: .flag,
            indicator: .none
        )

        #expect(text(segments) == "₿ 406k")
    }

    @Test func withoutFlagOrSymbolTheCodeIsUsed() {
        let segments = MenuBarLabel.segments(
            for: [quote("XRP-BRL", "12.40")],
            format: .flag,
            indicator: .none
        )

        #expect(text(segments) == "XRP 12,40")
    }

    /// Only the pair that lacks a flag changes; the others keep theirs.
    @Test func theFlagFallbackIsPerPair() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02"), quote("BTC-BRL", "405884")],
            format: .flag,
            indicator: .none
        )

        let label = text(segments)
        #expect(label.contains("🇪🇺 6,02"))
        #expect(label.contains("₿ 406k"))
    }

    // MARK: - Value only

    @Test func valueOnlyDropsEveryLabel() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02")],
            format: .value,
            indicator: .none
        )

        #expect(text(segments) == "6,02")
    }

    @Test func valueOnlyIsUnavailableWithTwoPairs() {
        #expect(MenuBarLabel.effectiveFormat(.value, pairCount: 2) == .auto)
        #expect(MenuBarLabel.effectiveFormat(.value, pairCount: 1) == .value)
        #expect(MenuBarLabel.disabledReason(for: .value, pairCount: 2) != nil)
        #expect(MenuBarLabel.disabledReason(for: .value, pairCount: 1) == nil)
    }

    // MARK: - Indicator

    @Test func theArrowCarriesDirectionByShape() {
        let up = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02", change: "0.19")],
            format: .value,
            indicator: .arrow
        )
        let down = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02", change: "-0.48")],
            format: .value,
            indicator: .arrow
        )

        #expect(text(up).hasSuffix("▴"))
        #expect(text(down).hasSuffix("▾"))
    }

    /// Colour lives on the indicator and nowhere else: a coloured number fights
    /// the system tint.
    @Test func onlyTheIndicatorIsColoured() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02", change: "0.19")],
            format: .auto,
            indicator: .arrow
        )

        let coloured = segments.filter {
            if case .indicator = $0.role { return true }
            return false
        }

        #expect(coloured.count == 1)
        #expect(coloured.first?.text == "▴")
    }

    @Test func percentIndicatorIsSigned() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02", change: "-0.02")],
            format: .value,
            indicator: .percent
        )

        #expect(text(segments) == "6,02 -0,02%")
    }

    @Test func noChangeMeansNoIndicator() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02")],
            format: .value,
            indicator: .arrow
        )

        #expect(text(segments) == "6,02")
    }

    // MARK: - Examples beside each option

    /// The example has to be judged against the whole selection, not against
    /// the one pair it shows: EUR alone has a unique symbol, but not once USD
    /// and CAD are in the list forcing every pair to its code.
    @Test func examplesReflectTheCollisionsOfTheWholeSelection() {
        let eur = quote("EUR-BRL", "6.02")

        #expect(
            text(MenuBarLabel.exampleSegments(for: eur, format: .auto, among: ["EUR"]))
                == "€ 6,02"
        )
        #expect(
            text(
                MenuBarLabel.exampleSegments(
                    for: eur,
                    format: .auto,
                    among: ["EUR", "USD", "CAD"]
                )) == "EUR 6,02"
        )
    }

    /// "Value only" still shows what it would do while it is disabled — that is
    /// what makes the explanation next to it legible.
    @Test func theValueOnlyExampleSurvivesBeingDisabled() {
        let eur = quote("EUR-BRL", "6.02")

        #expect(
            text(MenuBarLabel.exampleSegments(for: eur, format: .value, among: ["EUR", "USD"]))
                == "6,02"
        )
    }

    // MARK: - Numbers

    @Test func largeValuesAreAbbreviated() {
        #expect(unpadded("405884") == "406k")
        #expect(unpadded("99999") == "99.999")
        #expect(unpadded("6.0214") == "6,02")
    }

    /// Tabular digits do not help when the character count itself changes, so
    /// short values are padded to a fixed width.
    @Test func shortValuesArePaddedToAFixedWidth() {
        let short = MenuBarLabel.formattedValue(Decimal(string: "9.99")!)
        let long = MenuBarLabel.formattedValue(Decimal(string: "10.01")!)

        #expect(short.count == long.count)
        #expect(short.hasPrefix("\u{2007}"))
    }

    @Test func pairsAreSeparatedByATripleSpace() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02"), quote("BTC-BRL", "405884")],
            format: .value,
            indicator: .none
        )

        #expect(segments.contains { $0.text == MenuBarLabel.pairSeparator })
        #expect(MenuBarLabel.pairSeparator.count == 3)
    }

    @Test func noPairsMeansNoSegments() {
        #expect(MenuBarLabel.segments(for: [], format: .auto, indicator: .arrow).isEmpty)
    }

    /// The launch hold keeps the name in the bar even after the first fetch
    /// has landed. Empty segments are what the renderer turns into "Cota".
    @Test func theLaunchHoldSuppressesQuotes() {
        let quotes = [quote("EUR-BRL", "6.02")]
        #expect(
            MenuBarLabel.segments(
                for: quotes,
                format: .auto,
                indicator: .none,
                holdActive: true
            ).isEmpty
        )
        #expect(
            !MenuBarLabel.segments(
                for: quotes,
                format: .auto,
                indicator: .none,
                holdActive: false
            ).isEmpty
        )
    }

    /// Smoothstep: the fade starts and ends still, so "Cota" does not pop
    /// off and the quote does not pop on.
    @Test func theLaunchBlendEasesAtBothEnds() {
        #expect(MenuBarLabel.launchBlend(0) == 0)
        #expect(MenuBarLabel.launchBlend(1) == 1)
        #expect(MenuBarLabel.launchBlend(0.5) == 0.5)
        #expect(MenuBarLabel.launchBlend(0.25) < 0.25)
        #expect(MenuBarLabel.launchBlend(0.75) > 0.75)
    }

    @Test func theLaunchWidthMovesWithTheBlend() {
        #expect(MenuBarLabel.launchWidth(from: 10, to: 30, progress: 0) == 10)
        #expect(MenuBarLabel.launchWidth(from: 10, to: 30, progress: 1) == 30)
        #expect(MenuBarLabel.launchWidth(from: 10, to: 30, progress: 0.5) == 20)
    }
}
