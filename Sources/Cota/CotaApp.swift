import AppKit
import CotaKit
import SwiftUI

/// Launch-time work that is not the business of any view.
///
/// Notification permission used to be asked for from the panel's `.task`, and
/// the panel is only built when someone clicks the status item. An alert could
/// come due — and be dropped — before the app had ever asked.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationService.shared.requestPermission()
    }
}

@main
struct CotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var settings: SettingsStore
    @StateObject private var store: QuoteStore

    init() {
        let settings = SettingsStore()
        let store = QuoteStore(settings: settings)
        store.start()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, settings: settings)
        } label: {
            MenuBarLabelView(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
