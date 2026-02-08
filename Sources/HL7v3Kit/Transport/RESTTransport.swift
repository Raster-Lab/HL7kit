/// HL7v3Kit - REST Transport
///
/// Implements RESTful HTTP transport for HL7 v3.x messages.
/// Provides modern HTTP-based message exchange using URLSession.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HL7Core

// MARK: - REST Transport

/// RESTful HTTP transport for HL7 v3 messages
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public actor RESTTransport: HL7v3Transport {
    /// Transport configuration
    private let configuration: TransportConfiguration
    
    /// URL session for HTTP transport
    private let session: URLSession
    
    /// Connection pool
    private let connectionPool: ConnectionPool
    
    /// Initialize REST transport
    /// - Parameter configuration: Transport configuration
    public init(configuration: TransportConfiguration = .default) {
        self.configuration = configuration
        
        // Configure URLSession
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.httpMaximumConnectionsPerHost = configuration.connectionPoolSize
        
        // Configure TLS if needed
        #if canImport(Network)
        if let tlsConfig = configuration.tlsConfiguration {
            sessionConfig.tlsMinimumSupportedProtocolVersion = tlsConfig.minimumTLSVersion.toSecProtocol()
        }
        #endif
        
        self.session = URLSession(configuration: sessionConfig)
        self.connectionPool = ConnectionPool(maxSize: configuration.connectionPoolSize)
    }
    
    /// Send HL7 v3 message via REST
    public func send(
        _ message: String,
        to endpoint: URL,
        headers: [String: String] = [:]
    ) async throws -> String {
        // Send with retry logic
        var lastError: Error?
        for attempt in 0...configuration.maxRetries {
            do {
                return try await sendRequest(message, to: endpoint, headers: headers)
            } catch {
                lastError = error
                if attempt < configuration.maxRetries {
                    // Wait before retry
                    try await Task.sleep(for: .seconds(configuration.retryDelay))
                }
            }
        }
        
        throw lastError ?? TransportError.maxRetriesExceeded
    }
    
    /// Send HTTP request
    private func sendRequest(
        _ message: String,
        to endpoint: URL,
        headers: [String: String]
    ) async throws -> String {
        // Create request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        request.httpBody = message.data(using: .utf8)
        
        // Send request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse("Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw TransportError.serverError(
                httpResponse.statusCode,
                "HTTP \(httpResponse.statusCode): \(errorBody)"
            )
        }
        
        // Parse response
        guard let responseXML = String(data: data, encoding: .utf8) else {
            throw TransportError.invalidResponse("Failed to decode response as UTF-8")
        }
        
        return responseXML
    }
    
    /// Perform GET request
    public func get(
        from endpoint: URL,
        headers: [String: String] = [:]
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Send request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse("Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TransportError.serverError(
                httpResponse.statusCode,
                "HTTP \(httpResponse.statusCode)"
            )
        }
        
        // Parse response
        guard let responseXML = String(data: data, encoding: .utf8) else {
            throw TransportError.invalidResponse("Failed to decode response as UTF-8")
        }
        
        return responseXML
    }
    
    /// Perform PUT request
    public func put(
        _ message: String,
        to endpoint: URL,
        headers: [String: String] = [:]
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        request.httpBody = message.data(using: .utf8)
        
        // Send request
        let (data, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse("Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TransportError.serverError(
                httpResponse.statusCode,
                "HTTP \(httpResponse.statusCode)"
            )
        }
        
        // Parse response
        guard let responseXML = String(data: data, encoding: .utf8) else {
            throw TransportError.invalidResponse("Failed to decode response as UTF-8")
        }
        
        return responseXML
    }
    
    /// Perform DELETE request
    public func delete(
        at endpoint: URL,
        headers: [String: String] = [:]
    ) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Send request
        let (_, response) = try await session.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransportError.invalidResponse("Not an HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TransportError.serverError(
                httpResponse.statusCode,
                "HTTP \(httpResponse.statusCode)"
            )
        }
    }
}

// MARK: - Connection Pool

/// Connection pool for managing reusable connections
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
actor ConnectionPool {
    /// Maximum pool size
    private let maxSize: Int
    
    /// Active connections count
    private var activeConnections: Int = 0
    
    /// Available connection slots
    private var availableSlots: Int
    
    /// Initialize connection pool
    init(maxSize: Int) {
        self.maxSize = maxSize
        self.availableSlots = maxSize
    }
    
    /// Acquire a connection slot
    /// - Throws: TransportError.queueFull if no slots available
    func acquire() throws {
        guard availableSlots > 0 else {
            throw TransportError.queueFull
        }
        availableSlots -= 1
        activeConnections += 1
    }
    
    /// Release a connection slot
    func release() {
        guard activeConnections > 0 else { return }
        activeConnections -= 1
        availableSlots += 1
    }
    
    /// Get pool statistics
    func statistics() -> (active: Int, available: Int, total: Int) {
        return (activeConnections, availableSlots, maxSize)
    }
}
