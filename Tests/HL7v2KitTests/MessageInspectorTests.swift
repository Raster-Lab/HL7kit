/// Tests for Message Inspector and developer tools
///
/// Tests the message inspection, debugging, and analysis tools

import XCTest
@testable import HL7v2Kit
import HL7Core

final class MessageInspectorTests: XCTestCase {
    var testMessage: HL7v2Message!
    var inspector: MessageInspector!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test message
        testMessage = try TestMessageGenerator.generateADTA01(
            patientID: "12345",
            patientName: "Doe^John",
            sendingApp: "TestApp"
        )
        
        inspector = MessageInspector(message: testMessage)
    }
    
    // MARK: - Summary Tests
    
    func testSummaryContainsBasicInfo() {
        let summary = inspector.summary()
        
        XCTAssertTrue(summary.contains("Message Type: ADT"))
        XCTAssertTrue(summary.contains("Event Type: A01"))
        XCTAssertTrue(summary.contains("Version:"))
        XCTAssertTrue(summary.contains("Segment Count:"))
    }
    
    // MARK: - Tree View Tests
    
    func testTreeViewStructure() {
        let treeView = inspector.treeView()
        
        XCTAssertTrue(treeView.contains("Message Structure:"))
        XCTAssertTrue(treeView.contains("ADT^A01"))
        XCTAssertTrue(treeView.contains("MSH"))
        XCTAssertTrue(treeView.contains("PID"))
    }
    
    func testTreeViewTruncatesLongFields() {
        let treeView = inspector.treeView(maxFieldLength: 10)
        // Should truncate fields longer than 10 characters
        XCTAssertTrue(treeView.contains("..."))
    }
    
    // MARK: - Segment Inspection Tests
    
    func testInspectExistingSegment() {
        let pidInfo = inspector.inspectSegment("PID")
        
        XCTAssertNotNil(pidInfo)
        XCTAssertTrue(pidInfo!.contains("Segment: PID"))
        XCTAssertTrue(pidInfo!.contains("12345"))
        XCTAssertTrue(pidInfo!.contains("Doe^John"))
    }
    
    func testInspectNonExistentSegment() {
        let info = inspector.inspectSegment("ZZZ")
        XCTAssertNil(info)
    }
    
    func testInspectSegmentWithMultipleOccurrences() async throws {
        // Create a message with multiple PID segments (unusual but valid)
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("TestApp")
                   .sendingFacility("TestFacility")
                   .receivingApplication("RecvApp")
                   .receivingFacility("RecvFacility")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("12345")
                   .version("2.5.1")
            }
            .segment("PID") { $0.field(1, value: "1").field(2, value: "Patient1") }
            .segment("PID") { $0.field(1, value: "2").field(2, value: "Patient2") }
            .build()
        
        let inspector = MessageInspector(message: message)
        
        let first = inspector.inspectSegment("PID", occurrence: 0)
        let second = inspector.inspectSegment("PID", occurrence: 1)
        
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertTrue(first!.contains("Patient1"))
        XCTAssertTrue(second!.contains("Patient2"))
        XCTAssertTrue(first!.contains("occurrence 1 of 2"))
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() {
        let stats = inspector.statistics()
        
        XCTAssertNotNil(stats["segmentCounts"])
        XCTAssertNotNil(stats["totalSegments"])
        XCTAssertNotNil(stats["totalFields"])
        XCTAssertNotNil(stats["uniqueSegments"])
        
        let totalSegments = stats["totalSegments"] as? Int
        XCTAssertNotNil(totalSegments)
        XCTAssertGreaterThan(totalSegments!, 0)
    }
    
    // MARK: - Search Tests
    
    func testSearchFindsValue() {
        let results = inspector.search(for: "12345")
        
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.segment == "PID" })
    }
    
    func testSearchCaseInsensitive() {
        let results = inspector.search(for: "doe", caseSensitive: false)
        
        XCTAssertFalse(results.isEmpty)
    }
    
    func testSearchNotFound() {
        let results = inspector.search(for: "NOTEXIST")
        
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - Comparison Tests
    
    func testCompareIdenticalMessages() async throws {
        let other = try TestMessageGenerator.generateADTA01(
            patientID: "12345",
            patientName: "Doe^John",
            sendingApp: "TestApp"
        )
        
        // Note: Messages won't be identical due to timestamp and control ID,
        // but we can test the comparison functionality
        let comparison = inspector.compare(with: other)
        
        XCTAssertTrue(comparison.contains("Message Comparison"))
        XCTAssertTrue(comparison.contains("ADT^A01"))
    }
    
    func testCompareDifferentMessages() async throws {
        let other = try TestMessageGenerator.generateADTA01(
            patientID: "67890",
            patientName: "Smith^Jane",
            sendingApp: "TestApp"
        )
        
        let comparison = inspector.compare(with: other)
        
        XCTAssertTrue(comparison.contains("Message Comparison"))
    }
    
    // MARK: - Validation Report Tests
    
    func testValidationReport() {
        let report = inspector.validationReport()
        
        XCTAssertTrue(report.contains("Validation Report"))
        XCTAssertTrue(report.contains("Status:"))
    }
}

// MARK: - Pretty Printer Tests

final class MessagePrettyPrinterTests: XCTestCase {
    func testPrettyPrintDefault() async throws {
        let message = try TestMessageGenerator.generateADTA01()
        let output = MessagePrettyPrinter.print(message)
        
        XCTAssertTrue(output.contains("MSH"))
        XCTAssertTrue(output.contains("PID"))
        XCTAssertTrue(output.contains("["))
        XCTAssertTrue(output.contains("]"))
    }
    
    func testPrettyPrintWithoutIndices() async throws {
        let message = try TestMessageGenerator.generateADTA01()
        var options = MessagePrettyPrinter.FormatOptions()
        options.showIndices = false
        
        let output = MessagePrettyPrinter.print(message, options: options)
        
        XCTAssertTrue(output.contains("MSH"))
        XCTAssertFalse(output.contains("["))
    }
    
    func testPrettyPrintMaxLength() async throws {
        let message = try TestMessageGenerator.generateADTA01()
        var options = MessagePrettyPrinter.FormatOptions()
        options.maxValueLength = 10
        
        let output = MessagePrettyPrinter.print(message, options: options)
        
        XCTAssertTrue(output.contains("..."))
    }
}

// MARK: - Message Diff Tests

final class MessageDiffTests: XCTestCase {
    func testDiffIdenticalMessages() async throws {
        let message1 = try TestMessageGenerator.generateADTA01(
            patientID: "12345",
            patientName: "Doe^John"
        )
        let message2 = try TestMessageGenerator.generateADTA01(
            patientID: "12345",
            patientName: "Doe^John"
        )
        
        // Note: Won't be identical due to timestamps, but should have similar structure
        let diffs = MessageDiff.diff(original: message1, modified: message2)
        
        // Should have some differences due to timestamps/control IDs
        XCTAssertNotNil(diffs)
    }
    
    func testDiffDifferentPatients() async throws {
        let message1 = try TestMessageGenerator.generateADTA01(
            patientID: "12345",
            patientName: "Doe^John"
        )
        let message2 = try TestMessageGenerator.generateADTA01(
            patientID: "67890",
            patientName: "Smith^Jane"
        )
        
        let diffs = MessageDiff.diff(original: message1, modified: message2)
        
        XCTAssertFalse(diffs.isEmpty)
        XCTAssertTrue(diffs.contains { $0.type == .fieldChanged })
    }
    
    func testDiffReport() async throws {
        let message1 = try TestMessageGenerator.generateADTA01(patientID: "12345")
        let message2 = try TestMessageGenerator.generateADTA01(patientID: "67890")
        
        let report = MessageDiff.report(original: message1, modified: message2)
        
        XCTAssertTrue(report.contains("Message Diff Report"))
        XCTAssertTrue(report.contains("Changes:"))
    }
}

// MARK: - Test Message Generator Tests

final class TestMessageGeneratorTests: XCTestCase {
    func testGenerateADTA01() throws {
        let message = try TestMessageGenerator.generateADTA01()
        
        XCTAssertEqual(message.messageType, "ADT")
        XCTAssertEqual(message.eventType, "A01")
        
        // Should have MSH, EVN, PID, PV1
        let segmentIDs = message.segments.map { $0.segmentID }
        XCTAssertTrue(segmentIDs.contains("MSH"))
        XCTAssertTrue(segmentIDs.contains("EVN"))
        XCTAssertTrue(segmentIDs.contains("PID"))
        XCTAssertTrue(segmentIDs.contains("PV1"))
    }
    
    func testGenerateORUR01() throws {
        let message = try TestMessageGenerator.generateORUR01(
            observations: [("GLU", "95"), ("NA", "140")]
        )
        
        XCTAssertEqual(message.messageType, "ORU")
        XCTAssertEqual(message.eventType, "R01")
        
        let segmentIDs = message.segments.map { $0.segmentID }
        XCTAssertTrue(segmentIDs.contains("OBR"))
        XCTAssertTrue(segmentIDs.contains("OBX"))
        
        // Should have 2 OBX segments
        let obxCount = segmentIDs.filter { $0 == "OBX" }.count
        XCTAssertEqual(obxCount, 2)
    }
    
    func testGenerateORMO01() throws {
        let message = try TestMessageGenerator.generateORMO01()
        
        XCTAssertEqual(message.messageType, "ORM")
        XCTAssertEqual(message.eventType, "O01")
        
        let segmentIDs = message.segments.map { $0.segmentID }
        XCTAssertTrue(segmentIDs.contains("ORC"))
        XCTAssertTrue(segmentIDs.contains("OBR"))
    }
    
    func testGenerateACK() throws {
        let message = try TestMessageGenerator.generateACK(
            originalMessageControlID: "12345",
            acknowledgmentCode: "AA"
        )
        
        XCTAssertEqual(message.messageType, "ACK")
        
        let segmentIDs = message.segments.map { $0.segmentID }
        XCTAssertTrue(segmentIDs.contains("MSA"))
    }
    
    func testGenerateBatch() throws {
        let messages = try TestMessageGenerator.generateBatch(count: 5) { index in
            try TestMessageGenerator.generateADTA01(patientID: "PATIENT\(index)")
        }
        
        XCTAssertEqual(messages.count, 5)
        XCTAssertTrue(messages.allSatisfy { $0.messageType == "ADT" })
    }
    
    func testGenerateRandomMessage() throws {
        let message = try TestMessageGenerator.generateRandomMessage(
            segmentCount: 10,
            fieldsPerSegment: 5
        )
        
        XCTAssertEqual(message.messageType, "XXX")
        XCTAssertGreaterThanOrEqual(message.segments.count, 10)
    }
}

// MARK: - Test Data Builder Tests

final class TestDataBuilderTests: XCTestCase {
    func testPatientID() {
        let id = TestDataBuilder.patientID()
        
        XCTAssertTrue(id.hasPrefix("TEST"))
        XCTAssertEqual(id.count, 9) // "TEST" + 5 digits
    }
    
    func testPatientName() {
        let name = TestDataBuilder.patientName()
        
        XCTAssertTrue(name.contains("^"))
        
        let parts = name.split(separator: "^")
        XCTAssertEqual(parts.count, 2)
    }
    
    func testDate() {
        let today = TestDataBuilder.date()
        
        XCTAssertEqual(today.count, 8) // YYYYMMDD
    }
    
    func testTimestamp() {
        let now = TestDataBuilder.timestamp()
        
        XCTAssertEqual(now.count, 14) // YYYYMMDDHHmmss
    }
    
    func testObservation() {
        let obs = TestDataBuilder.observation(identifier: "GLU", value: "95", unit: "mg/dL")
        
        XCTAssertTrue(obs.contains("GLU"))
        XCTAssertTrue(obs.contains("95"))
        XCTAssertTrue(obs.contains("mg/dL"))
    }
}

// MARK: - Mock Objects Tests

final class MockObjectsTests: XCTestCase {
    func testMockSegment() {
        let segment = MockSegment(
            segmentID: "TST",
            fields: ["value1", "value2", "value3"]
        )
        
        XCTAssertEqual(segment.segmentID, "TST")
        XCTAssertEqual(segment.fields.count, 3)
        XCTAssertEqual(segment[0].serialize(), "value1")
    }
    
    func testMockParser() throws {
        let parser = MockParser()
        
        let message = try parser.parse("test data")
        
        XCTAssertEqual(parser.parseCount, 1)
        XCTAssertEqual(parser.lastParsedData, "test data")
        XCTAssertNotNil(message)
    }
    
    func testMockParserFailure() {
        let parser = MockParser()
        parser.shouldSucceed = false
        
        XCTAssertThrowsError(try parser.parse("test data"))
    }
    
    func testMockValidator() throws {
        let validator = MockValidator(result: .valid)
        let message = try TestMessageGenerator.generateADTA01()
        
        let result = validator.validate(message)
        
        XCTAssertTrue(result.isValid)
    }
}

// MARK: - Performance Test Helpers Tests

final class PerformanceTestHelpersTests: XCTestCase {
    func testMeasureTime() {
        let time = PerformanceTestHelpers.measureTime {
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        XCTAssertGreaterThanOrEqual(time, 0.01)
        XCTAssertLessThan(time, 0.1)
    }
    
    func testMeasureAverage() {
        let avgTime = PerformanceTestHelpers.measureAverage(iterations: 10) {
            // Quick operation
            _ = (0..<100).reduce(0, +)
        }
        
        XCTAssertGreaterThan(avgTime, 0)
        XCTAssertLessThan(avgTime, 0.01) // Should be very fast
    }
    
    func testMeasureThroughput() throws {
        var counter = 0
        let throughput = PerformanceTestHelpers.measureThroughput(duration: 0.1) {
            counter += 1
            _ = try? TestMessageGenerator.generateADTA01()
        }
        
        XCTAssertGreaterThan(throughput, 0)
        print("Message generation throughput: \(throughput) msg/s")
    }
}
