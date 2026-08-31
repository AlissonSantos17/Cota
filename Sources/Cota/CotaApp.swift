import SwiftUI
import CotaKit

@main
struct CotaApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var store: QuoteStore

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: QuoteStore(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, settings: settings)
                .task {
                    NotificationService.shared.requestPermission()
                    store.start()
                }
        } label: {
            Text(store.menuBarSummary)
        }
        .menuBarExtraStyle(.window)
    }
}
