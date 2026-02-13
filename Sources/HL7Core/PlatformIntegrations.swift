// PlatformIntegrations.swift
// HL7Core
//
// Platform integration protocols and adapters for Apple frameworks.
// Provides abstractions for HealthKit, CareKit, ResearchKit,
// iCloud sync, Handoff, and Siri shortcuts integration.

import Foundation

// MARK: - Health Data Types

/// Represents a clinical measurement that can be exchanged with health platforms
public struct HealthMeasurement: Sendable, Codable, Hashable {
    /// Unique identifier for this measurement
    public let id: String
    
    /// Type of measurement (e.g., "heart_rate", "blood_pressure", "body_temperature")
    public let measurementType: String
    
    /// Numeric value of the measurement
    public let value: Double
    
    /// Unit of measurement (e.g., "bpm", "mmHg", "°C")
    public let unit: String
    
    /// When the measurement was taken
    public let timestamp: Date
    
    /// Source of the measurement (e.g., device name, app name)
    public let source: String?
    
    /// Additional metadata as key-value pairs
    public let metadata: [String: String]?
    
    /// Creates a new health measurement
    public init(
        id: String = UUID().uuidString,
        measurementType: String,
        value: Double,
        unit: String,
        timestamp: Date = Date(),
        source: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.measurementType = measurementType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
        self.metadata = metadata
    }
}

/// Represents a clinical vital sign with systolic/diastolic or multi-component values
public struct VitalSign: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Type of vital sign
    public let type: VitalSignType
    
    /// Primary value
    public let primaryValue: Double
    
    /// Secondary value (e.g., diastolic for blood pressure)
    public let secondaryValue: Double?
    
    /// Unit of measurement
    public let unit: String
    
    /// When the vital sign was recorded
    public let timestamp: Date
    
    /// Status of the measurement
    public let status: MeasurementStatus
    
    /// Creates a new vital sign
    public init(
        id: String = UUID().uuidString,
        type: VitalSignType,
        primaryValue: Double,
        secondaryValue: Double? = nil,
        unit: String,
        timestamp: Date = Date(),
        status: MeasurementStatus = .final
    ) {
        self.id = id
        self.type = type
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.unit = unit
        self.timestamp = timestamp
        self.status = status
    }
}

/// Types of vital signs
public enum VitalSignType: String, Sendable, Codable, Hashable, CaseIterable {
    case heartRate = "heart_rate"
    case bloodPressure = "blood_pressure"
    case bodyTemperature = "body_temperature"
    case respiratoryRate = "respiratory_rate"
    case oxygenSaturation = "oxygen_saturation"
    case bodyWeight = "body_weight"
    case bodyHeight = "body_height"
    case bodyMassIndex = "bmi"
    case bloodGlucose = "blood_glucose"
    case stepCount = "step_count"
}

/// Status of a measurement
public enum MeasurementStatus: String, Sendable, Codable, Hashable {
    case preliminary
    case final
    case amended
    case cancelled
    case enteredInError = "entered_in_error"
}

// MARK: - HealthKit Integration Protocol

/// Protocol for integrating HL7 data with health data platforms (e.g., HealthKit)
///
/// Implement this protocol to bridge between HL7kit messages and health platform data stores.
/// The protocol provides a uniform interface for reading and writing health measurements
/// regardless of the underlying platform.
///
/// Example usage:
/// ```swift
/// class MyHealthKitAdapter: HealthDataProvider {
///     func readMeasurements(ofType type: String, from: Date, to: Date) async throws -> [HealthMeasurement] {
///         // Query HealthKit and convert to HealthMeasurement
///     }
/// }
/// ```
public protocol HealthDataProvider: Sendable {
    /// Read measurements of a given type within a date range
    func readMeasurements(
        ofType type: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthMeasurement]
    
    /// Write a measurement to the health data store
    func writeMeasurement(_ measurement: HealthMeasurement) async throws
    
    /// Write multiple measurements in a batch
    func writeMeasurements(_ measurements: [HealthMeasurement]) async throws
    
    /// Check if the provider has authorization for a specific measurement type
    func isAuthorized(forType type: String) async -> Bool
    
    /// Request authorization for specific measurement types
    func requestAuthorization(forTypes types: [String]) async throws
    
    /// Delete a measurement by ID
    func deleteMeasurement(withId id: String) async throws
    
    /// Observe changes to a measurement type in real-time
    func observeChanges(
        forType type: String,
        handler: @Sendable @escaping (HealthMeasurement) -> Void
    ) async throws -> PlatformObservationToken
}

/// Token representing an active observation that can be cancelled
public final class PlatformObservationToken: Sendable {
    /// Unique identifier for the observation
    public let id: String
    
    /// The type being observed
    public let observedType: String
    
    private let _cancelHandler: @Sendable () -> Void
    
    /// Creates a new observation token
    public init(
        id: String = UUID().uuidString,
        observedType: String,
        cancelHandler: @Sendable @escaping () -> Void
    ) {
        self.id = id
        self.observedType = observedType
        self._cancelHandler = cancelHandler
    }
    
    /// Cancel the observation
    public func cancel() {
        _cancelHandler()
    }
}

// MARK: - CareKit Integration Protocol

/// Represents a care plan task that can be exchanged with care management platforms
public struct CareTask: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Title of the task
    public let title: String
    
    /// Detailed instructions
    public let instructions: String?
    
    /// Category of the task
    public let category: CareTaskCategory
    
    /// Schedule for the task
    public let schedule: TaskSchedule
    
    /// Whether the task is currently active
    public let isActive: Bool
    
    /// Associated patient identifier
    public let patientId: String?
    
    /// Associated care plan identifier
    public let carePlanId: String?
    
    /// Creates a new care task
    public init(
        id: String = UUID().uuidString,
        title: String,
        instructions: String? = nil,
        category: CareTaskCategory = .other,
        schedule: TaskSchedule = TaskSchedule(),
        isActive: Bool = true,
        patientId: String? = nil,
        carePlanId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.category = category
        self.schedule = schedule
        self.isActive = isActive
        self.patientId = patientId
        self.carePlanId = carePlanId
    }
}

/// Category for care tasks
public enum CareTaskCategory: String, Sendable, Codable, Hashable {
    case medication
    case exercise
    case nutrition
    case monitoring
    case appointment
    case education
    case other
}

/// Schedule for a care task
public struct TaskSchedule: Sendable, Codable, Hashable {
    /// Start date of the schedule
    public let startDate: Date?
    
    /// End date of the schedule
    public let endDate: Date?
    
    /// Frequency in times per day
    public let frequencyPerDay: Int
    
    /// Specific times of day (hours in 24h format)
    public let timesOfDay: [Int]?
    
    /// Days of the week (1=Sunday, 7=Saturday)
    public let daysOfWeek: [Int]?
    
    /// Creates a new task schedule
    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        frequencyPerDay: Int = 1,
        timesOfDay: [Int]? = nil,
        daysOfWeek: [Int]? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.frequencyPerDay = frequencyPerDay
        self.timesOfDay = timesOfDay
        self.daysOfWeek = daysOfWeek
    }
}

/// Represents the outcome of completing a care task
public struct CareOutcome: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Associated task identifier
    public let taskId: String
    
    /// When the outcome was recorded
    public let timestamp: Date
    
    /// Values associated with the outcome
    public let values: [OutcomeValue]
    
    /// Notes from the patient or caregiver
    public let note: String?
    
    /// Creates a new care outcome
    public init(
        id: String = UUID().uuidString,
        taskId: String,
        timestamp: Date = Date(),
        values: [OutcomeValue] = [],
        note: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.timestamp = timestamp
        self.values = values
        self.note = note
    }
}

/// A value recorded as part of a care outcome
public struct OutcomeValue: Sendable, Codable, Hashable {
    /// Kind of value
    public let kind: String
    
    /// Numeric value (if applicable)
    public let numericValue: Double?
    
    /// Text value (if applicable)
    public let textValue: String?
    
    /// Boolean value (if applicable)
    public let booleanValue: Bool?
    
    /// Unit of measurement
    public let unit: String?
    
    /// Creates a new outcome value
    public init(
        kind: String,
        numericValue: Double? = nil,
        textValue: String? = nil,
        booleanValue: Bool? = nil,
        unit: String? = nil
    ) {
        self.kind = kind
        self.numericValue = numericValue
        self.textValue = textValue
        self.booleanValue = booleanValue
        self.unit = unit
    }
}

/// Protocol for integrating HL7 data with care management platforms (e.g., CareKit)
///
/// Implement this protocol to bridge between HL7kit messages and care plan management systems.
/// Supports care tasks, outcomes, and care plan synchronization.
public protocol CareDataProvider: Sendable {
    /// Fetch care tasks for a patient
    func fetchTasks(forPatient patientId: String) async throws -> [CareTask]
    
    /// Create a new care task
    func createTask(_ task: CareTask) async throws
    
    /// Update an existing care task
    func updateTask(_ task: CareTask) async throws
    
    /// Delete a care task by ID
    func deleteTask(withId id: String) async throws
    
    /// Record an outcome for a task
    func recordOutcome(_ outcome: CareOutcome) async throws
    
    /// Fetch outcomes for a task within a date range
    func fetchOutcomes(
        forTask taskId: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [CareOutcome]
}

// MARK: - ResearchKit Integration Protocol

/// Represents a research survey question
public struct SurveyQuestion: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Question text
    public let text: String
    
    /// Type of answer expected
    public let answerType: AnswerType
    
    /// Whether the question is required
    public let isRequired: Bool
    
    /// Available choices for multiple-choice questions
    public let choices: [String]?
    
    /// Minimum value for numeric questions
    public let minimumValue: Double?
    
    /// Maximum value for numeric questions
    public let maximumValue: Double?
    
    /// Creates a new survey question
    public init(
        id: String = UUID().uuidString,
        text: String,
        answerType: AnswerType = .text,
        isRequired: Bool = true,
        choices: [String]? = nil,
        minimumValue: Double? = nil,
        maximumValue: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.answerType = answerType
        self.isRequired = isRequired
        self.choices = choices
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
    }
}

/// Type of answer for a survey question
public enum AnswerType: String, Sendable, Codable, Hashable {
    case text
    case numeric
    case boolean
    case date
    case singleChoice = "single_choice"
    case multipleChoice = "multiple_choice"
    case scale
}

/// Represents a research survey
public struct ResearchSurvey: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Title of the survey
    public let title: String
    
    /// Description of the survey
    public let description: String?
    
    /// Questions in the survey
    public let questions: [SurveyQuestion]
    
    /// Version of the survey
    public let version: String
    
    /// Creates a new research survey
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        questions: [SurveyQuestion] = [],
        version: String = "1.0"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.questions = questions
        self.version = version
    }
}

/// Represents a response to a survey question
public struct SurveyAnswer: Sendable, Codable, Hashable {
    /// Question identifier
    public let questionId: String
    
    /// Text answer
    public let textValue: String?
    
    /// Numeric answer
    public let numericValue: Double?
    
    /// Boolean answer
    public let booleanValue: Bool?
    
    /// Date answer
    public let dateValue: Date?
    
    /// Selected choices (for multiple choice)
    public let selectedChoices: [String]?
    
    /// Creates a new survey answer
    public init(
        questionId: String,
        textValue: String? = nil,
        numericValue: Double? = nil,
        booleanValue: Bool? = nil,
        dateValue: Date? = nil,
        selectedChoices: [String]? = nil
    ) {
        self.questionId = questionId
        self.textValue = textValue
        self.numericValue = numericValue
        self.booleanValue = booleanValue
        self.dateValue = dateValue
        self.selectedChoices = selectedChoices
    }
}

/// Represents a completed survey response
public struct SurveyResponse: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Survey identifier
    public let surveyId: String
    
    /// Participant identifier
    public let participantId: String
    
    /// When the survey was completed
    public let completedAt: Date
    
    /// Answers to the survey questions
    public let answers: [SurveyAnswer]
    
    /// Creates a new survey response
    public init(
        id: String = UUID().uuidString,
        surveyId: String,
        participantId: String,
        completedAt: Date = Date(),
        answers: [SurveyAnswer] = []
    ) {
        self.id = id
        self.surveyId = surveyId
        self.participantId = participantId
        self.completedAt = completedAt
        self.answers = answers
    }
}

/// Consent status for research participation
public enum ConsentStatus: String, Sendable, Codable, Hashable {
    case pending
    case consented
    case declined
    case withdrawn
    case expired
}

/// Represents a research consent record
public struct ResearchConsent: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Study identifier
    public let studyId: String
    
    /// Participant identifier
    public let participantId: String
    
    /// Current consent status
    public let status: ConsentStatus
    
    /// When consent was given or updated
    public let timestamp: Date
    
    /// Version of the consent document
    public let consentVersion: String
    
    /// Digital signature (if applicable)
    public let signature: String?
    
    /// Creates a new research consent
    public init(
        id: String = UUID().uuidString,
        studyId: String,
        participantId: String,
        status: ConsentStatus = .pending,
        timestamp: Date = Date(),
        consentVersion: String = "1.0",
        signature: String? = nil
    ) {
        self.id = id
        self.studyId = studyId
        self.participantId = participantId
        self.status = status
        self.timestamp = timestamp
        self.consentVersion = consentVersion
        self.signature = signature
    }
}

/// Protocol for integrating HL7 data with research platforms (e.g., ResearchKit)
///
/// Implement this protocol to bridge between HL7kit messages and research data collection systems.
/// Supports surveys, consent management, and research data collection.
public protocol ResearchDataProvider: Sendable {
    /// Fetch available surveys
    func fetchSurveys() async throws -> [ResearchSurvey]
    
    /// Submit a completed survey response
    func submitResponse(_ response: SurveyResponse) async throws
    
    /// Fetch responses for a survey
    func fetchResponses(forSurvey surveyId: String) async throws -> [SurveyResponse]
    
    /// Record consent status
    func recordConsent(_ consent: ResearchConsent) async throws
    
    /// Get consent status for a participant in a study
    func getConsentStatus(
        forParticipant participantId: String,
        inStudy studyId: String
    ) async throws -> ConsentStatus
}

// MARK: - Cloud Sync Protocol

/// Represents the sync state for a record
public enum SyncState: String, Sendable, Codable, Hashable {
    case pending
    case syncing
    case synced
    case conflict
    case failed
}

/// Represents a syncable record
public struct SyncRecord: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Type of the record (e.g., "message", "patient", "observation")
    public let recordType: String
    
    /// The serialized data payload
    public let payload: Data
    
    /// Current sync state
    public let syncState: SyncState
    
    /// Last modified timestamp
    public let lastModified: Date
    
    /// Version number for conflict resolution
    public let version: Int
    
    /// Zone identifier for iCloud partitioning
    public let zoneId: String?
    
    /// Creates a new sync record
    public init(
        id: String = UUID().uuidString,
        recordType: String,
        payload: Data,
        syncState: SyncState = .pending,
        lastModified: Date = Date(),
        version: Int = 1,
        zoneId: String? = nil
    ) {
        self.id = id
        self.recordType = recordType
        self.payload = payload
        self.syncState = syncState
        self.lastModified = lastModified
        self.version = version
        self.zoneId = zoneId
    }
}

/// Strategy for resolving sync conflicts
public enum ConflictResolutionStrategy: String, Sendable, Codable, Hashable {
    case localWins = "local_wins"
    case remoteWins = "remote_wins"
    case mostRecent = "most_recent"
    case manual
}

/// Represents a sync conflict between local and remote records
public struct SyncConflict: Sendable, Codable, Hashable {
    /// The local version of the record
    public let localRecord: SyncRecord
    
    /// The remote version of the record
    public let remoteRecord: SyncRecord
    
    /// Creates a new sync conflict
    public init(localRecord: SyncRecord, remoteRecord: SyncRecord) {
        self.localRecord = localRecord
        self.remoteRecord = remoteRecord
    }
}

/// Protocol for cloud data synchronization (e.g., iCloud, CloudKit)
///
/// Implement this protocol to enable cloud sync of HL7 data.
/// Supports record-level sync with conflict resolution.
public protocol CloudSyncProvider: Sendable {
    /// Push local records to the cloud
    func pushRecords(_ records: [SyncRecord]) async throws
    
    /// Pull records from the cloud
    func pullRecords(ofType recordType: String, since date: Date?) async throws -> [SyncRecord]
    
    /// Resolve a sync conflict using the given strategy
    func resolveConflict(
        _ conflict: SyncConflict,
        strategy: ConflictResolutionStrategy
    ) async throws -> SyncRecord
    
    /// Get the current sync state for a record
    func getSyncState(forRecord id: String) async throws -> SyncState
    
    /// Subscribe to sync state changes
    func observeSyncChanges(
        handler: @Sendable @escaping (SyncRecord) -> Void
    ) async throws -> PlatformObservationToken
    
    /// Get the last successful sync date
    func lastSyncDate() async throws -> Date?
}

// MARK: - Handoff Protocol

/// Represents an activity that can be handed off between devices
public struct HandoffActivity: Sendable, Codable, Hashable {
    /// Unique activity type identifier (reverse DNS, e.g., "com.myapp.viewPatient")
    public let activityType: String
    
    /// Human-readable title
    public let title: String
    
    /// Key-value pairs of user info for the activity
    public let userInfo: [String: String]
    
    /// Whether the activity is eligible for handoff
    public let isEligibleForHandoff: Bool
    
    /// Whether the activity is eligible for search
    public let isEligibleForSearch: Bool
    
    /// Whether the activity is eligible for public indexing
    public let isEligibleForPublicIndexing: Bool
    
    /// Keywords for search indexing
    public let keywords: [String]
    
    /// Web page URL for universal link support
    public let webpageURL: String?
    
    /// Creates a new handoff activity
    public init(
        activityType: String,
        title: String,
        userInfo: [String: String] = [:],
        isEligibleForHandoff: Bool = true,
        isEligibleForSearch: Bool = false,
        isEligibleForPublicIndexing: Bool = false,
        keywords: [String] = [],
        webpageURL: String? = nil
    ) {
        self.activityType = activityType
        self.title = title
        self.userInfo = userInfo
        self.isEligibleForHandoff = isEligibleForHandoff
        self.isEligibleForSearch = isEligibleForSearch
        self.isEligibleForPublicIndexing = isEligibleForPublicIndexing
        self.keywords = keywords
        self.webpageURL = webpageURL
    }
}

/// Protocol for device-to-device activity handoff (e.g., NSUserActivity)
///
/// Implement this protocol to enable Handoff of HL7 data viewing/editing activities
/// between Apple devices.
public protocol HandoffProvider: Sendable {
    /// Register an activity for handoff
    func registerActivity(_ activity: HandoffActivity) async throws
    
    /// Update an existing activity
    func updateActivity(_ activity: HandoffActivity) async throws
    
    /// Invalidate an activity (stop advertising for handoff)
    func invalidateActivity(ofType activityType: String) async throws
    
    /// Handle an incoming handoff activity
    func handleIncomingActivity(_ activity: HandoffActivity) async throws
    
    /// Check if handoff is available
    func isHandoffAvailable() async -> Bool
}

// MARK: - Shortcuts / Intent Protocol

/// Represents a shortcut action that can be invoked via Siri or Shortcuts app
public struct ShortcutAction: Sendable, Codable, Hashable {
    /// Unique identifier
    public let id: String
    
    /// Intent identifier (e.g., "com.myapp.lookupPatient")
    public let intentIdentifier: String
    
    /// User-visible title
    public let title: String
    
    /// Suggested invocation phrase for Siri
    public let suggestedPhrase: String?
    
    /// Description of what the shortcut does
    public let shortcutDescription: String?
    
    /// Input parameters
    public let parameters: [ShortcutParameter]
    
    /// Creates a new shortcut action
    public init(
        id: String = UUID().uuidString,
        intentIdentifier: String,
        title: String,
        suggestedPhrase: String? = nil,
        shortcutDescription: String? = nil,
        parameters: [ShortcutParameter] = []
    ) {
        self.id = id
        self.intentIdentifier = intentIdentifier
        self.title = title
        self.suggestedPhrase = suggestedPhrase
        self.shortcutDescription = shortcutDescription
        self.parameters = parameters
    }
}

/// A parameter for a shortcut action
public struct ShortcutParameter: Sendable, Codable, Hashable {
    /// Parameter name
    public let name: String
    
    /// Parameter type
    public let type: ShortcutParameterType
    
    /// Whether the parameter is required
    public let isRequired: Bool
    
    /// Default value (as string)
    public let defaultValue: String?
    
    /// Creates a new shortcut parameter
    public init(
        name: String,
        type: ShortcutParameterType = .string,
        isRequired: Bool = true,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.type = type
        self.isRequired = isRequired
        self.defaultValue = defaultValue
    }
}

/// Type of a shortcut parameter
public enum ShortcutParameterType: String, Sendable, Codable, Hashable {
    case string
    case integer
    case decimal
    case boolean
    case date
    case url
}

/// Result of executing a shortcut
public struct ShortcutResult: Sendable, Codable, Hashable {
    /// Whether the shortcut executed successfully
    public let success: Bool
    
    /// Human-readable response message
    public let responseMessage: String
    
    /// Output data (if any)
    public let outputData: [String: String]?
    
    /// Creates a new shortcut result
    public init(
        success: Bool,
        responseMessage: String,
        outputData: [String: String]? = nil
    ) {
        self.success = success
        self.responseMessage = responseMessage
        self.outputData = outputData
    }
}

/// Protocol for Siri shortcuts and App Intents integration
///
/// Implement this protocol to enable voice-activated and shortcut-based
/// access to HL7 data operations.
public protocol ShortcutsProvider: Sendable {
    /// Register a shortcut action
    func registerShortcut(_ action: ShortcutAction) async throws
    
    /// Remove a registered shortcut
    func removeShortcut(withId id: String) async throws
    
    /// Execute a shortcut with parameters
    func executeShortcut(
        withIdentifier intentIdentifier: String,
        parameters: [String: String]
    ) async throws -> ShortcutResult
    
    /// List all registered shortcuts
    func listShortcuts() async throws -> [ShortcutAction]
    
    /// Donate an interaction (for Siri suggestions)
    func donateInteraction(for action: ShortcutAction) async throws
}

// MARK: - Platform Integration Manager

/// Centralized manager for all platform integrations
///
/// Provides a single point of access to register and use platform-specific providers.
/// Uses actor isolation for thread-safe provider management.
///
/// Example usage:
/// ```swift
/// let manager = PlatformIntegrationManager()
/// await manager.registerHealthDataProvider(myHealthKitAdapter)
/// let measurements = try await manager.readHealthMeasurements(ofType: "heart_rate", from: start, to: end)
/// ```
public actor PlatformIntegrationManager {
    /// Registered health data provider
    private var healthProvider: (any HealthDataProvider)?
    
    /// Registered care data provider
    private var careProvider: (any CareDataProvider)?
    
    /// Registered research data provider
    private var researchProvider: (any ResearchDataProvider)?
    
    /// Registered cloud sync provider
    private var cloudSyncProvider: (any CloudSyncProvider)?
    
    /// Registered handoff provider
    private var handoffProvider: (any HandoffProvider)?
    
    /// Registered shortcuts provider
    private var shortcutsProvider: (any ShortcutsProvider)?
    
    /// Active observation tokens
    private var activeObservations: [String: PlatformObservationToken]
    
    /// Creates a new platform integration manager
    public init() {
        self.activeObservations = [:]
    }
    
    // MARK: - Provider Registration
    
    /// Register a health data provider
    public func registerHealthDataProvider(_ provider: any HealthDataProvider) {
        self.healthProvider = provider
    }
    
    /// Register a care data provider
    public func registerCareDataProvider(_ provider: any CareDataProvider) {
        self.careProvider = provider
    }
    
    /// Register a research data provider
    public func registerResearchDataProvider(_ provider: any ResearchDataProvider) {
        self.researchProvider = provider
    }
    
    /// Register a cloud sync provider
    public func registerCloudSyncProvider(_ provider: any CloudSyncProvider) {
        self.cloudSyncProvider = provider
    }
    
    /// Register a handoff provider
    public func registerHandoffProvider(_ provider: any HandoffProvider) {
        self.handoffProvider = provider
    }
    
    /// Register a shortcuts provider
    public func registerShortcutsProvider(_ provider: any ShortcutsProvider) {
        self.shortcutsProvider = provider
    }
    
    // MARK: - Provider Access
    
    /// Get the registered health data provider
    public func getHealthDataProvider() -> (any HealthDataProvider)? {
        healthProvider
    }
    
    /// Get the registered care data provider
    public func getCareDataProvider() -> (any CareDataProvider)? {
        careProvider
    }
    
    /// Get the registered research data provider
    public func getResearchDataProvider() -> (any ResearchDataProvider)? {
        researchProvider
    }
    
    /// Get the registered cloud sync provider
    public func getCloudSyncProvider() -> (any CloudSyncProvider)? {
        cloudSyncProvider
    }
    
    /// Get the registered handoff provider
    public func getHandoffProvider() -> (any HandoffProvider)? {
        handoffProvider
    }
    
    /// Get the registered shortcuts provider
    public func getShortcutsProvider() -> (any ShortcutsProvider)? {
        shortcutsProvider
    }
    
    // MARK: - Convenience Methods
    
    /// Read health measurements using the registered provider
    public func readHealthMeasurements(
        ofType type: String,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthMeasurement] {
        guard let provider = healthProvider else {
            throw HL7Error.configurationError("No health data provider registered")
        }
        return try await provider.readMeasurements(ofType: type, from: startDate, to: endDate)
    }
    
    /// Write a health measurement using the registered provider
    public func writeHealthMeasurement(_ measurement: HealthMeasurement) async throws {
        guard let provider = healthProvider else {
            throw HL7Error.configurationError("No health data provider registered")
        }
        try await provider.writeMeasurement(measurement)
    }
    
    /// Fetch care tasks for a patient using the registered provider
    public func fetchCareTasks(forPatient patientId: String) async throws -> [CareTask] {
        guard let provider = careProvider else {
            throw HL7Error.configurationError("No care data provider registered")
        }
        return try await provider.fetchTasks(forPatient: patientId)
    }
    
    /// Submit a research survey response using the registered provider
    public func submitSurveyResponse(_ response: SurveyResponse) async throws {
        guard let provider = researchProvider else {
            throw HL7Error.configurationError("No research data provider registered")
        }
        try await provider.submitResponse(response)
    }
    
    /// Push records to the cloud using the registered provider
    public func pushToCloud(_ records: [SyncRecord]) async throws {
        guard let provider = cloudSyncProvider else {
            throw HL7Error.configurationError("No cloud sync provider registered")
        }
        try await provider.pushRecords(records)
    }
    
    /// Register a handoff activity using the registered provider
    public func registerHandoffActivity(_ activity: HandoffActivity) async throws {
        guard let provider = handoffProvider else {
            throw HL7Error.configurationError("No handoff provider registered")
        }
        try await provider.registerActivity(activity)
    }
    
    /// Execute a shortcut using the registered provider
    public func executeShortcut(
        withIdentifier id: String,
        parameters: [String: String] = [:]
    ) async throws -> ShortcutResult {
        guard let provider = shortcutsProvider else {
            throw HL7Error.configurationError("No shortcuts provider registered")
        }
        return try await provider.executeShortcut(withIdentifier: id, parameters: parameters)
    }
    
    // MARK: - Observation Management
    
    /// Start observing health data changes
    public func startObservingHealth(
        forType type: String,
        handler: @Sendable @escaping (HealthMeasurement) -> Void
    ) async throws -> String {
        guard let provider = healthProvider else {
            throw HL7Error.configurationError("No health data provider registered")
        }
        let token = try await provider.observeChanges(forType: type, handler: handler)
        activeObservations[token.id] = token
        return token.id
    }
    
    /// Stop an active observation
    public func stopObservation(withId id: String) {
        if let token = activeObservations.removeValue(forKey: id) {
            token.cancel()
        }
    }
    
    /// Stop all active observations
    public func stopAllObservations() {
        for (_, token) in activeObservations {
            token.cancel()
        }
        activeObservations.removeAll()
    }
    
    /// Get the count of active observations
    public func activeObservationCount() -> Int {
        activeObservations.count
    }
    
    // MARK: - Status
    
    /// Check which providers are registered
    public func registeredProviders() -> [String] {
        var providers: [String] = []
        if healthProvider != nil { providers.append("HealthData") }
        if careProvider != nil { providers.append("CareData") }
        if researchProvider != nil { providers.append("ResearchData") }
        if cloudSyncProvider != nil { providers.append("CloudSync") }
        if handoffProvider != nil { providers.append("Handoff") }
        if shortcutsProvider != nil { providers.append("Shortcuts") }
        return providers
    }
}

// MARK: - Vital Sign to HL7 Mapping Utilities

/// Utility for converting between platform health data and HL7 message fields
public enum HealthDataMapper: Sendable {
    
    /// Maps a vital sign type to its LOINC code
    public static func loincCode(for vitalSign: VitalSignType) -> String {
        switch vitalSign {
        case .heartRate: return "8867-4"
        case .bloodPressure: return "85354-9"
        case .bodyTemperature: return "8310-5"
        case .respiratoryRate: return "9279-1"
        case .oxygenSaturation: return "2708-6"
        case .bodyWeight: return "29463-7"
        case .bodyHeight: return "8302-2"
        case .bodyMassIndex: return "39156-5"
        case .bloodGlucose: return "2345-7"
        case .stepCount: return "55423-8"
        }
    }
    
    /// Maps a vital sign type to its display name
    public static func displayName(for vitalSign: VitalSignType) -> String {
        switch vitalSign {
        case .heartRate: return "Heart Rate"
        case .bloodPressure: return "Blood Pressure"
        case .bodyTemperature: return "Body Temperature"
        case .respiratoryRate: return "Respiratory Rate"
        case .oxygenSaturation: return "Oxygen Saturation"
        case .bodyWeight: return "Body Weight"
        case .bodyHeight: return "Body Height"
        case .bodyMassIndex: return "Body Mass Index"
        case .bloodGlucose: return "Blood Glucose"
        case .stepCount: return "Step Count"
        }
    }
    
    /// Maps a vital sign type to its standard unit
    public static func standardUnit(for vitalSign: VitalSignType) -> String {
        switch vitalSign {
        case .heartRate: return "bpm"
        case .bloodPressure: return "mmHg"
        case .bodyTemperature: return "°C"
        case .respiratoryRate: return "breaths/min"
        case .oxygenSaturation: return "%"
        case .bodyWeight: return "kg"
        case .bodyHeight: return "cm"
        case .bodyMassIndex: return "kg/m2"
        case .bloodGlucose: return "mg/dL"
        case .stepCount: return "steps"
        }
    }
    
    /// Maps a vital sign type to its UCUM (Unified Code for Units of Measure) code
    public static func ucumCode(for vitalSign: VitalSignType) -> String {
        switch vitalSign {
        case .heartRate: return "/min"
        case .bloodPressure: return "mm[Hg]"
        case .bodyTemperature: return "Cel"
        case .respiratoryRate: return "/min"
        case .oxygenSaturation: return "%"
        case .bodyWeight: return "kg"
        case .bodyHeight: return "cm"
        case .bodyMassIndex: return "kg/m2"
        case .bloodGlucose: return "mg/dL"
        case .stepCount: return "{steps}"
        }
    }
    
    /// Convert a HealthMeasurement to a VitalSign if the type matches
    public static func toVitalSign(_ measurement: HealthMeasurement) -> VitalSign? {
        guard let type = VitalSignType(rawValue: measurement.measurementType) else {
            return nil
        }
        return VitalSign(
            id: measurement.id,
            type: type,
            primaryValue: measurement.value,
            unit: measurement.unit,
            timestamp: measurement.timestamp
        )
    }
    
    /// Convert a VitalSign to a HealthMeasurement
    public static func toHealthMeasurement(_ vitalSign: VitalSign) -> HealthMeasurement {
        HealthMeasurement(
            id: vitalSign.id,
            measurementType: vitalSign.type.rawValue,
            value: vitalSign.primaryValue,
            unit: vitalSign.unit,
            timestamp: vitalSign.timestamp,
            source: nil,
            metadata: vitalSign.secondaryValue.map { ["secondaryValue": String($0)] }
        )
    }
}
