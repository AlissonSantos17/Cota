import Foundation

public protocol QuoteServiceProtocol {
    func fetchQuotes(pairs: [String]) async throws -> [Quote]
}

public enum QuoteError: LocalizedError, Equatable {
    case invalidURL
    case httpError(Int)
    case invalidResponse
    case invalidValue(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .httpError(let statusCode):
            return "The API returned HTTP error \(statusCode)."
        case .invalidResponse:
            return "The API returned an invalid response."
        case .invalidValue(let field):
            return "The field '\(field)' returned an invalid value."
        }
    }
}

public final class QuoteService: QuoteServiceProtocol {
    private let session: URLSession
    private let baseURL = "https://economia.awesomeapi.com.br/json/last"
    private let maxRetries = 3

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        guard !pairs.isEmpty else { return [] }

        let list = pairs.joined(separator: ",")

        guard let url = URL(string: "\(baseURL)/\(list)") else {
            throw QuoteError.invalidURL
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.httpMethod = "GET"

        var lastError: Error = QuoteError.invalidResponse

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw QuoteError.invalidResponse
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    throw QuoteError.httpError(httpResponse.statusCode)
                }

                let dictionary = try JSONDecoder().decode(
                    [String: Quote].self, from: data
                )

                return pairs.compactMap { pair in
                    let key = pair.replacingOccurrences(of: "-", with: "")
                    return dictionary[key]
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError
    }
}
