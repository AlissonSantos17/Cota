import Foundation

public struct Quote: Identifiable, Decodable {
    public let code: String
    public let codein: String
    public let name: String
    public let bid: Decimal
    public let pctChange: Decimal
    public let createDate: String

    public var id: String {
        "\(code)-\(codein)"
    }

    enum CodingKeys: String, CodingKey {
        case code
        case codein
        case name
        case bid
        case pctChange = "pctChange"
        case createDate = "create_date"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decode(String.self, forKey: .code)
        codein = try container.decode(String.self, forKey: .codein)
        name = try container.decode(String.self, forKey: .name)
        createDate = try container.decode(String.self, forKey: .createDate)

        let bidString = try container.decode(String.self, forKey: .bid)
        let pctChangeString = try container.decode(String.self, forKey: .pctChange)

        guard let bid = Decimal(string: bidString) else {
            throw QuoteError.invalidValue("bid")
        }

        guard let pctChange = Decimal(string: pctChangeString) else {
            throw QuoteError.invalidValue("pctChange")
        }

        self.bid = bid
        self.pctChange = pctChange
    }
}
