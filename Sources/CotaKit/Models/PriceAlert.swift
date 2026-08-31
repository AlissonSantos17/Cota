import Foundation

public struct PriceAlert: Codable, Identifiable, Equatable {
    public var id: UUID
    public var pair: String
    public var threshold: Decimal
    public var isAbove: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        pair: String,
        threshold: Decimal,
        isAbove: Bool,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.pair = pair
        self.threshold = threshold
        self.isAbove = isAbove
        self.isEnabled = isEnabled
    }

    public var label: String {
        let direction = isAbove ? "above" : "below"
        return "\(pair) \(direction) \(threshold)"
    }
}
