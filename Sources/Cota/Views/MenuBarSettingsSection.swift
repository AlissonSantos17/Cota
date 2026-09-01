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
            group {
                SectionHeader(title: "Menu bar")
                preview
            }

            SectionSeparator()

            group {
                SectionHeader(title: "Pairs to show")
                pairsList
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
                Text(settings.orderedMenuBarPairs.isEmpty ? "No pairs selected" : "Waiting for quotes")
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

    private var pairsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(settings.pairs.enumerated()), id: \.element) { index, pair in
                ListRow(leadingWidth: 16) {
                    Toggle("", isOn: Binding(
                        get: { settings.isShownInMenuBar(pair) },
                        set: { settings.setMenuBarPair(pair, shown: $0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .accessibilityLabel("Show \(pair) in the menu bar")
                } center: {
                    Text(pair)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, Layout.horizontalPadding)

                if index < settings.pairs.count - 1 {
                    RowSeparator()
                }
            }

            // Not a cap: three labels start pushing the other menu bar icons
            // off, but where that line falls depends on what else the person
            // keeps up there, so this explains rather than forbids.
            if settings.orderedMenuBarPairs.count > 2 {
                helpText("Two pairs fit comfortably; more will crowd the other menu bar icons.")
            }
        }
    }

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

    private var staleToggle: some View {
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
        .padding(.top, 6)
        .help("The panel always marks stale quotes; this dims the menu bar too.")
    }

    private func helpText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Layout.horizontalPadding + 16 + Layout.columnSpacing)
            .padding(.trailing, Layout.horizontalPadding)
            .padding(.bottom, 6)
    }
}
