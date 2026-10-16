import Foundation
import Testing

@testable import CotaKit

/// Alerts judged against the quote already on screen the moment they are
/// created or switched back on, instead of waiting up to a whole refresh
/// interval for the next fetch.
@Suite @MainActor
struct QuoteStoreAlertTests: QuoteStoreFixture {
    /// A store wired to a notification service that records instead of
    /// drawing banners, with one pair and the clock set to now.
    private struct Harness {
        let store: QuoteStore
        let mock: MockQuoteService
        let settings: SettingsStore
        let recorder: AlertFixture.Recorder
        let clock: AlertFixture.TestClock
    }

    private func makeHarness() -> Harness {
        let clock = AlertFixture.TestClock()
        clock.now = Date()
        let (notifications, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let mock = MockQuoteService()
        let settings = SettingsStore(defaults: AlertFixture.freshDefaults())
        settings.addPair("USD-BRL")
        let store = QuoteStore(service: mock, settings: settings, notifications: notifications)
        return Harness(
            store: store, mock: mock, settings: settings, recorder: recorder, clock: clock)
    }

    private func usd(_ bid: String, clock: AlertFixture.TestClock, age: TimeInterval = 0) -> Quote {
        AlertFixture.quote(
            "USD-BRL", bid: bid, updatedAt: clock.now.addingTimeInterval(-age), clock: clock)
    }

    private let alert = PriceAlert(pair: "USD-BRL", threshold: Decimal(string: "5")!, isAbove: true)

    @Test func aNewAlertIsJudgedAgainstTheQuoteOnScreen() async throws {
        let harness = makeHarness()
        harness.mock.result = .success([usd("5.10", clock: harness.clock)])
        await harness.store.refresh()

        harness.settings.addAlert(alert)

        try await waitUntil { harness.recorder.sent.count == 1 }
        #expect(harness.mock.fetchCount == 1)
    }

    @Test func switchingAnAlertBackOnIsJudgedAtOnce() async throws {
        let harness = makeHarness()
        harness.mock.result = .success([usd("5.10", clock: harness.clock)])
        await harness.store.refresh()

        var muted = alert
        muted.isEnabled = false
        harness.settings.addAlert(muted)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.recorder.sent.isEmpty)

        harness.settings.updateAlert(alert)

        try await waitUntil { harness.recorder.sent.count == 1 }
        #expect(harness.mock.fetchCount == 1)
    }

    /// The quote on screen is over an hour old: the alert is not judged on
    /// it, and waits for the next fetch to bring a current one.
    @Test func withoutACurrentQuoteTheAlertWaitsForTheFetch() async throws {
        let harness = makeHarness()
        harness.mock.result = .success([usd("5.10", clock: harness.clock, age: 7_200)])
        await harness.store.refresh()

        harness.settings.addAlert(alert)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.recorder.sent.isEmpty)

        harness.mock.result = .success([usd("5.10", clock: harness.clock)])
        await harness.store.refresh()

        #expect(harness.recorder.sent.count == 1)
    }

    /// Before the first fetch there is nothing to judge against.
    @Test func anAlertAddedBeforeAnyQuoteWaits() async throws {
        let harness = makeHarness()

        harness.settings.addAlert(alert)
        try await Task.sleep(for: .milliseconds(50))

        #expect(harness.recorder.sent.isEmpty)
    }
}
