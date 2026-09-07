import Foundation
import Testing

@testable import CotaKit

@Suite
struct QuoteFormatTests {
    private func dec(_ text: String) -> Decimal {
        Decimal(string: text)!
    }

    // MARK: - Decimals by magnitude

    @Test func belowTenKeepsFourDecimals() {
        #expect(QuoteFormat.value(dec("5.9713")) == "5,9713")
    }

    @Test func belowAThousandKeepsTwo() {
        #expect(QuoteFormat.value(dec("42.5")) == "42,50")
    }

    /// The defect this rule exists to fix: the pairs list printed
    /// `398.348,0000` beside `5,9713`, twice the width for no information.
    @Test func aboveAThousandDropsTheDecimals() {
        #expect(QuoteFormat.value(dec("398348.12")) == "398.348")
    }

    @Test func theBoundariesBelongToTheCoarserRule() {
        #expect(QuoteFormat.value(dec("10")) == "10,00")
        #expect(QuoteFormat.value(dec("1000")) == "1.000")
    }

    // MARK: - Menu bar

    @Test func theMenuBarAbbreviatesAboveAHundredThousand() {
        #expect(QuoteFormat.menuBar(dec("398348")) == "398k")
    }

    @Test func theMenuBarStopsAtTwoDecimals() {
        #expect(QuoteFormat.menuBar(dec("5.9713")) == "5,97")
    }

    /// Only the menu bar abbreviates; the panel has the room and precision is
    /// what the reader opened it for.
    @Test func theOtherSurfacesDoNotAbbreviate() {
        #expect(QuoteFormat.value(dec("398348")) == "398.348")
    }

    // MARK: - Percentages

    @Test func percentCarriesItsSign() {
        #expect(QuoteFormat.percent(dec("-0.83")) == "-0,83%")
        #expect(QuoteFormat.percent(dec("1.2")) == "+1,20%")
    }

    /// Surfaces that draw a ▲/▼ take the unsigned form: a sign next to an
    /// arrow states the direction twice.
    @Test func percentMagnitudeDropsTheSign() {
        #expect(QuoteFormat.percentMagnitude(dec("-0.83")) == "0,83%")
    }

    // MARK: - Threshold parsing

    /// The field is pt-BR. Replacing `,` with `.` and handing the rest to
    /// `Decimal` turned `350.000` into 350 and `5.000,50` into a silent 5.
    @Test func parseThresholdReadsBrazilianGrouping() {
        #expect(QuoteFormat.parseThreshold("6,02") == dec("6.02"))
        #expect(QuoteFormat.parseThreshold("6.02") == dec("6.02"))
        #expect(QuoteFormat.parseThreshold("350.000") == dec("350000"))
        #expect(QuoteFormat.parseThreshold("5.000,50") == dec("5000.50"))
        #expect(QuoteFormat.parseThreshold("350000,50") == dec("350000.50"))
    }

    /// `Decimal(string:)` stops at the first character it cannot use and hands
    /// back the prefix, so `5abc` came out as a valid 5 and `1e5` as 100.000.
    /// A threshold the person did not type is worse than no threshold: the Add
    /// button lit up and the alert was armed on a number nobody chose.
    @Test func parseThresholdRejectsAnythingThatIsNotJustANumber() {
        #expect(QuoteFormat.parseThreshold("5abc") == nil)
        #expect(QuoteFormat.parseThreshold("1e5") == nil)
        #expect(QuoteFormat.parseThreshold("6,02,") == nil)
        #expect(QuoteFormat.parseThreshold("5 000") == nil)
        #expect(QuoteFormat.parseThreshold("R$ 6,02") == nil)
        #expect(QuoteFormat.parseThreshold("+6,02") == nil)
    }

    /// Whitespace around the number is typing, not input.
    @Test func parseThresholdTrimsSurroundingWhitespace() {
        #expect(QuoteFormat.parseThreshold("  6,02 ") == dec("6.02"))
    }

    @Test func parseThresholdRejectsZeroAndNegative() {
        #expect(QuoteFormat.parseThreshold("0") == nil)
        #expect(QuoteFormat.parseThreshold("-1") == nil)
        #expect(QuoteFormat.parseThreshold("-5,00") == nil)
        #expect(QuoteFormat.parseThreshold("") == nil)
        #expect(QuoteFormat.parseThreshold("abc") == nil)
    }
}
