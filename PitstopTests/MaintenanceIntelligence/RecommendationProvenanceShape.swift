import Foundation
@testable import Pitstop

// Test-only recommendation shape from the MNT-INT-001 record, area 1 (MNT-INT-002). It checks
// whether provenance and applicability can be expressed before any real source is approved;
// production `MaintenancePolicy` stays unchanged until then, so nothing here ships in the app.

/// The published document a recommendation comes from.
struct RecommendationSource: Hashable, Sendable {
    enum Kind: String, Sendable {
        case ownersManual
        case maintenanceBooklet
        case repairInformationPortal
        case commercialAPI
    }

    let kind: Kind
    let publisher: String
    let documentTitle: String
    /// The document revision; a new edition is a new source, never an in-place edit.
    let edition: String
    let referenceURL: URL
    let licenceReference: String
    let retrievedAt: Date
    let verifiedBy: String
    let verifiedAt: Date
}

/// A place inside a source, so every rule and every procedure component can be traced (C2).
struct SourceReference: Hashable, Sendable {
    let source: RecommendationSource
    let section: String
}

/// The dimensions the domain model lists for a Maintenance Recommendation.
enum ApplicabilityDimension: String, CaseIterable, Hashable, Sendable {
    case make
    case model
    case generation
    case modelYear
    case market
    case engine
    case transmission
    case drivetrain
    case serviceRegime
}

enum ApplicabilityRequirement: Hashable, Sendable {
    case equals(String)
    case yearWithin(ClosedRange<Int>)

    func isSatisfied(by fact: String) -> Bool {
        switch self {
        case let .equals(expected):
            return fact == expected
        case let .yearWithin(range):
            guard let year = Int(fact) else { return false }
            return range.contains(year)
        }
    }
}

/// Facts the owner supplied or confirmed. A missing dimension is unknown, never a default.
struct VehicleFacts: Hashable, Sendable {
    var values: [ApplicabilityDimension: String]

    /// What the production `Vehicle` can supply today: make, model and year only.
    init(vehicle: Vehicle) {
        var values: [ApplicabilityDimension: String] = [:]
        values[.make] = vehicle.make
        values[.model] = vehicle.model
        values[.modelYear] = vehicle.year.map(String.init)
        self.values = values
    }

    init(_ values: [ApplicabilityDimension: String]) {
        self.values = values
    }
}

enum ApplicabilityOutcome: Hashable, Sendable {
    case applies
    case mismatch(ApplicabilityDimension)
    case unknown(ApplicabilityDimension)
}

struct Applicability: Hashable, Sendable {
    let requirements: [ApplicabilityDimension: ApplicabilityRequirement]

    /// Every named dimension must match a known fact. Dimensions are checked in a fixed order so
    /// the outcome is deterministic; a mismatch anywhere wins over an unknown elsewhere.
    func evaluate(_ facts: VehicleFacts) -> ApplicabilityOutcome {
        let named = ApplicabilityDimension.allCases.filter { requirements[$0] != nil }
        for dimension in named {
            if let fact = facts.values[dimension], let requirement = requirements[dimension],
               !requirement.isSatisfied(by: fact)
            {
                return .mismatch(dimension)
            }
        }
        if let missing = named.first(where: { facts.values[$0] == nil }) {
            return .unknown(missing)
        }
        return .applies
    }
}

/// How the next due point is placed (ADR 0020 Q3). Completion-based is today's production rule.
enum RecommendationAnchoring: Hashable, Sendable {
    case completionBased
    case fixedGridFromFirstRegistration
}

struct RecommendationRule: Hashable, Sendable {
    let distanceKm: Int?
    let months: Int?
    let anchoring: RecommendationAnchoring

    /// The first grid point strictly after `date`. Nil for a completion-based rule or a grid
    /// without a time step; the grid never moves with a completion, early or late.
    func nextGridDate(after date: Date, firstRegistration: Date, calendar: Calendar) -> Date? {
        guard anchoring == .fixedGridFromFirstRegistration, let months, months > 0 else { return nil }
        var step = 1
        while let point = calendar.date(byAdding: .month, value: months * step, to: firstRegistration) {
            if point > date {
                return point
            }
            step += 1
        }
        return nil
    }
}

/// One required part of a procedure; its provenance is not optional (REQ-DOMAIN-004).
struct ProcedureComponent: Hashable, Sendable {
    let id: String
    let name: String
    let provenance: SourceReference
}

struct ProcedureComposition: Hashable, Sendable {
    let operationID: MaintenanceOperationID
    let components: [ProcedureComponent]
}

/// A sourced recommendation record. The user never edits it; a custom policy sits beside it.
struct MaintenanceRecommendationRecord: Identifiable, Hashable, Sendable {
    let id: String
    let operationID: MaintenanceOperationID
    let rule: RecommendationRule
    let applicability: Applicability
    let provenance: SourceReference
    let procedure: ProcedureComposition?
}

/// What production would need to carry a recommendation without losing meaning.
enum ProductionModelGap: Hashable, Sendable {
    case noProvenance
    case noAnchoringField
    case noProcedureType
    case noVehicleFact(ApplicabilityDimension)
    case noFirstRegistrationDate
}

enum RecommendationProjection: Hashable, Sendable {
    case policy(MaintenancePolicy)
    case notApplicable(ApplicabilityOutcome)
    /// Production would read the rule with a different meaning, so no policy is produced.
    case notRepresentable(ProductionModelGap)
}

enum RecommendationResolver {
    static func project(
        _ record: MaintenanceRecommendationRecord,
        facts: VehicleFacts
    ) -> RecommendationProjection {
        let outcome = record.applicability.evaluate(facts)
        guard outcome == .applies else { return .notApplicable(outcome) }
        // ADR 0020 Q3: a policy without an anchoring field is completion-based, so a grid rule
        // projected into today's policy would silently move with every completion.
        guard record.rule.anchoring == .completionBased else { return .notRepresentable(.noAnchoringField) }
        return .policy(MaintenancePolicy(
            operationID: record.operationID,
            distanceIntervalKm: record.rule.distanceKm,
            timeIntervalMonths: record.rule.months,
            source: .defaultRecommendation
        ))
    }

    static func policies(
        from records: [MaintenanceRecommendationRecord],
        facts: VehicleFacts
    ) -> [MaintenancePolicy] {
        records.compactMap {
            if case let .policy(policy) = project($0, facts: facts) {
                return policy
            }
            return nil
        }
    }

    /// Gaps a real source with these records would hit in the production model.
    static func productionGaps(of records: [MaintenanceRecommendationRecord]) -> Set<ProductionModelGap> {
        let productionFacts = VehicleFacts(vehicle: Vehicle(name: "", make: "", model: "", year: 0))
        var gaps: Set<ProductionModelGap> = records.isEmpty ? [] : [.noProvenance]
        for record in records {
            if record.rule.anchoring == .fixedGridFromFirstRegistration {
                gaps.formUnion([.noAnchoringField, .noFirstRegistrationDate])
            }
            if record.procedure != nil {
                gaps.insert(.noProcedureType)
            }
            for dimension in record.applicability.requirements.keys where productionFacts.values[dimension] == nil {
                gaps.insert(.noVehicleFact(dimension))
            }
        }
        return gaps
    }
}
