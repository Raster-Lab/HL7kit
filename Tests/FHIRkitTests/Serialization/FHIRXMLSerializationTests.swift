/// FHIRXMLSerializationTests.swift
/// Tests for FHIR XML serialization and deserialization

import XCTest
@testable import FHIRkit
@testable import HL7Core

final class FHIRXMLSerializationTests: XCTestCase {
    
    // MARK: - Basic XML Encoding Tests
    
    func testPatientXMLEncoding() async throws {
        let patient = Patient(
            id: "patient-001",
            name: [HumanName(family: "Smith", given: ["John"])],
            gender: "male"
        )
        
        let xmlString = try await FHIRXML.encodeToString(patient)
        
        // Verify XML structure
        XCTAssertTrue(xmlString.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xmlString.contains("<Patient"))
        XCTAssertTrue(xmlString.contains("xmlns=\"http://hl7.org/fhir\""))
        XCTAssertTrue(xmlString.contains("</Patient>"))
    }
    
    func testPatientXMLEncodingToData() async throws {
        let patient = Patient(
            id: "patient-002",
            name: [HumanName(family: "Doe")]
        )
        
        let xmlData = try await FHIRXML.encode(patient)
        XCTAssertFalse(xmlData.isEmpty)
        
        // Convert to string to verify content
        let xmlString = String(data: xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString?.contains("Patient") ?? false)
    }
    
    // MARK: - XML Round-Trip Tests
    
    func testPatientXMLRoundTrip() async throws {
        let original = Patient(
            id: "patient-003",
            identifier: [Identifier(system: "http://example.org", value: "123")],
            name: [HumanName(family: "Johnson", given: ["Alice"])],
            gender: "female",
            birthDate: "1990-01-15"
        )
        
        // Encode to XML
        let xmlData = try await FHIRXML.encode(original)
        
        // Decode back
        let decoded = try await FHIRXML.decode(Patient.self, from: xmlData)
        
        XCTAssertEqual(decoded.id, "patient-003")
        XCTAssertEqual(decoded.name?.first?.family, "Johnson")
        XCTAssertEqual(decoded.gender, "female")
    }
    
    func testPatientXMLStringRoundTrip() async throws {
        let original = Patient(
            id: "patient-004",
            name: [HumanName(family: "Brown")]
        )
        
        // Encode to XML string
        let xmlString = try await FHIRXML.encodeToString(original)
        
        // Decode from XML string
        let decoded = try await FHIRXML.decode(Patient.self, from: xmlString)
        
        XCTAssertEqual(decoded.id, "patient-004")
        XCTAssertEqual(decoded.name?.first?.family, "Brown")
    }
    
    // MARK: - Complex Structure Tests
    
    func testObservationXMLEncoding() async throws {
        let observation = Observation(
            id: "obs-001",
            status: "final",
            code: CodeableConcept(
                coding: [Coding(system: "http://loinc.org", code: "8867-4")],
                text: "Heart rate"
            ),
            subject: Reference(reference: "Patient/patient-001"),
            valueQuantity: Quantity(value: 72, unit: "bpm")
        )
        
        let xmlString = try await FHIRXML.encodeToString(observation)
        
        XCTAssertTrue(xmlString.contains("<Observation"))
        XCTAssertTrue(xmlString.contains("</Observation>"))
    }
    
    func testPractitionerXMLEncoding() async throws {
        let practitioner = Practitioner(
            id: "pract-001",
            name: [HumanName(family: "Smith", given: ["John"], prefix: ["Dr."])],
            gender: "male"
        )
        
        let xmlString = try await FHIRXML.encodeToString(practitioner)
        
        XCTAssertTrue(xmlString.contains("<Practitioner"))
        XCTAssertTrue(xmlString.contains("</Practitioner>"))
    }
    
    // MARK: - XML Serializer Actor Tests
    
    func testXMLSerializerActor() async throws {
        let serializer = FHIRXMLSerializer()
        let patient = Patient(id: "test-001", name: [HumanName(family: "Test")])
        
        let xmlData = try await serializer.encode(patient)
        XCTAssertFalse(xmlData.isEmpty)
        
        let decoded = try await serializer.decode(Patient.self, from: xmlData)
        XCTAssertEqual(decoded.id, "test-001")
        XCTAssertEqual(decoded.name?.first?.family, "Test")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidXMLDecoding() async {
        do {
            _ = try await FHIRXML.decode(Patient.self, from: "<invalid>xml</invalid>")
            XCTFail("Should have thrown an error")
        } catch {
            // Expected to throw an error
            XCTAssertTrue(true)
        }
    }
    
    func testEmptyXMLDecoding() async {
        do {
            _ = try await FHIRXML.decode(Patient.self, from: "")
            XCTFail("Should have thrown an error")
        } catch {
            // Expected to throw an error
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testXMLWithCustomConfiguration() async throws {
        let patient = Patient(id: "patient-005", name: [HumanName(family: "Wilson")])
        let config = FHIRSerializationConfiguration.prettyPrinted
        
        let xmlString = try await FHIRXML.encodeToString(patient, configuration: config)
        
        XCTAssertTrue(xmlString.contains("Patient"))
        XCTAssertTrue(xmlString.contains("Wilson"))
    }
    
    // MARK: - Namespace Tests
    
    func testXMLNamespacePresence() async throws {
        let patient = Patient(id: "patient-006", name: [HumanName(family: "Davis")])
        
        let xmlString = try await FHIRXML.encodeToString(patient)
        
        // Verify FHIR namespace is present
        XCTAssertTrue(xmlString.contains("http://hl7.org/fhir"))
    }
    
    // MARK: - Resource Container Tests
    
    func testResourceContainerXMLDecoding() async throws {
        // Create a simple XML patient
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Patient xmlns="http://hl7.org/fhir">
            <id value="patient-007"/>
            <name>
                <family value="Miller"/>
            </name>
        </Patient>
        """
        
        guard let xmlData = xmlString.data(using: .utf8) else {
            XCTFail("Failed to convert XML string to data")
            return
        }
        
        let container = try await FHIRXML.decodeResource(from: xmlData)
        
        if case .patient(let patient) = container {
            XCTAssertEqual(patient.id, "patient-007")
        } else {
            XCTFail("Expected patient resource")
        }
    }
    
    // MARK: - Multiple Resources Tests
    
    func testMultipleResourcesXMLEncoding() async throws {
        let patient = Patient(id: "patient-008", name: [HumanName(family: "Anderson")])
        let practitioner = Practitioner(id: "pract-002", name: [HumanName(family: "Brown")])
        
        let patientXML = try await FHIRXML.encodeToString(patient)
        let practitionerXML = try await FHIRXML.encodeToString(practitioner)
        
        XCTAssertTrue(patientXML.contains("Patient"))
        XCTAssertTrue(practitionerXML.contains("Practitioner"))
    }
}
