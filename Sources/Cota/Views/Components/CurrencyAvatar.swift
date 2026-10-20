import CotaKit
import SwiftUI

/// The round avatar that leads a pair in the panel and in Settings: the
/// origin's glyph in mint, and a small badge with the destination's glyph in
/// the lower right corner.
///
/// Every pair carries the badge, BRL included. Leaving the real out made it
/// look like the one currency without a symbol, and the avatar alone could
/// not say what a pair was quoted in.
struct CurrencyAvatar: View {
    let base: String
    let quote: String
    var size: CGFloat = CotaTheme.Size.avatar

    init(pair: String, size: CGFloat = CotaTheme.Size.avatar) {
        let display = PairDisplay(id: pair)
        self.base = display.base
        self.quote = display.quote
        self.size = size
    }

    var body: some View {
        Text(Currency.named(base).avatarGlyph)
            .font(.system(size: glyphSize, weight: .semibold))
            .foregroundStyle(CotaTheme.mint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: size, height: size)
            .background(CotaTheme.graphite, in: Circle())
            .overlay(alignment: .bottomTrailing) {
                if showsBadge {
                    badge
                        .offset(x: CotaTheme.Size.badgeOutset, y: 3)
                }
            }
            .accessibilityHidden(true)
    }

    private var showsBadge: Bool {
        !quote.isEmpty
    }

    private var glyphSize: CGFloat {
        size >= CotaTheme.Size.avatar ? 15 : 14
    }

    /// A faint disc with the glyph, at the circle's lower right edge. A
    /// two-character glyph like "R$" is set smaller, so it neither spreads
    /// over the origin's glyph nor reaches the text beside the avatar.
    private var badge: some View {
        let glyph = Currency.named(quote).avatarGlyph

        return Text(glyph)
            .font(.system(size: glyph.count > 1 ? 8.5 : 11, weight: .light))
            .foregroundStyle(CotaTheme.badgeGlyph)
            .lineLimit(1)
            .fixedSize()
            .frame(width: CotaTheme.Size.avatarBadge, height: CotaTheme.Size.avatarBadge)
            // Just enough to read as a badge. See-through, so the edge of the
            // avatar still shows beneath it.
            .background(CotaTheme.badgeFill, in: Circle())
    }
}
