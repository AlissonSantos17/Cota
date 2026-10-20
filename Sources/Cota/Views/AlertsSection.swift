import AppKit
import CotaKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings → Alerts: permission and recovery notices, the sentence that
/// composes a new alert, and the alerts with their distance to the target.
struct AlertsSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    @ObservedObject private var notifications = NotificationService.shared

    var body: some View {
        SettingsHeader(title: L10n.t("settings.alerts"), subtitle: L10n.t("alerts.subtitle"))

        if notifications.authorizationDenied {
            SettingsNote(L10n.t("alerts.notificationsOff"), color: CotaTheme.amber)
        }

        if let backup = settings.unreadableAlertsBackup {
            unreadableAlertsNotice(backup)
        }

        AlertComposer(pairs: settings.pairs, quotes: store.quotes) { alert in
            settings.addAlert(alert)
        }

        VStack(spacing: 0) {
            ForEach(settings.alerts) { alert in
                AlertRow(
                    alert: alert,
                    quote: store.quotes.first { $0.id == alert.pair },
                    pause: notifications.pauses[alert.id],
                    onToggle: { enabled in
                        var updated = alert
                        updated.isEnabled = enabled
                        settings.updateAlert(updated)
                    },
                    onRemove: { settings.removeAlert(id: alert.id) }
                )
            }
        }
    }

    /// Recovery without knowing a defaults key: the bytes are written to a
    /// file the person picks. The copy in the app stays where it is.
    private func unreadableAlertsNotice(_ backup: Data) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            SettingsNote(L10n.t("alerts.unreadable"), color: CotaTheme.amber)

            Button(L10n.t("alerts.saveCopy")) { Self.saveCopy(of: backup) }
                .controlSize(.small)
        }
    }

    private static func saveCopy(of backup: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Cota unreadable alerts.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? backup.write(to: url, options: .atomic)
    }
}
