import SwiftUI

enum SettingsLayout {
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let headerToContentSpacing: CGFloat = 8
    static let rowHeight: CGFloat = 34
    static let trailingSlotWidth: CGFloat = 20
    static let leadingSlotWidth: CGFloat = 16
    static let hairline: CGFloat = 0.5
}

struct SettingsRow<Leading: View, Center: View, Trailing: View>: View {
    let leading: Leading
    let center: Center
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            leading
                .frame(width: SettingsLayout.leadingSlotWidth, alignment: .center)

            center
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .frame(width: SettingsLayout.trailingSlotWidth, alignment: .trailing)
        }
        .frame(height: SettingsLayout.rowHeight)
    }
}

struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: SettingsLayout.hairline)
            .padding(.leading, SettingsLayout.horizontalPadding + SettingsLayout.leadingSlotWidth + 8)
            .padding(.trailing, SettingsLayout.horizontalPadding)
    }
}

struct SectionSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(height: SettingsLayout.hairline)
    }
}
