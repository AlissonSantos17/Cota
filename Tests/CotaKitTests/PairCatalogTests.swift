import Foundation
import Testing

@testable import CotaKit

@Suite
struct PairCatalogTests {
    /// Every pair saved before cross pairs existed has to stay valid, or an
    /// upgrade would quietly drop it from the list.
    @Test func everyFormerPairIsStillOffered() {
        let former = [
            "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL",
            "ARS-BRL", "CAD-BRL", "AUD-BRL", "JPY-BRL",
            "CHF-BRL", "CNY-BRL", "ETH-BRL", "XRP-BRL",
        ]

        for pair in former {
            #expect(PairCatalog.contains(pair), "\(pair)")
        }
    }

    /// The API serves GBP-JPY but not JPY-GBP, and one unknown pair fails
    /// the whole `last` request.
    @Test func combinationsTheAPIRefusesAreNotOffered() {
        #expect(PairCatalog.contains("GBP-JPY"))
        #expect(!PairCatalog.contains("JPY-GBP"))
        #expect(!PairCatalog.contains("BTC-ETH"))
        #expect(!PairCatalog.contains("EUR-EUR"))
    }

    @Test func everyDestinationIsACatalogCurrency() {
        for origin in PairCatalog.currencies {
            for destination in PairCatalog.destinations(from: origin) {
                #expect(PairCatalog.currencies.contains(destination))
                #expect(destination != origin)
            }
        }
    }

    @Test func noPairIsListedTwice() {
        #expect(Set(PairCatalog.pairs).count == PairCatalog.pairs.count)
    }

    /// The menu bar's symbol and flag lookups need an entry for every currency
    /// offered, or a new pair would fall back to its bare code.
    @Test func everyCurrencyIsKnownToTheLabels() {
        for code in PairCatalog.currencies {
            let currency = Currency.named(code)
            #expect(currency.symbol != nil || code == "XRP", "\(code)")
        }
    }
}
