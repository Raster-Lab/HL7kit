/// Streaming API for processing large HL7 v2.x files
///
/// Provides memory-efficient streaming capabilities for parsing large files
/// containing multiple HL7 messages without loading the entire file into memory.

import Foundation
import HL7Core

// MARK: - Message Stream

/// Async sequence for streaming HL7 messages from a file or data source
public struct HL7MessageStream: AsyncSequence {
    public typealias Element = Result<HL7v2Message, Error>
    
    private let source: MessageStreamSource
    private let parser: HL7v2Parser
    private let bufferSize: Int
    
    /// Initialize a message stream
    /// - Parameters:
    ///   - source: Source of message data
    ///   - parser: Parser to use for messages
    ///   - bufferSize: Buffer size in bytes (default 64KB)
    public init(source: MessageStreamSource, parser: HL7v2Parser, bufferSize: Int = 65536) {
        self.source = source
        self.parser = parser
        self.bufferSize = bufferSize
    }
    
    public func makeAsyncIterator() -> HL7MessageStreamIterator {
        HL7MessageStreamIterator(
            source: source,
            parser: parser,
            bufferSize: bufferSize
        )
    }
}

// MARK: - Message Stream Source

/// Protocol for message stream data sources
public protocol MessageStreamSource: Sendable {
    /// Read next chunk of data from the source
    /// - Parameter maxBytes: Maximum bytes to read
    /// - Returns: Data read, or nil if end of source
    /// - Throws: Error if reading fails
    func readNext(maxBytes: Int) async throws -> Data?
    
    /// Close the source
    func close() async throws
}

// MARK: - File Stream Source

/// File-based message stream source
public actor FileStreamSource: MessageStreamSource {
    private let fileURL: URL
    private var fileHandle: FileHandle?
    private var isOpen: Bool = false
    
    /// Initialize with file URL
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// Open the file for reading
    private func open() throws {
        guard !isOpen else { return }
        fileHandle = try FileHandle(forReadingFrom: fileURL)
        isOpen = true
    }
    
    public func readNext(maxBytes: Int) async throws -> Data? {
        if !isOpen {
            try open()
        }
        
        guard let handle = fileHandle else {
            return nil
        }
        
        if #available(macOS 10.15.4, iOS 13.4, *) {
            let data = try handle.read(upToCount: maxBytes)
            return data?.isEmpty == false ? data : nil
        } else {
            let data = handle.readData(ofLength: maxBytes)
            return data.isEmpty ? nil : data
        }
    }
    
    public func close() async throws {
        if #available(macOS 10.15, iOS 13.0, *) {
            try fileHandle?.close()
        } else {
            fileHandle?.closeFile()
        }
        fileHandle = nil
        isOpen = false
    }
    
    deinit {
        if #available(macOS 10.15, iOS 13.0, *) {
            try? fileHandle?.close()
        } else {
            fileHandle?.closeFile()
        }
    }
}

// MARK: - Data Stream Source

/// In-memory data-based message stream source
public actor DataStreamSource: MessageStreamSource {
    private let data: Data
    private var currentPosition: Int = 0
    
    /// Initialize with data
    public init(data: Data) {
        self.data = data
    }
    
    public func readNext(maxBytes: Int) async throws -> Data? {
        guard currentPosition < data.count else {
            return nil
        }
        
        let endPosition = min(currentPosition + maxBytes, data.count)
        let chunk = data[currentPosition..<endPosition]
        currentPosition = endPosition
        
        return chunk.isEmpty ? nil : chunk
    }
    
    public func close() async throws {
        currentPosition = data.count
    }
}

// MARK: - Message Stream Iterator

/// Iterator for streaming HL7 messages
public struct HL7MessageStreamIterator: AsyncIteratorProtocol {
    public typealias Element = Result<HL7v2Message, Error>
    
    private let source: MessageStreamSource
    private let parser: HL7v2Parser
    private let bufferSize: Int
    private var buffer: String = ""
    private var isExhausted: Bool = false
    private let segmentTerminator: Character
    
    init(source: MessageStreamSource, parser: HL7v2Parser, bufferSize: Int) {
        self.source = source
        self.parser = parser
        self.bufferSize = bufferSize
        
        // Determine segment terminator from parser configuration
        switch parser.configuration.segmentTerminator {
        case .cr:
            self.segmentTerminator = "\r"
        case .lf:
            self.segmentTerminator = "\n"
        case .crlf, .any:
            self.segmentTerminator = "\r"  // Default to CR for CRLF/any
        }
    }
    
    public mutating func next() async -> Element? {
        guard !isExhausted else { return nil }
        
        do {
            // Try to extract a message from the current buffer
            if let message = try extractMessage() {
                return .success(message)
            }
            
            // Read more data until we have a complete message or reach end of source
            while !isExhausted {
                guard let data = try await source.readNext(maxBytes: bufferSize) else {
                    isExhausted = true
                    
                    // Try to parse any remaining data in buffer
                    if !buffer.isEmpty {
                        let result = try parser.parse(buffer)
                        buffer = ""
                        return .success(result.message)
                    }
                    
                    return nil
                }
                
                // Convert data to string and append to buffer
                guard let string = String(data: data, encoding: parser.configuration.encoding.stringEncoding) else {
                    return .failure(HL7Error.parsingError("Failed to decode data with encoding \(parser.configuration.encoding)"))
                }
                
                buffer += string
                
                // Try to extract a message from the updated buffer
                if let message = try extractMessage() {
                    return .success(message)
                }
            }
            
            return nil
        } catch {
            return .failure(error)
        }
    }
    
    /// Extract a complete message from the buffer
    /// - Returns: Parsed message if a complete message is available, nil otherwise
    private mutating func extractMessage() throws -> HL7v2Message? {
        // Look for message boundaries (MSH segments)
        let segments = buffer.components(separatedBy: String(segmentTerminator))
        
        // Find the start of a message (MSH segment)
        guard let firstMSHIndex = segments.firstIndex(where: { $0.hasPrefix("MSH") }) else {
            // No MSH found, keep accumulating
            return nil
        }
        
        // Find the next MSH after the first one (start of next message)
        let nextMSHIndex = segments[(firstMSHIndex + 1)...].firstIndex(where: { $0.hasPrefix("MSH") })
        
        if let nextMSH = nextMSHIndex {
            // We have a complete message
            let messageSegments = Array(segments[firstMSHIndex..<nextMSH])
            let messageString = messageSegments.joined(separator: String(segmentTerminator))
            
            // Remove parsed message from buffer
            let remainingSegments = Array(segments[nextMSH...])
            buffer = remainingSegments.joined(separator: String(segmentTerminator))
            
            let result = try parser.parse(messageString)
            return result.message
        } else if isExhausted {
            // Last message in the stream
            let messageSegments = Array(segments[firstMSHIndex...])
            let messageString = messageSegments.joined(separator: String(segmentTerminator))
            buffer = ""
            let result = try parser.parse(messageString)
            return result.message
        } else {
            // Need more data to complete the message
            return nil
        }
    }
}

// MARK: - Streaming File Reader

/// High-level API for streaming HL7 messages from files
public actor HL7FileStreamReader {
    private let parser: HL7v2Parser
    
    /// Initialize with parser
    public init(parser: HL7v2Parser = HL7v2Parser()) {
        self.parser = parser
    }
    
    /// Stream messages from a file
    /// - Parameters:
    ///   - fileURL: URL of file to read
    ///   - bufferSize: Buffer size in bytes (default 64KB)
    /// - Returns: Async sequence of message results
    public func streamMessages(from fileURL: URL, bufferSize: Int = 65536) -> HL7MessageStream {
        let source = FileStreamSource(fileURL: fileURL)
        return HL7MessageStream(source: source, parser: parser, bufferSize: bufferSize)
    }
    
    /// Stream messages from data
    /// - Parameters:
    ///   - data: Data to read
    ///   - bufferSize: Buffer size in bytes (default 64KB)
    /// - Returns: Async sequence of message results
    public func streamMessages(from data: Data, bufferSize: Int = 65536) -> HL7MessageStream {
        let source = DataStreamSource(data: data)
        return HL7MessageStream(source: source, parser: parser, bufferSize: bufferSize)
    }
    
    /// Count messages in a file without parsing them fully
    /// - Parameter fileURL: URL of file to count
    /// - Returns: Number of messages (MSH segments) in the file
    public func countMessages(in fileURL: URL) async throws -> Int {
        let source = FileStreamSource(fileURL: fileURL)
        var count = 0
        var buffer = ""
        
        while let data = try await source.readNext(maxBytes: 65536) {
            guard let string = String(data: data, encoding: .utf8) else {
                throw HL7Error.parsingError("Failed to decode file data")
            }
            buffer += string
        }
        
        try await source.close()
        
        // Count MSH segments
        count = buffer.components(separatedBy: "MSH").count - 1
        return count
    }
}

// MARK: - Batch Stream

/// Async sequence for streaming batches from a file
public struct HL7BatchStream: AsyncSequence {
    public typealias Element = Result<BatchMessage, Error>
    
    private let source: MessageStreamSource
    private let parser: HL7v2Parser
    private let bufferSize: Int
    
    /// Initialize a batch stream
    /// - Parameters:
    ///   - source: Source of batch data
    ///   - parser: Parser to use for batches
    ///   - bufferSize: Buffer size in bytes (default 64KB)
    public init(source: MessageStreamSource, parser: HL7v2Parser, bufferSize: Int = 65536) {
        self.source = source
        self.parser = parser
        self.bufferSize = bufferSize
    }
    
    public func makeAsyncIterator() -> HL7BatchStreamIterator {
        HL7BatchStreamIterator(
            source: source,
            parser: parser,
            bufferSize: bufferSize
        )
    }
}

// MARK: - Batch Stream Iterator

/// Iterator for streaming batches
public struct HL7BatchStreamIterator: AsyncIteratorProtocol {
    public typealias Element = Result<BatchMessage, Error>
    
    private let source: MessageStreamSource
    private let parser: HL7v2Parser
    private let bufferSize: Int
    private var buffer: String = ""
    private var isExhausted: Bool = false
    private let segmentTerminator: Character
    
    init(source: MessageStreamSource, parser: HL7v2Parser, bufferSize: Int) {
        self.source = source
        self.parser = parser
        self.bufferSize = bufferSize
        
        // Determine segment terminator from parser configuration
        switch parser.configuration.segmentTerminator {
        case .cr:
            self.segmentTerminator = "\r"
        case .lf:
            self.segmentTerminator = "\n"
        case .crlf, .any:
            self.segmentTerminator = "\r"
        }
    }
    
    public mutating func next() async -> Element? {
        guard !isExhausted else { return nil }
        
        do {
            // Try to extract a batch from the current buffer
            if let batch = try extractBatch() {
                return .success(batch)
            }
            
            // Read more data until we have a complete batch or reach end of source
            while !isExhausted {
                guard let data = try await source.readNext(maxBytes: bufferSize) else {
                    isExhausted = true
                    return nil
                }
                
                // Convert data to string and append to buffer
                guard let string = String(data: data, encoding: parser.configuration.encoding.stringEncoding) else {
                    return .failure(HL7Error.parsingError("Failed to decode data"))
                }
                
                buffer += string
                
                // Try to extract a batch from the updated buffer
                if let batch = try extractBatch() {
                    return .success(batch)
                }
            }
            
            return nil
        } catch {
            return .failure(error)
        }
    }
    
    /// Extract a complete batch from the buffer
    private mutating func extractBatch() throws -> BatchMessage? {
        let segments = buffer.components(separatedBy: String(segmentTerminator))
        
        // Find BHS and BTS pair
        guard let bhsIndex = segments.firstIndex(where: { $0.hasPrefix("BHS") }) else {
            return nil
        }
        
        guard let btsIndex = segments[(bhsIndex + 1)...].firstIndex(where: { $0.hasPrefix("BTS") }) else {
            // No complete batch yet
            return nil
        }
        
        // Extract batch segments
        let batchSegments = Array(segments[bhsIndex...btsIndex])
        let batchString = batchSegments.joined(separator: String(segmentTerminator))
        
        // Remove parsed batch from buffer
        let remainingSegments = Array(segments[(btsIndex + 1)...])
        buffer = remainingSegments.joined(separator: String(segmentTerminator))
        
        return try parser.parseBatch(batchString)
    }
}

extension HL7FileStreamReader {
    /// Stream batches from a file
    /// - Parameters:
    ///   - fileURL: URL of file to read
    ///   - bufferSize: Buffer size in bytes (default 64KB)
    /// - Returns: Async sequence of batch results
    public func streamBatches(from fileURL: URL, bufferSize: Int = 65536) -> HL7BatchStream {
        let source = FileStreamSource(fileURL: fileURL)
        return HL7BatchStream(source: source, parser: parser, bufferSize: bufferSize)
    }
}
