import Foundation
import Testing

@testable import CotaKit

/// Stands in for `SMAppService`, which needs a real bundle a test process does
/// not have. Kept here rather than on `LaunchAgent`: the app has no use for it.
final class StubLaunchAgent: @unchecked Sendable {
    var enabled: Bool
    let failing: Bool

    init(enabled: Bool, failing: Bool = false) {
        self.enabled = enabled
        self.failing = failing
    }

    struct RegistrationFailed: Error {}

    var agent: LaunchAgent {
        LaunchAgent(
            isEnabled: { [self] in enabled },
            setEnabled: { [self] wanted in
                if failing { throw RegistrationFailed() }
                enabled = wanted
            }
        )
    }
}

extension LaunchAgent {
    static func stub(enabled: Bool) -> LaunchAgent {
        StubLaunchAgent(enabled: enabled).agent
    }
}

@Suite @MainActor
struct SettingsStoreTests {
    /// A defaults domain of its own per test, so one test's pairs cannot leak
    /// into the next or into the real app's configuration.
    private func freshDefaults() -> UserDefaults {
        let name = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func encoded(_ settings: [PairSetting]) -> Data {
        try! JSONEncoder().encode(settings)
    }

    // MARK: - Launch at login

    /// The toggle used to read `false` on every open because nothing ever
    /// called `loadLaunchAtLogin()`. Someone with the app registered saw "off"
    /// while it did launch at login, and flipping the switch on was a no-op.
    @Test func launchAtLoginReflectsTheRegisteredState() {
        let store = SettingsStore(
            defaults: freshDefaults(),
            launchAgent: .stub(enabled: true)
        )

        #expect(store.launchAtLogin)
    }

    @Test func settingLaunchAtLoginGoesThroughTheAgent() {
        let agent = StubLaunchAgent(enabled: false)
        let store = SettingsStore(defaults: freshDefaults(), launchAgent: agent.agent)

        store.setLaunchAtLogin(true)

        #expect(agent.enabled)
        #expect(store.launchAtLogin)
    }

    /// A failed register leaves the switch showing what the system actually
    /// holds, not what the click asked for.
    @Test func aFailedRegisterFallsBackToTheSystemState() {
        let agent = StubLaunchAgent(enabled: false, failing: true)
        let store = SettingsStore(defaults: freshDefaults(), launchAgent: agent.agent)

        store.setLaunchAtLogin(true)

        #expect(store.launchAtLogin == false)
    }

    // MARK: - Migration

    @Test func migrationFoldsTheOldMenuBarListIntoTheFlag() {
        let defaults = freshDefaults()
        defaults.set(["EUR-BRL", "USD-BRL", "BTC-BRL"], forKey: "selectedPairs")
        defaults.set(["USD-BRL"], forKey: "menuBarPairs")

        let store = SettingsStore(defaults: defaults)

        #expect(store.pairs == ["EUR-BRL", "USD-BRL", "BTC-BRL"])
        #expect(store.orderedMenuBarPairs == ["USD-BRL"])
        #expect(store.isShownInMenuBar("EUR-BRL") == false)
    }

    /// The order the person arranged by hand survives: it drives both the panel
    /// and the menu bar.
    @Test func migrationKeepsTheOrderOfTheOldList() {
        let defaults = freshDefaults()
        defaults.set(["BTC-BRL", "EUR-BRL"], forKey: "selectedPairs")
        defaults.set(["EUR-BRL", "BTC-BRL"], forKey: "menuBarPairs")

        let store = SettingsStore(defaults: defaults)

        #expect(store.pairs == ["BTC-BRL", "EUR-BRL"])
        #expect(store.orderedMenuBarPairs == ["BTC-BRL", "EUR-BRL"])
    }

    /// A name left in the old menu bar list after its pair was removed simply
    /// has nowhere to land — the reconciling the old two-list model needed.
    @Test func migrationDropsMenuBarNamesWithNoPair() {
        let defaults = freshDefaults()
        defaults.set(["EUR-BRL"], forKey: "selectedPairs")
        defaults.set(["EUR-BRL", "GONE-BRL"], forKey: "menuBarPairs")

        let store = SettingsStore(defaults: defaults)

        #expect(store.pairs == ["EUR-BRL"])
        #expect(store.orderedMenuBarPairs == ["EUR-BRL"])
    }

    /// Absent rather than empty means "never configured", and the old build
    /// labelled the bar with the first pair in that case.
    @Test func migrationWithoutAMenuBarListTicksTheFirstPair() {
        let defaults = freshDefaults()
        defaults.set(["EUR-BRL", "USD-BRL"], forKey: "selectedPairs")

        let store = SettingsStore(defaults: defaults)

        #expect(store.orderedMenuBarPairs == ["EUR-BRL"])
    }

    /// An empty list is a choice the person made, not a missing value.
    @Test func migrationKeepsAnEmptyMenuBarSelectionEmpty() {
        let defaults = freshDefaults()
        defaults.set(["EUR-BRL"], forKey: "selectedPairs")
        defaults.set([String](), forKey: "menuBarPairs")

        let store = SettingsStore(defaults: defaults)

        #expect(store.orderedMenuBarPairs.isEmpty)
    }

    @Test func aFreshInstallLandsOnTheDefaults() {
        let store = SettingsStore(defaults: freshDefaults())

        #expect(store.pairs == SettingsStore.defaultPairs)
        #expect(store.orderedMenuBarPairs == [SettingsStore.defaultPairs[0]])
    }

    @Test func migrationRunsOnceAndThenIgnoresTheOldKeys() {
        let defaults = freshDefaults()
        defaults.set(["EUR-BRL", "USD-BRL"], forKey: "selectedPairs")
        defaults.set(["EUR-BRL"], forKey: "menuBarPairs")

        _ = SettingsStore(defaults: defaults)

        // An older build writing to the legacy keys must not undo what the new
        // model has since recorded.
        defaults.set(["JPY-BRL"], forKey: "selectedPairs")

        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened.pairs == ["EUR-BRL", "USD-BRL"])
    }

    /// The legacy keys stay behind, so an install that rolls back to the
    /// previous build still finds its configuration.
    @Test func migrationLeavesTheOldKeysInPlace() {
        let defaults = freshDefaults()
        defaults.set(["EUR-BRL"], forKey: "selectedPairs")

        _ = SettingsStore(defaults: defaults)

        #expect(defaults.stringArray(forKey: "selectedPairs") == ["EUR-BRL"])
    }

    // MARK: - The flag as a property of the pair

    @Test func removingAPairTakesItsFlagWithIt() {
        let defaults = freshDefaults()
        defaults.set(
            encoded([
                PairSetting(pair: "EUR-BRL", showsInMenuBar: true),
                PairSetting(pair: "USD-BRL", showsInMenuBar: true),
            ]), forKey: "pairSettings")

        let store = SettingsStore(defaults: defaults)
        store.removePair("EUR-BRL")

        #expect(store.orderedMenuBarPairs == ["USD-BRL"])

        // Re-adding it starts unticked rather than resurrecting the old flag.
        store.addPair("EUR-BRL")
        #expect(store.isShownInMenuBar("EUR-BRL") == false)
    }

    /// An alert whose pair is gone stayed listed, was skipped by checkAlerts,
    /// and the form picker no longer offered the pair — a visible alert that
    /// could never fire.
    @Test func removingAPairRemovesItsAlerts() {
        let defaults = freshDefaults()
        defaults.set(
            encoded([
                PairSetting(pair: "EUR-BRL", showsInMenuBar: true),
                PairSetting(pair: "USD-BRL", showsInMenuBar: false),
            ]), forKey: "pairSettings")

        let store = SettingsStore(defaults: defaults)
        store.addAlert(
            PriceAlert(pair: "EUR-BRL", threshold: Decimal(string: "6")!, isAbove: true))
        store.addAlert(
            PriceAlert(pair: "USD-BRL", threshold: Decimal(string: "5")!, isAbove: false))

        store.removePair("EUR-BRL")

        #expect(store.alerts.map(\.pair) == ["USD-BRL"])

        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened.alerts.map(\.pair) == ["USD-BRL"])
    }

    @Test func reorderingCarriesTheFlag() {
        let defaults = freshDefaults()
        defaults.set(
            encoded([
                PairSetting(pair: "EUR-BRL", showsInMenuBar: false),
                PairSetting(pair: "USD-BRL", showsInMenuBar: true),
            ]), forKey: "pairSettings")

        let store = SettingsStore(defaults: defaults)
        store.swapPairs(0, 1)

        #expect(store.pairs == ["USD-BRL", "EUR-BRL"])
        #expect(store.orderedMenuBarPairs == ["USD-BRL"])
    }

    @Test func tickingAPairPersists() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.setMenuBarPair(SettingsStore.defaultPairs[1], shown: true)

        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened.isShownInMenuBar(SettingsStore.defaultPairs[1]))
    }

    /// Coercion belongs at read time (`effectiveFormat`). Writing `.auto` back
    /// over the stored choice meant unticking the second pair could not
    /// restore "Value only".
    @Test func tickingASecondPairKeepsTheStoredValueFormat() {
        let defaults = freshDefaults()
        defaults.set(
            encoded([
                PairSetting(pair: "EUR-BRL", showsInMenuBar: true),
                PairSetting(pair: "USD-BRL", showsInMenuBar: false),
            ]), forKey: "pairSettings")

        let store = SettingsStore(defaults: defaults)
        store.menuBarFormat = .value
        store.setMenuBarPair("USD-BRL", shown: true)

        #expect(store.menuBarFormat == .value)
        #expect(
            MenuBarLabel.effectiveFormat(
                store.menuBarFormat, pairCount: store.orderedMenuBarPairs.count)
                == .auto)

        store.setMenuBarPair("USD-BRL", shown: false)
        #expect(store.menuBarFormat == .value)
        #expect(
            MenuBarLabel.effectiveFormat(
                store.menuBarFormat, pairCount: store.orderedMenuBarPairs.count)
                == .value)

        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened.menuBarFormat == .value)
    }
}
