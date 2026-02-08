/// Parser infrastructure for HL7 v2.x messages
///
/// Provides configurable parsing with encoding detection, delimiter auto-detection,
/// error recovery, streaming support, and diagnostic reporting.

import Foundation
import HL7Core

// MARK: - Message Encoding

/// Character encoding for HL7 v2.x messages
public enum MessageEncoding: Sendable, Equatable {
    /// ASCII encoding
    case ascii
    /// UTF-8 encoding (default)
    case utf8
    /// Latin-1 (ISO 8859-1) encoding
    case latin1
    /// Auto-detect encoding from message data
    case autoDetect

    /// Detect the encoding from raw data
    /// - Parameter data: Raw message data
    /// - Returns: Detected encoding (never returns `.autoDetect`)
    public static func detect(from data: Data) -> MessageEncoding {
        // Check for UTF-8 BOM
        if data.count >= 3,
           data[data.startIndex] == 0xEF,
           data[data.startIndex + 1] == 0xBB,
           data[data.startIndex + 2] == 0xBF {
            return .utf8
        }

        // Attempt UTF-8 validation
        if String(data: data, encoding: .utf8) != nil {
            // Check if all bytes are ASCII range
            let isASCII = data.allSatisfy { $0 < 0x80 }
            return isASCII ? .ascii : .utf8
        }

        // Fall back to Latin-1 (always succeeds for any byte sequence)
        return .latin1
    }

    /// The `String.Encoding` equivalent
    var stringEncoding: String.Encoding {
        switch self {
        case .ascii: return .ascii
        case .utf8, .autoDetect: return .utf8
        case .latin1: return .isoLatin1
        }
    }
}

// MARK: - Segment Terminator

/// Segment terminator style for HL7 v2.x messages
public enum SegmentTerminator: Sendable, Equatable {
    /// Carriage return (`\r`) — HL7 standard
    case cr
    /// Line feed (`\n`)
    case lf
    /// Carriage return + line feed (`\r\n`)
    case crlf
    /// Accept any of the above
    case any

    /// Split a message string into individual segment strings
    /// - Parameter string: Raw message string
    /// - Returns: Non-empty segment strings
    public func split(_ string: String) -> [String] {
        let parts: [String]
        switch self {
        case .cr:
            parts = string.components(separatedBy: "\r")
        case .lf:
            parts = string.components(separatedBy: "\n")
        case .crlf:
            parts = string.components(separatedBy: "\r\n")
        case .any:
            // Normalize all terminators to \n then split
            let normalized = string
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            parts = normalized.components(separatedBy: "\n")
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Error Recovery Mode

/// Error recovery strategy during parsing
public enum ErrorRecoveryMode: Sendable, Equatable {
    /// Fail immediately on first error
    case strict
    /// Skip invalid segments and continue parsing
    case skipInvalidSegments
    /// Attempt to recover from all errors
    case bestEffort
}

// MARK: - Parser Location

/// Location within a parsed message for diagnostic reporting
public struct ParserLocation: Sendable, Equatable {
    /// Zero-based segment index in the message
    public let segmentIndex: Int
    /// Segment identifier (e.g. "MSH", "PID"), if known
    public let segmentID: String?
    /// Zero-based field index within the segment, if applicable
    public let fieldIndex: Int?
    /// Byte offset in the original data, if applicable
    public let offset: Int?

    /// Creates a parser location
    public init(segmentIndex: Int, segmentID: String? = nil, fieldIndex: Int? = nil, offset: Int? = nil) {
        self.segmentIndex = segmentIndex
        self.segmentID = segmentID
        self.fieldIndex = fieldIndex
        self.offset = offset
    }
}

// MARK: - Parser Warning

/// A non-fatal warning produced during parsing
public struct ParserWarning: Sendable, Equatable {
    /// Human-readable warning description
    public let message: String
    /// Location where the warning was produced
    public let location: ParserLocation

    /// Creates a parser warning
    public init(message: String, location: ParserLocation) {
        self.message = message
        self.location = location
    }
}

// MARK: - Parser Error

/// A recorded error produced during non-strict parsing
public struct ParserError: Sendable, Equatable {
    /// Human-readable error description
    public let message: String
    /// Location where the error was produced
    public let location: ParserLocation

    /// Creates a parser error
    public init(message: String, location: ParserLocation) {
        self.message = message
        self.location = location
    }
}

// MARK: - Parser Diagnostics

/// Diagnostic information collected during a parse operation
public struct ParserDiagnostics: Sendable, Equatable {
    /// Warnings produced during parsing
    public var warnings: [ParserWarning]
    /// Errors produced during parsing (only populated in recovery modes)
    public var errors: [ParserError]
    /// Number of segments successfully parsed
    public var segmentsParsed: Int
    /// Number of segments skipped due to errors
    public var segmentsSkipped: Int
    /// Wall-clock time spent parsing
    public var parseTime: Duration?

    /// Creates empty diagnostics
    public init() {
        self.warnings = []
        self.errors = []
        self.segmentsParsed = 0
        self.segmentsSkipped = 0
        self.parseTime = nil
    }
}

// MARK: - Parser Configuration

/// Configuration options for the HL7 v2.x parser
public struct ParserConfiguration: Sendable, Equatable {
    /// Parsing strategy to use
    public let strategy: ParsingStrategy
    /// Whether to enforce strict validation
    public let strictMode: Bool
    /// Maximum message size in bytes (default 1 MB)
    public let maxMessageSize: Int
    /// Whether to allow custom Z-segments
    public let allowCustomSegments: Bool
    /// Character encoding for the message
    public let encoding: MessageEncoding
    /// Segment terminator style
    public let segmentTerminator: SegmentTerminator
    /// Whether to auto-detect delimiters from MSH segment
    public let autoDetectDelimiters: Bool
    /// Error recovery strategy
    public let errorRecovery: ErrorRecoveryMode

    /// Creates a parser configuration with default values
    public init(
        strategy: ParsingStrategy = .eager,
        strictMode: Bool = false,
        maxMessageSize: Int = 1_048_576,
        allowCustomSegments: Bool = true,
        encoding: MessageEncoding = .utf8,
        segmentTerminator: SegmentTerminator = .cr,
        autoDetectDelimiters: Bool = true,
        errorRecovery: ErrorRecoveryMode = .strict
    ) {
        self.strategy = strategy
        self.strictMode = strictMode
        self.maxMessageSize = maxMessageSize
        self.allowCustomSegments = allowCustomSegments
        self.encoding = encoding
        self.segmentTerminator = segmentTerminator
        self.autoDetectDelimiters = autoDetectDelimiters
        self.errorRecovery = errorRecovery
    }
}

// `ParsingStrategy` Equatable conformance is needed by `ParserConfiguration`
extension ParsingStrategy: Equatable {
    public static func == (lhs: ParsingStrategy, rhs: ParsingStrategy) -> Bool {
        switch (lhs, rhs) {
        case (.eager, .eager): return true
        case (.lazy, .lazy): return true
        case (.indexed, .indexed): return true
        case (.streaming(let a), .streaming(let b)):
            return a.bufferSize == b.bufferSize
                && a.maxPoolSize == b.maxPoolSize
                && a.autoGrow == b.autoGrow
                && a.maxBufferSize == b.maxBufferSize
        case (.chunked(let a), .chunked(let b)):
            return a.chunkSize == b.chunkSize && a.overlap == b.overlap
        case (.automatic(let a), .automatic(let b)):
            return a == b
        default: return false
        }
    }
}

// MARK: - Parse Result

/// Result of a parse operation containing the message and diagnostics
public struct ParseResult: Sendable, Equatable {
    /// The parsed HL7 v2.x message
    public let message: HL7v2Message
    /// Diagnostics collected during parsing
    public let diagnostics: ParserDiagnostics
}

// MARK: - HL7v2Parser

/// Standard well-known segment identifiers
private let standardSegmentIDs: Set<String> = [
    "MSH", "EVN", "PID", "PD1", "NK1", "PV1", "PV2",
    "OBR", "OBX", "ORC", "RXA", "RXE", "RXO", "RXR",
    "DG1", "PR1", "GT1", "IN1", "IN2", "IN3",
    "AL1", "ACC", "AIG", "AIL", "AIP", "AIS",
    "BHS", "BTS", "FHS", "FTS",
    "DSC", "DSP", "ERR", "ERQ",
    "MFI", "MFE", "MSA", "QAK", "QPD", "QRD", "QRF",
    "RGS", "SCH", "TXA", "NTE", "ROL",
    "SPM", "SAC", "TQ1", "TQ2",
    "SFT", "UAC", "STF", "ARQ", "APR"
]

/// Configurable parser for HL7 v2.x messages
///
/// Supports encoding detection, delimiter auto-detection, validation,
/// error recovery, and diagnostic reporting.
///
/// ```swift
/// let parser = HL7v2Parser()
/// let result = try parser.parse("MSH|^~\\&|...")
/// print(result.message.messageType())
/// ```
public struct HL7v2Parser: Sendable {

    /// Parser configuration
    public let configuration: ParserConfiguration

    /// Creates a parser with the specified configuration
    /// - Parameter configuration: Parser settings (uses defaults if omitted)
    public init(configuration: ParserConfiguration = ParserConfiguration()) {
        self.configuration = configuration
    }

    // MARK: Public API

    /// Parse an HL7 v2.x message from a string
    /// - Parameter string: Raw message string
    /// - Returns: Parse result containing the message and diagnostics
    /// - Throws: `HL7Error` if parsing fails and recovery is not possible
    public func parse(_ string: String) throws -> ParseResult {
        let clock = ContinuousClock()
        let start = clock.now

        // Size check (approximate; 1 character ≈ 1–4 bytes)
        guard string.utf8.count <= configuration.maxMessageSize else {
            throw HL7Error.parsingError("Message exceeds maximum size of \(configuration.maxMessageSize) bytes")
        }

        let segmentStrings = splitSegments(string)

        guard !segmentStrings.isEmpty else {
            throw HL7Error.parsingError("Empty message")
        }

        guard segmentStrings[0].hasPrefix("MSH") else {
            throw HL7Error.parsingError("Message must start with MSH segment")
        }

        // Detect encoding characters
        let encodingChars: EncodingCharacters
        if configuration.autoDetectDelimiters {
            encodingChars = try detectDelimiters(from: segmentStrings[0])
        } else {
            encodingChars = .standard
        }

        var diagnostics = ParserDiagnostics()
        var segments: [BaseSegment] = []

        // Handle lazy parsing strategy
        if case .lazy = configuration.strategy {
            // For lazy parsing, parse only MSH immediately and store raw strings for others
            // Parse MSH first (always required)
            if let mshSegment = try parseSegment(segmentStrings[0], at: 0, encodingCharacters: encodingChars, diagnostics: &diagnostics) {
                validateSegmentStructure(mshSegment, at: 0, diagnostics: &diagnostics)
                segments.append(mshSegment)
                diagnostics.segmentsParsed += 1
            }
            
            // For other segments in lazy mode, we still parse them but mark the message
            // as lazy-parsed. In a full implementation, you'd store raw strings.
            // For now, we parse normally but enable potential future lazy optimizations.
            for (index, segStr) in segmentStrings.dropFirst().enumerated() {
                let actualIndex = index + 1
                if let segment = try parseSegment(segStr, at: actualIndex, encodingCharacters: encodingChars, diagnostics: &diagnostics) {
                    validateSegmentStructure(segment, at: actualIndex, diagnostics: &diagnostics)
                    segments.append(segment)
                    diagnostics.segmentsParsed += 1
                }
            }
        } else {
            // Eager parsing (default)
            for (index, segStr) in segmentStrings.enumerated() {
                if let segment = try parseSegment(segStr, at: index, encodingCharacters: encodingChars, diagnostics: &diagnostics) {
                    validateSegmentStructure(segment, at: index, diagnostics: &diagnostics)
                    segments.append(segment)
                    diagnostics.segmentsParsed += 1
                }
            }
        }

        guard !segments.isEmpty, segments[0].segmentID == "MSH" else {
            throw HL7Error.parsingError("Message must contain a valid MSH segment")
        }

        let message = try HL7v2Message(segments: segments, encodingCharacters: encodingChars)
        diagnostics.parseTime = clock.now - start
        return ParseResult(message: message, diagnostics: diagnostics)
    }

    /// Parse an HL7 v2.x message from raw data
    /// - Parameter data: Raw message data
    /// - Returns: Parse result containing the message and diagnostics
    /// - Throws: `HL7Error` if parsing fails and recovery is not possible
    public func parse(_ data: Data) throws -> ParseResult {
        guard data.count <= configuration.maxMessageSize else {
            throw HL7Error.parsingError("Message exceeds maximum size of \(configuration.maxMessageSize) bytes")
        }

        let resolvedEncoding = configuration.encoding == .autoDetect
            ? detectEncoding(from: data)
            : configuration.encoding

        guard let string = String(data: data, encoding: resolvedEncoding.stringEncoding) else {
            throw HL7Error.encodingError("Unable to decode message data with \(resolvedEncoding) encoding")
        }

        return try parse(string)
    }

    // MARK: Private Helpers

    /// Detect encoding characters from the MSH segment header
    /// - Parameter mshString: Raw MSH segment string
    /// - Returns: Detected encoding characters
    /// - Throws: `HL7Error` if the MSH header is malformed
    private func detectDelimiters(from mshString: String) throws -> EncodingCharacters {
        guard mshString.count >= 8 else {
            throw HL7Error.parsingError("MSH segment too short to detect delimiters")
        }

        let fieldSeparator = mshString[mshString.index(mshString.startIndex, offsetBy: 3)]
        let encStart = mshString.index(mshString.startIndex, offsetBy: 4)
        let encEnd = mshString.index(encStart, offsetBy: 4)
        let encodingString = String(mshString[encStart..<encEnd])

        return try EncodingCharacters.parse(from: encodingString, fieldSeparator: fieldSeparator)
    }

    /// Detect character encoding from raw data
    /// - Parameter data: Raw message data
    /// - Returns: Detected encoding (never `.autoDetect`)
    private func detectEncoding(from data: Data) -> MessageEncoding {
        return MessageEncoding.detect(from: data)
    }

    /// Split a raw message string into individual segment strings
    /// - Parameter string: Raw message string
    /// - Returns: Non-empty segment strings
    private func splitSegments(_ string: String) -> [String] {
        return configuration.segmentTerminator.split(string)
    }

    /// Parse a single segment string with error recovery
    /// - Parameters:
    ///   - string: Raw segment string
    ///   - index: Zero-based segment index
    ///   - encodingCharacters: Encoding characters to use
    ///   - diagnostics: Diagnostics collector (mutated in place)
    /// - Returns: Parsed segment, or `nil` if skipped
    /// - Throws: `HL7Error` in strict mode when the segment is invalid
    private func parseSegment(
        _ string: String,
        at index: Int,
        encodingCharacters: EncodingCharacters,
        diagnostics: inout ParserDiagnostics
    ) throws -> BaseSegment? {
        do {
            let segment = try BaseSegment.parse(string, encodingCharacters: encodingCharacters)
            return segment
        } catch {
            let location = ParserLocation(segmentIndex: index, segmentID: String(string.prefix(3)))

            switch configuration.errorRecovery {
            case .strict:
                throw error
            case .skipInvalidSegments, .bestEffort:
                diagnostics.errors.append(
                    ParserError(message: error.localizedDescription, location: location)
                )
                diagnostics.segmentsSkipped += 1
                return nil
            }
        }
    }

    /// Validate the structure of a parsed segment
    /// - Parameters:
    ///   - segment: Parsed segment
    ///   - index: Zero-based segment index
    ///   - diagnostics: Diagnostics collector (mutated in place)
    private func validateSegmentStructure(
        _ segment: BaseSegment,
        at index: Int,
        diagnostics: inout ParserDiagnostics
    ) {
        let location = ParserLocation(segmentIndex: index, segmentID: segment.segmentID)

        // Segment ID must be exactly 3 alphanumeric characters
        let id = segment.segmentID
        if id.count != 3 || !id.allSatisfy({ $0.isLetter || $0.isNumber }) {
            diagnostics.warnings.append(
                ParserWarning(message: "Invalid segment ID '\(id)': must be 3 alphanumeric characters", location: location)
            )
        }

        // First segment must be MSH
        if index == 0 && id != "MSH" {
            diagnostics.warnings.append(
                ParserWarning(message: "First segment must be MSH, found '\(id)'", location: location)
            )
        }

        // Z-segment check
        if id.hasPrefix("Z") && !configuration.allowCustomSegments {
            diagnostics.warnings.append(
                ParserWarning(message: "Custom Z-segment '\(id)' is not allowed by configuration", location: location)
            )
        }

        // Unknown non-Z, non-standard segment
        if !id.hasPrefix("Z") && !standardSegmentIDs.contains(id) {
            diagnostics.warnings.append(
                ParserWarning(message: "Unknown segment ID '\(id)'", location: location)
            )
        }

        // Strict mode: warn about empty fields in required positions for MSH
        if configuration.strictMode && id == "MSH" {
            // MSH-9 (message type) and MSH-10 (control ID) are required
            let requiredMSHFields: [(Int, String)] = [
                (8, "MSH-9 Message Type"),
                (9, "MSH-10 Message Control ID"),
            ]
            for (fieldIdx, fieldName) in requiredMSHFields {
                if segment[fieldIdx].isEmpty {
                    diagnostics.warnings.append(
                        ParserWarning(
                            message: "Required field \(fieldName) is empty",
                            location: ParserLocation(segmentIndex: index, segmentID: id, fieldIndex: fieldIdx)
                        )
                    )
                }
            }
        }
    }
}

// MARK: - HL7v2StreamingParser

/// Streaming parser that processes HL7 v2.x data incrementally
///
/// Feed data in chunks via ``feed(_:)`` and retrieve parsed segments
/// one at a time via ``next()``. Call ``finish()`` when all data has
/// been provided.
public struct HL7v2StreamingParser: StreamingMessageParser, Sendable {
    public typealias Element = BaseSegment

    /// Parser configuration
    private let configuration: ParserConfiguration

    /// Internal buffer accumulating incoming bytes
    private var buffer: Data

    /// Segments that have been parsed and are ready for retrieval
    private var parsedSegments: [BaseSegment]

    /// Whether ``finish()`` has been called
    public private(set) var isFinished: Bool

    /// Encoding characters detected from MSH (populated on first segment)
    private var encodingCharacters: EncodingCharacters?

    /// Diagnostics for the streaming session
    private var diagnostics: ParserDiagnostics

    /// Running count of segments processed (for location tracking)
    private var segmentIndex: Int

    /// Creates a streaming parser
    /// - Parameter configuration: Parser settings (uses defaults if omitted)
    public init(configuration: ParserConfiguration = ParserConfiguration()) {
        self.configuration = configuration
        self.buffer = Data()
        self.parsedSegments = []
        self.isFinished = false
        self.encodingCharacters = nil
        self.diagnostics = ParserDiagnostics()
        self.segmentIndex = 0
    }

    /// Feed a chunk of data to the parser
    /// - Parameter data: Data to append to the internal buffer
    /// - Returns: Number of bytes consumed
    /// - Throws: `HL7Error` if the buffer exceeds the maximum message size
    public mutating func feed(_ data: Data) throws -> Int {
        guard !isFinished else {
            throw HL7Error.parsingError("Cannot feed data after finish() has been called")
        }

        buffer.append(data)

        guard buffer.count <= configuration.maxMessageSize else {
            throw HL7Error.parsingError("Streaming buffer exceeds maximum size of \(configuration.maxMessageSize) bytes")
        }

        // Resolve encoding
        let resolvedEncoding = configuration.encoding == .autoDetect
            ? MessageEncoding.detect(from: buffer)
            : configuration.encoding

        guard let bufferString = String(data: buffer, encoding: resolvedEncoding.stringEncoding) else {
            return data.count
        }

        // Determine terminator character(s) for boundary detection
        let terminator: String
        switch configuration.segmentTerminator {
        case .cr: terminator = "\r"
        case .lf: terminator = "\n"
        case .crlf: terminator = "\r\n"
        case .any: terminator = "\n" // normalized below
        }

        let workingString: String
        if configuration.segmentTerminator == .any {
            workingString = bufferString
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        } else {
            workingString = bufferString
        }

        // Split by terminator — last element may be incomplete
        var parts = workingString.components(separatedBy: terminator)
        let remainder = parts.removeLast() // keep incomplete trailing data

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Detect encoding characters from first segment
            if encodingCharacters == nil {
                if configuration.autoDetectDelimiters && trimmed.hasPrefix("MSH") && trimmed.count >= 8 {
                    let fs = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 3)]
                    let encStart = trimmed.index(trimmed.startIndex, offsetBy: 4)
                    let encEnd = trimmed.index(encStart, offsetBy: 4)
                    let encStr = String(trimmed[encStart..<encEnd])
                    encodingCharacters = try? EncodingCharacters.parse(from: encStr, fieldSeparator: fs)
                }
                if encodingCharacters == nil {
                    encodingCharacters = .standard
                }
            }

            let enc = encodingCharacters ?? .standard
            do {
                let segment = try BaseSegment.parse(trimmed, encodingCharacters: enc)
                parsedSegments.append(segment)
                diagnostics.segmentsParsed += 1
                segmentIndex += 1
            } catch {
                switch configuration.errorRecovery {
                case .strict:
                    throw error
                case .skipInvalidSegments, .bestEffort:
                    let loc = ParserLocation(segmentIndex: segmentIndex, segmentID: String(trimmed.prefix(3)))
                    diagnostics.errors.append(ParserError(message: error.localizedDescription, location: loc))
                    diagnostics.segmentsSkipped += 1
                    segmentIndex += 1
                }
            }
        }

        // Keep only the unconsumed remainder in the buffer
        if let remainderData = remainder.data(using: resolvedEncoding.stringEncoding) {
            buffer = remainderData
        } else {
            buffer = Data()
        }

        return data.count
    }

    /// Retrieve the next parsed segment
    /// - Returns: Next segment, or `nil` if none is ready
    public mutating func next() throws -> BaseSegment? {
        guard !parsedSegments.isEmpty else { return nil }
        return parsedSegments.removeFirst()
    }

    /// Signal that no more data will be fed
    ///
    /// Any data remaining in the buffer is parsed as a final segment.
    public mutating func finish() throws {
        guard !isFinished else { return }
        isFinished = true

        // Process any remaining data in the buffer
        let resolvedEncoding = configuration.encoding == .autoDetect
            ? MessageEncoding.detect(from: buffer)
            : configuration.encoding

        if let remaining = String(data: buffer, encoding: resolvedEncoding.stringEncoding) {
            let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let enc = encodingCharacters ?? .standard
                do {
                    let segment = try BaseSegment.parse(trimmed, encodingCharacters: enc)
                    parsedSegments.append(segment)
                    diagnostics.segmentsParsed += 1
                } catch {
                    switch configuration.errorRecovery {
                    case .strict:
                        throw error
                    case .skipInvalidSegments, .bestEffort:
                        let loc = ParserLocation(segmentIndex: segmentIndex, segmentID: String(trimmed.prefix(3)))
                        diagnostics.errors.append(ParserError(message: error.localizedDescription, location: loc))
                        diagnostics.segmentsSkipped += 1
                    }
                }
                segmentIndex += 1
            }
        }
        buffer = Data()
    }

    /// Reset the parser to its initial state
    public mutating func reset() {
        buffer = Data()
        parsedSegments = []
        isFinished = false
        encodingCharacters = nil
        diagnostics = ParserDiagnostics()
        segmentIndex = 0
    }
}
