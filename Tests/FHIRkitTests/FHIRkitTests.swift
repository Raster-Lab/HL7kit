import XCTest
@testable import FHIRkit
@testable import HL7Core

/// Tests for FHIRkit module
final class FHIRkitTests: XCTestCase {
    
    // MARK: - Version Tests
    
    func testVersionInformation() {
        XCTAssertEqual(FHIRkitVersion.version, "0.1.0")
    }
    
    // MARK: - Resource Creation Tests
    
    func testBasicResourceCreation() {
        let resource = FHIRBasicResource(
            resourceType: "Patient",
            id: "patient-001",
            messageID: "MSG001",
            timestamp: Date()
        )
        
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertEqual(resource.id, "patient-001")
        XCTAssertEqual(resource.messageID, "MSG001")
    }
    
    func testResourceWithoutID() {
        let resource = FHIRBasicResource(
            resourceType: "Observation",
            messageID: "MSG002"
        )
        
        XCTAssertEqual(resource.resourceType, "Observation")
        XCTAssertNil(resource.id)
    }
    
    func testResourceTimestamp() {
        let timestamp = Date()
        let resource = FHIRBasicResource(
            resourceType: "Encounter",
            messageID: "MSG003",
            timestamp: timestamp
        )
        
        XCTAssertEqual(resource.timestamp, timestamp)
    }
    
    // MARK: - Resource Validation Tests
    
    func testValidResourceValidation() throws {
        let resource = FHIRBasicResource(
            resourceType: "Patient",
            id: "patient-001",
            messageID: "MSG001"
        )
        
        XCTAssertNoThrow(try resource.validate())
    }
    
    func testEmptyResourceTypeValidation() {
        let resource = FHIRBasicResource(
            resourceType: "",
            messageID: "MSG001"
        )
        
        XCTAssertThrowsError(try resource.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    // MARK: - Resource Type Tests
    
    func testCommonResourceTypes() {
        let resourceTypes = [
            "Patient", "Practitioner", "Organization",
            "Observation", "Condition", "AllergyIntolerance",
            "Encounter", "Appointment", "Schedule",
            "MedicationRequest", "MedicationStatement",
            "DiagnosticReport", "DocumentReference",
            "Bundle", "OperationOutcome"
        ]
        
        for (index, type) in resourceTypes.enumerated() {
            let resource = FHIRBasicResource(
                resourceType: type,
                id: "\(type.lowercased())-\(index)",
                messageID: "MSG\(String(format: "%03d", index))"
            )
            
            XCTAssertEqual(resource.resourceType, type)
        }
    }
    
    // MARK: - Codable Tests
    
    func testResourceJSONEncoding() throws {
        let resource = FHIRBasicResource(
            resourceType: "Patient",
            id: "patient-001",
            messageID: "MSG001",
            timestamp: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(resource)
        
        XCTAssertFalse(jsonData.isEmpty)
        
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"resourceType\":\"Patient\""))
    }
    
    func testResourceJSONDecoding() throws {
        let jsonString = """
        {
            "resourceType": "Patient",
            "id": "patient-001",
            "messageID": "MSG001",
            "timestamp": "2024-01-01T12:00:00Z"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resource = try decoder.decode(FHIRBasicResource.self, from: jsonString.data(using: .utf8)!)
        
        XCTAssertEqual(resource.resourceType, "Patient")
        XCTAssertEqual(resource.id, "patient-001")
        XCTAssertEqual(resource.messageID, "MSG001")
    }
    
    func testResourceRoundTripEncoding() throws {
        let original = FHIRBasicResource(
            resourceType: "Observation",
            id: "obs-001",
            messageID: "MSG001",
            timestamp: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FHIRBasicResource.self, from: jsonData)
        
        XCTAssertEqual(original.resourceType, decoded.resourceType)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.messageID, decoded.messageID)
    }
    
    // MARK: - Multiple Resource Tests
    
    func testMultipleResourceCreation() {
        let resources = (1...10).map { i in
            FHIRBasicResource(
                resourceType: "Patient",
                id: "patient-\(String(format: "%03d", i))",
                messageID: "MSG\(String(format: "%03d", i))"
            )
        }
        
        XCTAssertEqual(resources.count, 10)
        XCTAssertEqual(resources.first?.id, "patient-001")
        XCTAssertEqual(resources.last?.id, "patient-010")
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() async {
        let resource = FHIRBasicResource(
            resourceType: "Patient",
            id: "patient-001",
            messageID: "MSG001"
        )
        
        await Task {
            XCTAssertEqual(resource.resourceType, "Patient")
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testResourceCreationPerformance() {
        measure {
            for i in 0..<1000 {
                _ = FHIRBasicResource(
                    resourceType: "Patient",
                    id: "patient-\(i)",
                    messageID: "MSG\(i)"
                )
            }
        }
    }
    
    func testResourceValidationPerformance() throws {
        let resource = FHIRBasicResource(
            resourceType: "Patient",
            id: "patient-001",
            messageID: "MSG001"
        )
        
        measure {
            for _ in 0..<1000 {
                try? resource.validate()
            }
        }
    }
    
    func testResourceEncodingPerformance() throws {
        let resource = FHIRBasicResource(
            resourceType: "Patient",
            id: "patient-001",
            messageID: "MSG001",
            timestamp: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(resource)
            }
        }
    }
}
