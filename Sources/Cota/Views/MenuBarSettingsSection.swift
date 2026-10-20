import CotaKit
import SwiftUI

/// Settings → Menu bar.
///
/// The preview sits at the top because the choice only makes sense if the
/// person can see the result while deciding: symbols dropping to codes, or a
/// flag falling back for crypto, are both things you understand by watching
/// them happen.
struct MenuBarSettingsSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore

    var body: some View {
        SettingsHeader(title: L10n.t("settings.menuBar"), subtitle: L10n.t("menuBar.subtitle"))

        VStack(alignment: .leading, spacing: 8) {
            preview

            // No pair picker here: the pin in Pairs is the single source of
            // truth, and a second selector would put the reader back in front
            // of two lists of the same thing.
            if settings.orderedMenuBarPairs.isEmpty {
                SettingsNote(L10n.t("menuBar.empty"))
            } else if settings.orderedMenuBarPairs.count > 2 {
                // Not a cap: where the line falls depends on what else the
                // person keeps up there, so this explains rather than forbids.
                SettingsNote(L10n.t("menuBar.crowded"))
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            formatCards

            if let reason = MenuBarLabel.disabledReason(for: .value, pairCount: pinnedCount) {
                SettingsNote(reason)
            }

            // Only while "Symbol" is in fallback: without it the card looks
            // identical to "Code" and the option reads as broken.
            if selectedFormat == .auto, let note = collisionNote {
                SettingsNote(note)
            }
        }

        VStack(spacing: 0) {
            SettingsRow(divider: .bottom, verticalPadding: 6) {
                SettingsLabel(L10n.t("menuBar.change"))
            } control: {
                SegmentedControl(
                    segments: ChangeIndicator.allCases.map { .init($0.label, $0) },
                    selection: $settings.menuBarIndicator
                )
                .accessibilityLabel(L10n.t("menuBar.change"))
            }

            // Governs the menu bar and nothing else. Dimming grates precisely
            // on the bar, which is always in view; the panel was opened on
            // purpose, and there is room there to explain stale data.
            SettingsRow(divider: .none, verticalPadding: 6) {
                SettingsLabel(L10n.t("menuBar.dimStale"), note: L10n.t("menuBar.dimStaleNote"))
            } control: {
                Toggle("", isOn: $settings.dimWhenStale)
                    .toggleStyle(MintToggleStyle())
                    .accessibilityLabel(L10n.t("menuBar.dimStale"))
            }
        }
    }

    private var pinnedCount: Int {
        settings.orderedMenuBarPairs.count
    }

    // MARK: - Preview

    /// Drawn by the same renderer the menu bar uses, from the same segments,
    /// so the preview cannot promise something the bar will not draw.
    private var preview: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)

            if selectedQuotes.isEmpty {
                Text(settings.orderedMenuBarPairs.isEmpty ? "" : L10n.t("menuBar.waiting"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else {
                Image(nsImage: MenuBarLabelImage.render(previewSegments, dimmed: false))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: CotaTheme.Radius.segment)
                            .fill(Color.white.opacity(0.18))
                    )
            }

            Text(
                Date.now.formatted(
                    .dateTime.weekday(.abbreviated).day().month().hour().minute()
                        .locale(L10n.language.locale))
            )
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.75))
            .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.card)
                .fill(CotaTheme.menuBarStrip)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t("a11y.menuBarPreview"))
    }

    private var previewSegments: [LabelSegment] {
        MenuBarLabel.segments(
            for: selectedQuotes,
            format: settings.menuBarFormat,
            indicator: settings.menuBarIndicator,
            alertPairs: settings.alertPairs
        )
    }

    private var selectedQuotes: [MenuBarQuote] {
        store.menuBarQuotes
    }

    // MARK: - Format

    /// What the bar is actually drawing, which is not always what is stored:
    /// "Value only" falls back to "Symbol" as soon as a second pair is pinned.
    /// The stored choice is left alone — unpinning the second pair has to
    /// bring "Value only" back.
    private var selectedFormat: MenuBarFormat {
        MenuBarLabel.effectiveFormat(settings.menuBarFormat, pairCount: pinnedCount)
    }

    private var formatCards: some View {
        HStack(spacing: 8) {
            ForEach(MenuBarFormat.allCases) { format in
                FormatCard(
                    label: format.label,
                    example: example(for: format),
                    isSelected: selectedFormat == format,
                    isEnabled: MenuBarLabel.disabledReason(for: format, pairCount: pinnedCount)
                        == nil
                ) {
                    settings.menuBarFormat = format
                }
            }
        }
    }

    /// Examples derive from the first pinned pair rather than a fixed value:
    /// an example hardcoded to EUR while the person follows USD and CAD
    /// describes a configuration that is not theirs. With nothing pinned, the
    /// first pair in the list stands in.
    private func example(for format: MenuBarFormat) -> [LabelSegment] {
        let sample =
            selectedQuotes.first
            ?? store.quotes.first.map {
                MenuBarQuote(pair: $0.id, bid: $0.bid, change: $0.pctChange)
            }
        guard let sample else { return [] }

        let among = selectedQuotes.isEmpty ? [sample] : selectedQuotes
        return MenuBarLabel.exampleSegments(
            for: sample,
            format: format,
            among: among.map(\.code),
            destinations: among.map(\.destination)
        )
    }

    private var collisionNote: String? {
        MenuBarLabel.collisionNote(among: selectedQuotes.map(\.code))
    }
}

private struct FormatCard: View {
    let label: String
    let example: [LabelSegment]
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                LabelSegmentsText(segments: example, size: 15)
                    .frame(height: 20, alignment: .leading)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? CotaTheme.mint : CotaTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.card)
                    .fill(isSelected ? CotaTheme.mintCard : CotaTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.card)
                    .strokeBorder(isSelected ? CotaTheme.mint : CotaTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
