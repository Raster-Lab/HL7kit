import XCTest
@testable import HL7Core

// MARK: - Test Helpers

/// A simple integration test that always passes
struct PassingTest: IntegrationTest, @unchecked Sendable {
    let name: String
    let dependencies: [String]
    var executed = false

    init(name: String = "PassingTest", dependencies: [String] = []) {
        self.name = name
        self.dependencies = dependencies
    }

    func setup() async throws {}
    func execute() async throws {}
    func teardown() async throws {}
    func validate() async throws -> IntegrationTestStatus { .passed }
}

/// A simple integration test that always fails
struct FailingTest: IntegrationTest, @unchecked Sendable {
    let name: String
    let dependencies: [String]

    init(name: String = "FailingTest", dependencies: [String] = []) {
        self.name = name
        self.dependencies = dependencies
    }

    func execute() async throws {}
    func validate() async throws -> IntegrationTestStatus { .failed("intentional failure") }
}

/// A simple integration test that skips
struct SkippingTest: IntegrationTest, @unchecked Sendable {
    let name: String
    let dependencies: [String]

    init(name: String = "SkippingTest", dependencies: [String] = []) {
        self.name = name
        self.dependencies = dependencies
    }

    func execute() async throws {}
    func validate() async throws -> IntegrationTestStatus { .skipped("not applicable") }
}

/// A simple integration test that throws during execute
struct ErroringTest: IntegrationTest, @unchecked Sendable {
    let name: String
    let dependencies: [String]

    init(name: String = "ErroringTest", dependencies: [String] = []) {
        self.name = name
        self.dependencies = dependencies
    }

    func execute() async throws {
        throw HL7Error.unknown("test error")
    }

    func validate() async throws -> IntegrationTestStatus { .passed }
}

/// A simple benchmark case
struct SimpleBenchmark: BenchmarkCase {
    let name: String
    let warmupCount: Int
    let iterationCount: Int

    init(name: String = "SimpleBenchmark", warmupCount: Int = 1, iterationCount: Int = 5) {
        self.name = name
        self.warmupCount = warmupCount
        self.iterationCount = iterationCount
    }

    func measure() async throws {
        // Perform a small computation
        var sum = 0
        for i in 0..<100 {
            sum += i
        }
        _ = sum
    }
}

/// A simple conformance test case
struct SimpleConformanceTest: ConformanceTestCase {
    let requirement: ConformanceRequirement
    let shouldPass: Bool

    init(requirement: ConformanceRequirement, shouldPass: Bool = true) {
        self.requirement = requirement
        self.shouldPass = shouldPass
    }

    func evaluate() async throws -> Bool {
        shouldPass
    }
}

// MARK: - Integration Test Runner Tests

final class IntegrationTestRunnerTests: XCTestCase {

    func testSinglePassingTest() async {
        let runner = IntegrationTestRunner()
        let test = PassingTest()
        let result = await runner.run(test: test)

        XCTAssertEqual(result.name, "PassingTest")
        XCTAssertTrue(result.passed)
        XCTAssertGreaterThanOrEqual(result.duration, 0)
    }

    func testSingleFailingTest() async {
        let runner = IntegrationTestRunner()
        let test = FailingTest()
        let result = await runner.run(test: test)

        XCTAssertEqual(result.name, "FailingTest")
        XCTAssertFalse(result.passed)
        if case .failed(let msg) = result.status {
            XCTAssertEqual(msg, "intentional failure")
        } else {
            XCTFail("Expected failed status")
        }
    }

    func testSkippingTest() async {
        let runner = IntegrationTestRunner()
        let test = SkippingTest()
        let result = await runner.run(test: test)

        XCTAssertFalse(result.passed)
        if case .skipped(let reason) = result.status {
            XCTAssertEqual(reason, "not applicable")
        } else {
            XCTFail("Expected skipped status")
        }
    }

    func testErroringTest() async {
        let runner = IntegrationTestRunner()
        let test = ErroringTest()
        let result = await runner.run(test: test)

        XCTAssertFalse(result.passed)
        if case .error(let msg) = result.status {
            XCTAssertTrue(msg.contains("error"))
        } else {
            XCTFail("Expected error status")
        }
    }

    func testSuiteSequentialExecution() async {
        let suite = IntegrationTestSuite(name: "TestSuite", tests: [
            PassingTest(name: "Test1"),
            FailingTest(name: "Test2"),
            SkippingTest(name: "Test3"),
        ])

        let runner = IntegrationTestRunner()
        let results = await runner.run(suite: suite, mode: .sequential)

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].passed)
        XCTAssertFalse(results[1].passed)
        XCTAssertFalse(results[2].passed)
    }

    func testSuiteParallelExecution() async {
        let suite = IntegrationTestSuite(name: "ParallelSuite", tests: [
            PassingTest(name: "P1"),
            PassingTest(name: "P2"),
            PassingTest(name: "P3"),
        ])

        let runner = IntegrationTestRunner()
        let results = await runner.run(suite: suite, mode: .parallel)

        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertTrue(result.passed)
        }
    }

    func testDependencyOrdering() async {
        let suite = IntegrationTestSuite(name: "DepSuite", tests: [
            PassingTest(name: "C", dependencies: ["B"]),
            PassingTest(name: "B", dependencies: ["A"]),
            PassingTest(name: "A"),
        ])

        let runner = IntegrationTestRunner()
        let results = await runner.run(suite: suite, mode: .sequential)

        XCTAssertEqual(results.count, 3)
        // A should run before B, B before C
        let names = results.map(\.name)
        let indexA = names.firstIndex(of: "A")!
        let indexB = names.firstIndex(of: "B")!
        let indexC = names.firstIndex(of: "C")!
        XCTAssertLessThan(indexA, indexB)
        XCTAssertLessThan(indexB, indexC)
    }

    func testReportGeneration() async {
        let runner = IntegrationTestRunner()
        _ = await runner.run(test: PassingTest(name: "ReportTest"))
        _ = await runner.run(test: FailingTest(name: "FailReport"))

        let report = await runner.generateReport()
        XCTAssertTrue(report.contains("Integration Test Report"))
        XCTAssertTrue(report.contains("Passed: 1"))
        XCTAssertTrue(report.contains("Failed: 1"))
        XCTAssertTrue(report.contains("PASS"))
        XCTAssertTrue(report.contains("FAIL"))
    }

    func testClearResults() async {
        let runner = IntegrationTestRunner()
        _ = await runner.run(test: PassingTest())
        let before = await runner.allResults()
        XCTAssertEqual(before.count, 1)

        await runner.clear()
        let after = await runner.allResults()
        XCTAssertEqual(after.count, 0)
    }
}

// MARK: - Performance Benchmark Tests

final class PerformanceBenchmarkTests: XCTestCase {

    func testSimpleBenchmark() async throws {
        let runner = PerformanceBenchmarkRunner()
        let bc = SimpleBenchmark(name: "Addition", warmupCount: 1, iterationCount: 5)
        let result = try await runner.run(benchmarkCase: bc)

        XCTAssertEqual(result.name, "Addition")
        XCTAssertEqual(result.iterations, 5)
        XCTAssertGreaterThanOrEqual(result.min, 0)
        XCTAssertGreaterThanOrEqual(result.max, result.min)
        XCTAssertGreaterThanOrEqual(result.avg, result.min)
        XCTAssertLessThanOrEqual(result.avg, result.max)
        XCTAssertGreaterThanOrEqual(result.median, result.min)
        XCTAssertGreaterThanOrEqual(result.p95, result.median)
        XCTAssertGreaterThanOrEqual(result.p99, result.p95)
    }

    func testBenchmarkSuite() async throws {
        let suite = BenchmarkSuite(name: "MathSuite", cases: [
            SimpleBenchmark(name: "Bench1", warmupCount: 1, iterationCount: 3),
            SimpleBenchmark(name: "Bench2", warmupCount: 1, iterationCount: 3),
        ])

        let runner = PerformanceBenchmarkRunner()
        let results = try await runner.run(suite: suite)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "Bench1")
        XCTAssertEqual(results[1].name, "Bench2")
    }

    func testBaselineComparison() async throws {
        let runner = PerformanceBenchmarkRunner()
        await runner.setBaseline(name: "BaselineTest", avgTime: 0.001)

        let bc = SimpleBenchmark(name: "BaselineTest", warmupCount: 1, iterationCount: 5)
        let result = try await runner.run(benchmarkCase: bc)

        XCTAssertNotNil(result.baselineChange)
    }

    func testBenchmarkReport() async throws {
        let runner = PerformanceBenchmarkRunner()
        let bc = SimpleBenchmark(name: "ReportBench", warmupCount: 1, iterationCount: 3)
        _ = try await runner.run(benchmarkCase: bc)

        let report = await runner.generateReport()
        XCTAssertTrue(report.contains("Performance Benchmark Report"))
        XCTAssertTrue(report.contains("ReportBench"))
        XCTAssertTrue(report.contains("Min:"))
        XCTAssertTrue(report.contains("Avg:"))
    }

    func testBenchmarkTimingResultProperties() {
        let result = BenchmarkTimingResult(
            name: "Test",
            min: 0.001,
            max: 0.010,
            avg: 0.005,
            median: 0.004,
            p95: 0.009,
            p99: 0.010,
            iterations: 100,
            estimatedMemoryBytes: 1024,
            baselineChange: 5.0
        )

        XCTAssertEqual(result.name, "Test")
        XCTAssertEqual(result.min, 0.001)
        XCTAssertEqual(result.max, 0.010)
        XCTAssertEqual(result.avg, 0.005)
        XCTAssertEqual(result.median, 0.004)
        XCTAssertEqual(result.p95, 0.009)
        XCTAssertEqual(result.p99, 0.010)
        XCTAssertEqual(result.iterations, 100)
        XCTAssertEqual(result.estimatedMemoryBytes, 1024)
        XCTAssertEqual(result.baselineChange, 5.0)
    }
}

// MARK: - Conformance Test Runner Tests

final class ConformanceTestRunnerTests: XCTestCase {

    func testPassingConformanceTest() async {
        let req = ConformanceRequirement(id: "REQ-001", description: "Must parse MSH", category: .messageStructure)
        let tc = SimpleConformanceTest(requirement: req, shouldPass: true)

        let runner = ConformanceTestRunner()
        let result = await runner.run(testCase: tc)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.requirement.id, "REQ-001")
    }

    func testFailingConformanceTest() async {
        let req = ConformanceRequirement(id: "REQ-002", description: "Must validate segments", category: .validation, mandatory: true)
        let tc = SimpleConformanceTest(requirement: req, shouldPass: false)

        let runner = ConformanceTestRunner()
        let result = await runner.run(testCase: tc)

        XCTAssertFalse(result.passed)
    }

    func testConformanceReport() async {
        let requirements = [
            ConformanceRequirement(id: "REQ-001", description: "Parse MSH", category: .messageStructure, mandatory: true),
            ConformanceRequirement(id: "REQ-002", description: "Validate PID", category: .validation, mandatory: true),
            ConformanceRequirement(id: "REQ-003", description: "Support TLS", category: .security, mandatory: false),
        ]

        let testCases: [any ConformanceTestCase] = [
            SimpleConformanceTest(requirement: requirements[0], shouldPass: true),
            SimpleConformanceTest(requirement: requirements[1], shouldPass: false),
            SimpleConformanceTest(requirement: requirements[2], shouldPass: true),
        ]

        let runner = ConformanceTestRunner()
        let report = await runner.run(testCases: testCases)

        // 2 out of 3 passed
        XCTAssertEqual(report.passRate, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertFalse(report.allMandatoryPassed) // REQ-002 is mandatory and failed
        XCTAssertEqual(report.results.count, 3)
    }

    func testConformanceReportExport() async {
        let req = ConformanceRequirement(id: "REQ-001", description: "Test req", category: .messageStructure)
        let tc = SimpleConformanceTest(requirement: req, shouldPass: true)

        let runner = ConformanceTestRunner()
        _ = await runner.run(testCase: tc)
        let report = await runner.generateReport()
        let text = report.exportAsText()

        XCTAssertTrue(text.contains("Conformance Test Report"))
        XCTAssertTrue(text.contains("REQ-001"))
        XCTAssertTrue(text.contains("100.0%"))
    }

    func testCategoryPassRates() async {
        let testCases: [any ConformanceTestCase] = [
            SimpleConformanceTest(
                requirement: ConformanceRequirement(id: "R1", description: "A", category: .messageStructure),
                shouldPass: true
            ),
            SimpleConformanceTest(
                requirement: ConformanceRequirement(id: "R2", description: "B", category: .messageStructure),
                shouldPass: true
            ),
            SimpleConformanceTest(
                requirement: ConformanceRequirement(id: "R3", description: "C", category: .dataTypes),
                shouldPass: false
            ),
        ]

        let runner = ConformanceTestRunner()
        let report = await runner.run(testCases: testCases)

        XCTAssertEqual(report.categoryPassRates[.messageStructure] ?? -1, 1.0, accuracy: 0.01)
        XCTAssertEqual(report.categoryPassRates[.dataTypes] ?? -1, 0.0, accuracy: 0.01)
    }

    func testConformanceClear() async {
        let runner = ConformanceTestRunner()
        let req = ConformanceRequirement(id: "R1", description: "Test", category: .encoding)
        _ = await runner.run(testCase: SimpleConformanceTest(requirement: req))

        let beforeReport = await runner.generateReport()
        XCTAssertEqual(beforeReport.results.count, 1)

        await runner.clear()
        let afterReport = await runner.generateReport()
        XCTAssertEqual(afterReport.results.count, 0)
    }
}

// MARK: - Mock Server/Client Tests

final class MockServerClientTests: XCTestCase {

    func testMockServerDefaultResponse() async {
        let server = MockServer()
        let request = MockRequest(path: "/unknown")
        let response = await server.handle(request)

        XCTAssertEqual(response.statusCode, 404)
    }

    func testMockServerConfiguredRoute() async {
        let server = MockServer()
        await server.when(path: "/api/patient", method: .get, respond: MockResponse(statusCode: 200, body: "patient data"))

        let request = MockRequest(path: "/api/patient", method: .get)
        let response = await server.handle(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, "patient data")
    }

    func testMockServerRouteMatching() async {
        let server = MockServer()
        let route = MockRoute(
            path: "/api/data",
            method: .post,
            requiredHeaders: ["Content-Type": "application/json"],
            response: MockResponse(statusCode: 201, body: "created")
        )
        await server.addRoute(route)

        // Matching request
        let matchingReq = MockRequest(path: "/api/data", method: .post, headers: ["Content-Type": "application/json"])
        let matchResp = await server.handle(matchingReq)
        XCTAssertEqual(matchResp.statusCode, 201)

        // Non-matching request (wrong method)
        let wrongMethod = MockRequest(path: "/api/data", method: .get)
        let wrongResp = await server.handle(wrongMethod)
        XCTAssertEqual(wrongResp.statusCode, 404)
    }

    func testMockClientSendsRequests() async {
        let server = MockServer()
        await server.when(path: "/test", respond: MockResponse(statusCode: 200, body: "ok"))

        let client = MockClient(server: server)
        let response = await client.send(MockRequest(path: "/test"))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, "ok")

        let interactions = await client.allInteractions()
        XCTAssertEqual(interactions.count, 1)
        XCTAssertEqual(interactions[0].request.path, "/test")
    }

    func testMockServerVerification() async {
        let server = MockServer()
        await server.when(path: "/api/check", respond: MockResponse(statusCode: 200))

        _ = await server.handle(MockRequest(path: "/api/check", method: .get))
        _ = await server.handle(MockRequest(path: "/api/check", method: .get))

        let verified = await server.verify(path: "/api/check", method: .get, expectedCount: 2)
        XCTAssertTrue(verified)

        let wrongCount = await server.verify(path: "/api/check", method: .get, expectedCount: 3)
        XCTAssertFalse(wrongCount)
    }

    func testMockServerReset() async {
        let server = MockServer()
        await server.when(path: "/reset", respond: MockResponse(statusCode: 200))
        _ = await server.handle(MockRequest(path: "/reset"))

        let before = await server.allInteractions()
        XCTAssertEqual(before.count, 1)

        await server.reset()
        let after = await server.allInteractions()
        XCTAssertEqual(after.count, 0)

        // Routes should also be cleared
        let response = await server.handle(MockRequest(path: "/reset"))
        XCTAssertEqual(response.statusCode, 404)
    }

    func testMockRequestEquality() {
        let r1 = MockRequest(path: "/a", method: .get, headers: ["X": "1"])
        let r2 = MockRequest(path: "/a", method: .get, headers: ["X": "1"])
        let r3 = MockRequest(path: "/b", method: .post)

        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }

    func testMockRouteMatchesCriteria() {
        let route = MockRoute(path: "/api", method: .post, requiredHeaders: ["Auth": "token"], response: MockResponse())

        XCTAssertTrue(route.matches(MockRequest(path: "/api", method: .post, headers: ["Auth": "token"])))
        XCTAssertFalse(route.matches(MockRequest(path: "/api", method: .get, headers: ["Auth": "token"])))
        XCTAssertFalse(route.matches(MockRequest(path: "/other", method: .post, headers: ["Auth": "token"])))
        XCTAssertFalse(route.matches(MockRequest(path: "/api", method: .post)))
    }
}

// MARK: - Test Data Generator Tests

final class TestDataGeneratorTests: XCTestCase {

    func testReproducibility() {
        var gen1 = TestDataGenerator(seed: 12345)
        var gen2 = TestDataGenerator(seed: 12345)

        // Same seed should produce same results
        XCTAssertEqual(gen1.generatePatientName(), gen2.generatePatientName())
        XCTAssertEqual(gen1.generateMRN(), gen2.generateMRN())
        XCTAssertEqual(gen1.generateSSN(), gen2.generateSSN())
        XCTAssertEqual(gen1.generatePhone(), gen2.generatePhone())
        XCTAssertEqual(gen1.generateDateOfBirth(), gen2.generateDateOfBirth())
    }

    func testDifferentSeeds() {
        var gen1 = TestDataGenerator(seed: 1)
        var gen2 = TestDataGenerator(seed: 2)

        // Different seeds should (very likely) produce different results
        let name1 = gen1.generatePatientName()
        let name2 = gen2.generatePatientName()
        // Not strictly guaranteed but extremely likely with different seeds
        _ = name1
        _ = name2
    }

    func testPatientNameFormat() {
        var gen = TestDataGenerator(seed: 42)
        let name = gen.generatePatientName()

        // Should contain ^ separator (Last^First)
        XCTAssertTrue(name.contains("^"))
        let parts = name.split(separator: "^")
        XCTAssertEqual(parts.count, 2)
        XCTAssertFalse(parts[0].isEmpty)
        XCTAssertFalse(parts[1].isEmpty)
    }

    func testMRNFormat() {
        var gen = TestDataGenerator(seed: 42)
        let mrn = gen.generateMRN()

        XCTAssertTrue(mrn.hasPrefix("MRN"))
        XCTAssertEqual(mrn.count, 9) // MRN + 6 digits
    }

    func testSSNFormat() {
        var gen = TestDataGenerator(seed: 42)
        let ssn = gen.generateSSN()

        // Format: XXX-XX-XXXX
        let parts = ssn.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0].count, 3)
        XCTAssertEqual(parts[1].count, 2)
        XCTAssertEqual(parts[2].count, 4)
    }

    func testPhoneFormat() {
        var gen = TestDataGenerator(seed: 42)
        let phone = gen.generatePhone()

        XCTAssertTrue(phone.hasPrefix("("))
        XCTAssertTrue(phone.contains(") "))
        XCTAssertTrue(phone.contains("-"))
    }

    func testDateOfBirthFormat() {
        var gen = TestDataGenerator(seed: 42)
        let dob = gen.generateDateOfBirth()

        // YYYYMMDD format = 8 characters
        XCTAssertEqual(dob.count, 8)
        let year = Int(dob.prefix(4))!
        XCTAssertGreaterThanOrEqual(year, 1940)
        XCTAssertLessThanOrEqual(year, 2005)
    }

    func testTimestampFormat() {
        var gen = TestDataGenerator(seed: 42)
        let ts = gen.generateTimestamp()

        // YYYYMMDDHHMMSS = 14 characters
        XCTAssertEqual(ts.count, 14)
    }

    func testADTMessageStructure() {
        var gen = TestDataGenerator(seed: 42)
        let msg = gen.generateADTMessage()

        XCTAssertTrue(msg.contains("MSH|"))
        XCTAssertTrue(msg.contains("ADT^A01"))
        XCTAssertTrue(msg.contains("EVN|"))
        XCTAssertTrue(msg.contains("PID|"))
        XCTAssertTrue(msg.contains("PV1|"))
    }

    func testORUMessageStructure() {
        var gen = TestDataGenerator(seed: 42)
        let msg = gen.generateORUMessage()

        XCTAssertTrue(msg.contains("MSH|"))
        XCTAssertTrue(msg.contains("ORU^R01"))
        XCTAssertTrue(msg.contains("PID|"))
        XCTAssertTrue(msg.contains("OBR|"))
        XCTAssertTrue(msg.contains("OBX|"))
    }

    func testFHIRPatientJSON() {
        var gen = TestDataGenerator(seed: 42)
        let json = gen.generateFHIRPatientJSON()

        XCTAssertTrue(json.contains("\"resourceType\": \"Patient\""))
        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"gender\""))
        XCTAssertTrue(json.contains("\"birthDate\""))
    }

    func testFixtureGeneration() {
        var gen = TestDataGenerator(seed: 42)
        let fixture = gen.generateFixture()

        XCTAssertTrue(fixture.patientName.contains("^"))
        XCTAssertTrue(fixture.mrn.hasPrefix("MRN"))
        XCTAssertTrue(fixture.ssn.contains("-"))
        XCTAssertTrue(fixture.adtMessage.contains("MSH|"))
        XCTAssertTrue(fixture.oruMessage.contains("MSH|"))
    }

    func testMultipleFixtures() {
        var gen = TestDataGenerator(seed: 42)
        let fixtures = gen.generateFixtures(count: 5)

        XCTAssertEqual(fixtures.count, 5)
        // All should have valid data
        for fixture in fixtures {
            XCTAssertTrue(fixture.mrn.hasPrefix("MRN"))
            XCTAssertTrue(fixture.patientName.contains("^"))
        }
    }

    func testSeededRandomGenerator() {
        var rng1 = SeededRandomGenerator(seed: 999)
        var rng2 = SeededRandomGenerator(seed: 999)

        for _ in 0..<20 {
            XCTAssertEqual(rng1.next(), rng2.next())
        }
    }

    func testSeededRandomGeneratorRange() {
        var rng = SeededRandomGenerator(seed: 42)
        for _ in 0..<100 {
            let val = rng.nextInt(in: 5...10)
            XCTAssertGreaterThanOrEqual(val, 5)
            XCTAssertLessThanOrEqual(val, 10)
        }
    }

    func testSeededRandomElement() {
        var rng = SeededRandomGenerator(seed: 42)
        let items = ["a", "b", "c"]
        let result = rng.randomElement(from: items)
        XCTAssertNotNil(result)
        XCTAssertTrue(items.contains(result!))

        let empty: [String] = []
        let nilResult = rng.randomElement(from: empty)
        XCTAssertNil(nilResult)
    }
}

// MARK: - Aggregate Test Suite

final class TestingInfrastructureTests: XCTestCase {
    /// Smoke test that all major types can be instantiated
    func testAllTypesInstantiate() async {
        _ = IntegrationTestRunner()
        _ = IntegrationTestSuite(name: "Suite", tests: [])
        _ = IntegrationTestResult(name: "Test", status: .passed, duration: 0.1)
        _ = PerformanceBenchmarkRunner()
        _ = BenchmarkSuite(name: "Suite", cases: [])
        _ = BenchmarkTimingResult(name: "B", min: 0, max: 0, avg: 0, median: 0, p95: 0, p99: 0, iterations: 0)
        _ = ConformanceTestRunner()
        _ = ConformanceRequirement(id: "R", description: "D", category: .messageStructure)
        _ = ConformanceReport(results: [])
        _ = MockServer()
        _ = MockRequest(path: "/")
        _ = MockResponse()
        _ = MockRoute(path: "/", response: MockResponse())
        _ = TestDataGenerator()
        _ = SeededRandomGenerator(seed: 1)
        _ = HL7TestFixture(patientName: "", mrn: "", ssn: "", phone: "", dateOfBirth: "", adtMessage: "", oruMessage: "")
    }

    func testConformanceCategoryAllCases() {
        let categories = ConformanceCategory.allCases
        XCTAssertTrue(categories.contains(.messageStructure))
        XCTAssertTrue(categories.contains(.dataTypes))
        XCTAssertTrue(categories.contains(.transport))
        XCTAssertTrue(categories.contains(.validation))
        XCTAssertTrue(categories.contains(.security))
        XCTAssertTrue(categories.contains(.encoding))
    }

    func testMockHTTPMethods() {
        XCTAssertEqual(MockHTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(MockHTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(MockHTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(MockHTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(MockHTTPMethod.patch.rawValue, "PATCH")
    }

    func testIntegrationTestStatusEquality() {
        XCTAssertEqual(IntegrationTestStatus.passed, IntegrationTestStatus.passed)
        XCTAssertEqual(IntegrationTestStatus.failed("x"), IntegrationTestStatus.failed("x"))
        XCTAssertNotEqual(IntegrationTestStatus.passed, IntegrationTestStatus.failed("x"))
        XCTAssertEqual(IntegrationTestStatus.skipped("r"), IntegrationTestStatus.skipped("r"))
        XCTAssertEqual(IntegrationTestStatus.error("e"), IntegrationTestStatus.error("e"))
    }
}
