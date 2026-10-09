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

    /// Pairs the last successful fetch was asked for and the API omitted.
    /// Distinct from a failed fetch: the other quotes are on screen.
    @Published public private(set) var unavailablePairs: [String] = []

    /// Whether the last fetch is old enough to present as stale. Recomputed on
    /// a tick because it is a function of elapsed time: nothing else
    /// republishes while a refresh keeps failing.
    @Published public private(set) var stale = false

    /// Recent ticks for the 24h window: seeded from the intraday endpoint on
    /// first load, then extended with each live bid and pruned to the window.
    @Published public private(set) var intradayBids: [String: [IntradayPoint]] = [:]

    /// The menu bar keeps the app name until this drops, even if the first
    /// fetch has already landed. It is a launch hold, not a loading flag.
    @Published public private(set) var launchHoldActive = true

    /// 0 is the name, 1 is the quote. The renderer crossfades between them.
    @Published public private(set) var launchReveal: Double = 0

    /// How soon to ask again after consecutive failures. At login the first
    /// fetch runs before the network is up; waiting out the whole interval
    /// after it left the menu bar on the app name for minutes. Once the steps
    /// run out the loop is back on the interval.
    public nonisolated static let defaultRetryDelays: [Duration] = [
        .seconds(5), .seconds(10), .seconds(20), .seconds(40),
    ]

    private let maxHistoryPoints = 30
    /// A cap on memory, not on the window: the window is `intradayWindow`.
    private let maxIntradayPoints = 200
    private let intradayWindow: TimeInterval = 24 * 3600
    private let service: QuoteServiceProtocol
    public let settings: SettingsStore
    private let launchHold: Duration
    private let launchRevealDuration: Duration
    private let retryDelays: [Duration]
    private let now: @Sendable () -> Date

    /// The day each pair's daily closes were fetched for. Closes only change
    /// when the day does, so this is the condition to ask again — "nothing
    /// stored yet" froze the 7d and 30d windows on the day of launch.
    private var dailyHistoryDay: [String: Date] = [:]

    private var loop: Task<Void, Never>?
    private var staleLoop: Task<Void, Never>?
    private var launchHoldTask: Task<Void, Never>?
    private var launchRevealTask: Task<Void, Never>?
    private var pairsObservation: AnyCancellable?
    private var intervalObservation: AnyCancellable?
    private var menuBarObservation: AnyCancellable?
    /// Bumped when the interval changes. The wait resumes instead of relying
    /// on cancelling a child `Task.sleep`, which CI's older runtime sometimes
    /// delivered after the test timeout.
    private var loopGeneration = 0
    private var intervalWait: CheckedContinuation<Void, Never>?
    /// Set when a refresh is asked for while one is in flight, so the fetch
    /// that is running answers for it instead of the request being lost.
    private var pendingRefresh = false
    /// The pairs the last fetch covers, as a set: what changes a fetch, as
    /// opposed to the order, which only changes the list.
    private var observedPairs: Set<String> = []
    /// Failures since the last fetch that came back, counting only the kind a
    /// retry can fix. Picks the step of `retryDelays` the loop waits for.
    private var consecutiveFailures = 0

    public init(
        service: QuoteServiceProtocol = QuoteService(),
        settings: SettingsStore,
        launchHold: Duration = MenuBarLabel.launchHold,
        launchReveal: Duration = MenuBarLabel.launchReveal,
        retryDelays: [Duration] = QuoteStore.defaultRetryDelays,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.settings = settings
        self.launchHold = launchHold
        self.launchRevealDuration = launchReveal
        self.retryDelays = retryDelays
        self.now = now

        observedPairs = Set(settings.pairs)

        pairsObservation = settings.$pairs
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newPairs in
                guard let self else { return }
                Task { @MainActor in
                    // Order is a property of the list, not of what has to be
                    // asked for. Comparing the arrays made every drag in the
                    // pairs list cost a round trip to the API.
                    let updated = Set(newPairs)
                    let membershipChanged = updated != self.observedPairs
                    self.observedPairs = updated

                    self.quotes = self.quotes.filter { newPairs.contains($0.id) }
                    self.unavailablePairs = self.unavailablePairs.filter {
                        newPairs.contains($0)
                    }

                    guard membershipChanged else { return }
                    await self.refresh()
                }
            }

        intervalObservation = settings.$refreshInterval
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.restartLoop()
            }

        // pairSettings can change without `pairs` changing — ticking the
        // first menu bar pair is the case. The hold and refresh already
        // asked; this is the third arrival startRevealIfReady waits for.
        menuBarObservation = settings.$pairSettings
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.startRevealIfReady()
                }
            }
    }

    /// Only the tasks. `AnyCancellable` cancels its subscription when it is
    /// deallocated, which is precisely now, so cancelling the observations here
    /// was work already done — and reaching for them from a `deinit`, which is
    /// not actor-isolated, is an error in the Swift 6 language mode.
    deinit {
        loop?.cancel()
        staleLoop?.cancel()
        launchHoldTask?.cancel()
        launchRevealTask?.cancel()
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
                await self?.runFetchLoop()
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

    /// Fetches, then waits out the interval. An interval change resumes the
    /// wait so the next fetch runs now — without cancelling the loop itself.
    private func runFetchLoop() async {
        while !Task.isCancelled {
            let generation = loopGeneration
            await refresh()

            if Task.isCancelled { break }
            if loopGeneration != generation { continue }

            await sleepForInterval(generation: generation, delay: nextWait())
        }
    }

    /// The interval, unless the last fetches failed in a way worth asking
    /// again about sooner. A step is never longer than the interval: a failure
    /// should not take longer to recover from than a success takes to refresh.
    private func nextWait() -> Duration {
        let interval = Duration.seconds(settings.refreshInterval)
        guard consecutiveFailures > 0, consecutiveFailures <= retryDelays.count else {
            return interval
        }
        return min(retryDelays[consecutiveFailures - 1], interval)
    }

    private func sleepForInterval(generation: Int, delay: Duration) async {
        await withCheckedContinuation { continuation in
            guard loopGeneration == generation else {
                continuation.resume()
                return
            }
            intervalWait = continuation
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                self.finishIntervalWait(generation: generation)
            }
        }
    }

    private func finishIntervalWait(generation: Int) {
        guard loopGeneration == generation, let wait = intervalWait else { return }
        intervalWait = nil
        wait.resume()
    }

    /// The sleep already in flight used the previous interval. Resume it so
    /// 5m → 30s does not wait out the remaining minutes.
    private func restartLoop() {
        guard loop != nil else { return }
        loopGeneration += 1
        if let wait = intervalWait {
            intervalWait = nil
            wait.resume()
        }
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
        // Bumped, not just resumed: the `Task.sleep` this loop left behind
        // still carries the old generation, and without a bump it was still
        // valid when it came due — waking the wait a *later* loop was sitting
        // in and pulling its next fetch forward.
        loopGeneration += 1
        loop?.cancel()
        loop = nil
        if let wait = intervalWait {
            intervalWait = nil
            wait.resume()
        }
        staleLoop?.cancel()
        staleLoop = nil
        launchHoldTask?.cancel()
        launchHoldTask = nil
        launchRevealTask?.cancel()
        launchRevealTask = nil
    }

    /// Coalesced rather than dropped: the pairs observation asks for a refresh
    /// the moment a pair is added, which is exactly when a fetch is most likely
    /// to be in flight. Returning early there left the new pair unanswered
    /// until the next tick of the loop.
    public func refresh() async {
        guard !loading else {
            pendingRefresh = true
            return
        }

        loading = true

        defer {
            loading = false
        }

        repeat {
            pendingRefresh = false
            await performFetch()
        } while pendingRefresh && !Task.isCancelled
    }

    private func performFetch() async {
        error = nil

        // The pairs this response answers for. Reading `settings.pairs` again
        // after the await measured the response against a list it was never
        // asked for, which is how a pair added mid-flight came back "missing".
        let requested = settings.pairs

        do {
            let newQuotes = try await service.fetchQuotes(pairs: requested)
            quotes = newQuotes
            let returned = Set(newQuotes.map(\.id))
            let current = Set(settings.pairs)
            unavailablePairs = requested.filter {
                !returned.contains($0) && current.contains($0)
            }
            lastUpdate = .now
            hasLoaded = true
            stale = false
            consecutiveFailures = 0
            await updatePriceHistory(with: newQuotes)
            NotificationService.shared.checkAlerts(settings.alerts, against: quotes)
            startRevealIfReady()
        } catch {
            // Stopping cancels the request in flight. That is not the API
            // failing: nothing to show, nothing to retry.
            guard !Self.isCancellation(error) else { return }

            // `quotes` is left alone: the last good values stay on screen,
            // and the error and the staleness rule say they are old.
            self.error = error.localizedDescription
            consecutiveFailures = Self.isTransient(error) ? consecutiveFailures + 1 : 0
        }
    }

    /// URLSession reports a cancelled task as `URLError.cancelled`, not as
    /// `CancellationError`.
    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// Transport failures and server errors can clear up in seconds. A 4xx or
    /// a body that does not decode will not, and asking again soon only spends
    /// the API's rate limit.
    private static func isTransient(_ error: Error) -> Bool {
        switch error {
        case is URLError:
            return true
        case QuoteError.httpError(let status):
            return (500..<600).contains(status)
        default:
            return false
        }
    }
}

/// What one pair's history fetch came back with. Either half may be nil: a
/// failed leg has to stay unset so the next refresh asks again.
private struct HistoryFetch: Sendable {
    let id: String
    let daily: [Decimal]?
    let intra: [IntradayPoint]?
}

extension QuoteStore {
    private func updatePriceHistory(with quotes: [Quote]) async {
        let activeIDs = Set(quotes.map(\.id))
        priceHistory = priceHistory.filter { activeIDs.contains($0.key) }
        intradayBids = intradayBids.filter { activeIDs.contains($0.key) }
        dailyHistoryDay = dailyHistoryDay.filter { activeIDs.contains($0.key) }

        let service = self.service
        let maxHistory = maxHistoryPoints
        let maxIntraday = QuoteService.maxIntradayPoints
        let today = Calendar.current.startOfDay(for: now())

        await withTaskGroup(of: HistoryFetch.self) { group in
            for quote in quotes {
                let id = quote.id
                let needsDaily = priceHistory[id] == nil || dailyHistoryDay[id] != today
                let needsIntraday = intradayBids[id] == nil
                guard needsDaily || needsIntraday else { continue }

                group.addTask {
                    let daily: [Decimal]? =
                        needsDaily
                        ? try? await service.fetchDailyBids(pair: id, days: maxHistory)
                        : nil
                    let intra: [IntradayPoint]? =
                        needsIntraday
                        ? try? await service.fetchIntradayBids(pair: id, points: maxIntraday)
                        : nil
                    return HistoryFetch(id: id, daily: daily, intra: intra)
                }
            }

            for await result in group {
                if let daily = result.daily {
                    priceHistory[result.id] = daily
                    // Only on success: a failed fetch has to be retried, and
                    // stamping it would hold the stale closes for the whole day.
                    dailyHistoryDay[result.id] = today
                }
                if let intra = result.intra {
                    intradayBids[result.id] = intra
                }
            }
        }

        // Live ticks belong on a seeded series. Appending after a failed
        // seed would write a non-nil value and block the retry.
        for quote in quotes where intradayBids[quote.id] != nil {
            appendIntradayBid(quote.bid, to: quote.id)
        }
    }

    private func appendIntradayBid(_ bid: Decimal, to pairID: String) {
        var points = intradayBids[pairID, default: []]
        let timestamp = now()

        if points.last?.bid != bid {
            points.append(IntradayPoint(date: timestamp, bid: bid))
        }

        // Pruned on every tick, not only on append: a pair whose bid has not
        // moved all day still has to shed yesterday's points.
        let cutoff = timestamp.addingTimeInterval(-intradayWindow)
        points.removeAll { $0.date < cutoff }

        if points.count > maxIntradayPoints {
            points.removeFirst(points.count - maxIntradayPoints)
        }

        intradayBids[pairID] = points
    }

    // MARK: - Period derived values

    /// The series a sparkline should draw for the given window.
    ///
    /// The 24h window is the previous daily close followed by the bids seen in
    /// this session; the longer windows are daily closes with the live bid
    /// appended as the current point.
    public func series(for pairID: String, period: QuotePeriod) -> [Decimal] {
        let daily = priceHistory[pairID] ?? []
        let intraday = (intradayBids[pairID] ?? []).map(\.bid)

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
