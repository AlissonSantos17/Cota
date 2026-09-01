import SwiftUI

/// Segmented control whose segments always have identical widths.
///
/// The stock control sizes each segment to its label, which leaves "30s"
/// wider than "1m" and stops the group short of the right margin.
struct SegmentedControl<Value: Hashable>: View {
    struct Segment {
        let label: String
        let value: Value

        init(_ label: String, _ value: Value) {
            self.label = label
            self.value = value
        }
    }

    let segments: [Segment]
    @Binding var selection: Value
    var height: CGFloat = 28

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments, id: \.value) { segment in
                Button {
                    selection = segment.value
                } label: {
                    Text(segment.label)
                        .font(.system(size: 11, weight: selection == segment.value ? .semibold : .regular))
                        .foregroundStyle(selection == segment.value ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(selection == segment.value ? Color.accentColor : Color.clear)
                )
                .accessibilityAddTraits(selection == segment.value ? [.isSelected] : [])
            }
        }
        .padding(3)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
        )
        .animation(.easeInOut(duration: 0.15), value: selection)
    }
}
