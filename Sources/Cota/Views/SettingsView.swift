import SwiftUI
import CotaKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            pairsSection

            Divider()

            intervalSection

            Divider()

            launchSection

            Divider()

            alertsSection

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var pairsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currency Pairs")
                .font(.subheadline)
                .bold()

            ForEach(settings.pairs, id: \.self) { pair in
                HStack {
                    Text(pair)
                        .font(.caption)
                    Spacer()
                    Button {
                        settings.removePair(pair)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.pairs.count <= 1)
                }
            }

            let available = SettingsStore.availablePairs
                .filter { !settings.pairs.contains($0) }

            if !available.isEmpty {
                Menu {
                    ForEach(available, id: \.self) { pair in
                        Button(pair) { settings.addPair(pair) }
                    }
                } label: {
                    Label("Add Pair", systemImage: "plus.circle")
                }
                .font(.caption)
            }
        }
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refresh Interval")
                .font(.subheadline)
                .bold()

            Picker("", selection: $settings.refreshInterval) {
                Text("30s").tag(30)
                Text("1m").tag(60)
                Text("2m").tag(120)
                Text("5m").tag(300)
                Text("10m").tag(600)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var launchSection: some View {
        Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            .font(.subheadline)
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Price Alerts")
                .font(.subheadline)
                .bold()

            ForEach(settings.alerts) { alert in
                HStack {
                    Text(alert.label)
                        .font(.caption)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { alert.isEnabled },
                        set: { enabled in
                            if var updated = settings.alerts.first(where: { $0.id == alert.id }) {
                                updated.isEnabled = enabled
                                settings.alerts = settings.alerts.map {
                                    $0.id == alert.id ? updated : $0
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    Button {
                        settings.removeAlert(id: alert.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            AddAlertRow(pairs: settings.pairs) { alert in
                settings.addAlert(alert)
            }
        }
    }
}

private struct AddAlertRow: View {
    let pairs: [String]
    let onAdd: (PriceAlert) -> Void

    @State private var selectedPair: String = ""
    @State private var thresholdText = ""
    @State private var isAbove = true

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: $selectedPair) {
                Text("Pair").tag("")
                ForEach(pairs, id: \.self) { pair in
                    Text(pair).tag(pair)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            Picker("", selection: $isAbove) {
                Text(">").tag(true)
                Text("<").tag(false)
            }
            .labelsHidden()
            .frame(width: 50)

            TextField("Value", text: $thresholdText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            Button {
                guard !selectedPair.isEmpty,
                      let threshold = Decimal(string: thresholdText) else { return }
                onAdd(PriceAlert(pair: selectedPair, threshold: threshold, isAbove: isAbove))
                thresholdText = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(selectedPair.isEmpty || Decimal(string: thresholdText) == nil)
        }
        .font(.caption)
    }
}
