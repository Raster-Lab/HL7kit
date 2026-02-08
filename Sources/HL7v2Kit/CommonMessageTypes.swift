/// Common HL7 v2.x message types with typed accessors and validation
///
/// Provides structured representations for ADT, ORM, ORU, ACK, and QRY/QBP
/// message types with convenience accessors for common fields, segment-level
/// validation, and message-specific business rules.

import Foundation
import HL7Core

// MARK: - MessageTypeProtocol

/// Protocol for typed HL7 v2.x message wrappers
///
/// Conforming types wrap an ``HL7v2Message`` and provide typed accessors
/// for message-specific segments and fields, along with validation rules.
public protocol HL7v2TypedMessage: Sendable {
    /// The wrapped raw message
    var message: HL7v2Message { get }

    /// The expected message type code (e.g., "ADT", "ORM")
    static var messageTypeCode: String { get }

    /// Validate the message according to type-specific rules
    /// - Throws: ``HL7Error`` if validation fails
    func validate() throws
}

// MARK: - Validation Rule

/// A single validation rule for a message type
public struct MessageValidationRule: Sendable {
    /// Human-readable description of the rule
    public let description: String
    /// Validation function returning `true` if the rule passes
    public let check: @Sendable (HL7v2Message) -> Bool

    /// Creates a validation rule
    /// - Parameters:
    ///   - description: Human-readable description
    ///   - check: Closure returning `true` when the rule is satisfied
    public init(description: String, check: @escaping @Sendable (HL7v2Message) -> Bool) {
        self.description = description
        self.check = check
    }
}

/// Result of validating a typed message
public struct MessageValidationResult: Sendable, Equatable {
    /// Whether all rules passed
    public let isValid: Bool
    /// Descriptions of failed rules
    public let failures: [String]

    /// Creates a validation result
    public init(isValid: Bool, failures: [String]) {
        self.isValid = isValid
        self.failures = failures
    }
}

// MARK: - Shared Helpers

/// Check whether a message contains at least one segment with the given ID
private func hasSegment(_ id: String, in message: HL7v2Message) -> Bool {
    return !message.segments(withID: id).isEmpty
}

/// Get the first segment with the given ID, or nil
private func firstSegment(_ id: String, in message: HL7v2Message) -> BaseSegment? {
    return message.segments(withID: id).first
}

// MARK: - ADT Message

/// ADT (Admit/Discharge/Transfer) message
///
/// ADT messages manage patient administration events. Common trigger events:
/// - A01: Admit/Visit Notification
/// - A02: Transfer a Patient
/// - A03: Discharge/End Visit
/// - A04: Register a Patient
/// - A05: Pre-admit a Patient
/// - A08: Update Patient Information
/// - A11: Cancel Admit
/// - A12: Cancel Transfer
/// - A13: Cancel Discharge
///
/// Required segments: MSH, EVN, PID, PV1
public struct ADTMessage: HL7v2TypedMessage {

    public let message: HL7v2Message
    public static let messageTypeCode = "ADT"

    /// Known ADT trigger events
    public enum TriggerEvent: String, Sendable, CaseIterable {
        case admit = "A01"
        case transfer = "A02"
        case discharge = "A03"
        case register = "A04"
        case preAdmit = "A05"
        case updatePatientInfo = "A08"
        case cancelAdmit = "A11"
        case cancelTransfer = "A12"
        case cancelDischarge = "A13"
    }

    // MARK: - Initialization

    /// Wrap an existing ``HL7v2Message`` as an ADT message
    /// - Parameter message: Raw HL7 v2.x message
    /// - Throws: ``HL7Error`` if the message type does not match
    public init(message: HL7v2Message) throws {
        let type = message.messageType()
        guard type.hasPrefix("ADT") else {
            throw HL7Error.validationError("Expected ADT message type, got: \(type)")
        }
        self.message = message
    }

    /// Create an ADT message from a raw string
    /// - Parameter rawValue: Raw HL7 message string
    /// - Returns: Typed ADT message
    /// - Throws: ``HL7Error`` on parse or type mismatch
    public static func parse(_ rawValue: String) throws -> ADTMessage {
        let msg = try HL7v2Message.parse(rawValue)
        return try ADTMessage(message: msg)
    }

    // MARK: - Segment Accessors

    /// Event type segment (EVN)
    public var eventSegment: BaseSegment? { firstSegment("EVN", in: message) }

    /// Patient identification segment (PID)
    public var patientSegment: BaseSegment? { firstSegment("PID", in: message) }

    /// Patient visit segment (PV1)
    public var visitSegment: BaseSegment? { firstSegment("PV1", in: message) }

    /// Patient additional demographic segment (PD1)
    public var additionalDemographics: BaseSegment? { firstSegment("PD1", in: message) }

    /// Patient visit additional info segment (PV2)
    public var visitAdditionalInfo: BaseSegment? { firstSegment("PV2", in: message) }

    /// Next of kin segments (NK1) — may repeat
    public var nextOfKinSegments: [BaseSegment] { message.segments(withID: "NK1") }

    /// Allergy segments (AL1) — may repeat
    public var allergySegments: [BaseSegment] { message.segments(withID: "AL1") }

    /// Diagnosis segments (DG1) — may repeat
    public var diagnosisSegments: [BaseSegment] { message.segments(withID: "DG1") }

    /// Observation segments (OBX) — may repeat
    public var observationSegments: [BaseSegment] { message.segments(withID: "OBX") }

    // MARK: - Convenience Field Accessors

    /// Trigger event code from MSH-9 second component (e.g., "A01")
    public var triggerEvent: String {
        let msh = message.messageHeader
        return msh[8][1].value.raw
    }

    /// Patient identifier list (PID-3)
    public var patientIdentifier: String {
        patientSegment?[2].serialize() ?? ""
    }

    /// Patient name (PID-5)
    public var patientName: String {
        patientSegment?[4].serialize() ?? ""
    }

    /// Date of birth (PID-7)
    public var dateOfBirth: String {
        patientSegment?[6].value.value.raw ?? ""
    }

    /// Administrative sex (PID-8)
    public var sex: String {
        patientSegment?[7].value.value.raw ?? ""
    }

    /// Patient class from PV1-2 (I=Inpatient, O=Outpatient, E=Emergency)
    public var patientClass: String {
        visitSegment?[1].value.value.raw ?? ""
    }

    /// Assigned patient location (PV1-3)
    public var assignedLocation: String {
        visitSegment?[2].serialize() ?? ""
    }

    /// Attending doctor (PV1-7)
    public var attendingDoctor: String {
        visitSegment?[6].serialize() ?? ""
    }

    /// Visit number (PV1-19)
    public var visitNumber: String {
        visitSegment?[18].value.value.raw ?? ""
    }

    // MARK: - Validation

    /// Validation rules for ADT messages
    public static let validationRules: [MessageValidationRule] = [
        MessageValidationRule(description: "MSH segment is required") { msg in
            msg.messageHeader.segmentID == "MSH"
        },
        MessageValidationRule(description: "EVN segment is required") { msg in
            hasSegment("EVN", in: msg)
        },
        MessageValidationRule(description: "PID segment is required") { msg in
            hasSegment("PID", in: msg)
        },
        MessageValidationRule(description: "PV1 segment is required") { msg in
            hasSegment("PV1", in: msg)
        },
        MessageValidationRule(description: "MSH-9 must contain ADT message type") { msg in
            msg.messageType().hasPrefix("ADT")
        },
    ]

    public func validate() throws {
        let result = validateRules(Self.validationRules, message: message)
        guard result.isValid else {
            throw HL7Error.validationError("ADT validation failed: \(result.failures.joined(separator: "; "))")
        }
    }

    /// Run validation rules and return detailed result
    public func validateDetailed() -> MessageValidationResult {
        return validateRules(Self.validationRules, message: message)
    }
}

// MARK: - ORM Message

/// ORM (Order Entry) message
///
/// ORM messages carry requests for clinical services including lab tests,
/// procedures, medications, and other orders.
///
/// Common trigger events:
/// - O01: Order Message
///
/// Required segments: MSH, PID, ORC
public struct ORMMessage: HL7v2TypedMessage {

    public let message: HL7v2Message
    public static let messageTypeCode = "ORM"

    // MARK: - Initialization

    /// Wrap an existing ``HL7v2Message`` as an ORM message
    /// - Parameter message: Raw HL7 v2.x message
    /// - Throws: ``HL7Error`` if the message type does not match
    public init(message: HL7v2Message) throws {
        let type = message.messageType()
        guard type.hasPrefix("ORM") else {
            throw HL7Error.validationError("Expected ORM message type, got: \(type)")
        }
        self.message = message
    }

    /// Create an ORM message from a raw string
    public static func parse(_ rawValue: String) throws -> ORMMessage {
        let msg = try HL7v2Message.parse(rawValue)
        return try ORMMessage(message: msg)
    }

    // MARK: - Segment Accessors

    /// Patient identification segment (PID)
    public var patientSegment: BaseSegment? { firstSegment("PID", in: message) }

    /// Patient visit segment (PV1)
    public var visitSegment: BaseSegment? { firstSegment("PV1", in: message) }

    /// Common order segments (ORC) — may repeat
    public var orderControlSegments: [BaseSegment] { message.segments(withID: "ORC") }

    /// Observation request segments (OBR) — may repeat
    public var observationRequestSegments: [BaseSegment] { message.segments(withID: "OBR") }

    /// Notes/comments segments (NTE) — may repeat
    public var noteSegments: [BaseSegment] { message.segments(withID: "NTE") }

    /// Insurance segments (IN1) — may repeat
    public var insuranceSegments: [BaseSegment] { message.segments(withID: "IN1") }

    /// Allergy segments (AL1) — may repeat
    public var allergySegments: [BaseSegment] { message.segments(withID: "AL1") }

    // MARK: - Convenience Field Accessors

    /// First ORC order control code (ORC-1): NW=New, CA=Cancel, DC=Discontinue
    public var orderControl: String {
        orderControlSegments.first?[0].value.value.raw ?? ""
    }

    /// Placer order number (ORC-2)
    public var placerOrderNumber: String {
        orderControlSegments.first?[1].serialize() ?? ""
    }

    /// Filler order number (ORC-3)
    public var fillerOrderNumber: String {
        orderControlSegments.first?[2].serialize() ?? ""
    }

    /// Order status (ORC-5)
    public var orderStatus: String {
        orderControlSegments.first?[4].value.value.raw ?? ""
    }

    /// Universal service identifier from first OBR (OBR-4)
    public var universalServiceID: String {
        observationRequestSegments.first?[3].serialize() ?? ""
    }

    /// Observation date/time from first OBR (OBR-7)
    public var observationDateTime: String {
        observationRequestSegments.first?[6].value.value.raw ?? ""
    }

    /// Ordering provider from first OBR (OBR-16)
    public var orderingProvider: String {
        observationRequestSegments.first?[15].serialize() ?? ""
    }

    /// Patient identifier list (PID-3)
    public var patientIdentifier: String {
        patientSegment?[2].serialize() ?? ""
    }

    // MARK: - Validation

    public static let validationRules: [MessageValidationRule] = [
        MessageValidationRule(description: "MSH segment is required") { msg in
            msg.messageHeader.segmentID == "MSH"
        },
        MessageValidationRule(description: "PID segment is required") { msg in
            hasSegment("PID", in: msg)
        },
        MessageValidationRule(description: "At least one ORC segment is required") { msg in
            hasSegment("ORC", in: msg)
        },
        MessageValidationRule(description: "MSH-9 must contain ORM message type") { msg in
            msg.messageType().hasPrefix("ORM")
        },
    ]

    public func validate() throws {
        let result = validateRules(Self.validationRules, message: message)
        guard result.isValid else {
            throw HL7Error.validationError("ORM validation failed: \(result.failures.joined(separator: "; "))")
        }
    }

    /// Run validation rules and return detailed result
    public func validateDetailed() -> MessageValidationResult {
        return validateRules(Self.validationRules, message: message)
    }
}

// MARK: - ORU Message

/// ORU (Observation Result) message
///
/// ORU messages deliver results of observations, including laboratory,
/// radiology, and other diagnostic results.
///
/// Common trigger events:
/// - R01: Unsolicited Observation Message
///
/// Required segments: MSH, PID, OBR, OBX
public struct ORUMessage: HL7v2TypedMessage {

    public let message: HL7v2Message
    public static let messageTypeCode = "ORU"

    // MARK: - Initialization

    /// Wrap an existing ``HL7v2Message`` as an ORU message
    /// - Parameter message: Raw HL7 v2.x message
    /// - Throws: ``HL7Error`` if the message type does not match
    public init(message: HL7v2Message) throws {
        let type = message.messageType()
        guard type.hasPrefix("ORU") else {
            throw HL7Error.validationError("Expected ORU message type, got: \(type)")
        }
        self.message = message
    }

    /// Create an ORU message from a raw string
    public static func parse(_ rawValue: String) throws -> ORUMessage {
        let msg = try HL7v2Message.parse(rawValue)
        return try ORUMessage(message: msg)
    }

    // MARK: - Segment Accessors

    /// Patient identification segment (PID)
    public var patientSegment: BaseSegment? { firstSegment("PID", in: message) }

    /// Patient visit segment (PV1)
    public var visitSegment: BaseSegment? { firstSegment("PV1", in: message) }

    /// Observation request segments (OBR) — may repeat
    public var observationRequestSegments: [BaseSegment] { message.segments(withID: "OBR") }

    /// Observation/result segments (OBX) — may repeat
    public var observationSegments: [BaseSegment] { message.segments(withID: "OBX") }

    /// Notes/comments segments (NTE) — may repeat
    public var noteSegments: [BaseSegment] { message.segments(withID: "NTE") }

    // MARK: - Convenience Field Accessors

    /// Universal service identifier from first OBR (OBR-4)
    public var universalServiceID: String {
        observationRequestSegments.first?[3].serialize() ?? ""
    }

    /// Observation date/time from first OBR (OBR-7)
    public var observationDateTime: String {
        observationRequestSegments.first?[6].value.value.raw ?? ""
    }

    /// Patient identifier list (PID-3)
    public var patientIdentifier: String {
        patientSegment?[2].serialize() ?? ""
    }

    /// Patient name (PID-5)
    public var patientName: String {
        patientSegment?[4].serialize() ?? ""
    }

    /// Get all observation results as structured data
    /// - Returns: Array of observation result tuples
    public var observations: [ObservationResult] {
        return observationSegments.map { obx in
            ObservationResult(
                setID: obx[0].value.value.raw,
                valueType: obx[1].value.value.raw,
                identifier: obx[2].serialize(),
                value: obx[4].serialize(),
                units: obx[5].serialize(),
                referenceRange: obx[6].value.value.raw,
                abnormalFlags: obx[7].value.value.raw,
                resultStatus: obx[10].value.value.raw
            )
        }
    }

    // MARK: - Validation

    public static let validationRules: [MessageValidationRule] = [
        MessageValidationRule(description: "MSH segment is required") { msg in
            msg.messageHeader.segmentID == "MSH"
        },
        MessageValidationRule(description: "PID segment is required") { msg in
            hasSegment("PID", in: msg)
        },
        MessageValidationRule(description: "At least one OBR segment is required") { msg in
            hasSegment("OBR", in: msg)
        },
        MessageValidationRule(description: "At least one OBX segment is required") { msg in
            hasSegment("OBX", in: msg)
        },
        MessageValidationRule(description: "MSH-9 must contain ORU message type") { msg in
            msg.messageType().hasPrefix("ORU")
        },
    ]

    public func validate() throws {
        let result = validateRules(Self.validationRules, message: message)
        guard result.isValid else {
            throw HL7Error.validationError("ORU validation failed: \(result.failures.joined(separator: "; "))")
        }
    }

    /// Run validation rules and return detailed result
    public func validateDetailed() -> MessageValidationResult {
        return validateRules(Self.validationRules, message: message)
    }
}

/// Structured representation of an OBX observation result
public struct ObservationResult: Sendable, Equatable {
    /// Set ID (OBX-1)
    public let setID: String
    /// Value type (OBX-2): NM=Numeric, ST=String, CE=Coded Entry
    public let valueType: String
    /// Observation identifier (OBX-3)
    public let identifier: String
    /// Observation value (OBX-5)
    public let value: String
    /// Units (OBX-6)
    public let units: String
    /// Reference range (OBX-7)
    public let referenceRange: String
    /// Abnormal flags (OBX-8): N=Normal, H=High, L=Low
    public let abnormalFlags: String
    /// Result status (OBX-11): F=Final, P=Preliminary
    public let resultStatus: String

    /// Creates an observation result
    public init(
        setID: String,
        valueType: String,
        identifier: String,
        value: String,
        units: String,
        referenceRange: String,
        abnormalFlags: String,
        resultStatus: String
    ) {
        self.setID = setID
        self.valueType = valueType
        self.identifier = identifier
        self.value = value
        self.units = units
        self.referenceRange = referenceRange
        self.abnormalFlags = abnormalFlags
        self.resultStatus = resultStatus
    }
}

// MARK: - ACK Message

/// ACK (Acknowledgment) message
///
/// ACK messages acknowledge receipt and processing status of any HL7 message.
///
/// Required segments: MSH, MSA
public struct ACKMessage: HL7v2TypedMessage {

    public let message: HL7v2Message
    public static let messageTypeCode = "ACK"

    /// Standard acknowledgment codes
    public enum AcknowledgmentCode: String, Sendable, CaseIterable {
        /// Application Accept — message was successfully processed
        case accept = "AA"
        /// Application Error — message had errors but was processed
        case error = "AE"
        /// Application Reject — message was rejected and not processed
        case reject = "AR"
        /// Commit Accept — message was committed to safe storage
        case commitAccept = "CA"
        /// Commit Error — error during commit
        case commitError = "CE"
        /// Commit Reject — commit was rejected
        case commitReject = "CR"
    }

    // MARK: - Initialization

    /// Wrap an existing ``HL7v2Message`` as an ACK message
    /// - Parameter message: Raw HL7 v2.x message
    /// - Throws: ``HL7Error`` if the message type does not match
    public init(message: HL7v2Message) throws {
        let type = message.messageType()
        guard type.hasPrefix("ACK") else {
            throw HL7Error.validationError("Expected ACK message type, got: \(type)")
        }
        self.message = message
    }

    /// Create an ACK message from a raw string
    public static func parse(_ rawValue: String) throws -> ACKMessage {
        let msg = try HL7v2Message.parse(rawValue)
        return try ACKMessage(message: msg)
    }

    // MARK: - Segment Accessors

    /// Message acknowledgment segment (MSA)
    public var acknowledgmentSegment: BaseSegment? { firstSegment("MSA", in: message) }

    /// Error segments (ERR) — may repeat
    public var errorSegments: [BaseSegment] { message.segments(withID: "ERR") }

    // MARK: - Convenience Field Accessors

    /// Acknowledgment code (MSA-1): AA, AE, AR, CA, CE, CR
    public var acknowledgmentCode: String {
        acknowledgmentSegment?[0].value.value.raw ?? ""
    }

    /// Typed acknowledgment code, or nil if not recognized
    public var typedAcknowledgmentCode: AcknowledgmentCode? {
        AcknowledgmentCode(rawValue: acknowledgmentCode)
    }

    /// Message control ID of the acknowledged message (MSA-2)
    public var acknowledgedMessageControlID: String {
        acknowledgmentSegment?[1].value.value.raw ?? ""
    }

    /// Text message (MSA-3)
    public var textMessage: String {
        acknowledgmentSegment?[2].value.value.raw ?? ""
    }

    /// Whether the acknowledgment indicates success
    public var isAccepted: Bool {
        acknowledgmentCode == "AA" || acknowledgmentCode == "CA"
    }

    /// Whether the acknowledgment indicates an error
    public var isError: Bool {
        acknowledgmentCode == "AE" || acknowledgmentCode == "CE"
    }

    /// Whether the acknowledgment indicates rejection
    public var isRejected: Bool {
        acknowledgmentCode == "AR" || acknowledgmentCode == "CR"
    }

    // MARK: - Validation

    public static let validationRules: [MessageValidationRule] = [
        MessageValidationRule(description: "MSH segment is required") { msg in
            msg.messageHeader.segmentID == "MSH"
        },
        MessageValidationRule(description: "MSA segment is required") { msg in
            hasSegment("MSA", in: msg)
        },
        MessageValidationRule(description: "MSH-9 must contain ACK message type") { msg in
            msg.messageType().hasPrefix("ACK")
        },
        MessageValidationRule(description: "MSA-1 (acknowledgment code) must not be empty") { msg in
            guard let msa = firstSegment("MSA", in: msg) else { return false }
            return !msa[0].value.value.raw.isEmpty
        },
        MessageValidationRule(description: "MSA-2 (message control ID) must not be empty") { msg in
            guard let msa = firstSegment("MSA", in: msg) else { return false }
            return !msa[1].value.value.raw.isEmpty
        },
    ]

    public func validate() throws {
        let result = validateRules(Self.validationRules, message: message)
        guard result.isValid else {
            throw HL7Error.validationError("ACK validation failed: \(result.failures.joined(separator: "; "))")
        }
    }

    /// Run validation rules and return detailed result
    public func validateDetailed() -> MessageValidationResult {
        return validateRules(Self.validationRules, message: message)
    }

    /// Create an ACK response for a given message
    /// - Parameters:
    ///   - originalMessage: The message being acknowledged
    ///   - code: Acknowledgment code
    ///   - textMessage: Optional text message
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - controlID: Control ID for the ACK message
    ///   - version: HL7 version
    /// - Returns: Constructed ACK message
    /// - Throws: ``HL7Error`` on build failure
    public static func respond(
        to originalMessage: HL7v2Message,
        code: AcknowledgmentCode = .accept,
        textMessage: String? = nil,
        sendingApp: String = "",
        sendingFacility: String = "",
        controlID: String = "",
        version: String = "2.5.1"
    ) throws -> ACKMessage {
        let builder = MessageTemplate.ack(
            originalMessage: originalMessage,
            ackCode: code.rawValue,
            sendingApp: sendingApp,
            sendingFacility: sendingFacility,
            controlID: controlID,
            textMessage: textMessage,
            version: version
        )
        let msg = try builder.build()
        return try ACKMessage(message: msg)
    }
}

// MARK: - QRY Message

/// QRY (Query) message
///
/// QRY messages request specific information from another system using
/// the traditional query definition approach.
///
/// Required segments: MSH, QRD
public struct QRYMessage: HL7v2TypedMessage {

    public let message: HL7v2Message
    public static let messageTypeCode = "QRY"

    // MARK: - Initialization

    /// Wrap an existing ``HL7v2Message`` as a QRY message
    /// - Parameter message: Raw HL7 v2.x message
    /// - Throws: ``HL7Error`` if the message type does not match
    public init(message: HL7v2Message) throws {
        let type = message.messageType()
        guard type.hasPrefix("QRY") else {
            throw HL7Error.validationError("Expected QRY message type, got: \(type)")
        }
        self.message = message
    }

    /// Create a QRY message from a raw string
    public static func parse(_ rawValue: String) throws -> QRYMessage {
        let msg = try HL7v2Message.parse(rawValue)
        return try QRYMessage(message: msg)
    }

    // MARK: - Segment Accessors

    /// Query definition segment (QRD)
    public var queryDefinition: BaseSegment? { firstSegment("QRD", in: message) }

    /// Query filter segment (QRF)
    public var queryFilter: BaseSegment? { firstSegment("QRF", in: message) }

    // MARK: - Convenience Field Accessors

    /// Query date/time (QRD-1)
    public var queryDateTime: String {
        queryDefinition?[0].value.value.raw ?? ""
    }

    /// Query format code (QRD-3)
    public var queryFormatCode: String {
        queryDefinition?[2].value.value.raw ?? ""
    }

    /// Who subject filter (QRD-8) — typically a patient identifier
    public var whoSubjectFilter: String {
        queryDefinition?[7].serialize() ?? ""
    }

    // MARK: - Validation

    public static let validationRules: [MessageValidationRule] = [
        MessageValidationRule(description: "MSH segment is required") { msg in
            msg.messageHeader.segmentID == "MSH"
        },
        MessageValidationRule(description: "QRD segment is required") { msg in
            hasSegment("QRD", in: msg)
        },
        MessageValidationRule(description: "MSH-9 must contain QRY message type") { msg in
            msg.messageType().hasPrefix("QRY")
        },
    ]

    public func validate() throws {
        let result = validateRules(Self.validationRules, message: message)
        guard result.isValid else {
            throw HL7Error.validationError("QRY validation failed: \(result.failures.joined(separator: "; "))")
        }
    }

    /// Run validation rules and return detailed result
    public func validateDetailed() -> MessageValidationResult {
        return validateRules(Self.validationRules, message: message)
    }
}

// MARK: - QBP Message

/// QBP (Query by Parameter) message
///
/// QBP messages use a parameter-based query approach, replacing older QRY style.
///
/// Required segments: MSH, QPD
public struct QBPMessage: HL7v2TypedMessage {

    public let message: HL7v2Message
    public static let messageTypeCode = "QBP"

    // MARK: - Initialization

    /// Wrap an existing ``HL7v2Message`` as a QBP message
    /// - Parameter message: Raw HL7 v2.x message
    /// - Throws: ``HL7Error`` if the message type does not match
    public init(message: HL7v2Message) throws {
        let type = message.messageType()
        guard type.hasPrefix("QBP") else {
            throw HL7Error.validationError("Expected QBP message type, got: \(type)")
        }
        self.message = message
    }

    /// Create a QBP message from a raw string
    public static func parse(_ rawValue: String) throws -> QBPMessage {
        let msg = try HL7v2Message.parse(rawValue)
        return try QBPMessage(message: msg)
    }

    // MARK: - Segment Accessors

    /// Query parameter definition segment (QPD)
    public var queryParameterDefinition: BaseSegment? { firstSegment("QPD", in: message) }

    /// Response control parameter segment (RCP)
    public var responseControlParameter: BaseSegment? { firstSegment("RCP", in: message) }

    /// Continuation pointer segment (DSC)
    public var continuationPointer: BaseSegment? { firstSegment("DSC", in: message) }

    // MARK: - Convenience Field Accessors

    /// Message query name (QPD-1)
    public var messageQueryName: String {
        queryParameterDefinition?[0].serialize() ?? ""
    }

    /// Query tag (QPD-2)
    public var queryTag: String {
        queryParameterDefinition?[1].value.value.raw ?? ""
    }

    /// Query parameters (QPD-3 onward) as raw field strings
    public var queryParameters: [String] {
        guard let qpd = queryParameterDefinition else { return [] }
        var params: [String] = []
        var i = 2
        while true {
            let field = qpd[i]
            if field.isEmpty { break }
            params.append(field.serialize())
            i += 1
        }
        return params
    }

    // MARK: - Validation

    public static let validationRules: [MessageValidationRule] = [
        MessageValidationRule(description: "MSH segment is required") { msg in
            msg.messageHeader.segmentID == "MSH"
        },
        MessageValidationRule(description: "QPD segment is required") { msg in
            hasSegment("QPD", in: msg)
        },
        MessageValidationRule(description: "MSH-9 must contain QBP message type") { msg in
            msg.messageType().hasPrefix("QBP")
        },
    ]

    public func validate() throws {
        let result = validateRules(Self.validationRules, message: message)
        guard result.isValid else {
            throw HL7Error.validationError("QBP validation failed: \(result.failures.joined(separator: "; "))")
        }
    }

    /// Run validation rules and return detailed result
    public func validateDetailed() -> MessageValidationResult {
        return validateRules(Self.validationRules, message: message)
    }
}

// MARK: - Validation Helpers

/// Run a set of validation rules against a message
/// - Parameters:
///   - rules: Array of validation rules
///   - message: Message to validate
/// - Returns: Validation result
private func validateRules(_ rules: [MessageValidationRule], message: HL7v2Message) -> MessageValidationResult {
    var failures: [String] = []
    for rule in rules {
        if !rule.check(message) {
            failures.append(rule.description)
        }
    }
    return MessageValidationResult(isValid: failures.isEmpty, failures: failures)
}

// MARK: - MessageTemplate Extensions for Query Types

extension MessageTemplate {

    /// QRY (Query) message template
    /// - Parameters:
    ///   - triggerEvent: Trigger event (e.g., "Q01")
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - receivingApp: Receiving application name
    ///   - receivingFacility: Receiving facility name
    ///   - controlID: Message control ID
    ///   - version: HL7 version (default "2.5.1")
    /// - Returns: Preconfigured message builder
    public static func qry(
        triggerEvent: String = "Q01",
        sendingApp: String = "",
        sendingFacility: String = "",
        receivingApp: String = "",
        receivingFacility: String = "",
        controlID: String = "",
        version: String = "2.5.1"
    ) -> HL7v2MessageBuilder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = dateFormatter.string(from: Date())

        return HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility(sendingFacility)
                   .receivingApplication(receivingApp)
                   .receivingFacility(receivingFacility)
                   .dateTime(dateTime)
                   .messageType("QRY", triggerEvent: triggerEvent)
                   .messageControlID(controlID)
                   .processingID("P")
                   .version(version)
            }
    }

    /// QBP (Query by Parameter) message template
    /// - Parameters:
    ///   - triggerEvent: Trigger event (e.g., "Q22")
    ///   - sendingApp: Sending application name
    ///   - sendingFacility: Sending facility name
    ///   - receivingApp: Receiving application name
    ///   - receivingFacility: Receiving facility name
    ///   - controlID: Message control ID
    ///   - version: HL7 version (default "2.5.1")
    /// - Returns: Preconfigured message builder
    public static func qbp(
        triggerEvent: String = "Q22",
        sendingApp: String = "",
        sendingFacility: String = "",
        receivingApp: String = "",
        receivingFacility: String = "",
        controlID: String = "",
        version: String = "2.5.1"
    ) -> HL7v2MessageBuilder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateTime = dateFormatter.string(from: Date())

        return HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication(sendingApp)
                   .sendingFacility(sendingFacility)
                   .receivingApplication(receivingApp)
                   .receivingFacility(receivingFacility)
                   .dateTime(dateTime)
                   .messageType("QBP", triggerEvent: triggerEvent)
                   .messageControlID(controlID)
                   .processingID("P")
                   .version(version)
            }
    }
}
