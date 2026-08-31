import Foundation

struct Cotacao: Identifiable, Decodable {
    let code: String
    let codein: String
    let name: String
    let bid: Decimal
    let pctChange: Decimal
    let createDate: String

    var id: String {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        code = try container.decode(String.self, forKey: .code)
        codein = try container.decode(String.self, forKey: .codein)
        name = try container.decode(String.self, forKey: .name)
        createDate = try container.decode(String.self, forKey: .createDate)

        let bidString = try container.decode(String.self, forKey: .bid)
        let pctChangeString = try container.decode(String.self, forKey: .pctChange)

        guard let bid = Decimal(string: bidString) else {
            throw CotacaoError.invalidValue("bid")
        }

        guard let pctChange = Decimal(string: pctChangeString) else {
            throw CotacaoError.invalidValue("pctChange")
        }

        self.bid = bid
        self.pctChange = pctChange
    }
}
