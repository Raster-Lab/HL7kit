/// HL7 v2.x Validation Engine
///
/// Provides a comprehensive validation framework for HL7 v2.x messages including:
/// - Conformance profile support (segment/field definitions with metadata)
/// - Composable validation rules engine
/// - Required field validation (presence/optionality checking)
/// - Data type validation (ST, NM, DT, TM, TS, ID, IS, etc.)
/// - Cardinality checking (segment and field repetition constraints)
/// - Custom validation rules support (user-defined rules)

import Foundation
import HL7Core

// MARK: - HL7 v2.x Data Types

/// Standard HL7 v2.x data types for field validation
public enum HL7v2DataType: String, Sendable, CaseIterable {
    /// String (ST) — Any displayable characters
    case string = "ST"
    /// Text (TX) — String data meant for display/print
    case text = "TX"
    /// Formatted text (FT) — String with embedded formatting
    case formattedText = "FT"
    /// Numeric (NM) — Numeric value (optional leading sign, digits, optional decimal)
    case numeric = "NM"
    /// Date (DT) — YYYY[MM[DD]]
    case date = "DT"
    /// Time (TM) — HH[MM[SS[.SSSS]]][+/-ZZZZ]
    case time = "TM"
    /// Timestamp (TS/DTM) — YYYY[MM[DD[HH[MM[SS[.SSSS]]]]]][+/-ZZZZ]
    case timestamp = "TS"
    /// Coded value (ID) — Coded value for HL7-defined tables
    case codedValue = "ID"
    /// Coded value user-defined (IS) — Coded value for user-defined tables
    case codedValueUser = "IS"
    /// Sequence ID (SI) — Non-negative integer
    case sequenceID = "SI"
    /// Coded element (CE) — Composite: identifier^text^coding-system
    case codedElement = "CE"
    /// Coded with exceptions (CWE) — Similar to CE with additional components
    case codedWithExceptions = "CWE"
    /// Extended composite name (XPN) — Person name: family^given^middle^suffix^prefix
    case extendedPersonName = "XPN"
    /// Extended address (XAD) — Address components
    case extendedAddress = "XAD"
    /// Extended composite ID (CX) — ID^check-digit^code^assigning-authority
    case extendedCompositeID = "CX"
    /// Extended telecom number (XTN) — Phone/email
    case extendedTelecom = "XTN"
    /// Hierarchic designator (HD) — namespace^universalID^universalIDType
    case hierarchicDesignator = "HD"
    /// Entity identifier (EI) — entityID^namespace^universalID^universalIDType
    case entityIdentifier = "EI"
    /// Processing type (PT) — processingID^processingMode
    case processingType = "PT"
    /// Message type (MSG) — messageCode^triggerEvent^messageStructure
    case messageType = "MSG"
    /// Version identifier (VID) — versionID^internationalizationCode^internationalVersionID
    case versionIdentifier = "VID"
    /// Varies — Data type determined at runtime
    case varies = "varies"
}

// MARK: - Field Optionality

/// Optionality of a field in an HL7 v2.x segment
public enum FieldOptionality: String, Sendable {
    /// Required — Must be present and non-empty
    case required = "R"
    /// Optional — May be present or absent
    case optional = "O"
    /// Conditional — Required under certain conditions
    case conditional = "C"
    /// Not used — Should not be populated
    case notUsed = "X"
    /// Backward compatible — For backward compatibility only
    case backward = "B"
    /// Withdrawn — Removed from the specification
    case withdrawn = "W"
}

// MARK: - Cardinality

/// Cardinality constraint for segments or field repetitions
public struct Cardinality: Sendable, Equatable {
    /// Minimum occurrences (0 = optional)
    public let min: Int
    /// Maximum occurrences (nil = unbounded)
    public let max: Int?

    /// Creates a cardinality constraint
    /// - Parameters:
    ///   - min: Minimum occurrences
    ///   - max: Maximum occurrences (nil = unbounded)
    public init(min: Int, max: Int? = nil) {
        self.min = Swift.max(0, min)
        self.max = max
    }

    /// Exactly one occurrence: [1..1]
    public static let exactlyOne = Cardinality(min: 1, max: 1)
    /// Zero or one occurrence: [0..1]
    public static let zeroOrOne = Cardinality(min: 0, max: 1)
    /// One or more occurrences: [1..*]
    public static let oneOrMore = Cardinality(min: 1, max: nil)
    /// Zero or more occurrences: [0..*]
    public static let zeroOrMore = Cardinality(min: 0, max: nil)

    /// Check whether a count satisfies this cardinality
    /// - Parameter count: The actual count to check
    /// - Returns: `true` if the count is within bounds
    public func isSatisfied(by count: Int) -> Bool {
        guard count >= min else { return false }
        if let max = max { return count <= max }
        return true
    }

    /// Human-readable description of the cardinality, e.g. "[1..1]", "[0..*]"
    public var displayString: String {
        let maxStr = max.map(String.init) ?? "*"
        return "[\(min)..\(maxStr)]"
    }
}

// MARK: - Field Definition

/// Definition of a field within an HL7 v2.x segment
///
/// Describes the expected data type, optionality, length constraints,
/// and repetition rules for a specific field position.
public struct FieldDefinition: Sendable {
    /// Field position within the segment (1-based, matching HL7 convention)
    public let position: Int
    /// Human-readable name of the field
    public let name: String
    /// Expected data type
    public let dataType: HL7v2DataType
    /// Optionality (required, optional, conditional, etc.)
    public let optionality: FieldOptionality
    /// Maximum length (nil = no limit)
    public let maxLength: Int?
    /// Repetition cardinality (nil = no repetitions allowed, i.e. [1..1])
    public let repetitions: Cardinality

    /// Creates a field definition
    /// - Parameters:
    ///   - position: 1-based field position
    ///   - name: Human-readable name
    ///   - dataType: Expected data type
    ///   - optionality: Required, optional, etc.
    ///   - maxLength: Maximum character length (nil = unlimited)
    ///   - repetitions: Repetition cardinality (default: exactly one)
    public init(
        position: Int,
        name: String,
        dataType: HL7v2DataType,
        optionality: FieldOptionality = .optional,
        maxLength: Int? = nil,
        repetitions: Cardinality = .exactlyOne
    ) {
        self.position = position
        self.name = name
        self.dataType = dataType
        self.optionality = optionality
        self.maxLength = maxLength
        self.repetitions = repetitions
    }
}

// MARK: - Segment Definition

/// Definition of a segment's structure within an HL7 v2.x conformance profile
///
/// Describes expected fields, cardinality, and segment-level constraints.
public struct SegmentDefinition: Sendable {
    /// Segment identifier (e.g., "MSH", "PID")
    public let segmentID: String
    /// Human-readable name of the segment
    public let name: String
    /// Ordered field definitions for this segment
    public let fields: [FieldDefinition]

    /// Creates a segment definition
    /// - Parameters:
    ///   - segmentID: Segment identifier
    ///   - name: Human-readable name
    ///   - fields: Ordered field definitions
    public init(segmentID: String, name: String, fields: [FieldDefinition]) {
        self.segmentID = segmentID
        self.name = name
        self.fields = fields
    }

    /// Look up a field definition by 1-based position
    /// - Parameter position: 1-based field position
    /// - Returns: Field definition, or nil if not defined
    public func field(at position: Int) -> FieldDefinition? {
        return fields.first { $0.position == position }
    }
}

// MARK: - Conformance Profile

/// Segment requirement within a conformance profile
public struct SegmentRequirement: Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Cardinality within the message
    public let cardinality: Cardinality
    /// Optional segment definition for deep validation
    public let definition: SegmentDefinition?

    /// Creates a segment requirement
    /// - Parameters:
    ///   - segmentID: Segment identifier
    ///   - cardinality: How many times this segment may appear
    ///   - definition: Optional detailed segment definition
    public init(
        segmentID: String,
        cardinality: Cardinality,
        definition: SegmentDefinition? = nil
    ) {
        self.segmentID = segmentID
        self.cardinality = cardinality
        self.definition = definition
    }
}

/// A conformance profile describing the expected structure of an HL7 v2.x message
///
/// Conformance profiles define which segments are required, their cardinality,
/// and optionally the expected fields within each segment.
public struct ConformanceProfile: Sendable {
    /// Profile identifier (e.g., "ADT_A01")
    public let identifier: String
    /// Human-readable description
    public let description: String
    /// HL7 version this profile applies to (e.g., "2.5.1")
    public let hl7Version: String
    /// Message type code (e.g., "ADT")
    public let messageType: String
    /// Trigger event (e.g., "A01"), or nil for general profiles
    public let triggerEvent: String?
    /// Ordered segment requirements
    public let segmentRequirements: [SegmentRequirement]

    /// Creates a conformance profile
    public init(
        identifier: String,
        description: String,
        hl7Version: String,
        messageType: String,
        triggerEvent: String? = nil,
        segmentRequirements: [SegmentRequirement]
    ) {
        self.identifier = identifier
        self.description = description
        self.hl7Version = hl7Version
        self.messageType = messageType
        self.triggerEvent = triggerEvent
        self.segmentRequirements = segmentRequirements
    }

    /// Look up a segment requirement by segment ID
    /// - Parameter segmentID: Segment identifier
    /// - Returns: Segment requirement, or nil if not defined
    public func requirement(for segmentID: String) -> SegmentRequirement? {
        return segmentRequirements.first { $0.segmentID == segmentID }
    }
}

// MARK: - Validation Engine

/// HL7 v2.x validation engine
///
/// Provides comprehensive validation of HL7 v2.x messages against conformance
/// profiles, data type rules, cardinality constraints, and custom rules.
///
/// ## Usage
///
/// ```swift
/// let engine = HL7v2ValidationEngine()
///
/// // Validate against a conformance profile
/// let result = engine.validate(message, against: profile)
///
/// // Validate with custom rules
/// let result = engine.validate(message, rules: [myRule1, myRule2])
/// ```
public struct HL7v2ValidationEngine: Sendable {

    /// Validation options controlling engine behavior
    public let options: ValidationOptions

    /// Creates a validation engine
    /// - Parameter options: Validation options
    public init(options: ValidationOptions = .default) {
        self.options = options
    }

    // MARK: - Profile-Based Validation

    /// Validate a message against a conformance profile
    /// - Parameters:
    ///   - message: The HL7 v2.x message to validate
    ///   - profile: The conformance profile to validate against
    /// - Returns: Validation result with all issues found
    public func validate(
        _ message: HL7v2Message,
        against profile: ConformanceProfile
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // 1. Validate message type matches profile
        let msgType = message.messageType()
        if !msgType.hasPrefix(profile.messageType) {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Message type '\(msgType)' does not match profile '\(profile.messageType)'",
                location: "MSH-9",
                code: "MSG_TYPE_MISMATCH"
            ))
            if options.stopOnFirstError { return .invalid(issues) }
        }

        // 2. Validate segment cardinality
        let cardinalityIssues = validateSegmentCardinality(message, profile: profile)
        issues.append(contentsOf: cardinalityIssues)
        if options.stopOnFirstError && issues.contains(where: { $0.severity == .error }) {
            return .invalid(issues)
        }

        // 3. Validate field-level rules for segments that have definitions
        for requirement in profile.segmentRequirements {
            guard let definition = requirement.definition else { continue }
            let matchingSegments = message.segments(withID: requirement.segmentID)
            for (idx, segment) in matchingSegments.enumerated() {
                let prefix = matchingSegments.count > 1
                    ? "\(requirement.segmentID)[\(idx + 1)]"
                    : requirement.segmentID
                let fieldIssues = validateSegmentFields(segment, definition: definition, pathPrefix: prefix)
                issues.append(contentsOf: fieldIssues)
                if options.stopOnFirstError && issues.contains(where: { $0.severity == .error }) {
                    return .invalid(issues)
                }
            }
        }

        // Respect maxIssues
        if issues.count > options.maxIssues {
            issues = Array(issues.prefix(options.maxIssues))
        }

        return HL7v2ValidationEngine.result(from: issues)
    }

    // MARK: - Rules-Based Validation

    /// Validate a message using an array of composable validation rules
    /// - Parameters:
    ///   - message: The HL7 v2.x message to validate
    ///   - rules: Array of validation rules to apply
    /// - Returns: Validation result
    public func validate(
        _ message: HL7v2Message,
        rules: [HL7v2ValidationRule]
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []

        for rule in rules {
            let ruleIssues = rule.validate(message: message)
            issues.append(contentsOf: ruleIssues)
            if options.stopOnFirstError && issues.contains(where: { $0.severity == .error }) {
                break
            }
            if issues.count >= options.maxIssues {
                break
            }
        }

        if issues.count > options.maxIssues {
            issues = Array(issues.prefix(options.maxIssues))
        }

        return HL7v2ValidationEngine.result(from: issues)
    }

    // MARK: - Data Type Validation

    /// Validate a raw string value against an HL7 v2.x data type
    /// - Parameters:
    ///   - value: The raw string value
    ///   - dataType: Expected data type
    /// - Returns: Array of validation issues (empty if valid)
    public func validateDataType(
        _ value: String,
        as dataType: HL7v2DataType,
        location: String? = nil
    ) -> [ValidationIssue] {
        return HL7v2ValidationEngine.validateValue(value, dataType: dataType, location: location)
    }

    // MARK: - Internal Helpers

    /// Validate segment cardinality against a conformance profile
    private func validateSegmentCardinality(
        _ message: HL7v2Message,
        profile: ConformanceProfile
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for requirement in profile.segmentRequirements {
            let count = message.segments(withID: requirement.segmentID).count
            if !requirement.cardinality.isSatisfied(by: count) {
                let severity: ValidationSeverity = requirement.cardinality.min > 0 && count == 0
                    ? .error
                    : .error
                issues.append(ValidationIssue(
                    severity: severity,
                    message: "Segment '\(requirement.segmentID)' appears \(count) time(s), expected \(requirement.cardinality.displayString)",
                    location: requirement.segmentID,
                    code: "SEGMENT_CARDINALITY"
                ))
            }
        }

        return issues
    }

    /// Validate fields within a segment against a segment definition
    private func validateSegmentFields(
        _ segment: BaseSegment,
        definition: SegmentDefinition,
        pathPrefix: String
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for fieldDef in definition.fields {
            let location = "\(pathPrefix)-\(fieldDef.position)"

            // For MSH segment, field index in the array has a +1 offset for MSH-1 (field separator)
            // MSH-1 = fields[0] (field separator)
            // MSH-2 = fields[1] (encoding chars)
            // MSH-3 = fields[2], etc.
            // For other segments: field position N corresponds to fields[N-1]
            let fieldIndex: Int
            if segment.segmentID == "MSH" {
                fieldIndex = fieldDef.position - 1
            } else {
                fieldIndex = fieldDef.position - 1
            }

            let field = segment[fieldIndex]

            // 1. Required field presence check
            if fieldDef.optionality == .required && field.isEmpty {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Required field '\(fieldDef.name)' is empty",
                    location: location,
                    code: "REQUIRED_FIELD_MISSING"
                ))
                continue
            }

            // Skip further validation if field is empty and optional
            guard !field.isEmpty else { continue }

            // 2. Not-used field check
            if fieldDef.optionality == .notUsed && !field.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Field '\(fieldDef.name)' should not be populated (marked as not used)",
                    location: location,
                    code: "FIELD_NOT_USED"
                ))
            }

            // 3. Max length check
            if let maxLength = fieldDef.maxLength {
                let serialized = field.serialize()
                if serialized.count > maxLength {
                    issues.append(ValidationIssue(
                        severity: .error,
                        message: "Field '\(fieldDef.name)' exceeds maximum length \(maxLength) (actual: \(serialized.count))",
                        location: location,
                        code: "FIELD_TOO_LONG"
                    ))
                }
            }

            // 4. Repetition cardinality check
            if !fieldDef.repetitions.isSatisfied(by: field.repetitionCount) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Field '\(fieldDef.name)' has \(field.repetitionCount) repetition(s), expected \(fieldDef.repetitions.displayString)",
                    location: location,
                    code: "FIELD_REPETITION_CARDINALITY"
                ))
            }

            // 5. Data type validation (first repetition, first component value)
            let rawValue = field.value.value.raw
            if !rawValue.isEmpty {
                let typeIssues = HL7v2ValidationEngine.validateValue(rawValue, dataType: fieldDef.dataType, location: location)
                issues.append(contentsOf: typeIssues)
            }
        }

        return issues
    }

    /// Validate a raw value against a data type
    static func validateValue(
        _ value: String,
        dataType: HL7v2DataType,
        location: String?
    ) -> [ValidationIssue] {
        switch dataType {
        case .numeric:
            return validateNumeric(value, location: location)
        case .date:
            return validateDate(value, location: location)
        case .time:
            return validateTime(value, location: location)
        case .timestamp:
            return validateTimestamp(value, location: location)
        case .sequenceID:
            return validateSequenceID(value, location: location)
        case .string, .text, .formattedText, .codedValue, .codedValueUser,
             .codedElement, .codedWithExceptions, .extendedPersonName,
             .extendedAddress, .extendedCompositeID, .extendedTelecom,
             .hierarchicDesignator, .entityIdentifier, .processingType,
             .messageType, .versionIdentifier, .varies:
            return []
        }
    }

    /// Validate a numeric (NM) value
    private static func validateNumeric(_ value: String, location: String?) -> [ValidationIssue] {
        // NM: optional leading +/-, digits, optional decimal point, digits
        let pattern = #"^[+-]?\d+(\.\d+)?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return [ValidationIssue(
                severity: .error,
                message: "Invalid numeric value: '\(value)'",
                location: location,
                code: "INVALID_NM"
            )]
        }
        return []
    }

    /// Validate a date (DT) value: YYYY[MM[DD]]
    private static func validateDate(_ value: String, location: String?) -> [ValidationIssue] {
        let pattern = #"^\d{4}(\d{2}(\d{2})?)?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return [ValidationIssue(
                severity: .error,
                message: "Invalid date value: '\(value)' (expected YYYY[MM[DD]])",
                location: location,
                code: "INVALID_DT"
            )]
        }
        // Validate month/day ranges if present
        if value.count >= 6 {
            let monthStart = value.index(value.startIndex, offsetBy: 4)
            let monthEnd = value.index(monthStart, offsetBy: 2)
            if let month = Int(value[monthStart..<monthEnd]), (month < 1 || month > 12) {
                return [ValidationIssue(
                    severity: .error,
                    message: "Invalid month in date: '\(value)'",
                    location: location,
                    code: "INVALID_DT_MONTH"
                )]
            }
        }
        if value.count >= 8 {
            let dayStart = value.index(value.startIndex, offsetBy: 6)
            let dayEnd = value.index(dayStart, offsetBy: 2)
            if let day = Int(value[dayStart..<dayEnd]), (day < 1 || day > 31) {
                return [ValidationIssue(
                    severity: .error,
                    message: "Invalid day in date: '\(value)'",
                    location: location,
                    code: "INVALID_DT_DAY"
                )]
            }
        }
        return []
    }

    /// Validate a time (TM) value: HH[MM[SS[.SSSS]]][+/-ZZZZ]
    private static func validateTime(_ value: String, location: String?) -> [ValidationIssue] {
        let pattern = #"^\d{2}(\d{2}(\d{2}(\.\d{1,4})?)?)?([+-]\d{4})?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return [ValidationIssue(
                severity: .error,
                message: "Invalid time value: '\(value)' (expected HH[MM[SS[.SSSS]]][+/-ZZZZ])",
                location: location,
                code: "INVALID_TM"
            )]
        }
        // Validate hour range
        let hourEnd = value.index(value.startIndex, offsetBy: 2)
        if let hour = Int(value[value.startIndex..<hourEnd]), (hour < 0 || hour > 23) {
            return [ValidationIssue(
                severity: .error,
                message: "Invalid hour in time: '\(value)'",
                location: location,
                code: "INVALID_TM_HOUR"
            )]
        }
        return []
    }

    /// Validate a timestamp (TS/DTM) value: YYYY[MM[DD[HH[MM[SS[.SSSS]]]]]][+/-ZZZZ]
    private static func validateTimestamp(_ value: String, location: String?) -> [ValidationIssue] {
        let pattern = #"^\d{4}(\d{2}(\d{2}(\d{2}(\d{2}(\d{2}(\.\d{1,4})?)?)?)?)?)?([+-]\d{4})?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return [ValidationIssue(
                severity: .error,
                message: "Invalid timestamp value: '\(value)' (expected YYYY[MM[DD[HH[MM[SS[.SSSS]]]]]][+/-ZZZZ])",
                location: location,
                code: "INVALID_TS"
            )]
        }
        // Basic year check
        if value.count >= 4 {
            let yearEnd = value.index(value.startIndex, offsetBy: 4)
            if let year = Int(value[value.startIndex..<yearEnd]), year < 1000 {
                return [ValidationIssue(
                    severity: .warning,
                    message: "Unusual year in timestamp: '\(value)'",
                    location: location,
                    code: "UNUSUAL_TS_YEAR"
                )]
            }
        }
        return []
    }

    /// Validate a sequence ID (SI) value: non-negative integer
    private static func validateSequenceID(_ value: String, location: String?) -> [ValidationIssue] {
        let pattern = #"^\d+$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else {
            return [ValidationIssue(
                severity: .error,
                message: "Invalid sequence ID value: '\(value)' (expected non-negative integer)",
                location: location,
                code: "INVALID_SI"
            )]
        }
        return []
    }

    /// Convert issues array into a ValidationResult
    static func result(from issues: [ValidationIssue]) -> ValidationResult {
        if issues.isEmpty {
            return .valid
        }
        let hasErrors = issues.contains { $0.severity == .error }
        return hasErrors ? .invalid(issues) : .warning(issues)
    }
}

// MARK: - Composable Validation Rules

/// Protocol for HL7 v2.x message validation rules
///
/// Implement this protocol to create custom, composable validation rules
/// that can be applied independently or combined in the validation engine.
public protocol HL7v2ValidationRule: Sendable {
    /// Human-readable description of the rule
    var ruleDescription: String { get }

    /// Validate a message
    /// - Parameter message: The message to validate
    /// - Returns: Array of validation issues (empty if valid)
    func validate(message: HL7v2Message) -> [ValidationIssue]
}

// MARK: - Built-in Validation Rules

/// Validates that a specific segment is present in the message
public struct RequiredSegmentRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier that must be present
    public let segmentID: String
    /// Minimum number of occurrences
    public let minimumCount: Int

    public var ruleDescription: String {
        if minimumCount == 1 {
            return "Segment '\(segmentID)' is required"
        }
        return "At least \(minimumCount) '\(segmentID)' segment(s) required"
    }

    /// Creates a required segment rule
    /// - Parameters:
    ///   - segmentID: Segment identifier
    ///   - minimumCount: Minimum occurrences (default: 1)
    public init(segmentID: String, minimumCount: Int = 1) {
        self.segmentID = segmentID
        self.minimumCount = minimumCount
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        let count = message.segments(withID: segmentID).count
        if count < minimumCount {
            return [ValidationIssue(
                severity: .error,
                message: ruleDescription,
                location: segmentID,
                code: "REQUIRED_SEGMENT"
            )]
        }
        return []
    }
}

/// Validates that a specific field in a segment is present and non-empty
public struct RequiredFieldRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Field position (1-based)
    public let fieldPosition: Int
    /// Human-readable field name
    public let fieldName: String

    public var ruleDescription: String {
        "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) is required"
    }

    /// Creates a required field rule
    /// - Parameters:
    ///   - segmentID: Segment identifier
    ///   - fieldPosition: 1-based field position
    ///   - fieldName: Human-readable field name
    public init(segmentID: String, fieldPosition: Int, fieldName: String) {
        self.segmentID = segmentID
        self.fieldPosition = fieldPosition
        self.fieldName = fieldName
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        guard let segment = message.segments(withID: segmentID).first else {
            // If segment is absent, that's a different rule's responsibility
            return []
        }
        let fieldIndex = fieldPosition - 1
        let field = segment[fieldIndex]
        if field.isEmpty {
            return [ValidationIssue(
                severity: .error,
                message: ruleDescription,
                location: "\(segmentID)-\(fieldPosition)",
                code: "REQUIRED_FIELD_MISSING"
            )]
        }
        return []
    }
}

/// Validates field length does not exceed a maximum
public struct FieldLengthRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Field position (1-based)
    public let fieldPosition: Int
    /// Maximum allowed length
    public let maxLength: Int
    /// Human-readable field name
    public let fieldName: String

    public var ruleDescription: String {
        "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) must not exceed \(maxLength) characters"
    }

    /// Creates a field length rule
    public init(segmentID: String, fieldPosition: Int, maxLength: Int, fieldName: String) {
        self.segmentID = segmentID
        self.fieldPosition = fieldPosition
        self.maxLength = maxLength
        self.fieldName = fieldName
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        guard let segment = message.segments(withID: segmentID).first else {
            return []
        }
        let fieldIndex = fieldPosition - 1
        let field = segment[fieldIndex]
        guard !field.isEmpty else { return [] }
        let serialized = field.serialize()
        if serialized.count > maxLength {
            return [ValidationIssue(
                severity: .error,
                message: "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) length \(serialized.count) exceeds maximum \(maxLength)",
                location: "\(segmentID)-\(fieldPosition)",
                code: "FIELD_TOO_LONG"
            )]
        }
        return []
    }
}

/// Validates that a field's data type matches expectations
public struct DataTypeRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Field position (1-based)
    public let fieldPosition: Int
    /// Expected data type
    public let dataType: HL7v2DataType
    /// Human-readable field name
    public let fieldName: String

    public var ruleDescription: String {
        "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) must be a valid \(dataType.rawValue)"
    }

    /// Creates a data type validation rule
    public init(segmentID: String, fieldPosition: Int, dataType: HL7v2DataType, fieldName: String) {
        self.segmentID = segmentID
        self.fieldPosition = fieldPosition
        self.dataType = dataType
        self.fieldName = fieldName
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        guard let segment = message.segments(withID: segmentID).first else {
            return []
        }
        let fieldIndex = fieldPosition - 1
        let field = segment[fieldIndex]
        guard !field.isEmpty else { return [] }
        let rawValue = field.value.value.raw
        guard !rawValue.isEmpty else { return [] }
        return HL7v2ValidationEngine.validateValue(
            rawValue,
            dataType: dataType,
            location: "\(segmentID)-\(fieldPosition)"
        )
    }
}

/// Validates that a field value is within a set of allowed values
public struct ValueSetRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Field position (1-based)
    public let fieldPosition: Int
    /// Set of allowed values
    public let allowedValues: Set<String>
    /// Human-readable field name
    public let fieldName: String

    public var ruleDescription: String {
        "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) must be one of: \(allowedValues.sorted().joined(separator: ", "))"
    }

    /// Creates a value set validation rule
    public init(segmentID: String, fieldPosition: Int, allowedValues: Set<String>, fieldName: String) {
        self.segmentID = segmentID
        self.fieldPosition = fieldPosition
        self.allowedValues = allowedValues
        self.fieldName = fieldName
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        guard let segment = message.segments(withID: segmentID).first else {
            return []
        }
        let fieldIndex = fieldPosition - 1
        let field = segment[fieldIndex]
        guard !field.isEmpty else { return [] }
        let rawValue = field.value.value.raw
        guard !rawValue.isEmpty else { return [] }
        if !allowedValues.contains(rawValue) {
            return [ValidationIssue(
                severity: .error,
                message: "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) value '\(rawValue)' is not in the allowed set",
                location: "\(segmentID)-\(fieldPosition)",
                code: "VALUE_NOT_IN_SET"
            )]
        }
        return []
    }
}

/// Validates a field value against a regular expression pattern
public struct PatternRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Field position (1-based)
    public let fieldPosition: Int
    /// Regular expression pattern the value must match
    public let pattern: String
    /// Human-readable field name
    public let fieldName: String

    public var ruleDescription: String {
        "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) must match pattern: \(pattern)"
    }

    /// Creates a pattern validation rule
    public init(segmentID: String, fieldPosition: Int, pattern: String, fieldName: String) {
        self.segmentID = segmentID
        self.fieldPosition = fieldPosition
        self.pattern = pattern
        self.fieldName = fieldName
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        guard let segment = message.segments(withID: segmentID).first else {
            return []
        }
        let fieldIndex = fieldPosition - 1
        let field = segment[fieldIndex]
        guard !field.isEmpty else { return [] }
        let rawValue = field.value.value.raw
        guard !rawValue.isEmpty else { return [] }
        if rawValue.range(of: pattern, options: .regularExpression) == nil {
            return [ValidationIssue(
                severity: .error,
                message: "Field '\(fieldName)' (\(segmentID)-\(fieldPosition)) value '\(rawValue)' does not match expected pattern",
                location: "\(segmentID)-\(fieldPosition)",
                code: "PATTERN_MISMATCH"
            )]
        }
        return []
    }
}

/// Custom validation rule using a closure
///
/// Allows arbitrary validation logic to be expressed as a composable rule.
public struct CustomValidationRule: HL7v2ValidationRule, Sendable {
    public let ruleDescription: String
    private let validation: @Sendable (HL7v2Message) -> [ValidationIssue]

    /// Creates a custom validation rule
    /// - Parameters:
    ///   - description: Human-readable description
    ///   - validation: Closure performing validation
    public init(
        description: String,
        validation: @escaping @Sendable (HL7v2Message) -> [ValidationIssue]
    ) {
        self.ruleDescription = description
        self.validation = validation
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        return validation(message)
    }
}

// MARK: - Segment Cardinality Rule

/// Validates segment cardinality (number of occurrences)
public struct SegmentCardinalityRule: HL7v2ValidationRule, Sendable {
    /// Segment identifier
    public let segmentID: String
    /// Expected cardinality
    public let cardinality: Cardinality

    public var ruleDescription: String {
        "Segment '\(segmentID)' must appear \(cardinality.displayString) time(s)"
    }

    /// Creates a segment cardinality rule
    public init(segmentID: String, cardinality: Cardinality) {
        self.segmentID = segmentID
        self.cardinality = cardinality
    }

    public func validate(message: HL7v2Message) -> [ValidationIssue] {
        let count = message.segments(withID: segmentID).count
        if !cardinality.isSatisfied(by: count) {
            return [ValidationIssue(
                severity: .error,
                message: "Segment '\(segmentID)' appears \(count) time(s), expected \(cardinality.displayString)",
                location: segmentID,
                code: "SEGMENT_CARDINALITY"
            )]
        }
        return []
    }
}

// MARK: - Built-in Conformance Profiles

/// Standard conformance profiles for common HL7 v2.x message types
public enum StandardProfiles {

    // MARK: - MSH Segment Definition

    /// Standard MSH segment definition with core fields
    public static let mshDefinition = SegmentDefinition(
        segmentID: "MSH",
        name: "Message Header",
        fields: [
            FieldDefinition(position: 1, name: "Field Separator", dataType: .string, optionality: .required, maxLength: 1),
            FieldDefinition(position: 2, name: "Encoding Characters", dataType: .string, optionality: .required, maxLength: 4),
            FieldDefinition(position: 3, name: "Sending Application", dataType: .hierarchicDesignator, optionality: .optional, maxLength: 227),
            FieldDefinition(position: 4, name: "Sending Facility", dataType: .hierarchicDesignator, optionality: .optional, maxLength: 227),
            FieldDefinition(position: 5, name: "Receiving Application", dataType: .hierarchicDesignator, optionality: .optional, maxLength: 227),
            FieldDefinition(position: 6, name: "Receiving Facility", dataType: .hierarchicDesignator, optionality: .optional, maxLength: 227),
            FieldDefinition(position: 7, name: "Date/Time of Message", dataType: .timestamp, optionality: .required, maxLength: 26),
            FieldDefinition(position: 8, name: "Security", dataType: .string, optionality: .optional, maxLength: 40),
            FieldDefinition(position: 9, name: "Message Type", dataType: .messageType, optionality: .required, maxLength: 15),
            FieldDefinition(position: 10, name: "Message Control ID", dataType: .string, optionality: .required, maxLength: 199),
            FieldDefinition(position: 11, name: "Processing ID", dataType: .processingType, optionality: .required, maxLength: 3),
            FieldDefinition(position: 12, name: "Version ID", dataType: .versionIdentifier, optionality: .required, maxLength: 60),
        ]
    )

    // MARK: - PID Segment Definition

    /// Standard PID segment definition
    public static let pidDefinition = SegmentDefinition(
        segmentID: "PID",
        name: "Patient Identification",
        fields: [
            FieldDefinition(position: 1, name: "Set ID", dataType: .sequenceID, optionality: .optional, maxLength: 4),
            FieldDefinition(position: 2, name: "Patient ID (External)", dataType: .extendedCompositeID, optionality: .optional, maxLength: 20),
            FieldDefinition(position: 3, name: "Patient Identifier List", dataType: .extendedCompositeID, optionality: .required, maxLength: 250, repetitions: .oneOrMore),
            FieldDefinition(position: 4, name: "Alternate Patient ID", dataType: .extendedCompositeID, optionality: .backward, maxLength: 20),
            FieldDefinition(position: 5, name: "Patient Name", dataType: .extendedPersonName, optionality: .required, maxLength: 250, repetitions: .oneOrMore),
            FieldDefinition(position: 6, name: "Mother's Maiden Name", dataType: .extendedPersonName, optionality: .optional, maxLength: 250),
            FieldDefinition(position: 7, name: "Date/Time of Birth", dataType: .timestamp, optionality: .optional, maxLength: 26),
            FieldDefinition(position: 8, name: "Administrative Sex", dataType: .codedValue, optionality: .optional, maxLength: 1),
        ]
    )

    // MARK: - PV1 Segment Definition

    /// Standard PV1 segment definition (core fields)
    public static let pv1Definition = SegmentDefinition(
        segmentID: "PV1",
        name: "Patient Visit",
        fields: [
            FieldDefinition(position: 1, name: "Set ID", dataType: .sequenceID, optionality: .optional, maxLength: 4),
            FieldDefinition(position: 2, name: "Patient Class", dataType: .codedValue, optionality: .required, maxLength: 1),
        ]
    )

    // MARK: - EVN Segment Definition

    /// Standard EVN segment definition
    public static let evnDefinition = SegmentDefinition(
        segmentID: "EVN",
        name: "Event Type",
        fields: [
            FieldDefinition(position: 1, name: "Event Type Code", dataType: .codedValue, optionality: .optional, maxLength: 3),
            FieldDefinition(position: 2, name: "Recorded Date/Time", dataType: .timestamp, optionality: .optional, maxLength: 26),
        ]
    )

    // MARK: - MSA Segment Definition

    /// Standard MSA segment definition
    public static let msaDefinition = SegmentDefinition(
        segmentID: "MSA",
        name: "Message Acknowledgment",
        fields: [
            FieldDefinition(position: 1, name: "Acknowledgment Code", dataType: .codedValue, optionality: .required, maxLength: 2),
            FieldDefinition(position: 2, name: "Message Control ID", dataType: .string, optionality: .required, maxLength: 199),
            FieldDefinition(position: 3, name: "Text Message", dataType: .string, optionality: .optional, maxLength: 80),
        ]
    )

    // MARK: - ORC Segment Definition

    /// Standard ORC segment definition (core fields)
    public static let orcDefinition = SegmentDefinition(
        segmentID: "ORC",
        name: "Common Order",
        fields: [
            FieldDefinition(position: 1, name: "Order Control", dataType: .codedValue, optionality: .required, maxLength: 2),
            FieldDefinition(position: 2, name: "Placer Order Number", dataType: .entityIdentifier, optionality: .optional, maxLength: 22),
            FieldDefinition(position: 3, name: "Filler Order Number", dataType: .entityIdentifier, optionality: .optional, maxLength: 22),
        ]
    )

    // MARK: - OBR Segment Definition

    /// Standard OBR segment definition (core fields)
    public static let obrDefinition = SegmentDefinition(
        segmentID: "OBR",
        name: "Observation Request",
        fields: [
            FieldDefinition(position: 1, name: "Set ID", dataType: .sequenceID, optionality: .optional, maxLength: 4),
            FieldDefinition(position: 2, name: "Placer Order Number", dataType: .entityIdentifier, optionality: .optional, maxLength: 22),
            FieldDefinition(position: 3, name: "Filler Order Number", dataType: .entityIdentifier, optionality: .optional, maxLength: 22),
            FieldDefinition(position: 4, name: "Universal Service Identifier", dataType: .codedWithExceptions, optionality: .required, maxLength: 250),
        ]
    )

    // MARK: - OBX Segment Definition

    /// Standard OBX segment definition (core fields)
    public static let obxDefinition = SegmentDefinition(
        segmentID: "OBX",
        name: "Observation/Result",
        fields: [
            FieldDefinition(position: 1, name: "Set ID", dataType: .sequenceID, optionality: .optional, maxLength: 4),
            FieldDefinition(position: 2, name: "Value Type", dataType: .codedValue, optionality: .conditional, maxLength: 3),
            FieldDefinition(position: 3, name: "Observation Identifier", dataType: .codedWithExceptions, optionality: .required, maxLength: 250),
            FieldDefinition(position: 4, name: "Observation Sub-ID", dataType: .string, optionality: .conditional, maxLength: 20),
            FieldDefinition(position: 5, name: "Observation Value", dataType: .varies, optionality: .conditional, maxLength: 65536),
            FieldDefinition(position: 6, name: "Units", dataType: .codedWithExceptions, optionality: .optional, maxLength: 250),
            FieldDefinition(position: 7, name: "References Range", dataType: .string, optionality: .optional, maxLength: 60),
            FieldDefinition(position: 8, name: "Abnormal Flags", dataType: .codedValue, optionality: .optional, maxLength: 5, repetitions: .zeroOrMore),
            FieldDefinition(position: 11, name: "Observation Result Status", dataType: .codedValue, optionality: .required, maxLength: 1),
        ]
    )

    // MARK: - Standard Profiles

    /// ADT A01 (Admit) conformance profile
    public static let adtA01 = ConformanceProfile(
        identifier: "ADT_A01",
        description: "ADT Admit/Visit Notification",
        hl7Version: "2.5.1",
        messageType: "ADT",
        triggerEvent: "A01",
        segmentRequirements: [
            SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne, definition: mshDefinition),
            SegmentRequirement(segmentID: "EVN", cardinality: .exactlyOne, definition: evnDefinition),
            SegmentRequirement(segmentID: "PID", cardinality: .exactlyOne, definition: pidDefinition),
            SegmentRequirement(segmentID: "PV1", cardinality: .exactlyOne, definition: pv1Definition),
            SegmentRequirement(segmentID: "NK1", cardinality: .zeroOrMore),
            SegmentRequirement(segmentID: "AL1", cardinality: .zeroOrMore),
            SegmentRequirement(segmentID: "DG1", cardinality: .zeroOrMore),
            SegmentRequirement(segmentID: "OBX", cardinality: .zeroOrMore, definition: obxDefinition),
        ]
    )

    /// ORU R01 (Unsolicited Observation) conformance profile
    public static let oruR01 = ConformanceProfile(
        identifier: "ORU_R01",
        description: "ORU Unsolicited Observation Result",
        hl7Version: "2.5.1",
        messageType: "ORU",
        triggerEvent: "R01",
        segmentRequirements: [
            SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne, definition: mshDefinition),
            SegmentRequirement(segmentID: "PID", cardinality: .exactlyOne, definition: pidDefinition),
            SegmentRequirement(segmentID: "OBR", cardinality: .oneOrMore, definition: obrDefinition),
            SegmentRequirement(segmentID: "OBX", cardinality: .oneOrMore, definition: obxDefinition),
        ]
    )

    /// ORM O01 (Order) conformance profile
    public static let ormO01 = ConformanceProfile(
        identifier: "ORM_O01",
        description: "ORM Order Message",
        hl7Version: "2.5.1",
        messageType: "ORM",
        triggerEvent: "O01",
        segmentRequirements: [
            SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne, definition: mshDefinition),
            SegmentRequirement(segmentID: "PID", cardinality: .exactlyOne, definition: pidDefinition),
            SegmentRequirement(segmentID: "ORC", cardinality: .oneOrMore, definition: orcDefinition),
            SegmentRequirement(segmentID: "OBR", cardinality: .zeroOrMore, definition: obrDefinition),
        ]
    )

    /// ACK conformance profile
    public static let ack = ConformanceProfile(
        identifier: "ACK",
        description: "General Acknowledgment",
        hl7Version: "2.5.1",
        messageType: "ACK",
        triggerEvent: nil,
        segmentRequirements: [
            SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne, definition: mshDefinition),
            SegmentRequirement(segmentID: "MSA", cardinality: .exactlyOne, definition: msaDefinition),
            SegmentRequirement(segmentID: "ERR", cardinality: .zeroOrMore),
        ]
    )
}
