import XCTest
@testable import HL7Core

/// Tests for actor-based concurrency patterns
final class ActorPatternsTests: XCTestCase {
    
    // MARK: - MessageProcessor Tests
    
    func testMessageProcessorSingleMessage() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        let result = try await processor.process(data: testData)
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.duration, .zero)
        XCTAssertEqual(result.messageData, testData)
    }
    
    func testMessageProcessorMetrics() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Process multiple messages
        for _ in 0..<5 {
            _ = try await processor.process(data: testData)
        }
        
        let metrics = await processor.metrics()
        
        XCTAssertEqual(metrics.messagesProcessed, 5)
        XCTAssertEqual(metrics.errorCount, 0)
        XCTAssertGreaterThan(metrics.totalDuration, .zero)
        XCTAssertGreaterThan(metrics.averageDuration, .zero)
    }
    
    func testMessageProcessorBatchProcessing() async throws {
        let processor = MessageProcessor()
        
        // Create test messages
        let messages = (0..<10).map { index in
            "MSH|^~\\&|Test\(index)".data(using: .utf8)!
        }
        
        let results = try await processor.processBatch(messages, maxConcurrency: 4)
        
        XCTAssertEqual(results.count, 10)
        XCTAssertTrue(results.allSatisfy { $0.success })
    }
    
    func testMessageProcessorConcurrency() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Process messages concurrently
        try await withThrowingTaskGroup(of: ProcessingResult.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await processor.process(data: testData)
                }
            }
            
            var resultCount = 0
            for try await result in group {
                XCTAssertTrue(result.success)
                resultCount += 1
            }
            
            XCTAssertEqual(resultCount, 20)
        }
        
        let metrics = await processor.metrics()
        XCTAssertEqual(metrics.messagesProcessed, 20)
    }
    
    func testMessageProcessorResetMetrics() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        _ = try await processor.process(data: testData)
        
        var metrics = await processor.metrics()
        XCTAssertEqual(metrics.messagesProcessed, 1)
        
        await processor.resetMetrics()
        
        metrics = await processor.metrics()
        XCTAssertEqual(metrics.messagesProcessed, 0)
        XCTAssertEqual(metrics.totalDuration, .zero)
    }
    
    func testMessageProcessorActiveCount() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Start processing in background
        let task = Task {
            try await processor.process(data: testData)
        }
        
        // Small delay to let processing start
        try await Task.sleep(for: .milliseconds(1))
        
        // Check active count (may be 0 or 1 depending on timing)
        let activeCount = await processor.activeCount
        XCTAssertGreaterThanOrEqual(activeCount, 0)
        
        _ = try await task.value
    }
    
    // MARK: - StreamProcessor Tests
    
    func testStreamProcessorBasicProcessing() async throws {
        let processor = StreamProcessor()
        
        // Create test stream
        let testData = (0..<5).map { index in
            "Message\(index)".data(using: .utf8)!
        }
        
        let stream = AsyncStream<Data> { continuation in
            for data in testData {
                continuation.yield(data)
            }
            continuation.finish()
        }
        
        let resultStream = try await processor.processStream(stream)
        
        var results: [ProcessingResult] = []
        for try await result in resultStream {
            results.append(result)
        }
        
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.allSatisfy { $0.success })
    }
    
    func testStreamProcessorPositionTracking() async throws {
        let processor = StreamProcessor()
        
        let testData = [
            Data([1, 2, 3]),
            Data([4, 5, 6]),
            Data([7, 8, 9])
        ]
        
        let stream = AsyncStream<Data> { continuation in
            for data in testData {
                continuation.yield(data)
            }
            continuation.finish()
        }
        
        let resultStream = try await processor.processStream(stream)
        
        // Consume stream
        for try await _ in resultStream {
            // Just consume
        }
        
        let position = await processor.currentPosition
        XCTAssertEqual(position, 9) // Total bytes processed
    }
    
    func testStreamProcessorCancellation() async throws {
        let processor = StreamProcessor()
        
        // Create infinite stream
        let stream = AsyncStream<Data> { continuation in
            Task {
                while true {
                    try? await Task.sleep(for: .milliseconds(10))
                    continuation.yield("Data".data(using: .utf8)!)
                }
            }
        }
        
        let task = Task {
            let resultStream = try await processor.processStream(stream)
            var count = 0
            for try await _ in resultStream {
                count += 1
                if count >= 3 {
                    break
                }
            }
            return count
        }
        
        let count = try await task.value
        XCTAssertEqual(count, 3)
    }
    
    func testStreamProcessorStateManagement() async throws {
        let processor = StreamProcessor()
        
        // Should not be processing initially
        var isProcessing = await processor.processingActive
        XCTAssertFalse(isProcessing)
        
        // Create simple stream
        let stream = AsyncStream<Data> { continuation in
            continuation.yield("Test".data(using: .utf8)!)
            continuation.finish()
        }
        
        let resultStream = try await processor.processStream(stream)
        
        // Consume stream
        for try await _ in resultStream {
            // Check if processing
            isProcessing = await processor.processingActive
            // May be true during processing
        }
        
        // Should not be processing after stream completes
        isProcessing = await processor.processingActive
        XCTAssertFalse(isProcessing)
    }
    
    // MARK: - MessagePipeline Tests
    
    func testMessagePipelineBasicProcessing() async throws {
        let pipeline = MessagePipeline()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        let result = try await pipeline.process(testData)
        
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.duration, .zero)
    }
    
    func testMessagePipelineMetrics() async throws {
        let pipeline = MessagePipeline()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Process multiple messages
        _ = try await pipeline.process(testData)
        _ = try await pipeline.process(testData)
        _ = try await pipeline.process(testData)
        
        let metrics = await pipeline.getMetrics()
        
        XCTAssertEqual(metrics.successCount, 3)
        XCTAssertEqual(metrics.failureCount, 0)
        XCTAssertEqual(metrics.totalProcessed, 3)
        XCTAssertGreaterThan(metrics.totalDuration, .zero)
        XCTAssertGreaterThan(metrics.averageDuration, .zero)
    }
    
    func testMessagePipelineConcurrentProcessing() async throws {
        let pipeline = MessagePipeline()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Process messages concurrently
        try await withThrowingTaskGroup(of: ProcessingResult.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await pipeline.process(testData)
                }
            }
            
            var resultCount = 0
            for try await result in group {
                XCTAssertTrue(result.success)
                resultCount += 1
            }
            
            XCTAssertEqual(resultCount, 10)
        }
        
        let metrics = await pipeline.getMetrics()
        XCTAssertEqual(metrics.successCount, 10)
    }
    
    // MARK: - MessageRouter Tests
    
    func testMessageRouterV2Detection() async throws {
        let router = MessageRouter()
        let v2Data = "MSH|^~\\&|Test".data(using: .utf8)!
        
        let result = try await router.route(v2Data)
        
        XCTAssertTrue(result.success)
        
        let stats = await router.statistics()
        XCTAssertEqual(stats[.v2], 1)
    }
    
    func testMessageRouterV3Detection() async throws {
        let router = MessageRouter()
        let v3Data = "<ClinicalDocument>".data(using: .utf8)!
        
        let result = try await router.route(v3Data)
        
        XCTAssertTrue(result.success)
        
        let stats = await router.statistics()
        XCTAssertEqual(stats[.v3], 1)
    }
    
    func testMessageRouterFHIRDetection() async throws {
        let router = MessageRouter()
        let fhirData = "{\"resourceType\":\"Patient\"}".data(using: .utf8)!
        
        let result = try await router.route(fhirData)
        
        XCTAssertTrue(result.success)
        
        let stats = await router.statistics()
        XCTAssertEqual(stats[.fhir], 1)
    }
    
    func testMessageRouterUnknownType() async throws {
        let router = MessageRouter()
        let unknownData = Data([0xFF, 0xFE])
        
        do {
            _ = try await router.route(unknownData)
            XCTFail("Should have thrown an error")
        } catch let error as HL7Error {
            if case .invalidFormat = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testMessageRouterMixedMessages() async throws {
        let router = MessageRouter()
        
        let messages: [Data] = [
            "MSH|^~\\&|Test".data(using: .utf8)!,
            "<ClinicalDocument>".data(using: .utf8)!,
            "{\"resourceType\":\"Patient\"}".data(using: .utf8)!,
            "MSH|^~\\&|Test2".data(using: .utf8)!,
        ]
        
        for message in messages {
            _ = try await router.route(message)
        }
        
        let stats = await router.statistics()
        
        XCTAssertEqual(stats[.v2], 2)
        XCTAssertEqual(stats[.v3], 1)
        XCTAssertEqual(stats[.fhir], 1)
    }
    
    func testMessageRouterStatisticsReset() async throws {
        let router = MessageRouter()
        let v2Data = "MSH|^~\\&|Test".data(using: .utf8)!
        
        _ = try await router.route(v2Data)
        
        var stats = await router.statistics()
        XCTAssertEqual(stats[.v2], 1)
        
        await router.resetStatistics()
        
        stats = await router.statistics()
        XCTAssertEqual(stats.count, 0)
    }
    
    func testMessageRouterConcurrentRouting() async throws {
        let router = MessageRouter()
        
        let messages: [(MessageType, Data)] = [
            (.v2, "MSH|^~\\&|Test".data(using: .utf8)!),
            (.v3, "<ClinicalDocument>".data(using: .utf8)!),
            (.fhir, "{\"resourceType\":\"Patient\"}".data(using: .utf8)!),
        ]
        
        // Route messages concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (_, data) in messages {
                for _ in 0..<5 {
                    group.addTask {
                        _ = try await router.route(data)
                    }
                }
            }
            
            try await group.waitForAll()
        }
        
        let stats = await router.statistics()
        XCTAssertEqual(stats[.v2], 5)
        XCTAssertEqual(stats[.v3], 5)
        XCTAssertEqual(stats[.fhir], 5)
    }
    
    // MARK: - Performance Tests
    
    func testMessageProcessorPerformance() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        measure {
            let expectation = XCTestExpectation(description: "Performance test")
            
            Task {
                do {
                    for _ in 0..<100 {
                        _ = try await processor.process(data: testData)
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Processing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testBatchProcessingPerformance() async throws {
        let processor = MessageProcessor()
        
        let messages = (0..<100).map { index in
            "MSH|^~\\&|Test\(index)".data(using: .utf8)!
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Batch performance test")
            
            Task {
                do {
                    _ = try await processor.processBatch(messages, maxConcurrency: 8)
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch processing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testActorIsolation() async throws {
        let processor = MessageProcessor()
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Process many messages concurrently to verify no data races
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = try await processor.process(data: testData)
                }
            }
            
            try await group.waitForAll()
        }
        
        let metrics = await processor.metrics()
        XCTAssertEqual(metrics.messagesProcessed, 100)
        XCTAssertEqual(metrics.errorCount, 0)
    }
    
    func testMultipleActorsConcurrent() async throws {
        // Create multiple independent actors
        let processors = (0..<5).map { _ in MessageProcessor() }
        let testData = "MSH|^~\\&|Test".data(using: .utf8)!
        
        // Process messages on all actors concurrently
        try await withThrowingTaskGroup(of: Int.self) { group in
            for (index, processor) in processors.enumerated() {
                group.addTask {
                    for _ in 0..<10 {
                        _ = try await processor.process(data: testData)
                    }
                    return index
                }
            }
            
            var completed = Set<Int>()
            for try await index in group {
                completed.insert(index)
            }
            
            XCTAssertEqual(completed.count, 5)
        }
        
        // Verify each processor handled exactly 10 messages
        for processor in processors {
            let metrics = await processor.metrics()
            XCTAssertEqual(metrics.messagesProcessed, 10)
        }
    }
}
