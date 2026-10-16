import Foundation
import UserNotifications

@testable import CotaKit

/// Shared by the notification suites: a hand-moved clock, a notification
/// centre that records instead of drawing, and quotes built the way the app
/// decodes them.
@MainActor
enum AlertFixture {
    static func freshDefaults() -> UserDefaults {
        let name = "NotificationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Time the test moves by hand, so fifteen minutes of cooldown take none.
    final class TestClock {
        var now = Date(timeIntervalSince1970: 1_000_000)

        func advance(_ seconds: TimeInterval) {
            now = now.addingTimeInterval(seconds)
        }
    }

    /// What the service handed to the notification centre, and a switch to
    /// make the centre refuse the next request.
    final class Recorder {
        var sent: [(id: UUID, value: Decimal)] = []
        /// Errors the centre answers with, one per request, before it starts
        /// accepting again.
        var refusals: [Error] = []
        /// What Notification Center still shows, for the relaunch check.
        var delivered: [DeliveredRequest] = []
    }

    struct Refused: Error {}

    /// `Quote` is decode-only, so samples are built the way the app gets them.
    /// The timestamp defaults to the clock: a quote fetched just now.
    static func quote(
        _ pair: String, bid: String, updatedAt: Date? = nil, timestamped: Bool = true,
        clock: TestClock
    ) -> Quote {
        let parts = pair.split(separator: "-")
        let seconds = Int((updatedAt ?? clock.now).timeIntervalSince1970)
        let timestamp = timestamped ? #", "timestamp": "\#(seconds)""# : ""
        let json = """
            {
              "code": "\(parts[0])", "codein": "\(parts[1])", "name": "\(pair)",
              "bid": "\(bid)", "pctChange": "0", "create_date": "2026-09-01 09:12:00"\(timestamp)
            }
            """
        return try! JSONDecoder().decode(Quote.self, from: Data(json.utf8))
    }

    /// A service that records what it would have sent instead of drawing a
    /// banner, with permission granted unless a test says otherwise.
    static func service(
        _ store: AlertStateStore, clock: TestClock
    ) -> (NotificationService, Recorder) {
        let service = NotificationService(store: store, clock: { clock.now })
        let recorder = Recorder()
        service.resolveAuthorization = { true }
        service.deliver = { alert, value in
            if !recorder.refusals.isEmpty {
                throw recorder.refusals.removeFirst()
            }
            recorder.sent.append((alert.id, value))
        }
        service.deliveredRequests = { recorder.delivered }
        return (service, recorder)
    }

    static func store() -> UserDefaultsAlertStateStore {
        UserDefaultsAlertStateStore(defaults: freshDefaults())
    }
}

/// The two kinds of refusal the centre is known to answer `add` with.
enum UNErrorFixture {
    static let notAllowed = UNError(.notificationsNotAllowed)
    static let invalidContent = UNError(.notificationInvalidNoContent)
}
