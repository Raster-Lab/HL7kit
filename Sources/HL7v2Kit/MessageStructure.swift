/// Message structure definitions for HL7 v2.x versions 2.1-2.8
///
/// This module provides a comprehensive database of message structures, including
/// version detection, structure validation, backward compatibility handling, and
/// query APIs for accessing definitions.

import Foundation
import HL7Core

// MARK: - HL7 Version

/// Represents an HL7 v2.x version
public struct HL7Version: Sendable, Equatable, Comparable, Hashable {
    /// Major version number
    public let major: Int
    /// Minor version number
    public let minor: Int
    /// Patch version number (optional)
    public let patch: Int?
    
    /// Initialize with version components
    /// - Parameters:
    ///   - major: Major version (e.g., 2)
    ///   - minor: Minor version (e.g., 5)
    ///   - patch: Patch version (e.g., 1), optional
    public init(major: Int, minor: Int, patch: Int? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Parse version from string (e.g., "2.5", "2.5.1")
    /// - Parameter string: Version string
    /// - Returns: Parsed version, or nil if invalid
    public static func parse(_ string: String) -> HL7Version? {
        let components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        
        let major = components[0]
        let minor = components[1]
        let patch = components.count > 2 ? components[2] : nil
        
        return HL7Version(major: major, minor: minor, patch: patch)
    }
    
    /// Version string representation (e.g., "2.5.1")
    public var versionString: String {
        if let patch = patch {
            return "\(major).\(minor).\(patch)"
        }
        return "\(major).\(minor)"
    }
    
    /// Compare versions for sorting
    public static func < (lhs: HL7Version, rhs: HL7Version) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return (lhs.patch ?? 0) < (rhs.patch ?? 0)
    }
    
    // MARK: - Common Versions
    
    /// HL7 v2.1 (1990)
    public static let v2_1 = HL7Version(major: 2, minor: 1)
    /// HL7 v2.2 (1994)
    public static let v2_2 = HL7Version(major: 2, minor: 2)
    /// HL7 v2.3 (1997)
    public static let v2_3 = HL7Version(major: 2, minor: 3)
    /// HL7 v2.3.1 (1999)
    public static let v2_3_1 = HL7Version(major: 2, minor: 3, patch: 1)
    /// HL7 v2.4 (2000)
    public static let v2_4 = HL7Version(major: 2, minor: 4)
    /// HL7 v2.5 (2003)
    public static let v2_5 = HL7Version(major: 2, minor: 5)
    /// HL7 v2.5.1 (2007) - Most widely implemented
    public static let v2_5_1 = HL7Version(major: 2, minor: 5, patch: 1)
    /// HL7 v2.6 (2007)
    public static let v2_6 = HL7Version(major: 2, minor: 6)
    /// HL7 v2.7 (2010)
    public static let v2_7 = HL7Version(major: 2, minor: 7)
    /// HL7 v2.7.1 (2011)
    public static let v2_7_1 = HL7Version(major: 2, minor: 7, patch: 1)
    /// HL7 v2.8 (2014)
    public static let v2_8 = HL7Version(major: 2, minor: 8)
    
    /// All supported versions in chronological order
    public static let allSupported: [HL7Version] = [
        .v2_1, .v2_2, .v2_3, .v2_3_1, .v2_4, .v2_5, .v2_5_1, .v2_6, .v2_7, .v2_7_1, .v2_8
    ]
}

extension HL7Version: CustomStringConvertible {
    public var description: String {
        return versionString
    }
}

// MARK: - Segment Usage

/// Indicates whether a segment is required, optional, or repeating
public enum SegmentUsage: Sendable, Equatable {
    /// Required (must appear exactly once)
    case required
    /// Optional (may appear zero or one time)
    case optional
    /// Required and repeating (must appear at least once, may repeat)
    case requiredRepeating
    /// Optional and repeating (may appear zero or more times)
    case optionalRepeating
    
    /// Whether the segment is required
    public var isRequired: Bool {
        switch self {
        case .required, .requiredRepeating:
            return true
        case .optional, .optionalRepeating:
            return false
        }
    }
    
    /// Whether the segment may repeat
    public var mayRepeat: Bool {
        switch self {
        case .requiredRepeating, .optionalRepeating:
            return true
        case .required, .optional:
            return false
        }
    }
    
    /// Get cardinality as a string (e.g., "1", "0..1", "1..*", "0..*")
    public var cardinality: String {
        switch self {
        case .required:
            return "1"
        case .optional:
            return "0..1"
        case .requiredRepeating:
            return "1..*"
        case .optionalRepeating:
            return "0..*"
        }
    }
}

// MARK: - Structure Segment Definition

/// Definition of a segment within a message structure
public struct StructureSegmentDefinition: Sendable, Equatable {
    /// Segment ID (e.g., "MSH", "PID", "OBX")
    public let segmentID: String
    /// Usage indicator (required, optional, etc.)
    public let usage: SegmentUsage
    /// Human-readable description
    public let description: String
    /// Applicable versions (nil means all versions)
    public let applicableVersions: [HL7Version]?
    
    /// Initialize a segment definition
    /// - Parameters:
    ///   - segmentID: Segment identifier
    ///   - usage: Usage indicator
    ///   - description: Human-readable description
    ///   - applicableVersions: Versions where this segment definition applies (nil = all)
    public init(
        segmentID: String,
        usage: SegmentUsage,
        description: String,
        applicableVersions: [HL7Version]? = nil
    ) {
        self.segmentID = segmentID
        self.usage = usage
        self.description = description
        self.applicableVersions = applicableVersions
    }
    
    /// Check if this segment definition applies to a specific version
    /// - Parameter version: HL7 version to check
    /// - Returns: `true` if the segment applies to this version
    public func applies(to version: HL7Version) -> Bool {
        guard let versions = applicableVersions else {
            return true // Applies to all versions
        }
        return versions.contains(version)
    }
}

// MARK: - Message Structure

/// Complete structure definition for an HL7 v2.x message type
public struct MessageStructure: Sendable, Equatable {
    /// Message type code (e.g., "ADT")
    public let messageType: String
    /// Trigger event code (e.g., "A01")
    public let triggerEvent: String
    /// Human-readable description
    public let description: String
    /// Ordered list of segment definitions
    public let segments: [StructureSegmentDefinition]
    /// First version where this message structure was introduced
    public let introducedInVersion: HL7Version
    /// Last version where this message structure was valid (nil = still valid)
    public let deprecatedInVersion: HL7Version?
    
    /// Initialize a message structure
    /// - Parameters:
    ///   - messageType: Message type code
    ///   - triggerEvent: Trigger event code
    ///   - description: Human-readable description
    ///   - segments: Ordered segment definitions
    ///   - introducedInVersion: First version supporting this structure
    ///   - deprecatedInVersion: Version where deprecated (nil if still valid)
    public init(
        messageType: String,
        triggerEvent: String,
        description: String,
        segments: [StructureSegmentDefinition],
        introducedInVersion: HL7Version = .v2_1,
        deprecatedInVersion: HL7Version? = nil
    ) {
        self.messageType = messageType
        self.triggerEvent = triggerEvent
        self.description = description
        self.segments = segments
        self.introducedInVersion = introducedInVersion
        self.deprecatedInVersion = deprecatedInVersion
    }
    
    /// Combined message type and trigger event (e.g., "ADT^A01")
    public var fullMessageType: String {
        return "\(messageType)^\(triggerEvent)"
    }
    
    /// Check if this structure applies to a specific version
    /// - Parameter version: HL7 version to check
    /// - Returns: `true` if the structure is valid for this version
    public func applies(to version: HL7Version) -> Bool {
        guard version >= introducedInVersion else {
            return false
        }
        if let deprecatedVersion = deprecatedInVersion {
            return version < deprecatedVersion
        }
        return true
    }
    
    /// Get segment definitions applicable to a specific version
    /// - Parameter version: HL7 version
    /// - Returns: Filtered segment definitions
    public func segments(for version: HL7Version) -> [StructureSegmentDefinition] {
        return segments.filter { $0.applies(to: version) }
    }
}

// MARK: - Message Structure Database

/// Central database of message structure definitions
public actor MessageStructureDatabase {
    
    /// Shared instance
    public static let shared = MessageStructureDatabase()
    
    /// Internal storage of message structures
    private var structures: [String: MessageStructure] = [:]
    
    /// Initialize with default structures
    private init() {
        Task {
            await registerDefaultStructures()
        }
    }
    
    /// Register a message structure
    /// - Parameter structure: Message structure to register
    public func register(_ structure: MessageStructure) {
        let key = "\(structure.messageType)^\(structure.triggerEvent)"
        structures[key] = structure
    }
    
    /// Get message structure by message type and trigger event
    /// - Parameters:
    ///   - messageType: Message type code (e.g., "ADT")
    ///   - triggerEvent: Trigger event code (e.g., "A01")
    /// - Returns: Message structure if found
    public func structure(
        messageType: String,
        triggerEvent: String
    ) -> MessageStructure? {
        let key = "\(messageType)^\(triggerEvent)"
        return structures[key]
    }
    
    /// Get message structure from a message
    /// - Parameter message: HL7 v2.x message
    /// - Returns: Message structure if found
    public func structure(for message: HL7v2Message) -> MessageStructure? {
        let msh = message.messageHeader
        let messageTypeField = msh[8]
        
        // MSH-9 is typically "MessageType^TriggerEvent"
        let components = messageTypeField.firstRepetition
        guard components.count >= 2 else {
            return nil
        }
        
        let messageType = components[0].value.raw
        let triggerEvent = components[1].value.raw
        
        return structure(messageType: messageType, triggerEvent: triggerEvent)
    }
    
    /// Get all registered message types
    /// - Returns: Array of all registered message structures
    public func allStructures() -> [MessageStructure] {
        return Array(structures.values).sorted { lhs, rhs in
            if lhs.messageType != rhs.messageType {
                return lhs.messageType < rhs.messageType
            }
            return lhs.triggerEvent < rhs.triggerEvent
        }
    }
    
    /// Get all message types for a specific version
    /// - Parameter version: HL7 version
    /// - Returns: Array of structures valid for this version
    public func structures(for version: HL7Version) -> [MessageStructure] {
        return structures.values.filter { $0.applies(to: version) }
    }
    
    /// Register default message structures
    private func registerDefaultStructures() async {
        // Register common message structures
        await registerADTStructures()
        await registerORMStructures()
        await registerORUStructures()
        await registerACKStructures()
        await registerQRYStructures()
    }
    
    // MARK: - ADT Structures
    
    private func registerADTStructures() async {
        // ADT^A01 - Admit/Visit Notification
        await register(MessageStructure(
            messageType: "ADT",
            triggerEvent: "A01",
            description: "Admit/Visit Notification",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "EVN", usage: .required, description: "Event Type"),
                StructureSegmentDefinition(segmentID: "PID", usage: .required, description: "Patient Identification"),
                StructureSegmentDefinition(segmentID: "PD1", usage: .optional, description: "Patient Additional Demographic"),
                StructureSegmentDefinition(segmentID: "NK1", usage: .optionalRepeating, description: "Next of Kin"),
                StructureSegmentDefinition(segmentID: "PV1", usage: .required, description: "Patient Visit"),
                StructureSegmentDefinition(segmentID: "PV2", usage: .optional, description: "Patient Visit - Additional Info"),
                StructureSegmentDefinition(segmentID: "DB1", usage: .optionalRepeating, description: "Disability"),
                StructureSegmentDefinition(segmentID: "OBX", usage: .optionalRepeating, description: "Observation/Result"),
                StructureSegmentDefinition(segmentID: "AL1", usage: .optionalRepeating, description: "Allergy Information"),
                StructureSegmentDefinition(segmentID: "DG1", usage: .optionalRepeating, description: "Diagnosis"),
                StructureSegmentDefinition(segmentID: "DRG", usage: .optional, description: "Diagnosis Related Group")
            ]
        ))
        
        // ADT^A03 - Discharge/End Visit
        await register(MessageStructure(
            messageType: "ADT",
            triggerEvent: "A03",
            description: "Discharge/End Visit",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "EVN", usage: .required, description: "Event Type"),
                StructureSegmentDefinition(segmentID: "PID", usage: .required, description: "Patient Identification"),
                StructureSegmentDefinition(segmentID: "PD1", usage: .optional, description: "Patient Additional Demographic"),
                StructureSegmentDefinition(segmentID: "PV1", usage: .required, description: "Patient Visit"),
                StructureSegmentDefinition(segmentID: "PV2", usage: .optional, description: "Patient Visit - Additional Info"),
                StructureSegmentDefinition(segmentID: "DB1", usage: .optionalRepeating, description: "Disability"),
                StructureSegmentDefinition(segmentID: "DG1", usage: .optionalRepeating, description: "Diagnosis"),
                StructureSegmentDefinition(segmentID: "DRG", usage: .optional, description: "Diagnosis Related Group")
            ]
        ))
        
        // ADT^A04 - Register a Patient
        await register(MessageStructure(
            messageType: "ADT",
            triggerEvent: "A04",
            description: "Register a Patient",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "EVN", usage: .required, description: "Event Type"),
                StructureSegmentDefinition(segmentID: "PID", usage: .required, description: "Patient Identification"),
                StructureSegmentDefinition(segmentID: "PD1", usage: .optional, description: "Patient Additional Demographic"),
                StructureSegmentDefinition(segmentID: "NK1", usage: .optionalRepeating, description: "Next of Kin"),
                StructureSegmentDefinition(segmentID: "PV1", usage: .required, description: "Patient Visit"),
                StructureSegmentDefinition(segmentID: "PV2", usage: .optional, description: "Patient Visit - Additional Info"),
                StructureSegmentDefinition(segmentID: "OBX", usage: .optionalRepeating, description: "Observation/Result"),
                StructureSegmentDefinition(segmentID: "AL1", usage: .optionalRepeating, description: "Allergy Information"),
                StructureSegmentDefinition(segmentID: "DG1", usage: .optionalRepeating, description: "Diagnosis")
            ]
        ))
        
        // ADT^A08 - Update Patient Information
        await register(MessageStructure(
            messageType: "ADT",
            triggerEvent: "A08",
            description: "Update Patient Information",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "EVN", usage: .required, description: "Event Type"),
                StructureSegmentDefinition(segmentID: "PID", usage: .required, description: "Patient Identification"),
                StructureSegmentDefinition(segmentID: "PD1", usage: .optional, description: "Patient Additional Demographic"),
                StructureSegmentDefinition(segmentID: "NK1", usage: .optionalRepeating, description: "Next of Kin"),
                StructureSegmentDefinition(segmentID: "PV1", usage: .required, description: "Patient Visit"),
                StructureSegmentDefinition(segmentID: "PV2", usage: .optional, description: "Patient Visit - Additional Info"),
                StructureSegmentDefinition(segmentID: "OBX", usage: .optionalRepeating, description: "Observation/Result"),
                StructureSegmentDefinition(segmentID: "AL1", usage: .optionalRepeating, description: "Allergy Information"),
                StructureSegmentDefinition(segmentID: "DG1", usage: .optionalRepeating, description: "Diagnosis")
            ]
        ))
    }
    
    // MARK: - ORM Structures
    
    private func registerORMStructures() async {
        // ORM^O01 - Order Message
        await register(MessageStructure(
            messageType: "ORM",
            triggerEvent: "O01",
            description: "Order Message",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "PID", usage: .required, description: "Patient Identification"),
                StructureSegmentDefinition(segmentID: "PV1", usage: .optional, description: "Patient Visit"),
                StructureSegmentDefinition(segmentID: "ORC", usage: .required, description: "Common Order"),
                StructureSegmentDefinition(segmentID: "OBR", usage: .required, description: "Observation Request"),
                StructureSegmentDefinition(segmentID: "NTE", usage: .optionalRepeating, description: "Notes and Comments"),
                StructureSegmentDefinition(segmentID: "OBX", usage: .optionalRepeating, description: "Observation/Result")
            ],
            introducedInVersion: .v2_1
        ))
    }
    
    // MARK: - ORU Structures
    
    private func registerORUStructures() async {
        // ORU^R01 - Observation Result
        await register(MessageStructure(
            messageType: "ORU",
            triggerEvent: "R01",
            description: "Unsolicited Observation Result",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "PID", usage: .required, description: "Patient Identification"),
                StructureSegmentDefinition(segmentID: "PV1", usage: .optional, description: "Patient Visit"),
                StructureSegmentDefinition(segmentID: "ORC", usage: .optional, description: "Common Order"),
                StructureSegmentDefinition(segmentID: "OBR", usage: .required, description: "Observation Request"),
                StructureSegmentDefinition(segmentID: "NTE", usage: .optionalRepeating, description: "Notes and Comments"),
                StructureSegmentDefinition(segmentID: "OBX", usage: .requiredRepeating, description: "Observation/Result")
            ],
            introducedInVersion: .v2_1
        ))
    }
    
    // MARK: - ACK Structures
    
    private func registerACKStructures() async {
        // ACK - General Acknowledgment (applies to all trigger events)
        await register(MessageStructure(
            messageType: "ACK",
            triggerEvent: "",
            description: "General Acknowledgment",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "MSA", usage: .required, description: "Message Acknowledgment"),
                StructureSegmentDefinition(segmentID: "ERR", usage: .optional, description: "Error")
            ],
            introducedInVersion: .v2_1
        ))
    }
    
    // MARK: - QRY Structures
    
    private func registerQRYStructures() async {
        // QRY^A19 - Patient Query
        await register(MessageStructure(
            messageType: "QRY",
            triggerEvent: "A19",
            description: "Patient Query",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "QRD", usage: .required, description: "Query Definition"),
                StructureSegmentDefinition(segmentID: "QRF", usage: .optional, description: "Query Filter")
            ],
            introducedInVersion: .v2_1
        ))
        
        // QBP^Q11 - Query by Parameter
        await register(MessageStructure(
            messageType: "QBP",
            triggerEvent: "Q11",
            description: "Query by Parameter",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "QPD", usage: .required, description: "Query Parameter Definition"),
                StructureSegmentDefinition(segmentID: "RCP", usage: .required, description: "Response Control Parameter")
            ],
            introducedInVersion: .v2_3
        ))
    }
}

// MARK: - Version Detection

extension HL7v2Message {
    /// Detect the HL7 version from the message header (MSH-12)
    /// - Returns: Detected version, or nil if unable to parse
    public func detectVersion() -> HL7Version? {
        let versionString = version()
        return HL7Version.parse(versionString)
    }
    
    /// Validate message structure against expected structure for detected version
    /// - Returns: Validation result
    public func validateStructure() async -> StructureValidationResult {
        guard let version = detectVersion() else {
            return StructureValidationResult(
                isValid: false,
                errors: ["Unable to detect HL7 version from MSH-12"],
                warnings: []
            )
        }
        
        guard let structure = await MessageStructureDatabase.shared.structure(for: self) else {
            return StructureValidationResult(
                isValid: true,
                errors: [],
                warnings: ["No structure definition found for message type"]
            )
        }
        
        return await validateStructure(against: structure, version: version)
    }
    
    /// Validate message structure against a specific structure definition
    /// - Parameters:
    ///   - structure: Expected message structure
    ///   - version: HL7 version to validate against
    /// - Returns: Validation result
    public func validateStructure(
        against structure: MessageStructure,
        version: HL7Version
    ) async -> StructureValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check if structure applies to this version
        guard structure.applies(to: version) else {
            errors.append("Message structure \(structure.fullMessageType) is not valid for version \(version)")
            return StructureValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Get segment definitions for this version
        let expectedSegments = structure.segments(for: version)
        
        // Build a map of actual segments by ID
        var actualSegmentCounts: [String: Int] = [:]
        for segment in allSegments {
            actualSegmentCounts[segment.segmentID, default: 0] += 1
        }
        
        // Validate each expected segment
        for segmentDef in expectedSegments {
            let count = actualSegmentCounts[segmentDef.segmentID] ?? 0
            
            switch segmentDef.usage {
            case .required:
                if count == 0 {
                    errors.append("Required segment \(segmentDef.segmentID) is missing")
                } else if count > 1 {
                    errors.append("Segment \(segmentDef.segmentID) should appear exactly once, found \(count)")
                }
                
            case .optional:
                if count > 1 {
                    errors.append("Segment \(segmentDef.segmentID) should appear at most once, found \(count)")
                }
                
            case .requiredRepeating:
                if count == 0 {
                    errors.append("Required repeating segment \(segmentDef.segmentID) is missing")
                }
                
            case .optionalRepeating:
                // Any count is valid
                break
            }
        }
        
        // Check for unexpected segments (not in structure)
        let expectedSegmentIDs = Set(expectedSegments.map { $0.segmentID })
        let actualSegmentIDs = Set(actualSegmentCounts.keys)
        let unexpectedSegmentIDs = actualSegmentIDs.subtracting(expectedSegmentIDs)
        
        for segmentID in unexpectedSegmentIDs {
            warnings.append("Segment \(segmentID) is not defined in structure for \(structure.fullMessageType)")
        }
        
        return StructureValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}

// MARK: - Structure Validation Result

/// Result of validating a message structure
public struct StructureValidationResult: Sendable, Equatable {
    /// Whether the structure is valid
    public let isValid: Bool
    /// Validation errors (structural violations)
    public let errors: [String]
    /// Validation warnings (non-critical issues)
    public let warnings: [String]
    
    /// Initialize a structure validation result
    public init(isValid: Bool, errors: [String], warnings: [String]) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}
