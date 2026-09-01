import Foundation
import SwiftUI
import ServiceManagement

@MainActor
public final class SettingsStore: ObservableObject {
    private enum Keys {
        static let pairs = "selectedPairs"
        static let refreshInterval = "refreshInterval"
        static let alerts = "priceAlerts"
        static let period = "quotePeriod"
        static let menuBarPairs = "menuBarPairs"
        static let menuBarFormat = "menuBarFormat"
        static let menuBarIndicator = "menuBarIndicator"
        static let dimWhenStale = "dimWhenStale"
    }

    private let defaults: UserDefaults

    @Published public var pairs: [String] {
        didSet {
            defaults.set(pairs, forKey: Keys.pairs)
            reconcileMenuBarPairs()
        }
    }

    @Published public var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published public var period: QuotePeriod {
        didSet { defaults.set(period.rawValue, forKey: Keys.period) }
    }

    /// Which pairs the menu bar labels. Explicit rather than "the first one",
    /// which was the implicit rule and left the user no way to change it.
    @Published public var menuBarPairs: [String] {
        didSet { defaults.set(menuBarPairs, forKey: Keys.menuBarPairs) }
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
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL"
    ]

    public static let availablePairs = [
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL",
        "ARS-BRL", "CAD-BRL", "AUD-BRL", "JPY-BRL",
        "CHF-BRL", "CNY-BRL", "ETH-BRL", "XRP-BRL"
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let resolvedPairs = defaults.stringArray(forKey: Keys.pairs) ?? Self.defaultPairs
        self.pairs = resolvedPairs
        let stored = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = stored > 0 ? stored : 300
        self.period = defaults.string(forKey: Keys.period)
            .flatMap(QuotePeriod.init(rawValue:)) ?? .day

        let storedMenuBarPairs = defaults.stringArray(forKey: Keys.menuBarPairs)
        self.menuBarPairs = storedMenuBarPairs ?? Array(resolvedPairs.prefix(1))
        self.menuBarFormat = defaults.string(forKey: Keys.menuBarFormat)
            .flatMap(MenuBarFormat.init(rawValue:)) ?? .auto
        self.menuBarIndicator = defaults.string(forKey: Keys.menuBarIndicator)
            .flatMap(ChangeIndicator.init(rawValue:)) ?? .arrow
        self.dimWhenStale = defaults.object(forKey: Keys.dimWhenStale) as? Bool ?? true

        if let data = defaults.data(forKey: Keys.alerts),
           let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data) {
            self.alerts = decoded
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
        pairs.append(pair)
    }

    public func removePair(_ pair: String) {
        pairs.removeAll { $0 == pair }
    }

    public func movePair(fromOffsets source: IndexSet, toOffset destination: Int) {
        pairs.move(fromOffsets: source, toOffset: destination)
    }

    public func movePair(from source: Int, to destination: Int) {
        guard source != destination,
              pairs.indices.contains(source),
              destination >= 0,
              destination <= pairs.count else {
            return
        }

        let item = pairs.remove(at: source)
        let target = destination > source ? destination - 1 : destination
        pairs.insert(item, at: min(target, pairs.count))
    }

    public func swapPairs(_ i: Int, _ j: Int) {
        guard i != j, pairs.indices.contains(i), pairs.indices.contains(j) else { return }
        pairs.swapAt(i, j)
    }

    // MARK: - Menu bar

    public func setMenuBarPair(_ pair: String, shown: Bool) {
        if shown {
            guard !menuBarPairs.contains(pair) else { return }
            menuBarPairs.append(pair)
        } else {
            menuBarPairs.removeAll { $0 == pair }
        }

        reconcileMenuBarFormat()
    }

    public func isShownInMenuBar(_ pair: String) -> Bool {
        menuBarPairs.contains(pair)
    }

    /// Menu bar pairs follow the order of the list in Settings, which is the
    /// order the user arranged by hand.
    public var orderedMenuBarPairs: [String] {
        pairs.filter(menuBarPairs.contains)
    }

    /// A pair dropped from the list cannot go on labelling the menu bar, and an
    /// empty selection would leave it blank with no way back inside itself.
    private func reconcileMenuBarPairs() {
        let surviving = menuBarPairs.filter(pairs.contains)
        let resolved = surviving.isEmpty ? Array(pairs.prefix(1)) : surviving

        if resolved != menuBarPairs {
            menuBarPairs = resolved
        }

        reconcileMenuBarFormat()
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
