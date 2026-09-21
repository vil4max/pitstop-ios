import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate

private func proposal(_ text: String, source: CaptureSource = .pitVoice) async throws -> MemoryProposal? {
    let input = CaptureInput(payload: .transcript(text), source: source, capturedAt: now)
    return try await RuleBasedInterpreter().interpret(input)
}

@Suite("Rule-based interpreter")
struct RuleBasedInterpreterTests {
    @Test(
        "ADR-0011: a report of completed work becomes a maintenance completion with its operation",
        arguments: [
            (
                "Поменял масло и масляный фильтр на пробеге 85000",
                MaintenanceOperationID.engineOilService,
                Double?.some(85000)
            ),
            ("заменил тормозную жидкость", .brakeFluid, Double?.none),
            ("changed the spark plugs at 92000 km", .sparkPlugs, Double?.some(92000)),
            ("сделал дсг на 62000", .dsgService, Double?.some(62000)),
        ]
    )
    func completedWorkIsProposed(text: String, operation: MaintenanceOperationID, kilometers: Double?) async throws {
        let result = try #require(await proposal(text))
        #expect(result.kind == .maintenanceCompletion)
        #expect(result.extractedOperationID == operation)
        #expect(result.extractedOdometerKm == kilometers)
        #expect(result.rawText == text)
    }

    @Test(
        "REQ-CAPTURE-014: an intention, a plan, or a question is never read as completed work",
        arguments: [
            "надо поменять масло",
            "заменить дворники",
            "хочу поменять масло на 85000",
            "пора менять тормозную жидкость",
            "когда я менял масло?",
            "should I have changed the oil?",
            "need to replace the cabin filter",
            "масло не менял",
            "масло поменял бы, да некогда",
            "I haven't changed the oil",
        ]
    )
    func intentionsAreNotInterpreted(text: String) async throws {
        #expect(try await proposal(text) == nil)
    }

    @Test("ADR-0011: a visit with several jobs is left raw rather than confirmed in part")
    func severalOperationsAreNotInterpreted() async throws {
        #expect(try await proposal("поменял масло и тормозную жидкость") == nil)
    }

    @Test("ADR-0011: a mileage report becomes an odometer reading")
    func mileageIsProposed() async throws {
        let result = try #require(await proposal("пробег 84 200"))
        #expect(result.kind == .odometerReading && result.extractedOdometerKm == 84200)
    }

    @Test("ADR-0011: a car wash becomes a vehicle event with its price when one is given")
    func carWashIsProposed() async throws {
        let result = try #require(await proposal("помыл машину за 1200"))
        #expect(result.kind == .vehicleEvent && result.extractedEventKind == .carWash)
        #expect(result.extractedAmount == 1200)
        // The price is not a mileage.
        #expect(result.extractedOdometerKm == nil)
    }

    @Test(
        "REQ-CAPTURE-006: an ordinary thought produces no proposal at all",
        arguments: [
            "Стук в подвеске справа спереди при проезде лежачих",
            "Спросить про пятно на заднем сиденье",
            "Купить зимнюю омывайку -25",
            "",
            "   ",
        ]
    )
    func unsupportedMeaningProposesNothing(text: String) async throws {
        #expect(try await proposal(text) == nil)
    }

    @Test("ADR-0011: the price of the work is never read as the mileage")
    func priceIsNotMileage() async throws {
        let service = try #require(await proposal("поменял масло за 5000"))
        #expect(service.kind == .maintenanceCompletion && service.extractedOdometerKm == nil)
        let both = try #require(await proposal("помыл машину на пробеге 84400 за 1200"))
        #expect(both.extractedOdometerKm == 84400 && both.extractedAmount == 1200)
        // Inside a washing report "на 1500" is money, not a mileage.
        #expect(try await proposal("помыл машину, потратил на 1500")?.extractedOdometerKm == nil)
    }

    @Test("ADR-0011: a number that cannot be a reading is not extracted as one")
    func implausibleNumbersAreIgnored() async throws {
        #expect(try await proposal("пробег 99999999") == nil)
        let litres = try #require(await proposal("залил масло 4,2 литра, пробег 85000"))
        #expect(litres.extractedOdometerKm == 85000)
    }

    @Test("REQ-CAPTURE-002: the same words give the same proposal from every source", arguments: CaptureSource.allCases)
    func sourceDoesNotChangeMeaning(source: CaptureSource) async throws {
        let result = try #require(await proposal("поменял масло на 85000", source: source))
        #expect(result.kind == .maintenanceCompletion && result.extractedOperationID == .engineOilService)
    }

    @Test(
        "ADR-0011: an ordinary word is never read as a hedge or a verb",
        arguments: [
            ("поменял масло в машине на 85000", MaintenanceOperationID.engineOilService),
            ("поработал и заменил свечи на 90000", .sparkPlugs),
            ("сменил тормозную жидкость в июне на 70000", .brakeFluid),
        ]
    )
    func ordinaryWordsDoNotBlockInterpretation(text: String, operation: MaintenanceOperationID) async throws {
        let result = try #require(await proposal(text))
        #expect(result.kind == .maintenanceCompletion && result.extractedOperationID == operation)
    }

    @Test(
        "ADR-0011: a year or a date is never read as a mileage",
        arguments: ["Куплена в 2019, пробег неизвестен", "поменял масло 15.06.2024", "масло с 2019 года"]
    )
    func yearsAndDatesAreNotMileage(text: String) async throws {
        #expect(try await proposal(text)?.extractedOdometerKm == nil)
    }

    @Test("ADR-0011: a top-up and a washing place are not reports of work")
    func ambiguousReportsAreLeftRaw() async throws {
        #expect(try await proposal("залил 5 литров масла")?.kind != .maintenanceCompletion)
        #expect(try await proposal("рядом открылась новая мойка") == nil)
    }

    @Test("ADR-0011: a bare number, and money, are not a mileage")
    func bareNumbersAreNotMileage() async throws {
        #expect(try await proposal("позвонить по номеру 89161234567") == nil)
        #expect(try await proposal("потратил на 1500") == nil)
        #expect(try await proposal("пробег 84 200")?.extractedOdometerKm == 84200)
    }

    @Test(
        "ADR-0011: malformed input is answered, never crashed on",
        arguments: ["помыл машину за", "пробег 84200 за", "пробег 999 999 999 999 999 999 999", "за", "мыл"]
    )
    func malformedInputIsSafe(text: String) async throws {
        // The call itself is the assertion: a truncated phrase or an absurd number must be answered,
        // not trapped on. Whatever comes back, the mileage is either absent or plausible.
        let kilometers = try await proposal(text)?.extractedOdometerKm
        #expect(kilometers == nil || DomainCommandLimits.isPlausibleOdometer(kilometers ?? 0))
    }

    @Test("ADR-0011: a word that merely contains a verb stem is not a report")
    func nearbyWordsAreNotVerbs() async throws {
        #expect(try await proposal("помыл машину мылом") != nil)
        #expect(try await proposal("купил мыло") == nil)
        #expect(try await proposal("смыл грязь с фар") == nil)
    }
}
