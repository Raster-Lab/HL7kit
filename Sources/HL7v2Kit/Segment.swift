/// Segment protocol and base implementation for HL7 v2.x messages
///
/// Segments are the primary building blocks of HL7 v2.x messages. Each segment
/// represents a logical grouping of data fields and begins with a three-character
/// segment identifier.

import Foundation
import HL7Core

/// Protocol for HL7 v2.x segments
public protocol HL7v2Segment: Sendable {
    /// Segment identifier (e.g., "MSH", "PID", "OBX")
    var segmentID: String { get }
    
    /// Collection of fields in the segment
    var fields: [Field] { get }
    
    /// Encoding characters used by this segment
    var encodingCharacters: EncodingCharacters { get }
    
    /// Get field at index
    /// - Parameter index: Field index (0-based)
    /// - Returns: Field at index, or empty field if out of bounds
    subscript(index: Int) -> Field { get }
    
    /// Serialize segment to raw string
    /// - Returns: Serialized segment string
    func serialize() throws -> String
    
    /// Parse segment from raw string
    /// - Parameters:
    ///   - rawValue: Raw segment string
    ///   - encodingCharacters: Encoding characters to use
    /// - Returns: Parsed segment
    /// - Throws: HL7Error if parsing fails
    static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters) throws -> Self
}

/// Base implementation of an HL7 v2.x segment
public struct BaseSegment: HL7v2Segment, Equatable {
    
    public let segmentID: String
    public let fields: [Field]
    public let encodingCharacters: EncodingCharacters
    
    /// Initialize with segment ID and fields
    /// - Parameters:
    ///   - segmentID: Segment identifier (3 characters)
    ///   - fields: Array of fields
    ///   - encodingCharacters: Encoding characters to use
    public init(segmentID: String, fields: [Field], encodingCharacters: EncodingCharacters = .standard) {
        // Intern common segment IDs for memory efficiency
        self.segmentID = InternedSegmentID.intern(segmentID)
        self.fields = fields
        self.encodingCharacters = encodingCharacters
    }
    
    /// Get field at index
    public subscript(index: Int) -> Field {
        guard index >= 0 && index < fields.count else {
            return Field(repetitions: [], encodingCharacters: encodingCharacters)
        }
        return fields[index]
    }
    
    /// Parse segment from raw string
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) throws -> BaseSegment {
        // Check minimum length
        guard rawValue.count >= 3 else {
            throw HL7Error.parsingError("Segment too short: minimum 3 characters required")
        }
        
        // Extract segment ID (first 3 characters) and intern common ones
        let rawSegmentID = String(rawValue.prefix(3))
        let segmentID = InternedSegmentID.intern(rawSegmentID)
        
        // Check if segment ID is valid (alphabetic characters)
        guard segmentID.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw HL7Error.parsingError("Invalid segment ID: \(segmentID)")
        }
        
        // Handle special case for MSH, FHS, and BHS segments (they have encoding characters in field 2)
        if segmentID == "MSH" || segmentID == "FHS" || segmentID == "BHS" {
            return try parseMSHLikeSegment(rawValue, segmentID: segmentID, encodingCharacters: encodingCharacters)
        }
        
        // For other segments, extract everything after segment ID
        let rawFieldData = String(rawValue.dropFirst(3))
        
        // Check if segment has a field separator
        guard let firstChar = rawFieldData.first, firstChar == encodingCharacters.fieldSeparator else {
            // Segment ID only, no fields
            return BaseSegment(segmentID: segmentID, fields: [], encodingCharacters: encodingCharacters)
        }
        
        // Drop the leading | (field delimiter) and split by |
        // For "PID|1|12345" after removing "PID" we have: "|1|12345"
        // Drop first | gives: "1|12345", split by | gives: ["1", "12345"] = 2 fields (correct!)
        // For "PID||||||Smith" after removing "PID" we have: "||||||Smith"  
        // Drop first | gives: "|||||Smith", split by | gives: ["", "", "", "", "", "Smith"] = 6 fields (correct!)
        let fieldParts = rawFieldData.dropFirst().split(separator: encodingCharacters.fieldSeparator, omittingEmptySubsequences: false)
        let fields = fieldParts.map { Field.parse(String($0), encodingCharacters: encodingCharacters) }
        
        return BaseSegment(segmentID: segmentID, fields: fields, encodingCharacters: encodingCharacters)
    }
    
    /// Parse MSH, FHS, or BHS segment (special case due to encoding characters in field 2)
    private static func parseMSHLikeSegment(_ rawValue: String, segmentID: String, encodingCharacters: EncodingCharacters) throws -> BaseSegment {
        // MSH/FHS/BHS format: MSH|^~\&|... or FHS|^~\&|... or BHS|^~\&|...
        // Field 1 is the field separator itself
        // Field 2 is the encoding characters (should NOT be parsed with delimiters)
        
        guard rawValue.count >= 8 else {
            throw HL7Error.parsingError("\(segmentID) segment too short")
        }
        
        let fieldSeparator = rawValue[rawValue.index(rawValue.startIndex, offsetBy: 3)]
        
        guard fieldSeparator == encodingCharacters.fieldSeparator else {
            throw HL7Error.parsingError("\(segmentID) field separator mismatch")
        }
        
        // Extract encoding characters from field 2
        let encodingStart = rawValue.index(rawValue.startIndex, offsetBy: 4)
        let encodingEnd = rawValue.index(encodingStart, offsetBy: 4)
        let encodingString = String(rawValue[encodingStart..<encodingEnd])
        
        // Parse the rest of the fields (after field 2)
        // The character after encodingEnd should be a field separator
        var remaining = String(rawValue[encodingEnd...])
        
        // Skip the field separator if present
        if remaining.first == encodingCharacters.fieldSeparator {
            remaining = String(remaining.dropFirst())
        }
        
        let fieldParts = remaining.split(separator: encodingCharacters.fieldSeparator, omittingEmptySubsequences: false)
        
        // Field 1 is the field separator, Field 2 is encoding characters
        // Create Field 2 with a single subcomponent to avoid parsing delimiters
        let encodingSubcomponent = Subcomponent(rawValue: encodingString, encodingCharacters: encodingCharacters)
        let encodingComponent = Component(subcomponents: [encodingSubcomponent], encodingCharacters: encodingCharacters)
        let encodingField = Field(repetitions: [[encodingComponent]], encodingCharacters: encodingCharacters)
        
        var fields: [Field] = [
            Field.parse(String(fieldSeparator), encodingCharacters: encodingCharacters),
            encodingField  // Field 2 special handling
        ]
        
        // Add remaining fields (Field 3 onward)
        fields.append(contentsOf: fieldParts.map { Field.parse(String($0), encodingCharacters: encodingCharacters) })
        
        return BaseSegment(segmentID: segmentID, fields: fields, encodingCharacters: encodingCharacters)
    }
    
    /// Serialize segment to raw string
    public func serialize() throws -> String {
        var result = segmentID
        
        // Special handling for MSH segment
        if segmentID == "MSH" {
            guard fields.count >= 2 else {
                throw HL7Error.validationError("MSH segment must have at least 2 fields")
            }
            
            // MSH-1 (field separator) and MSH-2 (encoding characters)
            result += String(encodingCharacters.fieldSeparator)
            result += fields[1].serialize()
            
            // Add remaining fields
            for i in 2..<fields.count {
                result += String(encodingCharacters.fieldSeparator)
                result += fields[i].serialize()
            }
        } else {
            // Regular segment
            for field in fields {
                result += String(encodingCharacters.fieldSeparator)
                result += field.serialize()
            }
        }
        
        return result
    }
}

extension BaseSegment: CustomStringConvertible {
    public var description: String {
        return (try? serialize()) ?? "\(segmentID)|<invalid>"
    }
}
