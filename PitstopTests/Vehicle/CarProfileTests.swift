import Foundation
@testable import Pitstop
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Suite("Car profile in the domain")
struct CarProfileTests {
    @Test("REQ-BOARD-030: a car without a chosen body reads as SUV and has no photo")
    func firstLaunchCarReadsAsSUV() {
        let car = Vehicle.provisional()
        #expect(car.chosenBody == nil)
        #expect(car.body == .suv)
        #expect(car.photoID == nil)
    }

    @Test("REQ-BOARD-030: the body is never derived from the name, make or model")
    func bodyIsNeverDerived() {
        let named = Vehicle(name: "Sedan", make: "Sedan", model: "Sedan")
        #expect(named.body == .suv)
        let renamed = Vehicle.provisional()
            .applying(VehicleFact(field: .name, value: "Sedan"))
            .applying(VehicleFact(field: .model, value: "Sedan"))
        #expect(renamed.chosenBody == nil && renamed.body == .suv)
        let chosen = Vehicle(name: "SUV", model: "SUV", chosenBody: .sedan)
        #expect(chosen.body == .sedan)
        #expect(chosen.applying(VehicleFact(field: .model, value: "SUV")).body == .sedan)
    }

    @Test("REQ-BOARD-030: the owner's body choice is stored, and clearing it reads as SUV again")
    func setAndClearBody() async throws {
        let store = FakeCarMemoryStore()
        let id = try await store.currentVehicle().id
        let set = try await store.execute(.setCarBody(.init(vehicleID: id, body: .sedan)), now: now)
        let chosen = try await store.currentVehicle()
        #expect(set == .vehicleUpdated(chosen))
        #expect(chosen.chosenBody == .sedan && chosen.body == .sedan)
        // A body is not a vehicle fact: it neither names the car nor ends the provisional state.
        #expect(chosen.isProvisional && chosen.name == ProvisionalCarContext.defaultName)

        try await store.execute(.setCarBody(.init(vehicleID: id, body: nil)), now: now)
        let cleared = try await store.currentVehicle()
        #expect(cleared.chosenBody == nil && cleared.body == .suv)
    }

    @Test("REQ-BOARD-033: the photo id is stored by command, and clearing it leaves no reference")
    func setAndClearPhotoID() async throws {
        let store = FakeCarMemoryStore()
        let id = try await store.currentVehicle().id
        let photo = CarPhotoID()
        try await store.execute(.setCarPhoto(.init(vehicleID: id, photoID: photo)), now: now)
        #expect(try await store.currentVehicle().photoID == photo)
        #expect(try await store.currentVehicle().body == .suv)

        try await store.execute(.setCarPhoto(.init(vehicleID: id, photoID: nil)), now: now)
        #expect(try await store.currentVehicle().photoID == nil)
    }

    @Test("REQ-BOARD-030: a profile command for another car changes nothing")
    func unknownVehicleIsRejected() async throws {
        let store = FakeCarMemoryStore()
        let other = VehicleID()
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.setCarBody(.init(vehicleID: other, body: .sedan)), now: now)
        }
        await #expect(throws: CarMemoryStoreError.unknownVehicle) {
            try await store.execute(.setCarPhoto(.init(vehicleID: other, photoID: CarPhotoID())), now: now)
        }
        let car = try await store.currentVehicle()
        #expect(car.chosenBody == nil && car.photoID == nil)
    }

    @Test("REQ-BOARD-030: profile commands always validate; there is no value to reject")
    func profileCommandsValidate() throws {
        let id = VehicleID()
        try DomainCommand.setCarBody(.init(vehicleID: id, body: .sedan)).validate(now: now)
        try DomainCommand.setCarBody(.init(vehicleID: id, body: nil)).validate(now: now)
        try DomainCommand.setCarPhoto(.init(vehicleID: id, photoID: CarPhotoID())).validate(now: now)
        try DomainCommand.setCarPhoto(.init(vehicleID: id, photoID: nil)).validate(now: now)
    }

    @Test("REQ-BOARD-030: a car saved before the body existed decodes with no choice")
    func olderEncodingDecodesWithoutProfile() throws {
        let old = #"{"id":{"rawValue":"00000000-0000-4000-8000-0000000C0FFE"},"name":"Kestrel","isProvisional":false}"#
        let car = try JSONDecoder().decode(Vehicle.self, from: Data(old.utf8))
        #expect(car.chosenBody == nil && car.body == .suv && car.photoID == nil)
    }
}
