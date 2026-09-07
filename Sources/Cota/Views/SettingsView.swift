import CotaKit
import SwiftUI

/// The contents of the Settings window.
///
/// Four tabs rather than one column: the panel version had grown to seven
/// headers of identical weight and needed scrolling inside a popover, which on
/// macOS is the sign that the content has outgrown the surface. Each tab has to
/// fit without scrolling — one that stops fitting is asking to be split.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    @ObservedObject private var notifications = NotificationService.shared

    /// Wide enough for the five columns of the pairs list. The popover's 360
    /// was the constraint that flattened the hierarchy in the first place.
    private static let width: CGFloat = 460

    var body: some View {
        TabView {
            tab {
                section {
                    SectionHeader(title: "Refresh interval")

                    intervalContent
                }

                SectionSeparator()

                section {
                    generalContent
                }
            }
            .tabItem { Text("General") }

            tab {
                section {
                    pairsList
                }
            }
            .tabItem { Text("Pairs") }

            tab {
                MenuBarSettingsSection(settings: settings, store: store)
            }
            .tabItem { Text("Menu bar") }

            tab {
                section {
                    alertsContent
                }
            }
            .tabItem { Text("Alerts") }
        }
        .padding(Layout.sectionSpacing)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Every tab is topped out and left to size itself vertically, so the
    /// window measures the tallest one and short tabs do not stretch.
    @ViewBuilder
    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, Layout.sectionSpacing)
    }

    // MARK: - Currency pairs

    @State private var dropTarget: String?

    private var pairsList: some View {
        VStack(spacing: 0) {
            pairsHeader

            ForEach(Array(settings.pairs.enumerated()), id: \.element) { index, pair in
                PairRow(
                    pair: pair,
                    quote: store.quotes.first { $0.id == pair },
                    canRemove: settings.pairs.count > 1,
                    isShownInMenuBar: settings.isShownInMenuBar(pair),
                    onToggleMenuBar: { settings.setMenuBarPair(pair, shown: $0) },
                    isDropTarget: dropTarget == pair,
                    onMoveUp: index > 0 ? { settings.swapPairs(index, index - 1) } : nil,
                    onMoveDown: index < settings.pairs.count - 1
                        ? { settings.swapPairs(index, index + 1) } : nil,
                    onRemove: { settings.removePair(pair) }
                )
                .padding(.horizontal, Layout.horizontalPadding)
                .contentShape(Rectangle())
                .draggable(PairPayload(pair: pair)) {
                    PairLabel(pair)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .dropDestination(for: PairPayload.self) { items, _ in
                    dropTarget = nil
                    guard let dropped = items.first?.pair,
                        let from = settings.pairs.firstIndex(of: dropped),
                        let to = settings.pairs.firstIndex(of: pair),
                        from != to
                    else {
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
                        Button("Remove \(PairDisplay(id: pair).text)", role: .destructive) {
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

    /// Mandatory here, and only here: with five columns a bare checkbox in the
    /// middle of a list of quotes does not explain itself. On a two or three
    /// column list the same header would be noise.
    private var pairsHeader: some View {
        ListRow(height: 22) {
            EmptyView()
        } center: {
            HStack(spacing: Layout.columnSpacing) {
                Text("Pair")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Rate")
                    .frame(width: PairColumns.rate, alignment: .trailing)
                Text("Change")
                    .frame(width: PairColumns.change, alignment: .trailing)
                Text("Menu bar")
                    .frame(width: PairColumns.menuBar, alignment: .center)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    private var hasAvailablePairs: Bool {
        !SettingsStore.availablePairs.filter { !settings.pairs.contains($0) }.isEmpty
    }

    private var addPairRow: some View {
        let available = SettingsStore.availablePairs.filter { !settings.pairs.contains($0) }

        return Menu {
            ForEach(available, id: \.self) { pair in
                Button(PairDisplay(id: pair).text) { settings.addPair(pair) }
            }
        } label: {
            ListRow {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } center: {
                Text("Add pair")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Refresh interval

    private let intervalOptions: [(label: String, value: Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("5m", 300), ("10m", 600),
    ]

    private var intervalContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            SegmentedControl(
                segments: intervalOptions.map { .init($0.label, $0.value) },
                selection: $settings.refreshInterval
            )
            .accessibilityLabel("Refresh interval")

            Text("Values are cached between refreshes.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Price alerts

    private var alertsContent: some View {
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
            Toggle(
                "",
                isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        // The login item can be revoked in System Settings while the app runs,
        // so the switch re-reads it on every open rather than trusting the
        // value it was built with.
        .task { settings.loadLaunchAtLogin() }
    }
}

// MARK: - Rows

/// The header and every row measure their columns here, so the checkbox lands
/// under its own label instead of wherever the rate above happened to end.
private enum PairColumns {
    static let rate: CGFloat = 96
    static let change: CGFloat = 64
    /// Wide enough for its own header: "Menu bar" at 11pt needs more than the
    /// checkbox does, and the label is what makes the column legible.
    static let menuBar: CGFloat = 60
}

private struct PairRow: View {
    let pair: String
    let quote: Quote?
    let canRemove: Bool
    let isShownInMenuBar: Bool
    let onToggleMenuBar: (Bool) -> Void
    let isDropTarget: Bool
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        ListRow {
            ReorderControl(hovering: hovering, onMoveUp: onMoveUp, onMoveDown: onMoveDown)
                .accessibilityLabel("Reorder \(PairDisplay(id: pair).text)")
        } center: {
            HStack(spacing: Layout.columnSpacing) {
                PairLabel(pair)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedBid)
                    .font(.system(size: 12, weight: .regular, design: .default).monospacedDigit())
                    .foregroundStyle(
                        quote == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
                    )
                    .frame(width: PairColumns.rate, alignment: .trailing)
                    .help(missingQuoteHelp ?? "")

                Text(formattedChange)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(changeColor)
                    .frame(width: PairColumns.change, alignment: .trailing)

                // The one source of truth about what the menu bar shows. The
                // Menu bar tab only reacts to this column.
                Toggle("", isOn: Binding(get: { isShownInMenuBar }, set: onToggleMenuBar))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .frame(width: PairColumns.menuBar, alignment: .center)
                    .accessibilityLabel("Show \(PairDisplay(id: pair).text) in the menu bar")
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
            .opacity(hovering && canRemove ? 1 : 0)
            .accessibilityLabel("Remove pair \(PairDisplay(id: pair).text)")
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
        return QuoteFormat.value(quote.bid)
    }

    private var missingQuoteHelp: String? {
        quote == nil ? "Not in the last API response" : nil
    }

    private var formattedChange: String {
        guard let quote else { return "—" }
        let value = quote.pctChange
        return "\(value < 0 ? "▼" : "▲") \(QuoteFormat.percentMagnitude(value))"
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
                            .foregroundStyle(
                                onMoveUp == nil
                                    ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
                            )
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
                            .foregroundStyle(
                                onMoveDown == nil
                                    ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
                            )
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
            HStack(spacing: 2) {
                dot
                dot
            }
            HStack(spacing: 2) {
                dot
                dot
            }
            HStack(spacing: 2) {
                dot
                dot
            }
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
