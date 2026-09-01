import Foundation

public protocol QuoteServiceProtocol {
    func fetchQuotes(pairs: [String]) async throws -> [Quote]
    func fetchDailyBids(pair: String, days: Int) async throws -> [Decimal]
    func fetchIntradayBids(pair: String, points: Int) async throws -> [Decimal]
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
    private let lastURL = "https://economia.awesomeapi.com.br/json/last"
    private let dailyURL = "https://economia.awesomeapi.com.br/json/daily"
    private let intradayURL = "https://economia.awesomeapi.com.br/json"
    private let maxRetries = 3

    /// The API caps this endpoint at 100 records no matter what is asked for.
    public static let maxIntradayPoints = 100

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        guard !pairs.isEmpty else { return [] }

        let list = pairs.joined(separator: ",")

        guard let url = URL(string: "\(lastURL)/\(list)") else {
            throw QuoteError.invalidURL
        }

        let data = try await fetchData(from: url)
        let dictionary = try JSONDecoder().decode([String: Quote].self, from: data)

        return pairs.compactMap { pair in
            let key = pair.replacingOccurrences(of: "-", with: "")
            return dictionary[key]
        }
    }

    public func fetchDailyBids(pair: String, days: Int) async throws -> [Decimal] {
        guard !pair.isEmpty, days > 0 else {
            return []
        }

        guard let url = URL(string: "\(dailyURL)/\(pair)/\(days)") else {
            throw QuoteError.invalidURL
        }

        let data = try await fetchData(from: url)
        let points = try JSONDecoder().decode([BidPoint].self, from: data)
        return points.reversed().map(\.bid)
    }

    /// Recent ticks, roughly one every 45 seconds while the market is open.
    /// A hundred of them cover about 80 minutes of trading — enough to draw
    /// the 24h window on launch instead of a flat line.
    public func fetchIntradayBids(pair: String, points: Int) async throws -> [Decimal] {
        guard !pair.isEmpty, points > 0 else {
            return []
        }

        let capped = min(points, Self.maxIntradayPoints)

        guard let url = URL(string: "\(intradayURL)/\(pair)/\(capped)") else {
            throw QuoteError.invalidURL
        }

        let data = try await fetchData(from: url)
        let points = try JSONDecoder().decode([BidPoint].self, from: data)
        return points.reversed().map(\.bid)
    }

    private func fetchData(from url: URL) async throws -> Data {
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

                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError
    }
}

/// One record from either the daily or the intraday endpoint.
private struct BidPoint: Decodable {
    let bid: Decimal

    enum CodingKeys: String, CodingKey {
        case bid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bidString = try container.decode(String.self, forKey: .bid)
        guard let bid = Decimal(string: bidString) else {
            throw QuoteError.invalidValue("bid")
        }
        self.bid = bid
    }
}
