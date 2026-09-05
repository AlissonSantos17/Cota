import Foundation
import Testing

@testable import CotaKit

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

    /// `value` needs a single pair; ticking a second one has to walk the format
    /// back, or the bar shows two unlabelled numbers.
    @Test func tickingASecondPairWalksTheValueFormatBack() {
        let defaults = freshDefaults()
        defaults.set(
            encoded([
                PairSetting(pair: "EUR-BRL", showsInMenuBar: true),
                PairSetting(pair: "USD-BRL", showsInMenuBar: false),
            ]), forKey: "pairSettings")

        let store = SettingsStore(defaults: defaults)
        store.menuBarFormat = .value
        store.setMenuBarPair("USD-BRL", shown: true)

        #expect(store.menuBarFormat == .auto)
    }
}
