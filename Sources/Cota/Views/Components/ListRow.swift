import SwiftUI

/// The single grid both screens are built on.
///
/// No element carries its own inset: section headers, rows, buttons and
/// footers all derive their spacing from here, which is what keeps the left
/// and right margins aligned as sections come and go.
enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let headerToContentSpacing: CGFloat = 8
    static let rowHeight: CGFloat = 34
    static let quoteRowHeight: CGFloat = 48
    static let leadingSlotWidth: CGFloat = 14
    static let trailingSlotWidth: CGFloat = 18
    static let columnSpacing: CGFloat = 8
    static let hairline: CGFloat = 0.5
}

/// A row with three slots: a fixed leading slot (handle, badge, icon), a
/// flexible center, and a fixed trailing slot for accessories.
///
/// The leading and trailing widths are reserved whether or not the slot has
/// content, so accessories land on the same x across every list.
struct ListRow<Leading: View, Center: View, Trailing: View>: View {
    let height: CGFloat
    let leading: Leading
    let center: Center
    let trailing: Trailing

    init(
        height: CGFloat = Layout.rowHeight,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.height = height
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Layout.columnSpacing) {
            leading
                .frame(width: Layout.leadingSlotWidth, alignment: .center)

            center
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .frame(width: Layout.trailingSlotWidth, alignment: .trailing)
        }
        .frame(height: height)
    }
}

/// Title of a section: 11px, secondary, sentence case.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.headerToContentSpacing)
    }
}

/// Hairline between rows of the same list, respecting the 16px margin.
struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: Layout.hairline)
            .padding(.horizontal, Layout.horizontalPadding)
    }
}

/// Hairline between sections, edge to edge.
struct SectionSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: Layout.hairline)
    }
}
