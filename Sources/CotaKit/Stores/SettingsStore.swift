import Foundation
import SwiftUI
import ServiceManagement

@MainActor
public final class SettingsStore: ObservableObject {
    private enum Keys {
        static let pairs = "selectedPairs"
        static let refreshInterval = "refreshInterval"
        static let alerts = "priceAlerts"
    }

    private let defaults: UserDefaults

    @Published public var pairs: [String] {
        didSet { defaults.set(pairs, forKey: Keys.pairs) }
    }

    @Published public var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published public var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }

    @Published public var alerts: [PriceAlert] {
        didSet { persistAlerts() }
    }

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

        self.pairs = defaults.stringArray(forKey: Keys.pairs)
            ?? Self.defaultPairs

        let stored = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = stored > 0 ? stored : 300

        if let data = defaults.data(forKey: Keys.alerts),
           let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data) {
            self.alerts = decoded
        } else {
            self.alerts = []
        }

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    public func addPair(_ pair: String) {
        guard !pairs.contains(pair) else { return }
        pairs.append(pair)
    }

    public func removePair(_ pair: String) {
        pairs.removeAll { $0 == pair }
    }

    public func addAlert(_ alert: PriceAlert) {
        alerts.append(alert)
    }

    public func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
    }

    private func persistAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            defaults.set(data, forKey: Keys.alerts)
        }
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
