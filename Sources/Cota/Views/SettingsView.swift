import SwiftUI
import CotaKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            pairsSection

            Divider()

            intervalSection

            Divider()

            launchSection

            Divider()

            alertsSection
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Label("Quotes", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Back to quotes")
            .keyboardShortcut(.cancelAction)

            Text("Settings")
                .font(.headline)

            Spacer()
        }
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
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.pairs.count <= 1)
                    .opacity(settings.pairs.count <= 1 ? 0.35 : 1)
                    .accessibilityLabel("Remove pair \(pair)")
                    .help("Remove pair")
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
                    Label("Add Pair", systemImage: "plus")
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
        Toggle("Launch at Login", isOn: Binding(
            get: { settings.launchAtLogin },
            set: { settings.setLaunchAtLogin($0) }
        ))
        .font(.subheadline)
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price Alerts")
                .font(.subheadline)
                .bold()

            if settings.alerts.isEmpty {
                Text("No alerts yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(settings.alerts) { alert in
                        HStack {
                            Text(alert.label)
                                .font(.caption)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { alert.isEnabled },
                                set: { enabled in
                                    var updated = alert
                                    updated.isEnabled = enabled
                                    settings.updateAlert(updated)
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            Button {
                                settings.removeAlert(id: alert.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove alert \(alert.label)")
                            .help("Remove alert")
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("New alert")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                AddAlertRow(pairs: settings.pairs) { alert in
                    settings.addAlert(alert)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
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
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(selectedPair.isEmpty || Decimal(string: thresholdText) == nil)
            .accessibilityLabel("Add alert")
        }
        .font(.caption)
    }
}
