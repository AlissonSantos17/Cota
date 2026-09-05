import Foundation
import Testing

@testable import CotaKit

final class MockQuoteService: QuoteServiceProtocol, @unchecked Sendable {
    var result: Result<[Quote], Error> = .success([])
    var dailyBids: [String: [Decimal]] = [:]
    var intradayBids: [String: [Decimal]] = [:]

    private(set) var fetchCount = 0

    func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        fetchCount += 1
        return try result.get()
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
    private func makeStore(
        launchHold: Duration = .seconds(2),
        launchReveal: Duration = .milliseconds(350)
    ) -> (QuoteStore, MockQuoteService) {
        let mockService = MockQuoteService()
        let suite = "cota.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(defaults: defaults)
        let store = QuoteStore(
            service: mockService,
            settings: settings,
            launchHold: launchHold,
            launchReveal: launchReveal
        )
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

    @Test func menuBarHasNothingToLabelBeforeTheFirstFetch() {
        let (store, _) = makeStore()
        #expect(store.menuBarQuotes.isEmpty)
    }

    /// The name stays in the bar for the hold even if the first fetch is
    /// instant. start() is what begins the clock; refresh alone does not.
    @Test func theLaunchHoldEndsAfterTheNameHasBeenShown() async throws {
        let (store, _) = makeStore(launchHold: .milliseconds(30))
        #expect(store.launchHoldActive)

        store.start()
        try await waitUntil { !store.launchHoldActive }
        #expect(!store.launchHoldActive)

        store.stop()
    }

    /// Quotes landing during the hold must not start the fade. The name
    /// stays put until the hold ends.
    @Test func theRevealWaitsForTheHold() async throws {
        let (store, mockService) = makeStore(
            launchHold: .milliseconds(80),
            launchReveal: .milliseconds(20)
        )
        mockService.result = .success([try quote(code: "EUR", bid: "6.02")])
        await store.refresh()

        #expect(!store.menuBarQuotes.isEmpty)
        #expect(store.launchReveal == 0)
    }

    @Test func theRevealRunsAfterHoldWhenQuotesAreReady() async throws {
        let (store, mockService) = makeStore(
            launchHold: .milliseconds(30),
            launchReveal: .milliseconds(30)
        )
        mockService.result = .success([try quote(code: "EUR", bid: "6.02")])
        await store.refresh()

        store.start()
        try await waitUntil { store.launchReveal == 1 }
        #expect(store.launchReveal == 1)

        store.stop()
    }

    @Test func theRevealDoesNotRunWithoutQuotes() async throws {
        let (store, mockService) = makeStore(
            launchHold: .milliseconds(20),
            launchReveal: .milliseconds(20)
        )
        mockService.result = .success([])

        store.start()
        try await waitUntil { !store.launchHoldActive }
        #expect(store.launchReveal == 0)

        store.stop()
    }

    @Test func flagReturnsCorrectEmoji() {
        let (store, _) = makeStore()
        #expect(store.flag("USD") == "🇺🇸")
        #expect(store.flag("EUR") == "🇪🇺")
        // Crypto has no issuing country and falls back to its symbol.
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
                Decimal(string: "5.18")!,
            ],
            "EUR-BRL": [
                Decimal(string: "5.90")!,
                Decimal(string: "5.85")!,
                Decimal(string: "6.00")!,
                Decimal(string: "6.02")!,
            ],
        ]

        await store.refresh()

        #expect(store.priceHistory["USD-BRL"] == mockService.dailyBids["USD-BRL"])
        #expect(store.priceHistory["EUR-BRL"] == mockService.dailyBids["EUR-BRL"])
        #expect(store.priceHistory["USD-BRL"] != store.priceHistory["EUR-BRL"])
    }

    /// The loop used to sleep the old interval to the end, so 5m → 30s
    /// waited out the remaining minutes. Restarting the loop is what makes
    /// the control mean what it says.
    @Test func changingTheIntervalFetchesAgainWithoutWaitingOutTheOldSleep() async throws {
        let (store, mockService) = makeStore()
        store.settings.refreshInterval = 300
        mockService.result = .success([try quote(code: "USD", bid: "5.00")])

        store.start()
        try await waitUntil { mockService.fetchCount >= 1 }
        #expect(mockService.fetchCount == 1)

        store.settings.refreshInterval = 30
        try await waitUntil { mockService.fetchCount >= 2 }
        #expect(mockService.fetchCount == 2)

        store.stop()
    }

    private func waitUntil(
        timeout: Duration = .milliseconds(400),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("timed out waiting for condition")
    }
}
