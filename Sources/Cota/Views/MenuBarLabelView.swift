import SwiftUI
import AppKit
import CotaKit

/// The label drawn in the menu bar.
///
/// `MenuBarExtra` flattens a `Text` label to a single size and a single colour,
/// and §6.3 needs three things it cannot express: a currency code one point
/// smaller and secondary, colour on the indicator and nowhere else, and tabular
/// figures. So the label is composed as an attributed string and handed over as
/// an image.
///
/// Being an image rather than a template, it carries its own colours and does
/// not follow the menu bar automatically — `colorScheme` is read here so that a
/// change of appearance re-enters `body` and redraws it.
struct MenuBarLabelView: View {
    @ObservedObject var store: QuoteStore
    @ObservedObject var settings: SettingsStore

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Staleness is a function of elapsed time. Nothing republishes while a
        // refresh keeps failing, so the label re-evaluates on a tick of its own.
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let segments = MenuBarLabel.segments(
                for: store.menuBarQuotes,
                format: settings.menuBarFormat,
                indicator: settings.menuBarIndicator
            )

            if segments.isEmpty {
                Text("Cota")
            } else {
                Image(nsImage: MenuBarLabelImage.render(
                    segments,
                    dimmed: isDimmed(now: context.date)
                ))
            }
        }
    }

    /// A quote an hour old wearing a normal face is worse than no quote. The
    /// toggle governs the menu bar only: the panel always marks stale data,
    /// because there is room there to explain it.
    private func isDimmed(now: Date) -> Bool {
        settings.dimWhenStale && (store.isStale(at: now) || store.error != nil)
    }
}

enum MenuBarLabelImage {
    static func render(_ segments: [LabelSegment], dimmed: Bool) -> NSImage {
        let text = attributedString(segments, dimmed: dimmed)
        let size = text.size()
        let bounds = NSSize(width: ceil(size.width), height: ceil(size.height))

        // Drawn through a handler rather than lockFocus: the handler runs once
        // per scale factor, so the label stays sharp on a retina display.
        let image = NSImage(size: bounds, flipped: false) { rect in
            text.draw(in: rect)
            return true
        }

        image.accessibilityDescription = segments.map(\.text).joined()
        return image
    }

    private static func attributedString(
        _ segments: [LabelSegment],
        dimmed: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for segment in segments {
            result.append(NSAttributedString(
                string: segment.text,
                attributes: [
                    .font: font(for: segment.role),
                    .foregroundColor: color(for: segment.role, dimmed: dimmed)
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
                        NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
                    ]
                ]
            ])

        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont.menuBarFont(ofSize: size)
    }
}
