import Foundation
import Testing

@testable import CotaKit

/// What survives time passing and the app closing: quote age, the cooldown,
/// and state read back on launch.
@Suite @MainActor
struct NotificationLifecycleTests {
    private let alert = PriceAlert(
        pair: "EUR-BRL",
        threshold: Decimal(string: "6")!,
        isAbove: true
    )

    // MARK: - Quote age

    /// A quote that arrived fine but describes the market an hour ago is not
    /// "the price now". Firing on it, or rearming on it, acts on a price that
    /// may no longer exist.
    @Test func aStaleQuoteIsNotEvaluated() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let old = clock.now.addingTimeInterval(-3_601)

        await service.checkAlerts(
            [alert],
            against: [AlertFixture.quote("EUR-BRL", bid: "6.01", updatedAt: old, clock: clock)])

        #expect(recorder.sent.isEmpty)
        #expect(service.state(for: alert.id) == nil)
    }

    @Test func aQuoteInsideTheWindowIsEvaluated() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let recent = clock.now.addingTimeInterval(-3_600)

        await service.checkAlerts(
            [alert],
            against: [AlertFixture.quote("EUR-BRL", bid: "6.01", updatedAt: recent, clock: clock)])

        #expect(recorder.sent.count == 1)
    }

    /// No timestamp, no age, and an age is what "the price now" rests on.
    /// The quote is left out of the alerts until one arrives with a time.
    @Test func aQuoteWithoutATimestampIsNotEvaluated() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        await service.checkAlerts(
            [alert],
            against: [AlertFixture.quote("EUR-BRL", bid: "6.01", timestamped: false, clock: clock)])

        #expect(recorder.sent.isEmpty)
        #expect(service.pause(for: alert.id) == .untimedQuote)
    }

    /// A timestamp from the future is a clock that cannot be trusted, not a
    /// fresh quote. A few minutes of drift between machines is allowed.
    @Test func aTimestampFromTheFutureIsNotTrusted() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        await service.checkAlerts(
            [alert],
            against: [
                AlertFixture.quote(
                    "EUR-BRL", bid: "6.01", updatedAt: clock.now.addingTimeInterval(301),
                    clock: clock)
            ])
        #expect(recorder.sent.isEmpty)
        #expect(service.pause(for: alert.id) == .untimedQuote)

        await service.checkAlerts(
            [alert],
            against: [
                AlertFixture.quote(
                    "EUR-BRL", bid: "6.01", updatedAt: clock.now.addingTimeInterval(300),
                    clock: clock)
            ])
        #expect(recorder.sent.count == 1)
    }

    /// Settings has to be able to say an alert is not being watched, and
    /// stop saying it as soon as a fresh quote arrives.
    @Test func aPauseIsReportedUntilAFreshQuoteArrives() async {
        let clock = AlertFixture.TestClock()
        let (service, _) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let old = clock.now.addingTimeInterval(-7_200)

        await service.checkAlerts(
            [alert],
            against: [AlertFixture.quote("EUR-BRL", bid: "5.90", updatedAt: old, clock: clock)])
        #expect(service.pause(for: alert.id) == .staleQuote)

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "5.90", clock: clock)])
        #expect(service.pause(for: alert.id) == nil)
    }

    /// A stale quote must not rearm either: a fall seen only in old data is
    /// not a fall the app saw.
    @Test func aStaleQuoteDoesNotRearm() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        clock.advance(7_200)
        let old = clock.now.addingTimeInterval(-3_601)
        await service.checkAlerts(
            [alert],
            against: [AlertFixture.quote("EUR-BRL", bid: "5.50", updatedAt: old, clock: clock)])

        #expect(service.state(for: alert.id)?.phase == .triggered)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(recorder.sent.count == 1)
    }

    // MARK: - Interrupted delivery

    /// The app stopped between handing the banner over and saving the
    /// answer. Notification Center still lists it, so it went out: marking it
    /// sent avoids a second banner for the same crossing.
    @Test func anInterruptedBannerThatWentOutIsNotRepeated() async {
        let clock = AlertFixture.TestClock()
        let store = AlertFixture.store()
        store.save([alert.id: interruptedState(requestedAt: clock.now.addingTimeInterval(-60))])

        let (service, recorder) = AlertFixture.service(store, clock: clock)
        recorder.delivered = [
            DeliveredRequest(
                identifier: NotificationService.requestIdentifier(
                    for: alert.id, value: Decimal(string: "6.01")!),
                date: clock.now.addingTimeInterval(-30))
        ]

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])

        #expect(recorder.sent.isEmpty)
        #expect(service.state(for: alert.id)?.phase == .triggered)
        #expect(service.state(for: alert.id)?.lastNotifiedAt == clock.now.addingTimeInterval(-30))
    }

    /// Not listed: it never went out, or the person already cleared it. The
    /// banner is owed, and sending it is the side to err on — a repeat is
    /// better than a crossing nobody heard about.
    @Test func anInterruptedBannerThatIsNotListedIsSent() async {
        let clock = AlertFixture.TestClock()
        let store = AlertFixture.store()
        store.save([alert.id: interruptedState(requestedAt: clock.now.addingTimeInterval(-60))])

        let (service, recorder) = AlertFixture.service(store, clock: clock)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])

        #expect(recorder.sent.count == 1)
    }

    /// Mid-request when the app stopped, handed over at `requestedAt`.
    private func interruptedState(requestedAt: Date) -> AlertState {
        var state = AlertState()
        _ = state.observe(
            bid: Decimal(string: "6.01")!, for: alert, rules: .standard, now: requestedAt)
        state.beginDelivery(at: requestedAt)
        return state
    }

    /// A banner from an earlier crossing can still sit in Notification
    /// Center. It is not the one the app was sending when it stopped.
    @Test func anOlderBannerDoesNotCountForTheInterruptedOne() async {
        let clock = AlertFixture.TestClock()
        let store = AlertFixture.store()
        store.save([alert.id: interruptedState(requestedAt: clock.now.addingTimeInterval(-60))])

        let (service, recorder) = AlertFixture.service(store, clock: clock)
        recorder.delivered = [
            DeliveredRequest(
                identifier: NotificationService.requestIdentifier(
                    for: alert.id, value: Decimal(string: "6.01")!),
                date: clock.now.addingTimeInterval(-86_400))
        ]

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])

        #expect(recorder.sent.count == 1)
    }

    // MARK: - Cooldown and persistence

    /// Marking the alert as triggered before checking the cooldown swallowed
    /// the recross: the banner never fired, and it also did not fire after
    /// the fifteen minutes.
    @Test func aRecrossDuringCooldownIsDeliveredAfterTheFloor() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        clock.advance(60)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "5.97", clock: clock)])
        clock.advance(60)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(recorder.sent.count == 1)

        clock.advance(781)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(recorder.sent.count == 2)
    }

    /// An in-memory set started empty on launch, so every alert whose
    /// condition already held fired again each time the app opened.
    @Test func reopeningTheAppDoesNotRepeatABanner() async {
        let clock = AlertFixture.TestClock()
        let store = AlertFixture.store()
        let (first, sentBefore) = AlertFixture.service(store, clock: clock)
        await first.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])

        let (reopened, sentAfter) = AlertFixture.service(store, clock: clock)
        clock.advance(3_000)
        await reopened.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])

        #expect(sentBefore.sent.count == 1)
        #expect(sentAfter.sent.isEmpty)
    }

    /// Quitting and reopening is not a way around the cooldown, and it does
    /// not hold the alert back past it either.
    @Test func reopeningTheAppKeepsTheCooldown() async {
        let clock = AlertFixture.TestClock()
        let store = AlertFixture.store()
        let (first, _) = AlertFixture.service(store, clock: clock)
        await first.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        clock.advance(60)
        await first.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "5.95", clock: clock)])

        let (reopened, recorder) = AlertFixture.service(store, clock: clock)
        clock.advance(60)
        await reopened.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(recorder.sent.isEmpty)

        clock.advance(780)
        await reopened.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(recorder.sent.count == 1)
    }

    /// Installs from before the state machine kept two keys: a set of fired
    /// ids and their last banner. Read once so an upgrade does not re-announce
    /// every alert that already fired.
    @Test func theLegacyStateIsCarriedOver() async {
        let clock = AlertFixture.TestClock()
        let defaults = AlertFixture.freshDefaults()
        defaults.set([alert.id.uuidString], forKey: "triggeredAlerts")
        defaults.set([alert.id.uuidString: clock.now], forKey: "alertLastNotified")

        let (service, recorder) = AlertFixture.service(
            UserDefaultsAlertStateStore(defaults: defaults), clock: clock)
        clock.advance(3_000)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])

        #expect(recorder.sent.isEmpty)
        #expect(service.state(for: alert.id)?.phase == .triggered)
    }
}
