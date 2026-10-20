import CotaKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case pairs
    case menuBar
    case themes
    case alerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L10n.t("settings.general")
        case .pairs: return L10n.t("settings.pairs")
        case .menuBar: return L10n.t("settings.menuBar")
        case .themes: return L10n.t("settings.themes")
        case .alerts: return L10n.t("settings.alerts")
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .pairs: return "list.bullet"
        case .menuBar: return "menubar.rectangle"
        case .themes: return "paintpalette"
        case .alerts: return "bell"
        }
    }
}

/// Which section is showing and whether Add pair is open. Owned by the window
/// controller, so the panel's gear can move an open window back to General.
@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var section: SettingsSection = .general
    @Published var isAddingPair = false
}

/// The contents of the Settings window: a sidebar of five sections and the
/// selected one beside it.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var store: QuoteStore
    @ObservedObject var navigation: SettingsNavigation
    @ObservedObject private var theme = ThemeController.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(CotaTheme.rowDivider)
                .frame(width: 1)

            content
        }
        // Flexible height: the content view runs under the transparent title
        // bar, so it is taller than the content size the window was given.
        .frame(width: CotaTheme.Size.settingsWindow.width)
        .frame(minHeight: CotaTheme.Size.settingsWindow.height, maxHeight: .infinity)
        .background(ThemeSurface(CotaTheme.window))
        .foregroundStyle(CotaTheme.textPrimary)
        .overlay { addPairOverlay }
        .animation(CotaTheme.Motion.expand, value: navigation.isAddingPair)
        .environment(\.colorScheme, CotaTheme.palette.colorScheme)
        .ignoresSafeArea()
        // Keying the tree on the language and the theme redraws every label
        // and colour when either changes.
        .id(ThemeKey(language: settings.language, theme: theme.active))
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { section in
                SidebarItem(
                    section: section,
                    count: count(for: section),
                    isSelected: navigation.section == section
                ) {
                    navigation.section = section
                }
            }

            Spacer(minLength: 0)
        }
        // Clears the traffic lights, which sit over the sidebar.
        .padding(.top, 46)
        .padding(.horizontal, 10)
        .padding(.bottom, 14)
        .frame(width: CotaTheme.Size.sidebar)
        .frame(maxHeight: .infinity)
        .background(CotaTheme.sidebar)
    }

    private func count(for section: SettingsSection) -> Int? {
        switch section {
        case .pairs: return settings.pairs.count
        case .alerts: return settings.alerts.filter(\.isEnabled).count
        case .general, .menuBar, .themes: return nil
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                switch navigation.section {
                case .general:
                    GeneralSection(settings: settings)
                case .pairs:
                    PairsSection(settings: settings, store: store) {
                        navigation.isAddingPair = true
                    }
                case .menuBar:
                    MenuBarSettingsSection(settings: settings, store: store)
                case .themes:
                    ThemesSection(settings: settings, store: store)
                case .alerts:
                    AlertsSection(settings: settings, store: store)
                }
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The window already paints the ground; on glass a second fill here
        // would hide the material.
        .background(Color.clear)
    }

    // MARK: - Add pair

    @ViewBuilder
    private var addPairOverlay: some View {
        if navigation.isAddingPair {
            ZStack(alignment: .top) {
                CotaTheme.veil
                    .onTapGesture { navigation.isAddingPair = false }
                    .transition(.opacity)

                // Centred on the whole window, as in the prototype, and as tall
                // as its content — it hangs from the top, never to the bottom.
                AddPairSheet(settings: settings, store: store) {
                    navigation.isAddingPair = false
                }
                .fixedSize(horizontal: false, vertical: true)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

private struct SidebarItem: View {
    let section: SettingsSection
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 14))
                    .frame(width: 18)

                Text(section.title)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let count {
                    Text("\(count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(CotaTheme.textSecondary)
                }
            }
            .foregroundStyle(isSelected ? CotaTheme.mint : CotaTheme.textControl)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: CotaTheme.Radius.button)
                    .fill(isSelected ? CotaTheme.mintSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - General

private struct GeneralSection: View {
    @ObservedObject var settings: SettingsStore

    private let intervalOptions: [(label: String, value: Int)] = [
        ("30s", 30), ("1m", 60), ("2m", 120), ("5m", 300), ("10m", 600),
    ]

    var body: some View {
        SettingsHeader(title: L10n.t("settings.general"))

        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("general.refresh"))
                .font(.system(size: 13))

            SegmentedControl(
                segments: intervalOptions.map { .init($0.label, $0.value) },
                selection: $settings.refreshInterval,
                fillsWidth: true
            )
            .accessibilityLabel(L10n.t("general.refresh"))

            SettingsNote(L10n.t("general.refreshNote"))
        }

        VStack(spacing: 0) {
            SettingsRow(divider: .top) {
                SettingsLabel(L10n.t("general.language"), note: L10n.t("general.languageNote"))
            } control: {
                SegmentedControl(
                    segments: AppLanguage.allCases.map { .init($0.label, $0) },
                    selection: $settings.language
                )
                .accessibilityLabel(L10n.t("general.language"))
            }

            SettingsRow(divider: .top) {
                SettingsLabel(L10n.t("general.launchAtLogin"))
            } control: {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                .toggleStyle(MintToggleStyle())
                .accessibilityLabel(L10n.t("general.launchAtLogin"))
            }
        }
        // The login item can be revoked in System Settings while the app runs,
        // so the switch re-reads it on every open rather than trusting the
        // value it was built with.
        .task { settings.loadLaunchAtLogin() }
    }
}
