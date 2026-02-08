/// Batch and file processing support for HL7 v2.x messages
///
/// Provides support for batch (BHS/BTS) and file (FHS/FTS) structures
/// as defined in HL7 v2.x specifications.

import Foundation
import HL7Core

// MARK: - File Header Segment (FHS)

/// File Header Segment (FHS) - Identifies the start of a file
public struct FHSSegment: HL7v2Segment, Equatable {
    public let segmentID: String = "FHS"
    public let fields: [Field]
    public let encodingCharacters: EncodingCharacters
    
    /// Field 1: File Field Separator
    public var fileFieldSeparator: String {
        self[0].firstValue ?? "|"
    }
    
    /// Field 2: File Encoding Characters
    public var fileEncodingCharacters: String {
        self[1].firstValue ?? "^~\\&"
    }
    
    /// Field 3: File Sending Application
    public var fileSendingApplication: String? {
        self[2].firstValue
    }
    
    /// Field 4: File Sending Facility
    public var fileSendingFacility: String? {
        self[3].firstValue
    }
    
    /// Field 5: File Receiving Application
    public var fileReceivingApplication: String? {
        self[4].firstValue
    }
    
    /// Field 6: File Receiving Facility
    public var fileReceivingFacility: String? {
        self[5].firstValue
    }
    
    /// Field 7: File Creation Date/Time
    public var fileCreationDateTime: String? {
        self[6].firstValue
    }
    
    /// Field 8: File Security
    public var fileSecurity: String? {
        self[7].firstValue
    }
    
    /// Field 9: File Name/ID
    public var fileNameID: String? {
        self[8].firstValue
    }
    
    /// Field 10: File Header Comment
    public var fileHeaderComment: String? {
        self[9].firstValue
    }
    
    /// Field 11: File Control ID
    public var fileControlID: String? {
        self[10].firstValue
    }
    
    /// Field 12: Reference File Control ID
    public var referenceFileControlID: String? {
        self[11].firstValue
    }
    
    /// Initialize FHS segment
    public init(fields: [Field], encodingCharacters: EncodingCharacters = .standard) {
        self.fields = fields
        self.encodingCharacters = encodingCharacters
    }
    
    public subscript(index: Int) -> Field {
        guard index >= 0 && index < fields.count else {
            return Field(repetitions: [], encodingCharacters: encodingCharacters)
        }
        return fields[index]
    }
    
    public func serialize() throws -> String {
        var result = segmentID
        result += String(encodingCharacters.fieldSeparator)
        result += fileEncodingCharacters
        
        for i in 2..<fields.count {
            result += String(encodingCharacters.fieldSeparator)
            result += fields[i].serialize()
        }
        
        return result
    }
    
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) throws -> FHSSegment {
        let baseSegment = try BaseSegment.parse(rawValue, encodingCharacters: encodingCharacters)
        guard baseSegment.segmentID == "FHS" else {
            throw HL7Error.parsingError("Expected FHS segment, got \(baseSegment.segmentID)")
        }
        return FHSSegment(fields: baseSegment.fields, encodingCharacters: encodingCharacters)
    }
}

// MARK: - File Trailer Segment (FTS)

/// File Trailer Segment (FTS) - Identifies the end of a file
public struct FTSSegment: HL7v2Segment, Equatable {
    public let segmentID: String = "FTS"
    public let fields: [Field]
    public let encodingCharacters: EncodingCharacters
    
    /// Field 1: File Batch Count
    public var fileBatchCount: Int? {
        guard let value = self[0].firstValue else { return nil }
        return Int(value)
    }
    
    /// Field 2: File Trailer Comment
    public var fileTrailerComment: String? {
        self[1].firstValue
    }
    
    /// Initialize FTS segment
    public init(fields: [Field], encodingCharacters: EncodingCharacters = .standard) {
        self.fields = fields
        self.encodingCharacters = encodingCharacters
    }
    
    public subscript(index: Int) -> Field {
        guard index >= 0 && index < fields.count else {
            return Field(repetitions: [], encodingCharacters: encodingCharacters)
        }
        return fields[index]
    }
    
    public func serialize() throws -> String {
        var result = segmentID
        for field in fields {
            result += String(encodingCharacters.fieldSeparator)
            result += field.serialize()
        }
        return result
    }
    
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) throws -> FTSSegment {
        let baseSegment = try BaseSegment.parse(rawValue, encodingCharacters: encodingCharacters)
        guard baseSegment.segmentID == "FTS" else {
            throw HL7Error.parsingError("Expected FTS segment, got \(baseSegment.segmentID)")
        }
        return FTSSegment(fields: baseSegment.fields, encodingCharacters: encodingCharacters)
    }
}

// MARK: - Batch Header Segment (BHS)

/// Batch Header Segment (BHS) - Identifies the start of a batch
public struct BHSSegment: HL7v2Segment, Equatable {
    public let segmentID: String = "BHS"
    public let fields: [Field]
    public let encodingCharacters: EncodingCharacters
    
    /// Field 1: Batch Field Separator
    public var batchFieldSeparator: String {
        self[0].firstValue ?? "|"
    }
    
    /// Field 2: Batch Encoding Characters
    public var batchEncodingCharacters: String {
        self[1].firstValue ?? "^~\\&"
    }
    
    /// Field 3: Batch Sending Application
    public var batchSendingApplication: String? {
        self[2].firstValue
    }
    
    /// Field 4: Batch Sending Facility
    public var batchSendingFacility: String? {
        self[3].firstValue
    }
    
    /// Field 5: Batch Receiving Application
    public var batchReceivingApplication: String? {
        self[4].firstValue
    }
    
    /// Field 6: Batch Receiving Facility
    public var batchReceivingFacility: String? {
        self[5].firstValue
    }
    
    /// Field 7: Batch Creation Date/Time
    public var batchCreationDateTime: String? {
        self[6].firstValue
    }
    
    /// Field 8: Batch Security
    public var batchSecurity: String? {
        self[7].firstValue
    }
    
    /// Field 9: Batch Name/ID/Type
    public var batchNameIDType: String? {
        self[8].firstValue
    }
    
    /// Field 10: Batch Comment
    public var batchComment: String? {
        self[9].firstValue
    }
    
    /// Field 11: Batch Control ID
    public var batchControlID: String? {
        self[10].firstValue
    }
    
    /// Field 12: Reference Batch Control ID
    public var referenceBatchControlID: String? {
        self[11].firstValue
    }
    
    /// Initialize BHS segment
    public init(fields: [Field], encodingCharacters: EncodingCharacters = .standard) {
        self.fields = fields
        self.encodingCharacters = encodingCharacters
    }
    
    public subscript(index: Int) -> Field {
        guard index >= 0 && index < fields.count else {
            return Field(repetitions: [], encodingCharacters: encodingCharacters)
        }
        return fields[index]
    }
    
    public func serialize() throws -> String {
        var result = segmentID
        result += String(encodingCharacters.fieldSeparator)
        result += batchEncodingCharacters
        
        for i in 2..<fields.count {
            result += String(encodingCharacters.fieldSeparator)
            result += fields[i].serialize()
        }
        
        return result
    }
    
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) throws -> BHSSegment {
        let baseSegment = try BaseSegment.parse(rawValue, encodingCharacters: encodingCharacters)
        guard baseSegment.segmentID == "BHS" else {
            throw HL7Error.parsingError("Expected BHS segment, got \(baseSegment.segmentID)")
        }
        return BHSSegment(fields: baseSegment.fields, encodingCharacters: encodingCharacters)
    }
}

// MARK: - Batch Trailer Segment (BTS)

/// Batch Trailer Segment (BTS) - Identifies the end of a batch
public struct BTSSegment: HL7v2Segment, Equatable {
    public let segmentID: String = "BTS"
    public let fields: [Field]
    public let encodingCharacters: EncodingCharacters
    
    /// Field 1: Batch Message Count
    public var batchMessageCount: Int? {
        guard let value = self[0].firstValue else { return nil }
        return Int(value)
    }
    
    /// Field 2: Batch Comment
    public var batchComment: String? {
        self[1].firstValue
    }
    
    /// Field 3: Batch Totals (optional repeating field)
    public var batchTotals: [String] {
        self[2].repetitions.compactMap { $0.first?.firstValue }
    }
    
    /// Initialize BTS segment
    public init(fields: [Field], encodingCharacters: EncodingCharacters = .standard) {
        self.fields = fields
        self.encodingCharacters = encodingCharacters
    }
    
    public subscript(index: Int) -> Field {
        guard index >= 0 && index < fields.count else {
            return Field(repetitions: [], encodingCharacters: encodingCharacters)
        }
        return fields[index]
    }
    
    public func serialize() throws -> String {
        var result = segmentID
        for field in fields {
            result += String(encodingCharacters.fieldSeparator)
            result += field.serialize()
        }
        return result
    }
    
    public static func parse(_ rawValue: String, encodingCharacters: EncodingCharacters = .standard) throws -> BTSSegment {
        let baseSegment = try BaseSegment.parse(rawValue, encodingCharacters: encodingCharacters)
        guard baseSegment.segmentID == "BTS" else {
            throw HL7Error.parsingError("Expected BTS segment, got \(baseSegment.segmentID)")
        }
        return BTSSegment(fields: baseSegment.fields, encodingCharacters: encodingCharacters)
    }
}

// MARK: - Batch Message Container

/// Container for a batch of HL7 messages
public struct BatchMessage: Sendable, Equatable {
    /// Batch header segment
    public let header: BHSSegment
    /// Messages in the batch
    public let messages: [HL7v2Message]
    /// Batch trailer segment
    public let trailer: BTSSegment
    
    /// Initialize a batch message
    public init(header: BHSSegment, messages: [HL7v2Message], trailer: BTSSegment) {
        self.header = header
        self.messages = messages
        self.trailer = trailer
    }
    
    /// Validate batch message count matches trailer
    public func validate() -> Bool {
        guard let trailerCount = trailer.batchMessageCount else { return false }
        return trailerCount == messages.count
    }
    
    /// Serialize batch to string
    public func serialize() throws -> String {
        var result = try header.serialize()
        result += "\r"
        
        for message in messages {
            result += try message.serialize()
            result += "\r"
        }
        
        result += try trailer.serialize()
        return result
    }
}

// MARK: - File Message Container

/// Container for a file of batches or messages
public struct FileMessage: Sendable, Equatable {
    /// File header segment
    public let header: FHSSegment
    /// Batches in the file
    public let batches: [BatchMessage]
    /// Individual messages (if not in batches)
    public let messages: [HL7v2Message]
    /// File trailer segment
    public let trailer: FTSSegment
    
    /// Initialize a file message
    public init(header: FHSSegment, batches: [BatchMessage] = [], messages: [HL7v2Message] = [], trailer: FTSSegment) {
        self.header = header
        self.batches = batches
        self.messages = messages
        self.trailer = trailer
    }
    
    /// Validate file batch count matches trailer
    public func validate() -> Bool {
        guard let trailerCount = trailer.fileBatchCount else { return false }
        // Count can be either number of batches or total messages
        return trailerCount == batches.count || trailerCount == (batches.count + messages.count)
    }
    
    /// Serialize file to string
    public func serialize() throws -> String {
        var result = try header.serialize()
        result += "\r"
        
        for batch in batches {
            result += try batch.serialize()
            result += "\r"
        }
        
        for message in messages {
            result += try message.serialize()
            result += "\r"
        }
        
        result += try trailer.serialize()
        return result
    }
}

// MARK: - Batch/File Parser Extensions

extension HL7v2Parser {
    /// Parse a batch message
    /// - Parameter rawValue: Raw batch string
    /// - Returns: Parsed batch message
    /// - Throws: HL7Error if parsing fails
    public func parseBatch(_ rawValue: String) throws -> BatchMessage {
        let segments = configuration.segmentTerminator.split(rawValue)
        
        guard segments.count >= 2 else {
            throw HL7Error.parsingError("Batch must have at least BHS and BTS segments")
        }
        
        // Parse BHS
        guard segments[0].hasPrefix("BHS") else {
            throw HL7Error.parsingError("Batch must start with BHS segment")
        }
        let header = try BHSSegment.parse(segments[0])
        
        // Parse BTS
        guard segments[segments.count - 1].hasPrefix("BTS") else {
            throw HL7Error.parsingError("Batch must end with BTS segment")
        }
        let trailer = try BTSSegment.parse(segments[segments.count - 1])
        
        // Parse messages between BHS and BTS
        var messages: [HL7v2Message] = []
        var currentMessageSegments: [String] = []
        
        for i in 1..<(segments.count - 1) {
            let segment = segments[i]
            
            // Check if this is the start of a new message (MSH segment)
            if segment.hasPrefix("MSH") {
                // If we have accumulated segments, parse the previous message
                if !currentMessageSegments.isEmpty {
                    let messageString = currentMessageSegments.joined(separator: "\r")
                    let result = try parse(messageString)
                    messages.append(result.message)
                    currentMessageSegments = []
                }
            }
            
            currentMessageSegments.append(segment)
        }
        
        // Parse the last accumulated message
        if !currentMessageSegments.isEmpty {
            let messageString = currentMessageSegments.joined(separator: "\r")
            let result = try parse(messageString)
            messages.append(result.message)
        }
        
        return BatchMessage(header: header, messages: messages, trailer: trailer)
    }
    
    /// Parse a file message
    /// - Parameter rawValue: Raw file string
    /// - Returns: Parsed file message
    /// - Throws: HL7Error if parsing fails
    public func parseFile(_ rawValue: String) throws -> FileMessage {
        let segments = configuration.segmentTerminator.split(rawValue)
        
        guard segments.count >= 2 else {
            throw HL7Error.parsingError("File must have at least FHS and FTS segments")
        }
        
        // Parse FHS
        guard segments[0].hasPrefix("FHS") else {
            throw HL7Error.parsingError("File must start with FHS segment")
        }
        let header = try FHSSegment.parse(segments[0])
        
        // Parse FTS
        guard segments[segments.count - 1].hasPrefix("FTS") else {
            throw HL7Error.parsingError("File must end with FTS segment")
        }
        let trailer = try FTSSegment.parse(segments[segments.count - 1])
        
        // Parse batches and messages between FHS and FTS
        var batches: [BatchMessage] = []
        var messages: [HL7v2Message] = []
        var currentBatchSegments: [String] = []
        var currentMessageSegments: [String] = []
        var inBatch = false
        
        for i in 1..<(segments.count - 1) {
            let segment = segments[i]
            
            if segment.hasPrefix("BHS") {
                // Start of a batch
                inBatch = true
                currentBatchSegments = [segment]
            } else if segment.hasPrefix("BTS") {
                // End of a batch
                currentBatchSegments.append(segment)
                let batchString = currentBatchSegments.joined(separator: "\r")
                let batch = try parseBatch(batchString)
                batches.append(batch)
                currentBatchSegments = []
                inBatch = false
            } else if inBatch {
                // Segment within a batch
                currentBatchSegments.append(segment)
            } else {
                // Individual message outside of a batch
                if segment.hasPrefix("MSH") {
                    // Start of a new message
                    if !currentMessageSegments.isEmpty {
                        let messageString = currentMessageSegments.joined(separator: "\r")
                        let result = try parse(messageString)
                        messages.append(result.message)
                        currentMessageSegments = []
                    }
                }
                currentMessageSegments.append(segment)
            }
        }
        
        // Parse the last accumulated message if any
        if !currentMessageSegments.isEmpty {
            let messageString = currentMessageSegments.joined(separator: "\r")
            let result = try parse(messageString)
            messages.append(result.message)
        }
        
        return FileMessage(header: header, batches: batches, messages: messages, trailer: trailer)
    }
}
