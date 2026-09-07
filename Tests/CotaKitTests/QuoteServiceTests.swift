import Foundation
import Testing

@testable import CotaKit

/// MockURLProtocol keeps a process-wide handler. Running these cases in
/// parallel lets one test's JSON land in another's request.
@Suite(.serialized)
struct QuoteServiceTests {
    private func makeService() -> (QuoteService, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = QuoteService(session: session)
        return (service, session)
    }

    @Test func fetchQuotesDecodesValidResponse() async throws {
        let (service, _) = makeService()
        let json = """
            {
                "USDBRL": {
                    "code": "USD",
                    "codein": "BRL",
                    "name": "Dollar/Real",
                    "bid": "5.1234",
                    "pctChange": "-0.42",
                    "create_date": "2026-08-31 10:00:00"
                }
            }
            """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let quotes = try await service.fetchQuotes(pairs: ["USD-BRL"])
        #expect(quotes.count == 1)
        #expect(quotes[0].code == "USD")
        #expect(quotes[0].codein == "BRL")
        #expect(quotes[0].bid == Decimal(string: "5.1234"))
    }

    @Test func fetchQuotesEmptyPairsReturnsEmpty() async throws {
        let (service, _) = makeService()
        let quotes = try await service.fetchQuotes(pairs: [])
        #expect(quotes.isEmpty)
    }

    @Test func fetchQuotesHTTPErrorThrows() async {
        let (service, _) = makeService()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await #expect(throws: QuoteError.self) {
            _ = try await service.fetchQuotes(pairs: ["USD-BRL"])
        }
    }

    /// A 404 is a missing resource, not a blip. Retrying it three times with
    /// backoff held `loading` for ~48s per call and blocked the manual refresh.
    @Test func fetchQuotesDoesNotRetryClientErrors() async {
        let (service, _) = makeService()
        let attempts = AttemptCounter()
        MockURLProtocol.requestHandler = { request in
            attempts.count += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        await #expect(throws: QuoteError.httpError(404)) {
            _ = try await service.fetchQuotes(pairs: ["USD-BRL"])
        }
        #expect(attempts.count == 1)
    }

    private final class AttemptCounter: @unchecked Sendable {
        var count = 0
    }

    @Test func fetchDailyBidsReturnsChronologicalBids() async throws {
        let (service, _) = makeService()
        let json = """
            [
                {"bid": "5.18", "timestamp": "3"},
                {"bid": "5.10", "timestamp": "2"},
                {"bid": "5.00", "timestamp": "1"}
            ]
            """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let bids = try await service.fetchDailyBids(pair: "USD-BRL", days: 15)
        #expect(
            bids == [
                Decimal(string: "5.00")!,
                Decimal(string: "5.10")!,
                Decimal(string: "5.18")!,
            ])
    }

    /// Intraday ticks carry their timestamp so the 24h window can be a window:
    /// a bare list of bids can only ever be "the last N the API gave us".
    @Test func fetchIntradayBidsCarriesTheTimestampOfEachTick() async throws {
        let (service, _) = makeService()
        let json = """
            [
                {"bid": "5.18", "timestamp": "1757260800"},
                {"bid": "5.10", "timestamp": "1757257200"}
            ]
            """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let points = try await service.fetchIntradayBids(pair: "USD-BRL", points: 10)

        #expect(
            points == [
                IntradayPoint(
                    date: Date(timeIntervalSince1970: 1_757_257_200),
                    bid: Decimal(string: "5.10")!
                ),
                IntradayPoint(
                    date: Date(timeIntervalSince1970: 1_757_260_800),
                    bid: Decimal(string: "5.18")!
                ),
            ])
    }
}
