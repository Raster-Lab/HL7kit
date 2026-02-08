/// Tests for streaming API
///
/// Tests for memory-efficient streaming of HL7 messages from files and data

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class StreamingAPITests: XCTestCase {
    
    let sampleMessages = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000||ADT^A01|MSG001|P|2.5\r" +
        "PID|1||12345||Doe^John\r" +
        "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120001||ADT^A01|MSG002|P|2.5\r" +
        "PID|1||67890||Smith^Jane\r" +
        "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120002||ADT^A01|MSG003|P|2.5\r" +
        "PID|1||11111||Brown^Bob"
    
    // MARK: - Data Stream Source Tests
    
    func testDataStreamSourceRead() async throws {
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let source = DataStreamSource(data: data)
        
        let chunk1 = try await source.readNext(maxBytes: 100)
        XCTAssertNotNil(chunk1)
        XCTAssertLessThanOrEqual(chunk1?.count ?? 0, 100)
        
        // Read until exhausted
        var totalRead = chunk1?.count ?? 0
        while let chunk = try await source.readNext(maxBytes: 100) {
            totalRead += chunk.count
        }
        
        XCTAssertEqual(totalRead, data.count)
    }
    
    func testDataStreamSourceClose() async throws {
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let source = DataStreamSource(data: data)
        try await source.close()
        
        let afterClose = try await source.readNext(maxBytes: 100)
        XCTAssertNil(afterClose)
    }
    
    // MARK: - Message Stream Tests
    
    func testMessageStreamFromData() async throws {
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let parser = HL7v2Parser()
        let source = DataStreamSource(data: data)
        let stream = HL7MessageStream(source: source, parser: parser, bufferSize: 1024)
        
        var messageCount = 0
        for await result in stream {
            switch result {
            case .success(let message):
                XCTAssertNotNil(message.messageHeader)
                messageCount += 1
            case .failure(let error):
                XCTFail("Failed to parse message: \(error)")
            }
        }
        
        XCTAssertEqual(messageCount, 3)
    }
    
    func testMessageStreamWithSmallBuffer() async throws {
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let parser = HL7v2Parser()
        let source = DataStreamSource(data: data)
        let stream = HL7MessageStream(source: source, parser: parser, bufferSize: 50) // Small buffer
        
        var messageCount = 0
        for await result in stream {
            switch result {
            case .success:
                messageCount += 1
            case .failure(let error):
                XCTFail("Failed to parse message: \(error)")
            }
        }
        
        XCTAssertEqual(messageCount, 3)
    }
    
    // MARK: - File Stream Reader Tests
    
    func testFileStreamReaderWithData() async throws {
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let reader = HL7FileStreamReader()
        let stream = await reader.streamMessages(from: data, bufferSize: 1024)
        
        var messages: [HL7v2Message] = []
        for await result in stream {
            switch result {
            case .success(let message):
                messages.append(message)
            case .failure(let error):
                XCTFail("Failed to parse message: \(error)")
            }
        }
        
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].messageControlID(), "MSG001")
        XCTAssertEqual(messages[1].messageControlID(), "MSG002")
        XCTAssertEqual(messages[2].messageControlID(), "MSG003")
    }
    
    func testFileStreamReaderCountMessages() async throws {
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_messages.hl7")
        
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        try data.write(to: tempFile)
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        let reader = HL7FileStreamReader()
        let count = try await reader.countMessages(in: tempFile)
        
        XCTAssertEqual(count, 3)
    }
    
    func testFileStreamReaderStreamFromFile() async throws {
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_stream_messages.hl7")
        
        guard let data = sampleMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        try data.write(to: tempFile)
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        let reader = HL7FileStreamReader()
        let stream = await reader.streamMessages(from: tempFile, bufferSize: 512)
        
        var messageCount = 0
        for await result in stream {
            switch result {
            case .success:
                messageCount += 1
            case .failure(let error):
                XCTFail("Failed to parse message: \(error)")
            }
        }
        
        XCTAssertEqual(messageCount, 3)
    }
    
    // MARK: - Batch Stream Tests
    
    func testBatchStream() async throws {
        let batchData = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130000\r" +
            "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130001||ADT^A01|MSG001|P|2.5\r" +
            "PID|1||12345||Doe^John\r" +
            "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130002||ADT^A01|MSG002|P|2.5\r" +
            "PID|1||67890||Smith^Jane\r" +
            "BTS|2|Batch complete\r" +
            "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130100\r" +
            "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130101||ADT^A01|MSG003|P|2.5\r" +
            "PID|1||11111||Brown^Bob\r" +
            "BTS|1|Batch complete"
        
        guard let data = batchData.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let parser = HL7v2Parser()
        let source = DataStreamSource(data: data)
        let stream = HL7BatchStream(source: source, parser: parser, bufferSize: 1024)
        
        var batchCount = 0
        var totalMessages = 0
        
        for await result in stream {
            switch result {
            case .success(let batch):
                batchCount += 1
                totalMessages += batch.messages.count
            case .failure(let error):
                XCTFail("Failed to parse batch: \(error)")
            }
        }
        
        XCTAssertEqual(batchCount, 2)
        XCTAssertEqual(totalMessages, 3)
    }
    
    func testFileStreamReaderStreamBatches() async throws {
        let batchData = "BHS|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130000\r" +
            "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101130001||ADT^A01|MSG001|P|2.5\r" +
            "PID|1||12345||Doe^John\r" +
            "BTS|1|Batch complete"
        
        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_batch_stream.hl7")
        
        guard let data = batchData.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        try data.write(to: tempFile)
        
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        
        let reader = HL7FileStreamReader()
        let stream = await reader.streamBatches(from: tempFile, bufferSize: 512)
        
        var batchCount = 0
        for await result in stream {
            switch result {
            case .success(let batch):
                batchCount += 1
                XCTAssertEqual(batch.messages.count, 1)
            case .failure(let error):
                XCTFail("Failed to parse batch: \(error)")
            }
        }
        
        XCTAssertEqual(batchCount, 1)
    }
    
    // MARK: - Edge Cases Tests
    
    func testStreamWithEmptyData() async throws {
        let emptyData = Data()
        let parser = HL7v2Parser()
        let source = DataStreamSource(data: emptyData)
        let stream = HL7MessageStream(source: source, parser: parser, bufferSize: 1024)
        
        var messageCount = 0
        for await _ in stream {
            messageCount += 1
        }
        
        XCTAssertEqual(messageCount, 0)
    }
    
    func testStreamWithSingleMessage() async throws {
        let singleMessage = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\rPID|1||12345"
        
        guard let data = singleMessage.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let parser = HL7v2Parser()
        let source = DataStreamSource(data: data)
        let stream = HL7MessageStream(source: source, parser: parser, bufferSize: 1024)
        
        var messageCount = 0
        for await result in stream {
            switch result {
            case .success:
                messageCount += 1
            case .failure(let error):
                XCTFail("Failed to parse message: \(error)")
            }
        }
        
        XCTAssertEqual(messageCount, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testStreamWithInvalidMessage() async throws {
        let invalidMessages = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\r" +
            "INVALID_SEGMENT_DATA\r" +
            "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG002|P|2.5"
        
        guard let data = invalidMessages.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let parser = HL7v2Parser(configuration: ParserConfiguration(
            strategy: .eager,
            strictMode: false,
            errorRecovery: .skipInvalidSegments
        ))
        
        let source = DataStreamSource(data: data)
        let stream = HL7MessageStream(source: source, parser: parser, bufferSize: 1024)
        
        var successCount = 0
        var errorCount = 0
        
        for await result in stream {
            switch result {
            case .success:
                successCount += 1
            case .failure:
                errorCount += 1
            }
        }
        
        // Should get at least one valid message
        XCTAssertGreaterThan(successCount, 0)
    }
    
    // MARK: - Performance Tests
    
    func testStreamingPerformance() async throws {
        // Create a large dataset
        var largeDataset = ""
        for i in 1...1000 {
            largeDataset += "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG\(i)|P|2.5\r"
            largeDataset += "PID|1||\(i)||Doe^John\r"
        }
        
        guard let data = largeDataset.data(using: .utf8) else {
            XCTFail("Failed to encode test data")
            return
        }
        
        let parser = HL7v2Parser()
        let source = DataStreamSource(data: data)
        let stream = HL7MessageStream(source: source, parser: parser, bufferSize: 8192)
        
        let startTime = Date()
        
        var messageCount = 0
        for await result in stream {
            if case .success = result {
                messageCount += 1
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(messageCount, 1000)
        // Should process 1000 messages in reasonable time
        XCTAssertLessThan(elapsed, 10.0) // 10 seconds max
    }
}
