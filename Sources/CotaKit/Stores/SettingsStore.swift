import Foundation
import ServiceManagement
import SwiftUI

@MainActor
public final class SettingsStore: ObservableObject {
    private enum Keys {
        static let pairSettings = "pairSettings"
        static let refreshInterval = "refreshInterval"
        static let alerts = "priceAlerts"
        static let period = "quotePeriod"
        static let menuBarFormat = "menuBarFormat"
        static let menuBarIndicator = "menuBarIndicator"
        static let dimWhenStale = "dimWhenStale"

        /// Read once, to migrate, then never again. Left in place rather than
        /// deleted: an install that rolls back to the previous build finds its
        /// configuration where it left it.
        enum Legacy {
            static let pairs = "selectedPairs"
            static let menuBarPairs = "menuBarPairs"
        }
    }

    private let defaults: UserDefaults

    /// The pairs and their menu bar flags — the single source of truth for both.
    @Published public private(set) var pairSettings: [PairSetting] {
        didSet {
            guard pairSettings != oldValue else { return }
            persistPairSettings()
            pairs = pairSettings.map(\.pair)
            reconcileMenuBarFormat()
        }
    }

    /// A read-only mirror of the pair names, so everything that only cares
    /// about which pairs exist — the fetch loop above all — keeps observing one
    /// plain array and does not have to learn about the flag.
    @Published public private(set) var pairs: [String]

    @Published public var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published public var period: QuotePeriod {
        didSet { defaults.set(period.rawValue, forKey: Keys.period) }
    }

    @Published public var menuBarFormat: MenuBarFormat {
        didSet { defaults.set(menuBarFormat.rawValue, forKey: Keys.menuBarFormat) }
    }

    @Published public var menuBarIndicator: ChangeIndicator {
        didSet { defaults.set(menuBarIndicator.rawValue, forKey: Keys.menuBarIndicator) }
    }

    /// Governs the menu bar only. The panel always marks stale data, because
    /// there is room there to say why.
    @Published public var dimWhenStale: Bool {
        didSet { defaults.set(dimWhenStale, forKey: Keys.dimWhenStale) }
    }

    @Published public var launchAtLogin = false

    @Published public var alerts: [PriceAlert] = []

    public static let defaultPairs = [
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL",
    ]

    public static let availablePairs = [
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL",
        "ARS-BRL", "CAD-BRL", "AUD-BRL", "JPY-BRL",
        "CHF-BRL", "CNY-BRL", "ETH-BRL", "XRP-BRL",
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let resolvedPairs = Self.loadPairSettings(from: defaults)
        self.pairSettings = resolvedPairs
        self.pairs = resolvedPairs.map(\.pair)
        let stored = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = stored > 0 ? stored : 300
        self.period =
            defaults.string(forKey: Keys.period)
            .flatMap(QuotePeriod.init(rawValue:)) ?? .day

        self.menuBarFormat =
            defaults.string(forKey: Keys.menuBarFormat)
            .flatMap(MenuBarFormat.init(rawValue:)) ?? .auto
        self.menuBarIndicator =
            defaults.string(forKey: Keys.menuBarIndicator)
            .flatMap(ChangeIndicator.init(rawValue:)) ?? .arrow
        self.dimWhenStale = defaults.object(forKey: Keys.dimWhenStale) as? Bool ?? true

        if let data = defaults.data(forKey: Keys.alerts),
            let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data)
        {
            self.alerts = decoded
        }
    }

    // MARK: - Persistence and migration

    /// Reads the pair list, migrating the two older keys on first run.
    ///
    /// The flag used to live in `menuBarPairs`, a separate list of names. It is
    /// folded in here, once: order comes from the pair list the person
    /// arranged, and a pair is ticked if the old list named it. Nothing they
    /// configured is lost, and someone who never opened the app lands on the
    /// same defaults as before.
    private static func loadPairSettings(from defaults: UserDefaults) -> [PairSetting] {
        if let data = defaults.data(forKey: Keys.pairSettings),
            let decoded = try? JSONDecoder().decode([PairSetting].self, from: data)
        {
            return decoded
        }

        let pairs = defaults.stringArray(forKey: Keys.Legacy.pairs) ?? defaultPairs
        // Absent rather than empty means "never configured", and the old code
        // labelled the bar with the first pair in that case.
        let shown =
            defaults.stringArray(forKey: Keys.Legacy.menuBarPairs)
            ?? Array(pairs.prefix(1))

        let migrated = pairs.map {
            PairSetting(pair: $0, showsInMenuBar: shown.contains($0))
        }

        // Written straight away: a crash before the first edit must not send
        // the next launch back through the migration against keys that may by
        // then have been changed by an older build.
        if let data = try? JSONEncoder().encode(migrated) {
            defaults.set(data, forKey: Keys.pairSettings)
        }

        return migrated
    }

    private func persistPairSettings() {
        if let data = try? JSONEncoder().encode(pairSettings) {
            defaults.set(data, forKey: Keys.pairSettings)
        }
    }

    public func loadLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    public func addPair(_ pair: String) {
        guard !pairs.contains(pair) else { return }
        pairSettings.append(PairSetting(pair: pair, showsInMenuBar: false))
    }

    public func removePair(_ pair: String) {
        pairSettings.removeAll { $0.pair == pair }
    }

    public func movePair(fromOffsets source: IndexSet, toOffset destination: Int) {
        pairSettings.move(fromOffsets: source, toOffset: destination)
    }

    public func movePair(from source: Int, to destination: Int) {
        guard source != destination,
            pairSettings.indices.contains(source),
            destination >= 0,
            destination <= pairSettings.count
        else {
            return
        }

        let item = pairSettings.remove(at: source)
        let target = destination > source ? destination - 1 : destination
        pairSettings.insert(item, at: min(target, pairSettings.count))
    }

    public func swapPairs(_ i: Int, _ j: Int) {
        guard i != j,
            pairSettings.indices.contains(i),
            pairSettings.indices.contains(j)
        else {
            return
        }
        pairSettings.swapAt(i, j)
    }

    // MARK: - Menu bar

    public func setMenuBarPair(_ pair: String, shown: Bool) {
        guard let index = pairSettings.firstIndex(where: { $0.pair == pair }) else { return }
        pairSettings[index].showsInMenuBar = shown
    }

    public func isShownInMenuBar(_ pair: String) -> Bool {
        pairSettings.first { $0.pair == pair }?.showsInMenuBar ?? false
    }

    /// Menu bar pairs follow the order of the list in Settings, which is the
    /// order the user arranged by hand.
    ///
    /// Removing a pair now takes its flag with it, so there is nothing left to
    /// reconcile — which was the whole point of folding the two lists into one.
    public var orderedMenuBarPairs: [String] {
        pairSettings.filter(\.showsInMenuBar).map(\.pair)
    }

    private func reconcileMenuBarFormat() {
        let resolved = MenuBarLabel.effectiveFormat(
            menuBarFormat,
            pairCount: orderedMenuBarPairs.count
        )

        if resolved != menuBarFormat {
            menuBarFormat = resolved
        }
    }

    public func addAlert(_ alert: PriceAlert) {
        alerts.append(alert)
        persistAlerts()
    }

    public func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
        persistAlerts()
    }

    public func updateAlert(_ alert: PriceAlert) {
        alerts = alerts.map { $0.id == alert.id ? alert : $0 }
        persistAlerts()
    }

    private func persistAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            defaults.set(data, forKey: Keys.alerts)
        }
    }
}
