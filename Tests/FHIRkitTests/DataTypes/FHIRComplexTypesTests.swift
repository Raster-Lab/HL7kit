/// FHIRComplexTypesTests.swift
/// Tests for FHIR complex data types

import XCTest
@testable import FHIRkit

final class FHIRComplexTypesTests: XCTestCase {
    
    // MARK: - Identifier Tests
    
    func testIdentifierCreation() {
        let identifier = Identifier(
            system: "http://example.com/ids",
            value: "12345"
        )
        
        XCTAssertEqual(identifier.system, "http://example.com/ids")
        XCTAssertEqual(identifier.value, "12345")
        XCTAssertNil(identifier.use)
        XCTAssertNil(identifier.type)
    }
    
    func testIdentifierWithAllFields() {
        let period = Period(start: "2024-01-01", end: "2024-12-31")
        let identifier = Identifier(
            use: "official",
            system: "http://example.com/ids",
            value: "12345",
            period: period,
            assigner: "Organization/123"
        )
        
        XCTAssertEqual(identifier.use, "official")
        XCTAssertEqual(identifier.value, "12345")
        XCTAssertNotNil(identifier.period)
        XCTAssertEqual(identifier.assigner, "Organization/123")
    }
    
    // MARK: - HumanName Tests
    
    func testHumanNameCreation() {
        let name = HumanName(
            family: "Doe",
            given: ["John", "Q"]
        )
        
        XCTAssertEqual(name.family, "Doe")
        XCTAssertEqual(name.given?.count, 2)
        XCTAssertEqual(name.given?[0], "John")
        XCTAssertEqual(name.given?[1], "Q")
    }
    
    func testHumanNameWithPrefix() {
        let name = HumanName(
            family: "Smith",
            given: ["Jane"],
            prefix: ["Dr."],
            suffix: ["PhD"]
        )
        
        XCTAssertEqual(name.prefix?[0], "Dr.")
        XCTAssertEqual(name.suffix?[0], "PhD")
    }
    
    // MARK: - Address Tests
    
    func testAddressCreation() {
        let address = Address(
            line: ["123 Main St", "Apt 4"],
            city: "Springfield",
            state: "IL",
            postalCode: "62701",
            country: "USA"
        )
        
        XCTAssertEqual(address.line?.count, 2)
        XCTAssertEqual(address.city, "Springfield")
        XCTAssertEqual(address.state, "IL")
        XCTAssertEqual(address.postalCode, "62701")
        XCTAssertEqual(address.country, "USA")
    }
    
    // MARK: - ContactPoint Tests
    
    func testContactPointCreation() {
        let contact = ContactPoint(
            system: "phone",
            value: "+1-555-123-4567",
            use: "home"
        )
        
        XCTAssertEqual(contact.system, "phone")
        XCTAssertEqual(contact.value, "+1-555-123-4567")
        XCTAssertEqual(contact.use, "home")
    }
    
    // MARK: - Period Tests
    
    func testPeriodCreation() {
        let period = Period(
            start: "2024-01-01",
            end: "2024-12-31"
        )
        
        XCTAssertEqual(period.start, "2024-01-01")
        XCTAssertEqual(period.end, "2024-12-31")
    }
    
    // MARK: - Range Tests
    
    func testRangeCreation() {
        let low = Quantity(value: 100, unit: "mg")
        let high = Quantity(value: 200, unit: "mg")
        let range = Range(low: low, high: high)
        
        XCTAssertNotNil(range.low)
        XCTAssertNotNil(range.high)
        XCTAssertEqual(range.low?.value, 100)
        XCTAssertEqual(range.high?.value, 200)
    }
    
    // MARK: - Quantity Tests
    
    func testQuantityCreation() {
        let quantity = Quantity(
            value: 150,
            unit: "mg",
            system: "http://unitsofmeasure.org",
            code: "mg"
        )
        
        XCTAssertEqual(quantity.value, 150)
        XCTAssertEqual(quantity.unit, "mg")
        XCTAssertEqual(quantity.system, "http://unitsofmeasure.org")
        XCTAssertEqual(quantity.code, "mg")
    }
    
    // MARK: - Coding Tests
    
    func testCodingCreation() {
        let coding = Coding(
            system: "http://loinc.org",
            code: "8310-5",
            display: "Body temperature"
        )
        
        XCTAssertEqual(coding.system, "http://loinc.org")
        XCTAssertEqual(coding.code, "8310-5")
        XCTAssertEqual(coding.display, "Body temperature")
    }
    
    // MARK: - CodeableConcept Tests
    
    func testCodeableConceptCreation() {
        let coding1 = Coding(
            system: "http://loinc.org",
            code: "8310-5",
            display: "Body temperature"
        )
        let coding2 = Coding(
            system: "http://snomed.info/sct",
            code: "386725007",
            display: "Body temperature"
        )
        
        let concept = CodeableConcept(
            coding: [coding1, coding2],
            text: "Body temperature"
        )
        
        XCTAssertEqual(concept.coding?.count, 2)
        XCTAssertEqual(concept.text, "Body temperature")
    }
    
    // MARK: - Reference Tests
    
    func testReferenceCreation() {
        let reference = Reference(
            reference: "Patient/123",
            type: "Patient",
            display: "John Doe"
        )
        
        XCTAssertEqual(reference.reference, "Patient/123")
        XCTAssertEqual(reference.type, "Patient")
        XCTAssertEqual(reference.display, "John Doe")
    }
    
    // MARK: - Annotation Tests
    
    func testAnnotationCreation() {
        let annotation = Annotation(
            authorString: "Dr. Smith",
            time: "2024-01-15T10:30:00Z",
            text: "Patient shows improvement"
        )
        
        XCTAssertEqual(annotation.authorString, "Dr. Smith")
        XCTAssertEqual(annotation.time, "2024-01-15T10:30:00Z")
        XCTAssertEqual(annotation.text, "Patient shows improvement")
    }
    
    // MARK: - Attachment Tests
    
    func testAttachmentCreation() {
        let attachment = Attachment(
            contentType: "image/png",
            data: "iVBORw0KGgo=",
            title: "X-Ray Image"
        )
        
        XCTAssertEqual(attachment.contentType, "image/png")
        XCTAssertEqual(attachment.data, "iVBORw0KGgo=")
        XCTAssertEqual(attachment.title, "X-Ray Image")
    }
    
    // MARK: - Signature Tests
    
    func testSignatureCreation() {
        let coding = Coding(
            system: "urn:iso-astm:E1762-95:2013",
            code: "1.2.840.10065.1.12.1.1",
            display: "Author's Signature"
        )
        let who = Reference(reference: "Practitioner/123", type: "Practitioner")
        
        let signature = Signature(
            type: [coding],
            when: "2024-01-15T10:30:00Z",
            who: who
        )
        
        XCTAssertEqual(signature.type.count, 1)
        XCTAssertEqual(signature.when, "2024-01-15T10:30:00Z")
        XCTAssertEqual(signature.who.reference, "Practitioner/123")
    }
    
    // MARK: - Codable Tests
    
    func testIdentifierCodable() throws {
        let original = Identifier(
            system: "http://example.com/ids",
            value: "12345"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Identifier.self, from: data)
        
        XCTAssertEqual(original.system, decoded.system)
        XCTAssertEqual(original.value, decoded.value)
    }
    
    func testHumanNameCodable() throws {
        let original = HumanName(
            family: "Doe",
            given: ["John"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HumanName.self, from: data)
        
        XCTAssertEqual(original.family, decoded.family)
        XCTAssertEqual(original.given, decoded.given)
    }
    
    // MARK: - Hashable Tests
    
    func testCodingHashable() {
        let coding1 = Coding(system: "http://loinc.org", code: "8310-5")
        let coding2 = Coding(system: "http://loinc.org", code: "8310-5")
        let coding3 = Coding(system: "http://loinc.org", code: "different")
        
        XCTAssertEqual(coding1, coding2)
        XCTAssertNotEqual(coding1, coding3)
    }
    
    // MARK: - Performance Tests
    
    func testComplexTypeCreationPerformance() {
        measure {
            for i in 0..<100 {
                _ = Identifier(system: "http://example.com", value: "\(i)")
                _ = HumanName(family: "Doe", given: ["John"])
                _ = Address(city: "Springfield", state: "IL")
            }
        }
    }
}
