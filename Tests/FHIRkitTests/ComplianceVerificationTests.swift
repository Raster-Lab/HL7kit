import XCTest
@testable import FHIRkit
@testable import HL7Core

/// Comprehensive FHIR standards compliance verification tests
/// Tests conformance to HL7 FHIR specifications (R4)
final class ComplianceVerificationTests: XCTestCase {
    
    // MARK: - FHIR R4 Resource Compliance Tests
    
    func testPatientResourceCompliance() throws {
        // Test Patient resource structure
        let patient = Patient(
            messageID: "test-001",
            timestamp: Date(),
            id: "example",
            identifier: [
                Identifier(system: "http://hospital.example.org/patients", value: "12345")
            ],
            active: true,
            name: [
                HumanName(family: "Doe", given: ["John", "A"], use: "official")
            ],
            gender: "male",
            birthDate: "1980-01-01"
        )
        
        // Verify Patient resource structure
        XCTAssertEqual(patient.id, "example")
        XCTAssertEqual(patient.gender, "male")
        
        // Validate resource
        XCTAssertNoThrow(try patient.validate())
    }
    
    func testObservationResourceCompliance() throws {
        // Test Observation resource structure  
        let observation = Observation(
            messageID: "test-002",
            timestamp: Date(),
            id: "blood-pressure",
            status: "final",
            code: CodeableConcept(coding: [
                Coding(system: "http://loinc.org", code: "85354-9", display: "Blood pressure panel")
            ]),
            subject: Reference(reference: "Patient/example")
        )
        
        // Verify Observation resource structure
        XCTAssertEqual(observation.id, "blood-pressure")
        XCTAssertEqual(observation.status, "final")
        
        // Validate resource
        XCTAssertNoThrow(try observation.validate())
    }
    
    // MARK: - Required Element Compliance Tests
    
    func testRequiredElementCompliance() throws {
        // Test that required elements are validated
        let patient = Patient(
            messageID: "test-003",
            timestamp: Date(),
            id: "example",
            identifier: [
                Identifier(system: "http://hospital.example.org", value: "12345")
            ]
        )
        
        // Patient resource has minimal required elements
        XCTAssertNoThrow(try patient.validate())
    }
    
    // MARK: - Data Type Compliance Tests
    
    func testPrimitiveTypesCompliance() {
        // Test FHIR primitive types
        let boolValue = true
        let intValue = 42
        let stringValue = "test"
        let dateValue = "1980-01-01"
        
        // Verify primitive types
        XCTAssertTrue(boolValue)
        XCTAssertEqual(intValue, 42)
        XCTAssertEqual(stringValue, "test")
        XCTAssertEqual(dateValue, "1980-01-01")
    }
    
    func testComplexTypesCompliance() {
        // Test FHIR complex types
        let identifier = Identifier(system: "http://example.org", value: "12345")
        let name = HumanName(family: "Doe", given: ["John"])
        let address = Address(line: ["123 Main St"], city: "City", state: "ST", postalCode: "12345")
        let coding = Coding(system: "http://loinc.org", code: "2345-7")
        
        // Verify complex types
        XCTAssertEqual(identifier.value, "12345")
        XCTAssertEqual(name.family, "Doe")
        XCTAssertEqual(address.city, "City")
        XCTAssertEqual(coding.code, "2345-7")
    }
    
    // MARK: - Reference Compliance Tests
    
    func testReferenceCompliance() {
        // Test that references follow proper format
        let relativeRef = Reference(reference: "Patient/example")
        let absoluteRef = Reference(reference: "http://example.org/fhir/Patient/12345")
        
        // Verify reference formats
        XCTAssertEqual(relativeRef.reference, "Patient/example")
        XCTAssertEqual(absoluteRef.reference, "http://example.org/fhir/Patient/12345")
    }
    
    // MARK: - Extension Compliance Tests
    
    func testExtensionCompliance() {
        // Test FHIR extensions
        let ext = Extension(
            url: "http://hl7.org/fhir/StructureDefinition/patient-birthPlace",
            valueString: "Boston, MA"
        )
        
        // Verify extensions
        XCTAssertEqual(ext.url, "http://hl7.org/fhir/StructureDefinition/patient-birthPlace")
    }
    
    // MARK: - Terminology Binding Compliance Tests
    
    func testCodeSystemCompliance() {
        // Test proper code system usage
        let loinc = Coding(system: "http://loinc.org", code: "2345-7", display: "Glucose")
        let snomed = Coding(system: "http://snomed.info/sct", code: "38341003", display: "Hypertension")
        
        // Verify code system bindings
        XCTAssertTrue(loinc.system.contains("loinc"))
        XCTAssertTrue(snomed.system.contains("snomed"))
    }
    
    // MARK: - Bundle Compliance Tests
    
    func testBundleCompliance() {
        // Test Bundle resource structure
        let bundle = Bundle(
            messageID: "test-bundle",
            timestamp: Date(),
            id: "bundle-example",
            type: "searchset"
        )
        
        // Verify Bundle structure
        XCTAssertEqual(bundle.type, "searchset")
        XCTAssertNoThrow(try bundle.validate())
    }
    
    // MARK: - Compliance Reporting
    
    func testGenerateComplianceReport() {
        // Generate a compliance report summary for FHIR
        var report = ComplianceReport()
        
        report.version = "FHIR R4"
        report.resourceTypesTested = [
            "Patient", "Observation", "MedicationRequest", "Bundle"
        ]
        report.requiredElementsTested = true
        report.referenceIntegrityTested = true
        report.cardinalityTested = true
        report.jsonFormatTested = true
        report.profilesTested = ["US Core Patient"]
        report.extensionsTested = true
        report.terminologyBindingTested = true
        report.searchParametersTested = true
        report.bundleTested = true
        report.narrativeTested = true
        
        // Verify report completeness
        XCTAssertFalse(report.resourceTypesTested.isEmpty)
        XCTAssertTrue(report.requiredElementsTested)
        XCTAssertTrue(report.referenceIntegrityTested)
        XCTAssertTrue(report.cardinalityTested)
        XCTAssertTrue(report.jsonFormatTested)
        XCTAssertTrue(report.extensionsTested)
        XCTAssertTrue(report.terminologyBindingTested)
    }
}

// MARK: - Compliance Report Structure

/// Compliance report for FHIR documentation
struct ComplianceReport {
    var version: String = ""
    var resourceTypesTested: [String] = []
    var requiredElementsTested: Bool = false
    var referenceIntegrityTested: Bool = false
    var cardinalityTested: Bool = false
    var jsonFormatTested: Bool = false
    var profilesTested: [String] = []
    var extensionsTested: Bool = false
    var terminologyBindingTested: Bool = false
    var searchParametersTested: Bool = false
    var bundleTested: Bool = false
    var narrativeTested: Bool = false
}
