import Foundation
@testable import Pitstop
import Testing

private typealias Kestrel = KestrelRecommendationFixture

@Suite("Recommendation provenance fixture (MNT-INT-002)")
struct RecommendationProvenanceTests {
    @Test("REQ-DOMAIN-004, ADR-0020: every fictional rule is expressible with its source, edition and market")
    func everyRuleIsExpressible() {
        #expect(Kestrel.schedule.map(\.operationID) == [
            .engineOilService, .dsgService, .awdCouplingService, .brakeFluid,
        ])
        let rules = Dictionary(uniqueKeysWithValues: Kestrel.schedule.map { ($0.operationID, $0.rule) })
        #expect(rules[.engineOilService] == RecommendationRule(
            distanceKm: 15000,
            months: 12,
            anchoring: .completionBased
        ))
        #expect(rules[.dsgService] == RecommendationRule(distanceKm: 60000, months: nil, anchoring: .completionBased))
        #expect(rules[.awdCouplingService] == RecommendationRule(
            distanceKm: 45000, months: 36, anchoring: .completionBased
        ))
        #expect(rules[.brakeFluid] == RecommendationRule(
            distanceKm: nil, months: 24, anchoring: .fixedGridFromFirstRegistration
        ))

        for record in Kestrel.schedule {
            #expect(record.provenance.source.edition == "XM-2024.1")
            #expect(!record.provenance.section.isEmpty)
            #expect(record.applicability.requirements[.market] == .equals("XM"))
            #expect(record.applicability.requirements[.serviceRegime] == .equals("normal"))
            #expect(record.applicability.evaluate(Kestrel.matchingFacts) == .applies)
        }
    }

    @Test("ADR-0020: the fixed-grid rule stays on the grid from first registration, early or late")
    func fixedGridRuleIsExpressible() {
        let rule = Kestrel.brakeFluid.rule
        let grid = { (done: Date) in
            rule.nextGridDate(after: done, firstRegistration: Kestrel.firstRegistration, calendar: Kestrel.calendar)
        }
        // First registration 2025-03-10 puts grid points on 2027-03-10, 2029-03-10, ...
        #expect(grid(Kestrel.day(2026, 1, 15)) == Kestrel.day(2027, 3, 10))
        #expect(grid(Kestrel.day(2027, 5, 1)) == Kestrel.day(2029, 3, 10))
        // A completion-based rule has no grid, which is what production does today (ADR 0020 Q3).
        #expect(Kestrel.oil.rule.nextGridDate(
            after: Kestrel.day(2026, 1, 15), firstRegistration: Kestrel.firstRegistration, calendar: Kestrel.calendar
        ) == nil)
    }

    @Test("REQ-DOMAIN-004: the oil procedure has three required components, each with provenance")
    func procedureCompositionCarriesProvenance() throws {
        let procedure = try #require(Kestrel.oil.procedure)
        #expect(procedure.operationID == Kestrel.oil.operationID)
        #expect(procedure.components.map(\.id) == ["engineOil", "oilFilter", "drainPlugSeal"])
        for component in procedure.components {
            #expect(component.provenance.source == Kestrel.oil.provenance.source)
            #expect(component.provenance.section.hasPrefix(Kestrel.oil.provenance.section))
        }
    }

    @Test("REQ-DOMAIN-004: a recommendation for another transmission yields no recommendation")
    func applicabilityMismatchYieldsNothing() {
        var facts = Kestrel.matchingFacts
        facts.values[.transmission] = "6-speed manual"
        for record in Kestrel.schedule {
            #expect(RecommendationResolver.project(record, facts: facts) == .notApplicable(.mismatch(.transmission)))
        }
        #expect(RecommendationResolver.policies(from: Kestrel.schedule, facts: facts).isEmpty)
    }

    @Test("REQ-DOMAIN-004: an unknown applicability fact yields no recommendation instead of a guess")
    func unknownFactYieldsNothing() {
        var facts = Kestrel.matchingFacts
        facts.values[.drivetrain] = nil
        for record in Kestrel.schedule {
            #expect(RecommendationResolver.project(record, facts: facts) == .notApplicable(.unknown(.drivetrain)))
        }
        #expect(RecommendationResolver.policies(from: Kestrel.schedule, facts: facts).isEmpty)
    }

    @Test("REQ-DOMAIN-004: a mismatch wins over an unknown fact, so the outcome does not depend on order")
    func mismatchWinsOverUnknown() {
        let facts = VehicleFacts([.make: "Other Fictional Motors"])
        #expect(Kestrel.applicability.evaluate(facts) == .mismatch(.make))
    }

    @Test("REQ-DOMAIN-004: the production vehicle cannot supply the facts the fixture names")
    func productionVehicleLeavesFactsUnknown() {
        let vehicle = Vehicle(name: "Kestrel", make: Kestrel.make, model: Kestrel.model, year: 2025)
        let facts = VehicleFacts(vehicle: vehicle)
        #expect(Kestrel.applicability.evaluate(facts) == .unknown(.market))
        #expect(RecommendationResolver.policies(from: Kestrel.schedule, facts: facts).isEmpty)
    }

    @Test("REQ-DOMAIN-006: a userCustom policy stays effective and the recommendation record is unchanged")
    func customPolicyOutranksRecommendation() throws {
        let before = Kestrel.oil
        let recommended = RecommendationResolver.policies(from: Kestrel.schedule, facts: Kestrel.matchingFacts)
        let custom = MaintenancePolicy(operationID: .engineOilService, distanceIntervalKm: 10000, source: .userCustom)

        let effective = (recommended + [custom]).effective
        let oil = try #require(effective.first { $0.operationID == .engineOilService })
        #expect(oil == custom)
        let dualClutch = try #require(effective.first { $0.operationID == .dsgService })
        #expect(dualClutch.source == .defaultRecommendation && dualClutch.distanceIntervalKm == 60000)
        // The custom policy sits beside the recommendation; it never rewrites it.
        #expect(recommended.contains {
            $0.operationID == .engineOilService && $0.source == .defaultRecommendation
                && $0.distanceIntervalKm == 15000 && $0.timeIntervalMonths == 12
        })
        #expect(Kestrel.oil == before)
    }

    @Test("ADR-0020: a fixed-grid rule is not projected into a production policy that would lose the grid")
    func fixedGridIsNotProjectedIntoProduction() {
        #expect(RecommendationResolver.project(Kestrel.brakeFluid, facts: Kestrel.matchingFacts)
            == .notRepresentable(.noAnchoringField))
        let projected = RecommendationResolver.policies(from: Kestrel.schedule, facts: Kestrel.matchingFacts)
        #expect(projected.map(\.operationID) == [.engineOilService, .dsgService, .awdCouplingService])
    }

    @Test("MNT-INT-002: the production-model gaps a real source would hit are listed")
    func productionGapsAreListed() {
        #expect(RecommendationResolver.productionGaps(of: Kestrel.schedule) == [
            .noProvenance,
            .noAnchoringField,
            .noFirstRegistrationDate,
            .noProcedureType,
            .noVehicleFact(.market),
            .noVehicleFact(.engine),
            .noVehicleFact(.transmission),
            .noVehicleFact(.drivetrain),
            .noVehicleFact(.serviceRegime),
        ])
    }

    @Test("MNT-INT-002: the fixture names only a fictional make, model, market and reserved domain")
    func fixtureIsFictional() throws {
        #expect(Kestrel.make == "Example Motors" && Kestrel.model == "Kestrel")
        // ISO 3166-1 reserves XA to XZ for user assignment, so no real market uses the code.
        #expect(Kestrel.market.count == 2 && Kestrel.market.hasPrefix("X"))
        #expect(Kestrel.source.referenceURL.host()?.hasSuffix(".example") == true)
        #expect(Kestrel.source.documentTitle.contains("fictional"))
        #expect(Kestrel.allStrings.allSatisfy { !$0.isEmpty })

        // Guard on the fixture sources themselves: any URL in them must use the reserved domain.
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(files.count >= 3)
        let pattern = /https?:\/\/([A-Za-z0-9.-]+)/
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in text.matches(of: pattern) {
                #expect(match.output.1.hasSuffix(".example"), "\(file.lastPathComponent): \(match.output.0)")
            }
        }
    }
}
