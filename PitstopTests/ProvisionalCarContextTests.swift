import Foundation
@testable import Pitstop
import Testing

@Suite("ProvisionalCarContext")
struct ProvisionalCarContextTests {
    @Test("REQ-DOMAIN-002: first launch has a display name and no vehicle facts")
    func firstLaunchHasNoVehicleFacts() {
        let context = ProvisionalCarContext.firstLaunch
        #expect(context.name == ProvisionalCarContext.defaultName)
        #expect(context.odometerKm == nil)
        #expect(context.make == nil)
        #expect(context.model == nil)
        #expect(context.year == nil)
    }

    @Test(
        "REQ-BOARD-002: the provisional name is shown in the user's language",
        arguments: [("en", "My New Car"), ("ru", "Моя новая машина"), ("uk", "Моя нова машина")]
    )
    func provisionalNameIsLocalisedForDisplay(language: String, expected: String) {
        let context = ProvisionalCarContext.firstLaunch
        #expect(context.displayName(locale: Locale(identifier: language)) == expected)
        #expect(context.name == ProvisionalCarContext.defaultName, "the stored placeholder never changes")
    }

    @Test("REQ-BOARD-002: a name the owner typed is shown as typed in every language")
    func typedNamePassesThrough() {
        let named = ProvisionalCarContext(vehicle: Vehicle(id: Vehicle.provisionalID, name: "Kestrel"), observedKm: nil)
        for language in ["en", "ru", "uk"] {
            #expect(named.displayName(locale: Locale(identifier: language)) == "Kestrel")
        }
        #expect(named.displayName == "Kestrel")
    }

    @Test("REQ-BOARD-002: a car that gained a fact but kept the placeholder name still shows it translated")
    func placeholderOnAKnownCarIsLocalised() {
        // A fact such as the make ends the provisional state without naming the car; validation then still
        // treats the stored name as the placeholder, so the display does too.
        let knownCar = ProvisionalCarContext(
            name: ProvisionalCarContext.defaultName,
            odometerKm: nil,
            make: "Kestrel Motors",
            model: nil,
            year: nil,
            isProvisional: false
        )
        #expect(knownCar.displayName(locale: Locale(identifier: "uk")) == "Моя нова машина")
    }

    @Test("ADR-0007: the provisional car ID is the fixed literal, never a random fallback")
    func provisionalIDIsTheFixedLiteral() {
        #expect(Vehicle.provisionalID.rawValue.uuidString == "00000000-0000-4000-8000-0000000C0FFE")
    }

    @Test("REQ-BOARD-004: unknown mileage is never shown as 0 km")
    func unknownMileageIsNotZero() {
        let context = ProvisionalCarContext.firstLaunch
        #expect(CarBoardMileage(odometerKm: context.odometerKm) == .unknown)
    }

    @Test("REQ-BOARD-005: a supplied zero reading is shown as 0 km")
    func suppliedZeroReadingIsShown() {
        #expect(CarBoardMileage(odometerKm: 0) == .kilometers(0))
    }
}
