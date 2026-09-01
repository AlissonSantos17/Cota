import AppKit
import CotaKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: QuoteStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        quotesPanel
            .frame(width: 360)
            .background { shortcutButtons }
    }

    /// Settings is a window of its own now, not a second page of the popover.
    /// The popover stays what it is: the quotes view.
    private func openSettings() {
        SettingsWindowController.show(settings: settings, store: store)
    }

    private var quotesPanel: some View {
        // Staleness is a function of elapsed time, so the panel re-evaluates on
        // a tick rather than only when the store publishes.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            VStack(spacing: 0) {
                header

                SectionSeparator()

                content(now: context.date)

                SectionSeparator()

                footer(now: context.date)
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if settings.pairs.isEmpty {
            emptyState
        } else if !store.hasLoaded {
            // The skeleton means "this is arriving". Once the first fetch has
            // failed it is not arriving, and animated placeholders would go on
            // promising a load that is never coming — the same lie as a stale
            // quote wearing a fresh face (§2.5).
            if store.error != nil {
                failureState
            } else {
                skeleton
            }
        } else {
            quotes
                .opacity(isDegraded(now: now) ? 0.5 : 1)
        }
    }

    /// Values are kept on screen when a refresh fails or goes stale — dimmed,
    /// never removed. Vanishing data is a worse answer than old data.
    private func isDegraded(now: Date) -> Bool {
        store.error != nil || store.isStale(at: now)
    }

    private var header: some View {
        HStack(spacing: Layout.columnSpacing) {
            Text("Quotes")
                .font(.system(size: 13, weight: .medium))

            if store.loading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }

            Spacer(minLength: Layout.columnSpacing)

            SegmentedControl(
                segments: QuotePeriod.allCases.map { .init($0.label, $0) },
                selection: $settings.period,
                height: 22
            )
            .frame(width: 108)
            .accessibilityLabel("Period")
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(height: 44)
    }

    private var quotes: some View {
        ForEach(Array(store.quotes.enumerated()), id: \.element.id) { index, quote in
            QuoteRow(
                quote: quote,
                symbol: store.symbol(quote.code),
                series: store.series(for: quote.id, period: settings.period),
                change: store.change(for: quote.id, period: settings.period),
                range: store.range(for: quote.id, period: settings.period)
            )

            if index < store.quotes.count - 1 {
                RowSeparator()
            }
        }
    }

    private func footer(now: Date) -> some View {
        HStack(spacing: 12) {
            status(now: now)
                .frame(maxWidth: .infinity, alignment: .leading)

            FooterButton(icon: "arrow.clockwise", help: "Refresh quotes") {
                Task { await store.refresh() }
            }
            .disabled(store.loading)

            FooterButton(icon: "gearshape", help: "Settings") {
                openSettings()
            }

            FooterButton(icon: "power", help: "Quit Cota") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(height: 38)
    }

    /// Relative rather than absolute: the question a stale panel raises is
    /// "how old is this?", not "what day is it?".
    private func status(now: Date) -> some View {
        let degraded = isDegraded(now: now)

        return HStack(spacing: 4) {
            if degraded {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
            }

            if store.error != nil {
                Text("Couldn't update")
            } else if let date = store.lastUpdate {
                Text("Updated \(Self.elapsed(from: date, to: now))")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(degraded ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        .help(store.error ?? "")
    }

    /// Hand-rolled rather than a relative date style: the stock one rounds a
    /// fetch that just landed into "in 0 seconds".
    private static func elapsed(from date: Date, to now: Date) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(date)))

        switch seconds {
        case ..<60:
            return "just now"
        case ..<3600:
            return "\(seconds / 60) min ago"
        case ..<86_400:
            return "\(seconds / 3600) h ago"
        default:
            return "\(seconds / 86_400) d ago"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No currency pairs")
                .font(.system(size: 13, weight: .medium))

            Text("Pick the pairs you want to follow.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button("Open settings") {
                openSettings()
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    /// Only for a failure with nothing to fall back on. Once a fetch has
    /// landed, a later failure keeps the values on screen and dims them — old
    /// data beats no data, and this state would be throwing it away.
    private var failureState: some View {
        VStack(spacing: 8) {
            Text("Couldn't load quotes")
                .font(.system(size: 13, weight: .medium))

            Text("Check your connection and try again.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button("Try again") {
                Task { await store.refresh() }
            }
            .controlSize(.small)
            .disabled(store.loading)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var skeleton: some View {
        ForEach(Array(settings.pairs.enumerated()), id: \.element) { index, _ in
            SkeletonRow()

            if index < settings.pairs.count - 1 {
                RowSeparator()
            }
        }
    }

    private var shortcutButtons: some View {
        Group {
            Button("Refresh") {
                Task { await store.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Settings") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

private struct SkeletonRow: View {
    var body: some View {
        ListRow(
            height: Layout.quoteRowHeight,
            leadingWidth: Layout.badgeSize,
            trailingWidth: Layout.valueColumnWidth
        ) {
            Circle()
                .fill(Color(nsColor: .quaternaryLabelColor))
                .frame(width: Layout.badgeSize, height: Layout.badgeSize)
        } center: {
            VStack(alignment: .leading, spacing: 4) {
                bar(width: 64, height: 10)
                bar(width: 48, height: 8)
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 4) {
                bar(width: 60, height: 10)
                bar(width: 40, height: 8)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .accessibilityLabel("Loading quote")
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(nsColor: .quaternaryLabelColor))
            .frame(width: width, height: height)
    }
}

private struct FooterButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 15, height: 15)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Quote row

private struct QuoteRow: View {
    let quote: Quote
    let symbol: String
    let series: [Decimal]
    let change: Decimal?
    let range: (low: Decimal, high: Decimal)?

    @State private var copied = false

    var body: some View {
        ListRow(
            height: Layout.quoteRowHeight,
            leadingWidth: Layout.badgeSize,
            trailingWidth: Layout.valueColumnWidth
        ) {
            CurrencyBadge(symbol: symbol)
        } center: {
            HStack(spacing: Layout.columnSpacing) {
                VStack(alignment: .leading, spacing: 2) {
                    PairLabel(base: quote.code, quote: quote.codein, size: 13)

                    Text(formattedRange)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Layout.columnSpacing)

                SparklineView(data: series, color: changeColor)
                    .frame(width: SparklineView.width, height: SparklineView.height)
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedValue)
                    .font(.system(size: 13).monospacedDigit())

                Text(formattedChange)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(changeColor)
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quote.code) to \(quote.codein)")
        .accessibilityValue("\(formattedValue), change \(formattedChange)")
        .accessibilityHint("Click to copy value")
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(formattedValue, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }
        .overlay(alignment: .topTrailing) {
            if copied {
                Text("Copied!")
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    .padding(.trailing, Layout.horizontalPadding)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    /// No currency prefix: the pair name already states it, and a prefix puts
    /// the digits at a different x on every row.
    private var formattedValue: String {
        QuoteFormat.value(quote.bid)
    }

    private var formattedRange: String {
        guard let range else { return "—" }
        return "\(QuoteFormat.rangeBound(range.low)) – \(QuoteFormat.rangeBound(range.high))"
    }

    /// Always carries an arrow: colour alone does not communicate direction to
    /// a colourblind reader.
    private var formattedChange: String {
        let value = change ?? quote.pctChange
        let arrow = value < 0 ? "▼" : "▲"
        return "\(arrow) \(QuoteFormat.percentMagnitude(value))"
    }

    private var changeColor: Color {
        (change ?? quote.pctChange) < 0 ? .red : .green
    }
}

private struct CurrencyBadge: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: Layout.badgeSize, height: Layout.badgeSize)
            .background(Color.accentColor.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}
