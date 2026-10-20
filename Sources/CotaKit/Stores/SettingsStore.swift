import Foundation
import SwiftUI

@MainActor
public final class SettingsStore: ObservableObject {
    private enum Keys {
        static let pairSettings = "pairSettings"
        static let refreshInterval = "refreshInterval"
        static let alerts = "priceAlerts"
        /// The alerts as they were stored when part of them could not be read.
        /// Written once, before anything can save over the original.
        static let unreadableAlerts = "priceAlerts.unreadable"
        static let period = "quotePeriod"
        static let menuBarFormat = "menuBarFormat"
        static let menuBarIndicator = "menuBarIndicator"
        static let dimWhenStale = "dimWhenStale"
        static let language = "appLanguage"

        /// Read once, to migrate, then never again. Left in place rather than
        /// deleted: an install that rolls back to the previous build finds its
        /// configuration where it left it.
        enum Legacy {
            static let pairs = "selectedPairs"
            static let menuBarPairs = "menuBarPairs"
        }
    }

    private let defaults: UserDefaults
    private let launchAgent: LaunchAgent
    private let drivesLocalization: Bool

    /// The pairs and their menu bar flags — the single source of truth for both.
    @Published public private(set) var pairSettings: [PairSetting] {
        didSet {
            guard pairSettings != oldValue else { return }
            persistPairSettings()
            pairs = pairSettings.map(\.pair)
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

    /// The language of every label, currency name and number. Changing it
    /// redraws in place: views observe the store, and `L10n` is pointed at the
    /// new strings before anything reads them.
    @Published public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            applyLanguage()
        }
    }

    @Published public var launchAtLogin = false

    @Published public var alerts: [PriceAlert] = []

    /// The stored alerts as they were when part of them could not be read,
    /// or nil when everything was readable. Offered back from Settings; never
    /// removed by the app.
    public var unreadableAlertsBackup: Data? {
        defaults.data(forKey: Keys.unreadableAlerts)
    }

    public static let defaultPairs = [
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL",
    ]

    public static var availablePairs: [String] {
        PairCatalog.pairs
    }

    /// `drivesLocalization` is for the app's own store only. `L10n.language`
    /// is process-wide, and tests that build stores in parallel must not move
    /// it under each other's feet.
    public init(
        defaults: UserDefaults = .standard,
        launchAgent: LaunchAgent = .system,
        drivesLocalization: Bool = false
    ) {
        self.defaults = defaults
        self.launchAgent = launchAgent
        self.drivesLocalization = drivesLocalization
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
        self.language =
            defaults.string(forKey: Keys.language)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system

        self.alerts = Self.loadAlerts(from: defaults)

        // Read here, not left to a caller: the switch is the only place the
        // login item is visible, and nothing was calling `loadLaunchAtLogin()`.
        self.launchAtLogin = launchAgent.isEnabled()

        applyLanguage()
    }

    private func applyLanguage() {
        guard drivesLocalization else { return }
        L10n.language = language
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

    /// Re-read on every open of Settings: the login item can be revoked in
    /// System Settings while the app is running.
    public func loadLaunchAtLogin() {
        launchAtLogin = launchAgent.isEnabled()
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAgent.setEnabled(enabled)
            launchAtLogin = enabled
        } catch {
            launchAtLogin = launchAgent.isEnabled()
        }
    }

    public func addPair(_ pair: String) {
        guard !pairs.contains(pair) else { return }
        pairSettings.append(PairSetting(pair: pair, showsInMenuBar: false))
    }

    public func removePair(_ pair: String) {
        pairSettings.removeAll { $0.pair == pair }
        let remaining = alerts.filter { $0.pair != pair }
        guard remaining.count != alerts.count else { return }
        alerts = remaining
        persistAlerts()
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

    /// Pairs with at least one alert switched on: the menu bar marks them
    /// with a dot.
    public var alertPairs: Set<String> {
        Set(alerts.filter(\.isEnabled).map(\.pair))
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

    /// Reads alert by alert. Decoding the array in one go failed it whole on a
    /// single bad record: the list came up empty, and the next change saved
    /// that empty list over every alert the person had. Whatever cannot be
    /// read is kept aside first, so it can still be recovered.
    private static func loadAlerts(from defaults: UserDefaults) -> [PriceAlert] {
        guard let data = defaults.data(forKey: Keys.alerts) else { return [] }

        let records = try? JSONDecoder().decode([LossyAlert].self, from: data)
        let alerts = records?.compactMap(\.alert) ?? []

        if alerts.count != records?.count, defaults.data(forKey: Keys.unreadableAlerts) == nil {
            defaults.set(data, forKey: Keys.unreadableAlerts)
        }

        return alerts
    }

    /// One element of the stored array, or nil when that element alone is
    /// unreadable.
    private struct LossyAlert: Decodable {
        let alert: PriceAlert?

        init(from decoder: Decoder) throws {
            alert = try? PriceAlert(from: decoder)
        }
    }

    private func persistAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            defaults.set(data, forKey: Keys.alerts)
        }
    }
}
