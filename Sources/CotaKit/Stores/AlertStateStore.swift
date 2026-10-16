import Foundation

/// Where the alerts' life-cycle state lives between launches. A protocol so
/// the service's rules can be tested against a store the test owns.
public protocol AlertStateStore {
    func load() -> [UUID: AlertState]
    func save(_ states: [UUID: AlertState])
}

public struct UserDefaultsAlertStateStore: AlertStateStore {
    private enum Keys {
        static let states = "alertStates"

        /// Read once, to migrate, then never again. Left in place like the
        /// settings' legacy keys: a rollback finds its state where it left it.
        enum Legacy {
            static let triggered = "triggeredAlerts"
            static let lastNotified = "alertLastNotified"
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [UUID: AlertState] {
        guard let data = defaults.data(forKey: Keys.states) else {
            return legacyStates()
        }

        // Unreadable state costs at most one repeated banner per alert, which
        // is better than refusing to launch the alerts at all.
        let stored = (try? JSONDecoder().decode([String: AlertState].self, from: data)) ?? [:]
        return stored.reduce(into: [:]) { result, entry in
            if let id = UUID(uuidString: entry.key) {
                result[id] = entry.value
            }
        }
    }

    public func save(_ states: [UUID: AlertState]) {
        let keyed = Dictionary(uniqueKeysWithValues: states.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(keyed) {
            defaults.set(data, forKey: Keys.states)
        }
    }

    /// The two keys from before the state machine: fired ids, and when each
    /// alert last notified. A fired id is `triggered`; one that only has a
    /// date had rearmed and is still inside, or past, its cooldown.
    private func legacyStates() -> [UUID: AlertState] {
        let triggered = Set(
            (defaults.stringArray(forKey: Keys.Legacy.triggered) ?? [])
                .compactMap(UUID.init(uuidString:))
        )
        let lastNotified =
            (defaults.dictionary(forKey: Keys.Legacy.lastNotified) as? [String: Date] ?? [:])
            .reduce(into: [UUID: Date]()) { result, entry in
                if let id = UUID(uuidString: entry.key) {
                    result[id] = entry.value
                }
            }

        var states: [UUID: AlertState] = [:]
        for (id, date) in lastNotified {
            states[id] = AlertState(phase: .rearmed, lastNotifiedAt: date)
        }
        for id in triggered {
            states[id] = AlertState(phase: .triggered, lastNotifiedAt: lastNotified[id])
        }
        return states
    }
}
