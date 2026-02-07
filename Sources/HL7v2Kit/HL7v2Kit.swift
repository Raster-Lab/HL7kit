/// HL7v2Kit - HL7 v2.x message processing toolkit
///
/// This module provides parsing, validation, and generation of HL7 v2.x messages
/// with support for versions 2.1 through 2.8.

import Foundation
import HL7Core

/// Version information for HL7v2Kit
public struct HL7v2KitVersion {
    /// The current version of HL7v2Kit
    public static let version = "0.1.0"
}

/// HL7 v2.x message container
///
/// This structure represents a complete HL7 v2.x message with its segments.
/// Messages must start with an MSH (Message Header) segment.
public struct HL7v2Message: Sendable, Equatable {
    
    /// Collection of segments (copy-on-write via Array's COW)
    private let segments: [BaseSegment]
    
    /// Encoding characters extracted from MSH segment
    public let encodingCharacters: EncodingCharacters
    
    /// Message header (MSH) segment
    public var messageHeader: BaseSegment {
        guard let msh = segments.first, msh.segmentID == "MSH" else {
            fatalError("Message must start with MSH segment")
        }
        return msh
    }
    
    /// Initialize with segments
    /// - Parameters:
    ///   - segments: Array of segments (must start with MSH)
    ///   - encodingCharacters: Encoding characters to use
    /// - Throws: HL7Error if segments don't start with MSH
    public init(segments: [BaseSegment], encodingCharacters: EncodingCharacters = .standard) throws {
        guard let first = segments.first, first.segmentID == "MSH" else {
            throw HL7Error.validationError("Message must start with MSH segment")
        }
        self.segments = segments
        self.encodingCharacters = encodingCharacters
    }
    
    /// Parse message from raw string
    /// - Parameter rawValue: Raw message string
    /// - Returns: Parsed message
    /// - Throws: HL7Error if parsing fails
    public static func parse(_ rawValue: String) throws -> HL7v2Message {
        // Split by segment terminator (carriage return)
        let segmentStrings = rawValue.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !segmentStrings.isEmpty else {
            throw HL7Error.parsingError("Empty message")
        }
        
        // First segment must be MSH
        guard segmentStrings[0].hasPrefix("MSH") else {
            throw HL7Error.parsingError("Message must start with MSH segment")
        }
        
        // Extract encoding characters from MSH segment
        let mshSegment = segmentStrings[0]
        guard mshSegment.count >= 8 else {
            throw HL7Error.parsingError("MSH segment too short")
        }
        
        let fieldSeparator = mshSegment[mshSegment.index(mshSegment.startIndex, offsetBy: 3)]
        let encodingStart = mshSegment.index(mshSegment.startIndex, offsetBy: 4)
        let encodingEnd = mshSegment.index(encodingStart, offsetBy: 4)
        let encodingString = String(mshSegment[encodingStart..<encodingEnd])
        
        let encodingCharacters = try EncodingCharacters.parse(from: encodingString, fieldSeparator: fieldSeparator)
        
        // Parse all segments
        var segments: [BaseSegment] = []
        for segmentString in segmentStrings {
            let segment = try BaseSegment.parse(segmentString, encodingCharacters: encodingCharacters)
            segments.append(segment)
        }
        
        return try HL7v2Message(segments: segments, encodingCharacters: encodingCharacters)
    }
    
    /// Get segment at index
    /// - Parameter index: Segment index (0-based)
    /// - Returns: Segment at index, or nil if out of bounds
    public subscript(index: Int) -> BaseSegment? {
        guard index >= 0 && index < segments.count else {
            return nil
        }
        return segments[index]
    }
    
    /// Get all segments with a specific segment ID
    /// - Parameter segmentID: Segment identifier (e.g., "PID", "OBX")
    /// - Returns: Array of matching segments
    public func segments(withID segmentID: String) -> [BaseSegment] {
        return segments.filter { $0.segmentID == segmentID }
    }
    
    /// Get all segments
    public var allSegments: [BaseSegment] {
        return segments
    }
    
    /// Number of segments
    public var segmentCount: Int {
        return segments.count
    }
    
    /// Serialize message to raw string
    /// - Returns: Serialized message string
    /// - Throws: HL7Error if serialization fails
    public func serialize() throws -> String {
        var result = ""
        for segment in segments {
            if !result.isEmpty {
                result += "\r"
            }
            result += try segment.serialize()
        }
        return result
    }
    
    /// Get message type from MSH-9
    /// - Returns: Message type (e.g., "ADT^A01")
    public func messageType() -> String {
        let msh = messageHeader
        return msh[8].serialize()
    }
    
    /// Get message control ID from MSH-10
    /// - Returns: Message control ID
    public func messageControlID() -> String {
        let msh = messageHeader
        return msh[9].value.value.raw
    }
    
    /// Get version from MSH-12
    /// - Returns: HL7 version (e.g., "2.5.1")
    public func version() -> String {
        let msh = messageHeader
        return msh[11].value.value.raw
    }
}

extension HL7v2Message: CustomStringConvertible {
    public var description: String {
        return (try? serialize()) ?? "<invalid message>"
    }
}

// Maintain backward compatibility with HL7Message protocol
extension HL7v2Message: HL7Message {
    public var messageID: String {
        return messageControlID()
    }
    
    public var timestamp: Date {
        // Parse from MSH-7 if needed, for now return current date
        return Date()
    }
    
    public var rawData: String {
        return (try? serialize()) ?? ""
    }
    
    public func validate() throws {
        // Basic validation
        guard segmentCount > 0 else {
            throw HL7Error.validationError("Message has no segments")
        }
        
        guard messageHeader.segmentID == "MSH" else {
            throw HL7Error.validationError("Message must start with MSH segment")
        }
    }
}
