import XCTest
@testable import HL7Core

final class ParsingStrategiesTests: XCTestCase {
    
    // MARK: - BufferConfiguration Tests
    
    func testBufferConfigurationDefaults() {
        let config = BufferConfiguration()
        
        XCTAssertEqual(config.bufferSize, 64 * 1024)
        XCTAssertEqual(config.maxPoolSize, 10)
        XCTAssertTrue(config.autoGrow)
        XCTAssertEqual(config.maxBufferSize, 1024 * 1024)
    }
    
    func testBufferConfigurationCustom() {
        let config = BufferConfiguration(
            bufferSize: 128 * 1024,
            maxPoolSize: 20,
            autoGrow: false,
            maxBufferSize: 2 * 1024 * 1024
        )
        
        XCTAssertEqual(config.bufferSize, 128 * 1024)
        XCTAssertEqual(config.maxPoolSize, 20)
        XCTAssertFalse(config.autoGrow)
        XCTAssertEqual(config.maxBufferSize, 2 * 1024 * 1024)
    }
    
    // MARK: - ParsingBuffer Tests
    
    func testParsingBufferInitialization() {
        let buffer = ParsingBuffer(size: 1024)
        
        XCTAssertEqual(buffer.position, 0)
        XCTAssertEqual(buffer.length, 0)
        XCTAssertEqual(buffer.availableSpace, 1024)
        XCTAssertFalse(buffer.isFull)
    }
    
    func testParsingBufferReset() {
        var buffer = ParsingBuffer(size: 1024)
        // Simulate usage (we can't actually write to it in this test)
        // but we can test the reset functionality
        buffer.reset()
        
        XCTAssertEqual(buffer.position, 0)
        XCTAssertEqual(buffer.length, 0)
    }
    
    // MARK: - BufferPool Tests
    
    func testBufferPoolAcquireAndRelease() async {
        let config = BufferConfiguration(maxPoolSize: 5)
        let pool = BufferPool(configuration: config)
        
        // Acquire a buffer
        let buffer1 = await pool.acquire()
        XCTAssertEqual(buffer1.position, 0)
        
        // Release it back
        await pool.release(buffer1)
        
        // Acquire again - should get a reset buffer
        let buffer2 = await pool.acquire()
        XCTAssertEqual(buffer2.position, 0)
    }
    
    func testBufferPoolMaxSize() async {
        let config = BufferConfiguration(maxPoolSize: 2)
        let pool = BufferPool(configuration: config)
        
        // Release more buffers than maxPoolSize
        for _ in 0..<5 {
            let buffer = await pool.acquire()
            await pool.release(buffer)
        }
        
        // Pool should not exceed max size
        // (We can't directly verify the internal state, but the test ensures no crashes)
    }
    
    func testBufferPoolClear() async {
        let pool = BufferPool()
        
        // Add some buffers
        for _ in 0..<3 {
            let buffer = await pool.acquire()
            await pool.release(buffer)
        }
        
        // Clear the pool
        await pool.clear()
        
        // Acquiring after clear should create a new buffer
        let buffer = await pool.acquire()
        XCTAssertEqual(buffer.position, 0)
    }
    
    // MARK: - LazyStorage Tests
    
    func testLazyStorageNotParsedInitially() {
        let data = "Hello".data(using: .utf8)!
        let storage = LazyStorage<String>(rawData: data) { data in
            String(data: data, encoding: .utf8)!
        }
        
        XCTAssertFalse(storage.isParsed)
        XCTAssertEqual(storage.rawData, data)
    }
    
    func testLazyStorageParseOnDemand() throws {
        let data = "Hello, World!".data(using: .utf8)!
        var storage = LazyStorage<String>(rawData: data) { data in
            String(data: data, encoding: .utf8)!
        }
        
        // Parse on first access
        let value = try storage.value()
        XCTAssertEqual(value, "Hello, World!")
        XCTAssertTrue(storage.isParsed)
        
        // Second access should return cached value
        let value2 = try storage.value()
        XCTAssertEqual(value2, "Hello, World!")
    }
    
    func testLazyStorageParserError() {
        let data = "Invalid".data(using: .utf8)!
        var storage = LazyStorage<Int>(rawData: data) { _ in
            throw HL7Error.parsingError("Cannot parse Int")
        }
        
        XCTAssertThrowsError(try storage.value()) { error in
            if case HL7Error.parsingError(let description, _) = error {
                XCTAssertEqual(description, "Cannot parse Int")
            } else {
                XCTFail("Expected parsingError")
            }
        }
    }
    
    // MARK: - ParsedIndex Tests
    
    func testParsedIndexCreation() {
        let index = ParsedIndex(offset: 100, length: 50, identifier: "MSH")
        
        XCTAssertEqual(index.offset, 100)
        XCTAssertEqual(index.length, 50)
        XCTAssertEqual(index.identifier, "MSH")
        XCTAssertEqual(index.range, 100..<150)
    }
    
    func testParsedIndexRange() {
        let index = ParsedIndex(offset: 0, length: 100)
        
        XCTAssertEqual(index.range.lowerBound, 0)
        XCTAssertEqual(index.range.upperBound, 100)
        XCTAssertTrue(index.range.contains(50))
        XCTAssertFalse(index.range.contains(150))
    }
    
    // MARK: - MessageIndex Tests
    
    func testMessageIndexCreation() {
        let entries = [
            ParsedIndex(offset: 0, length: 50, identifier: "MSH"),
            ParsedIndex(offset: 50, length: 30, identifier: "PID"),
            ParsedIndex(offset: 80, length: 40, identifier: "OBX")
        ]
        
        let index = MessageIndex(entries: entries, dataLength: 120)
        
        XCTAssertEqual(index.entries.count, 3)
        XCTAssertEqual(index.dataLength, 120)
    }
    
    func testMessageIndexFind() {
        let entries = [
            ParsedIndex(offset: 0, length: 50, identifier: "MSH"),
            ParsedIndex(offset: 50, length: 30, identifier: "PID"),
            ParsedIndex(offset: 80, length: 40, identifier: "MSH")
        ]
        
        let index = MessageIndex(entries: entries, dataLength: 120)
        
        let mshEntries = index.find(identifier: "MSH")
        XCTAssertEqual(mshEntries.count, 2)
        XCTAssertEqual(mshEntries[0].offset, 0)
        XCTAssertEqual(mshEntries[1].offset, 80)
        
        let pidEntries = index.find(identifier: "PID")
        XCTAssertEqual(pidEntries.count, 1)
        XCTAssertEqual(pidEntries[0].offset, 50)
        
        let unknownEntries = index.find(identifier: "UNKNOWN")
        XCTAssertEqual(unknownEntries.count, 0)
    }
    
    func testMessageIndexEntryAt() {
        let entries = [
            ParsedIndex(offset: 0, length: 50, identifier: "MSH"),
            ParsedIndex(offset: 50, length: 30, identifier: "PID"),
            ParsedIndex(offset: 80, length: 40, identifier: "OBX")
        ]
        
        let index = MessageIndex(entries: entries, dataLength: 120)
        
        let entry1 = index.entry(at: 25)
        XCTAssertNotNil(entry1)
        XCTAssertEqual(entry1?.identifier, "MSH")
        
        let entry2 = index.entry(at: 65)
        XCTAssertNotNil(entry2)
        XCTAssertEqual(entry2?.identifier, "PID")
        
        let entry3 = index.entry(at: 150)
        XCTAssertNil(entry3)
    }
    
    // MARK: - ChunkConfiguration Tests
    
    func testChunkConfigurationDefaults() {
        let config = ChunkConfiguration()
        
        XCTAssertEqual(config.chunkSize, 64 * 1024)
        XCTAssertEqual(config.overlap, 1024)
    }
    
    func testChunkConfigurationCustom() {
        let config = ChunkConfiguration(chunkSize: 128 * 1024, overlap: 2048)
        
        XCTAssertEqual(config.chunkSize, 128 * 1024)
        XCTAssertEqual(config.overlap, 2048)
    }
    
    // MARK: - ParsingStrategy Tests
    
    func testParsingStrategyEager() {
        let strategy = ParsingStrategy.eager
        
        if case .eager = strategy {
            // Success
        } else {
            XCTFail("Expected eager strategy")
        }
    }
    
    func testParsingStrategyLazy() {
        let strategy = ParsingStrategy.lazy
        
        if case .lazy = strategy {
            // Success
        } else {
            XCTFail("Expected lazy strategy")
        }
    }
    
    func testParsingStrategyStreaming() {
        let config = BufferConfiguration()
        let strategy = ParsingStrategy.streaming(config)
        
        if case .streaming(let bufferConfig) = strategy {
            XCTAssertEqual(bufferConfig.bufferSize, config.bufferSize)
        } else {
            XCTFail("Expected streaming strategy")
        }
    }
    
    func testParsingStrategyChunked() {
        let config = ChunkConfiguration(chunkSize: 1024, overlap: 128)
        let strategy = ParsingStrategy.chunked(config)
        
        if case .chunked(let chunkConfig) = strategy {
            XCTAssertEqual(chunkConfig.chunkSize, 1024)
            XCTAssertEqual(chunkConfig.overlap, 128)
        } else {
            XCTFail("Expected chunked strategy")
        }
    }
    
    func testParsingStrategyIndexed() {
        let strategy = ParsingStrategy.indexed
        
        if case .indexed = strategy {
            // Success
        } else {
            XCTFail("Expected indexed strategy")
        }
    }
    
    func testParsingStrategyAutomatic() {
        let strategy = ParsingStrategy.automatic(threshold: 2 * 1024 * 1024)
        
        if case .automatic(let threshold) = strategy {
            XCTAssertEqual(threshold, 2 * 1024 * 1024)
        } else {
            XCTFail("Expected automatic strategy")
        }
    }
    
    // MARK: - ParsingMemoryMetrics Tests
    
    func testParsingMemoryMetricsCreation() {
        let metrics = ParsingMemoryMetrics(
            peakMemory: 1024,
            averageMemory: 512,
            allocations: 10,
            poolHits: 5
        )
        
        XCTAssertEqual(metrics.peakMemory, 1024)
        XCTAssertEqual(metrics.averageMemory, 512)
        XCTAssertEqual(metrics.allocations, 10)
        XCTAssertEqual(metrics.poolHits, 5)
    }
    
    func testParsingMemoryMetricsPoolHitRate() {
        let metrics = ParsingMemoryMetrics(
            peakMemory: 1024,
            averageMemory: 512,
            allocations: 10,
            poolHits: 5
        )
        
        // 5 hits out of 15 total (10 allocations + 5 hits)
        XCTAssertEqual(metrics.poolHitRate, 5.0 / 15.0, accuracy: 0.001)
    }
    
    func testParsingMemoryMetricsPoolHitRateZero() {
        let metrics = ParsingMemoryMetrics(
            peakMemory: 1024,
            averageMemory: 512,
            allocations: 0,
            poolHits: 0
        )
        
        XCTAssertEqual(metrics.poolHitRate, 0.0)
    }
    
    // MARK: - ParsingMetricsTracker Tests
    
    func testParsingMetricsTrackerAllocation() async {
        let tracker = ParsingMetricsTracker()
        
        await tracker.recordAllocation(size: 1024, fromPool: false)
        await tracker.recordAllocation(size: 512, fromPool: true)
        
        let metrics = await tracker.snapshot()
        
        XCTAssertEqual(metrics.allocations, 1)
        XCTAssertEqual(metrics.poolHits, 1)
        XCTAssertGreaterThanOrEqual(metrics.peakMemory, 1024)
    }
    
    func testParsingMetricsTrackerDeallocation() async {
        let tracker = ParsingMetricsTracker()
        
        await tracker.recordAllocation(size: 1024, fromPool: false)
        await tracker.recordDeallocation(size: 512)
        
        let metrics = await tracker.snapshot()
        
        XCTAssertEqual(metrics.allocations, 1)
        XCTAssertGreaterThanOrEqual(metrics.peakMemory, 1024)
    }
    
    func testParsingMetricsTrackerPeakMemory() async {
        let tracker = ParsingMetricsTracker()
        
        await tracker.recordAllocation(size: 1024, fromPool: false)
        await tracker.recordAllocation(size: 2048, fromPool: false)
        await tracker.recordDeallocation(size: 1024)
        
        let metrics = await tracker.snapshot()
        
        // Peak should be 1024 + 2048 = 3072
        XCTAssertEqual(metrics.peakMemory, 3072)
    }
    
    func testParsingMetricsTrackerAverageMemory() async {
        let tracker = ParsingMetricsTracker()
        
        await tracker.recordAllocation(size: 1000, fromPool: false)
        await tracker.recordAllocation(size: 2000, fromPool: false)
        await tracker.recordAllocation(size: 3000, fromPool: false)
        
        let metrics = await tracker.snapshot()
        
        // Average should be (1000 + 3000 + 6000) / 3 = 3333
        XCTAssertEqual(metrics.averageMemory, 3333)
    }
    
    func testParsingMetricsTrackerReset() async {
        let tracker = ParsingMetricsTracker()
        
        await tracker.recordAllocation(size: 1024, fromPool: false)
        await tracker.recordAllocation(size: 512, fromPool: true)
        
        await tracker.reset()
        
        let metrics = await tracker.snapshot()
        
        XCTAssertEqual(metrics.peakMemory, 0)
        XCTAssertEqual(metrics.averageMemory, 0)
        XCTAssertEqual(metrics.allocations, 0)
        XCTAssertEqual(metrics.poolHits, 0)
    }
    
    // MARK: - Integration Tests
    
    func testBufferPoolWithMetricsTracking() async {
        let pool = BufferPool()
        let tracker = ParsingMetricsTracker()
        
        // Simulate buffer usage with tracking
        let buffer1 = await pool.acquire()
        await tracker.recordAllocation(size: 64 * 1024, fromPool: false)
        
        await pool.release(buffer1)
        await tracker.recordDeallocation(size: 64 * 1024)
        
        // Reuse from pool
        _ = await pool.acquire()
        await tracker.recordAllocation(size: 64 * 1024, fromPool: true)
        
        let metrics = await tracker.snapshot()
        
        XCTAssertEqual(metrics.allocations, 1)
        XCTAssertEqual(metrics.poolHits, 1)
        XCTAssertEqual(metrics.poolHitRate, 0.5, accuracy: 0.001)
    }
    
    func testLazyStorageWithComplexType() throws {
        struct ParsedMessage: Sendable {
            let segments: [String]
        }
        
        let data = "MSH|PID|OBX".data(using: .utf8)!
        var storage = LazyStorage<ParsedMessage>(rawData: data) { data in
            let string = String(data: data, encoding: .utf8)!
            let segments = string.split(separator: "|").map(String.init)
            return ParsedMessage(segments: segments)
        }
        
        XCTAssertFalse(storage.isParsed)
        
        let message = try storage.value()
        XCTAssertEqual(message.segments.count, 3)
        XCTAssertEqual(message.segments[0], "MSH")
        XCTAssertEqual(message.segments[1], "PID")
        XCTAssertEqual(message.segments[2], "OBX")
        XCTAssertTrue(storage.isParsed)
    }
}
