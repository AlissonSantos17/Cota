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

    /// Opens the window, or brings the existing one forward. One instance
    /// only: the gear is in the panel footer, which stays reachable while the
    /// window is open, and clicking it twice must not stack two windows.
    static func show(settings: SettingsStore, store: QuoteStore) {
        if let existing = shared {
            existing.activate()
            return
        }

        let controller = SettingsWindowController(settings: settings, store: store)
        shared = controller
        controller.activate()
    }

    private init(settings: SettingsStore, store: QuoteStore) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        // The window is sized by its content: each tab has to fit without
        // scrolling (§3.2), so a tab that outgrows the window is a signal to
        // split it rather than something to paper over with a scroller.
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settings, store: store)
        )
        window.setContentSize(window.contentView?.fittingSize ?? .zero)
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
