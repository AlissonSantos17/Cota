import Foundation
import Testing

@testable import CotaKit

/// The history the panel draws from, and the loop that keeps it current.
@MainActor
struct QuoteStoreHistoryTests: QuoteStoreFixture {

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

    /// A failed first history fetch used to write `[]`, which is not nil, so
    /// later refreshes never asked again. Sparkline, range and period change
    /// stayed empty until the app was restarted.
    @Test func aFailedHistoryFetchIsRetriedOnTheNextRefresh() async throws {
        let (store, mockService) = makeStore()
        let usd = try quote(code: "USD", bid: "5.18")
        mockService.result = .success([usd])
        mockService.dailyError = QuoteError.httpError(500)
        mockService.intradayError = QuoteError.httpError(500)

        await store.refresh()

        #expect(store.priceHistory["USD-BRL"] == nil)
        #expect(store.intradayBids["USD-BRL"] == nil)
        #expect(mockService.dailyFetchCount == 1)

        mockService.dailyError = nil
        mockService.intradayError = nil
        mockService.dailyBids = ["USD-BRL": [Decimal(string: "5.10")!, Decimal(string: "5.18")!]]
        mockService.intradayBids = [
            "USD-BRL": [IntradayPoint(date: Date(), bid: Decimal(string: "5.16")!)]
        ]

        await store.refresh()

        #expect(store.priceHistory["USD-BRL"] == mockService.dailyBids["USD-BRL"])
        #expect(
            store.intradayBids["USD-BRL"]?.map(\.bid) == [Decimal(string: "5.16")!, usd.bid])
        #expect(mockService.dailyFetchCount == 2)
    }

    /// Dragging a row changes the order of a list the app already has quotes
    /// for. The observation could not tell that from a pair being added, so
    /// every drag cost a round trip to the API.
    @Test func reorderingPairsDoesNotRefetch() async throws {
        let (store, mockService) = makeStore()
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        await store.refresh()
        #expect(mockService.fetchCount == 1)

        store.settings.swapPairs(0, 1)
        try await Task.sleep(for: .milliseconds(120))

        #expect(mockService.fetchCount == 1)
        #expect(store.settings.pairs[0] == "USD-BRL")
    }

    /// Adding one still does, of course — that is the case the observation is
    /// there for.
    @Test func addingAPairRefetches() async throws {
        let (store, mockService) = makeStore()
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        await store.refresh()
        store.settings.addPair("JPY-BRL")

        try await waitUntil { mockService.fetchCount == 2 }
        #expect(mockService.fetchCount == 2)
    }

    /// Daily closes were fetched once and then never again, because the only
    /// condition was "nothing stored yet". An app that lives in the menu bar
    /// for weeks kept drawing the 7d and 30d windows from the closes of the day
    /// it was launched.
    @Test func dailyHistoryIsFetchedAgainOnceTheDayRolls() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_756_000_000))
        let (store, mockService) = makeStore(clock: clock)
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])
        mockService.dailyBids = ["USD-BRL": [Decimal(string: "5.10")!]]

        await store.refresh()
        #expect(mockService.dailyFetchCount == 1)

        // Same day: the closes cannot have changed, so nothing is asked for.
        await store.refresh()
        #expect(mockService.dailyFetchCount == 1)

        clock.advance(days: 1)
        mockService.dailyBids = [
            "USD-BRL": [Decimal(string: "5.10")!, Decimal(string: "5.30")!]
        ]
        await store.refresh()

        #expect(mockService.dailyFetchCount == 2)
        #expect(store.priceHistory["USD-BRL"]?.count == 2)
    }

    /// "24h" was a point count, not a window: the series was whatever the last
    /// 200 ticks happened to be, seeded with about 80 minutes of trading. A
    /// tick from two days ago stayed on the chart and anchored the change and
    /// the range to it.
    @Test func theDayWindowDropsTicksOlderThanADay() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_756_000_000))
        let (store, mockService) = makeStore(clock: clock)
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])
        mockService.intradayBids = [
            "USD-BRL": [
                IntradayPoint(
                    date: clock.now.addingTimeInterval(-30 * 3600),
                    bid: Decimal(string: "4.00")!
                ),
                IntradayPoint(
                    date: clock.now.addingTimeInterval(-2 * 3600),
                    bid: Decimal(string: "5.10")!
                ),
            ]
        ]

        await store.refresh()

        #expect(
            store.series(for: "USD-BRL", period: .day) == [
                Decimal(string: "5.10")!,
                Decimal(string: "5.18")!,
            ])
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

    /// `stop()` resumed the wait but left its generation alone, so the
    /// `Task.sleep` from the stopped loop was still valid when it came due —
    /// and woke the wait the *next* loop was sitting in, fetching early and
    /// putting the interval permanently out of step.
    @Test func aStoppedLoopDoesNotWakeTheNextOne() async throws {
        let (store, mockService) = makeStore()
        store.settings.refreshInterval = 1
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        store.start()
        // `fetchCount` rises when the request starts. The loop has to be
        // parked in its sleep before stopping it, or this measures the guard
        // on a fetch still in flight instead of the leftover sleep.
        try await waitUntil { mockService.fetchCount == 1 && !store.loading }
        store.stop()

        // A long interval, so a fetch inside the next second can only have come
        // from the sleep the stopped loop left behind.
        store.settings.refreshInterval = 30
        store.start()
        try await waitUntil { mockService.fetchCount == 2 }

        try await Task.sleep(for: .milliseconds(1500))
        #expect(mockService.fetchCount == 2)

        store.stop()
    }
}
