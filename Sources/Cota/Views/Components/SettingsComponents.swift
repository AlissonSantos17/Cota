import SwiftUI

/// Title of a Settings section, with an optional subtitle under it.
struct SettingsHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(CotaTheme.textSubtitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An 11pt explanation under a control.
struct SettingsNote: View {
    let text: String
    var color: Color = CotaTheme.textSecondary

    init(_ text: String, color: Color = CotaTheme.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row label, with a note under it when the label needs one.
struct SettingsLabel: View {
    let title: String
    var note: String?

    init(_ title: String, note: String? = nil) {
        self.title = title
        self.note = note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13))
            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(CotaTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Label on the left, control on the right, a hairline above or below.
struct SettingsRow<Label: View, Control: View>: View {
    enum Divider {
        case top
        case bottom
        case none
    }

    var divider: Divider = .bottom
    var verticalPadding: CGFloat = 12
    @ViewBuilder let label: Label
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 20) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
            control
        }
        .padding(.vertical, verticalPadding)
        .overlay(alignment: divider == .top ? .top : .bottom) {
            if divider != .none {
                Rectangle()
                    .fill(CotaTheme.rowDivider)
                    .frame(height: 1)
            }
        }
    }
}

/// 30×18 switch: mint when on, a white tint when off, a 14pt white knob.
struct MintToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(configuration.isOn ? CotaTheme.mint : CotaTheme.toggleOff)
                .frame(width: 30, height: 18)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .padding(.horizontal, 2)
                }
                .animation(CotaTheme.Motion.digits, value: configuration.isOn)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

/// The filled mint button: Create alert, Add.
struct MintButton: View {
    let title: String
    var height: CGFloat = 28
    var fontSize: CGFloat = 12
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(isEnabled ? CotaTheme.onMint : CotaTheme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: CotaTheme.Radius.button)
                        .fill(isEnabled ? CotaTheme.mint : CotaTheme.disabledFill)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// An icon-only button in the secondary text colour.
struct IconButton: View {
    let icon: String
    var size: CGFloat = 13
    var color: Color = CotaTheme.textSecondary
    var width: CGFloat = 18
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(color)
                .frame(width: width, height: width)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
