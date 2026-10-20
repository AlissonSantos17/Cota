import Foundation

/// Settings → Temas. Which palette the panel and the Settings window draw with.
///
/// The menu bar label is not themed: it sits in the system's bar and follows
/// macOS, like the clock and the battery beside it.
public enum AppTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Mint on night — the icon's colours. The default.
    case cota
    /// Neutral macOS greys, mint accent.
    case dark
    /// White surfaces, deep green accent.
    case light
    /// Translucent: the wallpaper shows through the panel and the window.
    case glass

    public var id: String { rawValue }

    public var titleKey: String { "themes.\(rawValue)" }
    public var noteKey: String { "themes.\(rawValue).note" }

    /// Whether the theme draws on a dark ground. Picks the AppKit appearance,
    /// SwiftUI colour scheme and the system controls that go with it.
    public var isDark: Bool { self != .light }

    /// The theme actually drawn.
    ///
    /// With "Follow macOS" on, light mode always gets Light; dark mode keeps
    /// the person's choice, so someone on Cota or Liquid Glass does not lose
    /// it at sunset. Light chosen in dark mode falls back to Cota, the default.
    public static func resolve(_ chosen: AppTheme, followsSystem: Bool, systemIsDark: Bool)
        -> AppTheme
    {
        guard followsSystem else { return chosen }
        if !systemIsDark { return .light }
        return chosen == .light ? .cota : chosen
    }
}
