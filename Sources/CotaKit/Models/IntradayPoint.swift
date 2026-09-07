import Foundation

/// One intraday tick, with the time it was quoted.
///
/// The bid alone was enough to draw a line, but not to say what the line
/// covers: "24h" was really "the last 200 ticks we happened to keep", so a
/// tick from two days ago stayed on the chart and anchored the change and the
/// range to itself. The window can only be a window if the points know when
/// they are.
public struct IntradayPoint: Equatable, Sendable {
    public let date: Date
    public let bid: Decimal

    public init(date: Date, bid: Decimal) {
        self.date = date
        self.bid = bid
    }
}
