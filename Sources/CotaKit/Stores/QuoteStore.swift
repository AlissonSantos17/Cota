import Foundation
import SwiftUI

@MainActor
public final class QuoteStore: ObservableObject {
    @Published public private(set) var quotes: [Quote] = []
    @Published public private(set) var error: String?
    @Published public private(set) var loading = false
    @Published public private(set) var lastUpdate: Date?
    @Published public private(set) var priceHistory: [String: [Decimal]] = [:]

    private let maxHistoryPoints = 20
    private let service: QuoteServiceProtocol
    public let settings: SettingsStore

    private var loop: Task<Void, Never>?

    public init(
        service: QuoteServiceProtocol = QuoteService(),
        settings: SettingsStore
    ) {
        self.service = service
        self.settings = settings
    }

    deinit {
        loop?.cancel()
    }

    public func start() {
        guard loop == nil else {
            return
        }

        loop = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                await self.refresh()

                do {
                    try await Task.sleep(for: .seconds(self.settings.refreshInterval))
                } catch {
                    break
                }
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    public func refresh() async {
        guard !loading else {
            return
        }

        loading = true
        error = nil

        defer {
            loading = false
        }

        do {
            let newQuotes = try await service.fetchQuotes(pairs: settings.pairs)
            quotes = newQuotes
            lastUpdate = .now
            for quote in quotes {
                var history = priceHistory[quote.id, default: []]
                history.append(quote.bid)
                if history.count > maxHistoryPoints {
                    history.removeFirst(history.count - maxHistoryPoints)
                }
                priceHistory[quote.id] = history
            }
            NotificationService.shared.checkAlerts(settings.alerts, against: quotes)
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }

    public var menuBarSummary: String {
        guard let first = quotes.first else {
            return "Cota"
        }

        let value = first.bid.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Locale(identifier: "pt_BR"))
        )

        return "\(flag(first.code)) \(first.code) \(value)"
    }

    public func flag(_ code: String) -> String {
        switch code {
        case "EUR": return "🇪🇺"
        case "USD": return "🇺🇸"
        case "GBP": return "🇬🇧"
        case "BRL": return "🇧🇷"
        case "ARS": return "🇦🇷"
        case "BTC": return "₿"
        case "ETH": return "Ξ"
        case "XRP": return "✕"
        default: return code
        }
    }
}
