import Foundation

// The car's profile (ADR 0040) is not a vehicle fact: it neither names the car nor selects maintenance
// guidance, so these commands leave `isProvisional` and every fact alone. Only the owner issues them in
// the car editor; no capture proposal maps to them.

/// Sets the owner's body choice; `nil` clears it, and the car then reads as SUV (REQ-BOARD-030).
public struct SetCarBodyCommand: Hashable, Sendable {
    public let vehicleID: VehicleID
    public let body: CarBody?

    public init(vehicleID: VehicleID, body: CarBody?) {
        self.vehicleID = vehicleID
        self.body = body
    }
}

/// Points the car at the photo files saved under `photoID`; `nil` removes the reference. The caller
/// deletes the old id's files, since the store holds only the id (REQ-BOARD-033).
public struct SetCarPhotoCommand: Hashable, Sendable {
    public let vehicleID: VehicleID
    public let photoID: CarPhotoID?

    public init(vehicleID: VehicleID, photoID: CarPhotoID?) {
        self.vehicleID = vehicleID
        self.photoID = photoID
    }
}

public extension Vehicle {
    func applying(_ command: SetCarBodyCommand) -> Vehicle {
        var copy = self
        copy.chosenBody = command.body
        return copy
    }

    func applying(_ command: SetCarPhotoCommand) -> Vehicle {
        var copy = self
        copy.photoID = command.photoID
        return copy
    }
}
