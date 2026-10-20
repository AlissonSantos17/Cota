import Foundation
import Testing
import UserNotifications

@testable import CotaKit

@Suite @MainActor
struct NotificationServiceTests {
    private let alert = PriceAlert(
        pair: "EUR-BRL",
        threshold: Decimal(string: "6")!,
        isAbove: true
    )

    // MARK: - Arming

    @Test func aCrossingNotifiesOnce() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])

        #expect(recorder.sent.count == 1)
        #expect(recorder.sent.first?.value == Decimal(string: "6.01"))
    }

    /// Muting an alert used to wipe its memory of having fired, so switching
    /// it back on notified again at once. The toggle promised a pause and
    /// delivered a reset.
    @Test func switchingAnAlertOffAndOnDoesNotRenotify() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        await service.checkAlerts([alert], against: price)

        var muted = alert
        muted.isEnabled = false
        await service.checkAlerts([muted], against: price)
        await service.checkAlerts([alert], against: price)

        #expect(recorder.sent.count == 1)
    }

    /// The case the toggle used to get wrong the other way: the price fell
    /// past the rearm line while the alert was off. That fall was observed, so
    /// the crossing after re-enabling is a new event and is announced.
    @Test func aRearmWhileMutedLetsTheNextCrossingThrough() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        var muted = alert
        muted.isEnabled = false

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        clock.advance(300)
        await service.checkAlerts(
            [muted], against: [AlertFixture.quote("EUR-BRL", bid: "5.95", clock: clock)])
        clock.advance(300)
        await service.checkAlerts(
            [muted], against: [AlertFixture.quote("EUR-BRL", bid: "6.05", clock: clock)])
        #expect(recorder.sent.count == 1)

        clock.advance(600)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.05", clock: clock)])

        #expect(recorder.sent.count == 2)
    }

    @Test func aMutedAlertDoesNotNotify() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        var muted = alert
        muted.isEnabled = false
        await service.checkAlerts(
            [muted], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])

        #expect(recorder.sent.isEmpty)
    }

    /// Deleting is a real reset — the state of an alert that no longer exists
    /// has to go, or it accumulates forever.
    @Test func deletingAnAlertClearsItsState() async {
        let clock = AlertFixture.TestClock()
        let store = AlertFixture.store()
        let (service, _) = AlertFixture.service(store, clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        await service.checkAlerts([alert], against: price)
        await service.checkAlerts([], against: price)

        #expect(service.state(for: alert.id) == nil)
        #expect(store.load().isEmpty)
    }

    /// Re-creating an alert with the same threshold is a new alert, and a new
    /// alert whose condition already holds says so.
    @Test func aRecreatedAlertNotifiesAgain() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        await service.checkAlerts([alert], against: price)
        await service.checkAlerts([], against: price)

        let recreated = PriceAlert(pair: "EUR-BRL", threshold: Decimal(string: "6")!, isAbove: true)
        await service.checkAlerts([recreated], against: price)

        #expect(recorder.sent.count == 2)
    }

    // MARK: - Permission

    /// The request used to discard the result, so a denial left alerts armed
    /// and silent with nothing on screen saying why.
    @Test func aDeniedAuthorizationIsRecorded() async {
        let (service, _) = AlertFixture.service(
            AlertFixture.store(), clock: AlertFixture.TestClock())
        service.resolveAuthorization = { false }
        await service.refreshAuthorization()
        #expect(service.authorizationDenied)
    }

    /// With banners refused the crossing was marked as fired anyway, so the
    /// alert was spent on a notification nobody could receive.
    @Test func aDeniedAuthorizationDoesNotConsumeTheAlert() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        service.resolveAuthorization = { false }
        await service.checkAlerts([alert], against: price)

        #expect(recorder.sent.isEmpty)
        #expect(service.state(for: alert.id)?.phase == .conditionMet)
    }

    /// Permission used to be read once, at launch. Someone who allowed
    /// banners in System Settings with the app open kept getting nothing
    /// until they quit and reopened it.
    @Test func grantingPermissionWhileRunningNeedsNoRelaunch() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        service.resolveAuthorization = { false }
        await service.refreshAuthorization()
        await service.checkAlerts([alert], against: price)

        service.resolveAuthorization = { true }
        clock.advance(300)
        await service.checkAlerts([alert], against: price)

        #expect(recorder.sent.count == 1)
        #expect(!service.authorizationDenied)
    }

    /// The opposite change: permission revoked with the app open. The cached
    /// flag still said "allowed", the alert was marked as fired, and the
    /// request went nowhere. The banner is owed until it can be shown.
    @Test func revokingPermissionWhileRunningKeepsTheBannerOwed() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        clock.advance(300)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "5.95", clock: clock)])

        service.resolveAuthorization = { false }
        clock.advance(900)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])

        #expect(recorder.sent.count == 1)
        #expect(service.authorizationDenied)
        #expect(service.state(for: alert.id)?.phase == .conditionMet)

        service.resolveAuthorization = { true }
        clock.advance(300)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])

        #expect(recorder.sent.count == 2)
    }

    // MARK: - Delivery

    /// The alert used to be marked as fired before the request was made, so a
    /// request the centre refused left it fired with nothing on screen. Now
    /// it waits out the backoff and the retry describes the price at the
    /// retry, not the one at the refusal.
    @Test func aRefusedRequestIsRetriedAfterTheBackoffWithTheCurrentPrice() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        recorder.refusals = [AlertFixture.Refused()]
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(service.state(for: alert.id)?.phase == .conditionMet)

        clock.advance(30)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.02", clock: clock)])
        #expect(recorder.sent.isEmpty)

        clock.advance(30)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.03", clock: clock)])

        #expect(recorder.sent.map(\.value) == [Decimal(string: "6.03")!])
        #expect(service.state(for: alert.id)?.phase == .triggered)
    }

    /// The centre rejecting the request itself — no content, a bad attachment
    /// — fails identically every time. One attempt, then this crossing is
    /// left alone instead of costing a request per fetch.
    @Test func aRequestTheCentreRejectsIsNotRetried() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        recorder.refusals = [UNErrorFixture.invalidContent]
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        clock.advance(10_000)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])

        #expect(recorder.sent.isEmpty)
        #expect(service.state(for: alert.id)?.deliveryAbandoned == true)
    }

    /// "Notifications not allowed" from `add` is the permission changing under
    /// the check that just passed. It is a permission problem, not a failed
    /// request: the Settings warning shows and no backoff step is spent.
    @Test func aNotAllowedRefusalIsTreatedAsMissingPermission() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)

        recorder.refusals = [UNErrorFixture.notAllowed]
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])

        #expect(service.authorizationDenied)
        #expect(service.state(for: alert.id)?.failedAttempts == 0)

        clock.advance(1)
        await service.checkAlerts(
            [alert], against: [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)])
        #expect(recorder.sent.count == 1)
    }

    @Test func refusalsAreClassifiedForRetrying() {
        #expect(NotificationService.classify(UNErrorFixture.notAllowed) == .notAllowed)
        #expect(NotificationService.classify(UNErrorFixture.invalidContent) == .failed(.permanent))
        #expect(NotificationService.classify(AlertFixture.Refused()) == .failed(.transient))
    }

    /// The centre reports refusals from Objective-C, as plain `NSError`s in
    /// `UNErrorDomain`, not as the Swift `UNError` the fixtures build. The
    /// classification has to hold for the form that actually arrives.
    @Test func refusalsArrivingAsNSErrorAreClassifiedTheSame() {
        let notAllowed = NSError(domain: UNErrorDomain, code: 1)
        let noContent = NSError(domain: UNErrorDomain, code: 1401)
        let unknownCode = NSError(domain: UNErrorDomain, code: 9_999)
        let otherDomain = NSError(domain: NSCocoaErrorDomain, code: 1)

        #expect(NotificationService.classify(notAllowed) == .notAllowed)
        #expect(NotificationService.classify(noContent) == .failed(.permanent))
        #expect(NotificationService.classify(unknownCode) == .failed(.transient))
        #expect(NotificationService.classify(otherDomain) == .failed(.transient))
    }

    /// A quote that arrives while the centre is still answering for the last
    /// one — a coalesced refresh does exactly that — must not ask twice.
    @Test func aBannerInFlightIsNotAskedForTwice() async {
        let clock = AlertFixture.TestClock()
        let (service, recorder) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        var release: CheckedContinuation<Void, Never>?
        service.deliver = { alert, value in
            await withCheckedContinuation { release = $0 }
            recorder.sent.append((alert.id, value))
        }

        let first = Task { await service.checkAlerts([alert], against: price) }
        while release == nil { await Task.yield() }

        await service.checkAlerts([alert], against: price)
        release?.resume()
        await first.value

        #expect(recorder.sent.count == 1)
        #expect(service.state(for: alert.id)?.phase == .triggered)
    }

    /// Removed while its banner was in flight: the answer arrives for an
    /// alert that no longer exists and must not bring its state back.
    @Test func anAlertDeletedDuringDeliveryLeavesNoState() async {
        let clock = AlertFixture.TestClock()
        let (service, _) = AlertFixture.service(AlertFixture.store(), clock: clock)
        let price = [AlertFixture.quote("EUR-BRL", bid: "6.01", clock: clock)]

        var release: CheckedContinuation<Void, Never>?
        service.deliver = { _, _ in await withCheckedContinuation { release = $0 } }

        let first = Task { await service.checkAlerts([alert], against: price) }
        while release == nil { await Task.yield() }

        await service.checkAlerts([], against: price)
        release?.resume()
        await first.value

        #expect(service.state(for: alert.id) == nil)
    }

    // MARK: - Banner content

    /// The banner had a number format of its own, fixed at four decimals, so
    /// BTC arrived as `398.348,0000` — the exact defect `QuoteFormat` was
    /// extracted to end everywhere else.
    @Test func theNotificationUsesTheSharedNumberFormat() {
        let btc = PriceAlert(
            pair: "BTC-BRL",
            threshold: Decimal(string: "400000")!,
            isAbove: false
        )

        let body = NotificationService.body(
            for: btc,
            currentValue: Decimal(string: "398348.12")!,
            change: nil
        )

        #expect(body.contains("398.348"))
        #expect(!body.contains("398.348,1200"))
        #expect(NotificationService.title(for: btc).contains("400.000"))
    }

    /// Below ten the fourth decimal is where the movement lives, and the shared
    /// rule keeps it — the banner is not a narrower surface than the panel.
    @Test func theNotificationBodyKeepsPrecisionOnSmallValues() {
        let body = NotificationService.body(
            for: alert,
            currentValue: Decimal(string: "6.0123")!,
            change: nil
        )

        #expect(body.contains("6,0123"))
    }

    /// ✕ is a multiplication sign. Currency.swift refuses it as a glyph;
    /// the notification title used to ship it for XRP anyway.
    @Test func notificationFlagsComeFromTheCurrencyTable() {
        #expect(NotificationService.flag(for: "USD") == "🇺🇸")
        #expect(NotificationService.flag(for: "BTC") == "₿")
        #expect(NotificationService.flag(for: "XRP") == "XRP")
        #expect(NotificationService.flag(for: "XRP") != "✕")
    }
}
