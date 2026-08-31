import Foundation

protocol CotacaoServiceProtocol {
    func buscarCotacoes(pares: [String]) async throws -> [Cotacao]
}

enum CotacaoError: LocalizedError {
    case urlInvalida
    case httpError(Int)
    case respostaInvalida
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .urlInvalida:
            return "A URL da API é inválida."
        case .httpError(let statusCode):
            return "A API retornou o erro HTTP \(statusCode)."
        case .respostaInvalida:
            return "A API retornou uma resposta inválida."
        case .invalidValue(let field):
            return "O campo '\(field)' retornou um valor inválido."
        }
    }
}

final class CotacaoService: CotacaoServiceProtocol {
    private let session: URLSession
    private let baseURL = "https://economia.awesomeapi.com.br/json/last"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func buscarCotacoes(pares: [String]) async throws -> [Cotacao] {
        guard !pares.isEmpty else {
            return []
        }

        let lista = pares.joined(separator: ",")

        guard let url = URL(string: "\(baseURL)/\(lista)") else {
            throw CotacaoError.urlInvalida
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CotacaoError.respostaInvalida
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw CotacaoError.httpError(httpResponse.statusCode)
        }

        let dictionary = try JSONDecoder().decode(
            [String: Cotacao].self,
            from: data
        )

        return pares.compactMap { par in
            let key = par.replacingOccurrences(of: "-", with: "")
            return dictionary[key]
        }
    }
}
