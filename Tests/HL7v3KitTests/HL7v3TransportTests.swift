/// HL7v3KitTests - Transport Layer Tests
///
/// Tests for HL7 v3.x transport components including SOAP, REST, WS-Security,
/// message queuing, and connection management.

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
final class HL7v3TransportTests: XCTestCase {
    
    // MARK: - SOAP Envelope Tests
    
    func testSOAPEnvelopeCreation() {
        let body = "<hl7:message>Test</hl7:message>"
        let envelope = SOAPEnvelope(version: .soap12, body: body)
        
        let xml = envelope.toXML()
        
        XCTAssertTrue(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xml.contains("soap:Envelope"))
        XCTAssertTrue(xml.contains("soap:Body"))
        XCTAssertTrue(xml.contains(body))
    }
    
    func testSOAPEnvelopeWithHeader() {
        let timestamp = SecurityTimestamp(ttl: 300)
        let header = SOAPHeader(security: WSSecurity(timestamp: timestamp))
        let body = "<hl7:message>Test</hl7:message>"
        let envelope = SOAPEnvelope(version: .soap12, header: header, body: body)
        
        let xml = envelope.toXML()
        
        XCTAssertTrue(xml.contains("soap:Header"))
        XCTAssertTrue(xml.contains("wsse:Security"))
        XCTAssertTrue(xml.contains("wsu:Timestamp"))
    }
    
    func testSOAPEnvelopeParsing() throws {
        let soapXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
        <soap:Body>
        <hl7:message>Test Response</hl7:message>
        </soap:Body>
        </soap:Envelope>
        """
        
        let envelope = try SOAPEnvelope.parse(soapXML)
        
        XCTAssertTrue(envelope.body.contains("Test Response"))
        XCTAssertEqual(envelope.version, .soap12)
    }
    
    func testSOAPFaultParsing() {
        let faultXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
        <soap:Body>
        <soap:Fault>
        <faultcode>soap:Server</faultcode>
        <faultstring>Server Error</faultstring>
        </soap:Fault>
        </soap:Body>
        </soap:Envelope>
        """
        
        XCTAssertThrowsError(try SOAPEnvelope.parse(faultXML)) { error in
            if case TransportError.serverError(let code, let message) = error {
                XCTAssertEqual(code, 500)
                XCTAssertTrue(message.contains("Server Error"))
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        }
    }
    
    // MARK: - WS-Security Tests
    
    func testUsernameTokenPlainText() {
        let token = UsernameToken(
            username: "testuser",
            password: "testpass",
            passwordType: .text
        )
        
        let xml = token.toXML()
        
        XCTAssertTrue(xml.contains("<wsse:Username>testuser</wsse:Username>"))
        XCTAssertTrue(xml.contains("<wsse:Password"))
        XCTAssertTrue(xml.contains("PasswordText"))
    }
    
    func testUsernameTokenDigest() {
        let token = UsernameToken.withDigest(username: "testuser", password: "testpass")
        
        let xml = token.toXML()
        
        XCTAssertTrue(xml.contains("<wsse:Username>testuser</wsse:Username>"))
        XCTAssertTrue(xml.contains("PasswordDigest"))
        XCTAssertTrue(xml.contains("<wsse:Nonce"))
        XCTAssertTrue(xml.contains("<wsu:Created>"))
    }
    
    func testSecurityTimestamp() {
        let timestamp = SecurityTimestamp(ttl: 300)
        
        XCTAssertTrue(timestamp.isValid())
        
        let xml = timestamp.toXML()
        
        XCTAssertTrue(xml.contains("<wsu:Timestamp>"))
        XCTAssertTrue(xml.contains("<wsu:Created>"))
        XCTAssertTrue(xml.contains("<wsu:Expires>"))
    }
    
    func testExpiredTimestamp() throws {
        // Create timestamp that expired in the past
        let created = Date(timeIntervalSinceNow: -400)
        let expires = Date(timeIntervalSinceNow: -100)
        let timestamp = SecurityTimestamp(created: created, expires: expires)
        
        XCTAssertFalse(timestamp.isValid())
    }
    
    func testBinarySecurityToken() {
        let token = BinarySecurityToken(value: "dGVzdGNlcnRpZmljYXRl")
        
        let xml = token.toXML()
        
        XCTAssertTrue(xml.contains("<wsse:BinarySecurityToken"))
        XCTAssertTrue(xml.contains("ValueType"))
        XCTAssertTrue(xml.contains("EncodingType"))
        XCTAssertTrue(xml.contains("dGVzdGNlcnRpZmljYXRl"))
    }
    
    func testWSSecuritySerialization() {
        let timestamp = SecurityTimestamp(ttl: 300)
        let usernameToken = UsernameToken(
            username: "testuser",
            password: "testpass",
            passwordType: .text
        )
        let security = WSSecurity(usernameToken: usernameToken, timestamp: timestamp)
        
        let xml = security.toXML()
        
        XCTAssertTrue(xml.contains("<wsse:Security"))
        XCTAssertTrue(xml.contains("wsse:UsernameToken"))
        XCTAssertTrue(xml.contains("wsu:Timestamp"))
    }
    
    // MARK: - Transport Configuration Tests
    
    func testDefaultConfiguration() {
        let config = TransportConfiguration.default
        
        XCTAssertEqual(config.timeout, 30.0)
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.retryDelay, 1.0)
        XCTAssertTrue(config.useTLS)
        XCTAssertEqual(config.connectionPoolSize, 5)
    }
    
    func testCustomConfiguration() {
        let config = TransportConfiguration(
            timeout: 60.0,
            maxRetries: 5,
            retryDelay: 2.0,
            useTLS: false,
            connectionPoolSize: 10
        )
        
        XCTAssertEqual(config.timeout, 60.0)
        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.retryDelay, 2.0)
        XCTAssertFalse(config.useTLS)
        XCTAssertEqual(config.connectionPoolSize, 10)
    }
    
    func testTLSConfiguration() {
        let tlsConfig = TLSConfiguration(
            minimumTLSVersion: .tls12,
            validateCertificate: true
        )
        
        XCTAssertEqual(tlsConfig.minimumTLSVersion, .tls12)
        XCTAssertTrue(tlsConfig.validateCertificate)
    }
    
    // MARK: - Message Queue Tests
    
    func testMessageQueueCreation() async throws {
        let transport = MockTransport()
        let queue = MessageQueue(transport: transport, maxSize: 10)
        
        let stats = await queue.statistics()
        XCTAssertEqual(stats.queuedCount, 0)
        XCTAssertEqual(stats.completedCount, 0)
        XCTAssertEqual(stats.failedCount, 0)
        XCTAssertFalse(stats.isProcessing)
    }
    
    func testMessageEnqueue() async throws {
        let transport = MockTransport()
        let queue = MessageQueue(transport: transport, maxSize: 10)
        
        let message = MessageQueue.QueuedMessage(
            content: "<message>Test</message>",
            endpoint: URL(string: "http://example.com")!,
            priority: .normal
        )
        
        try await queue.enqueue(message)
        
        let size = await queue.size()
        XCTAssertEqual(size, 1)
    }
    
    func testMessageQueueFullError() async throws {
        let transport = MockTransport()
        let queue = MessageQueue(transport: transport, maxSize: 2)
        
        // Fill queue
        try await queue.enqueue(
            content: "<message>1</message>",
            to: URL(string: "http://example.com")!
        )
        try await queue.enqueue(
            content: "<message>2</message>",
            to: URL(string: "http://example.com")!
        )
        
        // Try to add one more - should fail
        do {
            try await queue.enqueue(
                content: "<message>3</message>",
                to: URL(string: "http://example.com")!
            )
            XCTFail("Expected queue full error")
        } catch TransportError.queueFull {
            // Expected
        }
    }
    
    func testMessagePriority() async throws {
        let transport = MockTransport()
        let queue = MessageQueue(transport: transport, maxSize: 10)
        
        // Enqueue messages with different priorities
        try await queue.enqueue(
            content: "<message>Normal</message>",
            to: URL(string: "http://example.com")!,
            priority: .normal
        )
        try await queue.enqueue(
            content: "<message>Urgent</message>",
            to: URL(string: "http://example.com")!,
            priority: .urgent
        )
        try await queue.enqueue(
            content: "<message>Low</message>",
            to: URL(string: "http://example.com")!,
            priority: .low
        )
        
        let size = await queue.size()
        XCTAssertEqual(size, 3)
        
        // Messages should be ordered by priority
        // (Urgent, Normal, Low)
    }
    
    func testBatchQueue() async throws {
        let transport = MockTransport()
        let batchQueue = BatchMessageQueue(transport: transport, batchSize: 3)
        
        let message1 = MessageQueue.QueuedMessage(
            content: "<message>1</message>",
            endpoint: URL(string: "http://example.com")!
        )
        let message2 = MessageQueue.QueuedMessage(
            content: "<message>2</message>",
            endpoint: URL(string: "http://example.com")!
        )
        let message3 = MessageQueue.QueuedMessage(
            content: "<message>3</message>",
            endpoint: URL(string: "http://example.com")!
        )
        
        // Add messages - should create batch when full
        let batch1 = await batchQueue.add(message1)
        XCTAssertNil(batch1) // Not full yet
        
        let batch2 = await batchQueue.add(message2)
        XCTAssertNil(batch2) // Not full yet
        
        let batch3 = await batchQueue.add(message3)
        XCTAssertNotNil(batch3) // Batch is full
        XCTAssertEqual(batch3?.messages.count, 3)
    }
    
    // MARK: - Connection Pool Tests
    
    func testConnectionPoolAcquireRelease() async throws {
        let pool = ConnectionPool(maxSize: 3)
        
        try await pool.acquire()
        try await pool.acquire()
        
        let stats1 = await pool.statistics()
        XCTAssertEqual(stats1.active, 2)
        XCTAssertEqual(stats1.available, 1)
        
        await pool.release()
        
        let stats2 = await pool.statistics()
        XCTAssertEqual(stats2.active, 1)
        XCTAssertEqual(stats2.available, 2)
    }
    
    func testConnectionPoolFullError() async throws {
        let pool = ConnectionPool(maxSize: 2)
        
        try await pool.acquire()
        try await pool.acquire()
        
        // Try to acquire one more - should fail
        do {
            try await pool.acquire()
            XCTFail("Expected queue full error")
        } catch TransportError.queueFull {
            // Expected
        }
    }
    
    // MARK: - XML Escaping Tests
    
    func testXMLEscaping() {
        let text = "Test <tag> & \"quote\" 'apostrophe'"
        let escaped = text.xmlEscaped
        
        XCTAssertEqual(escaped, "Test &lt;tag&gt; &amp; &quot;quote&quot; &apos;apostrophe&apos;")
    }
    
    // MARK: - Transport Error Tests
    
    func testTransportErrorDescriptions() {
        let error1 = TransportError.invalidURL("http://bad url")
        XCTAssertTrue(error1.description.contains("Invalid URL"))
        
        let error2 = TransportError.timeout
        XCTAssertTrue(error2.description.contains("timeout"))
        
        let error3 = TransportError.serverError(500, "Internal Server Error")
        XCTAssertTrue(error3.description.contains("500"))
        XCTAssertTrue(error3.description.contains("Internal Server Error"))
        
        let error4 = TransportError.maxRetriesExceeded
        XCTAssertTrue(error4.description.contains("retries exceeded"))
    }
}

// MARK: - Mock Transport

/// Mock transport for testing
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
actor MockTransport: HL7v3Transport {
    var sentMessages: [(String, URL, [String: String])] = []
    var responseToReturn: String = "<response>Success</response>"
    var shouldFail: Bool = false
    
    func send(
        _ message: String,
        to endpoint: URL,
        headers: [String: String]
    ) async throws -> String {
        sentMessages.append((message, endpoint, headers))
        
        if shouldFail {
            throw TransportError.connectionFailed("Mock failure")
        }
        
        return responseToReturn
    }
}
