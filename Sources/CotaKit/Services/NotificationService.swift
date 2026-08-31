import Foundation
import UserNotifications

@MainActor
public final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    private var triggeredAlerts: Set<UUID> = []

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    public func checkAlerts(_ alerts: [PriceAlert], against quotes: [Quote]) {
        let activeIDs = Set(alerts.filter(\.isEnabled).map(\.id))
        triggeredAlerts.formIntersection(activeIDs)

        for alert in alerts where alert.isEnabled {
            guard let quote = quotes.first(where: { "\($0.code)-\($0.codein)" == alert.pair }) else {
                continue
            }

            let isTriggered = alert.isAbove
                ? quote.bid >= alert.threshold
                : quote.bid <= alert.threshold

            if isTriggered {
                if !triggeredAlerts.contains(alert.id) {
                    triggeredAlerts.insert(alert.id)
                    send(alert: alert, currentValue: quote.bid)
                }
            } else {
                triggeredAlerts.remove(alert.id)
            }
        }
    }

    private func send(alert: PriceAlert, currentValue: Decimal) {
        let direction = alert.isAbove ? "above" : "below"
        let thresholdText = Self.format(alert.threshold)
        let currentText = Self.format(currentValue)
        let baseCode = alert.pair.split(separator: "-").first.map(String.init) ?? alert.pair
        let flag = Self.flag(for: baseCode)

        let content = UNMutableNotificationContent()
        content.title = "\(flag) Threshold Reached"
        content.body = "Price is now \(currentText) (\(direction) your \(thresholdText) alert)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(alert.id.uuidString)-\(currentText)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private static func format(_ value: Decimal) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(4))
                .locale(Locale(identifier: "pt_BR"))
        )
    }

    private static func flag(for code: String) -> String {
        switch code {
        case "EUR": return "🇪🇺"
        case "USD": return "🇺🇸"
        case "GBP": return "🇬🇧"
        case "BRL": return "🇧🇷"
        case "ARS": return "🇦🇷"
        case "CAD": return "🇨🇦"
        case "AUD": return "🇦🇺"
        case "JPY": return "🇯🇵"
        case "CHF": return "🇨🇭"
        case "CNY": return "🇨🇳"
        case "BTC": return "₿"
        case "ETH": return "Ξ"
        case "XRP": return "✕"
        default: return code
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
