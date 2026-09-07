import Foundation
import UserNotifications

@MainActor
public final class NotificationService: NSObject, UNUserNotificationCenterDelegate,
    ObservableObject
{
    public static let shared = NotificationService()

    private enum Keys {
        static let triggered = "triggeredAlerts"
        static let lastNotified = "alertLastNotified"
    }

    /// How far past the threshold the price must come back before an alert can
    /// fire again. Without it a price sitting on the threshold notifies on
    /// every crossing, which for a quote refreshed every few minutes means a
    /// stream of banners for a single event.
    private static let rearmMargin = Decimal(string: "0.003")!

    /// Floor between two notifications for the same alert.
    private static let cooldown: TimeInterval = 900

    private let defaults: UserDefaults

    /// Persisted: an in-memory set starts empty on launch, so every alert
    /// whose condition already held fired again each time the app opened.
    private var triggeredAlerts: Set<UUID>
    private var lastNotified: [UUID: Date]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.triggeredAlerts = Set(
            (defaults.stringArray(forKey: Keys.triggered) ?? []).compactMap(UUID.init(uuidString:))
        )
        self.lastNotified =
            (defaults.dictionary(forKey: Keys.lastNotified) as? [String: Date] ?? [:])
            .reduce(into: [:]) { result, entry in
                if let id = UUID(uuidString: entry.key) {
                    result[id] = entry.value
                }
            }
        super.init()
    }

    /// How a due alert reaches the person. Injectable so the arming rules can
    /// be tested without a notification centre — those rules are about which
    /// alerts are due, not about how a banner is drawn.
    lazy var deliver: (PriceAlert, Decimal) -> Void = { [weak self] alert, value in
        self?.send(alert: alert, currentValue: value)
    }

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

    public func refreshAuthorization() async {
        authorizationDenied = !(await resolveAuthorization())
    }

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

    public func checkAlerts(_ alerts: [PriceAlert], against quotes: [Quote], now: Date = .now) {
        // Garbage collection is about the alert existing, not about it being
        // on. Filtering by `isEnabled` here made switching an alert off wipe
        // its arming state, so switching it back on re-notified immediately if
        // the price was still past the threshold — the toggle promised a pause
        // and delivered a reset. A muted alert keeps remembering that it fired.
        let knownIDs = Set(alerts.map(\.id))
        triggeredAlerts.formIntersection(knownIDs)
        lastNotified = lastNotified.filter { knownIDs.contains($0.key) }

        for alert in alerts where alert.isEnabled {
            guard let quote = quotes.first(where: { "\($0.code)-\($0.codein)" == alert.pair })
            else {
                continue
            }

            if isTriggered(alert, bid: quote.bid) {
                guard !triggeredAlerts.contains(alert.id) else { continue }

                // Banners refused: the alert stays armed rather than being
                // spent on a notification nobody can receive. Consuming it here
                // meant that granting permission later still bought silence,
                // because a threshold already crossed may never rearm.
                guard !authorizationDenied else { continue }

                if let last = lastNotified[alert.id], now.timeIntervalSince(last) < Self.cooldown {
                    continue
                }

                triggeredAlerts.insert(alert.id)
                lastNotified[alert.id] = now
                deliver(alert, quote.bid)
            } else if hasRearmed(alert, bid: quote.bid) {
                triggeredAlerts.remove(alert.id)
            }
        }

        persist()
    }

    private func isTriggered(_ alert: PriceAlert, bid: Decimal) -> Bool {
        alert.isAbove ? bid >= alert.threshold : bid <= alert.threshold
    }

    /// The price has to clear the threshold by the margin, not merely cross
    /// back over it, before the alert arms again.
    private func hasRearmed(_ alert: PriceAlert, bid: Decimal) -> Bool {
        let margin = alert.threshold * Self.rearmMargin

        return alert.isAbove
            ? bid < alert.threshold - margin
            : bid > alert.threshold + margin
    }

    private func persist() {
        defaults.set(triggeredAlerts.map(\.uuidString), forKey: Keys.triggered)
        defaults.set(
            Dictionary(uniqueKeysWithValues: lastNotified.map { ($0.key.uuidString, $0.value) }),
            forKey: Keys.lastNotified
        )
    }

    private func send(alert: PriceAlert, currentValue: Decimal) {
        let baseCode = alert.pair.split(separator: "-").first.map(String.init) ?? alert.pair

        let content = UNMutableNotificationContent()
        content.title = "\(Self.flag(for: baseCode)) Threshold Reached"
        content.body = Self.body(for: alert, currentValue: currentValue)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(alert.id.uuidString)-\(QuoteFormat.value(currentValue))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Through `QuoteFormat` like every other surface. The banner used to fix
    /// four decimals of its own, which printed BTC as `398.348,0000`.
    static func body(for alert: PriceAlert, currentValue: Decimal) -> String {
        let direction = alert.isAbove ? "above" : "below"
        let threshold = QuoteFormat.value(alert.threshold)
        let current = QuoteFormat.value(currentValue)

        return "Price is now \(current) (\(direction) your \(threshold) alert)."
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
