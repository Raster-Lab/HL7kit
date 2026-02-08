/// HL7v2Kit - MLLP (Minimal Lower Layer Protocol) implementation
///
/// This module provides MLLP framing, stream parsing, connection management,
/// and connection pooling for HL7 v2.x message transport.
///
/// MLLP wraps HL7 messages in a simple frame:
/// - Start Block: `0x0B` (vertical tab)
/// - Message Data: UTF-8 encoded HL7 message
/// - End Block: `0x1C` (file separator) followed by `0x0D` (carriage return)

import Foundation
import HL7Core

// MARK: - MLLP Constants

/// MLLP protocol byte constants
private enum MLLPBytes {
    /// Start block byte (vertical tab)
    static let startByte: UInt8 = 0x0B
    /// End block byte (file separator)
    static let endByte: UInt8 = 0x1C
    /// Carriage return byte
    static let carriageReturn: UInt8 = 0x0D
}

// MARK: - MLLPFramer

/// MLLP message framer and deframer
///
/// Provides static methods to wrap and unwrap HL7 messages using the
/// Minimal Lower Layer Protocol framing format: `[0x0B][message][0x1C][0x0D]`
public struct MLLPFramer: Sendable {

    /// Frame an HL7 message string with MLLP envelope
    /// - Parameter message: The HL7 message string to frame
    /// - Returns: MLLP-framed data
    public static func frame(_ message: String) -> Data {
        let messageData = Data(message.utf8)
        return frame(messageData)
    }

    /// Frame raw message data with MLLP envelope
    /// - Parameter message: The raw message data to frame
    /// - Returns: MLLP-framed data
    public static func frame(_ message: Data) -> Data {
        var framed = Data(capacity: message.count + 3)
        framed.append(MLLPBytes.startByte)
        framed.append(message)
        framed.append(MLLPBytes.endByte)
        framed.append(MLLPBytes.carriageReturn)
        return framed
    }

    /// Remove MLLP framing and return the message as a string
    /// - Parameter data: MLLP-framed data
    /// - Returns: The contained HL7 message string
    /// - Throws: ``HL7Error/invalidFormat(_:context:)`` if the data is not valid MLLP
    public static func deframe(_ data: Data) throws -> String {
        let rawData = try deframeToData(data)
        guard let message = String(data: rawData, encoding: .utf8) else {
            throw HL7Error.invalidFormat("Failed to decode MLLP message content as UTF-8")
        }
        return message
    }

    /// Remove MLLP framing and return the raw message data
    /// - Parameter data: MLLP-framed data
    /// - Returns: The contained message data without framing bytes
    /// - Throws: ``HL7Error/invalidFormat(_:context:)`` if the data is not valid MLLP
    public static func deframeToData(_ data: Data) throws -> Data {
        guard data.count >= 3 else {
            throw HL7Error.invalidFormat(
                "MLLP frame too short: expected at least 3 bytes, got \(data.count)")
        }
        guard data[data.startIndex] == MLLPBytes.startByte else {
            throw HL7Error.invalidFormat(
                "MLLP frame missing start byte (0x0B)")
        }
        let lastIndex = data.endIndex - 1
        let secondLastIndex = data.endIndex - 2
        guard data[secondLastIndex] == MLLPBytes.endByte,
              data[lastIndex] == MLLPBytes.carriageReturn
        else {
            throw HL7Error.invalidFormat(
                "MLLP frame missing end block (0x1C 0x0D)")
        }
        return data[(data.startIndex + 1)..<secondLastIndex]
    }

    /// Check if the data contains a complete MLLP frame
    /// - Parameter data: Data to inspect
    /// - Returns: `true` if the data starts with `0x0B` and ends with `0x1C 0x0D`
    public static func isCompleteFrame(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return data[data.startIndex] == MLLPBytes.startByte
            && data[data.endIndex - 2] == MLLPBytes.endByte
            && data[data.endIndex - 1] == MLLPBytes.carriageReturn
    }

    /// Check if the data contains the MLLP start byte
    /// - Parameter data: Data to inspect
    /// - Returns: `true` if the data contains `0x0B`
    public static func containsStartByte(_ data: Data) -> Bool {
        data.contains(MLLPBytes.startByte)
    }
}

// MARK: - MLLPStreamParser

/// Streaming MLLP message parser
///
/// Accumulates incoming byte data and extracts complete MLLP-framed messages
/// as they become available. Useful for processing TCP stream data that may
/// arrive in arbitrary chunks.
public struct MLLPStreamParser: Sendable {

    /// Internal buffer for accumulating incoming data
    private var buffer: Data

    /// Number of bytes currently in the buffer
    public var pendingByteCount: Int {
        buffer.count
    }

    /// Create a new stream parser with an empty buffer
    public init() {
        self.buffer = Data()
    }

    /// Append incoming data to the internal buffer
    /// - Parameter data: The data received from the network
    public mutating func append(_ data: Data) {
        buffer.append(data)
    }

    /// Extract the next complete MLLP message from the buffer
    ///
    /// Searches the buffer for a complete MLLP frame (from `0x0B` to `0x1C 0x0D`).
    /// If found, the frame is removed from the buffer and the message is returned.
    /// Any data before the start byte is discarded.
    ///
    /// - Returns: The next complete message string, or `nil` if no complete message is available
    /// - Throws: ``HL7Error/invalidFormat(_:context:)`` if a complete frame contains invalid UTF-8
    public mutating func nextMessage() throws -> String? {
        // Find start byte
        guard let startIndex = buffer.firstIndex(of: MLLPBytes.startByte) else {
            return nil
        }

        // Discard any data before the start byte
        if startIndex > buffer.startIndex {
            buffer.removeSubrange(buffer.startIndex..<startIndex)
        }

        // Search for end block (0x1C 0x0D) after the start byte
        let searchStart = buffer.startIndex + 1
        guard buffer.count >= 3 else { return nil }

        for i in searchStart..<(buffer.endIndex - 1) {
            if buffer[i] == MLLPBytes.endByte && buffer[i + 1] == MLLPBytes.carriageReturn {
                // Extract the complete frame
                let frameEnd = i + 2
                let frameData = buffer[buffer.startIndex..<frameEnd]

                // Remove the frame from the buffer
                buffer.removeSubrange(buffer.startIndex..<frameEnd)

                // Deframe and return the message
                return try MLLPFramer.deframe(Data(frameData))
            }
        }

        return nil
    }

    /// Clear the buffer, discarding any pending data
    public mutating func reset() {
        buffer.removeAll()
    }
}

// MARK: - MLLPConfiguration

/// Configuration for an MLLP connection
///
/// Use ``MLLPConfigurationBuilder`` via ``builder()`` for fluent construction.
public struct MLLPConfiguration: Sendable, Equatable {

    /// Remote host address
    public let host: String

    /// Remote port number
    public let port: UInt16

    /// Whether to use TLS for the connection
    public let useTLS: Bool

    /// Timeout for establishing a connection, in seconds
    public let connectionTimeout: TimeInterval

    /// Timeout for waiting for a response, in seconds
    public let responseTimeout: TimeInterval

    /// Maximum number of retry attempts for failed sends
    public let maxRetryAttempts: Int

    /// Delay between retry attempts, in seconds
    public let retryDelay: TimeInterval

    /// Maximum allowed message size in bytes (default 1 MB)
    public let maxMessageSize: Int

    /// Whether to automatically reconnect on connection loss
    public let autoReconnect: Bool

    /// Interval for sending keep-alive probes, or `nil` to disable
    public let keepAliveInterval: TimeInterval?

    /// Create a configuration with explicit values
    public init(
        host: String,
        port: UInt16,
        useTLS: Bool = false,
        connectionTimeout: TimeInterval = 30.0,
        responseTimeout: TimeInterval = 30.0,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0,
        maxMessageSize: Int = 1_048_576,
        autoReconnect: Bool = true,
        keepAliveInterval: TimeInterval? = nil
    ) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.connectionTimeout = connectionTimeout
        self.responseTimeout = responseTimeout
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.maxMessageSize = maxMessageSize
        self.autoReconnect = autoReconnect
        self.keepAliveInterval = keepAliveInterval
    }

    /// Create a fluent builder for ``MLLPConfiguration``
    /// - Returns: A new ``MLLPConfigurationBuilder``
    public static func builder() -> MLLPConfigurationBuilder {
        MLLPConfigurationBuilder()
    }
}

// MARK: - MLLPConfigurationBuilder

/// Fluent builder for ``MLLPConfiguration``
///
/// ```swift
/// let config = MLLPConfiguration.builder()
///     .host("hl7.example.com")
///     .port(2575)
///     .useTLS(true)
///     .build()
/// ```
public struct MLLPConfigurationBuilder: Sendable {

    private var host: String = "localhost"
    private var port: UInt16 = 2575
    private var useTLS: Bool = false
    private var connectionTimeout: TimeInterval = 30.0
    private var responseTimeout: TimeInterval = 30.0
    private var maxRetryAttempts: Int = 3
    private var retryDelay: TimeInterval = 1.0
    private var maxMessageSize: Int = 1_048_576
    private var autoReconnect: Bool = true
    private var keepAliveInterval: TimeInterval?

    /// Create a new builder with default values
    public init() {}

    /// Set the remote host address
    @discardableResult
    public func host(_ host: String) -> MLLPConfigurationBuilder {
        var copy = self
        copy.host = host
        return copy
    }

    /// Set the remote port number
    @discardableResult
    public func port(_ port: UInt16) -> MLLPConfigurationBuilder {
        var copy = self
        copy.port = port
        return copy
    }

    /// Set whether to use TLS
    @discardableResult
    public func useTLS(_ useTLS: Bool) -> MLLPConfigurationBuilder {
        var copy = self
        copy.useTLS = useTLS
        return copy
    }

    /// Set the connection timeout in seconds
    @discardableResult
    public func connectionTimeout(_ timeout: TimeInterval) -> MLLPConfigurationBuilder {
        var copy = self
        copy.connectionTimeout = timeout
        return copy
    }

    /// Set the response timeout in seconds
    @discardableResult
    public func responseTimeout(_ timeout: TimeInterval) -> MLLPConfigurationBuilder {
        var copy = self
        copy.responseTimeout = timeout
        return copy
    }

    /// Set the maximum number of retry attempts
    @discardableResult
    public func maxRetryAttempts(_ attempts: Int) -> MLLPConfigurationBuilder {
        var copy = self
        copy.maxRetryAttempts = attempts
        return copy
    }

    /// Set the delay between retry attempts in seconds
    @discardableResult
    public func retryDelay(_ delay: TimeInterval) -> MLLPConfigurationBuilder {
        var copy = self
        copy.retryDelay = delay
        return copy
    }

    /// Set the maximum allowed message size in bytes
    @discardableResult
    public func maxMessageSize(_ size: Int) -> MLLPConfigurationBuilder {
        var copy = self
        copy.maxMessageSize = size
        return copy
    }

    /// Set whether to automatically reconnect on connection loss
    @discardableResult
    public func autoReconnect(_ autoReconnect: Bool) -> MLLPConfigurationBuilder {
        var copy = self
        copy.autoReconnect = autoReconnect
        return copy
    }

    /// Set the keep-alive interval in seconds, or `nil` to disable
    @discardableResult
    public func keepAliveInterval(_ interval: TimeInterval?) -> MLLPConfigurationBuilder {
        var copy = self
        copy.keepAliveInterval = interval
        return copy
    }

    /// Build the ``MLLPConfiguration`` from the current builder state
    /// - Returns: A configured ``MLLPConfiguration``
    public func build() -> MLLPConfiguration {
        MLLPConfiguration(
            host: host,
            port: port,
            useTLS: useTLS,
            connectionTimeout: connectionTimeout,
            responseTimeout: responseTimeout,
            maxRetryAttempts: maxRetryAttempts,
            retryDelay: retryDelay,
            maxMessageSize: maxMessageSize,
            autoReconnect: autoReconnect,
            keepAliveInterval: keepAliveInterval
        )
    }
}

// MARK: - MLLPConnectionState

/// Connection lifecycle states for an MLLP connection
public enum MLLPConnectionState: Sendable, Equatable {
    /// Not connected
    case disconnected
    /// Connection is being established
    case connecting
    /// Connection is active and ready for communication
    case connected
    /// Connection is being closed
    case disconnecting
    /// Connection encountered an error
    case error(String)
}

// MARK: - MLLPConnectionMetrics

/// Performance and usage metrics for an MLLP connection
public struct MLLPConnectionMetrics: Sendable {

    /// Total number of messages sent
    public var messagesSent: Int

    /// Total number of messages received
    public var messagesReceived: Int

    /// Total number of bytes sent
    public var bytesSent: Int

    /// Total number of bytes received
    public var bytesReceived: Int

    /// Time when the connection was established
    public var connectionStartTime: Date?

    /// Time of the last send or receive activity
    public var lastActivityTime: Date?

    /// Number of times the connection has been re-established
    public var reconnectionCount: Int

    /// Total number of errors encountered
    public var errors: Int

    /// Create metrics with all counters at zero
    public init() {
        self.messagesSent = 0
        self.messagesReceived = 0
        self.bytesSent = 0
        self.bytesReceived = 0
        self.connectionStartTime = nil
        self.lastActivityTime = nil
        self.reconnectionCount = 0
        self.errors = 0
    }
}

// MARK: - MLLPConnection

/// MLLP connection for sending and receiving HL7 v2.x messages
///
/// Manages the lifecycle of an MLLP connection including framing,
/// state tracking, and metrics collection.
///
/// > Note: Actual TCP networking via `Network.framework` is only available
/// > on Apple platforms. On other platforms, connection methods throw
/// > ``HL7Error/networkError(_:context:)``.
public actor MLLPConnection {

    /// Connection configuration
    private let configuration: MLLPConfiguration

    /// Current connection state
    private(set) var state: MLLPConnectionState

    /// Connection performance metrics
    private var metrics: MLLPConnectionMetrics

    /// Stream parser for incoming data
    private var streamParser: MLLPStreamParser

    /// Create a new MLLP connection with the given configuration
    /// - Parameter configuration: Connection settings
    public init(configuration: MLLPConfiguration) {
        self.configuration = configuration
        self.state = .disconnected
        self.metrics = MLLPConnectionMetrics()
        self.streamParser = MLLPStreamParser()
    }

    /// The current connection state
    public var currentState: MLLPConnectionState {
        state
    }

    /// The current connection metrics
    public var currentMetrics: MLLPConnectionMetrics {
        metrics
    }

    /// Establish the MLLP connection
    ///
    /// On Apple platforms this will use `Network.framework` (NWConnection).
    /// On other platforms this throws a network error.
    ///
    /// - Throws: ``HL7Error/networkError(_:context:)`` if connection cannot be established
    public func connect() async throws {
        state = .connecting
        #if canImport(Network)
        // Network.framework available — stub for future NWConnection implementation
        state = .connected
        metrics.connectionStartTime = Date()
        metrics.lastActivityTime = Date()
        #else
        state = .error("Network.framework not available on this platform")
        throw HL7Error.networkError("Network.framework not available on this platform")
        #endif
    }

    /// Close the MLLP connection
    public func disconnect() async {
        state = .disconnecting
        streamParser.reset()
        state = .disconnected
    }

    /// Send an HL7 v2.x message and wait for the response
    ///
    /// The message is serialized, framed with MLLP, transmitted, and the
    /// response is deframed and parsed back into an ``HL7v2Message``.
    ///
    /// - Parameter message: The HL7 v2.x message to send
    /// - Returns: The response ``HL7v2Message``
    /// - Throws: ``HL7Error/networkError(_:context:)`` on transport failure,
    ///           ``HL7Error/timeout(_:context:)`` if no response within the configured timeout
    public func send(_ message: HL7v2Message) async throws -> HL7v2Message {
        guard state == .connected else {
            throw HL7Error.networkError("Not connected")
        }

        let serialized = try message.serialize()
        let framedData = MLLPFramer.frame(serialized)

        guard framedData.count <= configuration.maxMessageSize else {
            throw HL7Error.networkError(
                "Message size \(framedData.count) exceeds maximum \(configuration.maxMessageSize)")
        }

        // Update send metrics
        metrics.messagesSent += 1
        metrics.bytesSent += framedData.count
        metrics.lastActivityTime = Date()

        #if canImport(Network)
        // Stub: In a real implementation, send via NWConnection and await response
        throw HL7Error.networkError(
            "Network I/O not yet implemented — NWConnection integration pending")
        #else
        throw HL7Error.networkError("Network.framework not available on this platform")
        #endif
    }

    /// Send raw MLLP-framed data and wait for the raw response
    ///
    /// - Parameter data: Pre-framed MLLP data to send
    /// - Returns: The raw response data (still MLLP-framed)
    /// - Throws: ``HL7Error/networkError(_:context:)`` on transport failure
    public func sendRaw(_ data: Data) async throws -> Data {
        guard state == .connected else {
            throw HL7Error.networkError("Not connected")
        }

        guard data.count <= configuration.maxMessageSize else {
            throw HL7Error.networkError(
                "Data size \(data.count) exceeds maximum \(configuration.maxMessageSize)")
        }

        metrics.bytesSent += data.count
        metrics.lastActivityTime = Date()

        #if canImport(Network)
        throw HL7Error.networkError(
            "Network I/O not yet implemented — NWConnection integration pending")
        #else
        throw HL7Error.networkError("Network.framework not available on this platform")
        #endif
    }
}

// MARK: - MLLPListenerConfiguration

/// Configuration for an ``MLLPListener``
public struct MLLPListenerConfiguration: Sendable {

    /// Port to listen on
    public let port: UInt16

    /// Whether to use TLS for incoming connections
    public let useTLS: Bool

    /// Maximum number of concurrent connections
    public let maxConnections: Int

    /// Handler invoked for each received HL7 message; returns the response message
    public let messageHandler: @Sendable (String) async throws -> String

    /// Create a listener configuration
    /// - Parameters:
    ///   - port: Port to listen on
    ///   - useTLS: Whether to use TLS (default: `false`)
    ///   - maxConnections: Maximum concurrent connections (default: `100`)
    ///   - messageHandler: Callback that processes received messages and returns a response
    public init(
        port: UInt16,
        useTLS: Bool = false,
        maxConnections: Int = 100,
        messageHandler: @escaping @Sendable (String) async throws -> String
    ) {
        self.port = port
        self.useTLS = useTLS
        self.maxConnections = maxConnections
        self.messageHandler = messageHandler
    }
}

// MARK: - MLLPListenerState

/// Lifecycle states for an ``MLLPListener``
public enum MLLPListenerState: Sendable, Equatable {
    /// Listener is not running
    case stopped
    /// Listener is starting up
    case starting
    /// Listener is accepting connections
    case listening
    /// Listener is shutting down
    case stopping
    /// Listener encountered an error
    case error(String)
}

// MARK: - MLLPListener

/// Server-side MLLP listener for accepting incoming HL7 connections
///
/// Listens on a specified port, accepts connections, deframes incoming
/// MLLP messages, invokes a handler, and sends back framed responses.
///
/// > Note: Actual TCP listening via `Network.framework` is only available
/// > on Apple platforms.
public actor MLLPListener {

    /// Listener configuration
    private let configuration: MLLPListenerConfiguration

    /// Current listener state
    private(set) var state: MLLPListenerState

    /// Create a new MLLP listener with the given configuration
    /// - Parameter configuration: Listener settings
    public init(configuration: MLLPListenerConfiguration) {
        self.configuration = configuration
        self.state = .stopped
    }

    /// The current listener state
    public var currentState: MLLPListenerState {
        state
    }

    /// Start listening for incoming connections
    ///
    /// - Throws: ``HL7Error/networkError(_:context:)`` if the listener cannot start
    public func start() async throws {
        state = .starting
        #if canImport(Network)
        // Stub: In a real implementation, create NWListener and begin accepting connections
        state = .listening
        #else
        state = .error("Network.framework not available on this platform")
        throw HL7Error.networkError("Network.framework not available on this platform")
        #endif
    }

    /// Stop listening and close all active connections
    public func stop() async {
        state = .stopping
        state = .stopped
    }
}

// MARK: - MLLPConnectionPool

/// Pool of reusable ``MLLPConnection`` instances
///
/// Manages a set of MLLP connections to reduce the overhead of
/// establishing new connections for each message exchange.
public actor MLLPConnectionPool {

    /// Connections available for use
    private var available: [MLLPConnection]

    /// Connections currently in use
    private var active: [MLLPConnection]

    /// Maximum number of connections in the pool
    private let maxConnections: Int

    /// Shared configuration for creating new connections
    private let configuration: MLLPConfiguration

    /// Create a new connection pool
    /// - Parameters:
    ///   - configuration: Configuration for connections created by this pool
    ///   - maxConnections: Maximum number of connections (default: `5`)
    public init(configuration: MLLPConfiguration, maxConnections: Int = 5) {
        self.configuration = configuration
        self.maxConnections = maxConnections
        self.available = []
        self.active = []
    }

    /// Number of connections available for use
    public var availableCount: Int {
        available.count
    }

    /// Number of connections currently in use
    public var activeCount: Int {
        active.count
    }

    /// Acquire a connection from the pool
    ///
    /// Returns an existing available connection, or creates a new one
    /// if the pool has capacity.
    ///
    /// - Returns: An ``MLLPConnection`` ready for use
    /// - Throws: ``HL7Error/networkError(_:context:)`` if the pool is exhausted
    public func acquire() async throws -> MLLPConnection {
        if !available.isEmpty {
            let connection = available.removeLast()
            active.append(connection)
            return connection
        }

        guard (available.count + active.count) < maxConnections else {
            throw HL7Error.networkError(
                "Connection pool exhausted (max \(maxConnections) connections)")
        }

        let connection = MLLPConnection(configuration: configuration)
        active.append(connection)
        return connection
    }

    /// Release a connection back to the pool
    ///
    /// The connection becomes available for reuse by other callers.
    ///
    /// - Parameter connection: The connection to release
    public func release(_ connection: MLLPConnection) async {
        if let index = active.firstIndex(where: { $0 === connection }) {
            active.remove(at: index)
            available.append(connection)
        }
    }

    /// Close all connections in the pool
    public func closeAll() async {
        for connection in active {
            await connection.disconnect()
        }
        for connection in available {
            await connection.disconnect()
        }
        active.removeAll()
        available.removeAll()
    }
}
