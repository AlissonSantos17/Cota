import Testing

@testable import CotaKit

@Suite
struct PairDisplayTests {
    /// The stored ID keeps the hyphen the API and persistence already use.
    /// The label is what the lists show, and it uses a slash.
    @Test func aPairIDUsesASlashInTheLabel() {
        #expect(PairDisplay(id: "EUR-BRL").text == "EUR/BRL")
    }

    @Test func aPairIDSplitsIntoBaseAndQuote() {
        let display = PairDisplay(id: "EUR-BRL")
        #expect(display.base == "EUR")
        #expect(display.quote == "BRL")
    }

    /// The panel already has the two codes; it should not have to reassemble
    /// an ID just to get the same label the settings lists use.
    @Test func codesBuildTheSameLabel() {
        #expect(PairDisplay(base: "EUR", quote: "BRL").text == "EUR/BRL")
    }
}
