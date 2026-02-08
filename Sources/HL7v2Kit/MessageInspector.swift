/// Message Inspector and Debugger for HL7 v2.x messages
///
/// Provides tools for analyzing, debugging, and inspecting HL7 messages
/// including structure visualization, field access, and diagnostic reporting.

import Foundation
import HL7Core

// MARK: - Message Inspector

/// Inspector for analyzing and debugging HL7 v2.x messages
public struct MessageInspector {
    /// The message to inspect
    public let message: HL7v2Message
    
    /// Initialize inspector with a message
    /// - Parameter message: Message to inspect
    public init(message: HL7v2Message) {
        self.message = message
    }
    
    /// Get a human-readable summary of the message
    /// - Returns: Summary string with message type, version, and segment count
    public func summary() -> String {
        var result = "HL7 v2.x Message Inspector\n"
        result += "=" * 50 + "\n"
        result += "Message Type: \(message.messageType())\n"
        result += "Event Type: \(message.eventType)\n"
        result += "Version: \(message.version())\n"
        result += "Segment Count: \(message.allSegments.count)\n"
        result += "Control ID: \(message.messageControlID())\n"
        
        // Extract MSH fields
        let msh = message.messageHeader
        result += "Sending Application: \(msh[2].value.value.raw)\n"
        result += "Receiving Application: \(msh[4].value.value.raw)\n"
        result += "Timestamp: \(msh[6].value.value.raw)\n"
        return result
    }
    
    /// Get a detailed tree view of the message structure
    /// - Parameter maxFieldLength: Maximum length to display for field values (default 50)
    /// - Returns: Tree structure string
    public func treeView(maxFieldLength: Int = 50) -> String {
        var result = "Message Structure:\n"
        result += "└── \(message.messageType()) (v\(message.version()))\n"
        
        for (index, segment) in message.allSegments.enumerated() {
            let isLast = index == message.allSegments.count - 1
            let prefix = isLast ? "    └── " : "    ├── "
            let segmentID = segment.segmentID
            
            result += prefix + segmentID
            
            // Add field count
            let fieldCount = segment.fields.count
            result += " [\(fieldCount) field\(fieldCount == 1 ? "" : "s")]\n"
            
            // Show first few fields if available
            let fieldsToShow = min(3, fieldCount)
            for fieldIndex in 0..<fieldsToShow {
                let field = segment[fieldIndex]
                let fieldValue = field.serialize()
                let truncated = fieldValue.count > maxFieldLength 
                    ? String(fieldValue.prefix(maxFieldLength)) + "..." 
                    : fieldValue
                
                let fieldPrefix = isLast ? "        " : "    │   "
                let fieldBullet = fieldIndex == fieldsToShow - 1 && fieldsToShow == fieldCount ? "└── " : "├── "
                result += fieldPrefix + fieldBullet + "[\(fieldIndex)]: \(truncated)\n"
            }
            
            if fieldCount > fieldsToShow {
                let remaining = fieldCount - fieldsToShow
                let fieldPrefix = isLast ? "        " : "    │   "
                result += fieldPrefix + "└── ... \(remaining) more field\(remaining == 1 ? "" : "s")\n"
            }
        }
        
        return result
    }
    
    /// Get detailed information about a specific segment
    /// - Parameters:
    ///   - segmentID: Segment identifier (e.g., "PID", "OBX")
    ///   - occurrence: Which occurrence if multiple exist (0-based, default 0)
    /// - Returns: Detailed segment information or nil if not found
    public func inspectSegment(_ segmentID: String, occurrence: Int = 0) -> String? {
        let segments = message.allSegments.filter { $0.segmentID == segmentID }
        guard occurrence < segments.count else { return nil }
        
        let segment = segments[occurrence]
        var result = "Segment: \(segmentID)"
        if segments.count > 1 {
            result += " [occurrence \(occurrence + 1) of \(segments.count)]"
        }
        result += "\n" + "=" * 50 + "\n"
        
        for (index, field) in segment.fields.enumerated() {
            let value = field.serialize()
            result += "[\(index)]: \(value)\n"
            
            // Show component breakdown if present
            if value.contains("^") {
                let components = value.split(separator: "^")
                for (compIndex, component) in components.enumerated() {
                    result += "     [\(index).\(compIndex)]: \(component)\n"
                }
            }
        }
        
        return result
    }
    
    /// Get statistics about the message
    /// - Returns: Dictionary of statistics
    public func statistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        // Segment statistics
        let segmentCounts = message.allSegments.reduce(into: [String: Int]()) { counts, segment in
            counts[segment.segmentID, default: 0] += 1
        }
        stats["segmentCounts"] = segmentCounts
        stats["totalSegments"] = message.allSegments.count
        stats["uniqueSegments"] = segmentCounts.count
        
        // Field statistics
        var totalFields = 0
        var emptyFields = 0
        var maxFieldsInSegment = 0
        
        for segment in message.allSegments {
            totalFields += segment.fields.count
            maxFieldsInSegment = max(maxFieldsInSegment, segment.fields.count)
            emptyFields += segment.fields.filter { $0.isEmpty }.count
        }
        
        stats["totalFields"] = totalFields
        stats["emptyFields"] = emptyFields
        stats["maxFieldsInSegment"] = maxFieldsInSegment
        stats["averageFieldsPerSegment"] = message.allSegments.isEmpty ? 0 : Double(totalFields) / Double(message.allSegments.count)
        
        // Size information
        if let serialized = try? message.serialize() {
            stats["totalSize"] = serialized.count
            stats["averageBytesPerSegment"] = message.allSegments.isEmpty ? 0 : serialized.count / message.allSegments.count
        }
        
        return stats
    }
    
    /// Search for a value in the message
    /// - Parameters:
    ///   - value: Value to search for
    ///   - caseSensitive: Whether search should be case-sensitive (default true)
    /// - Returns: Array of locations where value was found
    public func search(for value: String, caseSensitive: Bool = true) -> [(segment: String, field: Int, value: String)] {
        var results: [(segment: String, field: Int, value: String)] = []
        
        for segment in message.allSegments {
            for (index, field) in segment.fields.enumerated() {
                let fieldValue = field.serialize()
                let matches = caseSensitive 
                    ? fieldValue.contains(value)
                    : fieldValue.lowercased().contains(value.lowercased())
                
                if matches {
                    results.append((segment: segment.segmentID, field: index, value: fieldValue))
                }
            }
        }
        
        return results
    }
    
    /// Compare this message with another message
    /// - Parameter other: Other message to compare
    /// - Returns: Comparison report
    public func compare(with other: HL7v2Message) -> String {
        var result = "Message Comparison\n"
        result += "=" * 50 + "\n"
        result += "Message 1: \(message.messageType()) v\(message.version())\n"
        result += "Message 2: \(other.messageType()) v\(other.version())\n\n"
        
        // Compare segment counts
        let segments1 = message.allSegments.map { $0.segmentID }
        let segments2 = other.allSegments.map { $0.segmentID }
        
        if segments1 != segments2 {
            result += "⚠️ Different segment structure\n"
            result += "Message 1 segments: \(segments1.joined(separator: ", "))\n"
            result += "Message 2 segments: \(segments2.joined(separator: ", "))\n"
        } else {
            result += "✓ Same segment structure\n"
        }
        
        // Compare common segments
        let minSegments = min(message.allSegments.count, other.allSegments.count)
        var differences = 0
        
        for i in 0..<minSegments {
            let seg1 = message.allSegments[i]
            let seg2 = other.allSegments[i]
            
            let serialized1 = try? seg1.serialize()
            let serialized2 = try? seg2.serialize()
            
            if serialized1 != serialized2 {
                differences += 1
                result += "\nDifference in segment \(i) (\(seg1.segmentID)):\n"
                
                let maxFields = max(seg1.fields.count, seg2.fields.count)
                for fieldIndex in 0..<maxFields {
                    let field1 = fieldIndex < seg1.fields.count ? seg1[fieldIndex].serialize() : "<missing>"
                    let field2 = fieldIndex < seg2.fields.count ? seg2[fieldIndex].serialize() : "<missing>"
                    
                    if field1 != field2 {
                        result += "  Field [\(fieldIndex)]: '\(field1)' vs '\(field2)'\n"
                    }
                }
            }
        }
        
        result += "\nSummary: \(differences) segment\(differences == 1 ? "" : "s") differ\n"
        
        return result
    }
    
    /// Validate message and get detailed report
    /// - Returns: Validation report
    public func validationReport() -> String {
        var result = "Validation Report\n"
        result += "=" * 50 + "\n"
        
        // Perform basic validation
        do {
            try message.validate()
            result += "Status: ✓ Valid (basic checks passed)\n"
        } catch {
            result += "Status: ✗ Invalid\n"
            result += "Error: \(error)\n"
        }
        
        return result
    }
}

// MARK: - String Extension for Repeat Operator

fileprivate extension String {
    /// Repeat a string n times
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// MARK: - Pretty Printer

/// Pretty printer for HL7 messages
public struct MessagePrettyPrinter {
    /// Format options for pretty printing
    public struct FormatOptions: Sendable {
        /// Show field indices
        public var showIndices: Bool = true
        /// Show empty fields
        public var showEmptyFields: Bool = false
        /// Indent size in spaces
        public var indentSize: Int = 2
        /// Maximum field value length before truncation
        public var maxValueLength: Int? = nil
        
        /// Default format options
        public static let `default` = FormatOptions()
        
        public init() {}
    }
    
    /// Pretty print a message
    /// - Parameters:
    ///   - message: Message to print
    ///   - options: Format options
    /// - Returns: Pretty-printed string
    public static func print(_ message: HL7v2Message, options: FormatOptions = .default) -> String {
        var result = ""
        let indent = String(repeating: " ", count: options.indentSize)
        
        for segment in message.allSegments {
            result += "\(segment.segmentID)\n"
            
            for (index, field) in segment.fields.enumerated() {
                let value = field.serialize()
                
                // Skip empty fields if requested
                if !options.showEmptyFields && value.isEmpty {
                    continue
                }
                
                // Apply max length if specified
                let displayValue: String
                if let maxLen = options.maxValueLength, value.count > maxLen {
                    displayValue = String(value.prefix(maxLen)) + "..."
                } else {
                    displayValue = value
                }
                
                // Format line
                if options.showIndices {
                    result += "\(indent)[\(index)]: \(displayValue)\n"
                } else {
                    result += "\(indent)\(displayValue)\n"
                }
            }
            
            result += "\n"
        }
        
        return result
    }
}

// MARK: - Message Diff Tool

/// Tool for generating detailed diffs between messages
public struct MessageDiff {
    /// Type of difference
    public enum DifferenceType {
        case segmentAdded
        case segmentRemoved
        case segmentModified
        case fieldChanged
    }
    
    /// A single difference
    public struct Difference {
        public let type: DifferenceType
        public let location: String
        public let oldValue: String?
        public let newValue: String?
        public let description: String
    }
    
    /// Generate a diff between two messages
    /// - Parameters:
    ///   - original: Original message
    ///   - modified: Modified message
    /// - Returns: Array of differences
    public static func diff(original: HL7v2Message, modified: HL7v2Message) -> [Difference] {
        var differences: [Difference] = []
        
        let origSegments = original.allSegments
        let modSegments = modified.allSegments
        
        // Simple diff: compare segment by segment
        let maxSegments = max(origSegments.count, modSegments.count)
        
        for i in 0..<maxSegments {
            if i >= origSegments.count {
                // Segment added
                let seg = modSegments[i]
                differences.append(Difference(
                    type: .segmentAdded,
                    location: "Segment \(i)",
                    oldValue: nil,
                    newValue: seg.segmentID,
                    description: "Segment \(seg.segmentID) added at position \(i)"
                ))
            } else if i >= modSegments.count {
                // Segment removed
                let seg = origSegments[i]
                differences.append(Difference(
                    type: .segmentRemoved,
                    location: "Segment \(i)",
                    oldValue: seg.segmentID,
                    newValue: nil,
                    description: "Segment \(seg.segmentID) removed from position \(i)"
                ))
            } else {
                // Compare segments
                let origSeg = origSegments[i]
                let modSeg = modSegments[i]
                
                if origSeg.segmentID != modSeg.segmentID {
                    differences.append(Difference(
                        type: .segmentModified,
                        location: "Segment \(i)",
                        oldValue: origSeg.segmentID,
                        newValue: modSeg.segmentID,
                        description: "Segment at position \(i) changed from \(origSeg.segmentID) to \(modSeg.segmentID)"
                    ))
                } else {
                    // Compare fields
                    let maxFields = max(origSeg.fields.count, modSeg.fields.count)
                    for fieldIndex in 0..<maxFields {
                        let oldField = fieldIndex < origSeg.fields.count ? origSeg[fieldIndex].serialize() : ""
                        let newField = fieldIndex < modSeg.fields.count ? modSeg[fieldIndex].serialize() : ""
                        
                        if oldField != newField {
                            differences.append(Difference(
                                type: .fieldChanged,
                                location: "\(origSeg.segmentID)[\(fieldIndex)]",
                                oldValue: oldField.isEmpty ? nil : oldField,
                                newValue: newField.isEmpty ? nil : newField,
                                description: "Field \(origSeg.segmentID)[\(fieldIndex)] changed"
                            ))
                        }
                    }
                }
            }
        }
        
        return differences
    }
    
    /// Generate a human-readable diff report
    /// - Parameters:
    ///   - original: Original message
    ///   - modified: Modified message
    /// - Returns: Diff report string
    public static func report(original: HL7v2Message, modified: HL7v2Message) -> String {
        let diffs = diff(original: original, modified: modified)
        
        var result = "Message Diff Report\n"
        result += "=" * 50 + "\n"
        result += "Changes: \(diffs.count)\n\n"
        
        if diffs.isEmpty {
            result += "No differences found.\n"
        } else {
            for (index, diff) in diffs.enumerated() {
                result += "\(index + 1). "
                
                switch diff.type {
                case .segmentAdded:
                    result += "➕ Added: "
                case .segmentRemoved:
                    result += "➖ Removed: "
                case .segmentModified:
                    result += "✏️ Modified: "
                case .fieldChanged:
                    result += "🔄 Changed: "
                }
                
                result += diff.description + "\n"
                
                if let old = diff.oldValue {
                    result += "   - Old: \(old)\n"
                }
                if let new = diff.newValue {
                    result += "   + New: \(new)\n"
                }
                result += "\n"
            }
        }
        
        return result
    }
}
