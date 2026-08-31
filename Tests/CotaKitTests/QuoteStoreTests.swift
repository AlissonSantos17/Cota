import Testing
import Foundation
@testable import CotaKit

final class MockQuoteService: QuoteServiceProtocol, @unchecked Sendable {
    var result: Result<[Quote], Error> = .success([])

    func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        try result.get()
    }
}

@MainActor
struct QuoteStoreTests {
    private func makeStore() -> (QuoteStore, MockQuoteService) {
        let mockService = MockQuoteService()
        let store = QuoteStore(service: mockService)
        return (store, mockService)
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
}
