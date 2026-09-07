import Foundation
import Testing

@testable import CotaKit

@MainActor
struct QuoteStoreTests: QuoteStoreFixture {

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

    /// compactMap on the API dictionary dropped pairs the user asked for.
    /// The panel then had no row and no explanation — just a missing quote.
    @Test func refreshRecordsPairsMissingFromTheResponse() async throws {
        let (store, mockService) = makeStore()
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        await store.refresh()

        #expect(store.quotes.map(\.id) == ["USD-BRL"])
        #expect(
            store.unavailablePairs == [
                "EUR-BRL", "GBP-BRL", "BTC-BRL",
            ])
    }

    /// A refresh asked for while one was in flight used to be dropped by the
    /// `!loading` guard. It is the guard the pairs observation runs into, so
    /// adding a pair went unanswered until the next tick of the loop — up to
    /// ten minutes of a row reading "Not in the last API response".
    @Test func aRefreshAskedForDuringAFetchRunsAfterIt() async throws {
        let (store, mockService) = makeStore()
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])
        mockService.holdFetch = true

        let inFlight = Task { await store.refresh() }
        try await waitUntil { mockService.fetchCount == 1 }

        await store.refresh()
        mockService.holdFetch = false
        await inFlight.value

        try await waitUntil { mockService.fetchCount == 2 }
        #expect(mockService.fetchCount == 2)
    }

    /// The pair added mid-flight was measured against a response that had never
    /// been asked for it, so it landed in `unavailablePairs` and the panel
    /// called it missing from an API that was never asked.
    @Test func aPairAddedDuringAFetchIsNotReportedUnavailable() async throws {
        let (store, mockService) = makeStore()
        let usd = try quote(code: "USD", bid: "5.18")
        let jpy = try quote(code: "JPY", bid: "0.03")
        mockService.result = .success([usd])
        mockService.holdFetch = true

        let inFlight = Task { await store.refresh() }
        try await waitUntil { mockService.fetchCount == 1 }

        store.settings.addPair("JPY-BRL")
        mockService.result = .success([usd, jpy])
        mockService.holdFetch = false
        await inFlight.value

        try await waitUntil { store.quotes.contains { $0.id == "JPY-BRL" } }
        #expect(!store.unavailablePairs.contains("JPY-BRL"))
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

    /// Ticking the first menu bar pair after the hold used to leave the bar
    /// on the name: startRevealIfReady only ran at the end of the hold and of
    /// refresh, and setMenuBarPair does not change `pairs`, so neither fired.
    @Test func tickingTheFirstMenuBarPairStartsTheReveal() async throws {
        let (store, mockService) = makeStore(
            launchHold: .milliseconds(20),
            launchReveal: .milliseconds(20)
        )
        mockService.result = .success([try quote(code: "EUR", bid: "6.02")])
        await store.refresh()

        for pair in store.settings.pairs {
            store.settings.setMenuBarPair(pair, shown: false)
        }

        store.start()
        try await waitUntil { !store.launchHoldActive }
        #expect(store.launchReveal == 0)
        #expect(store.menuBarQuotes.isEmpty)

        store.settings.setMenuBarPair("EUR-BRL", shown: true)
        try await waitUntil { store.launchReveal == 1 }
        #expect(store.launchReveal == 1)

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
}
