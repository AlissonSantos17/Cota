import AppKit
import CotaKit
import SwiftUI

/// The rebrand's tokens (Design/Rebrand, sections 2a and 2b), now per theme.
///
/// Every colour name from the first rebrand is kept, so no call site changes:
/// `CotaTheme.mint` still reads the accent — it is simply read from the
/// active `Palette` instead of being a constant. `ThemeController` swaps the
/// palette and redraws the panel and the Settings window by identity.
///
/// "mint" is the accent's historical name. In Light it is a deep green, so
/// that it holds 4.5:1 on white; read it as "accent".
enum CotaTheme {
    /// The palette every token below reads. Written only by `ThemeController`,
    /// on the main thread.
    static var palette: Palette = .cota

    // MARK: Colours — surfaces

    static var night: Color { palette.panel }
    static var graphite: Color { palette.avatar }
    static var moss: Color { palette.moss }
    static var expandedRow: Color { palette.expandedRow }
    static var window: Color { palette.window }
    static var sidebar: Color { palette.sidebar }
    static var sheet: Color { palette.sheet }
    static var menuBarStrip: Color { palette.menuBarStrip }
    /// The dot at the end of the chart: white, or near-black on Light, where
    /// white would vanish into the panel.
    static var chartDot: Color { palette.theme == .light ? palette.text : .white }
    /// The clock and the waiting note in the menu bar preview: dark on the
    /// Light theme's pale strip, white everywhere else.
    static var menuBarPreviewText: Color { palette.theme == .light ? palette.text : .white }
    /// The highlight behind the Cota label in that preview.
    static var menuBarPreviewPill: Color {
        palette.theme == .light ? .black.opacity(0.10) : .white.opacity(0.18)
    }
    static var veil: Color { palette.veil }

    // MARK: Colours — accent and meaning

    static var mint: Color { palette.accent }
    static var coral: Color { palette.down }
    static var amber: Color { palette.amber }
    static var onMint: Color { palette.onAccent }

    // MARK: Colours — text

    static var textPrimary: Color { palette.text }
    static var textBody: Color { palette.text }
    static var textControl: Color { palette.textControl }
    static var textSecondary: Color { palette.textSecondary }
    static var textSubtitle: Color { palette.textSubtitle }

    // MARK: Colours — ink overlays (white on dark themes, black on Light)

    static var hairline: Color { palette.ink(0.07) }
    static var rowDivider: Color { palette.ink(0.06) }
    static var panelBorder: Color { palette.panelBorder }
    static var sheetBorder: Color { palette.ink(0.12) }
    static var fieldFill: Color { palette.ink(0.04) }
    static var fieldBorder: Color { palette.ink(0.07) }
    static var cardFill: Color { palette.ink(0.03) }
    static var cardBorder: Color { palette.ink(0.08) }
    static var chipFill: Color { palette.ink(0.08) }
    static var buttonFill: Color { palette.ink(0.06) }
    static var buttonFillHover: Color { palette.ink(0.10) }
    static var cancelFill: Color { palette.ink(0.07) }
    static var disabledFill: Color { palette.ink(0.08) }
    static var toggleOff: Color { palette.ink(0.15) }
    static var panelSegmentTrack: Color { palette.ink(0.05) }
    static var segmentTrack: Color { palette.ink(0.06) }
    static var footerStatus: Color { palette.footerStatus }

    // MARK: Colours — accent overlays

    /// Selected segment. On glass a white lift reads better than a tint.
    static var mintSelected: Color {
        palette.isGlass ? .white.opacity(0.18) : palette.accent.opacity(0.16)
    }
    static var mintSoft: Color { palette.accent.opacity(palette.isGlass ? 0.20 : 0.14) }
    static var mintChip: Color { palette.accent.opacity(palette.isGlass ? 0.18 : 0.12) }
    static var mintCounter: Color { palette.accent.opacity(palette.isGlass ? 0.16 : 0.10) }
    static var mintCard: Color { palette.accent.opacity(0.08) }
    static var mintFieldBorder: Color { palette.accent.opacity(palette.isGlass ? 0.55 : 0.40) }
    /// Quiet, so the origin's glyph stays the one that reads first.
    static var badgeGlyph: Color { palette.accent.opacity(palette == .light ? 0.5 : 0.35) }
    static var badgeFill: Color { palette.badgeFill }
    static var upFill: Color { palette.up.opacity(0.12) }
    static var downFill: Color { palette.down.opacity(0.12) }

    /// Rising and falling always come with ▲/▼ as well; colour alone does
    /// not tell a colourblind reader the direction.
    static func trend(_ change: Decimal) -> Color {
        change < 0 ? palette.down : palette.up
    }

    // MARK: Radii

    enum Radius {
        static let panel: CGFloat = 12
        static let row: CGFloat = 10
        static let field: CGFloat = 9
        static let card: CGFloat = 10
        static let button: CGFloat = 7
        static let segmentTrack: CGFloat = 7
        static let segment: CGFloat = 5
        static let chip: CGFloat = 6
        static let sheetBottom: CGFloat = 14
        static let themeCard: CGFloat = 12
    }

    // MARK: Sizes

    enum Size {
        static let panelWidth: CGFloat = 360
        static let panelHeader: CGFloat = 44
        static let row: CGFloat = 50
        static let avatar: CGFloat = 28
        static let avatarBadge: CGFloat = 15
        static let badgeOutset: CGFloat = 4
        static let sparkline = CGSize(width: 56, height: 22)
        static let chart = CGSize(width: 324, height: 116)
        static let valueColumn: CGFloat = 96
        static let converter: CGFloat = 40
        static let actionButton: CGFloat = 28
        static let footer: CGFloat = 36
        static let sidebar: CGFloat = 190
        static let settingsWindow = CGSize(width: 820, height: 600)
        static let sheetWidth: CGFloat = 500
        static let sheetList: CGFloat = 250
        static let themePreview: CGFloat = 132
    }

    // MARK: Motion

    enum Motion {
        static let digits = Animation.easeOut(duration: 0.12)
        static let expand = Animation.easeOut(duration: 0.18)
        /// Cross-fade when the theme changes.
        static let theme = Animation.easeOut(duration: 0.2)
    }
}

/// One theme's colours. Values match `THEMES` in Cota Rebrand.dc.html.
struct Palette: Equatable {
    let theme: AppTheme

    // Surfaces
    let panel: Color
    let window: Color
    let sidebar: Color
    let sheet: Color
    let expandedRow: Color
    let avatar: Color
    let badgeFill: Color
    let veil: Color
    let menuBarStrip: Color
    /// Behind the mini panel in the Themes cards.
    let previewWall: AnyShapeStyle

    // Text
    let text: Color
    let textControl: Color
    let textSecondary: Color
    let textSubtitle: Color
    let footerStatus: Color

    // Accent and meaning
    let accent: Color
    let onAccent: Color
    let up: Color
    let down: Color
    let amber: Color
    let moss: Color

    // Lines and overlays
    let panelBorder: Color
    /// White on dark themes, black on Light.
    let inkBase: Color
    /// Glass needs stronger fills to read over a busy wallpaper.
    let inkScale: Double

    var isGlass: Bool { theme == .glass }
    var colorScheme: ColorScheme { theme.isDark ? .dark : .light }
    var appearance: NSAppearance? { NSAppearance(named: theme.isDark ? .darkAqua : .aqua) }

    func ink(_ opacity: Double) -> Color { inkBase.opacity(min(1, opacity * inkScale)) }

    static func == (lhs: Palette, rhs: Palette) -> Bool { lhs.theme == rhs.theme }

    static func of(_ theme: AppTheme) -> Palette {
        switch theme {
        case .cota: return .cota
        case .dark: return .dark
        case .light: return .light
        case .glass: return .glass
        }
    }

    static let cota = Palette(
        theme: .cota,
        panel: Color(hex: 0x111714), window: Color(hex: 0x1C211F), sidebar: Color(hex: 0x161B18),
        sheet: Color(hex: 0x1F2622), expandedRow: Color(hex: 0x17201C),
        avatar: Color(hex: 0x1B2420),
        badgeFill: Color(hex: 0x1B2420, opacity: 0.55), veil: Color(hex: 0x060908, opacity: 0.55),
        menuBarStrip: Color(hex: 0x2E3438), previewWall: AnyShapeStyle(Color(hex: 0x262B2E)),
        text: Color(hex: 0xF2F5F3), textControl: Color(hex: 0xC4CCC8),
        textSecondary: Color(hex: 0x7E8B85),
        textSubtitle: Color(hex: 0x8A9690), footerStatus: .white.opacity(0.55),
        accent: Color(hex: 0x7BE0AE), onAccent: Color(hex: 0x0E1411), up: Color(hex: 0x7BE0AE),
        down: Color(hex: 0xFF8A7A), amber: Color(hex: 0xF5C26B), moss: Color(hex: 0x4B5C55),
        panelBorder: .white.opacity(0.09), inkBase: .white, inkScale: 1
    )

    static let dark = Palette(
        theme: .dark,
        panel: Color(hex: 0x1E1F21), window: Color(hex: 0x232426), sidebar: Color(hex: 0x1C1D1F),
        sheet: Color(hex: 0x2A2B2E), expandedRow: Color(hex: 0x28292C),
        avatar: Color(hex: 0x2C2D30),
        badgeFill: Color(hex: 0x2C2D30, opacity: 0.55), veil: .black.opacity(0.5),
        menuBarStrip: Color(hex: 0x2A2A2D), previewWall: AnyShapeStyle(Color(hex: 0x2A2A2D)),
        text: Color(hex: 0xF5F5F7), textControl: Color(hex: 0xC7C7CC),
        textSecondary: Color(hex: 0x8E8E93),
        textSubtitle: Color(hex: 0x98989D), footerStatus: .white.opacity(0.55),
        accent: Color(hex: 0x7BE0AE), onAccent: Color(hex: 0x0E1411), up: Color(hex: 0x7BE0AE),
        down: Color(hex: 0xFF8A7A), amber: Color(hex: 0xF5C26B), moss: Color(hex: 0x545458),
        panelBorder: .white.opacity(0.10), inkBase: .white, inkScale: 1.15
    )

    static let light = Palette(
        theme: .light,
        panel: .white, window: .white, sidebar: Color(hex: 0xF4F6F5),
        sheet: .white, expandedRow: Color(hex: 0xF2F6F4), avatar: Color(hex: 0xE6F2EB),
        badgeFill: Color.white.opacity(0.6), veil: Color(hex: 0x141E19, opacity: 0.25),
        menuBarStrip: Color(hex: 0xD5DBD8), previewWall: AnyShapeStyle(Color(hex: 0xD5DBD8)),
        text: Color(hex: 0x111714), textControl: Color(hex: 0x3E4743),
        textSecondary: Color(hex: 0x6B7570),
        textSubtitle: Color(hex: 0x5E6863), footerStatus: Color(hex: 0x111714, opacity: 0.6),
        accent: Color(hex: 0x138A55), onAccent: .white, up: Color(hex: 0x138A55),
        down: Color(hex: 0xD4483B), amber: Color(hex: 0xB07A12), moss: Color(hex: 0xB4BEB9),
        panelBorder: .black.opacity(0.10), inkBase: .black, inkScale: 0.85
    )

    static let glass = Palette(
        theme: .glass,
        panel: Color(hex: 0x18201C, opacity: 0.42), window: Color(hex: 0x18201C, opacity: 0.38),
        sidebar: .white.opacity(0.06), sheet: Color(hex: 0x1E2823, opacity: 0.62),
        expandedRow: .white.opacity(0.08), avatar: .white.opacity(0.12),
        badgeFill: .white.opacity(0.08), veil: .black.opacity(0.25),
        menuBarStrip: .white.opacity(0.08),
        previewWall: AnyShapeStyle(
            LinearGradient(
                colors: [Color(hex: 0x3E8A6B), Color(hex: 0x1B2626), Color(hex: 0x3B4F8E)],
                startPoint: .topTrailing, endPoint: .bottomLeading)),
        text: .white, textControl: .white.opacity(0.85), textSecondary: .white.opacity(0.62),
        textSubtitle: .white.opacity(0.66), footerStatus: .white.opacity(0.7),
        accent: Color(hex: 0x8EF0BF), onAccent: Color(hex: 0x0E1411), up: Color(hex: 0x8EF0BF),
        down: Color(hex: 0xFF9C8F), amber: Color(hex: 0xFFD27F), moss: .white.opacity(0.35),
        panelBorder: .white.opacity(0.22), inkBase: .white, inkScale: 1.7
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
