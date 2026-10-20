import CotaKit
import SwiftUI

// MARK: - Composer

/// A new alert written as a sentence: "Notify me when [EUR/BRL] [rises above]
/// [R$ 5.70]", with a live line under it saying how far the price is.
struct AlertComposer: View {
    let pairs: [String]
    let quotes: [Quote]
    let onAdd: (PriceAlert) -> Void

    @State private var selectedPair = ""
    @State private var isAbove = true
    @State private var thresholdText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(L10n.t("alerts.notifyWhen"))
                    .font(.system(size: 13))
                    .foregroundStyle(CotaTheme.textControl)

                ChipMenu(
                    options: pairs,
                    selection: $selectedPair,
                    glyph: { Currency.named(PairDisplay(id: $0).base).avatarGlyph },
                    label: { PairDisplay(id: $0).text }
                )

                ChipMenu(
                    options: [true, false],
                    selection: $isAbove,
                    glyph: { _ in nil },
                    label: { L10n.t($0 ? "alerts.rises" : "alerts.falls") }
                )

                valueField

                Spacer(minLength: 6)

                MintButton(title: L10n.t("alerts.create"), isEnabled: isValid, action: create)
            }

            Text(hint)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(CotaTheme.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.card).fill(CotaTheme.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.card)
                .strokeBorder(CotaTheme.fieldBorder, lineWidth: 1)
        )
        .onAppear(perform: pickPair)
        .onChange(of: pairs) { _ in pickPair() }
    }

    private var valueField: some View {
        HStack(spacing: 4) {
            // Never compressed: the field has a fixed width, and without this
            // the symbol was the one to give way, clipping "R$" to "R".
            Text(Currency.named(PairDisplay(id: pair).quote).moneySymbol)
                .foregroundStyle(CotaTheme.textSecondary)
                .fixedSize()
                .layoutPriority(1)

            TextField("", text: $thresholdText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .frame(width: 76)
                .onSubmit(create)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: CotaTheme.Radius.chip).fill(CotaTheme.chipFill))
        .overlay(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.chip)
                .strokeBorder(CotaTheme.mintFieldBorder, lineWidth: 1)
        )
    }

    /// The pair the sentence is about: the one picked, or the first in the
    /// list when the pick has since been removed.
    private var pair: String {
        pairs.contains(selectedPair) ? selectedPair : (pairs.first ?? "")
    }

    private func pickPair() {
        if !pairs.contains(selectedPair) {
            selectedPair = pairs.first ?? ""
        }
    }

    private var parsedThreshold: Decimal? {
        QuoteFormat.parseThreshold(thresholdText)
    }

    private var isValid: Bool {
        !pair.isEmpty && parsedThreshold != nil
    }

    private func create() {
        guard isValid, let threshold = parsedThreshold else { return }
        onAdd(PriceAlert(pair: pair, threshold: threshold, isAbove: isAbove))
        thresholdText = ""
    }

    /// `350.000` is grouping and `5.123` is not obviously either. The live line
    /// shows the price the number is being compared against, and an alert
    /// that would fire straight away says so before it is armed.
    private var hint: String {
        guard let threshold = parsedThreshold else { return L10n.t("alerts.enterValue") }
        guard let bid = quotes.first(where: { $0.id == pair })?.bid else {
            return L10n.t("alerts.hint.now", "—")
        }

        let alert = PriceAlert(pair: pair, threshold: threshold, isAbove: isAbove)
        let distance = abs(alert.distance(from: bid))
        var parts = [
            L10n.t(
                "alerts.hint.now", QuoteFormat.money(bid, currency: PairDisplay(id: pair).quote)),
            distance < Decimal(string: "0.005")!
                ? L10n.t("alerts.hint.onTarget")
                : L10n.t("alerts.hint.away", QuoteFormat.percentMagnitude(distance)),
        ]
        if alert.isPast(bid), distance >= Decimal(string: "0.005")! {
            parts.append(L10n.t("alerts.hint.firesNow"))
        }
        return parts.joined(separator: " · ")
    }
}

/// A chip that opens a short list: the pair and the direction in the
/// composer sentence.
private struct ChipMenu<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let glyph: (Value) -> String?
    let label: (Value) -> String

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack(spacing: 5) {
                if let glyph = glyph(selection) {
                    Text(glyph).foregroundStyle(CotaTheme.mint)
                }
                Text(label(selection))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(CotaTheme.textSecondary)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(CotaTheme.textPrimary)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.chip).fill(CotaTheme.chipFill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(options.isEmpty)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                        isOpen = false
                    } label: {
                        HStack(spacing: 6) {
                            if let glyph = glyph(option) {
                                Text(glyph)
                                    .foregroundStyle(CotaTheme.mint)
                                    .frame(width: 18)
                            }
                            Text(label(option))
                            Spacer(minLength: 12)
                            if option == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(CotaTheme.mint)
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(CotaTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .frame(minWidth: 140)
            .background(ThemeSurface(CotaTheme.sheet))
            .environment(\.colorScheme, CotaTheme.palette.colorScheme)
        }
    }
}

// MARK: - Rows

struct AlertRow: View {
    let alert: PriceAlert
    let quote: Quote?
    /// Set when the last evaluation left this alert out. Shown so an alert
    /// that stays quiet over a weekend reads as paused, not broken.
    let pause: AlertPause?
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CurrencyAvatar(pair: alert.pair)

            VStack(alignment: .leading, spacing: 6) {
                Text(alert.label)
                    .font(.system(size: 13).monospacedDigit())

                HStack(spacing: 8) {
                    progressBar

                    Text(note)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(isPaused ? CotaTheme.amber : CotaTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(get: { alert.isEnabled }, set: onToggle))
                .toggleStyle(MintToggleStyle())
                .accessibilityLabel(alert.label)

            IconButton(icon: "xmark", help: L10n.t("panel.removeAlert"), action: onRemove)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CotaTheme.rowDivider)
                .frame(height: 1)
        }
        .opacity(alert.isEnabled ? 1 : 0.55)
    }

    private var isPaused: Bool {
        alert.isEnabled && pause != nil
    }

    private var distance: Decimal? {
        quote.map { abs(alert.distance(from: $0.bid)) }
    }

    /// Fills as the price closes in: a quarter of the bar per percent away,
    /// never quite empty so the track still reads as a bar.
    private var progress: CGFloat {
        guard let distance else { return 0.06 }
        let percent = NSDecimalNumber(decimal: distance).doubleValue
        return CGFloat(max(6, 100 - percent * 25) / 100)
    }

    private var progressBar: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(CotaTheme.chipFill)
            .frame(width: 140, height: 3)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isPaused ? CotaTheme.amber : CotaTheme.mint)
                    .frame(width: 140 * progress, height: 3)
            }
    }

    private var note: String {
        if !alert.isEnabled { return L10n.t("alerts.row.off") }
        switch pause {
        case .staleQuote: return L10n.t("alerts.row.paused")
        case .untimedQuote: return L10n.t("alerts.row.pausedUntimed")
        case nil: break
        }
        guard let distance else { return "—" }
        return L10n.t("alerts.row.fromTarget", QuoteFormat.percentMagnitude(distance))
    }
}
