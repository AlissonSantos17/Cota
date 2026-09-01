import AppKit
import CotaKit
import SwiftUI

/// The label drawn in the menu bar.
///
/// `MenuBarExtra` flattens a `Text` label to a single size and a single colour,
/// and §6.3 needs three things it cannot express: a currency code one point
/// smaller and secondary, colour on the indicator and nowhere else, and tabular
/// figures. So the label is composed as an attributed string and handed over as
/// an image.
///
/// The body is one `Image` and nothing else. A menu bar label accepts a narrow
/// set of views, and wrapping it — in a `TimelineView`, to notice staleness on
/// a tick — produced a status item that drew nothing at all. Elapsed time is
/// watched by the store instead, which is where the rest of the panel already
/// reads it from.
///
/// Being an image rather than a template, it carries its own colours and does
/// not follow the menu bar automatically, so `colorScheme` is read here to
/// redraw on a change of appearance.
struct MenuBarLabelView: View {
    @ObservedObject var store: QuoteStore
    @ObservedObject var settings: SettingsStore

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: MenuBarLabelImage.render(segments, dimmed: isDimmed))
    }

    private var segments: [LabelSegment] {
        MenuBarLabel.segments(
            for: store.menuBarQuotes,
            format: settings.menuBarFormat,
            indicator: settings.menuBarIndicator
        )
    }

    /// A quote an hour old wearing a normal face is worse than no quote. The
    /// toggle governs the menu bar only: the panel always marks stale data,
    /// because there is room there to explain it.
    private var isDimmed: Bool {
        settings.dimWhenStale && (store.stale || store.error != nil)
    }
}

enum MenuBarLabelImage {
    /// Shown before the first fetch lands, and whenever no pair is selected. An
    /// empty label would leave an invisible status item with nothing to click.
    static let placeholder = "Cota"

    static func render(_ segments: [LabelSegment], dimmed: Bool) -> NSImage {
        let resolved =
            segments.isEmpty
            ? [LabelSegment(placeholder, .value)]
            : segments

        let text = attributedString(resolved, dimmed: dimmed)
        let size = text.size()
        let bounds = NSSize(width: max(1, ceil(size.width)), height: max(1, ceil(size.height)))

        // Drawn through a handler rather than lockFocus: the handler runs once
        // per scale factor, so the label stays sharp on a retina display.
        let image = NSImage(size: bounds, flipped: false) { rect in
            text.draw(in: rect)
            return true
        }

        image.accessibilityDescription = resolved.map(\.text).joined()
        return image
    }

    private static func attributedString(
        _ segments: [LabelSegment],
        dimmed: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for segment in segments {
            result.append(
                NSAttributedString(
                    string: segment.text,
                    attributes: [
                        .font: font(for: segment.role),
                        .foregroundColor: color(for: segment.role, dimmed: dimmed),
                    ]
                ))
        }

        return result
    }

    private static func font(for role: LabelSegment.Role) -> NSFont {
        switch role {
        case .code:
            // One point down, so the number stays the dominant element. A
            // symbol is left at full size: it is a single glyph, and shrinking
            // it makes it illegible.
            return tabular(size: baseFont.pointSize - 1)
        default:
            return tabular(size: baseFont.pointSize)
        }
    }

    private static func color(for role: LabelSegment.Role, dimmed: Bool) -> NSColor {
        if dimmed {
            return .tertiaryLabelColor
        }

        switch role {
        case .code:
            return .secondaryLabelColor
        case .indicator(let trend):
            switch trend {
            case .up: return .systemGreen
            case .down: return .systemRed
            case .flat: return .labelColor
            }
        case .lead, .value, .separator:
            return .labelColor
        }
    }

    private static let baseFont = NSFont.menuBarFont(ofSize: 0)

    /// Fixed-width figures, so a value going from 6,01 to 6,10 does not shove
    /// the icons to its left.
    private static func tabular(size: CGFloat) -> NSFont {
        let descriptor = NSFont.menuBarFont(ofSize: size)
            .fontDescriptor
            .addingAttributes([
                .featureSettings: [
                    [
                        NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                        NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
                    ]
                ]
            ])

        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont.menuBarFont(ofSize: size)
    }
}
