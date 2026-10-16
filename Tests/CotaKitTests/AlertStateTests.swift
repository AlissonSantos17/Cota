import Foundation
import Testing

@testable import CotaKit

/// The life cycle of one alert, with no notification centre and no clock of
/// its own: every rule here is about what an observed price means for that
/// alert, so it is tested by feeding prices in.
@Suite
struct AlertStateTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let rules = AlertRules.standard

    private func alert(_ threshold: String, above: Bool = true, enabled: Bool = true) -> PriceAlert
    {
        PriceAlert(
            pair: "USD-BRL",
            threshold: Decimal(string: threshold)!,
            isAbove: above,
            isEnabled: enabled
        )
    }

    /// Feeds one bid in and, when it comes due, completes the delivery the way
    /// the service does after the system accepts the request.
    @discardableResult
    private func observe(
        _ state: inout AlertState, _ bid: String, on alert: PriceAlert, at offset: TimeInterval = 0
    ) -> Bool {
        let now = start.addingTimeInterval(offset)
        let due = state.observe(bid: Decimal(string: bid)!, for: alert, rules: rules, now: now)
        if due {
            state.beginDelivery(at: now)
            state.deliverySucceeded(at: now)
        }
        return due
    }

    // MARK: - Hysteresis, as the review table lays it out

    /// Threshold 5,00 above: the rearm line is 5,00 − 0,3% = 4,985. Sitting on
    /// or just under the threshold is the same event; only clearing the line
    /// lets the alert fire again.
    @Test func anAboveAlertFollowsTheHysteresisTable() {
        let alert = alert("5.00")
        var state = AlertState()

        #expect(!observe(&state, "4.99", on: alert))
        #expect(state.phase == .armed)

        #expect(observe(&state, "5.01", on: alert))
        #expect(state.phase == .triggered)

        #expect(!observe(&state, "5.00", on: alert, at: 60))
        #expect(!observe(&state, "4.99", on: alert, at: 120))
        #expect(!observe(&state, "4.985", on: alert, at: 180))
        #expect(state.phase == .triggered)

        #expect(!observe(&state, "4.984", on: alert, at: 240))
        #expect(state.phase == .rearmed)

        #expect(observe(&state, "5.02", on: alert, at: 901))
        #expect(state.phase == .triggered)
    }

    /// The mirror image: below 5,00 rearms only above 5,015.
    @Test func aBelowAlertFollowsTheMirroredTable() {
        let alert = alert("5.00", above: false)
        var state = AlertState()

        #expect(!observe(&state, "5.01", on: alert))
        #expect(observe(&state, "4.99", on: alert))

        #expect(!observe(&state, "5.00", on: alert, at: 60))
        #expect(!observe(&state, "5.015", on: alert, at: 120))
        #expect(state.phase == .triggered)

        #expect(!observe(&state, "5.016", on: alert, at: 180))
        #expect(state.phase == .rearmed)

        #expect(observe(&state, "4.98", on: alert, at: 901))
    }

    /// The threshold itself counts as reached, in both directions.
    @Test func touchingTheThresholdCountsAsReached() {
        var above = AlertState()
        var below = AlertState()

        #expect(observe(&above, "5.00", on: alert("5.00")))
        #expect(observe(&below, "5.00", on: alert("5.00", above: false)))
    }

    /// The margin is a share of the threshold, so it scales with the price: a
    /// yen at R$ 0,032 rearms within a hundredth of a centavo, a bitcoin at
    /// R$ 400.000 only after R$ 1.200. A fixed amount would be either noise
    /// for one or a wall for the other.
    @Test func theMarginScalesWithThePrice() {
        let yen = alert("0.032")
        var yenState = AlertState()
        observe(&yenState, "0.0321", on: yen)
        observe(&yenState, "0.031905", on: yen, at: 60)
        #expect(yenState.phase == .triggered)
        observe(&yenState, "0.031903", on: yen, at: 120)
        #expect(yenState.phase == .rearmed)

        let bitcoin = alert("400000")
        var bitcoinState = AlertState()
        observe(&bitcoinState, "400500", on: bitcoin)
        observe(&bitcoinState, "398800", on: bitcoin, at: 60)
        #expect(bitcoinState.phase == .triggered)
        observe(&bitcoinState, "398799", on: bitcoin, at: 120)
        #expect(bitcoinState.phase == .rearmed)
    }

    // MARK: - Cooldown

    /// A recross inside fifteen minutes of the last banner waits, holding the
    /// condition, and goes out on the first quote past the floor.
    @Test func aRecrossInsideTheCooldownWaitsForTheFloor() {
        let alert = alert("5.00")
        var state = AlertState()

        observe(&state, "5.01", on: alert)
        observe(&state, "4.98", on: alert, at: 60)

        #expect(!observe(&state, "5.01", on: alert, at: 899))
        #expect(state.phase == .conditionMet)

        #expect(observe(&state, "5.01", on: alert, at: 900))
    }

    /// Condition met but held back by the cooldown, then the price falls back
    /// under the threshold: the crossing is over and nobody was told about it.
    /// Telling them later would describe a price that is no longer true.
    @Test func aHeldBackCrossingThatEndsIsDropped() {
        let alert = alert("5.00")
        var state = AlertState()

        observe(&state, "5.01", on: alert)
        observe(&state, "4.98", on: alert, at: 60)
        observe(&state, "5.01", on: alert, at: 120)
        #expect(state.phase == .conditionMet)

        observe(&state, "4.999", on: alert, at: 180)
        #expect(state.phase == .rearmed)
        #expect(!observe(&state, "4.999", on: alert, at: 1_000))
    }

    // MARK: - Creation

    /// Deliberate: an alert created with its condition already true says so on
    /// the first quote. Waiting for a crossing would leave someone who asked
    /// "tell me when USD is above 5" silent while it is above 5.
    @Test func aNewAlertWhoseConditionAlreadyHoldsIsDue() {
        var state = AlertState()
        #expect(observe(&state, "5.10", on: alert("5.00")))
    }

    // MARK: - Enabled, disabled

    @Test func aDisabledAlertIsNeverDue() {
        var state = AlertState()
        #expect(!observe(&state, "5.10", on: alert("5.00", enabled: false)))
        #expect(state.phase == .armed)
    }

    /// Disabling pauses the banner, not the watching. The price is still
    /// fetched for the pair, so a fall past the rearm line while the alert was
    /// off is a fact the app saw — re-enabling must not forget it, or the
    /// next crossing is swallowed.
    @Test func aRearmSeenWhileDisabledCountsOnceReEnabled() {
        let on = alert("5.00")
        var off = on
        off.isEnabled = false
        var state = AlertState()

        observe(&state, "5.01", on: on)
        observe(&state, "4.98", on: off, at: 60)
        #expect(state.phase == .rearmed)

        #expect(!observe(&state, "5.05", on: off, at: 1_000))
        #expect(observe(&state, "5.05", on: on, at: 1_060))
    }

    /// The other half of the same rule: with no rearm seen, re-enabling an
    /// alert that already fired for this crossing stays quiet.
    @Test func reEnablingWithoutARearmDoesNotRepeatTheBanner() {
        let on = alert("5.00")
        var off = on
        off.isEnabled = false
        var state = AlertState()

        observe(&state, "5.01", on: on)
        observe(&state, "5.02", on: off, at: 60)
        #expect(!observe(&state, "5.02", on: on, at: 2_000))
        #expect(state.phase == .triggered)
    }

    // MARK: - Delivery

    /// Asks for the banner and has the system refuse it, the way the service
    /// does when `add` throws.
    private func refuse(
        _ state: inout AlertState, _ failure: DeliveryFailure, on alert: PriceAlert,
        at offset: TimeInterval
    ) {
        let now = start.addingTimeInterval(offset)
        let due = state.observe(bid: Decimal(string: "5.01")!, for: alert, rules: rules, now: now)
        #expect(due)
        state.beginDelivery(at: now)
        state.deliveryFailed(failure, at: now, rules: rules)
    }

    /// A request the system refused did not reach anyone. The condition stays
    /// met and the cooldown, which measures time since the last banner, does
    /// not start.
    @Test func aFailedDeliveryKeepsTheCondition() {
        var state = AlertState()
        refuse(&state, .transient, on: alert("5.00"), at: 0)

        #expect(state.phase == .conditionMet)
        #expect(state.lastNotifiedAt == nil)
    }

    /// Transient refusals back off 1, 5 and 15 minutes. The retry is not a
    /// timer of its own: it happens on the first quote past the wait, so the
    /// fetch loop stays the only schedule in the app.
    @Test func transientFailuresBackOffProgressively() {
        let alert = alert("5.00")
        var state = AlertState()

        refuse(&state, .transient, on: alert, at: 0)
        #expect(!observe(&state, "5.01", on: alert, at: 59))
        refuse(&state, .transient, on: alert, at: 60)
        #expect(!observe(&state, "5.01", on: alert, at: 359))
        refuse(&state, .transient, on: alert, at: 360)
        #expect(!observe(&state, "5.01", on: alert, at: 1_259))
        #expect(observe(&state, "5.01", on: alert, at: 1_260))
    }

    /// Bounded in rate, not in count. A transient refusal is by definition
    /// one that can clear up, and the price can stay past the threshold for
    /// days: giving up after the last step left the alert silent for the
    /// whole of that time. Past the last step it keeps asking, at most once
    /// per longest wait.
    @Test func backoffStaysAtTheLongestStep() {
        let alert = alert("5.00")
        var state = AlertState()

        refuse(&state, .transient, on: alert, at: 0)
        refuse(&state, .transient, on: alert, at: 60)
        refuse(&state, .transient, on: alert, at: 360)
        refuse(&state, .transient, on: alert, at: 1_260)

        #expect(!state.deliveryAbandoned)
        #expect(!observe(&state, "5.01", on: alert, at: 2_159))
        refuse(&state, .transient, on: alert, at: 2_160)
        #expect(observe(&state, "5.01", on: alert, at: 3_060))
    }

    /// A request the system rejects as malformed fails the same way every
    /// time. Retrying it only repeats the error.
    @Test func aPermanentFailureIsNotRetried() {
        let alert = alert("5.00")
        var state = AlertState()

        refuse(&state, .permanent, on: alert, at: 0)

        #expect(state.deliveryAbandoned)
        #expect(!observe(&state, "5.01", on: alert, at: 100_000))
    }

    /// Giving up is for one crossing. When the price leaves the condition the
    /// failures are forgotten, and the next crossing is announced normally.
    @Test func theNextCrossingStartsWithACleanSlate() {
        let alert = alert("5.00")
        var state = AlertState()

        refuse(&state, .permanent, on: alert, at: 0)
        observe(&state, "4.99", on: alert, at: 60)
        #expect(state.phase == .armed)
        #expect(!state.deliveryAbandoned)

        #expect(observe(&state, "5.01", on: alert, at: 120))
    }

    /// Permission missing, or a request cut off by the app quitting, is not a
    /// failure of the request: it waits without spending a backoff step.
    @Test func aDeferredDeliveryCostsNoAttempt() {
        let alert = alert("5.00")
        var state = AlertState()

        _ = state.observe(bid: Decimal(string: "5.01")!, for: alert, rules: rules, now: start)
        state.beginDelivery(at: start)
        state.deliveryDeferred()

        #expect(state.phase == .conditionMet)
        #expect(state.failedAttempts == 0)
        #expect(observe(&state, "5.01", on: alert, at: 1))
    }

    /// While a request is in flight a second quote must not ask again: that is
    /// how one crossing became two banners.
    @Test func aRequestInFlightIsNotDueAgain() {
        let alert = alert("5.00")
        var state = AlertState()

        _ = state.observe(bid: Decimal(string: "5.01")!, for: alert, rules: rules, now: start)
        state.beginDelivery(at: start)

        let dueAgain = state.observe(
            bid: Decimal(string: "5.02")!, for: alert, rules: rules,
            now: start.addingTimeInterval(30))

        #expect(!dueAgain)
        #expect(state.phase == .requesting)
    }

    // MARK: - Persistence

    /// A request still in flight when the app quit is read back as in flight.
    /// Only the service can tell, by asking the notification centre, whether
    /// the banner went out before the app stopped.
    @Test func anInterruptedRequestIsReadBackAsInterrupted() throws {
        var state = AlertState()
        _ = state.observe(
            bid: Decimal(string: "5.01")!, for: alert("5.00"), rules: rules, now: start)
        state.beginDelivery(at: start)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AlertState.self, from: data)

        #expect(decoded.phase == .requesting)
    }

    /// A permanent refusal blocks the crossing for this run only. The same
    /// request failing differently needs a different build or system, and
    /// both mean a relaunch: one more attempt then is the way out of an
    /// otherwise stuck alert.
    @Test func aPermanentFailureIsRetriedOnceAfterARelaunch() throws {
        let alert = alert("5.00")
        var state = AlertState()
        refuse(&state, .permanent, on: alert, at: 0)

        let data = try JSONEncoder().encode(state)
        var relaunched = try JSONDecoder().decode(AlertState.self, from: data)

        #expect(!relaunched.deliveryAbandoned)
        #expect(observe(&relaunched, "5.01", on: alert, at: 60))
    }

    /// The backoff survives a relaunch: quitting is not a way to retry sooner.
    @Test func theBackoffIsPersisted() throws {
        var state = AlertState()
        refuse(&state, .transient, on: alert("5.00"), at: 0)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AlertState.self, from: data)

        #expect(decoded == state)
    }
}
