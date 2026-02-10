/// FHIRPerformanceTests.swift
/// Tests for FHIR performance optimization utilities

import XCTest
@testable import FHIRkit
@testable import HL7Core
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Mock URL Session

/// Minimal mock session for connection pool tests
private final class MockPoolSession: FHIRURLSession, @unchecked Sendable {
    let responseData: Data
    let statusCode: Int

    init(responseData: Data = Data("{\"resourceType\":\"Patient\"}".utf8), statusCode: Int = 200) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (responseData, response)
    }
}

// MARK: - Test Helpers

private let samplePatientJSON = """
{
    "resourceType": "Patient",
    "id": "test-1",
    "name": [{"family": "Smith", "given": ["John"]}],
    "gender": "male",
    "birthDate": "1990-01-01"
}
""".data(using: .utf8)!

private let sampleBundleJSON = """
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 3,
    "entry": [
        {"resource": {"resourceType": "Patient", "id": "p1"}},
        {"resource": {"resourceType": "Patient", "id": "p2"}},
        {"resource": {"resourceType": "Patient", "id": "p3"}}
    ]
}
""".data(using: .utf8)!

private let sampleXML = """
<?xml version="1.0" encoding="UTF-8"?>
<Patient xmlns="http://hl7.org/fhir">
  <id value="xml-1"/>
  <gender value="female"/>
</Patient>
""".data(using: .utf8)!

// MARK: - Tests

final class FHIRPerformanceTests: XCTestCase {

    // MARK: - Optimized JSON Parser Tests

    func testJSONParseResource() throws {
        let parser = OptimizedJSONParser()
        let dict = try parser.parseResource(from: samplePatientJSON)
        XCTAssertEqual(dict["resourceType"] as? String, "Patient")
        XCTAssertEqual(dict["id"] as? String, "test-1")
        XCTAssertEqual(dict["gender"] as? String, "male")
    }

    func testJSONParseResourceInvalidData() {
        let parser = OptimizedJSONParser()
        let badData = Data("not json".utf8)
        XCTAssertThrowsError(try parser.parseResource(from: badData))
    }

    func testJSONParseResourceArrayRoot() {
        let parser = OptimizedJSONParser()
        let arrayData = Data("[1,2,3]".utf8)
        XCTAssertThrowsError(try parser.parseResource(from: arrayData))
    }

    func testJSONParseBundleAllEntries() throws {
        let parser = OptimizedJSONParser()
        let entries = try parser.parseBundle(from: sampleBundleJSON)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0]["id"] as? String, "p1")
        XCTAssertEqual(entries[2]["id"] as? String, "p3")
    }

    func testJSONParseBundleMaxEntries() throws {
        let parser = OptimizedJSONParser()
        let entries = try parser.parseBundle(from: sampleBundleJSON, maxEntries: 2)
        XCTAssertEqual(entries.count, 2)
    }

    func testJSONParseBundleNoEntries() throws {
        let parser = OptimizedJSONParser()
        let noEntries = Data("{\"resourceType\":\"Bundle\"}".utf8)
        let entries = try parser.parseBundle(from: noEntries)
        XCTAssertTrue(entries.isEmpty)
    }

    func testJSONBenchmark() {
        let parser = OptimizedJSONParser()
        let stats = parser.benchmark(data: samplePatientJSON, iterations: 10)
        XCTAssertEqual(stats.bytesProcessed, samplePatientJSON.count * 10)
        XCTAssertEqual(stats.resourceCount, 10)
        XCTAssertGreaterThan(stats.parseTime, 0)
    }

    // MARK: - Optimized XML Parser Tests

    func testXMLParseResource() throws {
        let parser = OptimizedXMLParser()
        let node = try parser.parseResource(from: sampleXML)
        XCTAssertEqual(node.name, "Patient")
        XCTAssertFalse(node.children.isEmpty)
    }

    func testXMLParseResourceInvalid() {
        let parser = OptimizedXMLParser()
        let badData = Data("<<< invalid >>>".utf8)
        XCTAssertThrowsError(try parser.parseResource(from: badData))
    }

    func testXMLBenchmark() {
        let parser = OptimizedXMLParser()
        let stats = parser.benchmark(data: sampleXML, iterations: 5)
        XCTAssertEqual(stats.bytesProcessed, sampleXML.count * 5)
        XCTAssertEqual(stats.resourceCount, 5)
    }

    func testXMLResourceNodeEquality() {
        let a = XMLResourceNode(name: "Patient", attributes: ["xmlns": "http://hl7.org/fhir"], children: [], text: nil)
        let b = XMLResourceNode(name: "Patient", attributes: ["xmlns": "http://hl7.org/fhir"], children: [], text: nil)
        XCTAssertEqual(a, b)
    }

    // MARK: - Cache Tests

    func testCachePutAndGet() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 60)
        let data = Data("hello".utf8)
        await cache.put(resourceType: "Patient", id: "1", data: data)
        let result = await cache.get(resourceType: "Patient", id: "1")
        XCTAssertEqual(result, data)
    }

    func testCacheMiss() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 60)
        let result = await cache.get(resourceType: "Patient", id: "missing")
        XCTAssertNil(result)
    }

    func testCacheInvalidate() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 60)
        await cache.put(resourceType: "Patient", id: "1", data: Data("x".utf8))
        await cache.invalidate(resourceType: "Patient", id: "1")
        let result = await cache.get(resourceType: "Patient", id: "1")
        XCTAssertNil(result)
    }

    func testCacheInvalidateAllByType() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 60)
        await cache.put(resourceType: "Patient", id: "1", data: Data("a".utf8))
        await cache.put(resourceType: "Patient", id: "2", data: Data("b".utf8))
        await cache.put(resourceType: "Observation", id: "1", data: Data("c".utf8))
        await cache.invalidateAll(resourceType: "Patient")

        let p1 = await cache.get(resourceType: "Patient", id: "1")
        let p2 = await cache.get(resourceType: "Patient", id: "2")
        let o1 = await cache.get(resourceType: "Observation", id: "1")
        XCTAssertNil(p1)
        XCTAssertNil(p2)
        XCTAssertNotNil(o1)
    }

    func testCacheClear() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 60)
        await cache.put(resourceType: "Patient", id: "1", data: Data("a".utf8))
        await cache.clear()
        let stats = await cache.statistics()
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
    }

    func testCacheLRUEviction() async {
        let cache = FHIRResourceCache(maxSize: 2, ttl: 60)
        await cache.put(resourceType: "Patient", id: "1", data: Data("a".utf8))
        await cache.put(resourceType: "Patient", id: "2", data: Data("b".utf8))
        // Access id:2 to make id:1 the LRU
        _ = await cache.get(resourceType: "Patient", id: "2")
        // Adding a third should evict id:1
        await cache.put(resourceType: "Patient", id: "3", data: Data("c".utf8))

        let r1 = await cache.get(resourceType: "Patient", id: "1")
        let r2 = await cache.get(resourceType: "Patient", id: "2")
        let r3 = await cache.get(resourceType: "Patient", id: "3")
        XCTAssertNil(r1)
        XCTAssertNotNil(r2)
        XCTAssertNotNil(r3)

        let stats = await cache.statistics()
        XCTAssertEqual(stats.evictions, 1)
    }

    func testCacheTTLExpiration() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 0.01)
        await cache.put(resourceType: "Patient", id: "1", data: Data("a".utf8))
        // Wait for TTL to expire
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        let result = await cache.get(resourceType: "Patient", id: "1")
        XCTAssertNil(result)
    }

    func testCacheStatistics() async {
        let cache = FHIRResourceCache(maxSize: 10, ttl: 60)
        await cache.put(resourceType: "Patient", id: "1", data: Data("data".utf8))
        _ = await cache.get(resourceType: "Patient", id: "1")
        _ = await cache.get(resourceType: "Patient", id: "missing")

        let stats = await cache.statistics()
        XCTAssertEqual(stats.totalEntries, 1)
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 1)
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(stats.memoryUsage, 0)
    }

    // MARK: - Streaming Bundle Processor Tests

    func testStreamingBundleProcessEntries() async throws {
        let processor = StreamingBundleProcessor()
        final class IDCollector: @unchecked Sendable {
            var ids: [String] = []
        }
        let collector = IDCollector()
        let stats = try await processor.processBundle(data: sampleBundleJSON) { entry in
            if let id = entry["id"] as? String {
                collector.ids.append(id)
            }
        }
        XCTAssertEqual(collector.ids, ["p1", "p2", "p3"])
        XCTAssertEqual(stats.totalEntries, 3)
        XCTAssertEqual(stats.processedEntries, 3)
        XCTAssertEqual(stats.bytesProcessed, sampleBundleJSON.count)
        XCTAssertGreaterThan(stats.processingTime, 0)
    }

    func testStreamingBundleCountEntries() async throws {
        let processor = StreamingBundleProcessor()
        let count = try await processor.countEntries(data: sampleBundleJSON)
        XCTAssertEqual(count, 3)
    }

    func testStreamingBundleInvalidData() async {
        let processor = StreamingBundleProcessor()
        do {
            try await processor.processBundle(data: Data("bad".utf8)) { _ in }
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }
    }

    // MARK: - Memory Pressure Monitor Tests

    func testMemoryUsage() {
        let usage = MemoryPressureMonitor.currentMemoryUsage()
        // On Linux CI this may return 0 depending on mach availability
        XCTAssertGreaterThanOrEqual(usage, 0)
    }

    func testPeakMemoryUsage() {
        let peak = MemoryPressureMonitor.peakMemoryUsage()
        XCTAssertGreaterThanOrEqual(peak, 0)
    }

    func testShouldReduceMemory() {
        let monitor = MemoryPressureMonitor()
        // With a 0 threshold, should always be true (unless memory returns 0)
        let result = monitor.shouldReduceMemory(threshold: 0)
        XCTAssertTrue(result || MemoryPressureMonitor.currentMemoryUsage() == 0)
    }

    func testFormatBytes() {
        XCTAssertEqual(MemoryPressureMonitor.formatBytes(0), "0 B")
        XCTAssertEqual(MemoryPressureMonitor.formatBytes(512), "512 B")
        XCTAssertEqual(MemoryPressureMonitor.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(MemoryPressureMonitor.formatBytes(1_048_576), "1.0 MB")
        XCTAssertEqual(MemoryPressureMonitor.formatBytes(1_073_741_824), "1.0 GB")
    }

    // MARK: - Connection Pool Tests

    func testPoolAcquireAndRelease() async throws {
        let pool = ConnectionPool(
            configuration: PoolConfiguration(maxConnections: 2),
            sessionFactory: { MockPoolSession() }
        )
        let conn = try await pool.acquire()
        XCTAssertFalse(conn.id.isEmpty)
        await pool.release(conn)

        let stats = await pool.statistics()
        XCTAssertEqual(stats.totalConnections, 1)
        XCTAssertEqual(stats.activeConnections, 0)
        XCTAssertEqual(stats.availableConnections, 1)
    }

    func testPoolExhausted() async throws {
        let pool = ConnectionPool(
            configuration: PoolConfiguration(maxConnections: 1),
            sessionFactory: { MockPoolSession() }
        )
        let conn = try await pool.acquire()
        do {
            _ = try await pool.acquire()
            XCTFail("Should have thrown poolExhausted")
        } catch let error as FHIRPerformanceError {
            if case .poolExhausted = error {
                // expected
            } else {
                XCTFail("Wrong error type")
            }
        }
        await pool.release(conn)
    }

    func testPoolExecute() async throws {
        let pool = ConnectionPool(
            configuration: PoolConfiguration(maxConnections: 2),
            sessionFactory: { MockPoolSession() }
        )
        let url = URL(string: "https://fhir.example.com/Patient/1")!
        let request = URLRequest(url: url)
        let (data, response) = try await pool.execute(request: request)
        XCTAssertFalse(data.isEmpty)
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)

        let stats = await pool.statistics()
        XCTAssertEqual(stats.totalRequests, 1)
    }

    func testPoolDrain() async throws {
        let pool = ConnectionPool(
            configuration: PoolConfiguration(maxConnections: 5),
            sessionFactory: { MockPoolSession() }
        )
        let conn = try await pool.acquire()
        await pool.release(conn)
        await pool.drain()

        let stats = await pool.statistics()
        XCTAssertEqual(stats.activeConnections, 0)
        XCTAssertEqual(stats.availableConnections, 0)
    }

    func testPoolStatistics() async throws {
        let pool = ConnectionPool(
            configuration: PoolConfiguration(maxConnections: 3),
            sessionFactory: { MockPoolSession() }
        )
        let c1 = try await pool.acquire()
        _ = try await pool.acquire()
        await pool.release(c1)

        let stats = await pool.statistics()
        XCTAssertEqual(stats.totalConnections, 2)
        XCTAssertEqual(stats.activeConnections, 1)
        XCTAssertEqual(stats.availableConnections, 1)
        XCTAssertGreaterThanOrEqual(stats.averageWaitTime, 0)
    }

    // MARK: - Benchmark Tests

    func testBenchmarkMeasure() async throws {
        let bm = FHIRBenchmark()
        let result = try await bm.measure(label: "noop", iterations: 5) { }
        XCTAssertEqual(result.label, "noop")
        XCTAssertEqual(result.iterations, 5)
        XCTAssertGreaterThanOrEqual(result.totalTime, 0)
        XCTAssertGreaterThanOrEqual(result.averageTime, 0)
        XCTAssertGreaterThanOrEqual(result.operationsPerSecond, 0)
    }

    func testBenchmarkCompare() async throws {
        let bm = FHIRBenchmark()
        let slow = BenchmarkResult(label: "slow", iterations: 10, totalTime: 1.0, averageTime: 0.1, minTime: 0.08, maxTime: 0.12, standardDeviation: 0.01, operationsPerSecond: 10)
        let fast = BenchmarkResult(label: "fast", iterations: 10, totalTime: 0.5, averageTime: 0.05, minTime: 0.04, maxTime: 0.06, standardDeviation: 0.005, operationsPerSecond: 20)
        let comparison = bm.compare(baseline: slow, current: fast)
        XCTAssertTrue(comparison.isImproved)
        XCTAssertGreaterThan(comparison.speedup, 1.0)
        XCTAssertGreaterThan(comparison.improvementPercentage, 0)
    }

    // MARK: - Performance Profile Tests

    func testProfileJSONParsing() async {
        let profile = FHIRPerformanceProfile()
        let result = await profile.profileJSONParsing(sampleData: samplePatientJSON, iterations: 3)
        XCTAssertEqual(result.label, "JSON Parsing")
        XCTAssertEqual(result.iterations, 3)
    }

    func testProfileGenerateReport() {
        let profile = FHIRPerformanceProfile()
        let result = BenchmarkResult(label: "Test", iterations: 10, totalTime: 1.0, averageTime: 0.1, minTime: 0.05, maxTime: 0.15, standardDeviation: 0.02, operationsPerSecond: 10)
        let report = profile.generateReport(results: [result])
        XCTAssertTrue(report.contains("Test"))
        XCTAssertTrue(report.contains("Iterations: 10"))
    }

    // MARK: - Performance Metrics Tests

    func testRecordAndRetrieveMetrics() async {
        let metrics = FHIRPerformanceMetrics()
        await metrics.recordOperation(name: "parse", duration: 0.01, bytesProcessed: 1024)
        await metrics.recordOperation(name: "parse", duration: 0.02, bytesProcessed: 2048)

        let m = await metrics.getMetrics(for: "parse")
        XCTAssertEqual(m.name, "parse")
        XCTAssertEqual(m.count, 2)
        XCTAssertEqual(m.totalBytes, 3072)
        XCTAssertEqual(m.minTime, 0.01, accuracy: 0.001)
        XCTAssertEqual(m.maxTime, 0.02, accuracy: 0.001)
        XCTAssertGreaterThan(m.throughput, 0)
    }

    func testAllMetrics() async {
        let metrics = FHIRPerformanceMetrics()
        await metrics.recordOperation(name: "read", duration: 0.005)
        await metrics.recordOperation(name: "write", duration: 0.01)
        let all = await metrics.allMetrics()
        XCTAssertEqual(all.count, 2)
        XCTAssertNotNil(all["read"])
        XCTAssertNotNil(all["write"])
    }

    func testMetricsReset() async {
        let metrics = FHIRPerformanceMetrics()
        await metrics.recordOperation(name: "op", duration: 0.1)
        await metrics.reset()
        let all = await metrics.allMetrics()
        XCTAssertTrue(all.isEmpty)
    }

    func testMetricsMissingOperation() async {
        let metrics = FHIRPerformanceMetrics()
        let m = await metrics.getMetrics(for: "nonexistent")
        XCTAssertEqual(m.count, 0)
        XCTAssertEqual(m.totalTime, 0)
    }

    // MARK: - Configuration & Policy Tests

    func testCachePolicyEquality() {
        XCTAssertEqual(CachePolicy.cacheFirst, CachePolicy.cacheFirst)
        XCTAssertNotEqual(CachePolicy.noCache, CachePolicy.cacheOnly)
    }

    func testCacheConfigurationDefaults() {
        let config = CacheConfiguration()
        XCTAssertEqual(config.maxEntries, 1000)
        XCTAssertEqual(config.ttlSeconds, 300)
        XCTAssertEqual(config.policy, .cacheFirst)
        XCTAssertEqual(config.maxMemoryBytes, 50 * 1024 * 1024)
    }

    func testPoolConfigurationDefaults() {
        let config = PoolConfiguration()
        XCTAssertEqual(config.maxConnections, 10)
        XCTAssertEqual(config.connectionTTL, 300)
        XCTAssertEqual(config.acquireTimeout, 30)
        XCTAssertEqual(config.maxRequestsPerConnection, 1000)
    }

    func testParserStatisticsEquality() {
        let a = ParserStatistics(bytesProcessed: 100, parseTime: 0.5, resourceCount: 1)
        let b = ParserStatistics(bytesProcessed: 100, parseTime: 0.5, resourceCount: 1)
        XCTAssertEqual(a, b)
    }

    func testFHIRPerformanceErrorEquality() {
        XCTAssertEqual(
            FHIRPerformanceError.invalidFormat("x"),
            FHIRPerformanceError.invalidFormat("x")
        )
        XCTAssertNotEqual(
            FHIRPerformanceError.invalidFormat("x"),
            FHIRPerformanceError.poolExhausted("x")
        )
    }
}
