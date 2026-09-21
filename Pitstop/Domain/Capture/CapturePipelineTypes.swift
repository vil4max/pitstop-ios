import Foundation

public enum CaptureSource: String, Codable, Sendable, CaseIterable {
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
    case recognizedDocumentText(String)

    public var rawContent: String {
        switch self {
        case let .text(text), let .transcript(text), let .recognizedDocumentText(text):
            text
        }
    }
}

/// Surface that was visible when the capture started. A prior for interpretation only.
public enum VisibleFeature: String, Codable, Sendable, CaseIterable {
    case carBoard
    case notes
    case service
    case history
    case road
}

public struct CaptureInput: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let payload: CapturePayload
    public let source: CaptureSource
    public let capturedAt: Date
    /// The locale of the request that produced the capture: Siri's request locale, or the app's current
    /// locale for a typed capture (ADR 0030). A hint for interpreters, never the capture's language.
    public let localeIdentifier: String
    public let selectedVehicleID: VehicleID?
    public let visibleFeature: VisibleFeature?
    public let visibleEntityID: UUID?

    public init(
        id: UUID = UUID(),
        payload: CapturePayload,
        source: CaptureSource,
        capturedAt: Date = Date(),
        localeIdentifier: String,
        selectedVehicleID: VehicleID? = nil,
        visibleFeature: VisibleFeature? = nil,
        visibleEntityID: UUID? = nil
    ) {
        self.id = id
        self.payload = payload
        self.source = source
        self.capturedAt = capturedAt
        self.localeIdentifier = localeIdentifier
        self.selectedVehicleID = selectedVehicleID
        self.visibleFeature = visibleFeature
        self.visibleEntityID = visibleEntityID
    }
}

public enum ProposalKind: String, Codable, Sendable, CaseIterable {
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
    public let extractedDate: Date?
    public let extractedNoteContexts: Set<NoteContext>
    public let extractedVehicleFact: VehicleFact?
    public let extractedDistanceIntervalKm: Int?
    public let extractedTimeIntervalMonths: Int?
    public let extractedEventKind: HistoryEventKind?
    public let extractedAmount: Decimal?
    /// Fields the producer already knows it could not fill. The validator recomputes this itself.
    public let missingRequiredFields: [ProposalField]

    public init(
        id: UUID = UUID(),
        sourceInputID: UUID,
        kind: ProposalKind,
        rawText: String,
        confidence: Double? = nil,
        extractedOdometerKm: Double? = nil,
        extractedOperationID: MaintenanceOperationID? = nil,
        extractedDate: Date? = nil,
        extractedNoteContexts: Set<NoteContext> = [],
        extractedVehicleFact: VehicleFact? = nil,
        extractedDistanceIntervalKm: Int? = nil,
        extractedTimeIntervalMonths: Int? = nil,
        extractedEventKind: HistoryEventKind? = nil,
        extractedAmount: Decimal? = nil,
        missingRequiredFields: [ProposalField] = []
    ) {
        self.id = id
        self.sourceInputID = sourceInputID
        self.kind = kind
        self.rawText = rawText
        self.confidence = confidence
        self.extractedOdometerKm = extractedOdometerKm
        self.extractedOperationID = extractedOperationID
        self.extractedDate = extractedDate
        self.extractedNoteContexts = extractedNoteContexts
        self.extractedVehicleFact = extractedVehicleFact
        self.extractedDistanceIntervalKm = extractedDistanceIntervalKm
        self.extractedTimeIntervalMonths = extractedTimeIntervalMonths
        self.extractedEventKind = extractedEventKind
        self.extractedAmount = extractedAmount
        self.missingRequiredFields = missingRequiredFields
    }
}

public enum ProposalField: String, Codable, Sendable, CaseIterable {
    case odometerKm
    case operationID
    case vehicleFact
    case policyInterval
    case eventKind
    case amount
}
