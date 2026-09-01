import SwiftUI
import CotaKit

/// The "Menu bar" block of Settings.
///
/// The preview sits at the top because the choice only makes sense if the
/// person can see the result while deciding: `auto` dropping to codes, or a
/// flag falling back for crypto, are both things you understand by watching
/// them happen.
struct MenuBarSettingsSection: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore

    var body: some View {
        VStack(spacing: 0) {
            // "Preview", not "Menu bar": the tab already says which surface
            // this is, and repeating it inside makes the real headers below
            // look like siblings of a title.
            group {
                SectionHeader(title: "Preview")
                preview

                // No pair picker here: the "Menu bar" column of the Pairs tab
                // is the single source of truth, and a second selector would
                // put the reader back in front of two lists of the same thing.
                if settings.orderedMenuBarPairs.isEmpty {
                    helpText("Tick a pair in the Pairs tab to show it here.", indent: 0)
                } else if settings.orderedMenuBarPairs.count > 2 {
                    // Not a cap: where the line falls depends on what else the
                    // person keeps up there, so this explains rather than
                    // forbids.
                    helpText(
                        "Two pairs fit comfortably; more will crowd the other menu bar icons.",
                        indent: 0
                    )
                }
            }

            SectionSeparator()

            group {
                SectionHeader(title: "Format")
                formatList
            }

            SectionSeparator()

            group {
                SectionHeader(title: "Change indicator")
                indicatorControl
            }

            SectionSeparator()

            // Its own block rather than a tail of "Change indicator": it governs
            // the whole label, not what follows the number.
            group {
                staleToggle
            }
        }
    }

    @ViewBuilder
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, Layout.sectionSpacing)
    }

    // MARK: - Preview

    /// Drawn by the same renderer the menu bar uses, from the same segments, so
    /// the preview cannot promise something the bar will not draw.
    private var preview: some View {
        HStack {
            if selectedQuotes.isEmpty {
                Text(settings.orderedMenuBarPairs.isEmpty
                    ? "No pairs shown in the menu bar"
                    : "Waiting for quotes")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Image(nsImage: MenuBarLabelImage.render(previewSegments, dimmed: false))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 26)
        .padding(.horizontal, Layout.columnSpacing)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Menu bar preview")
    }

    private var previewSegments: [LabelSegment] {
        MenuBarLabel.segments(
            for: selectedQuotes,
            format: settings.menuBarFormat,
            indicator: settings.menuBarIndicator
        )
    }

    private var selectedQuotes: [MenuBarQuote] {
        store.menuBarQuotes
    }

    // MARK: - Pairs

    // MARK: - Format

    private var formatList: some View {
        VStack(spacing: 0) {
            ForEach(Array(MenuBarFormat.allCases.enumerated()), id: \.element) { index, format in
                formatRow(format)

                if let reason = MenuBarLabel.disabledReason(
                    for: format,
                    pairCount: settings.orderedMenuBarPairs.count
                ) {
                    helpText(reason)
                }

                // Only under "Automatic", and only while it is in fallback:
                // without it the row looks identical to "Currency code" and the
                // option reads as broken. With it, the coincidence becomes a
                // rule the person can act on.
                if format == .auto, let note = collisionNote {
                    helpText(note)
                }

                if index < MenuBarFormat.allCases.count - 1 {
                    RowSeparator()
                }
            }
        }
    }

    private func formatRow(_ format: MenuBarFormat) -> some View {
        let isDisabled = MenuBarLabel.disabledReason(
            for: format,
            pairCount: settings.orderedMenuBarPairs.count
        ) != nil

        return Button {
            settings.menuBarFormat = format
        } label: {
            ListRow(leadingWidth: 16, trailingWidth: 104) {
                Image(systemName: settings.menuBarFormat == format
                    ? "largecircle.fill.circle"
                    : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(settings.menuBarFormat == format
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(.secondary))
            } center: {
                Text(format.label)
                    .font(.system(size: 12))
            } trailing: {
                LabelSegmentsText(segments: example(for: format))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .padding(.horizontal, Layout.horizontalPadding)
        .accessibilityAddTraits(settings.menuBarFormat == format ? [.isSelected] : [])
    }

    /// Examples derive from the first selected pair, never from a fixed value:
    /// an example hardcoded to EUR while the person follows USD and CAD
    /// describes a configuration that is not theirs.
    private func example(for format: MenuBarFormat) -> [LabelSegment] {
        guard let first = selectedQuotes.first else { return [] }

        return MenuBarLabel.exampleSegments(
            for: first,
            format: format,
            among: selectedQuotes.map(\.code)
        )
    }

    private var collisionNote: String? {
        MenuBarLabel.collisionNote(among: selectedQuotes.map(\.code))
    }

    // MARK: - Indicator

    private var indicatorControl: some View {
        SegmentedControl(
            segments: ChangeIndicator.allCases.map { .init($0.label, $0) },
            selection: $settings.menuBarIndicator
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .accessibilityLabel("Change indicator")
    }

    /// Governs the menu bar and nothing else. Dimming grates precisely on the
    /// bar, which is always in view; the panel was opened on purpose, and the
    /// person there wants the whole picture with room to explain it.
    private var staleToggle: some View {
        VStack(spacing: 0) {
            ListRow {
                EmptyView()
            } center: {
                Text("Dim when data is stale")
                    .font(.system(size: 12))
            } trailing: {
                Toggle("", isOn: $settings.dimWhenStale)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .padding(.horizontal, Layout.horizontalPadding)

            // On screen, not in a tooltip: without it the panel going on
            // marking stale data with the toggle off reads as a bug, and a
            // tooltip is only found by someone who already suspected one.
            helpText(
                "Applies to the menu bar only. The popover always marks stale data.",
                indent: Layout.leadingSlotWidth + Layout.columnSpacing
            )
        }
    }

    /// Indented to whatever it explains: under a row, past the slot reserved
    /// for the radio or checkbox, so the line starts under the label and not
    /// under the control; under the preview, flush with the section margin.
    private func helpText(_ text: String, indent: CGFloat = 16 + Layout.columnSpacing) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Layout.horizontalPadding + indent)
            .padding(.trailing, Layout.horizontalPadding)
            .padding(.bottom, 6)
    }
}
