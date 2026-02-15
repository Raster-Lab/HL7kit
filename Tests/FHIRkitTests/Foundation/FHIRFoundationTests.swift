/// FHIRFoundationTests.swift
/// Tests for FHIR foundation types (Resource, DomainResource, Meta, Narrative, Extension)

import XCTest
@testable import FHIRkit
@testable import HL7Core

final class FHIRFoundationTests: XCTestCase {
    
    // MARK: - Meta Tests
    
    func testMetaCreation() {
        let meta = Meta(
            versionId: "1",
            lastUpdated: "2024-01-15T10:30:00Z",
            profile: ["http://hl7.org/fhir/StructureDefinition/Patient"]
        )
        
        XCTAssertEqual(meta.versionId, "1")
        XCTAssertEqual(meta.lastUpdated, "2024-01-15T10:30:00Z")
        XCTAssertEqual(meta.profile?.count, 1)
    }
    
    func testMetaWithSecurityTags() {
        let security = Coding(
            system: "http://terminology.hl7.org/CodeSystem/v3-ActReason",
            code: "HTEST",
            display: "test health data"
        )
        let meta = Meta(security: [security])
        
        XCTAssertEqual(meta.security?.count, 1)
        XCTAssertEqual(meta.security?[0].code, "HTEST")
    }
    
    // MARK: - Narrative Tests
    
    func testNarrativeCreation() {
        let narrative = Narrative(
            status: "generated",
            div: "<div xmlns=\"http://www.w3.org/1999/xhtml\">Patient narrative</div>"
        )
        
        XCTAssertEqual(narrative.status, "generated")
        XCTAssertTrue(narrative.div.contains("Patient narrative"))
    }
    
    // MARK: - Extension Tests
    
    func testExtensionCreation() {
        let ext = Extension(
            url: "http://example.com/fhir/extension/custom",
            valueString: "Custom value"
        )
        
        XCTAssertEqual(ext.url, "http://example.com/fhir/extension/custom")
        XCTAssertEqual(ext.valueString, "Custom value")
        XCTAssertNil(ext.valueInteger)
        XCTAssertNil(ext.valueBoolean)
    }
    
    func testExtensionWithMultipleValueTypes() {
        let stringExt = Extension(url: "http://example.com/string", valueString: "text")
        let intExt = Extension(url: "http://example.com/int", valueInteger: 42)
        let boolExt = Extension(url: "http://example.com/bool", valueBoolean: true)
        
        XCTAssertNotNil(stringExt.valueString)
        XCTAssertNotNil(intExt.valueInteger)
        XCTAssertNotNil(boolExt.valueBoolean)
    }
    
    func testNestedExtensions() {
        let innerExt = Extension(url: "http://example.com/inner", valueString: "inner")
        let outerExt = Extension(
            extension: [innerExt],
            url: "http://example.com/outer"
        )
        
        XCTAssertEqual(outerExt.extension?.count, 1)
        XCTAssertEqual(outerExt.extension?[0].url, "http://example.com/inner")
    }
    
    // MARK: - Patient Tests
    
    func testPatientCreation() {
        let patient = Patient(
            id: "patient-123",
            identifier: [Identifier(system: "http://hospital.org/mrn", value: "MRN123")],
            name: [HumanName(family: "Doe", given: ["John"])],
            gender: "male",
            birthDate: "1980-01-15"
        )
        
        XCTAssertEqual(patient.id, "patient-123")
        XCTAssertEqual(patient.resourceType, "Patient")
        XCTAssertEqual(patient.gender, "male")
        XCTAssertEqual(patient.birthDate, "1980-01-15")
        XCTAssertEqual(patient.name?.count, 1)
        XCTAssertEqual(patient.identifier?.count, 1)
    }
    
    func testPatientValidation() throws {
        let patient = Patient(
            id: "patient-123",
            name: [HumanName(family: "Doe", given: ["John"])]
        )
        
        XCTAssertNoThrow(try patient.validate())
    }
    
    func testPatientWithMeta() {
        let meta = Meta(versionId: "1", lastUpdated: "2024-01-15T10:30:00Z")
        let patient = Patient(
            id: "patient-123",
            meta: meta,
            name: [HumanName(family: "Doe", given: ["John"])]
        )
        
        XCTAssertNotNil(patient.meta)
        XCTAssertEqual(patient.meta?.versionId, "1")
    }
    
    func testPatientWithNarrative() {
        let narrative = Narrative(
            status: "generated",
            div: "<div>John Doe, Male, DOB: 1980-01-15</div>"
        )
        let patient = Patient(
            id: "patient-123",
            text: narrative,
            name: [HumanName(family: "Doe", given: ["John"])]
        )
        
        XCTAssertNotNil(patient.text)
        XCTAssertEqual(patient.text?.status, "generated")
    }
    
    func testPatientWithExtensions() {
        let raceExt = Extension(
            url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race",
            valueString: "Asian"
        )
        let patient = Patient(
            id: "patient-123",
            extension: [raceExt],
            name: [HumanName(family: "Doe", given: ["John"])]
        )
        
        XCTAssertEqual(patient.extension?.count, 1)
        XCTAssertEqual(patient.extension?[0].url, "http://hl7.org/fhir/us/core/StructureDefinition/us-core-race")
    }
    
    func testPatientWithContactInfo() {
        let phone = ContactPoint(system: "phone", value: "+1-555-123-4567", use: "home")
        let email = ContactPoint(system: "email", value: "john.doe@example.com", use: "home")
        let address = Address(
            line: ["123 Main St"],
            city: "Springfield",
            state: "IL",
            postalCode: "62701"
        )
        
        let patient = Patient(
            id: "patient-123",
            name: [HumanName(family: "Doe", given: ["John"])],
            telecom: [phone, email],
            address: [address]
        )
        
        XCTAssertEqual(patient.telecom?.count, 2)
        XCTAssertEqual(patient.address?.count, 1)
        XCTAssertEqual(patient.address?[0].city, "Springfield")
    }
    
    // MARK: - Observation Tests
    
    func testObservationCreation() {
        let code = CodeableConcept(
            coding: [Coding(system: "http://loinc.org", code: "8310-5", display: "Body temperature")],
            text: "Body temperature"
        )
        let subject = Reference(reference: "Patient/123", type: "Patient")
        
        let observation = Observation(
            id: "obs-123",
            status: "final",
            code: code,
            subject: subject
        )
        
        XCTAssertEqual(observation.id, "obs-123")
        XCTAssertEqual(observation.resourceType, "Observation")
        XCTAssertEqual(observation.status, "final")
        XCTAssertEqual(observation.code.text, "Body temperature")
        XCTAssertEqual(observation.subject?.reference, "Patient/123")
    }
    
    func testObservationValidation() throws {
        let code = CodeableConcept(
            coding: [Coding(system: "http://loinc.org", code: "8310-5")],
            text: "Body temperature"
        )
        let observation = Observation(
            id: "obs-123",
            status: "final",
            code: code
        )
        
        XCTAssertNoThrow(try observation.validate())
    }
    
    func testObservationMissingStatus() {
        let code = CodeableConcept(text: "Test")
        let observation = Observation(
            id: "obs-123",
            status: "",  // Empty status
            code: code
        )
        
        XCTAssertThrowsError(try observation.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    // MARK: - Codable Tests
    
    func testMetaCodable() throws {
        let original = Meta(versionId: "1", lastUpdated: "2024-01-15T10:30:00Z")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Meta.self, from: data)
        
        XCTAssertEqual(original.versionId, decoded.versionId)
        XCTAssertEqual(original.lastUpdated, decoded.lastUpdated)
    }
    
    func testNarrativeCodable() throws {
        let original = Narrative(status: "generated", div: "<div>Test</div>")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Narrative.self, from: data)
        
        XCTAssertEqual(original.status, decoded.status)
        XCTAssertEqual(original.div, decoded.div)
    }
    
    func testExtensionCodable() throws {
        let original = Extension(url: "http://example.com", valueString: "test")
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Extension.self, from: data)
        
        XCTAssertEqual(original.url, decoded.url)
        XCTAssertEqual(original.valueString, decoded.valueString)
    }
    
    func testPatientJSONEncoding() throws {
        let patient = Patient(
            id: "patient-123",
            name: [HumanName(family: "Doe", given: ["John"])],
            gender: "male"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(patient)
        
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"resourceType\"") && jsonString!.contains("Patient"))
        XCTAssertTrue(jsonString!.contains("\"gender\"") && jsonString!.contains("male"))
    }
    
    // MARK: - Performance Tests
    
    func testPatientCreationPerformance() {
        measure {
            for i in 0..<100 {
                _ = Patient(
                    id: "patient-\(i)",
                    name: [HumanName(family: "Doe", given: ["John"])],
                    gender: "male"
                )
            }
        }
    }
    
    func testObservationCreationPerformance() {
        let code = CodeableConcept(text: "Test")
        
        measure {
            for i in 0..<100 {
                _ = Observation(
                    id: "obs-\(i)",
                    status: "final",
                    code: code
                )
            }
        }
    }
}
