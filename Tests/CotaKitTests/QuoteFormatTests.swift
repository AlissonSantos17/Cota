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
}
