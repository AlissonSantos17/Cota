import SwiftUI
import CotaKit

/// Label segments drawn at list scale, for the examples beside each format
/// option in Settings.
///
/// The menu bar itself draws the same segments as an attributed image, at menu
/// bar scale. Both read one source, so the wording of an example cannot drift
/// from what the bar shows; only the typography differs, which is deliberate —
/// an example sitting in a list should be sized like the list.
struct LabelSegmentsText: View {
    let segments: [LabelSegment]
    var size: CGFloat = 11

    var body: some View {
        segments.reduce(Text("")) { result, segment in
            result + text(for: segment)
        }
        .lineLimit(1)
    }

    private func text(for segment: LabelSegment) -> Text {
        Text(segment.text)
            .font(font(for: segment.role))
            .foregroundColor(color(for: segment.role))
    }

    private func font(for role: LabelSegment.Role) -> Font {
        switch role {
        case .code:
            return .system(size: size - 1).monospacedDigit()
        default:
            return .system(size: size).monospacedDigit()
        }
    }

    private func color(for role: LabelSegment.Role) -> Color {
        switch role {
        case .code:
            return Color(nsColor: .tertiaryLabelColor)
        case .indicator(let trend):
            switch trend {
            case .up: return .green
            case .down: return .red
            case .flat: return Color(nsColor: .secondaryLabelColor)
            }
        case .lead, .value, .separator:
            return Color(nsColor: .secondaryLabelColor)
        }
    }
}
