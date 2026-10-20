import Foundation
import Testing

@testable import CotaKit

/// Every test here passes its language explicitly. `L10n.language` is
/// process-wide, and moving it would race the formatting tests running
/// alongside.
@Suite
struct LocalizationTests {
    private func dec(_ text: String) -> Decimal {
        Decimal(string: text)!
    }

    private let english = Locale(identifier: "en_US")

    // MARK: - QuoteFormat in English

    @Test func englishUsesADecimalPoint() {
        #expect(QuoteFormat.value(dec("5.6480"), locale: english) == "5.6480")
        #expect(QuoteFormat.value(dec("1234.6"), locale: english) == "1,235")
    }

    /// The decimal rules do not change with the language, only the separators.
    @Test func englishKeepsTheDecimalRules() {
        #expect(QuoteFormat.value(dec("0.005123"), locale: english) == "0.005123")
        #expect(QuoteFormat.value(dec("42.5"), locale: english) == "42.50")
        #expect(QuoteFormat.menuBar(dec("6.0214"), locale: english) == "6.02")
    }

    @Test func englishAbbreviatesTheSameWay() {
        #expect(QuoteFormat.menuBar(dec("398348"), locale: english) == "398k")
        #expect(QuoteFormat.rangeBound(dec("403100"), locale: english) == "403k")
    }

    @Test func englishPercentages() {
        #expect(QuoteFormat.percentMagnitude(dec("-0.84"), locale: english) == "0.84%")
        #expect(QuoteFormat.percent(dec("1.2"), locale: english) == "+1.20%")
    }

    @Test func parsingAcceptsBothGroupings() {
        #expect(QuoteFormat.parseThreshold("1,000.50") == dec("1000.50"))
        #expect(QuoteFormat.parseThreshold("1.000,50") == dec("1000.50"))
        #expect(QuoteFormat.parseThreshold("1000.50") == dec("1000.50"))
    }

    // MARK: - Strings

    @Test func bothLanguagesHaveTheirOwnStrings() {
        #expect(L10n.t("panel.title", in: .ptBR) == "Cotações")
        #expect(L10n.t("panel.title", in: .en) == "Rates")
    }

    @Test func everyCatalogCurrencyHasANameInBothLanguages() {
        for code in PairCatalog.currencies {
            #expect(L10n.t("currency.\(code)", in: .ptBR) != "currency.\(code)")
            #expect(L10n.t("currency.\(code)", in: .en) != "currency.\(code)")
        }
    }

    @Test func languageLocales() {
        #expect(AppLanguage.ptBR.locale.identifier == "pt_BR")
        #expect(AppLanguage.en.locale.identifier == "en_US")
        #expect(AppLanguage.en.lproj == "en")
        #expect(AppLanguage.ptBR.lproj == "pt-BR")
    }

    // MARK: - Avatar glyphs

    /// The avatar tells CAD from AUD; the menu bar symbol deliberately does not.
    @Test func avatarGlyphsAreDistinctWhereSymbolsCollide() {
        #expect(Currency.named("CAD").avatarGlyph == "C$")
        #expect(Currency.named("AUD").avatarGlyph == "A$")
        #expect(Currency.named("CAD").symbol == "$")
        #expect(Currency.named("AUD").symbol == "$")
    }

    @Test func everyCatalogCurrencyHasAnAvatarGlyph() {
        for code in PairCatalog.currencies {
            #expect(Currency.named(code).avatarGlyph != code, "\(code)")
        }
    }
}

@Suite
struct AmountFormatTests {
    private func dec(_ text: String) -> Decimal {
        Decimal(string: text)!
    }

    private let portuguese = Locale(identifier: "pt_BR")

    @Test func moneyCarriesAnUnambiguousSymbol() {
        #expect(QuoteFormat.money(dec("5.648"), currency: "BRL", locale: portuguese) == "R$ 5,6480")
        #expect(
            QuoteFormat.money(dec("1.0812"), currency: "USD", locale: portuguese) == "US$ 1,0812")
    }

    @Test func thresholdsShowWhatWasSet() {
        #expect(QuoteFormat.threshold(dec("5.7"), locale: portuguese) == "5,70")
        #expect(QuoteFormat.threshold(dec("5.6931"), locale: portuguese) == "5,6931")
        #expect(QuoteFormat.threshold(dec("401600"), locale: portuguese) == "401.600")
        #expect(QuoteFormat.threshold(dec("0.0051"), locale: portuguese) == "0,0051")
    }

    @Test func suggestedThresholdRoundsByMagnitude() {
        #expect(PriceAlert.suggestedThreshold(for: dec("5.648")) == dec("5.69"))
        #expect(PriceAlert.suggestedThreshold(for: dec("398420")) == dec("401607"))
        #expect(PriceAlert.suggestedThreshold(for: dec("0.03342")) == dec("0.0337"))
    }

    @Test func distanceAndSide() {
        let alert = PriceAlert(pair: "EUR-BRL", threshold: dec("5.70"), isAbove: true)
        #expect(alert.distance(from: dec("5.70")) == 0)
        #expect(alert.distance(from: dec("5")) == dec("14"))
        #expect(!alert.isPast(dec("5.69")))
        #expect(alert.isPast(dec("5.71")))
    }
}

@Suite
struct LocalizedParsingTests {
    private func dec(_ text: String) -> Decimal {
        Decimal(string: text)!
    }

    private let english = Locale(identifier: "en_US")
    private let portuguese = Locale(identifier: "pt_BR")

    /// Three digits after a lone separator: the language decides.
    @Test func aLoneSeparatorBeforeThreeDigitsFollowsTheLanguage() {
        #expect(QuoteFormat.parseThreshold("5.123", locale: portuguese) == dec("5123"))
        #expect(QuoteFormat.parseThreshold("5,123", locale: portuguese) == dec("5.123"))
        #expect(QuoteFormat.parseThreshold("5.123", locale: english) == dec("5.123"))
        #expect(QuoteFormat.parseThreshold("5,123", locale: english) == dec("5123"))
    }

    @Test func englishGroupingAndDecimals() {
        #expect(QuoteFormat.parseThreshold("1,000,000", locale: english) == dec("1000000"))
        #expect(QuoteFormat.parseThreshold("5.75", locale: english) == dec("5.75"))
        #expect(QuoteFormat.parseThreshold("5,75", locale: english) == dec("5.75"))
        #expect(QuoteFormat.parseThreshold("6,02,", locale: english) == nil)
    }
}
