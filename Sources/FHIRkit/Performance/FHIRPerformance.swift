/// FHIRPerformance.swift
/// Performance optimization utilities for FHIR operations
///
/// This file provides JSON/XML parsing optimization, resource caching,
/// memory management, connection pooling, benchmarking, and performance
/// metrics for FHIR R4 workflows.

import Foundation
import HL7Core

#if canImport(FoundationXML)
import FoundationXML
#endif

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Parser Statistics

/// Statistics collected during a parsing operation
public struct ParserStatistics: Sendable, Codable, Equatable {
    /// Total bytes processed
    public let bytesProcessed: Int

    /// Time taken to parse in seconds
    public let parseTime: TimeInterval

    /// Number of resources parsed
    public let resourceCount: Int

    public init(bytesProcessed: Int, parseTime: TimeInterval, resourceCount: Int) {
        self.bytesProcessed = bytesProcessed
        self.parseTime = parseTime
        self.resourceCount = resourceCount
    }
}

// MARK: - Optimized JSON Parser

/// High-performance JSON parser using JSONSerialization for fast FHIR resource parsing
public struct OptimizedJSONParser: Sendable {

    public init() {}

    /// Parse a FHIR resource from raw JSON data
    ///
    /// Uses `JSONSerialization` with fragment reading for maximum speed.
    ///
    /// - Parameter data: Raw JSON bytes
    /// - Returns: Parsed dictionary representation
    /// - Throws: If the data is not valid JSON or not a JSON object
    public func parseResource(from data: Data) throws -> [String: Any] {
        let options: JSONSerialization.ReadingOptions = [.fragmentsAllowed]
        let object = try JSONSerialization.jsonObject(with: data, options: options)
        guard let dict = object as? [String: Any] else {
            throw FHIRPerformanceError.invalidFormat("Expected JSON object at root")
        }
        return dict
    }

    /// Parse a FHIR Bundle extracting up to `maxEntries` entries
    ///
    /// - Parameters:
    ///   - data: Raw JSON bytes of a Bundle resource
    ///   - maxEntries: Maximum number of entries to return (default unlimited)
    /// - Returns: Array of entry resource dictionaries
    /// - Throws: If the data cannot be parsed or is not a Bundle
    public func parseBundle(from data: Data, maxEntries: Int = .max) throws -> [[String: Any]] {
        let root = try parseResource(from: data)
        guard let entries = root["entry"] as? [[String: Any]] else {
            return []
        }
        let limit = min(maxEntries, entries.count)
        var results: [[String: Any]] = []
        results.reserveCapacity(limit)
        for i in 0..<limit {
            if let resource = entries[i]["resource"] as? [String: Any] {
                results.append(resource)
            }
        }
        return results
    }

    /// Benchmark JSON parsing over multiple iterations
    ///
    /// - Parameters:
    ///   - data: JSON data to parse repeatedly
    ///   - iterations: Number of iterations to run
    /// - Returns: Aggregated parser statistics
    public func benchmark(data: Data, iterations: Int) -> ParserStatistics {
        let start = Date().timeIntervalSinceReferenceDate
        var resourceCount = 0
        for _ in 0..<iterations {
            if let dict = try? parseResource(from: data) {
                resourceCount += dict.isEmpty ? 0 : 1
            }
        }
        let elapsed = Date().timeIntervalSinceReferenceDate - start
        return ParserStatistics(
            bytesProcessed: data.count * iterations,
            parseTime: elapsed,
            resourceCount: resourceCount
        )
    }
}

// MARK: - XML Resource Node

/// Lightweight node representation for parsed XML resources
public struct XMLResourceNode: Sendable, Equatable {
    /// Element name
    public let name: String

    /// Element attributes
    public let attributes: [String: String]

    /// Child nodes
    public let children: [XMLResourceNode]

    /// Text content
    public let text: String?

    public init(name: String, attributes: [String: String] = [:], children: [XMLResourceNode] = [], text: String? = nil) {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.text = text
    }
}

// MARK: - Optimized XML Parser

/// High-performance XML parser producing lightweight XMLResourceNode trees
public struct OptimizedXMLParser: Sendable {

    public init() {}

    /// Parse a FHIR resource from XML data into a node tree
    ///
    /// - Parameter data: Raw XML bytes
    /// - Returns: Root XMLResourceNode
    /// - Throws: If the XML is malformed
    public func parseResource(from data: Data) throws -> XMLResourceNode {
        let parser = XMLParser(data: data)
        let delegate = XMLNodeBuilderDelegate()
        parser.delegate = delegate
        guard parser.parse(), let root = delegate.rootNode else {
            throw FHIRPerformanceError.invalidFormat(
                parser.parserError?.localizedDescription ?? "XML parsing failed"
            )
        }
        return root
    }

    /// Benchmark XML parsing over multiple iterations
    ///
    /// - Parameters:
    ///   - data: XML data to parse repeatedly
    ///   - iterations: Number of iterations to run
    /// - Returns: Aggregated parser statistics
    public func benchmark(data: Data, iterations: Int) -> ParserStatistics {
        let start = Date().timeIntervalSinceReferenceDate
        var resourceCount = 0
        for _ in 0..<iterations {
            if let _ = try? parseResource(from: data) {
                resourceCount += 1
            }
        }
        let elapsed = Date().timeIntervalSinceReferenceDate - start
        return ParserStatistics(
            bytesProcessed: data.count * iterations,
            parseTime: elapsed,
            resourceCount: resourceCount
        )
    }
}

// MARK: - XML Node Builder Delegate

/// Internal delegate that builds an XMLResourceNode tree during SAX parsing
private final class XMLNodeBuilderDelegate: NSObject, XMLParserDelegate {
    var rootNode: XMLResourceNode?

    private var stack: [(name: String, attributes: [String: String], children: [XMLResourceNode], text: String)] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        stack.append((name: elementName, attributes: attributes, children: [], text: ""))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard let current = stack.popLast() else { return }
        let trimmedText = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let node = XMLResourceNode(
            name: current.name,
            attributes: current.attributes,
            children: current.children,
            text: trimmedText.isEmpty ? nil : trimmedText
        )
        if stack.isEmpty {
            rootNode = node
        } else {
            stack[stack.count - 1].children.append(node)
        }
    }
}

// MARK: - Cache Policy

/// Caching strategy for FHIR resources
public enum CachePolicy: Sendable, Codable, Equatable {
    /// Never cache — always fetch from network
    case noCache
    /// Return cached data first, then revalidate
    case cacheFirst
    /// Fetch from network first, fall back to cache
    case networkFirst
    /// Only return cached data, never fetch
    case cacheOnly
    /// Return stale cache immediately while revalidating in the background
    case staleWhileRevalidate
}

// MARK: - Cache Configuration

/// Configuration for a FHIR resource cache
public struct CacheConfiguration: Sendable, Codable, Equatable {
    /// Maximum number of entries the cache may hold
    public let maxEntries: Int

    /// Time-to-live for each entry in seconds
    public let ttlSeconds: TimeInterval

    /// Caching policy
    public let policy: CachePolicy

    /// Maximum total memory in bytes the cache may use
    public let maxMemoryBytes: Int

    public init(
        maxEntries: Int = 1000,
        ttlSeconds: TimeInterval = 300,
        policy: CachePolicy = .cacheFirst,
        maxMemoryBytes: Int = 50 * 1024 * 1024
    ) {
        self.maxEntries = maxEntries
        self.ttlSeconds = ttlSeconds
        self.policy = policy
        self.maxMemoryBytes = maxMemoryBytes
    }
}

// MARK: - Cache Statistics

/// Runtime statistics for a FHIR resource cache
public struct CacheStatistics: Sendable, Codable, Equatable {
    /// Number of entries currently in the cache
    public let totalEntries: Int

    /// Total cache hits since creation
    public let hits: Int

    /// Total cache misses since creation
    public let misses: Int

    /// Hit rate as a fraction (0.0–1.0)
    public let hitRate: Double

    /// Approximate memory usage in bytes
    public let memoryUsage: Int

    /// Number of evictions performed
    public let evictions: Int

    public init(totalEntries: Int, hits: Int, misses: Int, hitRate: Double, memoryUsage: Int, evictions: Int) {
        self.totalEntries = totalEntries
        self.hits = hits
        self.misses = misses
        self.hitRate = hitRate
        self.memoryUsage = memoryUsage
        self.evictions = evictions
    }
}

// MARK: - FHIR Resource Cache

/// Thread-safe LRU cache for FHIR resource data with TTL-based expiration
public actor FHIRResourceCache {

    /// Maximum number of cached entries
    public let maxSize: Int

    /// Time-to-live for entries in seconds
    public let ttl: TimeInterval

    /// Internal cache entry
    private struct CacheEntry: Sendable {
        let data: Data
        let timestamp: Date
        var accessCount: Int
        var lastAccess: Date
        let etag: String?
        let resourceType: String
    }

    private var entries: [String: CacheEntry] = [:]
    private var hits: Int = 0
    private var misses: Int = 0
    private var evictions: Int = 0

    public init(maxSize: Int = 1000, ttl: TimeInterval = 300) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    // MARK: - Cache Operations

    /// Retrieve cached data for a resource
    ///
    /// Returns `nil` if the entry is missing or expired.
    ///
    /// - Parameters:
    ///   - resourceType: FHIR resource type (e.g. "Patient")
    ///   - id: Resource logical id
    /// - Returns: Cached data or nil
    public func get(resourceType: String, id: String) async -> Data? {
        let key = cacheKey(resourceType: resourceType, id: id)
        guard var entry = entries[key] else {
            misses += 1
            return nil
        }
        // TTL check
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            entries.removeValue(forKey: key)
            misses += 1
            return nil
        }
        entry.accessCount += 1
        entry.lastAccess = Date()
        entries[key] = entry
        hits += 1
        return entry.data
    }

    /// Store resource data in the cache
    ///
    /// If the cache is full, the least-recently-used entry is evicted.
    ///
    /// - Parameters:
    ///   - resourceType: FHIR resource type
    ///   - id: Resource logical id
    ///   - data: Serialized resource bytes
    ///   - etag: Optional ETag for conditional requests
    public func put(resourceType: String, id: String, data: Data, etag: String? = nil) async {
        let key = cacheKey(resourceType: resourceType, id: id)
        if entries.count >= maxSize && entries[key] == nil {
            evictLRU()
        }
        entries[key] = CacheEntry(
            data: data,
            timestamp: Date(),
            accessCount: 0,
            lastAccess: Date(),
            etag: etag,
            resourceType: resourceType
        )
    }

    /// Remove a single entry from the cache
    public func invalidate(resourceType: String, id: String) async {
        let key = cacheKey(resourceType: resourceType, id: id)
        entries.removeValue(forKey: key)
    }

    /// Remove all entries for a given resource type
    public func invalidateAll(resourceType: String) async {
        entries = entries.filter { $0.value.resourceType != resourceType }
    }

    /// Remove all entries from the cache
    public func clear() async {
        entries.removeAll()
        hits = 0
        misses = 0
        evictions = 0
    }

    /// Return current cache statistics
    public func statistics() async -> CacheStatistics {
        let total = hits + misses
        let rate = total > 0 ? Double(hits) / Double(total) : 0.0
        let memUsage = entries.values.reduce(0) { $0 + $1.data.count }
        return CacheStatistics(
            totalEntries: entries.count,
            hits: hits,
            misses: misses,
            hitRate: rate,
            memoryUsage: memUsage,
            evictions: evictions
        )
    }

    // MARK: - Private Helpers

    private func cacheKey(resourceType: String, id: String) -> String {
        "\(resourceType)/\(id)"
    }

    private func evictLRU() {
        guard let lruKey = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else {
            return
        }
        entries.removeValue(forKey: lruKey)
        evictions += 1
    }
}

// MARK: - Bundle Processing Stats

/// Statistics for streaming bundle processing
public struct BundleProcessingStats: Sendable, Codable, Equatable {
    /// Total entries in the bundle
    public let totalEntries: Int

    /// Entries successfully processed
    public let processedEntries: Int

    /// Total bytes of the raw bundle
    public let bytesProcessed: Int

    /// Peak memory estimate during processing in bytes
    public let peakMemory: Int

    /// Wall-clock processing time in seconds
    public let processingTime: TimeInterval

    public init(totalEntries: Int, processedEntries: Int, bytesProcessed: Int, peakMemory: Int, processingTime: TimeInterval) {
        self.totalEntries = totalEntries
        self.processedEntries = processedEntries
        self.bytesProcessed = bytesProcessed
        self.peakMemory = peakMemory
        self.processingTime = processingTime
    }
}

// MARK: - Streaming Bundle Processor

/// Processes large FHIR Bundles entry-by-entry to limit peak memory
public actor StreamingBundleProcessor {

    public init() {}

    /// Process each entry in a bundle by calling `handler` for every resource dictionary
    ///
    /// - Parameters:
    ///   - data: Raw JSON bundle data
    ///   - handler: Async closure invoked with each entry dictionary
    /// - Returns: Processing statistics
    @discardableResult
    public func processBundle(
        data: Data,
        handler: @Sendable ([String: Any]) async throws -> Void
    ) async throws -> BundleProcessingStats {
        let start = Date().timeIntervalSinceReferenceDate
        let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let dict = root as? [String: Any] else {
            throw FHIRPerformanceError.invalidFormat("Expected JSON object for Bundle")
        }
        let entries = (dict["entry"] as? [[String: Any]]) ?? []
        var processed = 0
        for entry in entries {
            if let resource = entry["resource"] as? [String: Any] {
                try await handler(resource)
                processed += 1
            }
        }
        let elapsed = Date().timeIntervalSinceReferenceDate - start
        return BundleProcessingStats(
            totalEntries: entries.count,
            processedEntries: processed,
            bytesProcessed: data.count,
            peakMemory: MemoryPressureMonitor.currentMemoryUsage(),
            processingTime: elapsed
        )
    }

    /// Count entries in a bundle without fully deserializing resources
    ///
    /// - Parameter data: Raw JSON bundle bytes
    /// - Returns: Number of entries found
    public func countEntries(data: Data) throws -> Int {
        let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let dict = root as? [String: Any] else {
            throw FHIRPerformanceError.invalidFormat("Expected JSON object for Bundle")
        }
        return (dict["entry"] as? [Any])?.count ?? 0
    }
}

// MARK: - Memory Pressure Monitor

/// Utility for querying process memory usage
public struct MemoryPressureMonitor: Sendable {

    public init() {}

    /// Approximate current resident memory in bytes
    public static func currentMemoryUsage() -> Int {
        #if os(Linux)
        // Read from /proc/self/statm on Linux (pages * page size)
        guard let data = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8) else {
            return 0
        }
        let parts = data.split(separator: " ")
        // Second field is resident set size in pages
        guard parts.count >= 2, let pages = Int(parts[1]) else { return 0 }
        return pages * 4096
        #else
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
        #endif
    }

    /// Peak (maximum) resident memory in bytes
    public static func peakMemoryUsage() -> Int {
        #if os(Linux)
        // Read VmHWM from /proc/self/status for peak RSS
        guard let data = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8) else {
            return 0
        }
        for line in data.split(separator: "\n") {
            if line.hasPrefix("VmHWM:") {
                let digits = line.filter { $0.isNumber }
                if let kb = Int(digits) { return kb * 1024 }
            }
        }
        return 0
        #else
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size_max) : 0
        #endif
    }

    /// Whether current memory exceeds the given threshold
    ///
    /// - Parameter threshold: Memory threshold in bytes
    /// - Returns: `true` when current usage exceeds the threshold
    public func shouldReduceMemory(threshold: Int) -> Bool {
        MemoryPressureMonitor.currentMemoryUsage() > threshold
    }

    /// Format a byte count into a human-readable string
    ///
    /// - Parameter bytes: Number of bytes
    /// - Returns: Formatted string (e.g. "1.5 MB")
    public static func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

// MARK: - Pool Configuration

/// Configuration for the connection pool
public struct PoolConfiguration: Sendable, Codable, Equatable {
    /// Maximum number of simultaneous connections
    public let maxConnections: Int

    /// Time-to-live for idle connections in seconds
    public let connectionTTL: TimeInterval

    /// Maximum time to wait for an available connection in seconds
    public let acquireTimeout: TimeInterval

    /// Maximum requests a single connection may serve before being recycled
    public let maxRequestsPerConnection: Int

    public init(
        maxConnections: Int = 10,
        connectionTTL: TimeInterval = 300,
        acquireTimeout: TimeInterval = 30,
        maxRequestsPerConnection: Int = 1000
    ) {
        self.maxConnections = maxConnections
        self.connectionTTL = connectionTTL
        self.acquireTimeout = acquireTimeout
        self.maxRequestsPerConnection = maxRequestsPerConnection
    }
}

// MARK: - Pooled Connection

/// A connection managed by `ConnectionPool`
public struct PooledConnection: Sendable {
    /// Unique connection identifier
    public let id: String

    /// The underlying URL session
    public let session: any FHIRURLSession

    /// Time the connection was created
    public let createdAt: Date

    /// Last time the connection was used
    public let lastUsed: Date

    /// Number of requests served by this connection
    public let requestCount: Int

    public init(id: String, session: any FHIRURLSession, createdAt: Date = Date(), lastUsed: Date = Date(), requestCount: Int = 0) {
        self.id = id
        self.session = session
        self.createdAt = createdAt
        self.lastUsed = lastUsed
        self.requestCount = requestCount
    }
}

// MARK: - Pool Statistics

/// Runtime statistics for the connection pool
public struct PoolStatistics: Sendable, Codable, Equatable {
    /// Total connections created since pool inception
    public let totalConnections: Int

    /// Currently in-use connections
    public let activeConnections: Int

    /// Idle connections available for reuse
    public let availableConnections: Int

    /// Total requests executed through the pool
    public let totalRequests: Int

    /// Average wait time to acquire a connection in seconds
    public let averageWaitTime: TimeInterval

    public init(totalConnections: Int, activeConnections: Int, availableConnections: Int, totalRequests: Int, averageWaitTime: TimeInterval) {
        self.totalConnections = totalConnections
        self.activeConnections = activeConnections
        self.availableConnections = availableConnections
        self.totalRequests = totalRequests
        self.averageWaitTime = averageWaitTime
    }
}

// MARK: - Connection Pool

/// Thread-safe connection pool for FHIR REST client sessions
public actor ConnectionPool {

    /// Pool configuration
    public let configuration: PoolConfiguration

    /// Factory creating new URL sessions
    private let sessionFactory: @Sendable () -> any FHIRURLSession

    private var available: [PooledConnection] = []
    private var active: [String: PooledConnection] = [:]
    private var totalCreated: Int = 0
    private var totalRequests: Int = 0
    private var totalWaitTime: TimeInterval = 0
    private var waitCount: Int = 0

    public init(
        configuration: PoolConfiguration = PoolConfiguration(),
        sessionFactory: @escaping @Sendable () -> any FHIRURLSession
    ) {
        self.configuration = configuration
        self.sessionFactory = sessionFactory
    }

    // MARK: - Pool Operations

    /// Acquire a connection from the pool
    ///
    /// Reuses an idle connection if available, otherwise creates a new one.
    ///
    /// - Returns: A pooled connection ready for use
    /// - Throws: `FHIRPerformanceError.poolExhausted` when the pool is at capacity
    public func acquire() async throws -> PooledConnection {
        let start = Date().timeIntervalSinceReferenceDate
        // Reuse idle connection
        if !available.isEmpty {
            var conn = available.removeLast()
            conn = PooledConnection(
                id: conn.id,
                session: conn.session,
                createdAt: conn.createdAt,
                lastUsed: Date(),
                requestCount: conn.requestCount
            )
            active[conn.id] = conn
            recordWait(since: start)
            return conn
        }
        // Create new connection if under limit
        let currentTotal = active.count + available.count
        guard currentTotal < configuration.maxConnections else {
            throw FHIRPerformanceError.poolExhausted(
                "Max connections (\(configuration.maxConnections)) reached"
            )
        }
        totalCreated += 1
        let conn = PooledConnection(
            id: UUID().uuidString,
            session: sessionFactory(),
            createdAt: Date(),
            lastUsed: Date(),
            requestCount: 0
        )
        active[conn.id] = conn
        recordWait(since: start)
        return conn
    }

    /// Return a connection to the pool for reuse
    ///
    /// - Parameter connection: The connection to release
    public func release(_ connection: PooledConnection) async {
        active.removeValue(forKey: connection.id)
        let updated = PooledConnection(
            id: connection.id,
            session: connection.session,
            createdAt: connection.createdAt,
            lastUsed: Date(),
            requestCount: connection.requestCount
        )
        available.append(updated)
    }

    /// Execute a request using a pooled connection
    ///
    /// Acquires a connection, performs the request, and releases it automatically.
    ///
    /// - Parameter request: The URL request to execute
    /// - Returns: Response data and URL response
    /// - Throws: Network or pool errors
    public func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        let conn = try await acquire()
        totalRequests += 1
        do {
            let result = try await conn.session.data(for: request)
            let updated = PooledConnection(
                id: conn.id,
                session: conn.session,
                createdAt: conn.createdAt,
                lastUsed: Date(),
                requestCount: conn.requestCount + 1
            )
            await release(updated)
            return result
        } catch {
            await release(conn)
            throw error
        }
    }

    /// Drain all connections from the pool
    public func drain() async {
        available.removeAll()
        active.removeAll()
    }

    /// Return current pool statistics
    public func statistics() async -> PoolStatistics {
        let avgWait = waitCount > 0 ? totalWaitTime / Double(waitCount) : 0
        return PoolStatistics(
            totalConnections: totalCreated,
            activeConnections: active.count,
            availableConnections: available.count,
            totalRequests: totalRequests,
            averageWaitTime: avgWait
        )
    }

    // MARK: - Private Helpers

    private func recordWait(since start: TimeInterval) {
        totalWaitTime += Date().timeIntervalSinceReferenceDate - start
        waitCount += 1
    }
}

// MARK: - Benchmark Result

/// Result of a single benchmark run
public struct BenchmarkResult: Sendable, Equatable {
    /// Human-readable label
    public let label: String

    /// Number of iterations executed
    public let iterations: Int

    /// Total elapsed time in seconds
    public let totalTime: TimeInterval

    /// Average time per iteration in seconds
    public let averageTime: TimeInterval

    /// Minimum iteration time in seconds
    public let minTime: TimeInterval

    /// Maximum iteration time in seconds
    public let maxTime: TimeInterval

    /// Standard deviation of iteration times
    public let standardDeviation: TimeInterval

    /// Throughput in operations per second
    public let operationsPerSecond: Double

    public init(
        label: String,
        iterations: Int,
        totalTime: TimeInterval,
        averageTime: TimeInterval,
        minTime: TimeInterval,
        maxTime: TimeInterval,
        standardDeviation: TimeInterval,
        operationsPerSecond: Double
    ) {
        self.label = label
        self.iterations = iterations
        self.totalTime = totalTime
        self.averageTime = averageTime
        self.minTime = minTime
        self.maxTime = maxTime
        self.standardDeviation = standardDeviation
        self.operationsPerSecond = operationsPerSecond
    }
}

// MARK: - Benchmark Comparison

/// Comparison between a baseline and current benchmark result
public struct BenchmarkComparison: Sendable, Equatable {
    /// The baseline result
    public let baselineResult: BenchmarkResult

    /// The current result
    public let currentResult: BenchmarkResult

    /// Speedup factor (> 1.0 means faster)
    public let speedup: Double

    /// Improvement as a percentage
    public let improvementPercentage: Double

    /// Whether the current result is an improvement
    public let isImproved: Bool

    public init(baselineResult: BenchmarkResult, currentResult: BenchmarkResult, speedup: Double, improvementPercentage: Double, isImproved: Bool) {
        self.baselineResult = baselineResult
        self.currentResult = currentResult
        self.speedup = speedup
        self.improvementPercentage = improvementPercentage
        self.isImproved = isImproved
    }
}

// MARK: - FHIR Benchmark

/// Lightweight benchmarking harness for FHIR operations
public struct FHIRBenchmark: Sendable {

    public init() {}

    /// Measure an async operation over multiple iterations
    ///
    /// - Parameters:
    ///   - label: A descriptive label for the benchmark
    ///   - iterations: Number of times to execute the operation
    ///   - operation: The async closure to measure
    /// - Returns: Aggregated benchmark result
    public func measure(
        label: String,
        iterations: Int,
        operation: @Sendable () async throws -> Void
    ) async throws -> BenchmarkResult {
        var times: [TimeInterval] = []
        times.reserveCapacity(iterations)

        let overallStart = Date().timeIntervalSinceReferenceDate
        for _ in 0..<iterations {
            let start = Date().timeIntervalSinceReferenceDate
            try await operation()
            times.append(Date().timeIntervalSinceReferenceDate - start)
        }
        let totalTime = Date().timeIntervalSinceReferenceDate - overallStart

        let avg = times.reduce(0, +) / Double(times.count)
        let minT = times.min() ?? 0
        let maxT = times.max() ?? 0
        let variance = times.reduce(0.0) { $0 + ($1 - avg) * ($1 - avg) } / Double(times.count)
        let stdDev = variance.squareRoot()
        let opsPerSec = totalTime > 0 ? Double(iterations) / totalTime : 0

        return BenchmarkResult(
            label: label,
            iterations: iterations,
            totalTime: totalTime,
            averageTime: avg,
            minTime: minT,
            maxTime: maxT,
            standardDeviation: stdDev,
            operationsPerSecond: opsPerSec
        )
    }

    /// Compare two benchmark results
    ///
    /// - Parameters:
    ///   - baseline: The reference result
    ///   - current: The result to compare
    /// - Returns: A comparison summary
    public func compare(baseline: BenchmarkResult, current: BenchmarkResult) -> BenchmarkComparison {
        let speedup = baseline.averageTime > 0 ? baseline.averageTime / current.averageTime : 0
        let improvement = baseline.averageTime > 0
            ? ((baseline.averageTime - current.averageTime) / baseline.averageTime) * 100
            : 0
        return BenchmarkComparison(
            baselineResult: baseline,
            currentResult: current,
            speedup: speedup,
            improvementPercentage: improvement,
            isImproved: current.averageTime < baseline.averageTime
        )
    }
}

// MARK: - FHIR Performance Profile

/// Convenience profiling helpers for common FHIR operations
public struct FHIRPerformanceProfile: Sendable {

    private let benchmark = FHIRBenchmark()

    public init() {}

    /// Profile JSON parsing performance
    public func profileJSONParsing(sampleData: Data, iterations: Int) async -> BenchmarkResult {
        let parser = OptimizedJSONParser()
        // measure is throwing but parsing errors are non-fatal here
        return (try? await benchmark.measure(label: "JSON Parsing", iterations: iterations) {
            _ = try parser.parseResource(from: sampleData)
        }) ?? BenchmarkResult(label: "JSON Parsing", iterations: 0, totalTime: 0, averageTime: 0, minTime: 0, maxTime: 0, standardDeviation: 0, operationsPerSecond: 0)
    }

    /// Profile XML parsing performance
    public func profileXMLParsing(sampleData: Data, iterations: Int) async -> BenchmarkResult {
        let parser = OptimizedXMLParser()
        return (try? await benchmark.measure(label: "XML Parsing", iterations: iterations) {
            _ = try parser.parseResource(from: sampleData)
        }) ?? BenchmarkResult(label: "XML Parsing", iterations: 0, totalTime: 0, averageTime: 0, minTime: 0, maxTime: 0, standardDeviation: 0, operationsPerSecond: 0)
    }

    /// Profile cache get/put performance
    public func profileCachePerformance(cache: FHIRResourceCache, operations: Int) async -> BenchmarkResult {
        let data = Data(repeating: 0x41, count: 128)
        return (try? await benchmark.measure(label: "Cache Operations", iterations: operations) {
            let id = UUID().uuidString
            await cache.put(resourceType: "Patient", id: id, data: data)
            _ = await cache.get(resourceType: "Patient", id: id)
        }) ?? BenchmarkResult(label: "Cache Operations", iterations: 0, totalTime: 0, averageTime: 0, minTime: 0, maxTime: 0, standardDeviation: 0, operationsPerSecond: 0)
    }

    /// Generate a human-readable report from multiple benchmark results
    public func generateReport(results: [BenchmarkResult]) -> String {
        var lines: [String] = ["=== FHIR Performance Report ===", ""]
        for result in results {
            lines.append("[\(result.label)]")
            lines.append("  Iterations: \(result.iterations)")
            lines.append(String(format: "  Avg: %.6f s  Min: %.6f s  Max: %.6f s", result.averageTime, result.minTime, result.maxTime))
            lines.append(String(format: "  StdDev: %.6f s  Ops/sec: %.1f", result.standardDeviation, result.operationsPerSecond))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Operation Metrics

/// Aggregated metrics for a named operation
public struct OperationMetrics: Sendable, Codable, Equatable {
    /// Operation name
    public let name: String

    /// Number of recordings
    public let count: Int

    /// Total time across all recordings in seconds
    public let totalTime: TimeInterval

    /// Average time per recording in seconds
    public let averageTime: TimeInterval

    /// Minimum recorded time
    public let minTime: TimeInterval

    /// Maximum recorded time
    public let maxTime: TimeInterval

    /// Total bytes processed across all recordings
    public let totalBytes: Int

    /// Throughput in bytes per second
    public let throughput: Double

    public init(name: String, count: Int, totalTime: TimeInterval, averageTime: TimeInterval, minTime: TimeInterval, maxTime: TimeInterval, totalBytes: Int, throughput: Double) {
        self.name = name
        self.count = count
        self.totalTime = totalTime
        self.averageTime = averageTime
        self.minTime = minTime
        self.maxTime = maxTime
        self.totalBytes = totalBytes
        self.throughput = throughput
    }
}

// MARK: - FHIR Performance Metrics

/// Actor that accumulates timing and throughput metrics for FHIR operations
public actor FHIRPerformanceMetrics {

    /// Internal mutable record used during accumulation
    private struct MetricRecord {
        var count: Int = 0
        var totalTime: TimeInterval = 0
        var minTime: TimeInterval = .greatestFiniteMagnitude
        var maxTime: TimeInterval = 0
        var totalBytes: Int = 0
    }

    private var records: [String: MetricRecord] = [:]

    public init() {}

    /// Record a single operation
    ///
    /// - Parameters:
    ///   - name: Operation name
    ///   - duration: Time taken in seconds
    ///   - bytesProcessed: Bytes involved (default 0)
    public func recordOperation(name: String, duration: TimeInterval, bytesProcessed: Int = 0) async {
        var record = records[name] ?? MetricRecord()
        record.count += 1
        record.totalTime += duration
        record.totalBytes += bytesProcessed
        if duration < record.minTime { record.minTime = duration }
        if duration > record.maxTime { record.maxTime = duration }
        records[name] = record
    }

    /// Retrieve metrics for a specific operation
    public func getMetrics(for operation: String) async -> OperationMetrics {
        guard let record = records[operation] else {
            return OperationMetrics(name: operation, count: 0, totalTime: 0, averageTime: 0, minTime: 0, maxTime: 0, totalBytes: 0, throughput: 0)
        }
        return buildMetrics(name: operation, record: record)
    }

    /// Retrieve metrics for all recorded operations
    public func allMetrics() async -> [String: OperationMetrics] {
        var result: [String: OperationMetrics] = [:]
        for (name, record) in records {
            result[name] = buildMetrics(name: name, record: record)
        }
        return result
    }

    /// Reset all accumulated metrics
    public func reset() async {
        records.removeAll()
    }

    // MARK: - Private

    private func buildMetrics(name: String, record: MetricRecord) -> OperationMetrics {
        let avg = record.count > 0 ? record.totalTime / Double(record.count) : 0
        let throughput = record.totalTime > 0 ? Double(record.totalBytes) / record.totalTime : 0
        return OperationMetrics(
            name: name,
            count: record.count,
            totalTime: record.totalTime,
            averageTime: avg,
            minTime: record.minTime == .greatestFiniteMagnitude ? 0 : record.minTime,
            maxTime: record.maxTime,
            totalBytes: record.totalBytes,
            throughput: throughput
        )
    }
}

// MARK: - Errors

/// Errors raised by performance utilities
public enum FHIRPerformanceError: Error, Sendable, Equatable {
    /// The input format is invalid
    case invalidFormat(String)
    /// The connection pool has no available connections
    case poolExhausted(String)
    /// A timeout occurred
    case timeout(String)
}
