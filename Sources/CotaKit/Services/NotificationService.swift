import Foundation
import UserNotifications

/// Why an alert is not being evaluated right now. Settings shows it, so a
/// silent alert is never a mystery.
public enum AlertPause: Equatable, Sendable {
    /// The latest quote for the pair is older than the allowed age.
    case staleQuote
    /// The latest quote has no timestamp, or one from the future: its age
    /// cannot be known.
    case untimedQuote
}

/// A banner Notification Center still lists, as far as the relaunch check
/// needs it.
struct DeliveredRequest: Equatable {
    let identifier: String
    let date: Date
}

/// What a refusal from `add` means for the alert.
enum Refusal: Equatable {
    /// Permission changed under the check that had just passed.
    case notAllowed
    case failed(DeliveryFailure)
}

/// Decides which alerts are owed a banner and asks the system to show it.
///
/// The life cycle of each alert is `AlertState`; this service feeds it the
/// quotes, checks permission at the moment a banner is due, and reports back
/// what the notification centre answered.
@MainActor
public final class NotificationService: NSObject, UNUserNotificationCenterDelegate,
    ObservableObject
{
    public static let shared = NotificationService()

    private let store: AlertStateStore
    private let rules: AlertRules
    private let clock: () -> Date

    private var states: [UUID: AlertState]

    /// Whether requests left in flight by the previous run were settled.
    /// Once per launch: after that, `requesting` only means "in flight now".
    private var hasReconciled = false

    /// A clock this far ahead of ours is drift between machines. Further
    /// than that, the timestamp is not to be trusted.
    private static let clockSkewTolerance: TimeInterval = 300

    init(
        store: AlertStateStore = UserDefaultsAlertStateStore(),
        rules: AlertRules = .standard,
        clock: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.rules = rules
        self.clock = clock
        self.states = store.load()
        super.init()
        deliver = { [weak self] alert, value in
            try await NotificationService.post(
                alert: alert, currentValue: value, change: self?.changes[alert.pair])
        }
    }

    /// How a due alert reaches the person. Throws when the notification
    /// centre refuses the request. Injectable so the rules can be tested
    /// without a notification centre.
    var deliver: (PriceAlert, Decimal) async throws -> Void = { alert, value in
        try await NotificationService.post(alert: alert, currentValue: value, change: nil)
    }

    /// The day's change per pair from the last check, for the banner body.
    private var changes: [String: Decimal] = [:]

    /// What Notification Center still shows. Injectable for the same reason
    /// as `deliver`.
    var deliveredRequests: () async -> [DeliveredRequest] = {
        await NotificationService.systemDeliveredRequests()
    }

    /// Alerts left out of the last evaluation, and why.
    @Published public private(set) var pauses: [UUID: AlertPause] = [:]

    /// True when the person has refused banners. Alerts stay armed; they just
    /// cannot appear, and Settings has to say so.
    @Published public private(set) var authorizationDenied = false

    /// Injectable so the denial path can be tested without a notification centre.
    var resolveAuthorization: () async -> Bool = {
        await NotificationService.systemAuthorization()
    }

    public func requestPermission() {
        // Set here rather than in `init`: `UNUserNotificationCenter.current()`
        // needs a real bundle, and the app calls this at launch anyway.
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthorization() }
    }

    /// Reads the permission as System Settings has it now. Called at launch,
    /// whenever the app becomes active, and before every banner — the switch
    /// in System Settings can change at any time while the app runs.
    public func refreshAuthorization() async {
        authorizationDenied = !(await resolveAuthorization())
    }

    /// The state of one alert, or nil when it has never been evaluated.
    public func state(for id: UUID) -> AlertState? {
        states[id]
    }

    public func pause(for id: UUID) -> AlertPause? {
        pauses[id]
    }

    /// Runs every alert against the quotes just fetched, then asks for the
    /// banners that came due.
    public func checkAlerts(_ alerts: [PriceAlert], against quotes: [Quote]) async {
        await reconcileInterruptedDeliveries()
        let now = clock()

        // Garbage collection is about the alert existing, not about it being
        // on: a muted alert keeps remembering that it fired.
        let knownIDs = Set(alerts.map(\.id))
        states = states.filter { knownIDs.contains($0.key) }

        changes = Dictionary(quotes.map { ($0.id, $0.pctChange) }, uniquingKeysWith: { $1 })

        var due: [(alert: PriceAlert, bid: Decimal)] = []
        var pauses: [UUID: AlertPause] = [:]
        for alert in alerts {
            guard let quote = quotes.first(where: { $0.id == alert.pair }) else { continue }

            // Neither fires nor rearms: either would act on a price that may
            // no longer exist.
            if let pause = Self.pause(for: quote, now: now, rules: rules) {
                pauses[alert.id] = pause
                continue
            }

            var state = states[alert.id] ?? AlertState()
            if state.observe(bid: quote.bid, for: alert, rules: rules, now: now) {
                due.append((alert, quote.bid))
            }
            states[alert.id] = state
        }

        self.pauses = pauses
        store.save(states)
        guard !due.isEmpty else { return }

        // Asked now rather than trusted from launch. Denied, the banners stay
        // owed: spending them on a request nobody can see meant granting
        // permission later still bought silence.
        await refreshAuthorization()
        guard !authorizationDenied else { return }

        for (alert, bid) in due {
            await send(alert, bid: bid)
        }
    }

    /// The alert is marked as notified only once the centre accepts the
    /// request. That is as far as an app can know: whether the person looked
    /// at the banner is not something the system reports.
    private func send(_ alert: PriceAlert, bid: Decimal) async {
        // Due when the loop ran, but the permission check awaited: another
        // check may have taken it, or the alert may have been deleted.
        guard states[alert.id]?.phase == .conditionMet else { return }

        // Saved before the request, so a relaunch knows it was in flight.
        states[alert.id]?.beginDelivery(at: clock())
        store.save(states)

        do {
            try await deliver(alert, bid)
            states[alert.id]?.deliverySucceeded(at: clock())
        } catch {
            switch Self.classify(error) {
            case .notAllowed:
                authorizationDenied = true
                states[alert.id]?.deliveryDeferred()
            case .failed(let failure):
                states[alert.id]?.deliveryFailed(failure, at: clock(), rules: rules)
            }
        }

        store.save(states)
    }

    /// The previous run stopped with banners in flight. Notification Center
    /// says which went out: one listed from the moment of the request on was
    /// it, and is not sent again. Anything else is still owed. Erring towards
    /// sending: a repeat is better than a crossing nobody heard about.
    private func reconcileInterruptedDeliveries() async {
        guard !hasReconciled else { return }
        hasReconciled = true

        let interrupted = states.filter { $0.value.phase == .requesting }.map(\.key)
        guard !interrupted.isEmpty else { return }

        let delivered = await deliveredRequests()
        for id in interrupted {
            guard let state = states[id], state.phase == .requesting else { continue }
            let prefix = "\(id.uuidString)-"
            let since = state.requestedAt ?? .distantPast
            let sent =
                delivered
                .filter { $0.identifier.hasPrefix(prefix) && $0.date >= since }
                .map(\.date)
                .max()

            if let sent {
                states[id]?.deliverySucceeded(at: sent)
            } else {
                states[id]?.deliveryDeferred()
            }
        }

        store.save(states)
    }

    /// Only a quote whose age is known and within the limit describes the
    /// market now. Without a timestamp there is no age to check.
    private static func pause(for quote: Quote, now: Date, rules: AlertRules) -> AlertPause? {
        guard let updatedAt = quote.updatedAt,
            updatedAt.timeIntervalSince(now) <= clockSkewTolerance
        else { return .untimedQuote }

        return now.timeIntervalSince(updatedAt) > rules.maxQuoteAge ? .staleQuote : nil
    }

    /// The centre's validation errors describe the request, which is built the
    /// same way every time: retrying cannot help. Anything else — an error
    /// from another domain, a code added later — is treated as one that can
    /// clear up, so the alert is not given up on by mistake.
    static func classify(_ error: Error) -> Refusal {
        guard let error = error as? UNError else { return .failed(.transient) }

        switch error.code {
        case .notificationsNotAllowed:
            return .notAllowed
        case .attachmentInvalidURL, .attachmentUnrecognizedType, .attachmentInvalidFileSize,
            .attachmentNotInDataStore, .attachmentMoveIntoDataStoreFailed, .attachmentCorrupt,
            .notificationInvalidNoDate, .notificationInvalidNoContent,
            .contentProvidingObjectNotAllowed, .contentProvidingInvalid, .badgeInputInvalid:
            return .failed(.permanent)
        default:
            return .failed(.transient)
        }
    }

    /// One identifier per banner. Starts with the alert's id, which is how
    /// the relaunch check finds an alert's banners in Notification Center.
    static func requestIdentifier(for id: UUID, value: Decimal) -> String {
        "\(id.uuidString)-\(QuoteFormat.value(value))"
    }

    // MARK: - System

    private static func systemAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            return false
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private static func systemDeliveredRequests() async -> [DeliveredRequest] {
        await UNUserNotificationCenter.current().deliveredNotifications().map {
            DeliveredRequest(identifier: $0.request.identifier, date: $0.date)
        }
    }

    private static func post(
        alert: PriceAlert, currentValue: Decimal, change: Decimal?
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title(for: alert)
        content.body = body(for: alert, currentValue: currentValue, change: change)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: requestIdentifier(for: alert.id, value: currentValue),
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    /// "Euro rose above R$ 5.75": the currency by name and the threshold
    /// with the destination's symbol, so the banner says what crossed what
    /// without the pair code.
    static func title(for alert: PriceAlert) -> String {
        let display = PairDisplay(id: alert.pair)
        let threshold =
            "\(Currency.named(display.quote).moneySymbol) \(QuoteFormat.threshold(alert.threshold))"
        let key = alert.isAbove ? "notification.crossedAbove" : "notification.crossedBelow"
        return L10n.t(key, L10n.currencyName(display.base), threshold)
    }

    /// Through `QuoteFormat` like every other surface. The banner used to fix
    /// four decimals of its own, which printed BTC as `398.348,0000`.
    static func body(for alert: PriceAlert, currentValue: Decimal, change: Decimal?) -> String {
        let current = QuoteFormat.money(currentValue, currency: PairDisplay(id: alert.pair).quote)
        guard let change else { return L10n.t("notification.bodyNoChange", current) }
        let arrow = change < 0 ? "▼" : "▲"
        return L10n.t(
            "notification.body", current, "\(arrow) \(QuoteFormat.percentMagnitude(change))")
    }

    static func flag(for code: String) -> String {
        let currency = Currency.named(code)
        return currency.flag ?? currency.symbol ?? code
    }

    /// Nonisolated: it reads nothing from the service, and taking the two
    /// non-Sendable UserNotifications types onto the main actor is an error in
    /// the Swift 6 language mode.
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
