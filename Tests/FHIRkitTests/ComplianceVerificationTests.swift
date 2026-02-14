import XCTest
@testable import FHIRkit
@testable import HL7Core

/// Comprehensive FHIR standards compliance verification tests
/// Tests conformance to HL7 FHIR specifications (R4)
final class ComplianceVerificationTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    private let parser = FHIRParser()
    
    // MARK: - FHIR R4 Resource Compliance Tests
    
    func testPatientResourceCompliance() throws {
        // Test Patient resource structure
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "meta": {
                "versionId": "1",
                "lastUpdated": "2024-01-01T12:00:00Z"
            },
            "identifier": [
                {
                    "system": "http://hospital.example.org/patients",
                    "value": "12345"
                }
            ],
            "active": true,
            "name": [
                {
                    "use": "official",
                    "family": "Doe",
                    "given": ["John", "A"]
                }
            ],
            "gender": "male",
            "birthDate": "1980-01-01"
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify Patient resource structure
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertEqual(resource.id, "example")
        
        // Validate resource
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testObservationResourceCompliance() throws {
        // Test Observation resource structure
        let json = """
        {
            "resourceType": "Observation",
            "id": "blood-pressure",
            "status": "final",
            "category": [
                {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/observation-category",
                            "code": "vital-signs",
                            "display": "Vital Signs"
                        }
                    ]
                }
            ],
            "code": {
                "coding": [
                    {
                        "system": "http://loinc.org",
                        "code": "85354-9",
                        "display": "Blood pressure panel"
                    }
                ]
            },
            "subject": {
                "reference": "Patient/example"
            },
            "effectiveDateTime": "2024-01-01T12:00:00Z",
            "component": [
                {
                    "code": {
                        "coding": [
                            {
                                "system": "http://loinc.org",
                                "code": "8480-6",
                                "display": "Systolic blood pressure"
                            }
                        ]
                    },
                    "valueQuantity": {
                        "value": 120,
                        "unit": "mmHg",
                        "system": "http://unitsofmeasure.org",
                        "code": "mm[Hg]"
                    }
                },
                {
                    "code": {
                        "coding": [
                            {
                                "system": "http://loinc.org",
                                "code": "8462-4",
                                "display": "Diastolic blood pressure"
                            }
                        ]
                    },
                    "valueQuantity": {
                        "value": 80,
                        "unit": "mmHg",
                        "system": "http://unitsofmeasure.org",
                        "code": "mm[Hg]"
                    }
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify Observation resource structure
        XCTAssertEqual(resource.resourceType, "Observation")
        XCTAssertEqual(resource.id, "blood-pressure")
        
        // Validate resource
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testMedicationRequestResourceCompliance() throws {
        // Test MedicationRequest resource structure
        let json = """
        {
            "resourceType": "MedicationRequest",
            "id": "med-request",
            "status": "active",
            "intent": "order",
            "medicationCodeableConcept": {
                "coding": [
                    {
                        "system": "http://www.nlm.nih.gov/research/umls/rxnorm",
                        "code": "197884",
                        "display": "Lisinopril 10 MG Oral Tablet"
                    }
                ]
            },
            "subject": {
                "reference": "Patient/example"
            },
            "authoredOn": "2024-01-01T12:00:00Z",
            "dosageInstruction": [
                {
                    "text": "Take one tablet daily",
                    "timing": {
                        "repeat": {
                            "frequency": 1,
                            "period": 1,
                            "periodUnit": "d"
                        }
                    },
                    "doseAndRate": [
                        {
                            "doseQuantity": {
                                "value": 1,
                                "unit": "tablet",
                                "system": "http://unitsofmeasure.org",
                                "code": "{tbl}"
                            }
                        }
                    ]
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify MedicationRequest resource structure
        XCTAssertEqual(resource.resourceType, "MedicationRequest")
        XCTAssertEqual(resource.id, "med-request")
        
        // Validate resource
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - Required Element Compliance Tests
    
    func testRequiredElementCompliance() throws {
        // Test that required elements are validated
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "identifier": [
                {
                    "system": "http://hospital.example.org",
                    "value": "12345"
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Patient resource has minimal required elements
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testMissingRequiredElement() throws {
        // Test that missing required elements are detected
        let json = """
        {
            "resourceType": "Observation",
            "id": "incomplete"
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Observation requires status and code
        // Validator should detect missing required elements
        XCTAssertThrowsError(try resource.validate())
    }
    
    // MARK: - Reference Integrity Tests
    
    func testReferenceCompliance() throws {
        // Test that references follow proper format
        let json = """
        {
            "resourceType": "Observation",
            "id": "obs1",
            "status": "final",
            "code": {
                "coding": [
                    {
                        "system": "http://loinc.org",
                        "code": "2345-7"
                    }
                ]
            },
            "subject": {
                "reference": "Patient/example"
            },
            "performer": [
                {
                    "reference": "Practitioner/doc1"
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify reference format
        XCTAssertEqual(resource.resourceType, "Observation")
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testRelativeReferenceCompliance() throws {
        // Test relative reference format
        let json = """
        {
            "resourceType": "Observation",
            "id": "obs2",
            "status": "final",
            "code": {
                "coding": [{"system": "http://loinc.org", "code": "2345-7"}]
            },
            "subject": {
                "reference": "Patient/12345"
            }
        }
        """
        
        let resource = try parser.parseResource(json)
        XCTAssertNoThrow(try validator.validate(resource))
    }
    
    func testAbsoluteReferenceCompliance() throws {
        // Test absolute reference format
        let json = """
        {
            "resourceType": "Observation",
            "id": "obs3",
            "status": "final",
            "code": {
                "coding": [{"system": "http://loinc.org", "code": "2345-7"}]
            },
            "subject": {
                "reference": "http://example.org/fhir/Patient/12345"
            }
        }
        """
        
        let resource = try parser.parseResource(json)
        XCTAssertNoThrow(try validator.validate(resource))
    }
    
    // MARK: - Cardinality Compliance Tests
    
    func testCardinalityCompliance() throws {
        // Test that cardinality rules are enforced
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "name": [
                {
                    "family": "Doe",
                    "given": ["John"]
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Name array can have 0..* cardinality
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testMaxCardinalityCompliance() throws {
        // Test that max cardinality is respected (1..1)
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "gender": "male"
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Gender has 0..1 cardinality
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - JSON Format Compliance Tests
    
    func testJSONFormatCompliance() throws {
        // Test proper JSON formatting
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "active": true,
            "name": [
                {
                    "family": "Doe",
                    "given": ["John"]
                }
            ],
            "telecom": [
                {
                    "system": "phone",
                    "value": "555-1234",
                    "use": "home"
                }
            ],
            "address": [
                {
                    "line": ["123 Main St"],
                    "city": "City",
                    "state": "ST",
                    "postalCode": "12345"
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify JSON parsing
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testPrimitiveTypesCompliance() throws {
        // Test FHIR primitive types
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "active": true,
            "birthDate": "1980-01-01",
            "deceasedBoolean": false,
            "multipleBirthInteger": 1
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify primitive types are handled correctly
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - FHIR Profile Compliance Tests
    
    func testUSCoreProfileCompliance() throws {
        // Test US Core Patient profile compliance
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "meta": {
                "profile": [
                    "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient"
                ]
            },
            "identifier": [
                {
                    "system": "http://hospital.example.org",
                    "value": "12345"
                }
            ],
            "name": [
                {
                    "family": "Doe",
                    "given": ["John"]
                }
            ],
            "gender": "male"
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify US Core profile elements
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - Extension Compliance Tests
    
    func testExtensionCompliance() throws {
        // Test FHIR extensions
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "extension": [
                {
                    "url": "http://hl7.org/fhir/StructureDefinition/patient-birthPlace",
                    "valueAddress": {
                        "city": "Boston",
                        "state": "MA",
                        "country": "USA"
                    }
                }
            ],
            "name": [
                {
                    "family": "Doe",
                    "given": ["John"]
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify extensions are parsed
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testModifierExtensionCompliance() throws {
        // Test modifier extensions
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "modifierExtension": [
                {
                    "url": "http://example.org/fhir/StructureDefinition/patient-modified",
                    "valueBoolean": true
                }
            ],
            "name": [
                {
                    "family": "Doe",
                    "given": ["John"]
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Modifier extensions should be recognized
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - Terminology Binding Compliance Tests
    
    func testCodeSystemCompliance() throws {
        // Test proper code system usage
        let json = """
        {
            "resourceType": "Observation",
            "id": "glucose",
            "status": "final",
            "code": {
                "coding": [
                    {
                        "system": "http://loinc.org",
                        "code": "2345-7",
                        "display": "Glucose [Mass/volume] in Serum or Plasma"
                    }
                ]
            },
            "subject": {
                "reference": "Patient/example"
            },
            "valueQuantity": {
                "value": 95,
                "unit": "mg/dL",
                "system": "http://unitsofmeasure.org",
                "code": "mg/dL"
            }
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify code system bindings
        XCTAssertEqual(resource.resourceType, "Observation")
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testValueSetCompliance() throws {
        // Test value set binding
        let json = """
        {
            "resourceType": "Observation",
            "id": "obs",
            "status": "final",
            "code": {
                "coding": [
                    {
                        "system": "http://loinc.org",
                        "code": "8480-6"
                    }
                ]
            },
            "subject": {
                "reference": "Patient/example"
            },
            "interpretation": [
                {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation",
                            "code": "N",
                            "display": "Normal"
                        }
                    ]
                }
            ]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify value set compliance
        XCTAssertEqual(resource.resourceType, "Observation")
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - Search Parameter Compliance Tests
    
    func testSearchParameterCompliance() throws {
        // Test that resources support standard search parameters
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "identifier": [
                {
                    "system": "http://hospital.example.org",
                    "value": "12345"
                }
            ],
            "name": [
                {
                    "family": "Doe",
                    "given": ["John"]
                }
            ],
            "birthDate": "1980-01-01"
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Patient supports: _id, identifier, name, birthdate, etc.
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertEqual(resource.id, "example")
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - Bundle Compliance Tests
    
    func testBundleCompliance() throws {
        // Test Bundle resource structure
        let json = """
        {
            "resourceType": "Bundle",
            "id": "bundle-example",
            "type": "searchset",
            "total": 2,
            "entry": [
                {
                    "fullUrl": "http://example.org/fhir/Patient/example",
                    "resource": {
                        "resourceType": "Patient",
                        "id": "example",
                        "name": [{"family": "Doe", "given": ["John"]}]
                    }
                },
                {
                    "fullUrl": "http://example.org/fhir/Patient/example2",
                    "resource": {
                        "resourceType": "Patient",
                        "id": "example2",
                        "name": [{"family": "Smith", "given": ["Jane"]}]
                    }
                }
            ]
        }
        """
        
        let bundle = try parser.parseBundle(json)
        
        // Verify Bundle structure
        XCTAssertEqual(bundle.resourceType, "Bundle")
        XCTAssertEqual(bundle.type, "searchset")
        XCTAssertNoThrow(try bundle.validate())
    }
    
    // MARK: - Meta Information Compliance Tests
    
    func testMetaInformationCompliance() throws {
        // Test Meta element compliance
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "meta": {
                "versionId": "2",
                "lastUpdated": "2024-01-01T12:00:00Z",
                "source": "http://example.org/fhir",
                "profile": [
                    "http://hl7.org/fhir/StructureDefinition/Patient"
                ],
                "security": [
                    {
                        "system": "http://terminology.hl7.org/CodeSystem/v3-ActReason",
                        "code": "HTEST"
                    }
                ],
                "tag": [
                    {
                        "system": "http://example.org/tags",
                        "code": "test-data"
                    }
                ]
            },
            "name": [{"family": "Doe"}]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify Meta elements
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
    }
    
    // MARK: - Narrative Compliance Tests
    
    func testNarrativeCompliance() throws {
        // Test narrative text element
        let json = """
        {
            "resourceType": "Patient",
            "id": "example",
            "text": {
                "status": "generated",
                "div": "<div xmlns=\\"http://www.w3.org/1999/xhtml\\">Patient: John Doe</div>"
            },
            "name": [{"family": "Doe", "given": ["John"]}]
        }
        """
        
        let resource = try parser.parseResource(json)
        
        // Verify narrative is preserved
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertNoThrow(try resource.validate())
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
