import Combine
import Foundation
import SwiftUI

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

    /// Whether the last fetch is old enough to present as stale. Recomputed on
    /// a tick because it is a function of elapsed time: nothing else
    /// republishes while a refresh keeps failing.
    @Published public private(set) var stale = false

    /// Recent ticks for the 24h window: seeded from the intraday endpoint on
    /// first load, then extended with each live bid.
    @Published public private(set) var intradayBids: [String: [Decimal]] = [:]

    /// The menu bar keeps the app name until this drops, even if the first
    /// fetch has already landed. It is a launch hold, not a loading flag.
    @Published public private(set) var launchHoldActive = true

    /// 0 is the name, 1 is the quote. The renderer crossfades between them.
    @Published public private(set) var launchReveal: Double = 0

    private let maxHistoryPoints = 30
    private let maxIntradayPoints = 200
    private let service: QuoteServiceProtocol
    public let settings: SettingsStore
    private let launchHold: Duration
    private let launchRevealDuration: Duration

    private var loop: Task<Void, Never>?
    private var staleLoop: Task<Void, Never>?
    private var launchHoldTask: Task<Void, Never>?
    private var launchRevealTask: Task<Void, Never>?
    private var pairsObservation: AnyCancellable?
    private var intervalObservation: AnyCancellable?

    public init(
        service: QuoteServiceProtocol = QuoteService(),
        settings: SettingsStore,
        launchHold: Duration = MenuBarLabel.launchHold,
        launchReveal: Duration = MenuBarLabel.launchReveal
    ) {
        self.service = service
        self.settings = settings
        self.launchHold = launchHold
        self.launchRevealDuration = launchReveal

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

        intervalObservation = settings.$refreshInterval
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartLoop()
            }
    }

    deinit {
        loop?.cancel()
        staleLoop?.cancel()
        launchHoldTask?.cancel()
        launchRevealTask?.cancel()
        pairsObservation?.cancel()
        intervalObservation?.cancel()
    }

    public func start() {
        if launchHoldTask == nil {
            launchHoldTask = Task { [weak self] in
                guard let self else { return }

                do {
                    try await Task.sleep(for: self.launchHold)
                } catch {
                    return
                }

                self.launchHoldActive = false
                self.startRevealIfReady()
            }
        }

        if loop == nil {
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

        if staleLoop == nil {
            staleLoop = Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(15))
                    } catch {
                        break
                    }

                    guard let self else { return }
                    self.refreshStaleness()
                }
            }
        }
    }

    /// The sleep already in flight used the previous interval. Cancel it and
    /// fetch now, so 5m → 30s does not wait out the remaining minutes.
    private func restartLoop() {
        guard loop != nil else { return }
        loop?.cancel()
        loop = nil
        start()
    }

    private func refreshStaleness() {
        let current = isStale()
        if current != stale {
            stale = current
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
        staleLoop?.cancel()
        staleLoop = nil
        launchHoldTask?.cancel()
        launchHoldTask = nil
        launchRevealTask?.cancel()
        launchRevealTask = nil
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
            stale = false
            await updatePriceHistory(with: newQuotes)
            NotificationService.shared.checkAlerts(settings.alerts, against: quotes)
            startRevealIfReady()
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updatePriceHistory(with quotes: [Quote]) async {
        let activeIDs = Set(quotes.map(\.id))
        priceHistory = priceHistory.filter { activeIDs.contains($0.key) }
        intradayBids = intradayBids.filter { activeIDs.contains($0.key) }

        for quote in quotes {
            if priceHistory[quote.id] == nil {
                priceHistory[quote.id] =
                    (try? await service.fetchDailyBids(
                        pair: quote.id,
                        days: maxHistoryPoints
                    )) ?? []
            }

            if intradayBids[quote.id] == nil {
                intradayBids[quote.id] =
                    (try? await service.fetchIntradayBids(
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
        Currency.named(code).symbol ?? String(code.prefix(1))
    }

    public func flag(_ code: String) -> String {
        Currency.named(code).flag ?? Currency.named(code).symbol ?? code
    }

    // MARK: - Menu bar

    /// The pairs the menu bar labels, in the order the user arranged them, with
    /// the change measured over the same period the panel is showing — two
    /// surfaces of one app disagreeing about "the change" is worse than either
    /// answer alone.
    public var menuBarQuotes: [MenuBarQuote] {
        settings.orderedMenuBarPairs.compactMap { pair in
            guard let quote = quotes.first(where: { $0.id == pair }) else {
                return nil
            }

            return MenuBarQuote(
                pair: pair,
                bid: quote.bid,
                change: change(for: pair, period: settings.period) ?? quote.pctChange
            )
        }
    }
}

extension QuoteStore {
    /// The fade starts only when the name has been shown and there is a
    /// quote to fade to. Either arriving first just waits for the other.
    private func startRevealIfReady() {
        guard !launchHoldActive, launchReveal < 1, !menuBarQuotes.isEmpty else {
            return
        }
        guard launchRevealTask == nil else { return }

        launchRevealTask = Task { [weak self] in
            guard let self else { return }

            let start = ContinuousClock.now
            while !Task.isCancelled {
                let elapsed = start.duration(to: .now)
                self.launchReveal = min(
                    1, Self.progress(elapsed: elapsed, of: self.launchRevealDuration))
                if self.launchReveal >= 1 {
                    break
                }

                do {
                    try await Task.sleep(for: .milliseconds(16))
                } catch {
                    return
                }
            }

            self.launchReveal = 1
        }
    }

    private static func progress(elapsed: Duration, of total: Duration) -> Double {
        let elapsedSeconds =
            Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        let totalSeconds =
            Double(total.components.seconds)
            + Double(total.components.attoseconds) / 1e18
        guard totalSeconds > 0 else { return 1 }
        return elapsedSeconds / totalSeconds
    }
}
