import Foundation
import Testing

@testable import CotaKit

@Suite @MainActor
struct NotificationServiceTests {
    private func freshDefaults() -> UserDefaults {
        let name = "NotificationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// `Quote` is decode-only, so samples are built the way the app gets them.
    private func quote(_ pair: String, bid: String) -> Quote {
        let parts = pair.split(separator: "-")
        let json = """
            {
              "code": "\(parts[0])", "codein": "\(parts[1])", "name": "\(pair)",
              "bid": "\(bid)", "pctChange": "0", "create_date": "2026-09-01 09:12:00"
            }
            """
        return try! JSONDecoder().decode(Quote.self, from: Data(json.utf8))
    }

    /// A service that records what it would have sent instead of drawing a
    /// banner: these rules are about which alerts are due.
    private func service(_ defaults: UserDefaults) -> (NotificationService, Recorder) {
        let service = NotificationService(defaults: defaults)
        let recorder = Recorder()
        service.deliver = { alert, value in recorder.sent.append((alert.id, value)) }
        return (service, recorder)
    }

    private final class Recorder {
        var sent: [(id: UUID, value: Decimal)] = []
    }

    private let alert = PriceAlert(
        pair: "EUR-BRL",
        threshold: Decimal(string: "6")!,
        isAbove: true
    )

    // MARK: - Arming

    @Test func aCrossingNotifiesOnce() {
        let (service, recorder) = self.service(freshDefaults())

        service.checkAlerts([alert], against: [quote("EUR-BRL", bid: "6.01")])
        service.checkAlerts([alert], against: [quote("EUR-BRL", bid: "6.02")])

        #expect(recorder.sent.count == 1)
    }

    /// The defect this fix exists for: muting an alert used to wipe its memory
    /// of having fired, so switching it back on notified again at once. The
    /// toggle promised a pause and delivered a reset.
    @Test func switchingAnAlertOffAndOnDoesNotRenotify() {
        let (service, recorder) = self.service(freshDefaults())
        let price = [quote("EUR-BRL", bid: "6.01")]

        service.checkAlerts([alert], against: price)
        #expect(recorder.sent.count == 1)

        var muted = alert
        muted.isEnabled = false
        service.checkAlerts([muted], against: price)
        #expect(recorder.sent.count == 1)

        service.checkAlerts([alert], against: price)
        #expect(recorder.sent.count == 1)
    }

    @Test func aMutedAlertDoesNotNotify() {
        let (service, recorder) = self.service(freshDefaults())

        var muted = alert
        muted.isEnabled = false
        service.checkAlerts([muted], against: [quote("EUR-BRL", bid: "6.01")])

        #expect(recorder.sent.isEmpty)
    }

    /// Deleting is still a real reset — the state of an alert that no longer
    /// exists has to go, or it accumulates forever.
    @Test func deletingAnAlertClearsItsState() {
        let defaults = freshDefaults()
        let (service, _) = self.service(defaults)
        let price = [quote("EUR-BRL", bid: "6.01")]

        service.checkAlerts([alert], against: price)
        service.checkAlerts([], against: price)

        #expect((defaults.stringArray(forKey: "triggeredAlerts") ?? []).isEmpty)
    }

    /// Re-creating an alert with the same threshold is a new alert, and a new
    /// alert whose condition already holds should say so.
    @Test func aRecreatedAlertNotifiesAgain() {
        let (service, recorder) = self.service(freshDefaults())
        let price = [quote("EUR-BRL", bid: "6.01")]

        service.checkAlerts([alert], against: price)
        service.checkAlerts([], against: price)

        let recreated = PriceAlert(pair: "EUR-BRL", threshold: Decimal(string: "6")!, isAbove: true)
        service.checkAlerts([recreated], against: price)

        #expect(recorder.sent.count == 2)
    }

    /// The price has to clear the threshold by the margin before the alert
    /// arms again; sitting on it is one event, not a stream of them.
    @Test func rearmingNeedsTheMargin() {
        let (service, recorder) = self.service(freshDefaults())

        service.checkAlerts([alert], against: [quote("EUR-BRL", bid: "6.01")])
        service.checkAlerts([alert], against: [quote("EUR-BRL", bid: "5.999")])
        service.checkAlerts([alert], against: [quote("EUR-BRL", bid: "6.01")])

        #expect(recorder.sent.count == 1)
    }

    /// The request used to discard the result, so a denial left alerts armed
    /// and silent with nothing on screen saying why.
    @Test func aDeniedAuthorizationIsRecorded() async {
        let (service, _) = self.service(freshDefaults())
        service.resolveAuthorization = { false }
        await service.refreshAuthorization()
        #expect(service.authorizationDenied)
    }

    /// With banners refused the crossing was still marked as fired, so the
    /// alert was spent on a notification nobody could receive. Granting
    /// permission afterwards left it silent until the price rearmed — which
    /// for a threshold already crossed can be never.
    @Test func aDeniedAuthorizationDoesNotConsumeTheAlert() async {
        let (service, recorder) = self.service(freshDefaults())
        let price = [quote("EUR-BRL", bid: "6.01")]

        service.resolveAuthorization = { false }
        await service.refreshAuthorization()
        service.checkAlerts([alert], against: price)
        #expect(recorder.sent.isEmpty)

        service.resolveAuthorization = { true }
        await service.refreshAuthorization()
        service.checkAlerts([alert], against: price)

        #expect(recorder.sent.count == 1)
    }

    /// The banner had a number format of its own, fixed at four decimals, so
    /// BTC arrived as `398.348,0000` — the exact defect `QuoteFormat` was
    /// extracted to end everywhere else.
    @Test func theNotificationBodyUsesTheSharedNumberFormat() {
        let btc = PriceAlert(
            pair: "BTC-BRL",
            threshold: Decimal(string: "400000")!,
            isAbove: false
        )

        let body = NotificationService.body(
            for: btc,
            currentValue: Decimal(string: "398348.12")!
        )

        #expect(body.contains("398.348"))
        #expect(!body.contains("398.348,1200"))
        #expect(body.contains("400.000"))
    }

    /// Below ten the fourth decimal is where the movement lives, and the shared
    /// rule keeps it — the banner is not a narrower surface than the panel.
    @Test func theNotificationBodyKeepsPrecisionOnSmallValues() {
        let body = NotificationService.body(
            for: alert,
            currentValue: Decimal(string: "6.0123")!
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

    /// Marking the alert as triggered before checking the cooldown swallowed
    /// the recross: the banner never fired, and the alert stayed triggered so
    /// it also did not fire after the fifteen minutes.
    @Test func aRecrossDuringCooldownIsDeliveredAfterTheFloor() {
        let (service, recorder) = self.service(freshDefaults())
        let start = Date(timeIntervalSince1970: 1_000_000)

        service.checkAlerts(
            [alert], against: [quote("EUR-BRL", bid: "6.01")], now: start)
        #expect(recorder.sent.count == 1)

        service.checkAlerts(
            [alert], against: [quote("EUR-BRL", bid: "5.97")], now: start.addingTimeInterval(60))

        service.checkAlerts(
            [alert], against: [quote("EUR-BRL", bid: "6.01")], now: start.addingTimeInterval(120))
        #expect(recorder.sent.count == 1)

        service.checkAlerts(
            [alert], against: [quote("EUR-BRL", bid: "6.01")], now: start.addingTimeInterval(901))
        #expect(recorder.sent.count == 2)
    }
}
