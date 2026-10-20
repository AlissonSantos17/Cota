import CotaKit
import SwiftUI

/// Settings → Temas: four cards, each a small live preview of the panel in
/// that theme, and the "Follow macOS" switch.
struct ThemesSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    @ObservedObject private var theme = ThemeController.shared

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        SettingsHeader(title: L10n.t("settings.themes"), subtitle: L10n.t("themes.subtitle"))

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppTheme.allCases) { option in
                ThemeCard(
                    theme: option,
                    isSelected: theme.active == option,
                    rows: previewRows
                ) {
                    settings.theme = option
                    // Picking a theme by hand is a request to see it now.
                    if settings.followsSystemAppearance, option != theme.active {
                        settings.followsSystemAppearance = false
                    }
                }
            }
        }

        SettingsRow(divider: .top) {
            SettingsLabel(L10n.t("themes.followSystem"), note: L10n.t("themes.followSystemNote"))
        } control: {
            Toggle("", isOn: $settings.followsSystemAppearance)
                .toggleStyle(MintToggleStyle())
                .accessibilityLabel(L10n.t("themes.followSystem"))
        }
    }

    /// The person's first three pairs, so the preview shows their own list.
    private var previewRows: [ThemeCard.Row] {
        settings.pairs.prefix(3).map { pair in
            let quote = store.quotes.first { $0.id == pair }
            let display = PairDisplay(id: pair)
            return ThemeCard.Row(
                pair: pair,
                base: display.base,
                name: L10n.currencyName(display.base),
                value: quote.map { QuoteFormat.money($0.bid, currency: display.quote) } ?? "—",
                change: quote?.pctChange ?? 0
            )
        }
    }
}

/// One theme option. Draws with `Palette.of(theme)` directly — never with
/// `CotaTheme`, which reads the active palette.
private struct ThemeCard: View {
    struct Row: Identifiable {
        let pair: String
        let base: String
        let name: String
        let value: String
        let change: Decimal
        var id: String { pair }

        var changeText: String {
            "\(change < 0 ? "▼" : "▲") \(QuoteFormat.percentMagnitude(change))"
        }
    }

    let theme: AppTheme
    let isSelected: Bool
    let rows: [Row]
    let action: () -> Void

    private var palette: Palette { .of(theme) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t(theme.titleKey))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? CotaTheme.mint : CotaTheme.textPrimary)
                        Text(L10n.t(theme.noteKey))
                            .font(.system(size: 11))
                            .foregroundStyle(CotaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    radio
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.themeCard)
                    .fill(isSelected ? CotaTheme.mintCard : CotaTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.themeCard)
                    .strokeBorder(isSelected ? CotaTheme.mint : CotaTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t(theme.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8).fill(palette.previewWall)
            miniPanel.padding(.top, 12).padding(.trailing, 14)
        }
        .frame(height: CotaTheme.Size.themePreview)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var miniPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.t("panel.title")).font(.system(size: 10, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 7) {
                    Text(Currency.named(row.base).avatarGlyph)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 18, height: 18)
                        .background(palette.avatar, in: Circle())
                    Text(row.name)
                        .font(.system(size: 9, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(row.value).font(.system(size: 9, weight: .medium).monospacedDigit())
                        Text(row.changeText)
                            .font(.system(size: 8).monospacedDigit())
                            .foregroundStyle(row.change < 0 ? palette.down : palette.up)
                    }
                }
                .padding(.horizontal, 6)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(
                        index == 0 ? palette.expandedRow : .clear)
                )
                .padding(.horizontal, 4)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(width: 196)
        .foregroundStyle(palette.text)
        .background {
            if palette.isGlass {
                RoundedRectangle(cornerRadius: 9).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 9).fill(palette.panel)
            } else {
                RoundedRectangle(cornerRadius: 9).fill(palette.panel)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(palette.panelBorder, lineWidth: 1))
        .environment(\.colorScheme, palette.colorScheme)
    }

    private var radio: some View {
        Circle()
            .strokeBorder(isSelected ? CotaTheme.mint : CotaTheme.toggleOff, lineWidth: 1.5)
            .frame(width: 16, height: 16)
            .overlay(
                Circle().fill(CotaTheme.mint).frame(width: 8, height: 8).opacity(isSelected ? 1 : 0)
            )
    }
}
