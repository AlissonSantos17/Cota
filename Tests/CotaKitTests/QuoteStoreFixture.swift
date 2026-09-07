import Foundation
import Testing

@testable import CotaKit

final class MockQuoteService: QuoteServiceProtocol, @unchecked Sendable {
    var result: Result<[Quote], Error> = .success([])
    var dailyBids: [String: [Decimal]] = [:]
    var intradayBids: [String: [IntradayPoint]] = [:]
    var dailyError: Error?
    var intradayError: Error?

    private(set) var fetchCount = 0
    private(set) var dailyFetchCount = 0
    private(set) var intradayFetchCount = 0
    private(set) var requestedPairs: [[String]] = []

    /// Keeps a fetch in flight so a test can ask for a second one while the
    /// first has not returned.
    var holdFetch = false

    func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        fetchCount += 1
        requestedPairs.append(pairs)
        // Captured on entry: a response answers the request that was made, so
        // a result set while this one is held belongs to the *next* call.
        let captured = result
        while holdFetch {
            try? await Task.sleep(for: .milliseconds(5))
        }
        return try captured.get()
    }

    func fetchDailyBids(pair: String, days: Int) async throws -> [Decimal] {
        dailyFetchCount += 1
        if let dailyError { throw dailyError }
        return dailyBids[pair] ?? []
    }

    func fetchIntradayBids(pair: String, points: Int) async throws -> [IntradayPoint] {
        intradayFetchCount += 1
        if let intradayError { throw intradayError }
        return intradayBids[pair] ?? []
    }
}

/// A clock a test can wind forward, for the rules that are a function of the
/// date rather than of elapsed time.
final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    func advance(days: Int) {
        now = Calendar.current.date(byAdding: .day, value: days, to: now)!
    }
}
/// The fixtures both `QuoteStore` suites are built on. Shared through a
/// protocol rather than copied: a store wired differently in one file than the
/// other is a difference between the tests, not between what they test.
@MainActor
protocol QuoteStoreFixture {}

extension QuoteStoreFixture {
    func makeStore(
        launchHold: Duration = .seconds(2),
        launchReveal: Duration = .milliseconds(350),
        clock: TestClock? = nil
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
            launchReveal: launchReveal,
            now: clock.map { clock in { clock.now } } ?? { Date() }
        )
        return (store, mockService)
    }

    func quote(code: String, bid: String, pctChange: String = "0") throws -> Quote {
        let json = """
            {
                "code": "\(code)", "codein": "BRL",
                "name": "\(code)/BRL", "bid": "\(bid)",
                "pctChange": "\(pctChange)", "create_date": "2026-08-31"
            }
            """.data(using: .utf8)!
        return try JSONDecoder().decode(Quote.self, from: json)
    }

    func waitUntil(
        timeout: Duration = .seconds(2),
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
