import Foundation
import Testing

@testable import CotaKit

@Suite @MainActor
struct AppThemeTests {
    private func freshDefaults() -> UserDefaults {
        let name = "AppThemeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Resolution

    @Test func withoutFollowTheChoiceIsDrawn() {
        for theme in AppTheme.allCases {
            #expect(AppTheme.resolve(theme, followsSystem: false, systemIsDark: false) == theme)
            #expect(AppTheme.resolve(theme, followsSystem: false, systemIsDark: true) == theme)
        }
    }

    @Test func followingLightModeAlwaysDrawsLight() {
        for theme in AppTheme.allCases {
            #expect(AppTheme.resolve(theme, followsSystem: true, systemIsDark: false) == .light)
        }
    }

    /// Someone on Cota or Liquid Glass keeps it when the Mac goes dark.
    @Test func followingDarkModeKeepsADarkChoice() {
        #expect(AppTheme.resolve(.cota, followsSystem: true, systemIsDark: true) == .cota)
        #expect(AppTheme.resolve(.dark, followsSystem: true, systemIsDark: true) == .dark)
        #expect(AppTheme.resolve(.glass, followsSystem: true, systemIsDark: true) == .glass)
        #expect(AppTheme.resolve(.light, followsSystem: true, systemIsDark: true) == .cota)
    }

    // MARK: - Persistence

    @Test func defaultsToCotaWithoutFollowing() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.theme == .cota)
        #expect(store.followsSystemAppearance == false)
    }

    @Test func themeSurvivesARelaunch() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.theme = .glass
        store.followsSystemAppearance = true

        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened.theme == .glass)
        #expect(reopened.followsSystemAppearance)
    }

    @Test func anUnknownStoredThemeFallsBackToCota() {
        let defaults = freshDefaults()
        defaults.set("neon", forKey: "appTheme")
        #expect(SettingsStore(defaults: defaults).theme == .cota)
    }

    @Test func everyThemeHasItsStrings() {
        for theme in AppTheme.allCases {
            for language in [AppLanguage.ptBR, .en] {
                #expect(L10n.t(theme.titleKey, in: language) != theme.titleKey)
                #expect(L10n.t(theme.noteKey, in: language) != theme.noteKey)
            }
        }
    }
}
