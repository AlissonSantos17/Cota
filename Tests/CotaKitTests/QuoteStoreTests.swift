import Testing
import Foundation
@testable import CotaKit

final class MockQuoteService: QuoteServiceProtocol, @unchecked Sendable {
    var result: Result<[Quote], Error> = .success([])
    var dailyBids: [String: [Decimal]] = [:]
    var intradayBids: [String: [Decimal]] = [:]

    func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        try result.get()
    }

    func fetchDailyBids(pair: String, days: Int) async throws -> [Decimal] {
        dailyBids[pair] ?? []
    }

    func fetchIntradayBids(pair: String, points: Int) async throws -> [Decimal] {
        intradayBids[pair] ?? []
    }
}

@MainActor
struct QuoteStoreTests {
    private func makeStore() -> (QuoteStore, MockQuoteService) {
        let mockService = MockQuoteService()
        let suite = "cota.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(defaults: defaults)
        let store = QuoteStore(service: mockService, settings: settings)
        return (store, mockService)
    }

    private func quote(code: String, bid: String, pctChange: String = "0") throws -> Quote {
        let json = """
        {
            "code": "\(code)", "codein": "BRL",
            "name": "\(code)/BRL", "bid": "\(bid)",
            "pctChange": "\(pctChange)", "create_date": "2026-08-31"
        }
        """.data(using: .utf8)!
        return try JSONDecoder().decode(Quote.self, from: json)
    }

    @Test func refreshUpdatesQuotes() async {
        let (store, mockService) = makeStore()
        let json = """
        {
            "code": "USD", "codein": "BRL",
            "name": "Dollar", "bid": "5.00",
            "pctChange": "1.5", "create_date": "2026-08-31"
        }
        """.data(using: .utf8)!

        let quote = try! JSONDecoder().decode(Quote.self, from: json)
        mockService.result = .success([quote])

        await store.refresh()

        #expect(store.quotes.count == 1)
        #expect(store.quotes[0].code == "USD")
        #expect(store.error == nil)
        #expect(store.lastUpdate != nil)
    }

    @Test func refreshSetsErrorOnFailure() async {
        let (store, mockService) = makeStore()
        mockService.result = .failure(QuoteError.invalidResponse)

        await store.refresh()

        #expect(store.quotes.isEmpty)
        #expect(store.error != nil)
    }

    @Test func menuBarSummaryDefaultWhenEmpty() {
        let (store, _) = makeStore()
        #expect(store.menuBarSummary == "Quotes")
    }

    @Test func flagReturnsCorrectEmoji() {
        let (store, _) = makeStore()
        #expect(store.flag("USD") == "🇺🇸")
        #expect(store.flag("EUR") == "🇪🇺")
        #expect(store.flag("BTC") == "₿")
        #expect(store.flag("XYZ") == "XYZ")
    }

    @Test func refreshSeedsDistinctDailyHistoryPerPair() async throws {
        let (store, mockService) = makeStore()
        let usd = try quote(code: "USD", bid: "5.18", pctChange: "-0.08")
        let eur = try quote(code: "EUR", bid: "6.02", pctChange: "0.20")
        mockService.result = .success([usd, eur])
        mockService.dailyBids = [
            "USD-BRL": [
                Decimal(string: "5.10")!,
                Decimal(string: "5.22")!,
                Decimal(string: "5.16")!,
                Decimal(string: "5.18")!
            ],
            "EUR-BRL": [
                Decimal(string: "5.90")!,
                Decimal(string: "5.85")!,
                Decimal(string: "6.00")!,
                Decimal(string: "6.02")!
            ]
        ]

        await store.refresh()

        #expect(store.priceHistory["USD-BRL"] == mockService.dailyBids["USD-BRL"])
        #expect(store.priceHistory["EUR-BRL"] == mockService.dailyBids["EUR-BRL"])
        #expect(store.priceHistory["USD-BRL"] != store.priceHistory["EUR-BRL"])
    }
}
