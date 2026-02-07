/// HL7Core - Shared utilities and protocols for HL7kit framework
///
/// This module provides common functionality shared across HL7 v2.x, v3.x, and FHIR implementations.
/// It includes base protocols, error handling, logging, and utility functions.

import Foundation

/// Version information for HL7Core
public struct HL7CoreVersion {
    /// The current version of HL7Core
    public static let version = "0.1.0"
    
    /// The Swift version used to build this framework
    public static let swiftVersion = "6.0"
}

/// Base protocol for all HL7 message types
public protocol HL7Message: Sendable {
    /// Unique message identifier
    var messageID: String { get }
    
    /// Message creation timestamp
    var timestamp: Date { get }
    
    /// Validates the message structure and content
    /// - Throws: `HL7Error` if validation fails
    func validate() throws
}

/// Common errors for HL7 operations
public enum HL7Error: Error, Sendable {
    /// Invalid message format
    case invalidFormat(String, context: ErrorContext? = nil)
    
    /// Missing required field
    case missingRequiredField(String, context: ErrorContext? = nil)
    
    /// Invalid data type
    case invalidDataType(String, context: ErrorContext? = nil)
    
    /// Parsing error
    case parsingError(String, context: ErrorContext? = nil)
    
    /// Validation error
    case validationError(String, context: ErrorContext? = nil)
    
    /// Network error
    case networkError(String, context: ErrorContext? = nil)
    
    /// Encoding error
    case encodingError(String, context: ErrorContext? = nil)
    
    /// Timeout error
    case timeout(String, context: ErrorContext? = nil)
    
    /// Authentication error
    case authenticationError(String, context: ErrorContext? = nil)
    
    /// Configuration error
    case configurationError(String, context: ErrorContext? = nil)
    
    /// Unknown error
    case unknown(String, context: ErrorContext? = nil)
    
    /// Get the error context if available
    public var context: ErrorContext? {
        switch self {
        case .invalidFormat(_, let context),
             .missingRequiredField(_, let context),
             .invalidDataType(_, let context),
             .parsingError(_, let context),
             .validationError(_, let context),
             .networkError(_, let context),
             .encodingError(_, let context),
             .timeout(_, let context),
             .authenticationError(_, let context),
             .configurationError(_, let context),
             .unknown(_, let context):
            return context
        }
    }
    
    /// Get the error message
    public var message: String {
        switch self {
        case .invalidFormat(let msg, _),
             .missingRequiredField(let msg, _),
             .invalidDataType(let msg, _),
             .parsingError(let msg, _),
             .validationError(let msg, _),
             .networkError(let msg, _),
             .encodingError(let msg, _),
             .timeout(let msg, _),
             .authenticationError(let msg, _),
             .configurationError(let msg, _),
             .unknown(let msg, _):
            return msg
        }
    }
}

/// Context information for errors
public struct ErrorContext: Sendable {
    /// Location where error occurred (e.g., file path, field path)
    public let location: String?
    
    /// Line number where error occurred
    public let line: Int?
    
    /// Column number where error occurred
    public let column: Int?
    
    /// Additional metadata
    public let metadata: [String: String]
    
    /// Underlying error if this error wraps another
    public let underlyingError: String?
    
    public init(
        location: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        metadata: [String: String] = [:],
        underlyingError: Error? = nil
    ) {
        self.location = location
        self.line = line
        self.column = column
        self.metadata = metadata
        self.underlyingError = underlyingError?.localizedDescription
    }
}

/// Base protocol for HL7 parsers
public protocol HL7Parser: Sendable {
    associatedtype MessageType: HL7Message
    
    /// Parse raw data into a message
    /// - Parameter data: Raw message data
    /// - Returns: Parsed message
    /// - Throws: `HL7Error` if parsing fails
    func parse(_ data: Data) throws -> MessageType
}

/// Base protocol for HL7 serializers
public protocol HL7Serializer: Sendable {
    associatedtype MessageType: HL7Message
    
    /// Serialize a message into raw data
    /// - Parameter message: Message to serialize
    /// - Returns: Serialized message data
    /// - Throws: `HL7Error` if serialization fails
    func serialize(_ message: MessageType) throws -> Data
}

/// Logging levels for HL7 operations
public enum HL7LogLevel: Int, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
}

/// Simple logger for HL7 operations
public actor HL7Logger {
    public static let shared = HL7Logger()
    
    private var logLevel: HL7LogLevel = .info
    
    private init() {}
    
    /// Set the logging level
    public func setLogLevel(_ level: HL7LogLevel) {
        self.logLevel = level
    }
    
    /// Log a message
    public func log(_ level: HL7LogLevel, _ message: String) {
        guard level.rawValue >= logLevel.rawValue else { return }
        print("[\(level)] \(message)")
    }
}
