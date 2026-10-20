import AppKit
import CotaKit
import SwiftUI

struct PanelView: View {
    @ObservedObject var store: QuoteStore
    @ObservedObject var settings: SettingsStore

    @ObservedObject private var panelState = PanelState.shared
    /// The converter's amount and direction are shared by every row, so
    /// opening the next pair converts the same 100.
    @State private var convertAmount = "100"
    @State private var convertInverted = false
    @State private var copiedPairID: String?

    var body: some View {
        quotesPanel
            .frame(width: CotaTheme.Size.panelWidth)
            // The window follows the content's height: a row opening has to
            // grow the panel, not scroll or clip inside a fixed frame.
            .fixedSize(horizontal: false, vertical: true)
            .syncsWindowHeight()
            .background(CotaTheme.night)
            .overlay(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.panel)
                    .strokeBorder(CotaTheme.panelBorder, lineWidth: 1)
            )
            .foregroundStyle(CotaTheme.textPrimary)
            .environment(\.colorScheme, .dark)
            .background { shortcutButtons }
            // The language lives in the settings store; reading it here makes
            // the whole panel redraw when it changes.
            .id(settings.language)
    }

    /// Settings is a window of its own, not a second page of the popover.
    private func openSettings() {
        SettingsWindowController.show(settings: settings, store: store)
    }

    private var quotesPanel: some View {
        // Staleness is a function of elapsed time, so the panel re-evaluates on
        // a tick rather than only when the store publishes.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            VStack(spacing: 0) {
                header

                content(now: context.date)
                    .padding(.bottom, 6)

                Rectangle()
                    .fill(CotaTheme.hairline)
                    .frame(height: 1)

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
            // promising a load that is never coming (§2.5).
            if store.error != nil {
                failureState
            } else {
                skeleton
            }
        } else {
            quotes(degraded: isDegraded(now: now))
        }
    }

    /// Values are kept on screen when a refresh fails or goes stale — dimmed,
    /// never removed. Vanishing data is a worse answer than old data.
    private func isDegraded(now: Date) -> Bool {
        store.error != nil || store.isStale(at: now)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            Text(L10n.t("panel.title"))
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if activeAlertCount > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "bell")
                        .font(.system(size: 10))
                    Text("\(activeAlertCount)")
                        .font(.system(size: 11).monospacedDigit())
                }
                .foregroundStyle(CotaTheme.mint)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(CotaTheme.mintCounter, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.t("a11y.alertsActive", "\(activeAlertCount)"))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: CotaTheme.Size.panelHeader)
    }

    private var activeAlertCount: Int {
        settings.alerts.filter(\.isEnabled).count
    }

    // MARK: - Rows

    private func quotes(degraded: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(settings.pairs, id: \.self) { pair in
                if let quote = store.quotes.first(where: { $0.id == pair }) {
                    PanelRow(
                        quote: quote,
                        series: store.series(for: quote.id, period: settings.period),
                        change: store.change(for: quote.id, period: settings.period),
                        range: store.range(for: quote.id, period: settings.period),
                        alert: alert(for: pair),
                        isExpanded: panelState.expandedPairID == pair,
                        isDegraded: degraded,
                        isCopied: copiedPairID == pair,
                        period: $settings.period,
                        convertAmount: $convertAmount,
                        convertInverted: $convertInverted,
                        onToggle: { toggle(pair) },
                        onCopy: { copy(quote) },
                        onAlert: { toggleAlert(for: quote) }
                    )
                } else {
                    UnavailableRow(pair: pair)
                }
            }
        }
    }

    /// The alert the row reports and the button acts on: an enabled one first,
    /// so the chart draws the line that will actually fire.
    private func alert(for pair: String) -> PriceAlert? {
        settings.alerts.first { $0.pair == pair && $0.isEnabled }
            ?? settings.alerts.first { $0.pair == pair }
    }

    private func toggle(_ pair: String) {
        withAnimation(CotaTheme.Motion.expand) {
            panelState.expandedPairID = panelState.expandedPairID == pair ? nil : pair
        }
    }

    private func copy(_ quote: Quote) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(QuoteFormat.value(quote.bid), forType: .string)
        copiedPairID = quote.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if copiedPairID == quote.id {
                copiedPairID = nil
            }
        }
    }

    private func toggleAlert(for quote: Quote) {
        if let existing = alert(for: quote.id) {
            settings.removeAlert(id: existing.id)
        } else {
            settings.addAlert(
                PriceAlert(
                    pair: quote.id,
                    threshold: PriceAlert.suggestedThreshold(for: quote.bid),
                    isAbove: true
                )
            )
        }
    }

    private var shortcutButtons: some View {
        Group {
            Button(L10n.t("footer.refresh")) {
                Task { await store.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(L10n.t("footer.settings")) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button(L10n.t("footer.quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

extension PanelView {
    // MARK: - Footer

    private func footer(now: Date) -> some View {
        HStack(spacing: 14) {
            status(now: now)
                .frame(maxWidth: .infinity, alignment: .leading)

            FooterButton(icon: "arrow.clockwise", help: L10n.t("footer.refresh")) {
                Task { await store.refresh() }
            }
            .disabled(store.loading)

            FooterButton(icon: "gearshape", help: L10n.t("footer.settings")) {
                openSettings()
            }

            FooterButton(icon: "power", help: L10n.t("footer.quit")) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: CotaTheme.Size.footer)
    }

    /// Relative rather than absolute: the question a stale panel raises is
    /// "how old is this?", not "what day is it?".
    private func status(now: Date) -> some View {
        let degraded = isDegraded(now: now)

        return HStack(spacing: 6) {
            Circle()
                .fill(degraded ? CotaTheme.amber : CotaTheme.mint)
                .frame(width: 6, height: 6)

            Text(statusText(now: now))
                .font(.system(size: 11).monospacedDigit())
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(degraded ? CotaTheme.amber : CotaTheme.footerStatus)
        .help(statusHelp)
    }

    private func statusText(now: Date) -> String {
        guard let date = store.lastUpdate else {
            return store.error != nil ? L10n.t("status.couldNotUpdate") : ""
        }

        let stamp: String
        if store.error != nil {
            stamp = L10n.t("status.offline", Self.time(date))
        } else if store.isStale(at: now) {
            stamp = L10n.t("status.stale", Self.elapsed(from: date, to: now))
        } else if now.timeIntervalSince(date) < 60 {
            stamp = L10n.t("status.updatedNow")
        } else {
            stamp = L10n.t("status.updatedAgo", Self.elapsed(from: date, to: now))
        }

        guard !store.unavailablePairs.isEmpty else { return stamp }
        return "\(stamp) · \(unavailableStatus)"
    }

    private var unavailableStatus: String {
        store.unavailablePairs.count == 1
            ? L10n.t("status.unavailable.one")
            : L10n.t("status.unavailable.many", "\(store.unavailablePairs.count)")
    }

    private var statusHelp: String {
        if let error = store.error, !error.isEmpty { return error }
        guard !store.unavailablePairs.isEmpty else { return "" }
        let names = store.unavailablePairs.map { PairDisplay(id: $0).text }.joined(separator: ", ")
        return L10n.t("status.unavailableHelp", names)
    }

    /// Hand-rolled rather than a relative date style: the stock one rounds a
    /// fetch that just landed into "in 0 seconds".
    private static func elapsed(from date: Date, to now: Date) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(date)))

        switch seconds {
        case ..<3600:
            return "\(max(1, seconds / 60)) min"
        case ..<86_400:
            return "\(seconds / 3600) h"
        default:
            return "\(seconds / 86_400) d"
        }
    }

    private static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(time: .shortened).locale(L10n.language.locale))
    }

    // MARK: - Empty, failure and loading

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(L10n.t("panel.empty.title"))
                .font(.system(size: 13, weight: .medium))

            Text(L10n.t("panel.empty.body"))
                .font(.system(size: 11))
                .foregroundStyle(CotaTheme.textSecondary)

            PanelTextButton(title: L10n.t("panel.empty.action")) {
                openSettings()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    /// Only for a failure with nothing to fall back on. Once a fetch has
    /// landed, a later failure keeps the values on screen and dims them.
    private var failureState: some View {
        VStack(spacing: 8) {
            Text(L10n.t("panel.failure.title"))
                .font(.system(size: 13, weight: .medium))

            Text(L10n.t("panel.failure.body"))
                .font(.system(size: 11))
                .foregroundStyle(CotaTheme.textSecondary)

            PanelTextButton(title: L10n.t("panel.failure.retry")) {
                Task { await store.refresh() }
            }
            .disabled(store.loading)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var skeleton: some View {
        VStack(spacing: 0) {
            ForEach(settings.pairs, id: \.self) { _ in
                SkeletonRow()
            }
        }
    }
}

private struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(CotaTheme.graphite)
                .frame(width: CotaTheme.Size.avatar, height: CotaTheme.Size.avatar)

            VStack(alignment: .leading, spacing: 4) {
                bar(width: 64, height: 10)
                bar(width: 48, height: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                bar(width: 60, height: 10)
                bar(width: 40, height: 8)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: CotaTheme.Size.row)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("a11y.loading"))
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(CotaTheme.graphite)
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
                .font(.system(size: 13))
                .foregroundStyle(CotaTheme.textSecondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct PanelTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CotaTheme.mint)
                .padding(.horizontal, 12)
                .frame(height: CotaTheme.Size.actionButton)
                .background(
                    CotaTheme.mintSoft,
                    in: RoundedRectangle(cornerRadius: CotaTheme.Radius.button)
                )
        }
        .buttonStyle(.plain)
    }
}
