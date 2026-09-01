import SwiftUI
import AppKit
import CotaKit

struct PanelView: View {
    @ObservedObject var store: QuoteStore
    @ObservedObject var settings: SettingsStore
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(settings: settings, store: store) {
                    showSettings = false
                }
            } else {
                quotesPanel
            }
        }
        .frame(width: 360)
        .animation(.easeInOut(duration: 0.15), value: showSettings)
        .background { shortcutButtons }
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
            skeleton
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
                showSettings = true
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
                Text("Updated \(date.formatted(.relative(presentation: .numeric).locale(Locale(identifier: "en_US"))))")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(degraded ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        .help(store.error ?? "")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No currency pairs")
                .font(.system(size: 13, weight: .medium))

            Text("Pick the pairs you want to follow.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button("Open settings") {
                showSettings = true
            }
            .controlSize(.small)
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
                showSettings.toggle()
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
                    Text("\(quote.code)/\(quote.codein)")
                        .font(.system(size: 13, weight: .medium))

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
        let formatted = abs(value).formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Locale(identifier: "pt_BR"))
        )
        return "\(arrow) \(formatted)%"
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

private enum QuoteFormat {
    private static let locale = Locale(identifier: "pt_BR")

    /// Large values (crypto) read better grouped and without decimals; FX
    /// pairs need the fourth decimal to show movement at all.
    static func value(_ value: Decimal) -> String {
        let fractionDigits = value >= 1000 ? 0 : 4
        return value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .locale(locale)
        )
    }

    /// Range bounds may abbreviate — the main value may not.
    static func rangeBound(_ value: Decimal) -> String {
        if value >= 1000 {
            let thousands = (value / 1000).formatted(
                .number
                    .precision(.fractionLength(0))
                    .locale(locale)
            )
            return "\(thousands)k"
        }

        return value.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(locale)
        )
    }
}
