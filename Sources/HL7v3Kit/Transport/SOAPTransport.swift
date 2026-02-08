/// HL7v3Kit - SOAP Transport
///
/// Implements SOAP 1.1/1.2 message transport for HL7 v3.x messages.
/// Provides SOAP envelope creation, serialization, and fault handling.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HL7Core

// MARK: - SOAP Version

/// SOAP protocol version
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public enum SOAPVersion: Sendable {
    case soap11
    case soap12
    
    /// Namespace URI for this SOAP version
    public var namespace: String {
        switch self {
        case .soap11:
            return "http://schemas.xmlsoap.org/soap/envelope/"
        case .soap12:
            return "http://www.w3.org/2003/05/soap-envelope"
        }
    }
    
    /// Content type for HTTP headers
    public var contentType: String {
        switch self {
        case .soap11:
            return "text/xml; charset=utf-8"
        case .soap12:
            return "application/soap+xml; charset=utf-8"
        }
    }
}

// MARK: - SOAP Envelope

/// SOAP envelope structure
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct SOAPEnvelope: Sendable {
    /// SOAP version
    public let version: SOAPVersion
    
    /// SOAP header (optional)
    public let header: SOAPHeader?
    
    /// SOAP body content (HL7 v3 message XML)
    public let body: String
    
    /// Initialize SOAP envelope
    public init(version: SOAPVersion = .soap12, header: SOAPHeader? = nil, body: String) {
        self.version = version
        self.header = header
        self.body = body
    }
    
    /// Serialize to XML string
    public func toXML() -> String {
        var xml = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
        xml += #"<soap:Envelope xmlns:soap="\#(version.namespace)">"# + "\n"
        
        // Add header if present
        if let header = header {
            xml += "<soap:Header>\n"
            xml += header.toXML()
            xml += "</soap:Header>\n"
        }
        
        // Add body
        xml += "<soap:Body>\n"
        xml += body
        xml += "\n</soap:Body>\n"
        xml += "</soap:Envelope>"
        
        return xml
    }
    
    /// Parse SOAP envelope from XML
    /// - Parameter xml: SOAP envelope XML
    /// - Returns: Parsed envelope
    /// - Throws: TransportError if parsing fails
    public static func parse(_ xml: String) throws -> SOAPEnvelope {
        // Simple XML parsing for SOAP envelope
        // Extract body content between <soap:Body> and </soap:Body>
        guard let bodyStart = xml.range(of: "<soap:Body>")?.upperBound ??
                              xml.range(of: "<SOAP-ENV:Body>")?.upperBound,
              let bodyEnd = xml.range(of: "</soap:Body>")?.lowerBound ??
                            xml.range(of: "</SOAP-ENV:Body>")?.lowerBound
        else {
            throw TransportError.invalidResponse("Missing SOAP Body in response")
        }
        
        let body = String(xml[bodyStart..<bodyEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for SOAP fault
        if body.contains("<soap:Fault>") || body.contains("<SOAP-ENV:Fault>") {
            let fault = try parseFault(body)
            throw TransportError.serverError(500, "SOAP Fault: \(fault.faultString)")
        }
        
        // Detect version
        let version: SOAPVersion = xml.contains("http://www.w3.org/2003/05/soap-envelope") ? .soap12 : .soap11
        
        return SOAPEnvelope(version: version, header: nil, body: body)
    }
    
    /// Parse SOAP fault from body
    private static func parseFault(_ body: String) throws -> SOAPFault {
        // Extract fault code
        var faultCode = "Unknown"
        if let codeStart = body.range(of: "<faultcode>")?.upperBound,
           let codeEnd = body.range(of: "</faultcode>", range: codeStart..<body.endIndex)?.lowerBound {
            faultCode = String(body[codeStart..<codeEnd])
        }
        
        // Extract fault string
        var faultString = "Unknown error"
        if let stringStart = body.range(of: "<faultstring>")?.upperBound,
           let stringEnd = body.range(of: "</faultstring>", range: stringStart..<body.endIndex)?.lowerBound {
            faultString = String(body[stringStart..<stringEnd])
        }
        
        return SOAPFault(faultCode: faultCode, faultString: faultString)
    }
}

// MARK: - SOAP Header

/// SOAP header for WS-Security and other extensions
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct SOAPHeader: Sendable {
    /// Security token
    public let security: WSSecurity?
    
    /// Additional header elements
    public let customElements: [String]
    
    /// Initialize SOAP header
    public init(security: WSSecurity? = nil, customElements: [String] = []) {
        self.security = security
        self.customElements = customElements
    }
    
    /// Serialize to XML
    func toXML() -> String {
        var xml = ""
        
        if let security = security {
            xml += security.toXML()
        }
        
        for element in customElements {
            xml += element + "\n"
        }
        
        return xml
    }
}

// MARK: - SOAP Fault

/// SOAP fault structure
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public struct SOAPFault: Sendable {
    /// Fault code
    public let faultCode: String
    
    /// Fault string description
    public let faultString: String
    
    /// Fault actor (optional)
    public let faultActor: String?
    
    /// Fault detail (optional)
    public let detail: String?
    
    /// Initialize SOAP fault
    public init(
        faultCode: String,
        faultString: String,
        faultActor: String? = nil,
        detail: String? = nil
    ) {
        self.faultCode = faultCode
        self.faultString = faultString
        self.faultActor = faultActor
        self.detail = detail
    }
}

// MARK: - SOAP Transport Implementation

/// SOAP-based transport for HL7 v3 messages
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
public actor SOAPTransport: HL7v3Transport {
    /// Transport configuration
    private let configuration: TransportConfiguration
    
    /// SOAP version to use
    private let soapVersion: SOAPVersion
    
    /// WS-Security configuration
    private let security: WSSecurity?
    
    /// URL session for HTTP transport
    private let session: URLSession
    
    /// Connection pool
    private let connectionPool: ConnectionPool
    
    /// Initialize SOAP transport
    /// - Parameters:
    ///   - configuration: Transport configuration
    ///   - soapVersion: SOAP version (default: SOAP 1.2)
    ///   - security: WS-Security configuration
    public init(
        configuration: TransportConfiguration = .default,
        soapVersion: SOAPVersion = .soap12,
        security: WSSecurity? = nil
    ) {
        self.configuration = configuration
        self.soapVersion = soapVersion
        self.security = security
        
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
    
    /// Send HL7 v3 message via SOAP
    public func send(
        _ message: String,
        to endpoint: URL,
        headers: [String: String] = [:]
    ) async throws -> String {
        // Create SOAP envelope
        let header = security != nil ? SOAPHeader(security: security) : nil
        let envelope = SOAPEnvelope(version: soapVersion, header: header, body: message)
        let soapXML = envelope.toXML()
        
        // Send with retry logic
        var lastError: Error?
        for attempt in 0...configuration.maxRetries {
            do {
                return try await sendRequest(soapXML, to: endpoint, headers: headers)
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
        _ soapXML: String,
        to endpoint: URL,
        headers: [String: String]
    ) async throws -> String {
        // Create request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(soapVersion.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("", forHTTPHeaderField: "SOAPAction") // Empty SOAPAction header
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Set body
        request.httpBody = soapXML.data(using: .utf8)
        
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
        
        // Extract body from SOAP envelope
        let responseEnvelope = try SOAPEnvelope.parse(responseXML)
        return responseEnvelope.body
    }
}

// MARK: - TLS Version Extension

#if canImport(Network)
import Network

extension TLSVersion {
    func toSecProtocol() -> tls_protocol_version_t {
        switch self {
        case .tls10: return .TLSv10
        case .tls11: return .TLSv11
        case .tls12: return .TLSv12
        case .tls13: return .TLSv13
        }
    }
}
#else
extension TLSVersion {
    // Placeholder for non-Apple platforms
    func toSecProtocol() -> UInt16 {
        switch self {
        case .tls10: return 0x0301
        case .tls11: return 0x0302
        case .tls12: return 0x0303
        case .tls13: return 0x0304
        }
    }
}
#endif
