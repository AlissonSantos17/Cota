import SwiftUI

@main
struct CotaApp: App {
    @StateObject private var store = CotacaoStore()

    var body: some Scene {
        MenuBarExtra {
            PainelView(store: store)
        } label: {
            Text(store.resumoBarra)
        }
        .menuBarExtraStyle(.window)
        .task {
            store.iniciar()
        }
    }
}
