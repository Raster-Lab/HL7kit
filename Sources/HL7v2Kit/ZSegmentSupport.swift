/// Custom segment (Z-segment) support for HL7 v2.x messages
///
/// Z-segments are custom segments defined by implementations for local use.
/// They follow the naming convention of starting with 'Z' followed by two
/// alphanumeric characters (e.g., "ZPI", "ZBE", "Z01").

import Foundation
import HL7Core

// MARK: - Z-Segment Definition

/// Definition of a custom Z-segment
public struct ZSegmentDefinition: Sendable, Equatable {
    /// Segment identifier (must start with 'Z')
    public let segmentID: String
    /// Human-readable name
    public let name: String
    /// Description of the segment's purpose
    public let description: String
    /// Field definitions
    public let fields: [ZFieldDefinition]
    
    /// Initialize a Z-segment definition
    /// - Parameters:
    ///   - segmentID: Segment identifier (must start with 'Z')
    ///   - name: Human-readable name
    ///   - description: Description of the segment
    ///   - fields: Field definitions
    /// - Throws: HL7Error if segment ID is invalid
    public init(
        segmentID: String,
        name: String,
        description: String = "",
        fields: [ZFieldDefinition] = []
    ) throws {
        guard segmentID.count == 3, segmentID.hasPrefix("Z") else {
            throw HL7Error.validationError("Z-segment ID must be 3 characters starting with 'Z'")
        }
        
        self.segmentID = segmentID
        self.name = name
        self.description = description
        self.fields = fields
    }
}

/// Definition of a field within a Z-segment
public struct ZFieldDefinition: Sendable, Equatable {
    /// Field index (0-based)
    public let index: Int
    /// Field name
    public let name: String
    /// Field description
    public let description: String
    /// Whether the field is required
    public let required: Bool
    /// Whether the field can repeat
    public let repeating: Bool
    /// Expected data type (informational)
    public let dataType: String?
    
    /// Initialize a Z-field definition
    public init(
        index: Int,
        name: String,
        description: String = "",
        required: Bool = false,
        repeating: Bool = false,
        dataType: String? = nil
    ) {
        self.index = index
        self.name = name
        self.description = description
        self.required = required
        self.repeating = repeating
        self.dataType = dataType
    }
}

// MARK: - Z-Segment Registry

/// Registry for custom Z-segment definitions
public actor ZSegmentRegistry {
    private var definitions: [String: ZSegmentDefinition] = [:]
    
    /// Shared registry instance
    public static let shared = ZSegmentRegistry()
    
    /// Register a Z-segment definition
    /// - Parameter definition: Z-segment definition to register
    public func register(_ definition: ZSegmentDefinition) {
        definitions[definition.segmentID] = definition
    }
    
    /// Get definition for a Z-segment
    /// - Parameter segmentID: Segment identifier
    /// - Returns: Definition if registered, nil otherwise
    public func definition(for segmentID: String) -> ZSegmentDefinition? {
        definitions[segmentID]
    }
    
    /// Check if a segment ID is registered
    /// - Parameter segmentID: Segment identifier
    /// - Returns: True if registered
    public func isRegistered(_ segmentID: String) -> Bool {
        definitions[segmentID] != nil
    }
    
    /// Get all registered Z-segment IDs
    /// - Returns: Array of segment IDs
    public func allSegmentIDs() -> [String] {
        Array(definitions.keys).sorted()
    }
    
    /// Remove a Z-segment definition
    /// - Parameter segmentID: Segment identifier
    public func unregister(_ segmentID: String) {
        definitions.removeValue(forKey: segmentID)
    }
    
    /// Clear all Z-segment definitions
    public func clearAll() {
        definitions.removeAll()
    }
}

// MARK: - Z-Segment Builder

/// Builder for constructing custom Z-segments
public struct ZSegmentBuilder {
    private let segmentID: String
    private var fields: [Field] = []
    private let encodingCharacters: EncodingCharacters
    
    /// Initialize a Z-segment builder
    /// - Parameters:
    ///   - segmentID: Segment identifier (must start with 'Z')
    ///   - encodingCharacters: Encoding characters to use
    /// - Throws: HL7Error if segment ID is invalid
    public init(segmentID: String, encodingCharacters: EncodingCharacters = .standard) throws {
        guard segmentID.count == 3, segmentID.hasPrefix("Z") else {
            throw HL7Error.validationError("Z-segment ID must be 3 characters starting with 'Z'")
        }
        self.segmentID = segmentID
        self.encodingCharacters = encodingCharacters
    }
    
    /// Add a field to the segment
    /// - Parameter value: Field value as string
    /// - Returns: Updated builder
    public func addField(_ value: String) -> ZSegmentBuilder {
        var builder = self
        let field = Field.parse(value, encodingCharacters: encodingCharacters)
        builder.fields.append(field)
        return builder
    }
    
    /// Add a field with components
    /// - Parameter components: Component values
    /// - Returns: Updated builder
    public func addField(components: [String]) -> ZSegmentBuilder {
        var builder = self
        let componentObjects = components.map { value in
            let subcomp = Subcomponent(rawValue: value, encodingCharacters: encodingCharacters)
            return Component(subcomponents: [subcomp], encodingCharacters: encodingCharacters)
        }
        let field = Field(repetitions: [componentObjects], encodingCharacters: encodingCharacters)
        builder.fields.append(field)
        return builder
    }
    
    /// Add a field object
    /// - Parameter field: Field object
    /// - Returns: Updated builder
    public func addField(_ field: Field) -> ZSegmentBuilder {
        var builder = self
        builder.fields.append(field)
        return builder
    }
    
    /// Add an empty field
    /// - Returns: Updated builder
    public func addEmptyField() -> ZSegmentBuilder {
        var builder = self
        builder.fields.append(Field(repetitions: [], encodingCharacters: encodingCharacters))
        return builder
    }
    
    /// Add multiple fields
    /// - Parameter values: Field values as strings
    /// - Returns: Updated builder
    public func addFields(_ values: [String]) -> ZSegmentBuilder {
        var builder = self
        for value in values {
            builder = builder.addField(value)
        }
        return builder
    }
    
    /// Build the segment
    /// - Returns: Built segment
    public func build() -> BaseSegment {
        BaseSegment(segmentID: segmentID, fields: fields, encodingCharacters: encodingCharacters)
    }
    
    /// Build and serialize the segment
    /// - Returns: Serialized segment string
    /// - Throws: HL7Error if serialization fails
    public func buildAndSerialize() throws -> String {
        try build().serialize()
    }
}

// MARK: - Z-Segment Extensions

extension BaseSegment {
    /// Check if this is a Z-segment (custom segment)
    public var isZSegment: Bool {
        segmentID.hasPrefix("Z") && segmentID.count == 3
    }
    
    /// Get the Z-segment definition if registered
    public func zSegmentDefinition() async -> ZSegmentDefinition? {
        guard isZSegment else { return nil }
        return await ZSegmentRegistry.shared.definition(for: segmentID)
    }
    
    /// Create a Z-segment builder for this segment type
    /// - Parameter encodingCharacters: Encoding characters to use
    /// - Returns: Builder for this segment type
    /// - Throws: HL7Error if not a Z-segment
    public static func zSegmentBuilder(
        segmentID: String,
        encodingCharacters: EncodingCharacters = .standard
    ) throws -> ZSegmentBuilder {
        try ZSegmentBuilder(segmentID: segmentID, encodingCharacters: encodingCharacters)
    }
}

// MARK: - Common Z-Segment Examples

extension ZSegmentDefinition {
    /// Example: Custom patient information segment
    public static let zpi = try! ZSegmentDefinition(
        segmentID: "ZPI",
        name: "Custom Patient Information",
        description: "Additional patient information not in standard PID segment",
        fields: [
            ZFieldDefinition(index: 0, name: "Set ID", dataType: "SI"),
            ZFieldDefinition(index: 1, name: "Patient Type", required: true, dataType: "ST"),
            ZFieldDefinition(index: 2, name: "Custom ID", dataType: "ST"),
            ZFieldDefinition(index: 3, name: "Notes", repeating: true, dataType: "FT")
        ]
    )
    
    /// Example: Custom billing information segment
    public static let zbe = try! ZSegmentDefinition(
        segmentID: "ZBE",
        name: "Custom Billing Extension",
        description: "Extended billing information",
        fields: [
            ZFieldDefinition(index: 0, name: "Billing Code", required: true, dataType: "ST"),
            ZFieldDefinition(index: 1, name: "Billing Category", dataType: "ST"),
            ZFieldDefinition(index: 2, name: "Amount", dataType: "NM"),
            ZFieldDefinition(index: 3, name: "Currency", dataType: "ST")
        ]
    )
    
    /// Example: Custom observation extension
    public static let zob = try! ZSegmentDefinition(
        segmentID: "ZOB",
        name: "Custom Observation Extension",
        description: "Extended observation data",
        fields: [
            ZFieldDefinition(index: 0, name: "Observation ID", required: true, dataType: "ST"),
            ZFieldDefinition(index: 1, name: "Extended Value", dataType: "ST"),
            ZFieldDefinition(index: 2, name: "Metadata", repeating: true, dataType: "ST")
        ]
    )
}

// MARK: - Validation

extension ZSegmentDefinition {
    /// Validate a segment against this definition
    /// - Parameter segment: Segment to validate
    /// - Returns: Validation result with any errors
    public func validate(_ segment: BaseSegment) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check segment ID matches
        guard segment.segmentID == segmentID else {
            let issue = ValidationIssue(
                severity: .error,
                message: "Segment ID mismatch: expected \(segmentID), got \(segment.segmentID)",
                location: segment.segmentID
            )
            return .invalid([issue])
        }
        
        // Validate required fields
        for fieldDef in fields where fieldDef.required {
            if fieldDef.index >= segment.fields.count || segment[fieldDef.index].isEmpty {
                let issue = ValidationIssue(
                    severity: .error,
                    message: "Required field '\(fieldDef.name)' (index \(fieldDef.index)) is missing",
                    location: "\(segmentID).\(fieldDef.index)"
                )
                issues.append(issue)
            }
        }
        
        // Check for unexpected repeating fields
        for fieldDef in fields where !fieldDef.repeating {
            if fieldDef.index < segment.fields.count {
                let field = segment[fieldDef.index]
                // Note: We cannot directly access repetitions, so we use a workaround
                // by checking if the field has multiple values through its string representation
                let fieldStr = field.serialize()
                let hasMultipleReps = fieldStr.contains("~")
                
                if hasMultipleReps {
                    let issue = ValidationIssue(
                        severity: .warning,
                        message: "Field '\(fieldDef.name)' (index \(fieldDef.index)) should not repeat",
                        location: "\(segmentID).\(fieldDef.index)"
                    )
                    issues.append(issue)
                }
            }
        }
        
        // Return result based on issues found
        if issues.isEmpty {
            return .valid
        } else if issues.allSatisfy({ $0.severity == .warning }) {
            return .warning(issues)
        } else {
            return .invalid(issues)
        }
    }
}
