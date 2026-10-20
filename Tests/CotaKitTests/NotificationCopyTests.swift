import Foundation
import Testing

@testable import CotaKit

/// The banner's wording, in the package's development language.
@Suite @MainActor
struct NotificationCopyTests {
    /// The title says what crossed what: the currency by name and the
    /// threshold in the destination's money.
    @Test func theNotificationTitleNamesTheCurrency() {
        let eur = PriceAlert(pair: "EUR-BRL", threshold: Decimal(string: "5.75")!, isAbove: true)
        #expect(NotificationService.title(for: eur) == "Euro passou de R$ 5,75")
    }

    @Test func theNotificationBodyCarriesTheDaysChange() {
        let eur = PriceAlert(pair: "EUR-BRL", threshold: Decimal(string: "5.75")!, isAbove: true)
        let body = NotificationService.body(
            for: eur,
            currentValue: Decimal(string: "5.7612")!,
            change: Decimal(string: "0.96")!
        )
        #expect(body == "Agora R$ 5,7612 · ▲ 0,96% hoje")
    }
}
