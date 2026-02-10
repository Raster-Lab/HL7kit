/// Testing Infrastructure for HL7kit
///
/// This module provides reusable testing utilities for HL7 integrations.
/// These utilities are library-level (no XCTest dependency) and can be used
/// by consumers to test their own HL7 implementations.

import Foundation

// MARK: - Integration Test Framework

/// Status of an integration test execution
public enum IntegrationTestStatus: Sendable, Equatable {
    /// Test passed successfully
    case passed
    /// Test failed with a message
    case failed(String)
    /// Test was skipped with a reason
    case skipped(String)
    /// Test encountered an error
    case error(String)
}

/// Result of an integration test execution
public struct IntegrationTestResult: Sendable {
    /// Name of the test
    public let name: String
    /// Status of the test
    public let status: IntegrationTestStatus
    /// Duration of the test execution in seconds
    public let duration: TimeInterval
    /// Additional details about the test execution
    public let details: String

    public init(name: String, status: IntegrationTestStatus, duration: TimeInterval, details: String = "") {
        self.name = name
        self.status = status
        self.duration = duration
        self.details = details
    }

    /// Whether the test passed
    public var passed: Bool {
        if case .passed = status { return true }
        return false
    }
}

/// Protocol for defining an integration test
public protocol IntegrationTest: Sendable {
    /// Name of the test
    var name: String { get }
    /// Names of tests that must run before this one
    var dependencies: [String] { get }
    /// Set up resources before execution
    func setup() async throws
    /// Execute the test logic
    func execute() async throws
    /// Tear down resources after execution
    func teardown() async throws
    /// Validate the results
    func validate() async throws -> IntegrationTestStatus
}

extension IntegrationTest {
    /// Default empty dependencies
    public var dependencies: [String] { [] }
    /// Default no-op setup
    public func setup() async throws {}
    /// Default no-op teardown
    public func teardown() async throws {}
}

/// A suite of integration tests grouped together
public struct IntegrationTestSuite: Sendable {
    /// Name of the suite
    public let name: String
    /// Tests in the suite
    public let tests: [any IntegrationTest]

    public init(name: String, tests: [any IntegrationTest]) {
        self.name = name
        self.tests = tests
    }
}

/// Execution mode for integration tests
public enum TestExecutionMode: Sendable {
    /// Run tests one at a time
    case sequential
    /// Run tests concurrently
    case parallel
}

/// Actor that manages integration test execution
public actor IntegrationTestRunner {
    private var results: [IntegrationTestResult] = []

    public init() {}

    /// Run a single integration test
    /// - Parameter test: The test to run
    /// - Returns: The test result
    @discardableResult
    public func run(test: any IntegrationTest) async -> IntegrationTestResult {
        let start = Date()
        var status: IntegrationTestStatus
        var details = ""

        do {
            try await test.setup()
            do {
                try await test.execute()
                status = try await test.validate()
            } catch {
                status = .error("Execute/validate error: \(error)")
            }
            do {
                try await test.teardown()
            } catch {
                details += "Teardown error: \(error). "
            }
        } catch {
            status = .error("Setup error: \(error)")
        }

        let duration = Date().timeIntervalSince(start)
        let result = IntegrationTestResult(name: test.name, status: status, duration: duration, details: details)
        results.append(result)
        return result
    }

    /// Run a suite of integration tests
    /// - Parameters:
    ///   - suite: The test suite to run
    ///   - mode: Execution mode (sequential or parallel)
    /// - Returns: Array of test results
    @discardableResult
    public func run(suite: IntegrationTestSuite, mode: TestExecutionMode = .sequential) async -> [IntegrationTestResult] {
        let ordered = topologicalSort(tests: suite.tests)
        var suiteResults: [IntegrationTestResult] = []

        switch mode {
        case .sequential:
            for test in ordered {
                let result = await run(test: test)
                suiteResults.append(result)
            }
        case .parallel:
            // Group tests by dependency level for safe parallelism
            let levels = dependencyLevels(tests: ordered)
            for level in levels {
                let levelResults = await withTaskGroup(of: IntegrationTestResult.self, returning: [IntegrationTestResult].self) { group in
                    for test in level {
                        group.addTask {
                            await self.run(test: test)
                        }
                    }
                    var collected: [IntegrationTestResult] = []
                    for await result in group {
                        collected.append(result)
                    }
                    return collected
                }
                suiteResults.append(contentsOf: levelResults)
            }
        }

        return suiteResults
    }

    /// Generate a text report of all test results
    /// - Returns: A formatted text summary
    public func generateReport() -> String {
        let passed = results.filter { $0.passed }.count
        let failed = results.filter { if case .failed = $0.status { return true }; return false }.count
        let skipped = results.filter { if case .skipped = $0.status { return true }; return false }.count
        let errored = results.filter { if case .error = $0.status { return true }; return false }.count
        let totalDuration = results.reduce(0.0) { $0 + $1.duration }

        var report = "Integration Test Report\n"
        report += "=======================\n"
        report += "Total: \(results.count) | Passed: \(passed) | Failed: \(failed) | Skipped: \(skipped) | Errors: \(errored)\n"
        report += String(format: "Duration: %.3fs\n\n", totalDuration)

        for result in results {
            let statusStr: String
            switch result.status {
            case .passed: statusStr = "PASS"
            case .failed(let msg): statusStr = "FAIL: \(msg)"
            case .skipped(let reason): statusStr = "SKIP: \(reason)"
            case .error(let msg): statusStr = "ERROR: \(msg)"
            }
            report += "[\(statusStr)] \(result.name) (\(String(format: "%.3fs", result.duration)))\n"
            if !result.details.isEmpty {
                report += "  Details: \(result.details)\n"
            }
        }

        return report
    }

    /// Get all collected results
    public func allResults() -> [IntegrationTestResult] {
        results
    }

    /// Clear all results
    public func clear() {
        results.removeAll()
    }

    // MARK: - Private Helpers

    /// Topological sort of tests based on dependencies
    private func topologicalSort(tests: [any IntegrationTest]) -> [any IntegrationTest] {
        let nameMap = Dictionary(uniqueKeysWithValues: tests.map { ($0.name, $0) })
        var visited = Set<String>()
        var sorted: [any IntegrationTest] = []

        func visit(_ test: any IntegrationTest) {
            guard !visited.contains(test.name) else { return }
            visited.insert(test.name)
            for dep in test.dependencies {
                if let depTest = nameMap[dep] {
                    visit(depTest)
                }
            }
            sorted.append(test)
        }

        for test in tests {
            visit(test)
        }
        return sorted
    }

    /// Group tests into dependency levels for parallel execution
    private func dependencyLevels(tests: [any IntegrationTest]) -> [[any IntegrationTest]] {
        var completed = Set<String>()
        var remaining = tests
        var levels: [[any IntegrationTest]] = []

        while !remaining.isEmpty {
            var currentLevel: [any IntegrationTest] = []
            var nextRemaining: [any IntegrationTest] = []

            for test in remaining {
                let depsResolved = test.dependencies.allSatisfy { completed.contains($0) }
                if depsResolved {
                    currentLevel.append(test)
                } else {
                    nextRemaining.append(test)
                }
            }

            if currentLevel.isEmpty {
                // Circular dependency or unresolvable - add remaining as-is
                levels.append(remaining)
                break
            }

            for test in currentLevel {
                completed.insert(test.name)
            }
            levels.append(currentLevel)
            remaining = nextRemaining
        }

        return levels
    }
}

// MARK: - Performance Benchmark Suite

/// Protocol for defining a benchmark case
public protocol BenchmarkCase: Sendable {
    /// Name of the benchmark
    var name: String { get }
    /// Number of warmup iterations
    var warmupCount: Int { get }
    /// Number of measured iterations
    var iterationCount: Int { get }
    /// Run the measured operation once
    func measure() async throws
}

extension BenchmarkCase {
    /// Default warmup count
    public var warmupCount: Int { 3 }
    /// Default iteration count
    public var iterationCount: Int { 10 }
}

/// Detailed benchmark timing result with statistical analysis
public struct BenchmarkTimingResult: Sendable {
    /// Name of the benchmark
    public let name: String
    /// Minimum time in seconds
    public let min: TimeInterval
    /// Maximum time in seconds
    public let max: TimeInterval
    /// Average time in seconds
    public let avg: TimeInterval
    /// Median time in seconds
    public let median: TimeInterval
    /// 95th percentile time in seconds
    public let p95: TimeInterval
    /// 99th percentile time in seconds
    public let p99: TimeInterval
    /// Number of iterations
    public let iterations: Int
    /// Estimated memory usage in bytes (if available)
    public let estimatedMemoryBytes: Int?
    /// Percentage change from baseline (positive = slower)
    public let baselineChange: Double?

    public init(
        name: String,
        min: TimeInterval,
        max: TimeInterval,
        avg: TimeInterval,
        median: TimeInterval,
        p95: TimeInterval,
        p99: TimeInterval,
        iterations: Int,
        estimatedMemoryBytes: Int? = nil,
        baselineChange: Double? = nil
    ) {
        self.name = name
        self.min = min
        self.max = max
        self.avg = avg
        self.median = median
        self.p95 = p95
        self.p99 = p99
        self.iterations = iterations
        self.estimatedMemoryBytes = estimatedMemoryBytes
        self.baselineChange = baselineChange
    }
}

/// A suite of benchmark cases grouped together
public struct BenchmarkSuite: Sendable {
    /// Name of the suite
    public let name: String
    /// Benchmark cases in the suite
    public let cases: [any BenchmarkCase]

    public init(name: String, cases: [any BenchmarkCase]) {
        self.name = name
        self.cases = cases
    }
}

/// Actor that executes benchmark cases and collects results
public actor PerformanceBenchmarkRunner {
    private var results: [BenchmarkTimingResult] = []
    private var baselines: [String: TimeInterval] = [:]

    public init() {}

    /// Set a baseline average time for a named benchmark
    /// - Parameters:
    ///   - name: Benchmark name
    ///   - avgTime: Baseline average time in seconds
    public func setBaseline(name: String, avgTime: TimeInterval) {
        baselines[name] = avgTime
    }

    /// Run a single benchmark case
    /// - Parameter benchmarkCase: The benchmark to run
    /// - Returns: Timing result with statistics
    @discardableResult
    public func run(benchmarkCase: any BenchmarkCase) async throws -> BenchmarkTimingResult {
        // Warmup
        for _ in 0..<benchmarkCase.warmupCount {
            try await benchmarkCase.measure()
        }

        // Measure memory before
        let memBefore = estimateMemory()

        // Measurement
        var durations: [TimeInterval] = []
        for _ in 0..<benchmarkCase.iterationCount {
            let start = Date()
            try await benchmarkCase.measure()
            durations.append(Date().timeIntervalSince(start))
        }

        // Measure memory after
        let memAfter = estimateMemory()
        let memDelta: Int? = (memBefore != nil && memAfter != nil) ? (memAfter! - memBefore!) : nil

        let sorted = durations.sorted()
        let avg = sorted.reduce(0, +) / Double(sorted.count)
        let median = percentile(sorted, p: 0.5)
        let p95 = percentile(sorted, p: 0.95)
        let p99 = percentile(sorted, p: 0.99)

        var baselineChange: Double? = nil
        if let baseline = baselines[benchmarkCase.name], baseline > 0 {
            baselineChange = ((avg - baseline) / baseline) * 100.0
        }

        let result = BenchmarkTimingResult(
            name: benchmarkCase.name,
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            avg: avg,
            median: median,
            p95: p95,
            p99: p99,
            iterations: benchmarkCase.iterationCount,
            estimatedMemoryBytes: memDelta,
            baselineChange: baselineChange
        )

        results.append(result)
        return result
    }

    /// Run all benchmarks in a suite
    /// - Parameter suite: The benchmark suite to run
    /// - Returns: Array of timing results
    @discardableResult
    public func run(suite: BenchmarkSuite) async throws -> [BenchmarkTimingResult] {
        var suiteResults: [BenchmarkTimingResult] = []
        for bc in suite.cases {
            let result = try await run(benchmarkCase: bc)
            suiteResults.append(result)
        }
        return suiteResults
    }

    /// Get all collected results
    public func allResults() -> [BenchmarkTimingResult] {
        results
    }

    /// Clear all results
    public func clear() {
        results.removeAll()
    }

    /// Generate a text report of benchmark results
    public func generateReport() -> String {
        var report = "Performance Benchmark Report\n"
        report += "============================\n"
        for r in results {
            report += "\(r.name):\n"
            report += String(format: "  Min: %.6fs | Max: %.6fs | Avg: %.6fs\n", r.min, r.max, r.avg)
            report += String(format: "  Median: %.6fs | P95: %.6fs | P99: %.6fs\n", r.median, r.p95, r.p99)
            report += "  Iterations: \(r.iterations)\n"
            if let mem = r.estimatedMemoryBytes {
                report += "  Est. Memory: \(mem) bytes\n"
            }
            if let change = r.baselineChange {
                report += String(format: "  Baseline Change: %+.2f%%\n", change)
            }
        }
        return report
    }

    // MARK: - Private

    private func percentile(_ sorted: [TimeInterval], p: Double) -> TimeInterval {
        guard !sorted.isEmpty else { return 0 }
        let index = p * Double(sorted.count - 1)
        let lower = Int(index)
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = index - Double(lower)
        return sorted[lower] + fraction * (sorted[upper] - sorted[lower])
    }

    private nonisolated func estimateMemory() -> Int? {
        #if os(Linux)
        // Read /proc/self/statm for RSS on Linux
        guard let data = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8) else { return nil }
        let parts = data.split(separator: " ")
        guard parts.count >= 2, let pages = Int(parts[1]) else { return nil }
        return pages * 4096
        #else
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Int(info.resident_size)
        #endif
    }
}

// MARK: - Conformance Test Suite

/// Category of a conformance requirement
public enum ConformanceCategory: String, Sendable, CaseIterable {
    /// Message structure conformance
    case messageStructure = "Message Structure"
    /// Data type conformance
    case dataTypes = "Data Types"
    /// Transport conformance
    case transport = "Transport"
    /// Validation conformance
    case validation = "Validation"
    /// Security conformance
    case security = "Security"
    /// Encoding conformance
    case encoding = "Encoding"
}

/// A specific conformance requirement
public struct ConformanceRequirement: Sendable {
    /// Unique identifier
    public let id: String
    /// Human-readable description
    public let description: String
    /// Category of the requirement
    public let category: ConformanceCategory
    /// Whether this requirement is mandatory
    public let mandatory: Bool

    public init(id: String, description: String, category: ConformanceCategory, mandatory: Bool = true) {
        self.id = id
        self.description = description
        self.category = category
        self.mandatory = mandatory
    }
}

/// Result of a single conformance test
public struct ConformanceTestResult: Sendable {
    /// The requirement being tested
    public let requirement: ConformanceRequirement
    /// Whether the test passed
    public let passed: Bool
    /// Details or failure message
    public let details: String

    public init(requirement: ConformanceRequirement, passed: Bool, details: String = "") {
        self.requirement = requirement
        self.passed = passed
        self.details = details
    }
}

/// Protocol for a conformance test case
public protocol ConformanceTestCase: Sendable {
    /// The requirement being tested
    var requirement: ConformanceRequirement { get }
    /// Run the conformance test
    /// - Returns: Whether the requirement is satisfied
    func evaluate() async throws -> Bool
}

/// Report summarizing conformance test results
public struct ConformanceReport: Sendable {
    /// Individual test results
    public let results: [ConformanceTestResult]
    /// Overall pass rate (0.0 to 1.0)
    public let passRate: Double
    /// Pass rate by category
    public let categoryPassRates: [ConformanceCategory: Double]
    /// Whether all mandatory requirements passed
    public let allMandatoryPassed: Bool

    public init(results: [ConformanceTestResult]) {
        self.results = results
        let total = results.count
        let passed = results.filter(\.passed).count
        self.passRate = total > 0 ? Double(passed) / Double(total) : 0

        var categoryResults: [ConformanceCategory: (passed: Int, total: Int)] = [:]
        for r in results {
            var entry = categoryResults[r.requirement.category, default: (0, 0)]
            entry.total += 1
            if r.passed { entry.passed += 1 }
            categoryResults[r.requirement.category] = entry
        }
        var rates: [ConformanceCategory: Double] = [:]
        for (cat, counts) in categoryResults {
            rates[cat] = counts.total > 0 ? Double(counts.passed) / Double(counts.total) : 0
        }
        self.categoryPassRates = rates

        self.allMandatoryPassed = results
            .filter { $0.requirement.mandatory }
            .allSatisfy(\.passed)
    }

    /// Generate a text report
    public func exportAsText() -> String {
        var report = "Conformance Test Report\n"
        report += "=======================\n"
        report += String(format: "Overall Pass Rate: %.1f%% (%d/%d)\n", passRate * 100, results.filter(\.passed).count, results.count)
        report += "Mandatory Requirements: \(allMandatoryPassed ? "ALL PASSED" : "SOME FAILED")\n\n"

        let grouped = Dictionary(grouping: results) { $0.requirement.category }
        for category in ConformanceCategory.allCases {
            guard let categoryResults = grouped[category] else { continue }
            let catPassed = categoryResults.filter(\.passed).count
            report += "\(category.rawValue): \(catPassed)/\(categoryResults.count)\n"
            for r in categoryResults {
                let icon = r.passed ? "✓" : "✗"
                let mandatoryTag = r.requirement.mandatory ? " [MANDATORY]" : ""
                report += "  \(icon) \(r.requirement.id): \(r.requirement.description)\(mandatoryTag)\n"
                if !r.details.isEmpty {
                    report += "    \(r.details)\n"
                }
            }
        }

        return report
    }
}

/// Actor that executes conformance tests and generates reports
public actor ConformanceTestRunner {
    private var results: [ConformanceTestResult] = []

    public init() {}

    /// Run a single conformance test case
    /// - Parameter testCase: The test case to run
    /// - Returns: The conformance test result
    @discardableResult
    public func run(testCase: any ConformanceTestCase) async -> ConformanceTestResult {
        let passed: Bool
        let details: String
        do {
            passed = try await testCase.evaluate()
            details = passed ? "" : "Requirement not satisfied"
        } catch {
            passed = false
            details = "Error: \(error)"
        }
        let result = ConformanceTestResult(requirement: testCase.requirement, passed: passed, details: details)
        results.append(result)
        return result
    }

    /// Run multiple conformance test cases
    /// - Parameter testCases: Test cases to run
    /// - Returns: A conformance report
    @discardableResult
    public func run(testCases: [any ConformanceTestCase]) async -> ConformanceReport {
        for tc in testCases {
            await run(testCase: tc)
        }
        return ConformanceReport(results: results)
    }

    /// Generate a report from collected results
    public func generateReport() -> ConformanceReport {
        ConformanceReport(results: results)
    }

    /// Clear all results
    public func clear() {
        results.removeAll()
    }
}

// MARK: - Mock Server and Client

/// HTTP method representation
public enum MockHTTPMethod: String, Sendable, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// A mock HTTP request
public struct MockRequest: Sendable, Equatable {
    /// URL path of the request
    public let path: String
    /// HTTP method
    public let method: MockHTTPMethod
    /// Request headers
    public let headers: [String: String]
    /// Request body
    public let body: String?

    public init(path: String, method: MockHTTPMethod = .get, headers: [String: String] = [:], body: String? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/// A mock HTTP response
public struct MockResponse: Sendable {
    /// HTTP status code
    public let statusCode: Int
    /// Response headers
    public let headers: [String: String]
    /// Response body
    public let body: String?
    /// Simulated delay in seconds
    public let delay: TimeInterval

    public init(statusCode: Int = 200, headers: [String: String] = [:], body: String? = nil, delay: TimeInterval = 0) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.delay = delay
    }
}

/// Recorded interaction between client and server
public struct MockInteraction: Sendable {
    /// The request that was made
    public let request: MockRequest
    /// The response that was returned
    public let response: MockResponse
    /// Timestamp of the interaction
    public let timestamp: Date

    public init(request: MockRequest, response: MockResponse, timestamp: Date = Date()) {
        self.request = request
        self.response = response
        self.timestamp = timestamp
    }
}

/// A route matcher for configuring mock responses
public struct MockRoute: Sendable {
    /// Path pattern to match
    public let path: String
    /// Method to match (nil matches any)
    public let method: MockHTTPMethod?
    /// Required headers (all must be present)
    public let requiredHeaders: [String: String]
    /// Response to return when matched
    public let response: MockResponse

    public init(path: String, method: MockHTTPMethod? = nil, requiredHeaders: [String: String] = [:], response: MockResponse) {
        self.path = path
        self.method = method
        self.requiredHeaders = requiredHeaders
        self.response = response
    }

    /// Check if a request matches this route
    public func matches(_ request: MockRequest) -> Bool {
        guard request.path == path else { return false }
        if let method = method, request.method != method { return false }
        for (key, value) in requiredHeaders {
            guard request.headers[key] == value else { return false }
        }
        return true
    }
}

/// Mock server that records requests and returns configured responses
public actor MockServer {
    private var routes: [MockRoute] = []
    private var interactions: [MockInteraction] = []
    private var defaultResponse: MockResponse

    /// Initialize with a default response for unmatched requests
    public init(defaultResponse: MockResponse = MockResponse(statusCode: 404, body: "Not Found")) {
        self.defaultResponse = defaultResponse
    }

    /// Configure a route on the server
    /// - Parameter route: The route to add
    public func addRoute(_ route: MockRoute) {
        routes.append(route)
    }

    /// Configure a simple route
    /// - Parameters:
    ///   - path: URL path
    ///   - method: HTTP method
    ///   - response: Response to return
    public func when(path: String, method: MockHTTPMethod? = nil, respond response: MockResponse) {
        routes.append(MockRoute(path: path, method: method, response: response))
    }

    /// Handle a request and return a response
    /// - Parameter request: The incoming request
    /// - Returns: The configured response
    public func handle(_ request: MockRequest) async -> MockResponse {
        let response: MockResponse
        if let route = routes.first(where: { $0.matches(request) }) {
            response = route.response
        } else {
            response = defaultResponse
        }

        if response.delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(response.delay * 1_000_000_000))
        }

        interactions.append(MockInteraction(request: request, response: response, timestamp: Date()))
        return response
    }

    /// Get all recorded interactions
    public func allInteractions() -> [MockInteraction] {
        interactions
    }

    /// Verify a specific number of requests were made to a path
    /// - Parameters:
    ///   - path: URL path
    ///   - method: Optional HTTP method filter
    ///   - count: Expected number of calls
    /// - Returns: Whether the verification passed
    public func verify(path: String, method: MockHTTPMethod? = nil, expectedCount: Int) -> Bool {
        let matching = interactions.filter { interaction in
            interaction.request.path == path &&
            (method == nil || interaction.request.method == method)
        }
        return matching.count == expectedCount
    }

    /// Reset all routes and interactions
    public func reset() {
        routes.removeAll()
        interactions.removeAll()
    }
}

/// Mock client that sends requests and records interactions
public actor MockClient {
    private var interactions: [MockInteraction] = []
    private let server: MockServer

    /// Initialize with a mock server to send requests to
    /// - Parameter server: The mock server
    public init(server: MockServer) {
        self.server = server
    }

    /// Send a request to the mock server
    /// - Parameter request: The request to send
    /// - Returns: The response from the server
    @discardableResult
    public func send(_ request: MockRequest) async -> MockResponse {
        let response = await server.handle(request)
        interactions.append(MockInteraction(request: request, response: response, timestamp: Date()))
        return response
    }

    /// Get all recorded interactions
    public func allInteractions() -> [MockInteraction] {
        interactions
    }

    /// Reset recorded interactions
    public func reset() {
        interactions.removeAll()
    }
}

// MARK: - Test Data Generators

/// Seeded random number generator for reproducible test data
public struct SeededRandomGenerator: Sendable {
    private var state: UInt64

    /// Initialize with a seed
    /// - Parameter seed: Seed value for reproducibility
    public init(seed: UInt64) {
        self.state = seed
    }

    /// Generate the next random UInt64
    public mutating func next() -> UInt64 {
        // xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Generate a random integer in a range
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % span)
    }

    /// Select a random element from an array
    public mutating func randomElement<T>(from array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        let index = Int(next() % UInt64(array.count))
        return array[index]
    }
}

/// Common test data fixture
public struct HL7TestFixture: Sendable {
    /// A sample patient name
    public let patientName: String
    /// A sample MRN
    public let mrn: String
    /// A sample SSN
    public let ssn: String
    /// A sample phone number
    public let phone: String
    /// A sample date of birth
    public let dateOfBirth: String
    /// A sample HL7 v2 ADT message
    public let adtMessage: String
    /// A sample HL7 v2 ORU message
    public let oruMessage: String

    public init(
        patientName: String,
        mrn: String,
        ssn: String,
        phone: String,
        dateOfBirth: String,
        adtMessage: String,
        oruMessage: String
    ) {
        self.patientName = patientName
        self.mrn = mrn
        self.ssn = ssn
        self.phone = phone
        self.dateOfBirth = dateOfBirth
        self.adtMessage = adtMessage
        self.oruMessage = oruMessage
    }
}

/// Generator for randomized but realistic HL7 test data
public struct TestDataGenerator: Sendable {
    private var rng: SeededRandomGenerator

    /// Initialize with a seed for reproducibility
    /// - Parameter seed: Seed value (default: 42)
    public init(seed: UInt64 = 42) {
        self.rng = SeededRandomGenerator(seed: seed)
    }

    // MARK: - Curated Name Lists

    private static let firstNames = [
        "James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael", "Linda",
        "David", "Elizabeth", "William", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
        "Thomas", "Sarah", "Charles", "Karen", "Christopher", "Lisa", "Daniel", "Nancy",
        "Matthew", "Betty", "Anthony", "Margaret", "Mark", "Sandra"
    ]

    private static let lastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
        "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
        "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson",
        "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson"
    ]

    // MARK: - Name Generation

    /// Generate a random patient name in "Last^First" HL7 format
    public mutating func generatePatientName() -> String {
        let first = rng.randomElement(from: Self.firstNames) ?? "John"
        let last = rng.randomElement(from: Self.lastNames) ?? "Doe"
        return "\(last)^\(first)"
    }

    // MARK: - Identifier Generation

    /// Generate a random MRN (Medical Record Number)
    public mutating func generateMRN() -> String {
        let num = rng.nextInt(in: 100000...999999)
        return "MRN\(num)"
    }

    /// Generate a random SSN in XXX-XX-XXXX format
    public mutating func generateSSN() -> String {
        let a = rng.nextInt(in: 100...999)
        let b = rng.nextInt(in: 10...99)
        let c = rng.nextInt(in: 1000...9999)
        return "\(a)-\(b)-\(c)"
    }

    /// Generate a random US phone number
    public mutating func generatePhone() -> String {
        let area = rng.nextInt(in: 200...999)
        let prefix = rng.nextInt(in: 200...999)
        let line = rng.nextInt(in: 1000...9999)
        return "(\(area)) \(prefix)-\(line)"
    }

    // MARK: - Date Generation

    /// Generate a random date string in HL7 format (YYYYMMDD)
    /// - Parameters:
    ///   - startYear: Start year (default: 1940)
    ///   - endYear: End year (default: 2005)
    public mutating func generateDateOfBirth(startYear: Int = 1940, endYear: Int = 2005) -> String {
        let year = rng.nextInt(in: startYear...endYear)
        let month = rng.nextInt(in: 1...12)
        let day = rng.nextInt(in: 1...28) // Safe upper bound for all months
        return String(format: "%04d%02d%02d", year, month, day)
    }

    /// Generate a random timestamp in HL7 format (YYYYMMDDHHMMSS)
    public mutating func generateTimestamp() -> String {
        let year = rng.nextInt(in: 2020...2025)
        let month = rng.nextInt(in: 1...12)
        let day = rng.nextInt(in: 1...28)
        let hour = rng.nextInt(in: 0...23)
        let minute = rng.nextInt(in: 0...59)
        let second = rng.nextInt(in: 0...59)
        return String(format: "%04d%02d%02d%02d%02d%02d", year, month, day, hour, minute, second)
    }

    // MARK: - HL7 v2.x Message Generation

    /// Generate a random HL7 v2.x ADT (Admit/Discharge/Transfer) message
    public mutating func generateADTMessage() -> String {
        let timestamp = generateTimestamp()
        let msgID = rng.nextInt(in: 100000...999999)
        let patientName = generatePatientName()
        let mrn = generateMRN()
        let dob = generateDateOfBirth()
        let gender = rng.randomElement(from: ["M", "F"]) ?? "M"

        return """
        MSH|^~\\&|SENDER|FACILITY|RECEIVER|FACILITY|\(timestamp)||ADT^A01|MSG\(msgID)|P|2.5\r\
        EVN|A01|\(timestamp)\r\
        PID|1||\(mrn)^^^HOSPITAL||\(patientName)|||\(dob)|\(gender)\r\
        PV1|1|I|WARD^ROOM^BED
        """
    }

    /// Generate a random HL7 v2.x ORU (Observation Result) message
    public mutating func generateORUMessage() -> String {
        let timestamp = generateTimestamp()
        let msgID = rng.nextInt(in: 100000...999999)
        let patientName = generatePatientName()
        let mrn = generateMRN()
        let value = rng.nextInt(in: 60...180)
        let testNames = ["GLUCOSE", "HEMOGLOBIN", "WBC", "RBC", "PLATELET"]
        let testName = rng.randomElement(from: testNames) ?? "GLUCOSE"
        let units = ["mg/dL", "g/dL", "K/uL", "M/uL", "K/uL"]
        let unit: String
        switch testName {
        case "GLUCOSE": unit = units[0]
        case "HEMOGLOBIN": unit = units[1]
        case "WBC": unit = units[2]
        case "RBC": unit = units[3]
        default: unit = units[4]
        }

        return """
        MSH|^~\\&|LAB|FACILITY|EHR|FACILITY|\(timestamp)||ORU^R01|MSG\(msgID)|P|2.5\r\
        PID|1||\(mrn)^^^HOSPITAL||\(patientName)\r\
        OBR|1||ORD\(msgID)|LAB^PANEL\r\
        OBX|1|NM|\(testName)^Lab Test||\(value)|\(unit)|||||F
        """
    }

    // MARK: - FHIR-like JSON Generation

    /// Generate a random FHIR-like Patient JSON snippet
    public mutating func generateFHIRPatientJSON() -> String {
        let first = rng.randomElement(from: Self.firstNames) ?? "John"
        let last = rng.randomElement(from: Self.lastNames) ?? "Doe"
        let mrn = generateMRN()
        let gender = rng.randomElement(from: ["male", "female"]) ?? "male"
        let year = rng.nextInt(in: 1940...2005)
        let month = rng.nextInt(in: 1...12)
        let day = rng.nextInt(in: 1...28)

        return """
        {
          "resourceType": "Patient",
          "id": "\(mrn)",
          "name": [{"family": "\(last)", "given": ["\(first)"]}],
          "gender": "\(gender)",
          "birthDate": "\(String(format: "%04d-%02d-%02d", year, month, day))"
        }
        """
    }

    // MARK: - Fixture Generation

    /// Generate a complete test fixture with correlated data
    public mutating func generateFixture() -> HL7TestFixture {
        HL7TestFixture(
            patientName: generatePatientName(),
            mrn: generateMRN(),
            ssn: generateSSN(),
            phone: generatePhone(),
            dateOfBirth: generateDateOfBirth(),
            adtMessage: generateADTMessage(),
            oruMessage: generateORUMessage()
        )
    }

    /// Generate multiple fixtures
    /// - Parameter count: Number of fixtures to generate
    /// - Returns: Array of test fixtures
    public mutating func generateFixtures(count: Int) -> [HL7TestFixture] {
        (0..<count).map { _ in generateFixture() }
    }
}
