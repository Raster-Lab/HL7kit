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
    case invalidFormat(String)
    
    /// Missing required field
    case missingRequiredField(String)
    
    /// Invalid data type
    case invalidDataType(String)
    
    /// Parsing error
    case parsingError(String)
    
    /// Validation error
    case validationError(String)
    
    /// Network error
    case networkError(String)
    
    /// Unknown error
    case unknown(String)
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
