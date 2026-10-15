import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate.addingTimeInterval(30 * 86400)

/// A corrected event's amount enters the editor as the reader writes numbers and saves back unchanged.
@MainActor
@Suite("History amount in the editor")
struct HistoryAmountInputTests {
    private static let ukrainian = Locale(identifier: "uk_UA")

    @Test(
        "REQ-CAPTURE-012: a stored amount is written in the reader's locale and parses back to the same value",
        arguments: ["12.5", "12500.5", "1500", "0.99", "123456.78"]
    )
    func amountRoundTripsInUkrainian(_ stored: String) throws {
        let amount = try #require(Decimal(string: stored, locale: Locale(identifier: "en_US_POSIX")))
        let text = FeatureFormat.amountInput(amount, locale: Self.ukrainian)

        #expect(!text.contains("."), "Ukrainian writes a decimal comma")
        #expect(InputParsing.amount(from: text) == .value(amount))
    }

    @Test("REQ-CAPTURE-012: the editor shows 12,5 to a Ukrainian reader, without grouping, as the row writes it")
    func editorShowsLocaleDecimal() async throws {
        let store = FakeCarMemoryStore()
        let model = HistoryViewModel(store: store, now: { now }, locale: Self.ukrainian)
        var draft = model.newDraft()
        draft.amountText = "12500.5"
        #expect(await model.save(draft))
        let original = try #require(await store.events.first)

        let correction = model.draft(for: original)

        #expect(correction.amountText == "12500,5")
        #expect(await model.save(correction, replacing: original))
        #expect(await store.events.first?.amount == original.amount)
    }

    @Test("REQ-CAPTURE-012: an English reader keeps the decimal point")
    func englishKeepsThePoint() throws {
        let amount = try #require(Decimal(string: "12.5", locale: Locale(identifier: "en_US_POSIX")))
        #expect(FeatureFormat.amountInput(amount, locale: Locale(identifier: "en_US")) == "12.5")
    }
}
