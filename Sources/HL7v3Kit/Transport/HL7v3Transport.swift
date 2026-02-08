/// HL7v3Kit - Transport Layer
///
/// This module provides networking and transport capabilities for HL7 v3.x messages,
/// including SOAP-based transport, REST-like endpoints, WS-Security, message queuing,
/// connection management, and TLS/SSL support.
///
/// HL7 v3 messages are typically transported via:
/// - SOAP over HTTP/HTTPS (traditional)
/// - RESTful HTTP endpoints (modern)
/// - Message queuing systems
///
/// This implementation leverages Foundation's URLSession and Swift 6.2 concurrency.

import Foundation
import HL7Core

// MARK: - Transport Protocol

/// Protocol for HL7 v3 message transport
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public protocol HL7v3Transport: Sendable {
    /// Send an HL7 v3 message
    /// - Parameters:
    ///   - message: The XML message to send
    ///   - endpoint: The destination endpoint URL
    ///   - headers: Additional HTTP headers
    /// - Returns: The response message
    /// - Throws: Transport errors
    func send(
        _ message: String,
        to endpoint: URL,
        headers: [String: String]
    ) async throws -> String
}

// MARK: - Transport Configuration

/// Configuration for HL7 v3 transport
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct TransportConfiguration: Sendable {
    /// Request timeout in seconds
    public let timeout: TimeInterval
    
    /// Maximum number of retries
    public let maxRetries: Int
    
    /// Retry delay in seconds
    public let retryDelay: TimeInterval
    
    /// Whether to use TLS/SSL
    public let useTLS: Bool
    
    /// Custom TLS configuration
    public let tlsConfiguration: TLSConfiguration?
    
    /// Connection pool size
    public let connectionPoolSize: Int
    
    /// Initialize transport configuration
    public init(
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        useTLS: Bool = true,
        tlsConfiguration: TLSConfiguration? = nil,
        connectionPoolSize: Int = 5
    ) {
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.useTLS = useTLS
        self.tlsConfiguration = tlsConfiguration
        self.connectionPoolSize = connectionPoolSize
    }
    
    /// Default configuration
    public static let `default` = TransportConfiguration()
}

// MARK: - TLS Configuration

#if canImport(Security)
import Security

/// TLS/SSL configuration
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct TLSConfiguration: Sendable {
    /// Minimum TLS version
    public let minimumTLSVersion: TLSVersion
    
    /// Whether to validate server certificate
    public let validateCertificate: Bool
    
    /// Custom certificate validation handler
    public let certificateValidation: (@Sendable (SecTrust) -> Bool)?
    
    /// Client certificate (for mutual TLS)
    public let clientCertificate: SecIdentity?
    
    /// Initialize TLS configuration
    public init(
        minimumTLSVersion: TLSVersion = .tls12,
        validateCertificate: Bool = true,
        certificateValidation: (@Sendable (SecTrust) -> Bool)? = nil,
        clientCertificate: SecIdentity? = nil
    ) {
        self.minimumTLSVersion = minimumTLSVersion
        self.validateCertificate = validateCertificate
        self.certificateValidation = certificateValidation
        self.clientCertificate = clientCertificate
    }
}
#else
/// TLS/SSL configuration (simplified for non-Apple platforms)
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct TLSConfiguration: Sendable {
    /// Minimum TLS version
    public let minimumTLSVersion: TLSVersion
    
    /// Whether to validate server certificate
    public let validateCertificate: Bool
    
    /// Initialize TLS configuration
    public init(
        minimumTLSVersion: TLSVersion = .tls12,
        validateCertificate: Bool = true
    ) {
        self.minimumTLSVersion = minimumTLSVersion
        self.validateCertificate = validateCertificate
    }
}
#endif

/// TLS version
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public enum TLSVersion: Sendable {
    case tls10
    case tls11
    case tls12
    case tls13
}

// MARK: - Transport Errors

/// Errors that can occur during transport
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public enum TransportError: Error, Sendable {
    case invalidURL(String)
    case connectionFailed(String)
    case timeout
    case invalidResponse(String)
    case serverError(Int, String)
    case tlsError(String)
    case maxRetriesExceeded
    case queueFull
    case invalidMessage(String)
}

extension TransportError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .timeout:
            return "Request timeout"
        case .invalidResponse(let reason):
            return "Invalid response: \(reason)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        case .tlsError(let reason):
            return "TLS error: \(reason)"
        case .maxRetriesExceeded:
            return "Maximum retries exceeded"
        case .queueFull:
            return "Message queue is full"
        case .invalidMessage(let reason):
            return "Invalid message: \(reason)"
        }
    }
}
