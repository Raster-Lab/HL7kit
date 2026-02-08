/// Performance benchmark tests for HL7 v2.x parser
///
/// Comprehensive performance testing for the HL7v2Kit parser including
/// throughput benchmarks, memory usage tests, and optimization comparisons.

import XCTest
import HL7Core
@testable import HL7v2Kit
import Foundation

final class PerformanceBenchmarkTests: XCTestCase {
    
    // MARK: - Test Data
    
    /// Sample ADT^A01 message for performance testing
    private let sampleADTA01 = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20231115120000||ADT^A01|MSG00001|P|2.5.1
        EVN|A01|20231115120000
        PID|1||12345^^^HOSPITAL^MR||DOE^JOHN^A||19800115|M|||123 MAIN ST^^ANYTOWN^CA^12345^USA|||||||12345678
        PV1|1|I|2000^2012^01||||004777^SMITH^JOHN^A|||SUR||||ADM|A0|
        """.replacingOccurrences(of: "\n        ", with: "\r")
    
    /// Sample ORU^R01 (lab results) message with multiple OBX segments
    private let sampleORUR01 = """
        MSH|^~\\&|LAB_SYS|HOSPITAL|EMR|HOSPITAL|20231115130000||ORU^R01|MSG00002|P|2.5.1
        PID|1||67890^^^HOSPITAL^MR||SMITH^JANE^B||19750320|F|||456 OAK AVE^^SOMETOWN^NY^54321^USA
        OBR|1|ORDER123|RESULT123|CBC^COMPLETE BLOOD COUNT|||20231115120000
        OBX|1|NM|WBC^WHITE BLOOD COUNT||7.5|10*3/uL|4.0-11.0|N|||F
        OBX|2|NM|RBC^RED BLOOD COUNT||4.8|10*6/uL|4.2-5.9|N|||F
        OBX|3|NM|HGB^HEMOGLOBIN||14.5|g/dL|12.0-16.0|N|||F
        OBX|4|NM|HCT^HEMATOCRIT||42.0|%|36.0-46.0|N|||F
        OBX|5|NM|PLT^PLATELET COUNT||250|10*3/uL|150-400|N|||F
        """.replacingOccurrences(of: "\n        ", with: "\r")
    
    /// Large message with many segments for stress testing
    private func generateLargeMessage(segmentCount: Int = 100) -> String {
        var segments = [
            "MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20231115120000||ORU^R01|MSG00003|P|2.5.1",
            "PID|1||99999^^^HOSPITAL^MR||PATIENT^TEST^X||19900101|M|||999 TEST ST^^TESTCITY^TX^99999^USA",
            "OBR|1|ORDER999|RESULT999|PANEL^TEST PANEL|||20231115120000"
        ]
        
        for i in 1...segmentCount {
            segments.append("OBX|\(i)|NM|TEST\(i)^TEST VALUE \(i)||\(Double(i) * 1.5)|mg/dL|0-100|N|||F")
        }
        
        return segments.joined(separator: "\r")
    }
    
    // MARK: - Baseline Performance Tests
    
    func testBaselineParsingPerformance() throws {
        let parser = HL7v2Parser()
        
        measure {
            for _ in 0..<100 {
                _ = try? parser.parse(sampleADTA01)
            }
        }
    }
    
    func testBaselineParsingThroughput() throws {
        let parser = HL7v2Parser()
        let iterations = 1000
        
        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(sampleADTA01)
        }
        let duration = Date().timeIntervalSince(start)
        
        let messagesPerSecond = Double(iterations) / duration
        print("📊 Baseline Throughput: \(String(format: "%.0f", messagesPerSecond)) messages/second")
        
        // Target: >10,000 messages/second
        // Note: This is a baseline test, actual throughput depends on hardware
        XCTAssertGreaterThan(messagesPerSecond, 100, "Parser throughput should be >100 msg/s")
    }
    
    func testLargeMessagePerformance() throws {
        let largeMessage = generateLargeMessage(segmentCount: 200)
        let parser = HL7v2Parser()
        
        measure {
            _ = try? parser.parse(largeMessage)
        }
    }
    
    // MARK: - Lazy vs Eager Parsing
    
    func testEagerParsingPerformance() throws {
        let config = ParserConfiguration(strategy: .eager)
        let parser = HL7v2Parser(configuration: config)
        
        measure {
            for _ in 0..<100 {
                _ = try? parser.parse(sampleORUR01)
            }
        }
    }
    
    func testLazyParsingPerformance() throws {
        let config = ParserConfiguration(strategy: .lazy)
        let parser = HL7v2Parser(configuration: config)
        
        measure {
            for _ in 0..<100 {
                _ = try? parser.parse(sampleORUR01)
            }
        }
    }
    
    func testLazyVsEagerComparison() throws {
        let iterations = 500
        
        // Eager parsing
        let eagerConfig = ParserConfiguration(strategy: .eager)
        let eagerParser = HL7v2Parser(configuration: eagerConfig)
        let eagerStart = Date()
        for _ in 0..<iterations {
            _ = try eagerParser.parse(sampleORUR01)
        }
        let eagerDuration = Date().timeIntervalSince(eagerStart)
        
        // Lazy parsing
        let lazyConfig = ParserConfiguration(strategy: .lazy)
        let lazyParser = HL7v2Parser(configuration: lazyConfig)
        let lazyStart = Date()
        for _ in 0..<iterations {
            _ = try lazyParser.parse(sampleORUR01)
        }
        let lazyDuration = Date().timeIntervalSince(lazyStart)
        
        let eagerThroughput = Double(iterations) / eagerDuration
        let lazyThroughput = Double(iterations) / lazyDuration
        
        print("📊 Eager Parsing: \(String(format: "%.0f", eagerThroughput)) msg/s")
        print("📊 Lazy Parsing: \(String(format: "%.0f", lazyThroughput)) msg/s")
        print("📊 Performance Ratio: \(String(format: "%.2f", lazyThroughput / eagerThroughput))x")
    }
    
    // MARK: - Object Pooling Tests
    
    func testObjectPoolingEffectiveness() async throws {
        let pool = SegmentPool(maxPoolSize: 50)
        
        // Preallocate some objects
        await pool.preallocate(20)
        
        // Acquire and release objects multiple times to build reuse
        let iterations = 100
        var storages: [SegmentPool.SegmentStorage] = []
        
        for _ in 0..<iterations {
            let storage = await pool.acquire()
            storages.append(storage)
        }
        
        for storage in storages {
            await pool.release(storage)
        }
        
        // Now do another round to get reuse
        storages.removeAll()
        for _ in 0..<50 {
            let storage = await pool.acquire()
            storages.append(storage)
        }
        
        for storage in storages {
            await pool.release(storage)
        }
        
        let stats = await pool.statistics()
        print("📊 Pool Statistics:")
        print("   - Available: \(stats.availableCount)")
        print("   - Acquire: \(stats.acquireCount)")
        print("   - Reuse: \(stats.reuseCount)")
        print("   - Allocations: \(stats.allocationCount)")
        print("   - Reuse Rate: \(String(format: "%.1f%%", stats.reuseRate * 100))")
        
        // After preallocating 20 and doing 150 acquires, we should have good reuse
        XCTAssertGreaterThan(stats.reuseRate, 0.3, "Pool reuse rate should be >30%")
    }
    
    func testGlobalPoolsPerformance() async throws {
        // Clear pools before testing
        await GlobalPools.clearAll()
        
        // Preallocate
        await GlobalPools.preallocateAll(30)
        
        // Test segment pool
        let segmentStorage = await GlobalPools.segments.acquire()
        await GlobalPools.segments.release(segmentStorage)
        
        // Test field pool
        let fieldStorage = await GlobalPools.fields.acquire()
        await GlobalPools.fields.release(fieldStorage)
        
        // Test component pool
        let componentStorage = await GlobalPools.components.acquire()
        await GlobalPools.components.release(componentStorage)
        
        // Get combined statistics
        let stats = await GlobalPools.allStatistics()
        
        print("📊 Global Pools Statistics:")
        print("   Segments - Reuse Rate: \(String(format: "%.1f%%", stats.segments.reuseRate * 100))")
        print("   Fields - Reuse Rate: \(String(format: "%.1f%%", stats.fields.reuseRate * 100))")
        print("   Components - Reuse Rate: \(String(format: "%.1f%%", stats.components.reuseRate * 100))")
    }
    
    // MARK: - String Interning Tests
    
    func testStringInterningPerformance() async throws {
        let interner = StringInterner()
        let commonSegmentIDs = ["MSH", "PID", "PV1", "OBX", "OBR", "EVN", "ORC"]
        
        // Intern strings multiple times
        for _ in 0..<1000 {
            for id in commonSegmentIDs {
                _ = await interner.intern(id)
            }
        }
        
        let stats = await interner.statistics()
        print("📊 String Interning Statistics:")
        print("   - Interned Count: \(stats.internedCount)")
        print("   - Hit Count: \(stats.hitCount)")
        print("   - Miss Count: \(stats.missCount)")
        print("   - Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100))")
        
        XCTAssertEqual(stats.internedCount, commonSegmentIDs.count)
        XCTAssertGreaterThan(stats.hitRate, 0.95, "String interning hit rate should be >95%")
    }
    
    func testInternedSegmentIDLookup() throws {
        // Test that common segment IDs are interned
        XCTAssertTrue(InternedSegmentID.isCommon("MSH"))
        XCTAssertTrue(InternedSegmentID.isCommon("PID"))
        XCTAssertTrue(InternedSegmentID.isCommon("OBX"))
        XCTAssertFalse(InternedSegmentID.isCommon("ZZZ"))
        
        // Test interning performance
        measure {
            for _ in 0..<10000 {
                _ = InternedSegmentID.intern("MSH")
                _ = InternedSegmentID.intern("PID")
                _ = InternedSegmentID.intern("OBX")
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageSmallMessages() throws {
        let parser = HL7v2Parser()
        let beforeMemory = MemoryUsage.current()
        
        // Parse many small messages
        for i in 0..<1000 {
            let message = sampleADTA01.replacingOccurrences(of: "MSG00001", with: "MSG\(String(format: "%05d", i))")
            _ = try parser.parse(message)
        }
        
        let afterMemory = MemoryUsage.current()
        
        if let before = beforeMemory, let after = afterMemory {
            let memoryIncrease = after.resident - before.resident
            let mbIncrease = Double(memoryIncrease) / (1024 * 1024)
            print("📊 Memory Increase for 1000 messages: \(String(format: "%.2f", mbIncrease)) MB")
        }
    }
    
    func testMemoryUsageLargeMessages() throws {
        let parser = HL7v2Parser()
        let largeMessage = generateLargeMessage(segmentCount: 500)
        let beforeMemory = MemoryUsage.current()
        
        // Parse fewer but larger messages
        for _ in 0..<100 {
            _ = try parser.parse(largeMessage)
        }
        
        let afterMemory = MemoryUsage.current()
        
        if let before = beforeMemory, let after = afterMemory {
            let memoryIncrease = after.resident - before.resident
            let mbIncrease = Double(memoryIncrease) / (1024 * 1024)
            print("📊 Memory Increase for 100 large messages: \(String(format: "%.2f", mbIncrease)) MB")
        }
    }
    
    // MARK: - Throughput Tests with Real Messages
    
    func testRealWorldThroughput() throws {
        let parser = HL7v2Parser()
        let messages = [sampleADTA01, sampleORUR01, generateLargeMessage(segmentCount: 50)]
        let iterations = 500
        
        var parsedCount = 0
        let start = Date()
        
        for _ in 0..<iterations {
            for message in messages {
                _ = try parser.parse(message)
                parsedCount += 1
            }
        }
        
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(parsedCount) / duration
        
        print("📊 Real-World Throughput:")
        print("   - Messages Parsed: \(parsedCount)")
        print("   - Duration: \(String(format: "%.2f", duration))s")
        print("   - Throughput: \(String(format: "%.0f", throughput)) msg/s")
        
        XCTAssertGreaterThan(throughput, 100, "Real-world throughput should be >100 msg/s")
    }
    
    func testConcurrentParsingThroughput() async throws {
        let iterations = 100
        let message = sampleADTA01  // Capture in local variable
        
        let start = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let parser = HL7v2Parser()  // Create parser in task
                    for _ in 0..<iterations {
                        _ = try? parser.parse(message)
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(start)
        let totalMessages = 10 * iterations
        let throughput = Double(totalMessages) / duration
        
        print("📊 Concurrent Parsing Throughput:")
        print("   - Total Messages: \(totalMessages)")
        print("   - Duration: \(String(format: "%.2f", duration))s")
        print("   - Throughput: \(String(format: "%.0f", throughput)) msg/s")
        
        XCTAssertGreaterThan(throughput, 100, "Concurrent throughput should be >100 msg/s")
    }
    
    // MARK: - Parser Configuration Impact
    
    func testStrictModePerformanceImpact() throws {
        let iterations = 500
        
        // Non-strict mode
        let normalConfig = ParserConfiguration(strictMode: false)
        let normalParser = HL7v2Parser(configuration: normalConfig)
        let normalStart = Date()
        for _ in 0..<iterations {
            _ = try normalParser.parse(sampleADTA01)
        }
        let normalDuration = Date().timeIntervalSince(normalStart)
        
        // Strict mode
        let strictConfig = ParserConfiguration(strictMode: true)
        let strictParser = HL7v2Parser(configuration: strictConfig)
        let strictStart = Date()
        for _ in 0..<iterations {
            _ = try strictParser.parse(sampleADTA01)
        }
        let strictDuration = Date().timeIntervalSince(strictStart)
        
        let normalThroughput = Double(iterations) / normalDuration
        let strictThroughput = Double(iterations) / strictDuration
        
        print("📊 Strict Mode Performance Impact:")
        print("   - Normal Mode: \(String(format: "%.0f", normalThroughput)) msg/s")
        print("   - Strict Mode: \(String(format: "%.0f", strictThroughput)) msg/s")
        print("   - Overhead: \(String(format: "%.1f%%", (normalDuration / strictDuration - 1.0) * 100))")
    }
    
    // MARK: - Benchmarking Framework Integration
    
    func testBenchmarkingFramework() async throws {
        let runner = BenchmarkRunner()
        let parser = HL7v2Parser()
        let message = sampleADTA01  // Capture in local variable
        
        let result = try await runner.run(
            name: "ADT^A01 Parsing",
            config: BenchmarkConfig(
                warmupIterations: 10,
                measuredIterations: 100
            )
        ) {
            _ = try parser.parse(message)
        }
        
        print("📊 Benchmark Results for \(result.name):")
        for metric in result.metrics {
            print("   - \(metric.name): \(String(format: "%.6f", metric.value)) \(metric.unit)")
        }
        
        // Find throughput metric
        let throughputMetric = result.metrics.first { $0.name == "Throughput" }
        XCTAssertNotNil(throughputMetric, "Benchmark should include throughput metric")
    }
}
