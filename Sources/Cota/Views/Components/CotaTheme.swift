import SwiftUI

/// The rebrand's tokens (Design/Rebrand, sections 2a and 2b).
///
/// The app takes its colours from the icon — mint on near-black — instead of
/// the system accent. Views read colours, radii, sizes and timings from here
/// and never carry a hex of their own.
enum CotaTheme {
    // MARK: Colours — surfaces

    /// Panel background.
    static let night = Color(hex: 0x111714)
    /// Currency avatar fill.
    static let graphite = Color(hex: 0x1B2420)
    /// Opening line, drag handle, unpinned pin, list group headers.
    static let moss = Color(hex: 0x4B5C55)
    /// An expanded row in the panel.
    static let expandedRow = Color(hex: 0x17201C)
    /// Settings content.
    static let window = Color(hex: 0x1C211F)
    /// Settings sidebar.
    static let sidebar = Color(hex: 0x161B18)
    /// The Add pair sheet.
    static let sheet = Color(hex: 0x1F2622)
    /// The strip behind the live menu bar preview.
    static let menuBarStrip = Color(hex: 0x2E3438)
    /// The veil behind the Add pair sheet.
    static let veil = Color(.sRGB, red: 6 / 255, green: 9 / 255, blue: 8 / 255, opacity: 0.55)

    // MARK: Colours — accent and meaning

    /// Accent, rising, selection.
    static let mint = Color(hex: 0x7BE0AE)
    /// Falling.
    static let coral = Color(hex: 0xFF8A7A)
    /// Stale data, paused alert, pair already in the list.
    static let amber = Color(hex: 0xF5C26B)
    /// Text on a mint fill.
    static let onMint = Color(hex: 0x0E1411)

    // MARK: Colours — text

    static let textPrimary = Color(hex: 0xF2F5F3)
    static let textBody = Color(hex: 0xE8ECEA)
    /// Unselected segment labels, sidebar items.
    static let textControl = Color(hex: 0xC4CCC8)
    /// Codes, notes, footer icons.
    static let textSecondary = Color(hex: 0x7E8B85)
    /// Settings section subtitles.
    static let textSubtitle = Color(hex: 0x8A9690)

    // MARK: Colours — white overlays

    /// Panel dividers.
    static let hairline = Color.white.opacity(0.07)
    static let rowDivider = Color.white.opacity(0.06)
    static let panelBorder = Color.white.opacity(0.09)
    static let sheetBorder = Color.white.opacity(0.12)
    static let fieldFill = Color.white.opacity(0.04)
    static let fieldBorder = Color.white.opacity(0.07)
    static let cardFill = Color.white.opacity(0.03)
    static let cardBorder = Color.white.opacity(0.08)
    static let chipFill = Color.white.opacity(0.08)
    static let buttonFill = Color.white.opacity(0.06)
    static let buttonFillHover = Color.white.opacity(0.10)
    static let cancelFill = Color.white.opacity(0.07)
    static let disabledFill = Color.white.opacity(0.08)
    static let toggleOff = Color.white.opacity(0.15)
    static let panelSegmentTrack = Color.white.opacity(0.05)
    static let segmentTrack = Color.white.opacity(0.06)
    static let footerStatus = Color.white.opacity(0.55)

    // MARK: Colours — mint overlays

    /// Selected segment.
    static let mintSelected = mint.opacity(0.16)
    /// Selected sidebar item, New alert button, selected list item.
    static let mintSoft = mint.opacity(0.14)
    /// Swap buttons.
    static let mintChip = mint.opacity(0.12)
    /// The alert counter in the panel header.
    static let mintCounter = mint.opacity(0.10)
    /// Selected format card.
    static let mintCard = mint.opacity(0.08)
    /// The border of the alert value field.
    static let mintFieldBorder = mint.opacity(0.40)
    /// The destination glyph in the avatar badge: quiet, so the origin's
    /// glyph stays the one that reads first.
    static let badgeGlyph = mint.opacity(0.35)
    /// The disc behind the badge glyph: noticeable, still see-through.
    static let badgeFill = graphite.opacity(0.55)
    static let upFill = mint.opacity(0.12)
    static let downFill = coral.opacity(0.12)

    /// Rising and falling always come with ▲/▼ as well; colour alone does
    /// not tell a colourblind reader the direction.
    static func trend(_ change: Decimal) -> Color {
        change < 0 ? coral : mint
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
    }

    // MARK: Sizes

    enum Size {
        static let panelWidth: CGFloat = 360
        static let panelHeader: CGFloat = 44
        static let row: CGFloat = 50
        static let avatar: CGFloat = 28
        /// The disc behind the badge glyph.
        static let avatarBadge: CGFloat = 15
        /// How far the badge reaches past the avatar's right edge.
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
    }

    // MARK: Motion

    enum Motion {
        /// Digits that changed.
        static let digits = Animation.easeOut(duration: 0.12)
        /// A row opening or closing, the sheet.
        static let expand = Animation.easeOut(duration: 0.18)
    }
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
