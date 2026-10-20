import CotaKit
import SwiftUI

/// The Add pair sheet: search, suggestions, and two columns — From and To —
/// that only ever combine into a pair the catalog offers.
struct AddPairSheet: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    let onClose: () -> Void

    @State private var query = ""
    @State private var from = "USD"
    @State private var to = "EUR"

    private static let suggestions = [
        ("USD", "EUR"), ("GBP", "BRL"), ("BTC", "USD"),
        ("ARS", "BRL"), ("ETH", "BRL"), ("JPY", "BRL"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            top

            columns
                .overlay(alignment: .top) { divider }
                .overlay(alignment: .bottom) { divider }

            footer
        }
        .frame(width: CotaTheme.Size.sheetWidth)
        .background(CotaTheme.sheet)
        .clipShape(SheetShape())
        .overlay(SheetShape(open: true).stroke(CotaTheme.sheetBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 30)
        .onAppear(perform: pickDefaults)
        .onExitCommand(perform: onClose)
    }

    private var divider: some View {
        Rectangle()
            .fill(CotaTheme.hairline)
            .frame(height: 1)
    }

    // MARK: - Top

    private var top: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("addPair.title"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                IconButton(icon: "xmark", size: 14, help: L10n.t("addPair.cancel"), action: onClose)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(CotaTheme.textSecondary)

                TextField(L10n.t("addPair.search"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(CotaTheme.buttonFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(CotaTheme.cardBorder, lineWidth: 1)
            )

            if !suggestions.isEmpty {
                HStack(spacing: 6) {
                    Text(L10n.t("addPair.suggested"))
                        .font(.system(size: 11))
                        .foregroundStyle(CotaTheme.textSecondary)

                    ForEach(suggestions, id: \.self) { pair in
                        SuggestionChip(pair: pair) { choose(pair) }
                    }
                }
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var suggestions: [String] {
        Self.suggestions
            .map { "\($0.0)-\($0.1)" }
            .filter { PairCatalog.contains($0) && !settings.pairs.contains($0) }
            .prefix(4)
            .map { $0 }
    }

    private func choose(_ pair: String) {
        let display = PairDisplay(id: pair)
        from = display.base
        to = display.quote
    }

    // MARK: - Columns

    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            CurrencyColumn(
                title: L10n.t("addPair.from"),
                codes: matching,
                selection: from,
                isEnabled: { _ in true },
                onSelect: selectFrom
            )

            // Takes no height of its own: a column of spacers here grew without
            // bound and stretched the sheet down to the bottom of the window.
            Color.clear
                .frame(width: 36, height: 0)

            CurrencyColumn(
                title: L10n.t("addPair.to"),
                codes: matching,
                selection: to,
                isEnabled: { PairCatalog.destinations(from: from).contains($0) },
                onSelect: { to = $0 }
            )
        }
        .overlay { swapButton }
    }

    /// Centred between the two lists. The columns are equal, so the middle
    /// of the row is the middle of the gap.
    private var swapButton: some View {
        Button(action: swap) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12))
                .foregroundStyle(CotaTheme.mint)
                .frame(width: 26, height: 26)
                .background(CotaTheme.mintChip, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSwap)
        .opacity(canSwap ? 1 : 0.3)
        .help(L10n.t("addPair.swap"))
        .accessibilityLabel(L10n.t("addPair.swap"))
    }

    /// Codes whose code or name, in either language, contains the query.
    private var matching: [String] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return PairCatalog.currencies }

        return PairCatalog.currencies.filter { code in
            [code, L10n.t("currency.\(code)", in: .ptBR), L10n.t("currency.\(code)", in: .en)]
                .contains {
                    $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }
        }
    }

    private func selectFrom(_ code: String) {
        from = code
        let destinations = PairCatalog.destinations(from: code)
        if !destinations.contains(to), let first = destinations.first {
            to = first
        }
    }

    private var canSwap: Bool {
        PairCatalog.contains("\(to)-\(from)")
    }

    private func swap() {
        guard canSwap else { return }
        (from, to) = (to, from)
    }

    /// Starts on a pair not yet in the list, so Add is live straight away.
    private func pickDefaults() {
        let candidate = PairCatalog.destinations(from: from)
            .first { !settings.pairs.contains("\(from)-\($0)") }
        if let candidate {
            to = candidate
        }
    }

    // MARK: - Footer

    private var pair: String {
        "\(from)-\(to)"
    }

    private var exists: Bool {
        settings.pairs.contains(pair)
    }

    private var footer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    exists
                        ? L10n.t("addPair.exists")
                        : L10n.t("addPair.preview", PairDisplay(id: pair).text)
                )
                .font(.system(size: 11))
                .foregroundStyle(exists ? CotaTheme.amber : CotaTheme.textSecondary)

                Text(previewLine)
                    .font(.system(size: 15).monospacedDigit())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                Text(L10n.t("addPair.cancel"))
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: CotaTheme.Radius.button)
                            .fill(CotaTheme.cancelFill)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            MintButton(
                title: L10n.t("addPair.add"),
                height: 30,
                fontSize: 13,
                isEnabled: !exists && PairCatalog.contains(pair),
                action: add
            )
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 14)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    /// "1 US dollar = ¥ 150.81", from the last rate the app saw. A pair never
    /// fetched has nothing honest to show.
    private var previewLine: String {
        let name = PairNames.inSentence(L10n.currencyName(from))
        guard let bid = store.quotes.first(where: { $0.id == pair })?.bid else {
            return "1 \(name) = —"
        }
        return "1 \(name) = \(QuoteFormat.money(bid, currency: to))"
    }

    private func add() {
        guard !exists, PairCatalog.contains(pair) else { return }
        settings.addPair(pair)
        PanelState.shared.expandedPairID = pair
        onClose()
    }
}

private struct SuggestionChip: View {
    let pair: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let display = PairDisplay(id: pair)

        Button(action: action) {
            HStack(spacing: 5) {
                Text(Currency.named(display.base).avatarGlyph)
                    .foregroundStyle(CotaTheme.mint)
                Text(display.text)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Capsule().fill(hovering ? CotaTheme.mintSoft : CotaTheme.buttonFill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct CurrencyColumn: View {
    let title: String
    let codes: [String]
    let selection: String
    let isEnabled: (String) -> Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(CotaTheme.textSecondary)
                .padding(.top, 10)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        group(
                            L10n.t("addPair.currencies"),
                            codes.filter { !Currency.named($0).isCrypto })
                        group(
                            L10n.t("addPair.crypto"), codes.filter { Currency.named($0).isCrypto })
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
                .frame(height: CotaTheme.Size.sheetList)
                .onAppear { proxy.scrollTo(selection, anchor: .center) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func group(_ label: String, _ codes: [String]) -> some View {
        if !codes.isEmpty {
            Text(label.uppercased(with: L10n.language.locale))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(CotaTheme.moss)
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            ForEach(codes, id: \.self) { code in
                CurrencyItem(
                    code: code,
                    isSelected: selection == code,
                    isEnabled: isEnabled(code)
                ) {
                    onSelect(code)
                }
                .id(code)
            }
        }
    }
}

private struct CurrencyItem: View {
    let code: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(Currency.named(code).avatarGlyph)
                    .font(.system(size: 14))
                    .foregroundStyle(CotaTheme.mint)
                    .frame(width: 18)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(code)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? CotaTheme.mint : CotaTheme.textPrimary)
                    .frame(width: 34, alignment: .leading)

                Text(L10n.currencyName(code))
                    .font(.system(size: 12))
                    .foregroundStyle(CotaTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.button)
                    .fill(fill)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(code), \(L10n.currencyName(code))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var fill: Color {
        if isSelected { return CotaTheme.mintSoft }
        return hovering && isEnabled ? CotaTheme.buttonFill : Color.clear
    }
}

/// Square on top — the sheet hangs from the top of the content — and rounded
/// at the bottom. `open` leaves the top edge out of the stroke.
private struct SheetShape: Shape {
    var open = false

    func path(in rect: CGRect) -> Path {
        let radius = CotaTheme.Radius.sheetBottom
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        if !open {
            path.closeSubpath()
        }
        return path
    }
}
