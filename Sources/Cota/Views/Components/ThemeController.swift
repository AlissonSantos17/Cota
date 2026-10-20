import AppKit
import Combine
import CotaKit
import SwiftUI

/// Resolves the theme that is drawn — the person's choice, or the system's
/// appearance when "Follow macOS" is on — and publishes it.
///
/// Views observe `active` and key their tree on it (see `ThemeKey`), the
/// same way the language already redraws everything in place.
@MainActor
final class ThemeController: ObservableObject {
    static let shared = ThemeController()

    @Published private(set) var active: AppTheme = .cota

    private var cancellables = Set<AnyCancellable>()
    private var appearanceObservation: NSKeyValueObservation?
    @Published private var systemIsDark = true

    private init() {}

    /// Called once from `CotaApp.init`.
    func attach(to settings: SettingsStore) {
        cancellables.removeAll()
        // `shared`, not `NSApp`: this runs from `CotaApp.init`, which can come
        // before `NSApp` is set, and a nil there would leave "Follow macOS"
        // deaf to the system.
        let app = NSApplication.shared
        systemIsDark = Self.isDark(app.effectiveAppearance)

        // effectiveAppearance is KVO-observable on NSApplication.
        appearanceObservation = app.observe(\.effectiveAppearance) { [weak self] changed, _ in
            Task { @MainActor in self?.systemIsDark = Self.isDark(changed.effectiveAppearance) }
        }

        Publishers.CombineLatest3(settings.$theme, settings.$followsSystemAppearance, $systemIsDark)
            .map { AppTheme.resolve($0, followsSystem: $1, systemIsDark: $2) }
            .removeDuplicates()
            .sink { [weak self] theme in
                CotaTheme.palette = .of(theme)
                withAnimation(CotaTheme.Motion.theme) { self?.active = theme }
            }
            .store(in: &cancellables)
    }

    private static func isDark(_ appearance: NSAppearance?) -> Bool {
        appearance?.bestMatch(from: [.darkAqua, .aqua]) != .aqua
    }
}

/// What the panel and the Settings window key their tree on: changing either
/// redraws every label and colour in place.
struct ThemeKey: Hashable {
    let language: AppLanguage
    let theme: AppTheme
}
