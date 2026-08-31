# Cota Improvements & Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve the Cota menu bar app from a static quote viewer into a configurable, testable, accessible app with alerts, sparklines, and user preferences.

**Architecture:** Extract all non-UI code into a `CotaKit` library target for testability. Add a `SettingsStore` backed by `UserDefaults` for persisting user preferences (pairs, interval, alerts, launch at login). Use `UNUserNotificationCenter` for price alerts. Accumulate price history in-memory for sparklines, seeded from the AwesomeAPI daily endpoint.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 13+, SPM, ServiceManagement (launch at login), UserNotifications (alerts), AppKit (clipboard, keyboard shortcuts)

**Spec:** Conversation context — no external spec document.

## Global Constraints

- macOS 13+ minimum deployment target
- No external dependencies — all features use system frameworks only
- SPM-based project (no Xcode project file)
- All code in English
- Executable name remains `Cota`

---

### Task 1: Extract CotaKit Library Target for Testability

**Files:**
- Modify: `Package.swift`
- Move: `Sources/Cota/Models/Quote.swift` → `Sources/CotaKit/Models/Quote.swift`
- Move: `Sources/Cota/Services/QuoteService.swift` → `Sources/CotaKit/Services/QuoteService.swift`
- Move: `Sources/Cota/Stores/QuoteStore.swift` → `Sources/CotaKit/Stores/QuoteStore.swift`
- Modify: `Sources/Cota/CotaApp.swift` (add `import CotaKit`)
- Modify: `Sources/Cota/Views/PanelView.swift` (add `import CotaKit`)

**Interfaces:**
- Consumes: nothing (first task)
- Produces: `CotaKit` module exporting `Quote`, `QuoteError`, `QuoteServiceProtocol`, `QuoteService`, `QuoteStore`

- [ ] **Step 1: Create CotaKit directory structure**

```bash
mkdir -p Sources/CotaKit/Models Sources/CotaKit/Services Sources/CotaKit/Stores
```

- [ ] **Step 2: Move model, service, and store files to CotaKit**

```bash
mv Sources/Cota/Models/Quote.swift Sources/CotaKit/Models/Quote.swift
mv Sources/Cota/Services/QuoteService.swift Sources/CotaKit/Services/QuoteService.swift
mv Sources/Cota/Stores/QuoteStore.swift Sources/CotaKit/Stores/QuoteStore.swift
rmdir Sources/Cota/Models Sources/Cota/Services Sources/Cota/Stores
```

- [ ] **Step 3: Update Package.swift with library target**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cota",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Cota",
            targets: ["Cota"]
        )
    ],
    targets: [
        .target(
            name: "CotaKit"
        ),
        .executableTarget(
            name: "Cota",
            dependencies: ["CotaKit"]
        ),
        .testTarget(
            name: "CotaKitTests",
            dependencies: ["CotaKit"]
        )
    ]
)
```

- [ ] **Step 4: Add `import CotaKit` to app files**

In `Sources/Cota/CotaApp.swift`, add `import CotaKit` after `import SwiftUI`.

In `Sources/Cota/Views/PanelView.swift`, add `import CotaKit` after `import AppKit`.

- [ ] **Step 5: Make CotaKit types public**

In `Quote.swift`: change `struct Quote` to `public struct Quote`, make all properties `public`, make `init(from:)` public, and make `CodingKeys` internal (it can stay private).

In `QuoteService.swift`: make `QuoteServiceProtocol` public, `QuoteError` public with public `errorDescription`, `QuoteService` public with public `init` and `fetchQuotes`.

In `QuoteStore.swift`: make `QuoteStore` public, all `@Published` properties public, `pairs` public, `init` public, and all public methods (`start`, `stop`, `refresh`, `flag`, `menuBarSummary`).

- [ ] **Step 6: Build and verify**

```bash
swift build
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: extract CotaKit library target for testability"
```

---

### Task 2: Unit Tests for QuoteService and QuoteStore

**Files:**
- Create: `Tests/CotaKitTests/MockURLProtocol.swift`
- Create: `Tests/CotaKitTests/QuoteServiceTests.swift`
- Create: `Tests/CotaKitTests/QuoteStoreTests.swift`

**Interfaces:**
- Consumes: `CotaKit` module (Task 1) — `Quote`, `QuoteService`, `QuoteServiceProtocol`, `QuoteStore`, `QuoteError`
- Produces: test suite covering service decoding, error handling, and store state management

- [ ] **Step 1: Create MockURLProtocol for intercepting network requests**

```swift
// Tests/CotaKitTests/MockURLProtocol.swift
import Foundation

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
```

- [ ] **Step 2: Write QuoteService tests**

```swift
// Tests/CotaKitTests/QuoteServiceTests.swift
import XCTest
@testable import CotaKit

final class QuoteServiceTests: XCTestCase {
    private var session: URLSession!
    private var service: QuoteService!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = QuoteService(session: session)
    }

    func testFetchQuotesDecodesValidResponse() async throws {
        let json = """
        {
            "USDBRL": {
                "code": "USD",
                "codein": "BRL",
                "name": "Dólar Americano/Real Brasileiro",
                "bid": "5.1234",
                "pctChange": "-0.42",
                "create_date": "2026-08-31 10:00:00",
                "pctChange": "-0.42"
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
        XCTAssertEqual(quotes.count, 1)
        XCTAssertEqual(quotes[0].code, "USD")
        XCTAssertEqual(quotes[0].codein, "BRL")
        XCTAssertEqual(quotes[0].bid, Decimal(string: "5.1234"))
    }

    func testFetchQuotesEmptyPairsReturnsEmpty() async throws {
        let quotes = try await service.fetchQuotes(pairs: [])
        XCTAssertTrue(quotes.isEmpty)
    }

    func testFetchQuotesHTTPErrorThrows() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await service.fetchQuotes(pairs: ["USD-BRL"])
            XCTFail("Expected error")
        } catch let error as QuoteError {
            if case .httpError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
}
```

- [ ] **Step 3: Write QuoteStore tests**

```swift
// Tests/CotaKitTests/QuoteStoreTests.swift
import XCTest
@testable import CotaKit

final class MockQuoteService: QuoteServiceProtocol {
    var result: Result<[Quote], Error> = .success([])

    func fetchQuotes(pairs: [String]) async throws -> [Quote] {
        try result.get()
    }
}

@MainActor
final class QuoteStoreTests: XCTestCase {
    private var mockService: MockQuoteService!
    private var store: QuoteStore!

    override func setUp() {
        mockService = MockQuoteService()
        store = QuoteStore(service: mockService)
    }

    func testRefreshUpdatesQuotes() async {
        let json = """
        {
            "code": "USD", "codein": "BRL",
            "name": "Dollar", "bid": "5.00",
            "pctChange": "1.5", "create_date": "2026-08-31"
        }
        """.data(using: .utf8)!

        let quote = try! JSONDecoder().decode(Quote.self, from: json)
        mockService.result = .success([quote])

        await store.refresh()

        XCTAssertEqual(store.quotes.count, 1)
        XCTAssertEqual(store.quotes[0].code, "USD")
        XCTAssertNil(store.error)
        XCTAssertNotNil(store.lastUpdate)
    }

    func testRefreshSetsErrorOnFailure() async {
        mockService.result = .failure(QuoteError.invalidResponse)

        await store.refresh()

        XCTAssertTrue(store.quotes.isEmpty)
        XCTAssertNotNil(store.error)
    }

    func testMenuBarSummaryDefaultWhenEmpty() {
        XCTAssertEqual(store.menuBarSummary, "Quotes")
    }

    func testFlagReturnsCorrectEmoji() {
        XCTAssertEqual(store.flag("USD"), "🇺🇸")
        XCTAssertEqual(store.flag("EUR"), "🇪🇺")
        XCTAssertEqual(store.flag("BTC"), "₿")
        XCTAssertEqual(store.flag("XYZ"), "XYZ")
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: add unit tests for QuoteService and QuoteStore"
```

---

### Task 3: Retry with Exponential Backoff

**Files:**
- Modify: `Sources/CotaKit/Services/QuoteService.swift`
- Modify: `Tests/CotaKitTests/QuoteServiceTests.swift`

**Interfaces:**
- Consumes: `QuoteService.fetchQuotes(pairs:)` from Task 1
- Produces: same `fetchQuotes(pairs:)` interface, now with internal retry logic (3 attempts, 1s/2s/4s delays)

- [ ] **Step 1: Write failing test for retry behavior**

Add to `QuoteServiceTests.swift`:

```swift
func testFetchQuotesRetriesOnTransientError() async throws {
    var attempts = 0
    let json = """
    {
        "USDBRL": {
            "code": "USD", "codein": "BRL",
            "name": "Dollar", "bid": "5.00",
            "pctChange": "0.5", "create_date": "2026-08-31"
        }
    }
    """

    MockURLProtocol.requestHandler = { request in
        attempts += 1
        if attempts < 3 {
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500,
                httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: nil
        )!
        return (response, Data(json.utf8))
    }

    let quotes = try await service.fetchQuotes(pairs: ["USD-BRL"])
    XCTAssertEqual(quotes.count, 1)
    XCTAssertEqual(attempts, 3)
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter testFetchQuotesRetriesOnTransientError
```

Expected: FAIL (currently no retry logic)

- [ ] **Step 3: Add retry logic to QuoteService**

In `QuoteService.swift`, replace the `fetchQuotes` method body with retry wrapper:

```swift
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
```

Add `private let maxRetries = 3` property to `QuoteService`.

- [ ] **Step 4: Run tests**

```bash
swift test
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add retry with exponential backoff to QuoteService"
```

---

### Task 4: Settings Store with UserDefaults Persistence

**Files:**
- Create: `Sources/CotaKit/Stores/SettingsStore.swift`
- Create: `Tests/CotaKitTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces: `SettingsStore` — `ObservableObject` with published properties:
  - `pairs: [String]` (get/set, persisted)
  - `refreshInterval: Int` (seconds, get/set, persisted)
  - `launchAtLogin: Bool` (get/set, persisted + SMAppService)
  - `alerts: [PriceAlert]` (get/set, persisted)

- [ ] **Step 1: Create PriceAlert model**

```swift
// Sources/CotaKit/Models/PriceAlert.swift
import Foundation

public struct PriceAlert: Codable, Identifiable, Equatable {
    public var id: UUID
    public var pair: String
    public var threshold: Decimal
    public var isAbove: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        pair: String,
        threshold: Decimal,
        isAbove: Bool,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.pair = pair
        self.threshold = threshold
        self.isAbove = isAbove
        self.isEnabled = isEnabled
    }

    public var description: String {
        let direction = isAbove ? "above" : "below"
        return "\(pair) \(direction) \(threshold)"
    }
}
```

- [ ] **Step 2: Create SettingsStore**

```swift
// Sources/CotaKit/Stores/SettingsStore.swift
import Foundation
import SwiftUI
import ServiceManagement

@MainActor
public final class SettingsStore: ObservableObject {
    private enum Keys {
        static let pairs = "selectedPairs"
        static let refreshInterval = "refreshInterval"
        static let alerts = "priceAlerts"
    }

    private let defaults: UserDefaults

    @Published public var pairs: [String] {
        didSet { defaults.set(pairs, forKey: Keys.pairs) }
    }

    @Published public var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published public var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }

    @Published public var alerts: [PriceAlert] {
        didSet { persistAlerts() }
    }

    public static let defaultPairs = [
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL"
    ]

    public static let availablePairs = [
        "EUR-BRL", "USD-BRL", "GBP-BRL", "BTC-BRL",
        "ARS-BRL", "CAD-BRL", "AUD-BRL", "JPY-BRL",
        "CHF-BRL", "CNY-BRL", "ETH-BRL", "XRP-BRL"
    ]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.pairs = defaults.stringArray(forKey: Keys.pairs)
            ?? Self.defaultPairs

        self.refreshInterval = defaults.integer(forKey: Keys.refreshInterval)
        if self.refreshInterval == 0 {
            self.refreshInterval = 300
        }

        if let data = defaults.data(forKey: Keys.alerts),
           let decoded = try? JSONDecoder().decode([PriceAlert].self, from: data) {
            self.alerts = decoded
        } else {
            self.alerts = []
        }

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    public func addPair(_ pair: String) {
        guard !pairs.contains(pair) else { return }
        pairs.append(pair)
    }

    public func removePair(_ pair: String) {
        pairs.removeAll { $0 == pair }
    }

    public func addAlert(_ alert: PriceAlert) {
        alerts.append(alert)
    }

    public func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
    }

    private func persistAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            defaults.set(data, forKey: Keys.alerts)
        }
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
```

- [ ] **Step 3: Write SettingsStore tests**

```swift
// Tests/CotaKitTests/SettingsStoreTests.swift
import XCTest
@testable import CotaKit

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.suiteName)
    }

    func testDefaultPairs() {
        XCTAssertEqual(store.pairs, SettingsStore.defaultPairs)
    }

    func testDefaultRefreshInterval() {
        XCTAssertEqual(store.refreshInterval, 300)
    }

    func testAddPair() {
        store.addPair("ARS-BRL")
        XCTAssertTrue(store.pairs.contains("ARS-BRL"))
    }

    func testAddDuplicatePairIsIgnored() {
        let count = store.pairs.count
        store.addPair("USD-BRL")
        XCTAssertEqual(store.pairs.count, count)
    }

    func testRemovePair() {
        store.removePair("BTC-BRL")
        XCTAssertFalse(store.pairs.contains("BTC-BRL"))
    }

    func testPairsPersistence() {
        store.addPair("ARS-BRL")
        let restored = SettingsStore(defaults: defaults)
        XCTAssertTrue(restored.pairs.contains("ARS-BRL"))
    }

    func testRefreshIntervalPersistence() {
        store.refreshInterval = 60
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.refreshInterval, 60)
    }

    func testAddAlert() {
        let alert = PriceAlert(pair: "USD-BRL", threshold: 6.0, isAbove: true)
        store.addAlert(alert)
        XCTAssertEqual(store.alerts.count, 1)
    }

    func testRemoveAlert() {
        let alert = PriceAlert(pair: "USD-BRL", threshold: 6.0, isAbove: true)
        store.addAlert(alert)
        store.removeAlert(id: alert.id)
        XCTAssertTrue(store.alerts.isEmpty)
    }

    func testAlertsPersistence() {
        let alert = PriceAlert(pair: "USD-BRL", threshold: 6.0, isAbove: true)
        store.addAlert(alert)
        let restored = SettingsStore(defaults: defaults)
        XCTAssertEqual(restored.alerts.count, 1)
        XCTAssertEqual(restored.alerts[0].pair, "USD-BRL")
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SettingsStore with UserDefaults persistence"
```

---

### Task 5: Wire Settings into QuoteStore and App

**Files:**
- Modify: `Sources/CotaKit/Stores/QuoteStore.swift`
- Modify: `Sources/Cota/CotaApp.swift`

**Interfaces:**
- Consumes: `SettingsStore.pairs`, `SettingsStore.refreshInterval` from Task 4
- Produces: `QuoteStore` now reads pairs and interval from `SettingsStore` instead of hardcoded values

- [ ] **Step 1: Update QuoteStore to accept SettingsStore**

Replace the hardcoded `pairs` and `interval` with references to `SettingsStore`:

```swift
@MainActor
public final class QuoteStore: ObservableObject {
    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    @Published private(set) var lastUpdate: Date?

    private let service: QuoteServiceProtocol
    private let settings: SettingsStore

    private var loop: Task<Void, Never>?

    public init(
        service: QuoteServiceProtocol = QuoteService(),
        settings: SettingsStore
    ) {
        self.service = service
        self.settings = settings
    }
    // ... rest stays the same but use settings.pairs and
    // Duration.seconds(settings.refreshInterval) instead of hardcoded values
}
```

- [ ] **Step 2: Update CotaApp to create and inject SettingsStore**

```swift
@main
struct CotaApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var store: QuoteStore

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: QuoteStore(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store, settings: settings)
                .task { store.start() }
        } label: {
            Text(store.menuBarSummary)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 3: Update PanelView to accept settings**

Add `@ObservedObject var settings: SettingsStore` to `PanelView`.

- [ ] **Step 4: Build and verify**

```bash
swift build
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: wire SettingsStore into QuoteStore and app"
```

---

### Task 6: Settings View with Pair Management and Refresh Interval

**Files:**
- Create: `Sources/Cota/Views/SettingsView.swift`
- Modify: `Sources/Cota/Views/PanelView.swift`

**Interfaces:**
- Consumes: `SettingsStore` from Task 4 — `pairs`, `availablePairs`, `addPair(_:)`, `removePair(_:)`, `refreshInterval`, `launchAtLogin`
- Produces: `SettingsView` — full settings panel accessible from PanelView's gear button

- [ ] **Step 1: Create SettingsView**

```swift
// Sources/Cota/Views/SettingsView.swift
import SwiftUI
import CotaKit

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            pairsSection
            intervalSection
            launchSection

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var pairsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currency Pairs")
                .font(.subheadline)
                .bold()

            ForEach(settings.pairs, id: \.self) { pair in
                HStack {
                    Text(pair)
                    Spacer()
                    Button {
                        settings.removePair(pair)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.pairs.count <= 1)
                }
            }

            let available = SettingsStore.availablePairs
                .filter { !settings.pairs.contains($0) }

            if !available.isEmpty {
                Menu {
                    ForEach(available, id: \.self) { pair in
                        Button(pair) { settings.addPair(pair) }
                    }
                } label: {
                    Label("Add Pair", systemImage: "plus.circle")
                }
                .font(.caption)
            }
        }
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refresh Interval")
                .font(.subheadline)
                .bold()

            Picker("", selection: $settings.refreshInterval) {
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
                Text("5 minutes").tag(300)
                Text("10 minutes").tag(600)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var launchSection: some View {
        Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            .font(.subheadline)
    }
}
```

- [ ] **Step 2: Add settings button to PanelView actions**

In `PanelView.swift`, add a `@State private var showSettings = false` and a gear button in the `actions` HStack:

```swift
private var actions: some View {
    HStack {
        Button {
            Task { await store.refresh() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(store.loading)

        Button {
            showSettings.toggle()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Spacer()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
        }
    }
    .font(.caption)
}
```

Add `.popover(isPresented: $showSettings)` to the VStack in `body` with `SettingsView(settings: settings)`.

- [ ] **Step 3: Build and verify**

```bash
swift build
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add settings view with pair management and refresh interval"
```

---

### Task 7: Click to Copy Value to Clipboard

**Files:**
- Modify: `Sources/Cota/Views/PanelView.swift`

**Interfaces:**
- Consumes: `QuoteRow` internal view, `Quote.bid`, `Quote.codein`
- Produces: clicking a `QuoteRow` copies the formatted bid value to the system clipboard, shows brief visual feedback

- [ ] **Step 1: Add tap gesture and copy logic to QuoteRow**

Add a `@State private var copied = false` to `QuoteRow`. Wrap the `HStack` body in a button or add `.onTapGesture`:

```swift
private struct QuoteRow: View {
    let quote: Quote
    let flag: String
    @State private var copied = false

    var body: some View {
        HStack {
            // ... existing content unchanged ...
        }
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(formattedValue, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }
        .overlay(alignment: .trailing) {
            if copied {
                Text("Copied!")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: click to copy quote value to clipboard"
```

---

### Task 8: Price Alert Notifications

**Files:**
- Create: `Sources/CotaKit/Services/NotificationService.swift`
- Modify: `Sources/CotaKit/Stores/QuoteStore.swift`
- Modify: `Sources/Cota/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `PriceAlert` from Task 4, `Quote` from Task 1, `SettingsStore.alerts` from Task 4
- Produces: `NotificationService` — requests notification permission and sends alerts when thresholds are crossed. `QuoteStore.refresh()` now checks alerts after fetching. `SettingsView` gains an alerts management section.

- [ ] **Step 1: Create NotificationService**

```swift
// Sources/CotaKit/Services/NotificationService.swift
import Foundation
import UserNotifications

public final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    public func checkAlerts(_ alerts: [PriceAlert], against quotes: [Quote]) {
        for alert in alerts where alert.isEnabled {
            guard let quote = quotes.first(where: { "\($0.code)-\($0.codein)" == alert.pair }) else {
                continue
            }

            let triggered = alert.isAbove
                ? quote.bid >= alert.threshold
                : quote.bid <= alert.threshold

            if triggered {
                send(alert: alert, currentValue: quote.bid)
            }
        }
    }

    private func send(alert: PriceAlert, currentValue: Decimal) {
        let content = UNMutableNotificationContent()
        content.title = "Cota Alert"
        let direction = alert.isAbove ? "above" : "below"
        content.body = "\(alert.pair) is \(direction) \(alert.threshold) — currently at \(currentValue)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
```

- [ ] **Step 2: Call alert checking in QuoteStore.refresh()**

After `quotes = newQuotes` in the `refresh()` method, add:

```swift
NotificationService.shared.checkAlerts(settings.alerts, against: quotes)
```

- [ ] **Step 3: Add alerts section to SettingsView**

Add an `alertsSection` to `SettingsView.body` and alert creation fields:

```swift
private var alertsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Price Alerts")
            .font(.subheadline)
            .bold()

        ForEach(settings.alerts) { alert in
            HStack {
                Text(alert.description)
                    .font(.caption)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { alert.isEnabled },
                    set: { enabled in
                        if var updated = settings.alerts.first(where: { $0.id == alert.id }) {
                            updated.isEnabled = enabled
                            settings.alerts = settings.alerts.map { $0.id == alert.id ? updated : $0 }
                        }
                    }
                ))
                .labelsHidden()
                Button {
                    settings.removeAlert(id: alert.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }

        AddAlertRow(pairs: settings.pairs) { alert in
            settings.addAlert(alert)
        }
    }
}
```

Create a small `AddAlertRow` helper view with a pair picker, threshold text field, above/below toggle, and add button.

- [ ] **Step 4: Request notification permission on app start**

In `CotaApp.swift`, add to the `.task` block:

```swift
.task {
    NotificationService.shared.requestPermission()
    store.start()
}
```

- [ ] **Step 5: Build and verify**

```bash
swift build
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add price alert notifications"
```

---

### Task 9: Sparkline View with Price History

**Files:**
- Create: `Sources/Cota/Views/SparklineView.swift`
- Modify: `Sources/CotaKit/Stores/QuoteStore.swift`
- Modify: `Sources/Cota/Views/PanelView.swift`

**Interfaces:**
- Consumes: `Quote` from Task 1, `QuoteStore` from Task 5
- Produces: `QuoteStore.priceHistory: [String: [Decimal]]` — maps pair IDs to last 20 bid values. `SparklineView` — SwiftUI `Shape` that draws a mini line chart from `[Decimal]`.

- [ ] **Step 1: Add price history tracking to QuoteStore**

Add to `QuoteStore`:

```swift
@Published private(set) var priceHistory: [String: [Decimal]] = [:]
private let maxHistoryPoints = 20
```

In `refresh()`, after `quotes = newQuotes`, append to history:

```swift
for quote in quotes {
    var history = priceHistory[quote.id, default: []]
    history.append(quote.bid)
    if history.count > maxHistoryPoints {
        history.removeFirst(history.count - maxHistoryPoints)
    }
    priceHistory[quote.id] = history
}
```

- [ ] **Step 2: Create SparklineView**

```swift
// Sources/Cota/Views/SparklineView.swift
import SwiftUI

struct SparklineView: View {
    let data: [Decimal]
    let color: Color

    var body: some View {
        if data.count >= 2 {
            SparklinePath(values: data.map { NSDecimalNumber(decimal: $0).doubleValue })
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 50, height: 16)
        }
    }
}

private struct SparklinePath: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard let min = values.min(), let max = values.max(), max > min else {
            return Path { path in
                path.move(to: CGPoint(x: 0, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            }
        }

        let stepX = rect.width / CGFloat(values.count - 1)
        let rangeY = max - min

        return Path { path in
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let y = rect.height - (CGFloat((value - min) / rangeY) * rect.height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
```

- [ ] **Step 3: Add sparkline to QuoteRow**

Update `QuoteRow` to accept `history: [Decimal]` and display the sparkline between the name and value columns:

```swift
private struct QuoteRow: View {
    let quote: Quote
    let flag: String
    let history: [Decimal]
    // ... existing code ...

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) { /* ... */ }

            Spacer()

            SparklineView(data: history, color: changeColor)

            VStack(alignment: .trailing, spacing: 2) { /* ... */ }
        }
        // ... existing modifiers ...
    }
}
```

Update the `quotes` computed property in `PanelView` to pass history:

```swift
private var quotes: some View {
    ForEach(store.quotes) { quote in
        QuoteRow(
            quote: quote,
            flag: store.flag(quote.code),
            history: store.priceHistory[quote.id, default: []]
        )
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
swift build
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add sparkline chart for price history"
```

---

### Task 10: Accessibility (VoiceOver Labels)

**Files:**
- Modify: `Sources/Cota/Views/PanelView.swift`
- Modify: `Sources/Cota/Views/SparklineView.swift`
- Modify: `Sources/Cota/Views/SettingsView.swift`

**Interfaces:**
- Consumes: all view files from previous tasks
- Produces: same views with proper VoiceOver support

- [ ] **Step 1: Add accessibility to QuoteRow**

```swift
var body: some View {
    HStack {
        // ... existing content ...
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(quote.code) to \(quote.codein)")
    .accessibilityValue("\(formattedValue), change \(formattedChange)")
    .accessibilityHint("Click to copy value")
    // ... existing modifiers ...
}
```

- [ ] **Step 2: Add accessibility to SparklineView**

```swift
var body: some View {
    if data.count >= 2 {
        SparklinePath(/* ... */)
            .accessibilityLabel("Price trend")
            .accessibilityValue(trendDescription)
    }
}

private var trendDescription: String {
    guard let first = data.first, let last = data.last else { return "No data" }
    if last > first { return "Trending up" }
    if last < first { return "Trending down" }
    return "Stable"
}
```

- [ ] **Step 3: Add accessibility to action buttons**

In `PanelView.actions`:

```swift
Button { /* refresh */ } label: {
    Label("Refresh", systemImage: "arrow.clockwise")
}
.accessibilityLabel("Refresh quotes")

Button { /* settings */ } label: {
    Label("Settings", systemImage: "gearshape")
}
.accessibilityLabel("Open settings")

Button { /* quit */ } label: {
    Label("Quit", systemImage: "power")
}
.accessibilityLabel("Quit Cota")
```

- [ ] **Step 4: Build and verify**

```bash
swift build
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add VoiceOver accessibility labels"
```

---

### Task 11: Global Keyboard Shortcut

**Files:**
- Modify: `Sources/Cota/CotaApp.swift`

**Interfaces:**
- Consumes: `CotaApp` from Task 5
- Produces: `Cmd+Shift+C` global keyboard shortcut to open the menu bar panel

Note: SwiftUI `MenuBarExtra` does not expose a programmatic toggle API. The most reliable approach for macOS 13+ is using `NSEvent.addGlobalMonitorForEvents` to detect the shortcut and simulate a click on the menu bar item via accessibility APIs. However, this requires the user to grant Accessibility permissions.

A simpler alternative that works within SwiftUI's constraints: add a `.keyboardShortcut` to the MenuBarExtra content so the shortcut works when the panel is already open (for refresh, etc.).

- [ ] **Step 1: Add keyboard shortcuts to panel actions**

In `PanelView`, add keyboard shortcuts to the buttons:

```swift
Button {
    Task { await store.refresh() }
} label: {
    Label("Refresh", systemImage: "arrow.clockwise")
}
.keyboardShortcut("r", modifiers: .command)
.disabled(store.loading)

Button {
    showSettings.toggle()
} label: {
    Label("Settings", systemImage: "gearshape")
}
.keyboardShortcut(",", modifiers: .command)

Button {
    NSApplication.shared.terminate(nil)
} label: {
    Label("Quit", systemImage: "power")
}
.keyboardShortcut("q", modifiers: .command)
```

- [ ] **Step 2: Build and verify**

```bash
swift build
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add keyboard shortcuts to panel actions"
```

---

## Summary

| Task | Description | Dependencies |
|------|-------------|-------------|
| 1 | Extract CotaKit library target | — |
| 2 | Unit tests for Service and Store | 1 |
| 3 | Retry with exponential backoff | 1 |
| 4 | Settings store with persistence | 1 |
| 5 | Wire settings into QuoteStore | 4 |
| 6 | Settings view (pairs, interval, launch at login) | 4, 5 |
| 7 | Click to copy value | — |
| 8 | Price alert notifications | 4, 5 |
| 9 | Sparkline view | 1 |
| 10 | Accessibility labels | 7, 9 |
| 11 | Keyboard shortcuts | 6 |
