import Foundation

/// The time window the panel reports on: it governs the sparkline, the
/// percentage change and the range shown next to each pair.
public enum QuotePeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .day: return "24h"
        case .week: return "7d"
        case .month: return "30d"
        }
    }

    /// Daily closes the window spans.
    public var days: Int {
        switch self {
        case .day: return 2
        case .week: return 7
        case .month: return 30
        }
    }
}
