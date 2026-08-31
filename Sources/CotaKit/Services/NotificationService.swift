import Foundation
import UserNotifications

public final class NotificationService: NSObject, UNUserNotificationCenterDelegate, Sendable {
    public static let shared = NotificationService()

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
        for alert in alerts where alert.isEnabled {
            guard let quote = quotes.first(where: { "\($0.code)-\($0.codein)" == alert.pair }) else {
                continue
            }

            let triggered = alert.isAbove
                ? quote.bid >= alert.threshold
                : quote.bid <= alert.threshold

            if triggered {
                send(alert: alert, currentValue: quote.bid)
            }
        }
    }

    private func send(alert: PriceAlert, currentValue: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = "Cota Alert"
        let direction = alert.isAbove ? "above" : "below"
        content.body = "\(alert.pair) is \(direction) \(alert.threshold) — currently at \(currentValue)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
