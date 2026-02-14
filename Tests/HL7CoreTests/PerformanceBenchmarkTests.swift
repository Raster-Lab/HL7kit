/// PerformanceBenchmarkTests.swift
/// Comprehensive cross-module performance benchmarking for HL7kit
///
/// Tests cover HL7 v2.x, HL7 v3.x, and FHIR modules with throughput,
/// latency, memory, and concurrency benchmarks.

import XCTest
@testable import HL7Core
@testable import HL7v2Kit
@testable import HL7v3Kit
@testable import FHIRkit
import Foundation

// MARK: - Cross-Module Performance Benchmarks

final class CrossModulePerformanceBenchmarkTests: XCTestCase {

    // MARK: - Test Data

    /// Sample HL7 v2.x ADT^A01 message
    private let sampleV2ADT = [
        "MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20231115120000||ADT^A01|MSG00001|P|2.5.1",
        "EVN|A01|20231115120000",
        "PID|1||12345^^^HOSPITAL^MR||DOE^JOHN^A||19800115|M|||123 MAIN ST^^ANYTOWN^CA^12345^USA|||||||12345678",
        "PV1|1|I|2000^2012^01||||004777^SMITH^JOHN^A|||SUR||||ADM|A0|"
    ].joined(separator: "\r")

    /// Sample HL7 v2.x ORU^R01 message
    private let sampleV2ORU = [
        "MSH|^~\\&|LAB_SYS|HOSPITAL|EMR|HOSPITAL|20231115130000||ORU^R01|MSG00002|P|2.5.1",
        "PID|1||67890^^^HOSPITAL^MR||SMITH^JANE^B||19750320|F|||456 OAK AVE^^SOMETOWN^NY^54321^USA",
        "OBR|1|ORDER123|RESULT123|CBC^COMPLETE BLOOD COUNT|||20231115120000",
        "OBX|1|NM|WBC^WHITE BLOOD COUNT||7.5|10*3/uL|4.0-11.0|N|||F",
        "OBX|2|NM|RBC^RED BLOOD COUNT||4.8|10*6/uL|4.2-5.9|N|||F",
        "OBX|3|NM|HGB^HEMOGLOBIN||14.5|g/dL|12.0-16.0|N|||F"
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

    /// Sample FHIR Bundle JSON
    private let sampleFHIRBundleJSON = """
        {
            "resourceType": "Bundle",
            "type": "searchset",
            "total": 5,
            "entry": [
                {"resource": {"resourceType": "Patient", "id": "p1", "gender": "male"}},
                {"resource": {"resourceType": "Patient", "id": "p2", "gender": "female"}},
                {"resource": {"resourceType": "Patient", "id": "p3", "gender": "male"}},
                {"resource": {"resourceType": "Patient", "id": "p4", "gender": "female"}},
                {"resource": {"resourceType": "Patient", "id": "p5", "gender": "male"}}
            ]
        }
        """.data(using: .utf8)!

    /// Generate a large v2 message with many OBX segments
    private func generateLargeV2Message(segmentCount: Int) -> String {
        var segments = [
            "MSH|^~\\&|LAB|FAC|EMR|FAC|20231115120000||ORU^R01|MSG99999|P|2.5.1",
            "PID|1||99999^^^HOSPITAL^MR||PATIENT^TEST||19900101|M",
            "OBR|1|ORD1|RES1|PANEL^TEST|||20231115120000"
        ]
        for i in 1...segmentCount {
            segments.append("OBX|\(i)|NM|TEST\(i)^VALUE \(i)||\(Double(i) * 1.1)|mg/dL|0-100|N|||F")
        }
        return segments.joined(separator: "\r")
    }

    /// Generate a large CDA XML document with multiple sections
    private func generateLargeCDADocument(sectionCount: Int) -> String {
        var sections = ""
        for i in 1...sectionCount {
            sections += """
                  <component>
                    <section>
                      <code code="\(10000 + i)" codeSystem="2.16.840.1.113883.6.1" displayName="Section \(i)"/>
                      <title>Test Section \(i)</title>
                      <text>Content for section \(i) with some detailed clinical information.</text>
                    </section>
                  </component>

            """
        }
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <ClinicalDocument xmlns="urn:hl7-org:v3">
              <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
              <id root="2.16.840.1.113883.19.5.99999.1" extension="large-doc"/>
              <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
              <effectiveTime value="20231115120000"/>
              <component>
                <structuredBody>
            \(sections)    </structuredBody>
              </component>
            </ClinicalDocument>
            """
    }

    // MARK: - HL7 v2.x Throughput Benchmarks

    func testV2ParsingThroughput() throws {
        let parser = HL7v2Parser()
        let iterations = 1000

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(sampleV2ADT)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [v2.x] ADT^A01 Throughput: \(String(format: "%.0f", throughput)) msg/s (\(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 100, "v2.x ADT parsing throughput should be >100 msg/s")
    }

    func testV2LargeMessageThroughput() throws {
        let parser = HL7v2Parser()
        let largeMessage = generateLargeV2Message(segmentCount: 100)
        let iterations = 200

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(largeMessage)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [v2.x] Large ORU (100 OBX) Throughput: \(String(format: "%.0f", throughput)) msg/s (\(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 50, "v2.x large message parsing throughput should be >50 msg/s")
    }

    func testV2MixedWorkloadThroughput() throws {
        let parser = HL7v2Parser()
        let messages = [sampleV2ADT, sampleV2ORU, generateLargeV2Message(segmentCount: 20)]
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

        print("📊 [v2.x] Mixed Workload Throughput: \(String(format: "%.0f", throughput)) msg/s (\(parsedCount) msgs in \(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 100, "v2.x mixed workload throughput should be >100 msg/s")
    }

    // MARK: - HL7 v3.x XML Parsing Benchmarks

    func testV3XMLParsingThroughput() throws {
        let parser = HL7v3XMLParser()
        let data = Data(sampleV3CDA.utf8)
        let iterations = 500

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(data)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [v3.x] CDA Document Throughput: \(String(format: "%.0f", throughput)) docs/s (\(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 50, "v3.x CDA parsing throughput should be >50 docs/s")
    }

    func testV3LargeDocumentParsing() throws {
        let parser = HL7v3XMLParser()
        let largeCDA = generateLargeCDADocument(sectionCount: 50)
        let data = Data(largeCDA.utf8)
        let iterations = 100

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parse(data)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [v3.x] Large CDA (50 sections) Throughput: \(String(format: "%.0f", throughput)) docs/s (\(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 10, "v3.x large CDA parsing throughput should be >10 docs/s")
    }

    // MARK: - FHIR JSON Parsing Benchmarks

    func testFHIRJSONParsingThroughput() throws {
        let parser = OptimizedJSONParser()
        let iterations = 1000

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parseResource(from: sampleFHIRPatientJSON)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [FHIR] Patient JSON Throughput: \(String(format: "%.0f", throughput)) resources/s (\(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 100, "FHIR JSON parsing throughput should be >100 resources/s")
    }

    func testFHIRBundleParsingThroughput() throws {
        let parser = OptimizedJSONParser()
        let iterations = 500

        let start = Date()
        for _ in 0..<iterations {
            _ = try parser.parseBundle(from: sampleFHIRBundleJSON)
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [FHIR] Bundle (5 entries) Throughput: \(String(format: "%.0f", throughput)) bundles/s (\(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 100, "FHIR Bundle parsing throughput should be >100 bundles/s")
    }

    // MARK: - Memory Profiling

    func testV2MemoryProfile() throws {
        let parser = HL7v2Parser()
        let beforeMemory = MemoryUsage.current()

        for i in 0..<500 {
            let message = sampleV2ADT.replacingOccurrences(of: "MSG00001", with: "MSG\(String(format: "%05d", i))")
            _ = try parser.parse(message)
        }

        let afterMemory = MemoryUsage.current()
        if let before = beforeMemory, let after = afterMemory {
            let memoryIncrease = after.resident - before.resident
            let mbIncrease = Double(memoryIncrease) / (1024 * 1024)
            print("📊 [v2.x] Memory for 500 ADT messages: \(String(format: "%.2f", mbIncrease)) MB")
        }
    }

    func testV3MemoryProfile() throws {
        let parser = HL7v3XMLParser()
        let data = Data(sampleV3CDA.utf8)
        let beforeMemory = MemoryUsage.current()

        for _ in 0..<200 {
            _ = try parser.parse(data)
        }

        let afterMemory = MemoryUsage.current()
        if let before = beforeMemory, let after = afterMemory {
            let memoryIncrease = after.resident - before.resident
            let mbIncrease = Double(memoryIncrease) / (1024 * 1024)
            print("📊 [v3.x] Memory for 200 CDA documents: \(String(format: "%.2f", mbIncrease)) MB")
        }
    }

    func testFHIRMemoryProfile() throws {
        let parser = OptimizedJSONParser()
        let beforeMemory = MemoryUsage.current()

        for _ in 0..<500 {
            _ = try parser.parseResource(from: sampleFHIRPatientJSON)
        }

        let afterMemory = MemoryUsage.current()
        if let before = beforeMemory, let after = afterMemory {
            let memoryIncrease = after.resident - before.resident
            let mbIncrease = Double(memoryIncrease) / (1024 * 1024)
            print("📊 [FHIR] Memory for 500 Patient resources: \(String(format: "%.2f", mbIncrease)) MB")
        }
    }

    // MARK: - Concurrent Parsing Benchmarks

    func testV2ConcurrentThroughput() async throws {
        let concurrency = 4
        let iterationsPerTask = 250
        let message = sampleV2ADT

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

        print("📊 [v2.x] Concurrent (\(concurrency) tasks) Throughput: \(String(format: "%.0f", throughput)) msg/s (\(totalMessages) msgs in \(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 100, "v2.x concurrent parsing throughput should be >100 msg/s")
    }

    func testV3ConcurrentThroughput() async throws {
        let concurrency = 4
        let iterationsPerTask = 100
        let cdaData = Data(sampleV3CDA.utf8)

        let start = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    let parser = HL7v3XMLParser()
                    for _ in 0..<iterationsPerTask {
                        _ = try? parser.parse(cdaData)
                    }
                }
            }
        }
        let duration = Date().timeIntervalSince(start)
        let totalDocs = concurrency * iterationsPerTask
        let throughput = Double(totalDocs) / duration

        print("📊 [v3.x] Concurrent (\(concurrency) tasks) Throughput: \(String(format: "%.0f", throughput)) docs/s (\(totalDocs) docs in \(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 50, "v3.x concurrent parsing throughput should be >50 docs/s")
    }

    func testFHIRConcurrentThroughput() async throws {
        let concurrency = 4
        let iterationsPerTask = 250
        let patientData = sampleFHIRPatientJSON

        let start = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrency {
                group.addTask {
                    let parser = OptimizedJSONParser()
                    for _ in 0..<iterationsPerTask {
                        _ = try? parser.parseResource(from: patientData)
                    }
                }
            }
        }
        let duration = Date().timeIntervalSince(start)
        let totalResources = concurrency * iterationsPerTask
        let throughput = Double(totalResources) / duration

        print("📊 [FHIR] Concurrent (\(concurrency) tasks) Throughput: \(String(format: "%.0f", throughput)) resources/s (\(totalResources) resources in \(String(format: "%.2f", duration))s)")
        XCTAssertGreaterThan(throughput, 100, "FHIR concurrent parsing throughput should be >100 resources/s")
    }

    // MARK: - Latency Benchmarks

    func testV2ParsingLatency() throws {
        let parser = HL7v2Parser()
        let iterations = 500
        var durations: [TimeInterval] = []

        for _ in 0..<iterations {
            let start = Date()
            _ = try parser.parse(sampleV2ADT)
            durations.append(Date().timeIntervalSince(start))
        }

        durations.sort()
        let p50 = durations[Int(Double(iterations) * 0.50)]
        let p95 = durations[Int(Double(iterations) * 0.95)]
        let p99 = durations[Int(Double(iterations) * 0.99)]

        print("📊 [v2.x] ADT Latency: p50=\(String(format: "%.0f", p50 * 1_000_000))μs p95=\(String(format: "%.0f", p95 * 1_000_000))μs p99=\(String(format: "%.0f", p99 * 1_000_000))μs")
        XCTAssertLessThan(p50, 0.01, "v2.x p50 latency should be <10ms")
    }

    func testV3ParsingLatency() throws {
        let parser = HL7v3XMLParser()
        let data = Data(sampleV3CDA.utf8)
        let iterations = 300
        var durations: [TimeInterval] = []

        for _ in 0..<iterations {
            let start = Date()
            _ = try parser.parse(data)
            durations.append(Date().timeIntervalSince(start))
        }

        durations.sort()
        let p50 = durations[Int(Double(iterations) * 0.50)]
        let p95 = durations[Int(Double(iterations) * 0.95)]
        let p99 = durations[Int(Double(iterations) * 0.99)]

        print("📊 [v3.x] CDA Latency: p50=\(String(format: "%.0f", p50 * 1_000_000))μs p95=\(String(format: "%.0f", p95 * 1_000_000))μs p99=\(String(format: "%.0f", p99 * 1_000_000))μs")
        XCTAssertLessThan(p50, 0.01, "v3.x p50 latency should be <10ms")
    }

    func testFHIRParsingLatency() throws {
        let parser = OptimizedJSONParser()
        let iterations = 500
        var durations: [TimeInterval] = []

        for _ in 0..<iterations {
            let start = Date()
            _ = try parser.parseResource(from: sampleFHIRPatientJSON)
            durations.append(Date().timeIntervalSince(start))
        }

        durations.sort()
        let p50 = durations[Int(Double(iterations) * 0.50)]
        let p95 = durations[Int(Double(iterations) * 0.95)]
        let p99 = durations[Int(Double(iterations) * 0.99)]

        print("📊 [FHIR] Patient JSON Latency: p50=\(String(format: "%.0f", p50 * 1_000_000))μs p95=\(String(format: "%.0f", p95 * 1_000_000))μs p99=\(String(format: "%.0f", p99 * 1_000_000))μs")
        XCTAssertLessThan(p50, 0.01, "FHIR p50 latency should be <10ms")
    }

    // MARK: - Object Pool Benchmarks

    func testV2ObjectPoolEfficiency() async throws {
        let pool = SegmentPool(maxPoolSize: 50)
        await pool.preallocate(20)

        var storages: [SegmentPool.SegmentStorage] = []
        for _ in 0..<100 {
            let storage = await pool.acquire()
            storages.append(storage)
        }
        for storage in storages {
            await pool.release(storage)
        }

        let stats = await pool.statistics()
        print("📊 [v2.x] Segment Pool: reuse=\(String(format: "%.1f%%", stats.reuseRate * 100)) acquires=\(stats.acquireCount) allocs=\(stats.allocationCount)")
        XCTAssertGreaterThan(stats.acquireCount, 0, "Pool should have acquires")
    }

    func testV3ObjectPoolEfficiency() async throws {
        let pool = XMLElementPool(maxPoolSize: 50)
        await pool.preallocate(20)

        var storages: [XMLElementPool.ElementStorage] = []
        for _ in 0..<100 {
            let storage = await pool.acquire()
            storages.append(storage)
        }
        for storage in storages {
            await pool.release(storage)
        }

        let stats = await pool.statistics()
        print("📊 [v3.x] XMLElement Pool: reuse=\(String(format: "%.1f%%", stats.reuseRate * 100)) acquires=\(stats.acquireCount) allocs=\(stats.allocationCount)")
        XCTAssertGreaterThan(stats.acquireCount, 0, "Pool should have acquires")
    }

    func testFHIRCacheEfficiency() async throws {
        let cache = FHIRResourceCache(maxSize: 100, ttl: 60)

        // Populate cache
        for i in 0..<50 {
            let data = Data("{\"id\":\"\(i)\"}".utf8)
            await cache.put(resourceType: "Patient", id: "p\(i)", data: data)
        }

        // Read mix of hits and misses
        for i in 0..<100 {
            _ = await cache.get(resourceType: "Patient", id: "p\(i % 70)")
        }

        let stats = await cache.statistics()
        print("📊 [FHIR] Cache: entries=\(stats.totalEntries) hits=\(stats.hits) misses=\(stats.misses) hitRate=\(String(format: "%.1f%%", stats.hitRate * 100))")
        XCTAssertGreaterThan(stats.hits, 0, "Cache should have hits")
    }

    // MARK: - String Interning Benchmarks

    func testV2StringInterningEfficiency() async throws {
        let interner = StringInterner()
        let commonIDs = ["MSH", "PID", "PV1", "OBX", "OBR", "EVN", "ORC", "NK1", "AL1", "DG1"]

        for _ in 0..<500 {
            for id in commonIDs {
                _ = await interner.intern(id)
            }
        }

        let stats = await interner.statistics()
        print("📊 [v2.x] String Interning: interned=\(stats.internedCount) hitRate=\(String(format: "%.1f%%", stats.hitRate * 100))")
        XCTAssertGreaterThan(stats.hitRate, 0.90, "String interning hit rate should be >90%")
    }

    func testV3StringInterningEfficiency() async throws {
        let interner = V3StringInterner()
        let commonNames = ["ClinicalDocument", "component", "section", "code", "title", "text",
                           "templateId", "id", "effectiveTime", "patient", "name", "entry"]

        for _ in 0..<500 {
            for name in commonNames {
                _ = await interner.intern(name)
            }
        }

        let stats = await interner.statistics()
        print("📊 [v3.x] String Interning: interned=\(stats.internedCount) hitRate=\(String(format: "%.1f%%", stats.hitRate * 100))")
        XCTAssertGreaterThan(stats.hitRate, 0.90, "v3 string interning hit rate should be >90%")
    }

    // MARK: - XCTest measure() Benchmarks

    func testMeasureV2Parse() throws {
        let parser = HL7v2Parser()
        measure {
            for _ in 0..<100 {
                _ = try? parser.parse(self.sampleV2ADT)
            }
        }
    }

    func testMeasureV3Parse() throws {
        let parser = HL7v3XMLParser()
        let data = Data(sampleV3CDA.utf8)
        measure {
            for _ in 0..<50 {
                _ = try? parser.parse(data)
            }
        }
    }

    func testMeasureFHIRParse() {
        let parser = OptimizedJSONParser()
        measure {
            for _ in 0..<100 {
                _ = try? parser.parseResource(from: self.sampleFHIRPatientJSON)
            }
        }
    }

    // MARK: - BenchmarkRunner Integration

    func testBenchmarkRunnerV2() async throws {
        let runner = BenchmarkRunner()
        let parser = HL7v2Parser()
        let message = sampleV2ADT

        let result = try await runner.run(
            name: "v2.x ADT^A01 Parse",
            config: BenchmarkConfig(warmupIterations: 5, measuredIterations: 50)
        ) {
            _ = try parser.parse(message)
        }

        print("📊 [BenchmarkRunner] \(result.name):")
        for metric in result.metrics {
            print("   - \(metric.name): \(String(format: "%.6f", metric.value)) \(metric.unit)")
        }

        XCTAssertFalse(result.metrics.isEmpty, "Benchmark should produce metrics")
    }

    func testBenchmarkRunnerV3() async throws {
        let runner = BenchmarkRunner()
        let parser = HL7v3XMLParser()
        let data = Data(sampleV3CDA.utf8)

        let result = try await runner.run(
            name: "v3.x CDA Parse",
            config: BenchmarkConfig(warmupIterations: 5, measuredIterations: 50)
        ) {
            _ = try parser.parse(data)
        }

        print("📊 [BenchmarkRunner] \(result.name):")
        for metric in result.metrics {
            print("   - \(metric.name): \(String(format: "%.6f", metric.value)) \(metric.unit)")
        }

        XCTAssertFalse(result.metrics.isEmpty, "Benchmark should produce metrics")
    }

    func testBenchmarkRunnerFHIR() async throws {
        let runner = BenchmarkRunner()
        let parser = OptimizedJSONParser()
        let data = sampleFHIRPatientJSON

        let result = try await runner.run(
            name: "FHIR Patient JSON Parse",
            config: BenchmarkConfig(warmupIterations: 5, measuredIterations: 50)
        ) {
            _ = try parser.parseResource(from: data)
        }

        print("📊 [BenchmarkRunner] \(result.name):")
        for metric in result.metrics {
            print("   - \(metric.name): \(String(format: "%.6f", metric.value)) \(metric.unit)")
        }

        XCTAssertFalse(result.metrics.isEmpty, "Benchmark should produce metrics")
    }

    // MARK: - Scalability Benchmarks

    func testV2ScalabilityWithMessageSize() throws {
        let parser = HL7v2Parser()
        let sizes = [10, 50, 100, 200]
        let iterations = 100

        print("📊 [v2.x] Scalability by Message Size:")
        for size in sizes {
            let message = generateLargeV2Message(segmentCount: size)
            let start = Date()
            for _ in 0..<iterations {
                _ = try parser.parse(message)
            }
            let duration = Date().timeIntervalSince(start)
            let throughput = Double(iterations) / duration
            print("   - \(size) segments: \(String(format: "%.0f", throughput)) msg/s")
        }
    }

    func testV3ScalabilityWithDocumentSize() throws {
        let parser = HL7v3XMLParser()
        let sizes = [5, 20, 50, 100]
        let iterations = 50

        print("📊 [v3.x] Scalability by Document Size:")
        for size in sizes {
            let doc = generateLargeCDADocument(sectionCount: size)
            let data = Data(doc.utf8)
            let start = Date()
            for _ in 0..<iterations {
                _ = try parser.parse(data)
            }
            let duration = Date().timeIntervalSince(start)
            let throughput = Double(iterations) / duration
            print("   - \(size) sections: \(String(format: "%.0f", throughput)) docs/s")
        }
    }

    // MARK: - FHIR Streaming Performance

    func testFHIRStreamingBundlePerformance() async throws {
        let processor = StreamingBundleProcessor()
        let iterations = 200

        let start = Date()
        for _ in 0..<iterations {
            _ = try await processor.processBundle(data: sampleFHIRBundleJSON) { _ in }
        }
        let duration = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / duration

        print("📊 [FHIR] Streaming Bundle Throughput: \(String(format: "%.0f", throughput)) bundles/s")
        XCTAssertGreaterThan(throughput, 50, "FHIR streaming bundle throughput should be >50 bundles/s")
    }

    // MARK: - Cross-Module Comparison Summary

    func testCrossModulePerformanceSummary() throws {
        let v2Parser = HL7v2Parser()
        let v3Parser = HL7v3XMLParser()
        let fhirParser = OptimizedJSONParser()
        let iterations = 300

        // v2
        let v2Start = Date()
        for _ in 0..<iterations { _ = try v2Parser.parse(sampleV2ADT) }
        let v2Duration = Date().timeIntervalSince(v2Start)
        let v2Throughput = Double(iterations) / v2Duration

        // v3
        let v3Data = Data(sampleV3CDA.utf8)
        let v3Start = Date()
        for _ in 0..<iterations { _ = try v3Parser.parse(v3Data) }
        let v3Duration = Date().timeIntervalSince(v3Start)
        let v3Throughput = Double(iterations) / v3Duration

        // FHIR
        let fhirStart = Date()
        for _ in 0..<iterations { _ = try fhirParser.parseResource(from: sampleFHIRPatientJSON) }
        let fhirDuration = Date().timeIntervalSince(fhirStart)
        let fhirThroughput = Double(iterations) / fhirDuration

        print("═══════════════════════════════════════════")
        print("  HL7kit Cross-Module Performance Summary")
        print("═══════════════════════════════════════════")
        print("  Module     │ Throughput       │ Avg Latency")
        print("  ───────────┼──────────────────┼─────────────")
        print("  HL7 v2.x   │ \(String(format: "%8.0f", v2Throughput)) msg/s   │ \(String(format: "%.0f", (v2Duration / Double(iterations)) * 1_000_000)) μs")
        print("  HL7 v3.x   │ \(String(format: "%8.0f", v3Throughput)) docs/s  │ \(String(format: "%.0f", (v3Duration / Double(iterations)) * 1_000_000)) μs")
        print("  FHIR       │ \(String(format: "%8.0f", fhirThroughput)) res/s   │ \(String(format: "%.0f", (fhirDuration / Double(iterations)) * 1_000_000)) μs")
        print("═══════════════════════════════════════════")

        XCTAssertGreaterThan(v2Throughput, 100, "v2 should meet minimum throughput")
        XCTAssertGreaterThan(v3Throughput, 50, "v3 should meet minimum throughput")
        XCTAssertGreaterThan(fhirThroughput, 100, "FHIR should meet minimum throughput")
    }
}
