/// V3TestUtilitiesTests.swift
/// Unit tests for V3TestUtilities

import XCTest
@testable import HL7v3Kit

final class V3TestUtilitiesTests: XCTestCase {
    // MARK: - Mock CDA Document Tests
    
    func testCreateMinimalCDADocument() async throws {
        let doc = await V3TestUtilities.createMinimalCDADocument()
        
        XCTAssertEqual(doc.name, "ClinicalDocument")
        XCTAssertEqual(doc.namespace, "urn:hl7-org:v3")
        XCTAssertEqual(doc.attributes["classCode"], "DOCCLIN")
        XCTAssertEqual(doc.attributes["moodCode"], "EVN")
        
        // Check required elements exist
        XCTAssertTrue(doc.hasChild(named: "typeId"))
        XCTAssertTrue(doc.hasChild(named: "id"))
        XCTAssertTrue(doc.hasChild(named: "code"))
        XCTAssertTrue(doc.hasChild(named: "title"))
        XCTAssertTrue(doc.hasChild(named: "effectiveTime"))
        XCTAssertTrue(doc.hasChild(named: "confidentialityCode"))
        XCTAssertTrue(doc.hasChild(named: "recordTarget"))
        XCTAssertTrue(doc.hasChild(named: "author"))
        XCTAssertTrue(doc.hasChild(named: "custodian"))
        XCTAssertTrue(doc.hasChild(named: "component"))
    }
    
    func testCreateMinimalCDADocumentWithoutBody() async throws {
        let doc = await V3TestUtilities.createMinimalCDADocument(includeBody: false)
        
        XCTAssertEqual(doc.name, "ClinicalDocument")
        XCTAssertFalse(doc.hasChild(named: "component"))
    }
    
    func testCreateMinimalCDADocumentCustomParameters() async throws {
        let doc = await V3TestUtilities.createMinimalCDADocument(
            documentType: "11488-4",
            title: "Consultation Note",
            patientName: "Jane Smith"
        )
        
        let code = doc.firstChild(named: "code")
        XCTAssertEqual(code?.attributes["code"], "11488-4")
        
        let title = doc.firstChild(named: "title")
        XCTAssertEqual(title?.text, "Consultation Note")
    }
    
    // MARK: - Mock Component Tests
    
    func testCreateMockRecordTarget() async throws {
        let recordTarget = await V3TestUtilities.createMockRecordTarget(patientName: "John Doe")
        
        XCTAssertEqual(recordTarget.name, "recordTarget")
        XCTAssertTrue(recordTarget.hasChild(named: "patientRole"))
        
        // Verify patient name structure
        let patientRole = recordTarget.firstChild(named: "patientRole")
        let patient = patientRole?.firstChild(named: "patient")
        let name = patient?.firstChild(named: "name")
        
        XCTAssertNotNil(name)
        let given = name?.firstChild(named: "given")
        let family = name?.firstChild(named: "family")
        
        XCTAssertEqual(given?.text, "John")
        XCTAssertEqual(family?.text, "Doe")
    }
    
    func testCreateMockAuthor() async throws {
        let author = await V3TestUtilities.createMockAuthor(authorName: "Dr. Smith")
        
        XCTAssertEqual(author.name, "author")
        XCTAssertTrue(author.hasChild(named: "time"))
        XCTAssertTrue(author.hasChild(named: "assignedAuthor"))
        
        let assignedAuthor = author.firstChild(named: "assignedAuthor")
        let assignedPerson = assignedAuthor?.firstChild(named: "assignedPerson")
        let name = assignedPerson?.firstChild(named: "name")
        
        XCTAssertEqual(name?.text, "Dr. Smith")
    }
    
    func testCreateMockCustodian() async throws {
        let custodian = await V3TestUtilities.createMockCustodian(orgName: "Test Hospital")
        
        XCTAssertEqual(custodian.name, "custodian")
        XCTAssertTrue(custodian.hasChild(named: "assignedCustodian"))
    }
    
    func testCreateMockComponent() async throws {
        let component = await V3TestUtilities.createMockComponent()
        
        XCTAssertEqual(component.name, "component")
        XCTAssertTrue(component.hasChild(named: "structuredBody"))
        
        let structuredBody = component.firstChild(named: "structuredBody")
        XCTAssertNotNil(structuredBody)
        XCTAssertGreaterThan(structuredBody?.children.count ?? 0, 0)
    }
    
    func testCreateMockSection() async throws {
        let section = await V3TestUtilities.createMockSection(
            title: "Medications",
            code: "10160-0",
            narrative: "Patient is taking aspirin"
        )
        
        XCTAssertEqual(section.name, "section")
        
        let title = section.firstChild(named: "title")
        XCTAssertEqual(title?.text, "Medications")
        
        let code = section.firstChild(named: "code")
        XCTAssertEqual(code?.attributes["code"], "10160-0")
        
        let text = section.firstChild(named: "text")
        XCTAssertEqual(text?.text, "Patient is taking aspirin")
    }
    
    func testCreateMockObservationEntry() async throws {
        let entry = await V3TestUtilities.createMockObservationEntry(
            code: "8310-5",
            displayName: "Body temperature",
            value: "37.0",
            unit: "Cel"
        )
        
        XCTAssertEqual(entry.name, "entry")
        
        let observation = entry.firstChild(named: "observation")
        XCTAssertNotNil(observation)
        XCTAssertEqual(observation?.attributes["classCode"], "OBS")
        
        let code = observation?.firstChild(named: "code")
        XCTAssertEqual(code?.attributes["code"], "8310-5")
        
        let value = observation?.firstChild(named: "value")
        XCTAssertEqual(value?.attributes["value"], "37.0")
        XCTAssertEqual(value?.attributes["unit"], "Cel")
    }
    
    func testCreateMockProcedureEntry() async throws {
        let entry = await V3TestUtilities.createMockProcedureEntry(
            code: "80146002",
            displayName: "Appendectomy"
        )
        
        XCTAssertEqual(entry.name, "entry")
        
        let procedure = entry.firstChild(named: "procedure")
        XCTAssertNotNil(procedure)
        XCTAssertEqual(procedure?.attributes["classCode"], "PROC")
        
        let code = procedure?.firstChild(named: "code")
        XCTAssertEqual(code?.attributes["code"], "80146002")
    }
    
    // MARK: - Test Data Generator Tests
    
    func testRandomOID() async throws {
        let oid = await V3TestUtilities.randomOID()
        
        XCTAssertTrue(oid.hasPrefix("2.16.840.1."))
        XCTAssertTrue(oid.contains("."))
        
        // Should be different on multiple calls
        let oid2 = await V3TestUtilities.randomOID()
        XCTAssertNotEqual(oid, oid2)
    }
    
    func testRandomTimestamp() async throws {
        let timestamp = await V3TestUtilities.randomTimestamp()
        
        XCTAssertEqual(timestamp.count, 14)  // YYYYMMDDHHMMSS
        XCTAssertTrue(timestamp.allSatisfy { $0.isNumber })
        
        // Should be different on multiple calls
        let timestamp2 = await V3TestUtilities.randomTimestamp()
        // May be same, but check format is correct
        XCTAssertEqual(timestamp2.count, 14)
    }
    
    func testRandomPatientName() async throws {
        let name = await V3TestUtilities.randomPatientName()
        
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains(" "))  // Should have first and last name
        
        let components = name.split(separator: " ")
        XCTAssertGreaterThanOrEqual(components.count, 2)
    }
    
    func testGenerateTestDocuments() async throws {
        let documents = await V3TestUtilities.generateTestDocuments(count: 5)
        
        XCTAssertEqual(documents.count, 5)
        
        for (index, doc) in documents.enumerated() {
            XCTAssertEqual(doc.name, "ClinicalDocument")
            
            let title = doc.firstChild(named: "title")
            XCTAssertTrue(title?.text?.contains("Test Document \(index + 1)") ?? false)
        }
    }
    
    // MARK: - Assertion Helper Tests
    
    func testAssertHasChild() async throws {
        let element = XMLElement(
            name: "parent",
            children: [
                XMLElement(name: "child1"),
                XMLElement(name: "child2")
            ]
        )
        
        // Should succeed
        try await V3TestUtilities.assertHasChild(element, named: "child1")
        
        // Should throw
        do {
            try await V3TestUtilities.assertHasChild(element, named: "nonexistent")
            XCTFail("Expected assertion error")
        } catch let error as V3TestUtilities.AssertionError {
            XCTAssertTrue(error.message.contains("missing required child"))
        }
    }
    
    func testAssertHasAttribute() async throws {
        let element = XMLElement(
            name: "test",
            attributes: ["id": "123", "type": "test"]
        )
        
        // Should succeed
        try await V3TestUtilities.assertHasAttribute(element, named: "id")
        
        // Should throw
        do {
            try await V3TestUtilities.assertHasAttribute(element, named: "nonexistent")
            XCTFail("Expected assertion error")
        } catch let error as V3TestUtilities.AssertionError {
            XCTAssertTrue(error.message.contains("missing required attribute"))
        }
    }
    
    func testAssertAttributeEquals() async throws {
        let element = XMLElement(
            name: "test",
            attributes: ["id": "123"]
        )
        
        // Should succeed
        try await V3TestUtilities.assertAttributeEquals(element, attribute: "id", expectedValue: "123")
        
        // Should throw for wrong value
        do {
            try await V3TestUtilities.assertAttributeEquals(element, attribute: "id", expectedValue: "456")
            XCTFail("Expected assertion error")
        } catch let error as V3TestUtilities.AssertionError {
            XCTAssertTrue(error.message.contains("expected"))
        }
        
        // Should throw for missing attribute
        do {
            try await V3TestUtilities.assertAttributeEquals(element, attribute: "missing", expectedValue: "123")
            XCTFail("Expected assertion error")
        } catch let error as V3TestUtilities.AssertionError {
            XCTAssertTrue(error.message.contains("missing attribute"))
        }
    }
    
    func testAssertTextEquals() async throws {
        let element = XMLElement(name: "test", text: "Hello World")
        
        // Should succeed
        try await V3TestUtilities.assertTextEquals(element, expectedText: "Hello World")
        
        // Should throw for wrong text
        do {
            try await V3TestUtilities.assertTextEquals(element, expectedText: "Wrong")
            XCTFail("Expected assertion error")
        } catch let error as V3TestUtilities.AssertionError {
            XCTAssertTrue(error.message.contains("expected"))
        }
    }
    
    func testAssertElementCount() async throws {
        let element = XMLElement(
            name: "root",
            children: [
                XMLElement(name: "item"),
                XMLElement(name: "item"),
                XMLElement(name: "other"),
                XMLElement(name: "item")
            ]
        )
        
        // Should succeed
        try await V3TestUtilities.assertElementCount(in: element, named: "item", equals: 3)
        
        // Should throw for wrong count
        do {
            try await V3TestUtilities.assertElementCount(in: element, named: "item", equals: 5)
            XCTFail("Expected assertion error")
        } catch let error as V3TestUtilities.AssertionError {
            XCTAssertTrue(error.message.contains("Expected 5"))
        }
    }
    
    // MARK: - Performance Test Utility Tests
    
    func testMeasureTime() async throws {
        let duration = await V3TestUtilities.measureTime {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        XCTAssertGreaterThanOrEqual(duration, 0.09)  // Allow some tolerance
        XCTAssertLessThan(duration, 0.2)
    }
    
    func testMeasureTimeAsync() async throws {
        let duration = await V3TestUtilities.measureTimeAsync {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }
        
        XCTAssertGreaterThanOrEqual(duration, 0.09)
        XCTAssertLessThan(duration, 0.2)
    }
    
    func testBenchmark() async throws {
        let metrics = await V3TestUtilities.benchmark(iterations: 10) {
            _ = (0..<1000).reduce(0, +)
        }
        
        XCTAssertEqual(metrics.durations.count, 10)
        XCTAssertGreaterThan(metrics.average, 0)
        XCTAssertGreaterThan(metrics.min, 0)
        XCTAssertGreaterThan(metrics.max, 0)
        XCTAssertGreaterThanOrEqual(metrics.max, metrics.min)
    }
    
    func testBenchmarkAsync() async throws {
        let metrics = await V3TestUtilities.benchmarkAsync(iterations: 5) {
            _ = (0..<1000).reduce(0, +)
        }
        
        XCTAssertEqual(metrics.durations.count, 5)
        XCTAssertGreaterThan(metrics.average, 0)
    }
    
    func testPerformanceMetricsCalculations() async throws {
        let durations = [0.1, 0.2, 0.15, 0.25, 0.18]
        let metrics = V3TestUtilities.PerformanceMetrics(durations: durations)
        
        XCTAssertEqual(metrics.average, 0.176, accuracy: 0.001)
        XCTAssertEqual(metrics.min, 0.1)
        XCTAssertEqual(metrics.max, 0.25)
        XCTAssertEqual(metrics.median, 0.18)
        XCTAssertGreaterThan(metrics.standardDeviation, 0)
    }
    
    func testPerformanceMetricsSummary() async throws {
        let durations = [0.1, 0.2, 0.15]
        let metrics = V3TestUtilities.PerformanceMetrics(durations: durations)
        
        let summary = metrics.summary
        
        XCTAssertTrue(summary.contains("Performance Metrics"))
        XCTAssertTrue(summary.contains("Average"))
        XCTAssertTrue(summary.contains("Median"))
        XCTAssertTrue(summary.contains("Min"))
        XCTAssertTrue(summary.contains("Max"))
        XCTAssertTrue(summary.contains("StdDev"))
        XCTAssertTrue(summary.contains("Runs"))
    }
    
    // MARK: - Comparison Utility Tests
    
    func testElementsEqual() async throws {
        let element1 = XMLElement(
            name: "test",
            attributes: ["id": "123"],
            children: [
                XMLElement(name: "child1", text: "Hello"),
                XMLElement(name: "child2", text: "World")
            ],
            text: "Parent text"
        )
        
        let element2 = XMLElement(
            name: "test",
            attributes: ["id": "123"],
            children: [
                XMLElement(name: "child1", text: "Hello"),
                XMLElement(name: "child2", text: "World")
            ],
            text: "Parent text"
        )
        
        let result1 = await V3TestUtilities.elementsEqual(element1, element2)
        XCTAssertTrue(result1)
    }
    
    func testElementsNotEqual() async throws {
        let element1 = XMLElement(name: "test", attributes: ["id": "123"])
        let element2 = XMLElement(name: "test", attributes: ["id": "456"])
        
        let result = await V3TestUtilities.elementsEqual(element1, element2)
        XCTAssertFalse(result)
    }
    
    func testElementsEqualIgnoreOrder() async throws {
        let element1 = XMLElement(
            name: "test",
            children: [
                XMLElement(name: "child1"),
                XMLElement(name: "child2")
            ]
        )
        
        let element2 = XMLElement(
            name: "test",
            children: [
                XMLElement(name: "child2"),
                XMLElement(name: "child1")
            ]
        )
        
        let resultNoOrder = await V3TestUtilities.elementsEqual(element1, element2, ignoreOrder: false)
        XCTAssertFalse(resultNoOrder)
        let resultWithOrder = await V3TestUtilities.elementsEqual(element1, element2, ignoreOrder: true)
        XCTAssertTrue(resultWithOrder)
    }
    
    // MARK: - XMLElement Extension Tests
    
    func testXMLElementHasChild() {
        let element = XMLElement(
            name: "parent",
            children: [
                XMLElement(name: "child1"),
                XMLElement(name: "child2")
            ]
        )
        
        XCTAssertTrue(element.hasChild(named: "child1"))
        XCTAssertTrue(element.hasChild(named: "child2"))
        XCTAssertFalse(element.hasChild(named: "nonexistent"))
    }
    
    func testXMLElementFirstChild() {
        let element = XMLElement(
            name: "parent",
            children: [
                XMLElement(name: "child1", text: "First"),
                XMLElement(name: "child1", text: "Second")
            ]
        )
        
        let first = element.firstChild(named: "child1")
        XCTAssertEqual(first?.text, "First")
    }
    
    func testXMLElementAllChildren() {
        let element = XMLElement(
            name: "parent",
            children: [
                XMLElement(name: "child1"),
                XMLElement(name: "child2"),
                XMLElement(name: "child1")
            ]
        )
        
        let allChild1 = element.allChildren(named: "child1")
        XCTAssertEqual(allChild1.count, 2)
    }
    
    // MARK: - Integration Tests
    
    func testCreateAndValidateCompleteDocument() async throws {
        // Create a complete document with sections and entries
        let section = await V3TestUtilities.createMockSection(
            title: "Vital Signs",
            entries: [
                await V3TestUtilities.createMockObservationEntry(
                    code: "8310-5",
                    displayName: "Body temperature",
                    value: "37.0",
                    unit: "Cel"
                )
            ]
        )
        
        let component = await V3TestUtilities.createMockComponent(sections: [section])
        
        let doc = XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: ["classCode": "DOCCLIN", "moodCode": "EVN"],
            children: [
                XMLElement(name: "typeId", attributes: ["root": "2.16.840.1.113883.1.3"]),
                XMLElement(name: "id", attributes: ["root": "1.2.3.4.5"]),
                XMLElement(name: "code", attributes: ["code": "34133-9"]),
                XMLElement(name: "title", text: "Test Document"),
                XMLElement(name: "effectiveTime", attributes: ["value": "20240101120000"]),
                XMLElement(name: "confidentialityCode", attributes: ["code": "N"]),
                await V3TestUtilities.createMockRecordTarget(),
                await V3TestUtilities.createMockAuthor(),
                await V3TestUtilities.createMockCustodian(),
                component
            ]
        )
        
        // Validate structure
        try await V3TestUtilities.assertHasChild(doc, named: "typeId")
        try await V3TestUtilities.assertHasChild(doc, named: "component")
        try await V3TestUtilities.assertElementCount(in: doc, named: "observation", equals: 1)
    }
}
