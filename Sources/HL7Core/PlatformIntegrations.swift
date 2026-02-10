/// Platform Integrations for HL7kit
///
/// Provides framework-agnostic protocols and data types for integrating HL7kit
/// with Apple platform frameworks: HealthKit, CareKit, ResearchKit, iCloud,
/// Handoff, and Siri Shortcuts. All types compile on any platform including
/// Linux; actual framework bridging is performed by conforming types that
/// import the platform-specific SDK.

import Foundation

// MARK: - Common Types

/// A lightweight representation of a clinical observation used for bridging
/// between HL7/FHIR resources and platform-specific health data stores.
public struct ClinicalObservation: Sendable, Codable, Equatable, Identifiable {
    /// Unique identifier for this observation
    public let id: String

    /// LOINC or other coding system code
    public let code: String

    /// Human-readable display name
    public let displayName: String

    /// Numeric value, if applicable
    public let value: Double?

    /// Unit of measurement (UCUM preferred)
    public let unit: String?

    /// String value for non-numeric observations
    public let stringValue: String?

    /// Observation timestamp
    public let effectiveDate: Date

    /// Patient identifier
    public let patientID: String?

    /// Creates a clinical observation
    public init(
        id: String = UUID().uuidString,
        code: String,
        displayName: String,
        value: Double? = nil,
        unit: String? = nil,
        stringValue: String? = nil,
        effectiveDate: Date = Date(),
        patientID: String? = nil
    ) {
        self.id = id
        self.code = code
        self.displayName = displayName
        self.value = value
        self.unit = unit
        self.stringValue = stringValue
        self.effectiveDate = effectiveDate
        self.patientID = patientID
    }
}

/// Category of clinical data for mapping purposes
public enum ClinicalDataCategory: String, Sendable, Codable, Equatable, CaseIterable {
    /// Vital signs (heart rate, blood pressure, temperature, etc.)
    case vitalSigns

    /// Laboratory test results
    case labResults

    /// Medication records
    case medications

    /// Immunization records
    case immunizations

    /// Allergy and intolerance records
    case allergies

    /// Procedure records
    case procedures

    /// Condition / diagnosis records
    case conditions
}

// MARK: - HealthKit Integration

/// Bridge protocol for converting between FHIR Observations and HealthKit samples.
///
/// Conforming types supply the actual HealthKit import and translation logic.
/// The protocol itself is framework-agnostic so that it compiles on all platforms.
public protocol HealthKitBridge: Sendable {
    /// Convert a clinical observation to a platform health sample representation.
    /// - Parameter observation: The source clinical observation
    /// - Returns: An opaque identifier for the created health sample
    /// - Throws: If the observation cannot be mapped
    func exportToHealthKit(_ observation: ClinicalObservation) async throws -> String

    /// Import a health sample identified by its unique ID.
    /// - Parameter sampleID: The platform health sample identifier
    /// - Returns: A clinical observation representation
    /// - Throws: If the sample cannot be read or mapped
    func importFromHealthKit(sampleID: String) async throws -> ClinicalObservation

    /// Query observations for a date range and category.
    /// - Parameters:
    ///   - category: The clinical data category to query
    ///   - start: Range start (inclusive)
    ///   - end: Range end (inclusive)
    /// - Returns: Array of clinical observations
    func queryHealthKit(
        category: ClinicalDataCategory,
        from start: Date,
        to end: Date
    ) async throws -> [ClinicalObservation]

    /// Request authorization for the specified data categories.
    /// - Parameter categories: Categories to request access for
    /// - Returns: `true` if authorization was granted
    func requestAuthorization(for categories: Set<ClinicalDataCategory>) async throws -> Bool
}

/// Static mapping utilities between LOINC codes and HealthKit quantity type identifiers.
public struct HealthKitDataMapping: Sendable {

    /// Known LOINC-to-identifier mappings for vital signs
    public static let vitalSignsMappings: [String: String] = [
        "8867-4": "HKQuantityTypeIdentifierHeartRate",
        "8310-5": "HKQuantityTypeIdentifierBodyTemperature",
        "8480-6": "HKQuantityTypeIdentifierBloodPressureSystolic",
        "8462-4": "HKQuantityTypeIdentifierBloodPressureDiastolic",
        "9279-1": "HKQuantityTypeIdentifierRespiratoryRate",
        "59408-5": "HKQuantityTypeIdentifierOxygenSaturation",
        "29463-7": "HKQuantityTypeIdentifierBodyMass",
        "8302-2": "HKQuantityTypeIdentifierHeight",
    ]

    /// Known LOINC-to-identifier mappings for lab results
    public static let labResultsMappings: [String: String] = [
        "2339-0": "HKQuantityTypeIdentifierBloodGlucose",
        "2093-3": "HKQuantityTypeIdentifierCholesterolTotal",
        "2085-9": "HKQuantityTypeIdentifierCholesterolHDL",
        "2089-1": "HKQuantityTypeIdentifierCholesterolLDL",
        "718-7": "HKQuantityTypeIdentifierHemoglobin",
    ]

    /// Known LOINC-to-identifier mappings for medication-related quantities
    public static let medicationMappings: [String: String] = [
        "insulin-dose": "HKQuantityTypeIdentifierInsulinDelivery",
    ]

    /// Resolve a LOINC code to a HealthKit quantity type identifier.
    /// - Parameter loincCode: The LOINC code to look up
    /// - Returns: The corresponding identifier, or `nil` if unmapped
    public static func quantityTypeIdentifier(forLOINC loincCode: String) -> String? {
        vitalSignsMappings[loincCode]
            ?? labResultsMappings[loincCode]
            ?? medicationMappings[loincCode]
    }

    /// Determine the clinical data category for a LOINC code.
    /// - Parameter loincCode: The LOINC code to classify
    /// - Returns: The matching category, or `nil` if unknown
    public static func category(forLOINC loincCode: String) -> ClinicalDataCategory? {
        if vitalSignsMappings[loincCode] != nil { return .vitalSigns }
        if labResultsMappings[loincCode] != nil { return .labResults }
        if medicationMappings[loincCode] != nil { return .medications }
        return nil
    }

    private init() {}
}

/// Configuration for HealthKit synchronization behavior
public struct HealthKitSyncConfiguration: Sendable, Codable, Equatable {
    /// Whether background delivery is enabled
    public let backgroundDeliveryEnabled: Bool

    /// Categories to synchronize
    public let categories: [ClinicalDataCategory]

    /// Minimum interval between syncs, in seconds
    public let syncInterval: TimeInterval

    /// Maximum number of samples per sync batch
    public let batchSize: Int

    /// Creates a sync configuration
    public init(
        backgroundDeliveryEnabled: Bool = false,
        categories: [ClinicalDataCategory] = ClinicalDataCategory.allCases,
        syncInterval: TimeInterval = 900,
        batchSize: Int = 100
    ) {
        self.backgroundDeliveryEnabled = backgroundDeliveryEnabled
        self.categories = categories
        self.syncInterval = syncInterval
        self.batchSize = batchSize
    }

    /// Default configuration with all categories enabled
    public static let `default` = HealthKitSyncConfiguration()
}

// MARK: - CareKit Integration

/// A lightweight representation of a care plan task for bridging with CareKit.
public struct CareTask: Sendable, Codable, Equatable, Identifiable {
    /// Unique task identifier
    public let id: String

    /// Human-readable task title
    public let title: String

    /// Detailed instructions
    public let instructions: String?

    /// Scheduled date for the task
    public let scheduledDate: Date

    /// Whether the task has been completed
    public let isCompleted: Bool

    /// Identifier of the associated care plan
    public let carePlanID: String?

    /// Creates a care task
    public init(
        id: String = UUID().uuidString,
        title: String,
        instructions: String? = nil,
        scheduledDate: Date = Date(),
        isCompleted: Bool = false,
        carePlanID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.carePlanID = carePlanID
    }
}

/// Bridge protocol for converting between HL7 care plans and CareKit tasks.
///
/// Conforming types provide the actual CareKit framework integration.
public protocol CareKitBridge: Sendable {
    /// Convert an HL7 care plan message into CareKit tasks.
    /// - Parameter hl7Message: Raw HL7 care plan message content
    /// - Returns: Array of care tasks derived from the message
    func importCarePlan(from hl7Message: String) async throws -> [CareTask]

    /// Export CareKit tasks as an HL7 care plan message.
    /// - Parameter tasks: The care tasks to export
    /// - Returns: HL7-formatted care plan message
    func exportCarePlan(tasks: [CareTask]) async throws -> String

    /// Synchronize a single task outcome back to HL7.
    /// - Parameter task: The completed or updated task
    /// - Returns: HL7 message fragment representing the outcome
    func syncTaskOutcome(_ task: CareTask) async throws -> String
}

/// Static mapping utilities for CareKit data conversion.
public struct CareKitDataMapping: Sendable {

    /// Map an HL7 activity code to a care task category string.
    /// - Parameter activityCode: The HL7 activity code
    /// - Returns: A human-readable category
    public static func taskCategory(forActivityCode activityCode: String) -> String {
        let mappings: [String: String] = [
            "MEDS": "Medication",
            "VITALS": "Vital Signs",
            "EXERCISE": "Physical Activity",
            "DIET": "Nutrition",
            "APPT": "Appointment",
            "EDU": "Education",
            "ASSESS": "Assessment",
        ]
        return mappings[activityCode] ?? "General"
    }

    /// Map a care task completion status to an HL7 outcome code.
    /// - Parameter isCompleted: Whether the task is completed
    /// - Returns: HL7 outcome status code
    public static func outcomeCode(isCompleted: Bool) -> String {
        isCompleted ? "completed" : "in-progress"
    }

    private init() {}
}

// MARK: - ResearchKit Integration

/// Consent status for research studies
public enum ConsentStatus: String, Sendable, Codable, Equatable {
    /// Participant has consented
    case consented

    /// Participant has declined
    case declined

    /// Consent has been withdrawn
    case withdrawn

    /// Consent is pending review
    case pending
}

/// A lightweight representation of a survey response for bridging with ResearchKit.
public struct SurveyResponse: Sendable, Codable, Equatable, Identifiable {
    /// Unique response identifier
    public let id: String

    /// The survey / questionnaire identifier
    public let surveyID: String

    /// Individual question results as key-value pairs
    public let answers: [String: String]

    /// Timestamp when the response was recorded
    public let completedDate: Date

    /// Participant identifier
    public let participantID: String?

    /// Creates a survey response
    public init(
        id: String = UUID().uuidString,
        surveyID: String,
        answers: [String: String],
        completedDate: Date = Date(),
        participantID: String? = nil
    ) {
        self.id = id
        self.surveyID = surveyID
        self.answers = answers
        self.completedDate = completedDate
        self.participantID = participantID
    }
}

/// Bridge protocol for exchanging survey and consent data with ResearchKit.
///
/// Conforming types provide the actual ResearchKit framework integration.
public protocol ResearchKitBridge: Sendable {
    /// Convert an HL7 questionnaire into a survey definition.
    /// - Parameter hl7Questionnaire: Raw HL7 questionnaire content
    /// - Returns: An opaque survey definition identifier
    func importQuestionnaire(from hl7Questionnaire: String) async throws -> String

    /// Export a survey response as an HL7 QuestionnaireResponse resource.
    /// - Parameter response: The survey response to export
    /// - Returns: HL7-formatted questionnaire response
    func exportSurveyResponse(_ response: SurveyResponse) async throws -> String

    /// Record a participant consent decision.
    /// - Parameters:
    ///   - participantID: The participant identifier
    ///   - status: The consent status
    ///   - studyID: The study identifier
    /// - Returns: HL7-formatted consent resource
    func recordConsent(
        participantID: String,
        status: ConsentStatus,
        studyID: String
    ) async throws -> String
}

/// Static mapping utilities for ResearchKit data conversion.
public struct ResearchKitDataMapping: Sendable {

    /// Map an HL7 question type to a survey step type string.
    /// - Parameter hl7QuestionType: HL7 item type code (e.g., "boolean", "choice")
    /// - Returns: A step type identifier for the survey engine
    public static func stepType(forHL7QuestionType hl7QuestionType: String) -> String {
        let mappings: [String: String] = [
            "boolean": "booleanQuestion",
            "choice": "multipleChoice",
            "open-choice": "textChoice",
            "string": "textAnswer",
            "integer": "numericAnswer",
            "decimal": "numericAnswer",
            "date": "dateQuestion",
            "dateTime": "dateTimeQuestion",
            "text": "textAnswer",
        ]
        return mappings[hl7QuestionType] ?? "textAnswer"
    }

    /// Map a consent status to an HL7 provision type code.
    /// - Parameter status: The consent status
    /// - Returns: HL7 provision type code
    public static func provisionTypeCode(for status: ConsentStatus) -> String {
        switch status {
        case .consented: return "permit"
        case .declined: return "deny"
        case .withdrawn: return "deny"
        case .pending: return "pending"
        }
    }

    private init() {}
}

// MARK: - iCloud Sync Support

/// Current status of a cloud synchronization operation
public enum CloudSyncStatus: String, Sendable, Codable, Equatable {
    /// No sync operation in progress
    case idle

    /// Sync is actively transferring data
    case syncing

    /// Sync completed with an error
    case error

    /// Sync completed successfully
    case completed
}

/// Strategy for resolving conflicts when the same record is modified on
/// multiple devices.
public enum ConflictResolutionStrategy: String, Sendable, Codable, Equatable {
    /// The most recently modified record wins
    case lastWriterWins

    /// The server-side record takes precedence
    case serverWins

    /// The client-side record takes precedence
    case clientWins

    /// Conflicts are presented to the caller for manual resolution
    case manual
}

/// Configuration for iCloud-based HL7 message synchronization.
public struct CloudSyncConfiguration: Sendable, Codable, Equatable {
    /// iCloud container identifier
    public let containerIdentifier: String

    /// Whether automatic sync is enabled
    public let automaticSyncEnabled: Bool

    /// Conflict resolution strategy
    public let conflictResolution: ConflictResolutionStrategy

    /// Maximum record size in bytes
    public let maxRecordSizeBytes: Int

    /// Sync interval in seconds
    public let syncInterval: TimeInterval

    /// Whether to sync over cellular data
    public let allowsCellularSync: Bool

    /// Creates a cloud sync configuration
    public init(
        containerIdentifier: String,
        automaticSyncEnabled: Bool = true,
        conflictResolution: ConflictResolutionStrategy = .lastWriterWins,
        maxRecordSizeBytes: Int = 1_048_576,
        syncInterval: TimeInterval = 300,
        allowsCellularSync: Bool = false
    ) {
        self.containerIdentifier = containerIdentifier
        self.automaticSyncEnabled = automaticSyncEnabled
        self.conflictResolution = conflictResolution
        self.maxRecordSizeBytes = maxRecordSizeBytes
        self.syncInterval = syncInterval
        self.allowsCellularSync = allowsCellularSync
    }
}

/// A record representing a single HL7 message stored in the cloud.
public struct CloudSyncRecord: Sendable, Codable, Equatable, Identifiable {
    /// Unique record identifier
    public let id: String

    /// The HL7 message content
    public let messageContent: String

    /// Message type (e.g., "ADT", "ORM")
    public let messageType: String

    /// Timestamp of the last modification
    public let lastModified: Date

    /// Identifier of the device that last modified this record
    public let deviceID: String

    /// Creates a cloud sync record
    public init(
        id: String = UUID().uuidString,
        messageContent: String,
        messageType: String,
        lastModified: Date = Date(),
        deviceID: String = ""
    ) {
        self.id = id
        self.messageContent = messageContent
        self.messageType = messageType
        self.lastModified = lastModified
        self.deviceID = deviceID
    }
}

/// Protocol for syncing HL7 messages via iCloud or a similar cloud backend.
///
/// Conforming types handle the actual CloudKit or network integration.
public protocol CloudSyncProvider: Sendable {
    /// Push a record to the cloud store.
    /// - Parameter record: The record to upload
    func push(_ record: CloudSyncRecord) async throws

    /// Pull all records modified after the given date.
    /// - Parameter since: Only return records modified after this date
    /// - Returns: Array of updated records
    func pull(since: Date) async throws -> [CloudSyncRecord]

    /// Delete a record from the cloud store.
    /// - Parameter recordID: Identifier of the record to delete
    func delete(recordID: String) async throws

    /// Resolve a conflict between a local and remote version of a record.
    /// - Parameters:
    ///   - local: The local version of the record
    ///   - remote: The remote version of the record
    ///   - strategy: The conflict resolution strategy to apply
    /// - Returns: The resolved record
    func resolveConflict(
        local: CloudSyncRecord,
        remote: CloudSyncRecord,
        strategy: ConflictResolutionStrategy
    ) async throws -> CloudSyncRecord

    /// Return the current sync status.
    func status() async -> CloudSyncStatus
}

// MARK: - Handoff Support

/// Activity types for NSUserActivity-based Handoff of HL7 data.
public enum HandoffActivityType: String, Sendable, Codable, Equatable, CaseIterable {
    /// Viewing an HL7 message
    case viewMessage = "com.hl7kit.viewMessage"

    /// Editing an HL7 message
    case editMessage = "com.hl7kit.editMessage"

    /// Validating an HL7 message
    case validateMessage = "com.hl7kit.validateMessage"

    /// Converting an HL7 message between formats
    case convertMessage = "com.hl7kit.convertMessage"

    /// Browsing a patient record
    case browsePatient = "com.hl7kit.browsePatient"
}

/// Payload transferred via Handoff between devices.
public struct HandoffPayload: Sendable, Codable, Equatable {
    /// The Handoff activity type
    public let activityType: HandoffActivityType

    /// HL7 message content being handed off
    public let messageContent: String

    /// Message type (e.g., "ADT^A01")
    public let messageType: String?

    /// Additional user info key-value pairs
    public let userInfo: [String: String]

    /// Timestamp when the handoff was initiated
    public let timestamp: Date

    /// Creates a handoff payload
    public init(
        activityType: HandoffActivityType,
        messageContent: String,
        messageType: String? = nil,
        userInfo: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.activityType = activityType
        self.messageContent = messageContent
        self.messageType = messageType
        self.userInfo = userInfo
        self.timestamp = timestamp
    }
}

/// Protocol for NSUserActivity-based Handoff of HL7 messages.
///
/// Conforming types create and handle `NSUserActivity` objects on Apple platforms.
public protocol HandoffProvider: Sendable {
    /// Begin advertising a Handoff activity.
    /// - Parameter payload: The payload to make available for continuation
    /// - Returns: An opaque activity identifier
    func beginActivity(with payload: HandoffPayload) async throws -> String

    /// Update the content of an in-progress Handoff activity.
    /// - Parameters:
    ///   - activityID: The activity identifier returned by `beginActivity`
    ///   - payload: The updated payload
    func updateActivity(activityID: String, with payload: HandoffPayload) async throws

    /// End a Handoff activity.
    /// - Parameter activityID: The activity identifier to end
    func endActivity(activityID: String) async throws

    /// Handle an incoming Handoff activity from another device.
    /// - Parameter userInfo: The user info dictionary from the incoming activity
    /// - Returns: The decoded handoff payload
    func handleIncomingActivity(userInfo: [String: String]) async throws -> HandoffPayload
}

// MARK: - Siri Shortcuts Integration

/// Actions that can be exposed as Siri Shortcuts.
public enum ShortcutAction: String, Sendable, Codable, Equatable, CaseIterable {
    /// Validate an HL7 message
    case validateMessage

    /// Convert between HL7 formats
    case convertFormat

    /// Look up a patient by identifier
    case lookupPatient

    /// Send an HL7 message to a destination
    case sendMessage
}

/// Response returned after executing a Siri Shortcut action.
public struct ShortcutResponse: Sendable, Codable, Equatable {
    /// Whether the action completed successfully
    public let success: Bool

    /// The action that was executed
    public let action: ShortcutAction

    /// Human-readable result message
    public let message: String

    /// Optional result data (e.g., converted message content)
    public let resultData: String?

    /// Timestamp of the response
    public let timestamp: Date

    /// Creates a shortcut response
    public init(
        success: Bool,
        action: ShortcutAction,
        message: String,
        resultData: String? = nil,
        timestamp: Date = Date()
    ) {
        self.success = success
        self.action = action
        self.message = message
        self.resultData = resultData
        self.timestamp = timestamp
    }
}

/// Protocol for exposing HL7 operations as Siri Shortcuts.
///
/// Conforming types register intents with the Shortcuts framework on Apple platforms.
public protocol ShortcutsProvider: Sendable {
    /// Execute a shortcut action.
    /// - Parameters:
    ///   - action: The shortcut action to execute
    ///   - input: Input data for the action (e.g., message content)
    /// - Returns: The action response
    func execute(action: ShortcutAction, input: String) async throws -> ShortcutResponse

    /// Register available shortcut actions with the system.
    /// - Parameter actions: Actions to make available as shortcuts
    func registerShortcuts(_ actions: [ShortcutAction]) async throws

    /// Donate an executed action to the system for prediction.
    /// - Parameter response: The response from a completed action
    func donateInteraction(for response: ShortcutResponse) async throws
}

// MARK: - Platform Integration Manager

/// Central actor for coordinating platform integrations.
///
/// Provides optional registries for each platform bridge so that consuming
/// code can discover and use integrations without direct framework imports.
public actor PlatformIntegrationManager {
    /// Registered HealthKit bridge, if any
    public private(set) var healthKitBridge: (any HealthKitBridge)?

    /// Registered CareKit bridge, if any
    public private(set) var careKitBridge: (any CareKitBridge)?

    /// Registered ResearchKit bridge, if any
    public private(set) var researchKitBridge: (any ResearchKitBridge)?

    /// Registered cloud sync provider, if any
    public private(set) var cloudSyncProvider: (any CloudSyncProvider)?

    /// Registered handoff provider, if any
    public private(set) var handoffProvider: (any HandoffProvider)?

    /// Registered shortcuts provider, if any
    public private(set) var shortcutsProvider: (any ShortcutsProvider)?

    /// Creates a new platform integration manager with no registered bridges
    public init() {}

    /// Register a HealthKit bridge implementation.
    /// - Parameter bridge: The bridge to register
    public func register(healthKit bridge: any HealthKitBridge) {
        healthKitBridge = bridge
    }

    /// Register a CareKit bridge implementation.
    /// - Parameter bridge: The bridge to register
    public func register(careKit bridge: any CareKitBridge) {
        careKitBridge = bridge
    }

    /// Register a ResearchKit bridge implementation.
    /// - Parameter bridge: The bridge to register
    public func register(researchKit bridge: any ResearchKitBridge) {
        researchKitBridge = bridge
    }

    /// Register a cloud sync provider implementation.
    /// - Parameter provider: The provider to register
    public func register(cloudSync provider: any CloudSyncProvider) {
        cloudSyncProvider = provider
    }

    /// Register a handoff provider implementation.
    /// - Parameter provider: The provider to register
    public func register(handoff provider: any HandoffProvider) {
        handoffProvider = provider
    }

    /// Register a shortcuts provider implementation.
    /// - Parameter provider: The provider to register
    public func register(shortcuts provider: any ShortcutsProvider) {
        shortcutsProvider = provider
    }
}
