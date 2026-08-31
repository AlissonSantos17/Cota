import SwiftUI
import UniformTypeIdentifiers
import CotaKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            SectionSeparator()

            ScrollView {
                VStack(spacing: 0) {
                    section {
                        SectionHeader(title: "Currency pairs")
                            .padding(.horizontal, SettingsLayout.horizontalPadding)
                            .padding(.bottom, SettingsLayout.headerToContentSpacing)

                        pairsList
                    }

                    SectionSeparator()

                    section {
                        SectionHeader(title: "Refresh interval")
                            .padding(.horizontal, SettingsLayout.horizontalPadding)
                            .padding(.bottom, SettingsLayout.headerToContentSpacing)

                        intervalContent
                    }

                    SectionSeparator()

                    section {
                        SectionHeader(title: "Price alerts")
                            .padding(.horizontal, SettingsLayout.horizontalPadding)
                            .padding(.bottom, SettingsLayout.headerToContentSpacing)

                        alertsContent
                    }

                    SectionSeparator()

                    section {
                        SectionHeader(title: "General")
                            .padding(.horizontal, SettingsLayout.horizontalPadding)
                            .padding(.bottom, SettingsLayout.headerToContentSpacing)

                        generalContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, SettingsLayout.sectionSpacing)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: SettingsLayout.leadingSlotWidth, height: SettingsLayout.rowHeight, alignment: .center)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Back to quotes")

            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            Color.clear
                .frame(width: SettingsLayout.leadingSlotWidth, height: SettingsLayout.rowHeight)
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .frame(height: 44)
    }

    // MARK: - Currency pairs

    @State private var draggingPair: String?

    private var pairsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(settings.pairs.enumerated()), id: \.element) { index, pair in
                PairRow(
                    pair: pair,
                    quote: store.quotes.first { $0.id == pair },
                    canRemove: settings.pairs.count > 1,
                    onRemove: { settings.removePair(pair) }
                )
                .padding(.horizontal, SettingsLayout.horizontalPadding)
                .contentShape(Rectangle())
                .onDrag {
                    draggingPair = pair
                    return NSItemProvider(object: pair as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: PairDropDelegate(
                        current: pair,
                        pairs: settings.pairs,
                        dragging: $draggingPair,
                        onMove: { from, to in
                            settings.movePair(from: from, to: to)
                        }
                    )
                )

                if index < settings.pairs.count - 1 {
                    RowSeparator()
                }
            }

            if hasAvailablePairs {
                RowSeparator()
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
            SettingsRow {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } center: {
                Text("Add pair")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            } trailing: {
                EmptyView()
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .padding(.horizontal, SettingsLayout.horizontalPadding)
    }

    // MARK: - Refresh interval

    private let intervalOptions: [(label: String, value: Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("5m", 300), ("10m", 600)
    ]

    private var intervalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(intervalOptions.enumerated()), id: \.element.value) { index, option in
                    IntervalSegment(
                        label: option.label,
                        isSelected: settings.refreshInterval == option.value,
                        isFirst: index == 0,
                        isLast: index == intervalOptions.count - 1
                    ) {
                        settings.refreshInterval = option.value
                    }
                }
            }
            .frame(height: 24)

            Text("Values are cached between refreshes.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
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
                    .padding(.horizontal, SettingsLayout.horizontalPadding)

                    if index < settings.alerts.count - 1 {
                        RowSeparator()
                    }
                }

                RowSeparator()
            }

            AddAlertRow(pairs: settings.pairs) { alert in
                settings.addAlert(alert)
            }
            .padding(.horizontal, SettingsLayout.horizontalPadding)
        }
    }

    // MARK: - General

    private var generalContent: some View {
        SettingsRow {
            EmptyView()
        } center: {
            Text("Launch at login")
                .font(.system(size: 13))
        } trailing: {
            Toggle("", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
    }
}

// MARK: - Rows

private struct PairRow: View {
    let pair: String
    let quote: Quote?
    let canRemove: Bool
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        SettingsRow {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        } center: {
            HStack {
                Text(pair)
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 12)

                Text(formattedBid)
                    .font(.system(size: 13, weight: .regular, design: .default).monospacedDigit())
                    .foregroundStyle(quote == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))

                Text(formattedChange)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(changeColor)
                    .frame(width: 56, alignment: .trailing)
            }
        } trailing: {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: SettingsLayout.trailingSlotWidth, height: SettingsLayout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .opacity(hovering && canRemove ? 1 : 0)
            .accessibilityLabel("Remove pair \(pair)")
            .help("Remove pair")
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

private struct PairDropDelegate: DropDelegate {
    let current: String
    let pairs: [String]
    @Binding var dragging: String?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging,
              dragging != current,
              let from = pairs.firstIndex(of: dragging),
              let to = pairs.firstIndex(of: current) else {
            return
        }
        let destination = to > from ? to + 1 : to
        onMove(from, destination)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Alerts

private enum AlertColumns {
    static let pair: CGFloat = 82
    static let condition: CGFloat = 72
    static let value: CGFloat = 72
    static let toggle: CGFloat = 40
}

private struct AlertRow: View {
    let alert: PriceAlert
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        SettingsRow {
            EmptyView()
        } center: {
            HStack(spacing: 8) {
                Text(alert.pair)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: AlertColumns.pair, alignment: .leading)

                Text(alert.isAbove ? "above" : "below")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: AlertColumns.condition, alignment: .leading)

                Text(formattedThreshold)
                    .font(.system(size: 13).monospacedDigit())
                    .frame(width: AlertColumns.value, alignment: .trailing)

                Toggle("", isOn: Binding(get: { alert.isEnabled }, set: onToggle))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .frame(width: AlertColumns.toggle, alignment: .center)
            }
        } trailing: {
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: SettingsLayout.trailingSlotWidth, height: SettingsLayout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel("Remove alert \(alert.label)")
            .help("Remove alert")
        }
        .onHover { hovering = $0 }
    }

    private var formattedThreshold: String {
        alert.threshold.formatted(
            .number
                .precision(.fractionLength(2))
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
        SettingsRow {
            EmptyView()
        } center: {
            HStack(spacing: 8) {
                Picker("", selection: $selectedPair) {
                    Text("Pair").tag("")
                    ForEach(pairs, id: \.self) { pair in
                        Text(pair).tag(pair)
                    }
                }
                .labelsHidden()
                .frame(width: AlertColumns.pair, alignment: .leading)

                Picker("", selection: $isAbove) {
                    Text(">").tag(true)
                    Text("<").tag(false)
                }
                .labelsHidden()
                .frame(width: AlertColumns.condition, alignment: .leading)

                TextField("Value", text: $thresholdText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: AlertColumns.value, alignment: .trailing)

                Button("Add") {
                    guard let threshold = Decimal(string: thresholdText.replacingOccurrences(of: ",", with: ".")) else {
                        return
                    }
                    onAdd(PriceAlert(pair: selectedPair, threshold: threshold, isAbove: isAbove))
                    thresholdText = ""
                }
                .controlSize(.small)
                .frame(width: AlertColumns.toggle, alignment: .center)
                .disabled(!isFormValid)
            }
        } trailing: {
            Color.clear
                .frame(width: SettingsLayout.trailingSlotWidth, height: SettingsLayout.rowHeight)
        }
    }

    private var isFormValid: Bool {
        !selectedPair.isEmpty
            && Decimal(string: thresholdText.replacingOccurrences(of: ",", with: ".")) != nil
    }
}

// MARK: - Interval segments

private struct IntervalSegment: View {
    let label: String
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedCorners(
                topLeft: isFirst ? 6 : 0,
                topRight: isLast ? 6 : 0,
                bottomLeft: isFirst ? 6 : 0,
                bottomRight: isLast ? 6 : 0
            )
            .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        )
        .overlay(alignment: .trailing) {
            if !isLast {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: SettingsLayout.hairline)
            }
        }
    }
}

private struct RoundedCorners: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tl = min(topLeft, min(rect.width, rect.height) / 2)
        let tr = min(topRight, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(bottomRight, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
            radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(
            center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
            radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
            radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(
            center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
            radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
