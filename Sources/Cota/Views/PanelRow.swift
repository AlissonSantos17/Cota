import AppKit
import CotaKit
import SwiftUI

/// A pair in the panel. Closed it is a name, a sparkline and the value; a
/// click opens it in place onto the large chart, the period, a converter and
/// two actions.
struct PanelRow: View {
    let quote: Quote
    let series: [Decimal]
    let change: Decimal?
    let range: (low: Decimal, high: Decimal)?
    let alert: PriceAlert?
    let isExpanded: Bool
    /// Stale or failed: values dim to half, nothing disappears.
    let isDegraded: Bool
    let isCopied: Bool
    @Binding var period: QuotePeriod
    @Binding var convertAmount: String
    @Binding var convertInverted: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    let onAlert: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            summary

            if isExpanded {
                detail
                    .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.row)
                .fill(isExpanded ? CotaTheme.expandedRow : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: CotaTheme.Radius.row))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    // MARK: - Closed

    private var summary: some View {
        HStack(spacing: 10) {
            CurrencyAvatar(pair: quote.id)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.currencyName(quote.code))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(PairDisplay(base: quote.code, quote: quote.codein).text)
                    .font(.system(size: 11))
                    .foregroundStyle(CotaTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SparklineView(data: series, color: trendColor)
                .opacity(isExpanded ? 0 : 1)

            VStack(alignment: .trailing, spacing: 1) {
                Text(QuoteFormat.money(quote.bid, currency: quote.codein))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .lineLimit(1)
                    .contentTransition(.numericText())

                Text(formattedChange)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(trendColor)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .frame(width: CotaTheme.Size.valueColumn, alignment: .trailing)
            .opacity(isDegraded ? 0.5 : 1)
            .animation(CotaTheme.Motion.digits, value: quote.bid)
        }
        .padding(.horizontal, 10)
        .frame(height: CotaTheme.Size.row)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PairDisplay(base: quote.code, quote: quote.codein).text)
        .accessibilityValue("\(QuoteFormat.value(quote.bid)), \(formattedChange)")
        .accessibilityAddTraits(.isButton)
    }

    private var changeValue: Decimal {
        change ?? quote.pctChange
    }

    /// Always carries an arrow: colour alone does not communicate direction to
    /// a colourblind reader.
    private var formattedChange: String {
        "\(changeValue < 0 ? "▼" : "▲") \(QuoteFormat.percentMagnitude(changeValue))"
    }

    private var trendColor: Color {
        CotaTheme.trend(changeValue)
    }

    // MARK: - Open

    private var detail: some View {
        VStack(spacing: 10) {
            PriceChartView(
                data: series,
                color: trendColor,
                fill: changeValue < 0 ? CotaTheme.downFill : CotaTheme.upFill,
                alert: alert?.isEnabled == true ? alert : nil
            )
            .opacity(isDegraded ? 0.5 : 1)

            HStack {
                SegmentedControl(
                    segments: QuotePeriod.allCases.map { .init($0.label, $0) },
                    selection: $period,
                    style: .panel
                )
                .accessibilityLabel(L10n.t("a11y.period"))

                Spacer(minLength: 8)

                rangeText
            }

            ConverterField(
                quote: quote,
                amount: $convertAmount,
                inverted: $convertInverted,
                isDegraded: isDegraded
            )

            HStack(spacing: 8) {
                ActionButton(
                    icon: isCopied ? "checkmark" : "doc.on.doc",
                    title: isCopied
                        ? L10n.t("panel.copied")
                        : L10n.t("panel.copy", QuoteFormat.value(quote.bid)),
                    style: .neutral,
                    action: onCopy
                )

                if alert != nil {
                    ActionButton(
                        icon: "bell.slash",
                        title: L10n.t("panel.removeAlert"),
                        style: .neutral,
                        action: onAlert
                    )
                } else {
                    ActionButton(
                        icon: "plus",
                        title: L10n.t("panel.newAlert"),
                        style: .accent,
                        action: onAlert
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private var rangeText: some View {
        let low = range.map { QuoteFormat.rangeBound($0.low) } ?? "—"
        let high = range.map { QuoteFormat.rangeBound($0.high) } ?? "—"

        return HStack(spacing: 12) {
            labelled(L10n.t("panel.low"), low)
            labelled(L10n.t("panel.high"), high)
        }
        .font(.system(size: 11).monospacedDigit())
        .opacity(isDegraded ? 0.5 : 1)
    }

    private func labelled(_ label: String, _ value: String) -> some View {
        (Text(label).foregroundColor(CotaTheme.textSecondary)
            + Text(" ")
            + Text(value).foregroundColor(CotaTheme.textControl))
            .lineLimit(1)
    }
}

/// Amount in, conversion out, with a swap between them. The amount and the
/// direction belong to the panel, not the row.
private struct ConverterField: View {
    let quote: Quote
    @Binding var amount: String
    @Binding var inverted: Bool
    let isDegraded: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $amount)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .accessibilityLabel(L10n.t("a11y.convertAmount"))

            Text(inputCode)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CotaTheme.mint)

            Button {
                inverted.toggle()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11))
                    .foregroundStyle(CotaTheme.mint)
                    .frame(width: 24, height: 24)
                    .background(CotaTheme.mintChip, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L10n.t("panel.convert.swap"))
            .accessibilityLabel(L10n.t("panel.convert.swap"))

            Text(result)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .tracking(-0.17)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .opacity(isDegraded ? 0.5 : 1)
                .contentTransition(.numericText())
                .animation(CotaTheme.Motion.digits, value: result)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: CotaTheme.Size.converter)
        .background(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.field)
                .fill(CotaTheme.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.field)
                .strokeBorder(CotaTheme.fieldBorder, lineWidth: 1)
        )
    }

    private var inputCode: String {
        inverted ? quote.codein : quote.code
    }

    private var outputCode: String {
        inverted ? quote.code : quote.codein
    }

    private var result: String {
        guard let value = QuoteFormat.parseThreshold(amount), quote.bid > 0 else { return "—" }
        let converted = inverted ? value / quote.bid : value * quote.bid
        return QuoteFormat.money(converted, currency: outputCode)
    }
}

private struct ActionButton: View {
    enum Style {
        case neutral
        case accent
    }

    let icon: String
    let title: String
    let style: Style
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: style == .accent ? .medium : .regular))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(style == .accent ? CotaTheme.mint : CotaTheme.textBody)
            .frame(maxWidth: .infinity)
            .frame(height: CotaTheme.Size.actionButton)
            .background(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.button)
                    .fill(fill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var fill: Color {
        switch style {
        case .accent: return CotaTheme.mintSoft
        case .neutral: return hovering ? CotaTheme.buttonFillHover : CotaTheme.buttonFill
        }
    }
}

/// A pair the last response left out. It keeps its place, with no value to
/// open onto.
struct UnavailableRow: View {
    let pair: String

    var body: some View {
        HStack(spacing: 10) {
            CurrencyAvatar(pair: pair)

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.currencyName(PairDisplay(id: pair).base))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(L10n.t("panel.unavailable"))
                    .font(.system(size: 11))
                    .foregroundStyle(CotaTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("—")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(CotaTheme.textSecondary)
                .frame(width: CotaTheme.Size.valueColumn, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: CotaTheme.Size.row)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PairDisplay(id: pair).text)
        .accessibilityValue(L10n.t("panel.unavailable"))
    }
}
