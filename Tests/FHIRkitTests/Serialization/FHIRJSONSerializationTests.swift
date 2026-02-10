/// FHIRJSONSerializationTests.swift
/// Tests for FHIR JSON serialization and deserialization

import XCTest
@testable import FHIRkit
@testable import HL7Core

final class FHIRJSONSerializationTests: XCTestCase {
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() {
        let config = FHIRSerializationConfiguration.default
        XCTAssertEqual(config.maxNestingDepth, 100)
        XCTAssertTrue(config.validateChoiceTypes)
        XCTAssertTrue(config.preserveElementOrder)
    }
    
    func testPrettyPrintedConfiguration() {
        let config = FHIRSerializationConfiguration.prettyPrinted
        switch config.outputFormatting {
        case .prettyPrinted:
            XCTAssertTrue(true)
        case .compact:
            XCTFail("Expected prettyPrinted formatting")
        }
    }
    
    func testStrictConfiguration() {
        let config = FHIRSerializationConfiguration.strict
        switch config.validationMode {
        case .strict:
            XCTAssertTrue(true)
        case .lenient, .none:
            XCTFail("Expected strict validation")
        }
        XCTAssertTrue(config.validateChoiceTypes)
    }
    
    // MARK: - Patient JSON Serialization Tests
    
    func testPatientJSONEncodingDecoding() async throws {
        let patient = Patient(
            id: "patient-001",
            identifier: [Identifier(system: "http://hospital.org/mrn", value: "12345")],
            active: true,
            name: [HumanName(family: "Smith", given: ["John", "Q"])],
            gender: "male",
            birthDate: "1980-05-15"
        )
        
        // Encode to JSON
        let jsonData = try await FHIRJSON.encode(patient)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Decode from JSON
        let decoded = try await FHIRJSON.decode(Patient.self, from: jsonData)
        XCTAssertEqual(decoded.resourceType, "Patient")
        XCTAssertEqual(decoded.id, "patient-001")
        XCTAssertEqual(decoded.name?.first?.family, "Smith")
        XCTAssertEqual(decoded.name?.first?.given?.count, 2)
        XCTAssertEqual(decoded.birthDate, "1980-05-15")
    }
    
    func testPatientJSONStringEncodingDecoding() async throws {
        let patient = Patient(
            id: "patient-002",
            name: [HumanName(family: "Doe", given: ["Jane"])],
            gender: "female"
        )
        
        // Encode to JSON string
        let jsonString = try await FHIRJSON.encodeToString(patient)
        XCTAssertTrue(jsonString.contains("\"resourceType\":\"Patient\""))
        XCTAssertTrue(jsonString.contains("\"family\":\"Doe\""))
        
        // Decode from JSON string
        let decoded = try await FHIRJSON.decode(Patient.self, from: jsonString)
        XCTAssertEqual(decoded.name?.first?.family, "Doe")
    }
    
    func testPatientWithComplexData() async throws {
        let patient = Patient(
            id: "patient-003",
            identifier: [
                Identifier(
                    use: "official",
                    type: CodeableConcept(text: "MRN"),
                    system: "http://hospital.org/mrn",
                    value: "MRN-12345"
                )
            ],
            name: [
                HumanName(
                    use: "official",
                    family: "Johnson",
                    given: ["Robert", "Michael"],
                    prefix: ["Dr."],
                    suffix: ["Jr."]
                )
            ],
            telecom: [
                ContactPoint(system: "phone", value: "+1-555-123-4567", use: "home"),
                ContactPoint(system: "email", value: "robert.johnson@example.com", use: "work")
            ],
            address: [
                Address(
                    use: "home",
                    line: ["123 Main St", "Apt 4B"],
                    city: "Boston",
                    state: "MA",
                    postalCode: "02101",
                    country: "USA"
                )
            ]
        )
        
        // Round-trip test
        let jsonData = try await FHIRJSON.encode(patient)
        let decoded = try await FHIRJSON.decode(Patient.self, from: jsonData)
        
        XCTAssertEqual(decoded.id, "patient-003")
        XCTAssertEqual(decoded.identifier?.first?.value, "MRN-12345")
        XCTAssertEqual(decoded.name?.first?.given?.count, 2)
        XCTAssertEqual(decoded.name?.first?.prefix?.first, "Dr.")
        XCTAssertEqual(decoded.telecom?.count, 2)
        XCTAssertEqual(decoded.address?.first?.city, "Boston")
    }
    
    // MARK: - Observation JSON Serialization Tests
    
    func testObservationJSONEncodingDecoding() async throws {
        let observation = Observation(
            id: "obs-001",
            status: "final",
            code: CodeableConcept(
                coding: [Coding(system: "http://loinc.org", code: "8867-4", display: "Heart rate")],
                text: "Heart Rate"
            ),
            subject: Reference(reference: "Patient/patient-001"),
            valueQuantity: Quantity(value: 72, unit: "beats/minute", system: "http://unitsofmeasure.org", code: "/min")
        )
        
        let jsonData = try await FHIRJSON.encode(observation)
        let decoded = try await FHIRJSON.decode(Observation.self, from: jsonData)
        
        XCTAssertEqual(decoded.resourceType, "Observation")
        XCTAssertEqual(decoded.id, "obs-001")
        XCTAssertEqual(decoded.status, "final")
        XCTAssertEqual(decoded.code.text, "Heart Rate")
        XCTAssertEqual(decoded.valueQuantity?.value, 72)
    }
    
    // MARK: - Bundle JSON Serialization Tests
    
    func testBundleJSONEncodingDecoding() async throws {
        let patient1 = Patient(id: "patient-001", name: [HumanName(family: "Smith")])
        let patient2 = Patient(id: "patient-002", name: [HumanName(family: "Doe")])
        
        let bundle = Bundle(
            id: "bundle-001",
            type: "searchset",
            total: 2,
            entry: [
                BundleEntry(resource: .patient(patient1)),
                BundleEntry(resource: .patient(patient2))
            ]
        )
        
        let jsonData = try await FHIRJSON.encode(bundle)
        let decoded = try await FHIRJSON.decode(Bundle.self, from: jsonData)
        
        XCTAssertEqual(decoded.resourceType, "Bundle")
        XCTAssertEqual(decoded.type, "searchset")
        XCTAssertEqual(decoded.total, 2)
        XCTAssertEqual(decoded.entry?.count, 2)
    }
    
    // MARK: - ResourceContainer Tests
    
    func testResourceContainerDecoding() async throws {
        let patientJSON = """
        {
            "resourceType": "Patient",
            "id": "patient-001",
            "messageID": "test-msg-001",
            "timestamp": "2024-01-01T00:00:00Z",
            "name": [{"family": "Smith"}]
        }
        """
        
        let container = try await FHIRJSON.decodeResource(from: patientJSON)
        
        if case .patient(let patient) = container {
            XCTAssertEqual(patient.id, "patient-001")
            XCTAssertEqual(patient.name?.first?.family, "Smith")
        } else {
            XCTFail("Expected patient resource")
        }
    }
    
    // MARK: - Serializer Actor Tests
    
    func testSerializerActor() async throws {
        let serializer = FHIRJSONSerializer()
        let patient = Patient(id: "test-001", name: [HumanName(family: "Test")])
        
        let data = try await serializer.encode(patient)
        XCTAssertFalse(data.isEmpty)
        
        let decoded = try await serializer.decode(Patient.self, from: data)
        XCTAssertEqual(decoded.id, "test-001")
    }
    
    // MARK: - Pretty Printing Tests
    
    func testPrettyPrintedOutput() async throws {
        let patient = Patient(id: "patient-001", name: [HumanName(family: "Smith")])
        let config = FHIRSerializationConfiguration.prettyPrinted
        
        let jsonString = try await FHIRJSON.encodeToString(patient, configuration: config)
        
        // Pretty-printed JSON should have newlines and indentation
        XCTAssertTrue(jsonString.contains("\n"))
        XCTAssertTrue(jsonString.contains("  "))
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidJSONDecoding() async {
        do {
            _ = try await FHIRJSON.decode(Patient.self, from: "invalid json")
            XCTFail("Should have thrown an error")
        } catch let error as FHIRSerializationError {
            switch error {
            case .invalidJSON:
                XCTAssertTrue(true)
            default:
                XCTFail("Expected invalidJSON error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Bundle Streaming Parser Tests
    
    func testBundleStreamParser() async throws {
        let patient1 = Patient(id: "patient-001", name: [HumanName(family: "Smith")])
        let patient2 = Patient(id: "patient-002", name: [HumanName(family: "Doe")])
        let patient3 = Patient(id: "patient-003", name: [HumanName(family: "Johnson")])
        
        let bundle = Bundle(
            id: "bundle-001",
            type: "searchset",
            total: 3,
            entry: [
                BundleEntry(resource: .patient(patient1)),
                BundleEntry(resource: .patient(patient2)),
                BundleEntry(resource: .patient(patient3))
            ]
        )
        
        let bundleData = try await FHIRJSON.encode(bundle)
        
        let parser = FHIRBundleStreamParser()
        let stream = try await parser.parseBundleEntries(from: bundleData)
        
        var count = 0
        for await resource in stream {
            count += 1
            switch resource {
            case .patient(let patient):
                XCTAssertTrue(patient.id?.starts(with: "patient-") ?? false)
            default:
                XCTFail("Expected patient resource")
            }
        }
        
        XCTAssertEqual(count, 3)
    }
    
    func testBundleStreamParserWithEmptyBundle() async throws {
        let bundle = Bundle(id: "bundle-empty", type: "searchset", total: 0, entry: nil)
        let bundleData = try await FHIRJSON.encode(bundle)
        
        let parser = FHIRBundleStreamParser()
        let stream = try await parser.parseBundleEntries(from: bundleData)
        
        var count = 0
        for await _ in stream {
            count += 1
        }
        
        XCTAssertEqual(count, 0)
    }
    
    // MARK: - Complex Resource Tests
    
    func testPractitionerSerialization() async throws {
        let practitioner = Practitioner(
            id: "pract-001",
            identifier: [Identifier(system: "http://hospital.org/npi", value: "1234567890")],
            active: true,
            name: [HumanName(family: "Johnson", given: ["Alice"])],
            gender: "female",
            qualification: [
                PractitionerQualification(
                    code: CodeableConcept(text: "MD"),
                    period: Period(start: "2010-01-01")
                )
            ]
        )
        
        let data = try await FHIRJSON.encode(practitioner)
        let decoded = try await FHIRJSON.decode(Practitioner.self, from: data)
        
        XCTAssertEqual(decoded.id, "pract-001")
        XCTAssertEqual(decoded.name?.first?.family, "Johnson")
        XCTAssertEqual(decoded.qualification?.count, 1)
    }
    
    func testMedicationRequestSerialization() async throws {
        let medRequest = MedicationRequest(
            id: "med-001",
            status: "active",
            intent: "order",
            medicationCodeableConcept: CodeableConcept(
                coding: [Coding(system: "http://www.nlm.nih.gov/research/umls/rxnorm", code: "197806")],
                text: "Ibuprofen 400mg"
            ),
            subject: Reference(reference: "Patient/patient-001")
        )
        
        let data = try await FHIRJSON.encode(medRequest)
        let decoded = try await FHIRJSON.decode(MedicationRequest.self, from: data)
        
        XCTAssertEqual(decoded.status, "active")
        XCTAssertEqual(decoded.medicationCodeableConcept?.text, "Ibuprofen 400mg")
    }
}
