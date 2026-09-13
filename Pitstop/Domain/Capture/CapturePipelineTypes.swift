import Foundation

public enum CaptureSource: String, Codable, Sendable {
    case pitVoice
    case pitText
    case directApp
    case widget
    case siri
    case shortcut
}

public enum CapturePayload: Hashable, Codable, Sendable {
    case text(String)
    case transcript(String)

    public var rawContent: String {
        switch self {
        case let .text(text), let .transcript(text):
            text
        }
    }
}

public struct CaptureInput: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let payload: CapturePayload
    public let source: CaptureSource
    public let capturedAt: Date
    public let localeIdentifier: String
    public let selectedVehicleID: VehicleID?

    public init(
        id: UUID = UUID(),
        payload: CapturePayload,
        source: CaptureSource,
        capturedAt: Date = Date(),
        localeIdentifier: String = "ru_RU",
        selectedVehicleID: VehicleID? = nil
    ) {
        self.id = id
        self.payload = payload
        self.source = source
        self.capturedAt = capturedAt
        self.localeIdentifier = localeIdentifier
        self.selectedVehicleID = selectedVehicleID
    }
}

public enum ProposalKind: String, Codable, Sendable {
    case rawNote
    case contextualNote
    case odometerReading
    case vehicleFact
    case maintenanceCompletion
    case maintenancePolicyDraft
    case vehicleEvent
    case expense
    case reminderCandidate
    case unknown
}

public enum ConfirmationOutcome: String, Codable, Sendable {
    case autoAcceptSafe
    case confirmCompact
    case clarify
    case preserveRaw
    case rejectUnsupported
}

public struct MemoryProposal: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let sourceInputID: UUID
    public let kind: ProposalKind
    public let rawText: String
    public let confidence: Double?
    public let extractedOdometerKm: Double?
    public let extractedOperationID: MaintenanceOperationID?
    public let missingRequiredFields: [String]

    public init(
        id: UUID = UUID(),
        sourceInputID: UUID,
        kind: ProposalKind,
        rawText: String,
        confidence: Double? = nil,
        extractedOdometerKm: Double? = nil,
        extractedOperationID: MaintenanceOperationID? = nil,
        missingRequiredFields: [String] = []
    ) {
        self.id = id
        self.sourceInputID = sourceInputID
        self.kind = kind
        self.rawText = rawText
        self.confidence = confidence
        self.extractedOdometerKm = extractedOdometerKm
        self.extractedOperationID = extractedOperationID
        self.missingRequiredFields = missingRequiredFields
    }
}

// MARK: - Domain Mutation Boundary Commands (spec 34)

public struct CreateNoteCommand: Hashable, Sendable {
    public let vehicleID: VehicleID?
    public let rawText: String
    public let canonicalContexts: Set<NoteContext>

    public init(
        vehicleID: VehicleID? = nil,
        rawText: String,
        canonicalContexts: Set<NoteContext> = []
    ) {
        self.vehicleID = vehicleID
        self.rawText = rawText
        self.canonicalContexts = canonicalContexts
    }
}

public struct RecordOdometerReadingCommand: Hashable, Sendable {
    public let reading: OdometerReading

    public init(reading: OdometerReading) {
        self.reading = reading
    }
}

public struct ConfirmMaintenanceCompletionCommand: Hashable, Sendable {
    public let completion: MaintenanceCompletion

    public init(completion: MaintenanceCompletion) {
        self.completion = completion
    }
}
