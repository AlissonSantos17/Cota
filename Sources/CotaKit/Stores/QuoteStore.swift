import Foundation
import SwiftUI
import Combine

@MainActor
public final class QuoteStore: ObservableObject {
    @Published public private(set) var quotes: [Quote] = []
    @Published public private(set) var error: String?
    @Published public private(set) var loading = false
    @Published public private(set) var lastUpdate: Date?

    /// Whether a fetch has ever succeeded. Drives the skeleton on first load,
    /// which is not the same state as "loading with values already on screen".
    @Published public private(set) var hasLoaded = false
    /// Daily closes per pair, oldest first.
    @Published public private(set) var priceHistory: [String: [Decimal]] = [:]

    /// Recent ticks for the 24h window: seeded from the intraday endpoint on
    /// first load, then extended with each live bid.
    @Published public private(set) var intradayBids: [String: [Decimal]] = [:]

    private let maxHistoryPoints = 30
    private let maxIntradayPoints = 200
    private let service: QuoteServiceProtocol
    public let settings: SettingsStore

    private var loop: Task<Void, Never>?
    private var pairsObservation: AnyCancellable?

    public init(
        service: QuoteServiceProtocol = QuoteService(),
        settings: SettingsStore
    ) {
        self.service = service
        self.settings = settings

        pairsObservation = settings.$pairs
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newPairs in
                guard let self else { return }
                Task { @MainActor in
                    self.quotes = self.quotes.filter { newPairs.contains($0.id) }
                    await self.refresh()
                }
            }
    }

    deinit {
        loop?.cancel()
        pairsObservation?.cancel()
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

    /// A quote older than three refresh cycles is presented as stale: one that
    /// looks fresh at 40 minutes is worse than no quote at all.
    public func isStale(at date: Date = .now) -> Bool {
        guard let lastUpdate else { return false }
        return date.timeIntervalSince(lastUpdate) > Double(settings.refreshInterval) * 3
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
            hasLoaded = true
            await updatePriceHistory(with: newQuotes)
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

        return "\(flag(first.code)) → \(flag(first.codein)) \(value)"
    }

    private func updatePriceHistory(with quotes: [Quote]) async {
        let activeIDs = Set(quotes.map(\.id))
        priceHistory = priceHistory.filter { activeIDs.contains($0.key) }
        intradayBids = intradayBids.filter { activeIDs.contains($0.key) }

        for quote in quotes {
            if priceHistory[quote.id] == nil {
                priceHistory[quote.id] = (try? await service.fetchDailyBids(
                    pair: quote.id,
                    days: maxHistoryPoints
                )) ?? []
            }

            if intradayBids[quote.id] == nil {
                intradayBids[quote.id] = (try? await service.fetchIntradayBids(
                    pair: quote.id,
                    points: QuoteService.maxIntradayPoints
                )) ?? []
            }

            appendIntradayBid(quote.bid, to: quote.id)
        }
    }

    private func appendIntradayBid(_ bid: Decimal, to pairID: String) {
        var bids = intradayBids[pairID, default: []]

        if bids.last == bid {
            return
        }

        bids.append(bid)
        if bids.count > maxIntradayPoints {
            bids.removeFirst(bids.count - maxIntradayPoints)
        }

        intradayBids[pairID] = bids
    }

    // MARK: - Period derived values

    /// The series a sparkline should draw for the given window.
    ///
    /// The 24h window is the previous daily close followed by the bids seen in
    /// this session; the longer windows are daily closes with the live bid
    /// appended as the current point.
    public func series(for pairID: String, period: QuotePeriod) -> [Decimal] {
        let daily = priceHistory[pairID] ?? []
        let intraday = intradayBids[pairID] ?? []

        switch period {
        case .day:
            guard let previousClose = daily.dropLast().last else {
                return intraday
            }
            return [previousClose] + intraday

        case .week, .month:
            var series = Array(daily.suffix(period.days))
            if let live = intraday.last, series.last != live {
                series.append(live)
            }
            return series
        }
    }

    /// Percentage change across the window, measured from its opening value.
    public func change(for pairID: String, period: QuotePeriod) -> Decimal? {
        let series = series(for: pairID, period: period)

        guard let open = series.first, let last = series.last, open != 0 else {
            return nil
        }

        return (last - open) / open * 100
    }

    /// Lowest and highest bid within the window.
    public func range(for pairID: String, period: QuotePeriod) -> (low: Decimal, high: Decimal)? {
        let series = series(for: pairID, period: period)

        guard let low = series.min(), let high = series.max() else {
            return nil
        }

        return (low, high)
    }

    /// Currency glyph for the row badge. Flag emoji render differently across
    /// macOS versions and mix optical sizes with the text symbols used for
    /// crypto, so the panel uses one typographic set instead.
    public func symbol(_ code: String) -> String {
        switch code {
        case "EUR": return "\u{20AC}"
        case "USD", "CAD", "AUD", "ARS": return "$"
        case "GBP": return "\u{A3}"
        case "BRL": return "R$"
        case "JPY", "CNY": return "\u{A5}"
        case "CHF": return "\u{20A3}"
        case "BTC": return "\u{20BF}"
        case "ETH": return "\u{39E}"
        case "XRP": return "\u{2715}"
        default: return String(code.prefix(1))
        }
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
