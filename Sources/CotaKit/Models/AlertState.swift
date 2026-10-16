import Foundation

/// Where one alert stands in its life cycle.
///
/// Three things used to share a single "triggered" flag: the price reaching
/// the threshold, a banner being asked for, and the system accepting it. They
/// can disagree — the condition holds while the cooldown runs, a request is
/// refused — and every disagreement was a lost or doubled notification.
public enum AlertPhase: String, Codable, Equatable, Sendable {
    /// Watching. Never notified, or notified so long ago that nothing is owed.
    case armed
    /// The price satisfies the alert and a banner is owed, but has not been
    /// asked for: the cooldown runs, permission is missing, or the last
    /// request was refused and the backoff runs.
    case conditionMet
    /// A banner was handed to the notification centre and the answer is not
    /// back yet. Read back after a relaunch, it means the app stopped before
    /// the answer came, and the service asks the centre what happened.
    case requesting
    /// The system accepted the banner. Waits for the price to clear the
    /// threshold by the rearm margin.
    case triggered
    /// The price cleared the margin after a banner. Can fire again, subject
    /// to the cooldown since that banner.
    case rearmed
}

/// The two numbers that keep one event from becoming a stream of banners, the
/// age past which a quote no longer describes the market, and how long to wait
/// after the notification centre refuses a banner.
public struct AlertRules: Equatable, Sendable {
    /// Share of the threshold the price must clear before the alert can fire
    /// again. A share rather than an amount, so it means the same for a yen
    /// at R$ 0,03 and a bitcoin at R$ 400.000.
    public var rearmMargin: Decimal
    /// Floor between two banners for the same alert.
    public var cooldown: TimeInterval
    /// A quote older than this is not evaluated at all: a banner saying
    /// "price is now X" has to be about now.
    public var maxQuoteAge: TimeInterval
    /// Wait before each retry of a banner the centre refused for a reason
    /// that can clear up. One step per failure; past the last step every
    /// retry waits the last step, so a refusal that does clear up is still
    /// caught while the price stays past the threshold.
    public var deliveryRetryDelays: [TimeInterval]

    public init(
        rearmMargin: Decimal,
        cooldown: TimeInterval,
        maxQuoteAge: TimeInterval,
        deliveryRetryDelays: [TimeInterval]
    ) {
        self.rearmMargin = rearmMargin
        self.cooldown = cooldown
        self.maxQuoteAge = maxQuoteAge
        self.deliveryRetryDelays = deliveryRetryDelays
    }

    public static let standard = AlertRules(
        rearmMargin: Decimal(string: "0.003")!,
        cooldown: 900,
        maxQuoteAge: 3600,
        deliveryRetryDelays: [60, 300, 900]
    )
}

/// Why the notification centre refused a banner, as far as retrying goes.
public enum DeliveryFailure: Equatable, Sendable {
    /// Could clear up on its own: worth asking again after a wait.
    case transient
    /// The request itself is invalid and would fail the same way every time.
    case permanent
}

/// One alert's state, persisted between launches. Transitions are the methods
/// below and nothing else, so each one can be tested by feeding prices in.
public struct AlertState: Codable, Equatable, Sendable {
    public private(set) var phase: AlertPhase
    /// When the system last accepted a banner for this alert. The cooldown is
    /// measured from here, and only from here: a refused request is not a
    /// banner anyone saw.
    public private(set) var lastNotifiedAt: Date?

    /// Refusals for the current crossing. Cleared when the crossing ends or a
    /// banner is accepted.
    public private(set) var failedAttempts = 0
    /// No retry before this date: the backoff after a transient refusal.
    public private(set) var retryAfter: Date?
    /// This crossing will not be retried in this run: the refusal was
    /// permanent. Not persisted, so a relaunch — the only thing that can
    /// change how the same request is answered — gets one more attempt. The
    /// alert stays; the next crossing starts afresh.
    public private(set) var deliveryAbandoned = false
    /// When the banner now in flight was handed over. After a relaunch, only
    /// a banner Notification Center dates from this moment on can be it.
    public private(set) var requestedAt: Date?

    public init(phase: AlertPhase = .armed, lastNotifiedAt: Date? = nil) {
        self.phase = phase
        self.lastNotifiedAt = lastNotifiedAt
    }

    /// Applies one observed bid and answers whether a banner is due now.
    ///
    /// A disabled alert keeps watching: it can rearm, so the crossing after it
    /// is switched back on is not swallowed, but it is never due.
    public mutating func observe(
        bid: Decimal, for alert: PriceAlert, rules: AlertRules, now: Date
    ) -> Bool {
        let reached = alert.isAbove ? bid >= alert.threshold : bid <= alert.threshold

        switch phase {
        case .requesting:
            return false

        case .triggered:
            if Self.cleared(bid, alert, margin: rules.rearmMargin) {
                phase = .rearmed
            }
            return false

        case .armed, .rearmed:
            guard reached, alert.isEnabled else { return false }
            phase = .conditionMet
            return isPastCooldown(rules, now: now)

        case .conditionMet:
            // The crossing ended before anyone was told. Telling them later
            // would describe a price that is no longer true. Nothing is
            // queued: a later crossing is judged on its own quote.
            guard reached else {
                phase = lastNotifiedAt == nil ? .armed : .rearmed
                clearFailures()
                return false
            }
            return alert.isEnabled && isPastCooldown(rules, now: now) && isPastBackoff(now: now)
        }
    }

    /// The banner is on its way; a second quote must not ask again.
    public mutating func beginDelivery(at date: Date) {
        guard phase == .conditionMet else { return }
        phase = .requesting
        requestedAt = date
    }

    public mutating func deliverySucceeded(at date: Date) {
        guard phase == .requesting else { return }
        phase = .triggered
        lastNotifiedAt = date
        requestedAt = nil
        clearFailures()
    }

    /// The centre refused the banner. Nobody saw anything, so it is still
    /// owed — after the backoff for a transient refusal, not again in this run
    /// when the refusal is permanent.
    public mutating func deliveryFailed(
        _ failure: DeliveryFailure, at date: Date, rules: AlertRules
    ) {
        guard phase == .requesting else { return }
        phase = .conditionMet
        requestedAt = nil
        failedAttempts += 1

        let delays = rules.deliveryRetryDelays
        if failure == .permanent {
            deliveryAbandoned = true
            retryAfter = nil
        } else if delays.isEmpty {
            retryAfter = nil
        } else {
            let step = min(failedAttempts, delays.count) - 1
            retryAfter = date.addingTimeInterval(delays[step])
        }
    }

    /// The request never got a real answer: permission was missing, or the
    /// app stopped first. Owed as before, without spending a backoff step.
    public mutating func deliveryDeferred() {
        guard phase == .requesting else { return }
        phase = .conditionMet
        requestedAt = nil
    }

    private mutating func clearFailures() {
        failedAttempts = 0
        retryAfter = nil
        deliveryAbandoned = false
    }

    private func isPastBackoff(now: Date) -> Bool {
        guard !deliveryAbandoned else { return false }
        guard let retryAfter else { return true }
        return now >= retryAfter
    }

    private func isPastCooldown(_ rules: AlertRules, now: Date) -> Bool {
        guard let last = lastNotifiedAt else { return true }
        return now.timeIntervalSince(last) >= rules.cooldown
    }

    /// Past the threshold by the margin, on the far side from the alert.
    /// Strict: sitting exactly on the line is still the same event.
    private static func cleared(_ bid: Decimal, _ alert: PriceAlert, margin: Decimal) -> Bool {
        let distance = alert.threshold * margin
        return alert.isAbove
            ? bid < alert.threshold - distance
            : bid > alert.threshold + distance
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case phase
        case lastNotifiedAt
        case failedAttempts
        case retryAfter
        case requestedAt
    }

    /// The failure fields are optional on read: state saved before they
    /// existed has no failures to remember. `deliveryAbandoned` is not stored
    /// at all: it lasts one run.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(AlertPhase.self, forKey: .phase)
        lastNotifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastNotifiedAt)
        failedAttempts = try container.decodeIfPresent(Int.self, forKey: .failedAttempts) ?? 0
        retryAfter = try container.decodeIfPresent(Date.self, forKey: .retryAfter)
        requestedAt = try container.decodeIfPresent(Date.self, forKey: .requestedAt)
    }
}
