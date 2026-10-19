import Foundation
import Testing

@testable import CotaKit

/// When the menu bar says what a value is priced in.
@Suite
struct MenuBarDestinationTests {
    private func quote(_ pair: String, _ bid: String, change: String? = nil) -> MenuBarQuote {
        MenuBarQuote(
            pair: pair,
            bid: Decimal(string: bid)!,
            change: change.flatMap { Decimal(string: $0) }
        )
    }

    private func text(_ segments: [LabelSegment]) -> String {
        segments.map(\.text).joined()
            .replacingOccurrences(of: "\u{2007}", with: "")
    }

    /// BRL was the only destination before cross pairs; a bar of BRL pairs
    /// reads exactly as it did.
    @Test func anAllBRLBarLeavesTheDestinationImplicit() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02"), quote("USD-BRL", "5.19")],
            format: .auto,
            indicator: .none
        )

        #expect(!text(segments).contains("BRL"))
    }

    /// Two euros side by side, one in reais and one in dollars, cannot be told
    /// apart without the destination — so every pair names it.
    @Test func aMixedBarNamesEveryDestination() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-BRL", "6.02"), quote("EUR-USD", "1.12")],
            format: .auto,
            indicator: .none
        )

        let label = text(segments)
        #expect(label.contains("€ 6,02 BRL"))
        #expect(label.contains("€ 1,12 USD"))
    }

    @Test func aSingleNonBRLPairNamesItsDestination() {
        let segments = MenuBarLabel.segments(
            for: [quote("BTC-USD", "82916", change: "0.5")],
            format: .flag,
            indicator: .arrow
        )

        #expect(text(segments) == "₿ 82.916 USD ▴")
    }

    /// Value only is a deliberate choice for a single pair; it stays bare.
    @Test func valueOnlyStaysBareWhateverTheDestination() {
        let segments = MenuBarLabel.segments(
            for: [quote("EUR-USD", "1.12")],
            format: .value,
            indicator: .none
        )

        #expect(text(segments) == "1,12")
    }

    @Test func examplesFollowTheDestinationsOfTheSelection() {
        let eur = quote("EUR-USD", "1.12")

        #expect(
            text(
                MenuBarLabel.exampleSegments(
                    for: eur,
                    format: .auto,
                    among: ["EUR"],
                    destinations: ["USD"]
                )) == "€ 1,12 USD"
        )
    }
}
