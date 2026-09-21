import Foundation
@testable import Pitstop
import Testing

private let now = DomainFixtures.Odometers.baseDate
private let day: TimeInterval = 86400
private let vehicleID = DomainFixtures.Vehicles.defaultID

private func event(_ kind: PlannedDatedEvent.Kind = .insuranceExpiry, inDays days: Double) -> PlannedDatedEvent {
    PlannedDatedEvent(vehicleID: vehicleID, kind: kind, date: now.addingTimeInterval(days * day), createdAt: now)
}

private func project(_ events: [PlannedDatedEvent], at moment: Date = now) -> RoadProjection {
    RoadProjector().project(RoadContext(
        now: moment,
        maintenanceStates: [],
        plannedEvents: events.map(\.roadEvent)
    ))
}

@Suite("Planned dated events")
struct PlannedDatedEventTests {
    @Test(
        "REQ-ROAD-017: a planned date must fall between 14 days ago and ten years ahead",
        arguments: [
            (-14.0, true),
            (-14.01, false),
            (0, true),
            (Double(PlannedEventLimits.maximumDaysAhead), true),
            (Double(PlannedEventLimits.maximumDaysAhead) + 0.01, false),
        ]
    )
    func dateWindow(days: Double, isValid: Bool) {
        for command in [
            DomainCommand.addPlannedEvent(.init(event: event(inDays: days))),
            .updatePlannedEvent(.init(event: event(inDays: days))),
        ] {
            if isValid {
                #expect(throws: Never.self) { try command.validate(now: now) }
            } else {
                #expect(throws: DomainCommandError.plannedDateOutOfRange) { try command.validate(now: now) }
            }
        }
    }

    @Test(
        "REQ-ROAD-017: an `other` label is one trimmed line of at most 40 characters",
        arguments: [
            ("Winter tyres", nil),
            (String(repeating: "я", count: PlannedEventLimits.maximumLabelLength), nil),
            (String(repeating: "я", count: PlannedEventLimits.maximumLabelLength + 1), .plannedLabelTooLong),
            ("   ", .invalidPlannedLabel),
            ("", .invalidPlannedLabel),
            (" Warranty", .invalidPlannedLabel),
            ("Two\nlines", .invalidPlannedLabel),
        ] as [(String, DomainCommandError?)]
    )
    func labelRules(label: String, expected: DomainCommandError?) {
        let command = DomainCommand.addPlannedEvent(.init(event: event(.other(label: label), inDays: 30)))
        if let expected {
            #expect(throws: expected) { try command.validate(now: now) }
        } else {
            #expect(throws: Never.self) { try command.validate(now: now) }
        }
    }

    @Test("REQ-ROAD-016: `other` without a label and removal need nothing more")
    func unlabelledOtherAndRemovalAreValid() throws {
        try DomainCommand.addPlannedEvent(.init(event: event(.other(label: nil), inDays: 10))).validate(now: now)
        try DomainCommand.removePlannedEvent(.init(eventID: UUID())).validate(now: now)
    }

    @Test("REQ-ROAD-016: the Road input carries only the kind, the date, and the owner's label")
    func roadEventCarriesTheStatedDateOnly() {
        let insurance = event(inDays: 40)
        let tyres = event(.other(label: "Winter tyres"), inDays: 60)

        #expect(insurance.roadEvent == PlannedVehicleEvent(
            id: insurance.id,
            kind: .insuranceExpiry,
            date: insurance.date
        ))
        #expect(tyres.roadEvent == PlannedVehicleEvent(
            id: tyres.id, kind: .other, date: tyres.date, label: "Winter tyres"
        ))
        #expect(insurance.label == nil && tyres.label == "Winter tyres")
    }

    @Test("REQ-ROAD-001, REQ-ROAD-007: a stated insurance expiry is a date milestone labelled by days left")
    func insuranceAppearsByDaysLeft() throws {
        // Stored as the start of a day 40 days ahead, seen at 10:00 today.
        let insurance = event(inDays: 39.58)
        let lead = try #require(project([insurance]).slots.first?.lead)

        #expect(lead.subject == .planned(.insuranceExpiry, id: insurance.id))
        #expect(lead.dimension == .time && lead.remainingKm == nil)
        #expect(lead.distanceLabel == .daysLeft(40))
        #expect(lead.plannedLabel == nil)
    }

    @Test("REQ-ROAD-016: tomorrow is one day left, not \"almost\"; a passed day counts whole days past")
    func wholeDaysForPlannedDates() throws {
        #expect(try #require(project([event(inDays: 0.58)]).slots.first?.lead).distanceLabel == .daysLeft(1))
        #expect(try #require(project([event(inDays: -3.42)]).slots.first?.lead).distanceLabel == .daysPast(3))
    }

    @Test("REQ-ROAD-016: an `other` milestone carries the owner's label for the surface")
    func otherMilestoneKeepsItsLabel() throws {
        let lead = try #require(project([event(.other(label: "Warranty ends"), inDays: 90)]).slots.first?.lead)
        #expect(lead.plannedLabel == "Warranty ends")
    }

    @Test(
        "REQ-ROAD-020: a planned date stays on Road as due for 14 days after it passes, then leaves",
        arguments: [(-1.0, true), (-14, true), (-14.01, false), (-30, false)]
    )
    func graceAfterTheDate(days: Double, isOnRoad: Bool) {
        let planned = event(inDays: days)
        let road = project([planned])

        #expect(planned.isOnRoad(now: now) == isOnRoad)
        #expect(road.slots.count == (isOnRoad ? 1 : 0))
        #expect(road.slots.first?.lead.map { $0.state == .due } ?? true)
    }

    @Test("REQ-ROAD-020: the same stored date leaves Road as time passes, with nothing deleted")
    func sameEventLeavesWithTime() {
        let insurance = event(inDays: 10)
        #expect(project([insurance]).slots.count == 1)
        #expect(project([insurance], at: now.addingTimeInterval(24 * day)).slots.count == 1)
        #expect(project([insurance], at: now.addingTimeInterval(24.01 * day)).slots.isEmpty)
    }
}
