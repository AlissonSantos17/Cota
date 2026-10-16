import AppKit
import CotaKit
import SwiftUI
import UniformTypeIdentifiers

/// The Alerts tab: permission and recovery notices, the alert list with each
/// alert's pause, and the form for a new one.
struct AlertsSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject private var notifications = NotificationService.shared

    var body: some View {
        VStack(spacing: 0) {
            if notifications.authorizationDenied {
                Text(
                    """
                    Notifications are off. Alerts are saved but will not appear \
                    until you allow them in System Settings.
                    """
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.bottom, 8)
            }

            if let backup = settings.unreadableAlertsBackup {
                unreadableAlertsNotice(backup)
            }

            if !settings.alerts.isEmpty {
                ForEach(Array(settings.alerts.enumerated()), id: \.element.id) { index, alert in
                    AlertRow(
                        alert: alert,
                        pause: notifications.pauses[alert.id],
                        onToggle: { enabled in
                            var updated = alert
                            updated.isEnabled = enabled
                            settings.updateAlert(updated)
                        },
                        onRemove: { settings.removeAlert(id: alert.id) }
                    )
                    .padding(.horizontal, Layout.horizontalPadding)

                    if index < settings.alerts.count - 1 {
                        RowSeparator()
                    }
                }

                RowSeparator()
            }

            AddAlertRow(pairs: settings.pairs) { alert in
                settings.addAlert(alert)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 6)

            // Two facts the rules depend on and the form cannot show: which
            // price is compared, and that nothing is watched while the app
            // is closed — there is no server doing it instead.
            Text("Alerts compare the bid and are checked while Cota is running.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 8)
        }
    }

    /// Recovery without knowing a defaults key: the bytes are written to a
    /// file the person picks. The copy in the app stays where it is.
    private func unreadableAlertsNotice(_ backup: Data) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Some saved alerts could not be read. The original data was kept.")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Save Copy…") { Self.saveCopy(of: backup) }
                .controlSize(.small)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, 8)
    }

    private static func saveCopy(of backup: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Cota unreadable alerts.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? backup.write(to: url, options: .atomic)
    }
}
