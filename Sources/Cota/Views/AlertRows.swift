import CotaKit
import SwiftUI

// MARK: - Alerts

/// Both the alert rows and the new alert form measure their columns here, so
/// the form reads as the next row of the list rather than a detached block.
private enum AlertColumns {
    static let pair: CGFloat = 84

    /// 72, not 52: the narrower column truncated "above" to "ab...". The width
    /// could shrink again if the condition became `>` and `<`, but then the
    /// existing alerts would have to use the symbol too, or the two rows stop
    /// lining up.
    static let condition: CGFloat = 72
}

struct AlertRow: View {
    let alert: PriceAlert
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Layout.columnSpacing) {
            PairLabel(alert.pair)
                .frame(width: AlertColumns.pair, alignment: .leading)

            Text(alert.isAbove ? "above" : "below")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: AlertColumns.condition, alignment: .leading)

            Text(formattedThreshold)
                .font(.system(size: 12).monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .trailing)

            Toggle("", isOn: Binding(get: { alert.isEnabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Layout.trailingSlotWidth, height: Layout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove alert \(alert.label)")
            .help("Remove alert")
        }
        .frame(height: Layout.rowHeight)
    }

    private var formattedThreshold: String {
        QuoteFormat.value(alert.threshold)
    }
}

struct AddAlertRow: View {
    let pairs: [String]
    let onAdd: (PriceAlert) -> Void

    @State private var selectedPair: String = ""
    @State private var thresholdText = ""
    @State private var isAbove = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            form

            // `350.000` is grouping and `5.123` is not obviously either. The
            // parse is a guess the person has to be able to see before the
            // alert is armed on it — the alert list shows the number only
            // after the fact.
            if let hint {
                Text(hint)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(parsedThreshold == nil ? .orange : .secondary)
                    .padding(.leading, AlertColumns.pair + AlertColumns.condition + 16)
            }
        }
    }

    private var hint: String? {
        guard !thresholdText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let parsed = parsedThreshold else { return "Not a number" }
        return "Reads as \(QuoteFormat.value(parsed))"
    }

    private var parsedThreshold: Decimal? {
        QuoteFormat.parseThreshold(thresholdText)
    }

    private var form: some View {
        HStack(spacing: Layout.columnSpacing) {
            Picker("", selection: $selectedPair) {
                Text("Pair").tag("")
                ForEach(pairs, id: \.self) { pair in
                    Text(PairDisplay(id: pair).text).tag(pair)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: AlertColumns.pair)

            Picker("", selection: $isAbove) {
                Text("above").tag(true)
                Text("below").tag(false)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: AlertColumns.condition)

            TextField("Value", text: $thresholdText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .controlSize(.small)
                .frame(maxWidth: .infinity)

            Button("Add") {
                guard let threshold = parsedThreshold else { return }
                onAdd(PriceAlert(pair: selectedPair, threshold: threshold, isAbove: isAbove))
                thresholdText = ""
            }
            .controlSize(.small)
            .disabled(!isFormValid)
        }
        .frame(height: Layout.rowHeight)
    }

    private var isFormValid: Bool {
        !selectedPair.isEmpty && parsedThreshold != nil
    }
}
