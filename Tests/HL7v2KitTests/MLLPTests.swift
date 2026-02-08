/// Tests for MLLP (Minimal Lower Layer Protocol) implementation

import XCTest
import Foundation
@testable import HL7v2Kit
@testable import HL7Core

final class MLLPTests: XCTestCase {

    // MARK: - MLLPFramer Tests

    func testFrameString() {
        let message = "MSH|^~\\&|SENDING|FACILITY"
        let framed = MLLPFramer.frame(message)

        XCTAssertEqual(framed.first, 0x0B, "First byte should be start block")
        XCTAssertEqual(framed[framed.count - 2], 0x1C, "Second-to-last byte should be end block")
        XCTAssertEqual(framed.last, 0x0D, "Last byte should be carriage return")
        XCTAssertEqual(framed.count, message.utf8.count + 3, "Frame adds 3 bytes of overhead")
    }

    func testFrameData() {
        let messageData = Data("MSH|^~\\&|TEST".utf8)
        let framed = MLLPFramer.frame(messageData)

        XCTAssertEqual(framed.first, 0x0B)
        XCTAssertEqual(framed[framed.count - 2], 0x1C)
        XCTAssertEqual(framed.last, 0x0D)
        XCTAssertEqual(framed.count, messageData.count + 3)
    }

    func testFrameEmptyString() {
        let framed = MLLPFramer.frame("")
        XCTAssertEqual(framed.count, 3)
        XCTAssertEqual(framed[0], 0x0B)
        XCTAssertEqual(framed[1], 0x1C)
        XCTAssertEqual(framed[2], 0x0D)
    }

    func testFrameEmptyData() {
        let framed = MLLPFramer.frame(Data())
        XCTAssertEqual(framed.count, 3)
    }

    func testDeframeValidMessage() throws {
        let original = "MSH|^~\\&|SENDING|FACILITY|RECEIVING|FACILITY"
        let framed = MLLPFramer.frame(original)
        let deframed = try MLLPFramer.deframe(framed)
        XCTAssertEqual(deframed, original)
    }

    func testDeframeToDataValid() throws {
        let original = Data("MSH|^~\\&|TEST".utf8)
        let framed = MLLPFramer.frame(original)
        let deframed = try MLLPFramer.deframeToData(framed)
        XCTAssertEqual(deframed, original)
    }

    func testDeframeEmptyMessage() throws {
        let framed = MLLPFramer.frame("")
        let deframed = try MLLPFramer.deframe(framed)
        XCTAssertEqual(deframed, "")
    }

    func testDeframeTooShort() {
        let data = Data([0x0B, 0x1C])
        XCTAssertThrowsError(try MLLPFramer.deframe(data)) { error in
            guard case HL7Error.invalidFormat(let msg, _) = error else {
                XCTFail("Expected invalidFormat error, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("too short"))
        }
    }

    func testDeframeMissingStartByte() {
        let data = Data([0x41, 0x42, 0x1C, 0x0D])
        XCTAssertThrowsError(try MLLPFramer.deframe(data)) { error in
            guard case HL7Error.invalidFormat(let msg, _) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(msg.contains("start byte"))
        }
    }

    func testDeframeMissingEndBlock() {
        let data = Data([0x0B, 0x41, 0x42, 0x43])
        XCTAssertThrowsError(try MLLPFramer.deframe(data)) { error in
            guard case HL7Error.invalidFormat(let msg, _) = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
            XCTAssertTrue(msg.contains("end block"))
        }
    }

    func testDeframeEmptyData() {
        XCTAssertThrowsError(try MLLPFramer.deframe(Data())) { error in
            guard case HL7Error.invalidFormat = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
        }
    }

    func testDeframeToDataEmptyData() {
        XCTAssertThrowsError(try MLLPFramer.deframeToData(Data())) { error in
            guard case HL7Error.invalidFormat = error else {
                XCTFail("Expected invalidFormat error")
                return
            }
        }
    }

    func testIsCompleteFrameValid() {
        let framed = MLLPFramer.frame("MSH|^~\\&|TEST")
        XCTAssertTrue(MLLPFramer.isCompleteFrame(framed))
    }

    func testIsCompleteFrameIncomplete() {
        let data = Data([0x0B, 0x41, 0x42])
        XCTAssertFalse(MLLPFramer.isCompleteFrame(data))
    }

    func testIsCompleteFrameEmpty() {
        XCTAssertFalse(MLLPFramer.isCompleteFrame(Data()))
    }

    func testIsCompleteFrameTooShort() {
        let data = Data([0x0B, 0x1C])
        XCTAssertFalse(MLLPFramer.isCompleteFrame(data))
    }

    func testIsCompleteFrameMissingStart() {
        let data = Data([0x41, 0x42, 0x1C, 0x0D])
        XCTAssertFalse(MLLPFramer.isCompleteFrame(data))
    }

    func testContainsStartBytePresent() {
        let data = Data([0x41, 0x0B, 0x42])
        XCTAssertTrue(MLLPFramer.containsStartByte(data))
    }

    func testContainsStartByteAbsent() {
        let data = Data([0x41, 0x42, 0x43])
        XCTAssertFalse(MLLPFramer.containsStartByte(data))
    }

    func testContainsStartByteEmptyData() {
        XCTAssertFalse(MLLPFramer.containsStartByte(Data()))
    }

    func testFrameDeframeRoundtrip() throws {
        let messages = [
            "MSH|^~\\&|SEND|FAC|RECV|FAC||ADT^A01|12345|P|2.5",
            "",
            "A",
            String(repeating: "X", count: 10000),
        ]
        for original in messages {
            let framed = MLLPFramer.frame(original)
            let deframed = try MLLPFramer.deframe(framed)
            XCTAssertEqual(deframed, original, "Round-trip failed for message of length \(original.count)")
        }
    }

    func testFrameDeframeDataRoundtrip() throws {
        let original = Data([0x00, 0xFF, 0x80, 0x7F, 0x01])
        let framed = MLLPFramer.frame(original)
        let deframed = try MLLPFramer.deframeToData(framed)
        XCTAssertEqual(deframed, original)
    }

    // MARK: - MLLPStreamParser Tests

    func testStreamParserSingleCompleteMessage() throws {
        var parser = MLLPStreamParser()
        let framed = MLLPFramer.frame("MSH|^~\\&|TEST")
        parser.append(framed)

        let message = try parser.nextMessage()
        XCTAssertEqual(message, "MSH|^~\\&|TEST")
        XCTAssertEqual(parser.pendingByteCount, 0)
    }

    func testStreamParserMultipleMessages() throws {
        var parser = MLLPStreamParser()
        let msg1 = MLLPFramer.frame("MESSAGE_ONE")
        let msg2 = MLLPFramer.frame("MESSAGE_TWO")

        var combined = Data()
        combined.append(msg1)
        combined.append(msg2)
        parser.append(combined)

        XCTAssertEqual(try parser.nextMessage(), "MESSAGE_ONE")
        XCTAssertEqual(try parser.nextMessage(), "MESSAGE_TWO")
        XCTAssertNil(try parser.nextMessage())
    }

    func testStreamParserIncrementalData() throws {
        var parser = MLLPStreamParser()
        let message = "MSH|^~\\&|INCREMENTAL"
        let framed = MLLPFramer.frame(message)

        // Send data in two chunks
        let midpoint = framed.count / 2
        parser.append(framed[0..<midpoint])
        XCTAssertNil(try parser.nextMessage(), "Should not have a complete message yet")
        XCTAssertGreaterThan(parser.pendingByteCount, 0)

        parser.append(framed[midpoint...])
        XCTAssertEqual(try parser.nextMessage(), message)
        XCTAssertEqual(parser.pendingByteCount, 0)
    }

    func testStreamParserByteByByte() throws {
        var parser = MLLPStreamParser()
        let message = "MSH|TEST"
        let framed = MLLPFramer.frame(message)

        for i in 0..<(framed.count - 1) {
            parser.append(Data([framed[i]]))
            XCTAssertNil(try parser.nextMessage())
        }

        parser.append(Data([framed[framed.count - 1]]))
        XCTAssertEqual(try parser.nextMessage(), message)
    }

    func testStreamParserDiscardsJunkBeforeStartByte() throws {
        var parser = MLLPStreamParser()
        var data = Data([0x41, 0x42, 0x43]) // "ABC" junk
        data.append(MLLPFramer.frame("VALID_MESSAGE"))
        parser.append(data)

        XCTAssertEqual(try parser.nextMessage(), "VALID_MESSAGE")
    }

    func testStreamParserNoStartByte() throws {
        var parser = MLLPStreamParser()
        parser.append(Data([0x41, 0x42, 0x43]))
        XCTAssertNil(try parser.nextMessage())
    }

    func testStreamParserReset() throws {
        var parser = MLLPStreamParser()
        parser.append(MLLPFramer.frame("TEST"))
        XCTAssertGreaterThan(parser.pendingByteCount, 0)

        parser.reset()
        XCTAssertEqual(parser.pendingByteCount, 0)
        XCTAssertNil(try parser.nextMessage())
    }

    func testStreamParserPendingByteCount() {
        var parser = MLLPStreamParser()
        XCTAssertEqual(parser.pendingByteCount, 0)

        parser.append(Data([0x0B, 0x41]))
        XCTAssertEqual(parser.pendingByteCount, 2)
    }

    func testStreamParserMultipleMessagesChunked() throws {
        var parser = MLLPStreamParser()
        let msg1 = MLLPFramer.frame("FIRST")
        let msg2 = MLLPFramer.frame("SECOND")

        // Send first message complete, second partial
        var chunk1 = Data()
        chunk1.append(msg1)
        chunk1.append(msg2[0..<3])
        parser.append(chunk1)

        XCTAssertEqual(try parser.nextMessage(), "FIRST")
        XCTAssertNil(try parser.nextMessage())

        // Complete the second message
        parser.append(msg2[3...])
        XCTAssertEqual(try parser.nextMessage(), "SECOND")
    }

    func testStreamParserEmptyMessage() throws {
        var parser = MLLPStreamParser()
        parser.append(MLLPFramer.frame(""))
        XCTAssertEqual(try parser.nextMessage(), "")
    }

    // MARK: - MLLPConfiguration Tests

    func testConfigurationDefaults() {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        XCTAssertEqual(config.host, "localhost")
        XCTAssertEqual(config.port, 2575)
        XCTAssertFalse(config.useTLS)
        XCTAssertEqual(config.connectionTimeout, 30.0)
        XCTAssertEqual(config.responseTimeout, 30.0)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.retryDelay, 1.0)
        XCTAssertEqual(config.maxMessageSize, 1_048_576)
        XCTAssertTrue(config.autoReconnect)
        XCTAssertNil(config.keepAliveInterval)
    }

    func testConfigurationCustomValues() {
        let config = MLLPConfiguration(
            host: "hl7.example.com",
            port: 4444,
            useTLS: true,
            connectionTimeout: 60.0,
            responseTimeout: 45.0,
            maxRetryAttempts: 5,
            retryDelay: 2.5,
            maxMessageSize: 2_000_000,
            autoReconnect: false,
            keepAliveInterval: 15.0
        )
        XCTAssertEqual(config.host, "hl7.example.com")
        XCTAssertEqual(config.port, 4444)
        XCTAssertTrue(config.useTLS)
        XCTAssertEqual(config.connectionTimeout, 60.0)
        XCTAssertEqual(config.responseTimeout, 45.0)
        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.retryDelay, 2.5)
        XCTAssertEqual(config.maxMessageSize, 2_000_000)
        XCTAssertFalse(config.autoReconnect)
        XCTAssertEqual(config.keepAliveInterval, 15.0)
    }

    func testConfigurationEquatable() {
        let config1 = MLLPConfiguration(host: "localhost", port: 2575)
        let config2 = MLLPConfiguration(host: "localhost", port: 2575)
        let config3 = MLLPConfiguration(host: "localhost", port: 2576)
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    // MARK: - MLLPConfigurationBuilder Tests

    func testBuilderDefaults() {
        let config = MLLPConfiguration.builder().build()
        XCTAssertEqual(config.host, "localhost")
        XCTAssertEqual(config.port, 2575)
        XCTAssertFalse(config.useTLS)
        XCTAssertEqual(config.connectionTimeout, 30.0)
        XCTAssertEqual(config.responseTimeout, 30.0)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.retryDelay, 1.0)
        XCTAssertEqual(config.maxMessageSize, 1_048_576)
        XCTAssertTrue(config.autoReconnect)
        XCTAssertNil(config.keepAliveInterval)
    }

    func testBuilderFluentAPI() {
        let config = MLLPConfiguration.builder()
            .host("hl7server.local")
            .port(5555)
            .useTLS(true)
            .connectionTimeout(10.0)
            .responseTimeout(15.0)
            .maxRetryAttempts(1)
            .retryDelay(0.5)
            .maxMessageSize(500_000)
            .autoReconnect(false)
            .keepAliveInterval(30.0)
            .build()

        XCTAssertEqual(config.host, "hl7server.local")
        XCTAssertEqual(config.port, 5555)
        XCTAssertTrue(config.useTLS)
        XCTAssertEqual(config.connectionTimeout, 10.0)
        XCTAssertEqual(config.responseTimeout, 15.0)
        XCTAssertEqual(config.maxRetryAttempts, 1)
        XCTAssertEqual(config.retryDelay, 0.5)
        XCTAssertEqual(config.maxMessageSize, 500_000)
        XCTAssertFalse(config.autoReconnect)
        XCTAssertEqual(config.keepAliveInterval, 30.0)
    }

    func testBuilderPartialOverride() {
        let config = MLLPConfiguration.builder()
            .host("custom-host")
            .port(9999)
            .build()

        XCTAssertEqual(config.host, "custom-host")
        XCTAssertEqual(config.port, 9999)
        XCTAssertFalse(config.useTLS) // default
        XCTAssertEqual(config.maxRetryAttempts, 3) // default
    }

    // MARK: - MLLPConnectionState Tests

    func testConnectionStateEquatable() {
        XCTAssertEqual(MLLPConnectionState.disconnected, MLLPConnectionState.disconnected)
        XCTAssertEqual(MLLPConnectionState.connecting, MLLPConnectionState.connecting)
        XCTAssertEqual(MLLPConnectionState.connected, MLLPConnectionState.connected)
        XCTAssertEqual(MLLPConnectionState.disconnecting, MLLPConnectionState.disconnecting)
        XCTAssertEqual(MLLPConnectionState.error("test"), MLLPConnectionState.error("test"))
        XCTAssertNotEqual(MLLPConnectionState.connected, MLLPConnectionState.disconnected)
        XCTAssertNotEqual(MLLPConnectionState.error("a"), MLLPConnectionState.error("b"))
    }

    // MARK: - MLLPConnectionMetrics Tests

    func testMetricsInitialValues() {
        let metrics = MLLPConnectionMetrics()
        XCTAssertEqual(metrics.messagesSent, 0)
        XCTAssertEqual(metrics.messagesReceived, 0)
        XCTAssertEqual(metrics.bytesSent, 0)
        XCTAssertEqual(metrics.bytesReceived, 0)
        XCTAssertNil(metrics.connectionStartTime)
        XCTAssertNil(metrics.lastActivityTime)
        XCTAssertEqual(metrics.reconnectionCount, 0)
        XCTAssertEqual(metrics.errors, 0)
    }

    func testMetricsMutability() {
        var metrics = MLLPConnectionMetrics()
        metrics.messagesSent = 5
        metrics.messagesReceived = 3
        metrics.bytesSent = 1024
        metrics.bytesReceived = 512
        metrics.connectionStartTime = Date()
        metrics.lastActivityTime = Date()
        metrics.reconnectionCount = 2
        metrics.errors = 1

        XCTAssertEqual(metrics.messagesSent, 5)
        XCTAssertEqual(metrics.messagesReceived, 3)
        XCTAssertEqual(metrics.bytesSent, 1024)
        XCTAssertEqual(metrics.bytesReceived, 512)
        XCTAssertNotNil(metrics.connectionStartTime)
        XCTAssertNotNil(metrics.lastActivityTime)
        XCTAssertEqual(metrics.reconnectionCount, 2)
        XCTAssertEqual(metrics.errors, 1)
    }

    // MARK: - MLLPConnection Tests

    func testConnectionInitialState() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let connection = MLLPConnection(configuration: config)
        let state = await connection.currentState
        XCTAssertEqual(state, .disconnected)
    }

    func testConnectionInitialMetrics() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let connection = MLLPConnection(configuration: config)
        let metrics = await connection.currentMetrics
        XCTAssertEqual(metrics.messagesSent, 0)
        XCTAssertEqual(metrics.messagesReceived, 0)
    }

    func testConnectionDisconnect() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let connection = MLLPConnection(configuration: config)
        await connection.disconnect()
        let state = await connection.currentState
        XCTAssertEqual(state, .disconnected)
    }

    func testConnectionSendWithoutConnect() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let connection = MLLPConnection(configuration: config)
        let rawMessage = "MSH|^~\\&|SEND|FAC|RECV|FAC||ADT^A01|123|P|2.5\rPID|||12345"
        do {
            let message = try HL7v2Message.parse(rawMessage)
            _ = try await connection.send(message)
            XCTFail("Expected networkError for sending without connection")
        } catch let error as HL7Error {
            guard case .networkError(let msg, _) = error else {
                XCTFail("Expected networkError, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("Not connected"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConnectionSendRawWithoutConnect() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let connection = MLLPConnection(configuration: config)
        do {
            _ = try await connection.sendRaw(Data([0x0B, 0x41, 0x1C, 0x0D]))
            XCTFail("Expected networkError for sending without connection")
        } catch let error as HL7Error {
            guard case .networkError = error else {
                XCTFail("Expected networkError")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    #if !canImport(Network)
    func testConnectionConnectOnLinux() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let connection = MLLPConnection(configuration: config)
        do {
            try await connection.connect()
            XCTFail("Expected networkError on non-Apple platform")
        } catch let error as HL7Error {
            guard case .networkError(let msg, _) = error else {
                XCTFail("Expected networkError")
                return
            }
            XCTAssertTrue(msg.contains("Network.framework"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    #endif

    // MARK: - MLLPListenerConfiguration Tests

    func testListenerConfigurationDefaults() {
        let config = MLLPListenerConfiguration(
            port: 2575,
            messageHandler: { msg in return msg }
        )
        XCTAssertEqual(config.port, 2575)
        XCTAssertFalse(config.useTLS)
        XCTAssertEqual(config.maxConnections, 100)
    }

    func testListenerConfigurationCustom() {
        let config = MLLPListenerConfiguration(
            port: 3000,
            useTLS: true,
            maxConnections: 50,
            messageHandler: { _ in return "ACK" }
        )
        XCTAssertEqual(config.port, 3000)
        XCTAssertTrue(config.useTLS)
        XCTAssertEqual(config.maxConnections, 50)
    }

    // MARK: - MLLPListenerState Tests

    func testListenerStateEquatable() {
        XCTAssertEqual(MLLPListenerState.stopped, MLLPListenerState.stopped)
        XCTAssertEqual(MLLPListenerState.starting, MLLPListenerState.starting)
        XCTAssertEqual(MLLPListenerState.listening, MLLPListenerState.listening)
        XCTAssertEqual(MLLPListenerState.stopping, MLLPListenerState.stopping)
        XCTAssertEqual(MLLPListenerState.error("x"), MLLPListenerState.error("x"))
        XCTAssertNotEqual(MLLPListenerState.stopped, MLLPListenerState.listening)
        XCTAssertNotEqual(MLLPListenerState.error("a"), MLLPListenerState.error("b"))
    }

    // MARK: - MLLPListener Tests

    func testListenerInitialState() async {
        let config = MLLPListenerConfiguration(
            port: 2575,
            messageHandler: { msg in return msg }
        )
        let listener = MLLPListener(configuration: config)
        let state = await listener.currentState
        XCTAssertEqual(state, .stopped)
    }

    func testListenerStop() async {
        let config = MLLPListenerConfiguration(
            port: 2575,
            messageHandler: { msg in return msg }
        )
        let listener = MLLPListener(configuration: config)
        await listener.stop()
        let state = await listener.currentState
        XCTAssertEqual(state, .stopped)
    }

    #if !canImport(Network)
    func testListenerStartOnLinux() async {
        let config = MLLPListenerConfiguration(
            port: 2575,
            messageHandler: { msg in return msg }
        )
        let listener = MLLPListener(configuration: config)
        do {
            try await listener.start()
            XCTFail("Expected networkError on non-Apple platform")
        } catch let error as HL7Error {
            guard case .networkError(let msg, _) = error else {
                XCTFail("Expected networkError")
                return
            }
            XCTAssertTrue(msg.contains("Network.framework"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    #endif

    // MARK: - MLLPConnectionPool Tests

    func testPoolInitialState() async {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let pool = MLLPConnectionPool(configuration: config, maxConnections: 3)
        let available = await pool.availableCount
        let active = await pool.activeCount
        XCTAssertEqual(available, 0)
        XCTAssertEqual(active, 0)
    }

    func testPoolAcquire() async throws {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let pool = MLLPConnectionPool(configuration: config, maxConnections: 3)
        let connection = try await pool.acquire()
        let active = await pool.activeCount
        XCTAssertEqual(active, 1)

        let state = await connection.currentState
        XCTAssertEqual(state, .disconnected)
    }

    func testPoolRelease() async throws {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let pool = MLLPConnectionPool(configuration: config, maxConnections: 3)
        let connection = try await pool.acquire()
        var activeCount = await pool.activeCount
        var availableCount = await pool.availableCount
        XCTAssertEqual(activeCount, 1)
        XCTAssertEqual(availableCount, 0)

        await pool.release(connection)
        activeCount = await pool.activeCount
        availableCount = await pool.availableCount
        XCTAssertEqual(activeCount, 0)
        XCTAssertEqual(availableCount, 1)
    }

    func testPoolReuse() async throws {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let pool = MLLPConnectionPool(configuration: config, maxConnections: 3)

        let conn1 = try await pool.acquire()
        await pool.release(conn1)

        let conn2 = try await pool.acquire()
        // Should reuse the same connection
        XCTAssertTrue(conn1 === conn2, "Pool should reuse released connections")
    }

    func testPoolExhaustion() async throws {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let pool = MLLPConnectionPool(configuration: config, maxConnections: 2)

        _ = try await pool.acquire()
        _ = try await pool.acquire()

        do {
            _ = try await pool.acquire()
            XCTFail("Expected networkError for pool exhaustion")
        } catch let error as HL7Error {
            guard case .networkError(let msg, _) = error else {
                XCTFail("Expected networkError")
                return
            }
            XCTAssertTrue(msg.contains("exhausted"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPoolCloseAll() async throws {
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let pool = MLLPConnectionPool(configuration: config, maxConnections: 5)

        _ = try await pool.acquire()
        let conn2 = try await pool.acquire()
        await pool.release(conn2)

        await pool.closeAll()
        let finalActive = await pool.activeCount
        let finalAvailable = await pool.availableCount
        XCTAssertEqual(finalActive, 0)
        XCTAssertEqual(finalAvailable, 0)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        // Verify types can be safely sent across concurrency boundaries
        let config = MLLPConfiguration(host: "localhost", port: 2575)
        let metrics = MLLPConnectionMetrics()

        let task1 = Task { @Sendable in
            return config.host
        }
        let task2 = Task { @Sendable in
            return metrics.messagesSent
        }

        let host = await task1.value
        let sent = await task2.value
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(sent, 0)
    }

    func testMLLPFramerSendable() async {
        let task = Task { @Sendable in
            return MLLPFramer.frame("TEST")
        }
        let result = await task.value
        XCTAssertTrue(MLLPFramer.isCompleteFrame(result))
    }

    // MARK: - Performance Tests

    func testFramingPerformance() {
        let message = String(repeating: "MSH|^~\\&|TEST|FAC|", count: 100)
        measure {
            for _ in 0..<1000 {
                _ = MLLPFramer.frame(message)
            }
        }
    }

    func testDeframingPerformance() throws {
        let message = String(repeating: "MSH|^~\\&|TEST|FAC|", count: 100)
        let framed = MLLPFramer.frame(message)
        measure {
            for _ in 0..<1000 {
                _ = try? MLLPFramer.deframe(framed)
            }
        }
    }

    func testStreamParserPerformance() throws {
        let messages = (0..<100).map { MLLPFramer.frame("MSG_\($0)") }
        var combined = Data()
        for msg in messages {
            combined.append(msg)
        }

        measure {
            var parser = MLLPStreamParser()
            parser.append(combined)
            while let _ = try? parser.nextMessage() {}
        }
    }

    // MARK: - Edge Case Tests

    func testFrameWithMLLPBytesInMessage() throws {
        // Message containing bytes that look like MLLP framing
        let message = "MSH|data\u{0B}embedded\u{1C}bytes\u{0D}here"
        let framed = MLLPFramer.frame(message)
        let deframed = try MLLPFramer.deframe(framed)
        XCTAssertEqual(deframed, message)
    }

    func testStreamParserWithEmbeddedEndBlock() throws {
        // Per the MLLP specification, HL7 message content must not contain 0x1C (file separator).
        // The 0x1C 0x0D sequence is reserved exclusively as the MLLP end-block marker.
        // If a malformed message somehow contains 0x1C 0x0D, the parser treats it as the
        // end-of-frame boundary, which is the correct behavior per the MLLP standard.
        var parser = MLLPStreamParser()
        let message = "INNER\u{1C}\u{0D}DATA"
        let framed = MLLPFramer.frame(message)
        parser.append(framed)

        let result = try parser.nextMessage()
        XCTAssertNotNil(result)
        // The parser correctly interprets the first 0x1C 0x0D as the end-of-frame
        // marker per the MLLP specification.
        XCTAssertEqual(result, "INNER")
    }

    func testLargeMessage() throws {
        let message = String(repeating: "A", count: 100_000)
        let framed = MLLPFramer.frame(message)
        let deframed = try MLLPFramer.deframe(framed)
        XCTAssertEqual(deframed, message)
    }

    func testUnicodeMessage() throws {
        let message = "MSH|^~\\&|日本語テスト|施設|Ñoño|Ünîcödé"
        let framed = MLLPFramer.frame(message)
        let deframed = try MLLPFramer.deframe(framed)
        XCTAssertEqual(deframed, message)
    }
}
