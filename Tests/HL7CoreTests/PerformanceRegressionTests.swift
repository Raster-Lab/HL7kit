/// PerformanceRegressionTests.swift
/// Phase 7.7 performance regression benchmark suite for HL7kit
///
/// Defines baselines for throughput, latency, memory, and concurrency
/// across all modules and validates that performance does not regress.

import XCTest
@testable import HL7Core
@testable import HL7v2Kit
@testable import HL7v3Kit
@testable import FHIRkit
import Foundation

// MARK: - Performance Regression Benchmarks

final class PerformanceRegressionTests: XCTestCase {

    // MARK: - Regression Baseline Infrastructure

    /// Defines an expected performance baseline for a specific metric.
    private struct PerformanceBaseline {
        let name: String
        let metric: String
        let minimumAcceptable: Double
        let expectedBaseline: Double
        let unit: String
    }

    /// Baselines covering all modules for regression detection.
    private static let baselines: [PerformanceBaseline] = [
        PerformanceBaseline(name: "v2 parsing throughput",      metric: "throughput",    minimumAcceptable: 100,    expectedBaseline: 1000,   unit: "msg/s"),
        PerformanceBaseline(name: "v3 parsing throughput",      metric: "throughput",    minimumAcceptable: 50,     expectedBaseline: 200,    unit: "docs/s"),
        PerformanceBaseline(name: "FHIR parsing throughput",    metric: "throughput",    minimumAcceptable: 100,    expectedBaseline: 500,    unit: "res/s"),
        PerformanceBaseline(name: "v2 latency p99",             metric: "latency_p99",   minimumAcceptable: 50,     expectedBaseline: 10,     unit: "ms"),
        PerformanceBaseline(name: "v3 latency p99",             metric: "latency_p99",   minimumAcceptable: 100,    expectedBaseline: 20,     unit: "ms"),
        PerformanceBaseline(name: "FHIR latency p99",           metric: "latency_p99",   minimumAcceptable: 50,     expectedBaseline: 10,     unit: "ms"),
        PerformanceBaseline(name: "MLLP framing throughput",    metric: "throughput",    minimumAcceptable: 50_000, expectedBaseline: 100_000, unit: "frames/s"),
        PerformanceBaseline(name: "Memory per 1000 v2 msgs",   metric: "memory_mb",     minimumAcceptable: 100,    expectedBaseline: 50,     unit: "MB"),
        PerformanceBaseline(name: "Concurrent v2 throughput",   metric: "throughput",    minimumAcceptable: 100,    expectedBaseline: 1000,   unit: "msg/s"),
        PerformanceBaseline(name: "String interning hit rate",  metric: "hit_rate",      minimumAcceptable: 90,     expectedBaseline: 98,     unit: "%"),
    ]

    // MARK: - Test Data

    /// Sample HL7 v2.x ADT^A01 message
    private let sampleV2ADT = [
        "MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20231115120000||ADT^A01|MSG00001|P|2.5.1",
        "EVN|A01|20231115120000",
        "PID|1||12345^^^HOSPITAL^MR||DOE^JOHN^A||19800115|M|||123 MAIN ST^^ANYTOWN^CA^12345^USA|||||||12345678",
        "PV1|1|I|2000^2012^01||||004777^SMITH^JOHN^A|||SUR||||ADM|A0|"
    ].joined(separator: "\r")

    /// Sample HL7 v3.x CDA XML document
    private let sampleV3CDA = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
          <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
          <id root="2.16.840.1.113883.19.5.99999.1" extension="doc-1"/>
          <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" displayName="Summarization of Episode Note"/>
          <title>Patient Summary</title>
          <effectiveTime value="20231115120000"/>
          <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
          <recordTarget>
            <patientRole>
              <id root="2.16.840.1.113883.19.5" extension="12345"/>
              <patient>
                <name><given>John</given><family>Doe</family></name>
                <administrativeGenderCode code="M" codeSystem="2.16.840.1.113883.5.1"/>
                <birthTime value="19800115"/>
              </patient>
            </patientRole>
          </recordTarget>
          <component>
            <structuredBody>
              <component>
                <section>
                  <templateId root="2.16.840.1.113883.10.20.22.2.6.1"/>
                  <code code="48765-2" codeSystem="2.16.840.1.113883.6.1" displayName="Allergies"/>
                  <title>Allergies and Adverse Reactions</title>
                  <text>No known allergies</text>
                </section>
              </component>
            </structuredBody>
          </component>
        </ClinicalDocument>
        """

    /// Sample FHIR Patient JSON
    private let sampleFHIRPatientJSON = """
        {
            "resourceType": "Patient",
            "id": "test-patient-1",
            "meta": {"versionId": "1", "lastUpdated": "2023-11-15T12:00:00Z"},
            "name": [{"family": "Doe", "given": ["John", "A"]}],
            "gender": "male",
            "birthDate": "1980-01-15",
            "address": [{"line": ["123 Main St"], "city": "Anytown", "state": "CA", "postalCode": "12345"}],
            "identifier": [{"system": "http://hospital.example.org/mrn", "value": "12345"}]
        }
        """.data(using: .utf8)!

    /// Sample FHIR Bundle JSON with 3 Patient entries
    private let sampleFHIRBundleJSON = """
        {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": 3,
            "entry": [
                {"resource": {"resourceType": "Patient", "id": "p1", "gender": "male"}},
                {"resource": {"resourceType": "Patient", "id": "p2", "gender": "female"}},
                {"resource": {"resourceType": "Patient", "id": "p3", "gender": "male"}}
            ]
        }
        """.data(using: .utf8)!

    // MARK: - 1. V2 Parsing Throughput Baseline

    func testV2ParsingThroughputBaseline() throws {
        let parser = HL7v2Parser()
        let iterations = 1000

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(sampleV2ADT)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        let baseline = Self.baselines.first { $0.name == "v2 parsing throughput" }!
        let status = throughput >= baseline.expectedBaseline ? "EXCEEDS" : (throughput >= baseline.minimumAcceptable ? "MEETS" : "BELOW")
        print("📊 [Regression] v2 Throughput: \(String(format: "%.0f", throughput)) msg/s (baseline: \(String(format: "%.0f", baseline.expectedBaseline)) msg/s) [\(status)]")

        XCTAssertGreaterThan(throughput, baseline.minimumAcceptable, "v2 parsing throughput should be >\(Int(baseline.minimumAcceptable)) msg/s")
    }

    // MARK: - 2. V3 XML Parsing Throughput Baseline

    func testV3XMLParsingThroughputBaseline() throws {
        let parser = HL7v3XMLParser()
        let data = Data(sampleV3CDA.utf8)
        let iterations = 500

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(data)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        let baseline = Self.baselines.first { $0.name == "v3 parsing throughput" }!
        let status = throughput >= baseline.expectedBaseline ? "EXCEEDS" : (throughput >= baseline.minimumAcceptable ? "MEETS" : "BELOW")
        print("📊 [Regression] v3 Throughput: \(String(format: "%.0f", throughput)) docs/s (baseline: \(String(format: "%.0f", baseline.expectedBaseline)) docs/s) [\(status)]")

        XCTAssertGreaterThan(throughput, baseline.minimumAcceptable, "v3 parsing throughput should be >\(Int(baseline.minimumAcceptable)) docs/s")
    }

    // MARK: - 3. FHIR Serialization Throughput Baseline

    func testFHIRSerializationThroughputBaseline() throws {
        let parser = OptimizedJSONParser()
        let iterations = 500

        let start = Date()
        for _ in 0..<iterations {
            let parsed = try parser.parseResource(from: sampleFHIRPatientJSON)
            _ = try JSONSerialization.data(withJSONObject: parsed, options: [])
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        let baseline = Self.baselines.first { $0.name == "FHIR parsing throughput" }!
        let status = throughput >= baseline.expectedBaseline ? "EXCEEDS" : (throughput >= baseline.minimumAcceptable ? "MEETS" : "BELOW")
        print("📊 [Regression] FHIR Parse+Encode Throughput: \(String(format: "%.0f", throughput)) res/s (baseline: \(String(format: "%.0f", baseline.expectedBaseline)) res/s) [\(status)]")

        XCTAssertGreaterThan(throughput, baseline.minimumAcceptable, "FHIR serialization throughput should be >\(Int(baseline.minimumAcceptable)) res/s")
    }

    // MARK: - 4. Memory Profile Large Volume

    func testMemoryProfileLargeVolume() throws {
        let parser = HL7v2Parser()
        let messageCount = 1000
        let beforeMemory = MemoryUsage.current()

        for i in 0..<messageCount {
            let message = sampleV2ADT.replacingOccurrences(of: "MSG00001", with: "MSG\(String(format: "%05d", i))")
            _ = try parser.parse(message)
        }

        let afterMemory = MemoryUsage.current()
        if let before = beforeMemory, let after = afterMemory {
            let memoryIncrease = after.resident - before.resident
            let mbIncrease = Double(memoryIncrease) / (1024 * 1024)
            let baseline = Self.baselines.first { $0.name == "Memory per 1000 v2 msgs" }!
            let status = mbIncrease <= baseline.expectedBaseline ? "EXCEEDS" : (mbIncrease <= baseline.minimumAcceptable ? "MEETS" : "ABOVE")
            print("📊 [Regression] Memory for \(messageCount) v2 messages: \(String(format: "%.2f", mbIncrease)) MB (limit: \(String(format: "%.0f", baseline.minimumAcceptable)) MB) [\(status)]")
            XCTAssertLessThan(mbIncrease, baseline.minimumAcceptable, "Memory for \(messageCount) v2 messages should be <\(Int(baseline.minimumAcceptable)) MB")
        }
    }

    // MARK: - 5. Concurrent Parsing Scalability

    func testConcurrentParsingScalability() async throws {
        let message = sampleV2ADT
        let concurrencyLevels = [2, 4, 8]
        let iterationsPerTask = 250
        var throughputs: [Int: Double] = [:]

        for concurrency in concurrencyLevels {
            let start = Date()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<concurrency {
                    group.addTask {
                        let parser = HL7v2Parser()
                        for _ in 0..<iterationsPerTask {
                            _ = try? parser.parse(message)
                        }
                    }
                }
            }
            let duration = Date().timeIntervalSince(start)
            let totalMessages = concurrency * iterationsPerTask
            let throughput = Double(totalMessages) / duration
            throughputs[concurrency] = throughput
            print("📊 [Regression] Concurrent v2 (\(concurrency) tasks): \(String(format: "%.0f", throughput)) msg/s (\(totalMessages) msgs in \(String(format: "%.2f", duration))s)")
        }

        let baseline = Self.baselines.first { $0.name == "Concurrent v2 throughput" }!
        if let t2 = throughputs[2], let t8 = throughputs[8] {
            let scalingFactor = t8 / t2
            print("📊 [Regression] Scaling factor (8 vs 2 tasks): \(String(format: "%.2f", scalingFactor))x")
            XCTAssertGreaterThan(t2, baseline.minimumAcceptable, "Concurrent v2 throughput at 2 tasks should be >\(Int(baseline.minimumAcceptable)) msg/s")
        }
    }

    // MARK: - 6. Network Transport Overhead

    func testNetworkTransportOverhead() {
        let iterations = 10_000
        let message = sampleV2ADT

        // Framing throughput
        let frameStart = Date()
        for _ in 0..<iterations {
            _ = MLLPFramer.frame(message)
        }
        let frameDuration = Date().timeIntervalSince(frameStart)
        let frameThroughput = Double(iterations) / frameDuration

        // Deframing throughput
        let framed = MLLPFramer.frame(message)
        var parser = MLLPStreamParser()
        let deframeStart = Date()
        for _ in 0..<iterations {
            parser.append(framed)
            while (try? parser.nextMessage()) != nil {}
        }
        let deframeDuration = Date().timeIntervalSince(deframeStart)
        let deframeThroughput = Double(iterations) / deframeDuration

        let baseline = Self.baselines.first { $0.name == "MLLP framing throughput" }!
        let status = frameThroughput >= baseline.expectedBaseline ? "EXCEEDS" : (frameThroughput >= baseline.minimumAcceptable ? "MEETS" : "BELOW")
        print("📊 [Regression] MLLP Frame: \(String(format: "%.0f", frameThroughput)) frames/s (baseline: \(String(format: "%.0f", baseline.minimumAcceptable)) frames/s) [\(status)]")
        print("📊 [Regression] MLLP Deframe: \(String(format: "%.0f", deframeThroughput)) frames/s")

        XCTAssertGreaterThan(frameThroughput, baseline.minimumAcceptable, "MLLP framing should be >\(Int(baseline.minimumAcceptable)) frames/s")
    }

    // MARK: - 7. Object Pool Regression Baseline

    func testObjectPoolRegressionBaseline() async throws {
        // SegmentPool reuse rate
        let segPool = SegmentPool(maxPoolSize: 50)
        await segPool.preallocate(20)

        var segStorages: [SegmentPool.SegmentStorage] = []
        for _ in 0..<100 {
            let storage = await segPool.acquire()
            segStorages.append(storage)
        }
        for storage in segStorages {
            await segPool.release(storage)
        }
        let segStats = await segPool.statistics()

        // XMLElementPool reuse rate
        let xmlPool = XMLElementPool(maxPoolSize: 50)
        await xmlPool.preallocate(20)

        var xmlStorages: [XMLElementPool.ElementStorage] = []
        for _ in 0..<100 {
            let storage = await xmlPool.acquire()
            xmlStorages.append(storage)
        }
        for storage in xmlStorages {
            await xmlPool.release(storage)
        }
        let xmlStats = await xmlPool.statistics()

        let segReuse = segStats.reuseRate * 100
        let xmlReuse = xmlStats.reuseRate * 100
        print("📊 [Regression] SegmentPool reuse: \(String(format: "%.1f", segReuse))% (acquires: \(segStats.acquireCount))")
        print("📊 [Regression] XMLElementPool reuse: \(String(format: "%.1f", xmlReuse))% (acquires: \(xmlStats.acquireCount))")

        XCTAssertGreaterThan(segReuse, 30, "SegmentPool reuse should be >30% after preallocate + release cycle")
        XCTAssertGreaterThan(xmlReuse, 30, "XMLElementPool reuse should be >30% after preallocate + release cycle")
    }

    // MARK: - 8. Streaming Bundle Performance

    func testStreamingBundlePerformance() async throws {
        let processor = StreamingBundleProcessor()
        let iterations = 200

        let start = Date()
        for _ in 0..<iterations {
            _ = try await processor.processBundle(data: sampleFHIRBundleJSON) { _ in }
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [Regression] Streaming Bundle Throughput: \(String(format: "%.0f", throughput)) bundles/s (baseline: >50 bundles/s)")
        XCTAssertGreaterThan(throughput, 50, "Streaming bundle throughput should be >50 bundles/s")
    }

    // MARK: - 9. Latency Percentile Baselines

    func testLatencyPercentileBaselines() throws {
        let v2Parser = HL7v2Parser()
        let v3Parser = HL7v3XMLParser()
        let fhirParser = OptimizedJSONParser()
        let v3Data = Data(sampleV3CDA.utf8)

        // v2 latencies
        var v2Durations: [TimeInterval] = []
        for _ in 0..<500 {
            let start = Date()
            _ = try v2Parser.parse(sampleV2ADT)
            v2Durations.append(Date().timeIntervalSince(start))
        }
        v2Durations.sort()

        // v3 latencies
        var v3Durations: [TimeInterval] = []
        for _ in 0..<300 {
            let start = Date()
            _ = try v3Parser.parse(v3Data)
            v3Durations.append(Date().timeIntervalSince(start))
        }
        v3Durations.sort()

        // FHIR latencies
        var fhirDurations: [TimeInterval] = []
        for _ in 0..<500 {
            let start = Date()
            _ = try fhirParser.parseResource(from: sampleFHIRPatientJSON)
            fhirDurations.append(Date().timeIntervalSince(start))
        }
        fhirDurations.sort()

        let v2P50  = v2Durations[Int(Double(v2Durations.count) * 0.50)] * 1000
        let v2P95  = v2Durations[Int(Double(v2Durations.count) * 0.95)] * 1000
        let v2P99  = v2Durations[Int(Double(v2Durations.count) * 0.99)] * 1000
        let v3P50  = v3Durations[Int(Double(v3Durations.count) * 0.50)] * 1000
        let v3P95  = v3Durations[Int(Double(v3Durations.count) * 0.95)] * 1000
        let v3P99  = v3Durations[Int(Double(v3Durations.count) * 0.99)] * 1000
        let fP50   = fhirDurations[Int(Double(fhirDurations.count) * 0.50)] * 1000
        let fP95   = fhirDurations[Int(Double(fhirDurations.count) * 0.95)] * 1000
        let fP99   = fhirDurations[Int(Double(fhirDurations.count) * 0.99)] * 1000

        print("📊 [Regression] Latency Percentile Summary (ms)")
        print("  ───────────┬──────────┬──────────┬──────────")
        print("  Module     │   p50    │   p95    │   p99")
        print("  ───────────┼──────────┼──────────┼──────────")
        print("  HL7 v2.x   │ \(String(format: "%7.3f", v2P50))  │ \(String(format: "%7.3f", v2P95))  │ \(String(format: "%7.3f", v2P99))")
        print("  HL7 v3.x   │ \(String(format: "%7.3f", v3P50))  │ \(String(format: "%7.3f", v3P95))  │ \(String(format: "%7.3f", v3P99))")
        print("  FHIR       │ \(String(format: "%7.3f", fP50))  │ \(String(format: "%7.3f", fP95))  │ \(String(format: "%7.3f", fP99))")
        print("  ───────────┴──────────┴──────────┴──────────")

        XCTAssertLessThan(v2P50, 10, "v2 p50 latency should be <10ms")
        XCTAssertLessThan(v3P50, 10, "v3 p50 latency should be <10ms")
        XCTAssertLessThan(fP50, 10, "FHIR p50 latency should be <10ms")
    }

    // MARK: - 10. Regression Baseline Comparison

    func testRegressionBaselineComparison() async throws {
        let runner = BenchmarkRunner()
        let v2Parser = HL7v2Parser()
        let v3Parser = HL7v3XMLParser()
        let fhirParser = OptimizedJSONParser()
        let v2Message = sampleV2ADT
        let v3Data = Data(sampleV3CDA.utf8)
        let fhirData = sampleFHIRPatientJSON

        // Run benchmarks via BenchmarkRunner
        let v2Result = try await runner.run(
            name: "v2 Regression Baseline",
            config: BenchmarkConfig(warmupIterations: 10, measuredIterations: 200)
        ) {
            _ = try v2Parser.parse(v2Message)
        }

        let v3Result = try await runner.run(
            name: "v3 Regression Baseline",
            config: BenchmarkConfig(warmupIterations: 10, measuredIterations: 200)
        ) {
            _ = try v3Parser.parse(v3Data)
        }

        let fhirResult = try await runner.run(
            name: "FHIR Regression Baseline",
            config: BenchmarkConfig(warmupIterations: 10, measuredIterations: 200)
        ) {
            _ = try fhirParser.parseResource(from: fhirData)
        }

        // Collect throughput metrics from manual measurement
        let v2Start = Date()
        for _ in 0..<500 { _ = try v2Parser.parse(v2Message) }
        let v2Throughput = 500.0 / Date().timeIntervalSince(v2Start)

        let v3Start = Date()
        for _ in 0..<300 { _ = try v3Parser.parse(v3Data) }
        let v3Throughput = 300.0 / Date().timeIntervalSince(v3Start)

        let fhirStart = Date()
        for _ in 0..<500 { _ = try fhirParser.parseResource(from: fhirData) }
        let fhirThroughput = 500.0 / Date().timeIntervalSince(fhirStart)

        // Baseline comparison table
        struct BaselineResult {
            let name: String
            let current: Double
            let target: Double
            let minimum: Double
            let unit: String
            var status: String {
                if current >= target { return "PASS" }
                if current >= minimum { return "WARN" }
                return "FAIL"
            }
        }

        let results: [BaselineResult] = [
            BaselineResult(name: "v2 throughput",   current: v2Throughput,   target: 1000,  minimum: 100,  unit: "msg/s"),
            BaselineResult(name: "v3 throughput",   current: v3Throughput,   target: 200,   minimum: 50,   unit: "docs/s"),
            BaselineResult(name: "FHIR throughput", current: fhirThroughput, target: 500,   minimum: 100,  unit: "res/s"),
        ]

        print("═══════════════════════════════════════════════════════════════")
        print("  Phase 7.7 Regression Baseline Comparison Report")
        print("═══════════════════════════════════════════════════════════════")
        print("  Benchmark        │ Current       │ Target        │ Status")
        print("  ─────────────────┼───────────────┼───────────────┼────────")
        for r in results {
            print("  \(r.name.padding(toLength: 17, withPad: " ", startingAt: 0)) │ \(String(format: "%8.0f", r.current)) \(r.unit.padding(toLength: 5, withPad: " ", startingAt: 0)) │ \(String(format: "%8.0f", r.target)) \(r.unit.padding(toLength: 5, withPad: " ", startingAt: 0)) │ \(r.status)")
        }
        print("═══════════════════════════════════════════════════════════════")

        // Print BenchmarkRunner details
        for result in [v2Result, v3Result, fhirResult] {
            print("📊 [BenchmarkRunner] \(result.name):")
            for metric in result.metrics {
                print("   - \(metric.name): \(String(format: "%.6f", metric.value)) \(metric.unit)")
            }
        }

        // Assert all minimum thresholds are met
        XCTAssertGreaterThan(v2Throughput, 100, "v2 throughput must meet minimum baseline")
        XCTAssertGreaterThan(v3Throughput, 50, "v3 throughput must meet minimum baseline")
        XCTAssertGreaterThan(fhirThroughput, 100, "FHIR throughput must meet minimum baseline")
        XCTAssertFalse(v2Result.metrics.isEmpty, "v2 benchmark should produce metrics")
        XCTAssertFalse(v3Result.metrics.isEmpty, "v3 benchmark should produce metrics")
        XCTAssertFalse(fhirResult.metrics.isEmpty, "FHIR benchmark should produce metrics")
    }
}
