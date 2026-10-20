import SwiftUI

/// Mint segmented control.
///
/// The selected segment is a tint of the brand colour rather than
/// `controlAccentColor`: the panel and Settings are always dark and always
/// mint, whatever accent the person picked for the rest of the system.
struct SegmentedControl<Value: Hashable>: View {
    struct Segment {
        let label: String
        let value: Value

        init(_ label: String, _ value: Value) {
            self.label = label
            self.value = value
        }
    }

    /// The panel's control is smaller and sits on a darker surface.
    enum Style {
        case panel
        case settings

        var fontSize: CGFloat { self == .panel ? 11 : 12 }
        var padding: EdgeInsets {
            self == .panel
                ? EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9)
                : EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        }
        var track: Color { self == .panel ? CotaTheme.panelSegmentTrack : CotaTheme.segmentTrack }
        var unselected: Color { self == .panel ? CotaTheme.textSecondary : CotaTheme.textControl }
    }

    let segments: [Segment]
    @Binding var selection: Value
    var style: Style = .settings
    /// Equal-width segments across the whole row, as for the refresh
    /// interval. Otherwise each segment is as wide as its label.
    var fillsWidth = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments, id: \.value) { segment in
                let isSelected = selection == segment.value

                Button {
                    selection = segment.value
                } label: {
                    Text(segment.label)
                        .font(
                            .system(size: style.fontSize, weight: isSelected ? .semibold : .regular)
                        )
                        .foregroundStyle(isSelected ? CotaTheme.mint : style.unselected)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(style.padding)
                        .frame(maxWidth: fillsWidth ? .infinity : nil)
                        .background(
                            RoundedRectangle(cornerRadius: CotaTheme.Radius.segment)
                                .fill(isSelected ? CotaTheme.mintSelected : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: CotaTheme.Radius.segmentTrack)
                .fill(style.track)
        )
        .animation(CotaTheme.Motion.digits, value: selection)
    }
}
