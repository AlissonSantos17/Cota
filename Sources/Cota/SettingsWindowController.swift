import AppKit
import CotaKit
import SwiftUI

/// The Settings window.
///
/// Not the SwiftUI `Settings` scene: `SettingsLink` is macOS 14 and this app
/// targets 13, and the older `showSettingsWindow:` selector is private and
/// unreliable. An accessory app also has to activate itself by hand before the
/// window can take focus — a menu bar app has no Dock icon to do it, so a
/// window opened without this appears behind whatever the person was using.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?

    private let navigation: SettingsNavigation

    /// Opens the window on a section, or brings the existing one forward and
    /// moves it there. One instance only: the gear is in the panel footer,
    /// which stays reachable while the window is open, and clicking it twice
    /// must not stack two windows.
    static func show(
        settings: SettingsStore,
        store: QuoteStore,
        section: SettingsSection = .general
    ) {
        if let existing = shared {
            existing.navigation.section = section
            existing.activate()
            return
        }

        let controller = SettingsWindowController(settings: settings, store: store)
        controller.navigation.section = section
        shared = controller
        controller.activate()
    }

    private init(settings: SettingsStore, store: QuoteStore) {
        let navigation = SettingsNavigation()
        self.navigation = navigation

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CotaTheme.Size.settingsWindow),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t("settings.title")
        // The sidebar runs up under the traffic lights, as in the design.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Dark only: a light variant has not been designed yet.
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(CotaTheme.window)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settings, store: store, navigation: navigation)
        )
        window.setContentSize(CotaTheme.Size.settingsWindow)
        window.center()
        window.setFrameAutosaveName("SettingsWindow")

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func activate() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Dropped on close so the next open rebuilds against current state, and so
    /// the app does not hold a window nobody is looking at.
    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }
}
