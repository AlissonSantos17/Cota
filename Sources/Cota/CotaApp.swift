import CotaKit
import SwiftUI

@main
struct CotaApp: App {
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
                .task {
                    NotificationService.shared.requestPermission()
                }
        } label: {
            MenuBarLabelView(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
