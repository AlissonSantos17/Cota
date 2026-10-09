import Foundation
import Testing

@testable import CotaKit

/// How the loop recovers from a failed fetch. At login the network is not up
/// yet; waiting out a full interval after that first failure left the menu bar
/// reading "Cota" for minutes after the connection came back.
@MainActor
struct QuoteStoreRetryTests: QuoteStoreFixture {
    /// Short enough to run, spread enough that each step can be told apart.
    private let fastRetries: [Duration] = [
        .milliseconds(20), .milliseconds(40), .milliseconds(80), .milliseconds(160),
    ]

    private var offline: Error { URLError(.notConnectedToInternet) }

    @Test func consecutiveFailuresAreRetriedUntilAFetchSucceeds() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.queuedResults = [.failure(offline), .failure(offline)]
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        store.start()
        try await waitUntil { !store.quotes.isEmpty }

        #expect(mockService.fetchCount == 3)
        #expect(store.error == nil)

        // Recovered: back on the interval (300s by default), not the retry
        // schedule.
        try await Task.sleep(for: .milliseconds(400))
        #expect(mockService.fetchCount == 3)

        store.stop()
    }

    @Test func aSuccessfulFetchWaitsForTheInterval() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        store.start()
        try await waitUntil { mockService.fetchCount == 1 && !store.loading }

        try await Task.sleep(for: .milliseconds(400))
        #expect(mockService.fetchCount == 1)

        store.stop()
    }

    /// Stopping cancels the request in flight, and URLSession reports that as
    /// `URLError.cancelled` rather than `CancellationError`. Neither is a
    /// failure of the API: no error on screen, no retry.
    @Test func stoppingDuringAFetchDoesNotRetry() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.result = .failure(URLError(.cancelled))
        mockService.holdFetch = true

        store.start()
        try await waitUntil { mockService.fetchCount == 1 }
        store.stop()
        mockService.holdFetch = false

        try await Task.sleep(for: .milliseconds(400))
        #expect(mockService.fetchCount == 1)
        #expect(store.error == nil)
    }

    @Test func aCancelledRequestIsNotRetriedOnTheFastSchedule() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.result = .failure(URLError(.cancelled))

        store.start()
        try await waitUntil { mockService.fetchCount == 1 && !store.loading }

        try await Task.sleep(for: .milliseconds(400))
        #expect(mockService.fetchCount == 1)
        #expect(store.error == nil)

        store.stop()
    }

    /// The schedule runs out, and the loop falls back to the interval rather
    /// than hammering an API that is down.
    @Test func persistentFailureFallsBackToTheInterval() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        store.settings.refreshInterval = 1
        mockService.result = .failure(offline)

        store.start()
        // One fetch plus four retries, well inside the one-second interval.
        try await waitUntil(timeout: .milliseconds(900)) { mockService.fetchCount == 5 }

        try await Task.sleep(for: .milliseconds(400))
        #expect(mockService.fetchCount == 5)

        try await waitUntil { mockService.fetchCount == 6 }
        #expect(store.error != nil)

        store.stop()
    }

    /// A retry step longer than the interval would make a failure slower to
    /// recover from than a success is to refresh.
    @Test func aRetryNeverWaitsLongerThanTheInterval() async throws {
        let (store, mockService) = makeStore(
            retryDelays: [.milliseconds(20), .seconds(30)]
        )
        store.settings.refreshInterval = 1
        mockService.result = .failure(offline)

        // 0ms, 20ms, then the 30s step capped to the 1s interval. Without the
        // fast first retry the third fetch lands at 2s; without the cap, at 30s.
        store.start()
        try await waitUntil(timeout: .milliseconds(1500)) { mockService.fetchCount == 3 }
        #expect(mockService.fetchCount == 3)

        store.stop()
    }

    /// A 404 or a body that does not decode will not fix itself in five
    /// seconds. Retrying fast would only spend the API's rate limit.
    @Test func aClientErrorWaitsForTheInterval() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.result = .failure(QuoteError.httpError(404))

        store.start()
        try await waitUntil { mockService.fetchCount == 1 && !store.loading }

        try await Task.sleep(for: .milliseconds(400))
        #expect(mockService.fetchCount == 1)
        #expect(store.error != nil)

        store.stop()
    }

    @Test func aServerErrorIsRetried() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.queuedResults = [.failure(QuoteError.httpError(503))]
        mockService.result = .success([try quote(code: "USD", bid: "5.18")])

        store.start()
        try await waitUntil { !store.quotes.isEmpty }
        #expect(mockService.fetchCount == 2)

        store.stop()
    }

    /// The last good quote stays on screen through an outage; the error and
    /// the staleness rule are what tell the user it is old.
    @Test func aFailedFetchKeepsTheLastQuote() async throws {
        let (store, mockService) = makeStore(retryDelays: fastRetries)
        mockService.queuedResults = [.success([try quote(code: "USD", bid: "5.18")])]
        mockService.result = .failure(offline)

        await store.refresh()
        let updatedAt = store.lastUpdate

        await store.refresh()

        #expect(store.quotes.map(\.id) == ["USD-BRL"])
        #expect(store.quotes.first?.bid == Decimal(string: "5.18"))
        #expect(store.lastUpdate == updatedAt)
        #expect(store.error != nil)
    }
}
