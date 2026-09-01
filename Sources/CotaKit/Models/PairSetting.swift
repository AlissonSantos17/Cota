import Foundation

/// A configured pair, and whether it labels the menu bar.
///
/// The flag used to live in a second list of pair names kept alongside the
/// first. Two lists of the same thing need reconciling on every edit — a pair
/// removed here had to be hunted down there — and in Settings they showed up as
/// two blocks that gave the reader no way to tell which did what. As a property
/// of the pair the relationship states itself: the pair exists, and optionally
/// it appears in the bar.
public struct PairSetting: Codable, Equatable, Sendable {
    public let pair: String
    public var showsInMenuBar: Bool

    public init(pair: String, showsInMenuBar: Bool) {
        self.pair = pair
        self.showsInMenuBar = showsInMenuBar
    }
}
