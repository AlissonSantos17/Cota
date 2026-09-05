import CotaKit
import SwiftUI

/// Pair name as the lists show it: the origin in the list weight, the
/// destination quieter, joined by a slash.
///
/// The stored ID stays hyphenated (`EUR-BRL`). This view is the one place
/// that pairing becomes `EUR/BRL` with the two codes at different weights.
struct PairLabel: View {
    let display: PairDisplay
    var size: CGFloat = 12

    init(_ id: String, size: CGFloat = 12) {
        self.display = PairDisplay(id: id)
        self.size = size
    }

    init(base: String, quote: String, size: CGFloat = 12) {
        self.display = PairDisplay(base: base, quote: quote)
        self.size = size
    }

    var body: some View {
        (Text(display.base)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(.primary)
            + Text("/")
            .font(.system(size: size, weight: .regular))
            .foregroundColor(.secondary)
            + Text(display.quote)
            .font(.system(size: size, weight: .regular))
            .foregroundColor(.secondary))
    }
}
