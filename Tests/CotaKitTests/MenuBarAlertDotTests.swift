import Foundation
import Testing

@testable import CotaKit

@Suite
struct MenuBarAlertDotTests {
    @Test func aPairWithAnAlertOnEndsInADot() {
        let quotes = [
            MenuBarQuote(pair: "EUR-BRL", bid: Decimal(string: "5.648")!, change: 1),
            MenuBarQuote(pair: "USD-BRL", bid: Decimal(string: "5.04")!, change: -1),
        ]
        let segments = MenuBarLabel.segments(
            for: quotes, format: .code, indicator: .arrow, alertPairs: ["USD-BRL"]
        )

        #expect(segments.filter { $0.role == .alertDot }.count == 1)
        #expect(segments.last?.role == .alertDot)
    }

    @Test func noAlertsNoDot() {
        let quotes = [MenuBarQuote(pair: "EUR-BRL", bid: Decimal(string: "5.648")!, change: 1)]
        let segments = MenuBarLabel.segments(for: quotes, format: .code, indicator: .arrow)
        #expect(!segments.contains { $0.role == .alertDot })
    }
}
