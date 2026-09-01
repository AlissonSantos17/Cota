import SwiftUI
import CotaKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            SectionSeparator()

            section {
                SectionHeader(title: "Currency pairs")

                pairsList
            }

            SectionSeparator()

            section {
                SectionHeader(title: "Refresh interval")

                intervalContent
            }

            SectionSeparator()

            section {
                SectionHeader(title: "Price alerts")

                alertsContent
            }

            SectionSeparator()

            section {
                SectionHeader(title: "General")

                generalContent
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, Layout.sectionSpacing)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Layout.leadingSlotWidth, height: Layout.rowHeight, alignment: .center)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Back to quotes")

            Text("Settings")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            Color.clear
                .frame(width: Layout.leadingSlotWidth, height: Layout.rowHeight)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(height: 34)
    }

    // MARK: - Currency pairs

    @State private var dropTarget: String?

    private var pairsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(settings.pairs.enumerated()), id: \.element) { index, pair in
                PairRow(
                    pair: pair,
                    quote: store.quotes.first { $0.id == pair },
                    canRemove: settings.pairs.count > 1,
                    isDropTarget: dropTarget == pair,
                    onMoveUp: index > 0 ? { settings.swapPairs(index, index - 1) } : nil,
                    onMoveDown: index < settings.pairs.count - 1 ? { settings.swapPairs(index, index + 1) } : nil,
                    onRemove: { settings.removePair(pair) }
                )
                .padding(.horizontal, Layout.horizontalPadding)
                .contentShape(Rectangle())
                .draggable(pair) {
                    Text(pair)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .dropDestination(for: String.self) { items, _ in
                    dropTarget = nil
                    guard let dropped = items.first,
                          let from = settings.pairs.firstIndex(of: dropped),
                          let to = settings.pairs.firstIndex(of: pair),
                          from != to else {
                        return false
                    }
                    settings.movePair(from: from, to: to > from ? to + 1 : to)
                    return true
                } isTargeted: { targeted in
                    dropTarget = targeted ? pair : (dropTarget == pair ? nil : dropTarget)
                }
                .contextMenu {
                    if index > 0 {
                        Button("Move up") { settings.swapPairs(index, index - 1) }
                    }
                    if index < settings.pairs.count - 1 {
                        Button("Move down") { settings.swapPairs(index, index + 1) }
                    }
                    if settings.pairs.count > 1 {
                        Divider()
                        Button("Remove \(pair)", role: .destructive) {
                            settings.removePair(pair)
                        }
                    }
                }

                if index < settings.pairs.count - 1 {
                    RowSeparator()
                }
            }

            if hasAvailablePairs {
                RowSeparator()
                Spacer().frame(height: 10)
                addPairRow
            }
        }
    }

    private var hasAvailablePairs: Bool {
        !SettingsStore.availablePairs.filter { !settings.pairs.contains($0) }.isEmpty
    }

    private var addPairRow: some View {
        let available = SettingsStore.availablePairs.filter { !settings.pairs.contains($0) }
        return Menu {
            ForEach(available, id: \.self) { pair in
                Button(pair) { settings.addPair(pair) }
            }
        } label: {
            Label {
                Text("Add pair")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .medium))
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: Layout.rowHeight)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Refresh interval

    private let intervalOptions: [(label: String, value: Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("5m", 300), ("10m", 600)
    ]

    private var intervalContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(intervalOptions, id: \.value) { option in
                    IntervalSegment(
                        label: option.label,
                        isSelected: settings.refreshInterval == option.value
                    ) {
                        settings.refreshInterval = option.value
                    }
                }
            }
            .padding(3)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
            )

            Text("Values are cached between refreshes.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Price alerts

    private var alertsContent: some View {
        VStack(spacing: 0) {
            if !settings.alerts.isEmpty {
                ForEach(Array(settings.alerts.enumerated()), id: \.element.id) { index, alert in
                    AlertRow(
                        alert: alert,
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
        }
    }

    // MARK: - General

    private var generalContent: some View {
        ListRow {
            EmptyView()
        } center: {
            Text("Launch at login")
                .font(.system(size: 12))
        } trailing: {
            Toggle("", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

// MARK: - Rows

private struct PairRow: View {
    let pair: String
    let quote: Quote?
    let canRemove: Bool
    let isDropTarget: Bool
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        ListRow {
            ReorderControl(hovering: hovering, onMoveUp: onMoveUp, onMoveDown: onMoveDown)
                .accessibilityLabel("Reorder \(pair)")
        } center: {
            HStack {
                Text(pair)
                    .font(.system(size: 12, weight: .medium))

                Spacer(minLength: 12)

                Text(formattedBid)
                    .font(.system(size: 12, weight: .regular, design: .default).monospacedDigit())
                    .foregroundStyle(quote == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

                Text(formattedChange)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(changeColor)
                    .frame(width: 52, alignment: .trailing)
            }
        } trailing: {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Layout.trailingSlotWidth, height: Layout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .opacity(canRemove ? 1 : 0.3)
            .accessibilityLabel("Remove pair \(pair)")
            .help("Remove pair")
        }
        .background(alignment: .top) {
            if isDropTarget {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }
        }
        .onHover { hovering = $0 }
    }

    private var formattedBid: String {
        guard let quote else { return "—" }
        return quote.bid.formatted(
            .number
                .precision(.fractionLength(4))
                .locale(Locale(identifier: "pt_BR"))
        )
    }

    private var formattedChange: String {
        guard let quote else { return "—" }
        let value = quote.pctChange
        let sign = value >= 0 ? "+" : ""
        let formatted = value.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Locale(identifier: "pt_BR"))
        )
        return "\(sign)\(formatted)%"
    }

    private var changeColor: Color {
        guard let quote else { return .secondary }
        return quote.pctChange >= 0 ? .green : .red
    }
}

private struct ReorderControl: View {
    let hovering: Bool
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        ZStack {
            if hovering {
                VStack(spacing: 1) {
                    Button {
                        onMoveUp?()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(onMoveUp == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                            .frame(width: Layout.leadingSlotWidth, height: 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onMoveUp == nil)
                    .help("Move up")

                    Button {
                        onMoveDown?()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(onMoveDown == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                            .frame(width: Layout.leadingSlotWidth, height: 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onMoveDown == nil)
                    .help("Move down")
                }
            } else {
                GripHandle()
            }
        }
        .frame(width: Layout.leadingSlotWidth, height: Layout.rowHeight)
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }
}

private struct GripHandle: View {
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) { dot; dot }
            HStack(spacing: 2) { dot; dot }
            HStack(spacing: 2) { dot; dot }
        }
        .frame(width: Layout.leadingSlotWidth, height: Layout.rowHeight)
        .contentShape(Rectangle())
    }

    private var dot: some View {
        Circle()
            .fill(Color.primary.opacity(0.35))
            .frame(width: 2.5, height: 2.5)
    }
}

// MARK: - Alerts

private enum AlertColumns {
    static let pair: CGFloat = 66
    static let condition: CGFloat = 54
    static let value: CGFloat = 78
}

private struct AlertRow: View {
    let alert: PriceAlert
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(alert.pair)
                .font(.system(size: 12, weight: .medium))
                .frame(width: AlertColumns.pair, alignment: .leading)

            Text(alert.isAbove ? "above" : "below")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: AlertColumns.condition, alignment: .leading)

            Text(formattedThreshold)
                .font(.system(size: 12).monospacedDigit())
                .frame(width: AlertColumns.value, alignment: .trailing)

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(get: { alert.isEnabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: Layout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove alert \(alert.label)")
            .help("Remove alert")
        }
        .frame(height: Layout.rowHeight)
    }

    private var formattedThreshold: String {
        alert.threshold.formatted(
            .number
                .precision(.fractionLength(4))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}

private struct AddAlertRow: View {
    let pairs: [String]
    let onAdd: (PriceAlert) -> Void

    @State private var selectedPair: String = ""
    @State private var thresholdText = ""
    @State private var isAbove = true

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedPair) {
                Text("Pair").tag("")
                ForEach(pairs, id: \.self) { pair in
                    Text(pair).tag(pair)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 76)

            Picker("", selection: $isAbove) {
                Text(">").tag(true)
                Text("<").tag(false)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 52)

            TextField("Value", text: $thresholdText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .controlSize(.small)
                .frame(width: 76)

            Spacer(minLength: 0)

            Button("Add") {
                guard let threshold = parseThreshold() else { return }
                onAdd(PriceAlert(pair: selectedPair, threshold: threshold, isAbove: isAbove))
                thresholdText = ""
            }
            .controlSize(.small)
            .disabled(!isFormValid)
        }
        .frame(height: Layout.rowHeight + 2)
    }

    private func parseThreshold() -> Decimal? {
        Decimal(string: thresholdText.replacingOccurrences(of: ",", with: "."))
    }

    private var isFormValid: Bool {
        !selectedPair.isEmpty && parseThreshold() != nil
    }
}

// MARK: - Interval segments

private struct IntervalSegment: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
