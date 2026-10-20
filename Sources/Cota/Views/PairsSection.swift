import CotaKit
import SwiftUI

/// Settings → Pairs: the list in panel order, each pair with its pin for the
/// menu bar, and the way into Add pair.
struct PairsSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    let onAdd: () -> Void

    @State private var dropTarget: String?

    var body: some View {
        SettingsHeader(title: L10n.t("settings.pairs"), subtitle: L10n.t("pairs.subtitle"))

        VStack(spacing: 0) {
            ForEach(Array(settings.pairs.enumerated()), id: \.element) { index, pair in
                PairRow(
                    pair: pair,
                    quote: store.quotes.first { $0.id == pair },
                    isPinned: settings.isShownInMenuBar(pair),
                    canRemove: settings.pairs.count > 1,
                    isDropTarget: dropTarget == pair,
                    onPin: {
                        settings.setMenuBarPair(pair, shown: !settings.isShownInMenuBar(pair))
                    },
                    onRemove: { settings.removePair(pair) }
                )
                .contentShape(Rectangle())
                .draggable(PairPayload(pair: pair)) {
                    Text(PairDisplay(id: pair).text)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            CotaTheme.sheet,
                            in: RoundedRectangle(cornerRadius: CotaTheme.Radius.chip))
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
                        Button(L10n.t("pairs.moveUp")) { settings.swapPairs(index, index - 1) }
                    }
                    if index < settings.pairs.count - 1 {
                        Button(L10n.t("pairs.moveDown")) { settings.swapPairs(index, index + 1) }
                    }
                    if settings.pairs.count > 1 {
                        Divider()
                        Button(L10n.t("pairs.removeHelp"), role: .destructive) {
                            settings.removePair(pair)
                        }
                    }
                }
            }

            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                    Text(L10n.t("pairs.add"))
                        .font(.system(size: 13))
                }
                .foregroundStyle(CotaTheme.mint)
                .frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PairRow: View {
    let pair: String
    let quote: Quote?
    let isPinned: Bool
    let canRemove: Bool
    let isDropTarget: Bool
    let onPin: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14))
                .foregroundStyle(CotaTheme.moss)
                .accessibilityHidden(true)

            CurrencyAvatar(pair: pair, size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(display.text)
                    .font(.system(size: 13, weight: .medium))
                Text(PairNames.description(of: pair))
                    .font(.system(size: 11))
                    .foregroundStyle(CotaTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(quote.map { QuoteFormat.money($0.bid, currency: display.quote) } ?? "—")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(quote == nil ? CotaTheme.textSecondary : CotaTheme.textPrimary)
                .lineLimit(1)
                .frame(width: 110, alignment: .trailing)
                .help(quote == nil ? L10n.t("panel.unavailable") : "")

            Text(formattedChange)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(
                    quote.map { CotaTheme.trend($0.pctChange) } ?? CotaTheme.textSecondary
                )
                .lineLimit(1)
                .frame(width: 70, alignment: .trailing)

            // The one source of truth about what the menu bar shows.
            IconButton(
                icon: "pin.fill",
                size: 14,
                color: isPinned ? CotaTheme.mint : CotaTheme.moss,
                width: 24,
                help: L10n.t("pairs.pinHelp"),
                action: onPin
            )
            .accessibilityAddTraits(isPinned ? [.isSelected] : [])

            IconButton(icon: "xmark", help: L10n.t("pairs.removeHelp"), action: onRemove)
                .disabled(!canRemove)
                .opacity(canRemove ? 1 : 0.3)
        }
        .frame(height: 46)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CotaTheme.rowDivider)
                .frame(height: 1)
        }
        .overlay(alignment: .top) {
            if isDropTarget {
                Rectangle()
                    .fill(CotaTheme.mint)
                    .frame(height: 2)
            }
        }
    }

    private var display: PairDisplay {
        PairDisplay(id: pair)
    }

    private var formattedChange: String {
        guard let quote else { return "—" }
        let value = quote.pctChange
        return "\(value < 0 ? "▼" : "▲") \(QuoteFormat.percentMagnitude(value))"
    }
}

/// Pair descriptions in running text: "Dólar americano em euro".
enum PairNames {
    static func description(of pair: String) -> String {
        let display = PairDisplay(id: pair)
        return L10n.t(
            "pairs.description",
            L10n.currencyName(display.base),
            inSentence(L10n.currencyName(display.quote))
        )
    }

    /// A currency name in the middle of a sentence. Portuguese lowercases
    /// every name; English keeps proper adjectives ("US dollar") and only
    /// lowers the common nouns.
    static func inSentence(_ name: String) -> String {
        if L10n.language.lproj == "pt-BR" {
            return name.lowercased(with: L10n.language.locale)
        }
        return ["Euro", "Ether", "Bitcoin"].contains(name) ? name.lowercased() : name
    }
}
