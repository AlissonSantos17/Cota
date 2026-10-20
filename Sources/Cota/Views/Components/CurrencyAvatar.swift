import CotaKit
import SwiftUI

/// The round avatar that leads a pair in the panel and in Settings: the
/// origin's glyph in mint, and — when the destination is not the real — a
/// small badge with the destination's glyph in the lower right corner.
///
/// BRL needs no badge because it is the default answer to "in what?": an app
/// of rates in reais only has to point out the pairs that are not.
struct CurrencyAvatar: View {
    let base: String
    let quote: String
    var size: CGFloat = CotaTheme.Size.avatar
    /// The badge is cut out of whatever the avatar sits on.
    var surface: Color = CotaTheme.night

    init(
        pair: String,
        size: CGFloat = CotaTheme.Size.avatar,
        surface: Color = CotaTheme.night
    ) {
        let display = PairDisplay(id: pair)
        self.base = display.base
        self.quote = display.quote
        self.size = size
        self.surface = surface
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
                        .offset(x: 5, y: 4)
                }
            }
            .accessibilityHidden(true)
    }

    private var showsBadge: Bool {
        !quote.isEmpty && quote != "BRL"
    }

    private var glyphSize: CGFloat {
        size >= CotaTheme.Size.avatar ? 15 : 14
    }

    private var badgeSize: CGFloat {
        size >= CotaTheme.Size.avatar ? CotaTheme.Size.avatarBadge : 16
    }

    private var badge: some View {
        Text(Currency.named(quote).avatarGlyph)
            .font(.system(size: 10))
            .foregroundStyle(CotaTheme.mint)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: badgeSize, height: badgeSize)
            .background(surface, in: Circle())
            .overlay(Circle().strokeBorder(CotaTheme.graphite, lineWidth: 1))
    }
}
