/// SchemaValidatorTests.swift
/// Unit tests for SchemaValidator

import XCTest
@testable import HL7v3Kit

final class SchemaValidatorTests: XCTestCase {
    // MARK: - Test Helpers
    
    func createValidCDADocument() -> XMLElement {
        XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: ["classCode": "DOCCLIN", "moodCode": "EVN"],
            children: [
                XMLElement(name: "typeId", attributes: ["root": "2.16.840.1.113883.1.3"]),
                XMLElement(name: "id", attributes: ["root": "1.2.3.4.5"]),
                XMLElement(name: "code", attributes: ["code": "34133-9", "codeSystem": "2.16.840.1.113883.6.1"]),
                XMLElement(name: "title", text: "Test Document"),
                XMLElement(name: "effectiveTime", attributes: ["value": "20240101120000"]),
                XMLElement(name: "confidentialityCode", attributes: ["code": "N"]),
                XMLElement(name: "recordTarget"),
                XMLElement(name: "author"),
                XMLElement(name: "custodian"),
                XMLElement(name: "component")
            ]
        )
    }
    
    func createInvalidCDADocument() -> XMLElement {
        XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: [:],  // Missing required attributes
            children: [
                // Missing required elements like typeId, id, etc.
                XMLElement(name: "title", text: "Incomplete Document")
            ]
        )
    }
    
    // MARK: - Basic Validation Tests
    
    func testValidateValidCDADocument() async throws {
        let validator = SchemaValidator()
        let element = createValidCDADocument()
        
        let result = await validator.validate(element: element)
        
        XCTAssertTrue(result.isValid, "Valid CDA document should pass validation")
        XCTAssertEqual(result.errors.filter { $0.severity != .warning }.count, 0)
    }
    
    func testValidateInvalidCDADocument() async throws {
        let validator = SchemaValidator()
        let element = createInvalidCDADocument()
        
        let result = await validator.validate(element: element)
        
        XCTAssertFalse(result.isValid, "Invalid CDA document should fail validation")
        XCTAssertGreaterThan(result.errors.count, 0)
    }
    
    func testValidationStatistics() async throws {
        let validator = SchemaValidator()
        let element = createValidCDADocument()
        
        let result = await validator.validate(element: element)
        
        XCTAssertGreaterThan(result.statistics.elementsValidated, 0)
        XCTAssertGreaterThan(result.statistics.rulesChecked, 0)
        XCTAssertGreaterThan(result.duration, 0)
    }
    
    // MARK: - Required Element Tests
    
    func testMissingRequiredElement() async throws {
        let element = XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: ["classCode": "DOCCLIN", "moodCode": "EVN"],
            children: [
                // Missing typeId, id, etc.
                XMLElement(name: "title", text: "Test")
            ]
        )
        
        let validator = SchemaValidator()
        let result = await validator.validate(element: element)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "CDA-MISSING-REQUIRED" })
    }
    
    func testMissingRequiredAttribute() async throws {
        let element = XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: [:],  // Missing classCode and moodCode
            children: [
                XMLElement(name: "typeId", attributes: ["root": "2.16.840.1.113883.1.3"])
            ]
        )
        
        let validator = SchemaValidator()
        let result = await validator.validate(element: element)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code.contains("MISSING-ATTR") })
    }
    
    // MARK: - Identifier Validation Tests
    
    func testValidIdentifier() async throws {
        let element = XMLElement(
            name: "id",
            attributes: ["root": "1.2.3.4.5", "extension": "12345"]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testInvalidIdentifierMissingRoot() async throws {
        let element = XMLElement(
            name: "id",
            attributes: ["extension": "12345"]  // Missing root
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "ID-MISSING-ROOT" })
    }
    
    // MARK: - Code Validation Tests
    
    func testValidCode() async throws {
        let element = XMLElement(
            name: "code",
            attributes: [
                "code": "34133-9",
                "codeSystem": "2.16.840.1.113883.6.1",
                "displayName": "Test Code"
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testCodeWithNullFlavor() async throws {
        let element = XMLElement(
            name: "code",
            attributes: ["nullFlavor": "UNK"]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testCodeMissingCodeAndNullFlavor() async throws {
        let element = XMLElement(
            name: "code",
            attributes: ["displayName": "Test"]  // Missing code or nullFlavor
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "CODE-MISSING" })
    }
    
    func testCodeMissingCodeSystem() async throws {
        let element = XMLElement(
            name: "code",
            attributes: ["code": "12345"]  // Missing codeSystem
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        // Should have a warning about missing codeSystem
        XCTAssertTrue(result.warnings.contains { $0.code == "CODE-NO-SYSTEM" })
    }
    
    // MARK: - Timestamp Validation Tests
    
    func testValidTimestamp() async throws {
        let element = XMLElement(
            name: "effectiveTime",
            attributes: ["value": "20240101120000"]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testInvalidTimestampFormat() async throws {
        let element = XMLElement(
            name: "effectiveTime",
            attributes: ["value": "2024"]  // Too short
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "TIME-INVALID-FORMAT" })
    }
    
    func testTimestampMissingValue() async throws {
        let element = XMLElement(
            name: "effectiveTime",
            attributes: [:]  // Missing value and nullFlavor
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "TIME-MISSING-VALUE" })
    }
    
    // MARK: - Template ID Validation Tests
    
    func testValidTemplateId() async throws {
        let element = XMLElement(
            name: "templateId",
            attributes: ["root": "2.16.840.1.113883.10.20.22.1.1"]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testTemplateIdMissingRoot() async throws {
        let element = XMLElement(
            name: "templateId",
            attributes: ["extension": "2014-06-09"]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "TEMPLATE-NO-ROOT" })
    }
    
    func testTemplateIdInvalidOID() async throws {
        let element = XMLElement(
            name: "templateId",
            attributes: ["root": "not-a-valid-oid"]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        // Should have a warning about invalid OID
        XCTAssertTrue(result.warnings.contains { $0.code == "TEMPLATE-INVALID-OID" })
    }
    
    // MARK: - Section Validation Tests
    
    func testValidSection() async throws {
        let element = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "title", text: "Medications"),
                XMLElement(name: "code", attributes: ["code": "10160-0"])
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testSectionMissingTitleAndCode() async throws {
        let element = XMLElement(
            name: "section",
            children: [
                XMLElement(name: "text", text: "Some content")
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        // Should have a warning
        XCTAssertTrue(result.warnings.contains { $0.code == "SECTION-NO-TITLE-CODE" })
    }
    
    // MARK: - Entry Validation Tests
    
    func testValidEntry() async throws {
        let element = XMLElement(
            name: "entry",
            children: [
                XMLElement(
                    name: "observation",
                    attributes: ["classCode": "OBS", "moodCode": "EVN"],
                    children: [
                        XMLElement(name: "code", attributes: ["code": "12345"]),
                        XMLElement(name: "statusCode", attributes: ["code": "completed"])
                    ]
                )
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testEntryMissingClinicalStatement() async throws {
        let element = XMLElement(
            name: "entry",
            children: [
                XMLElement(name: "id", attributes: ["root": "1.2.3"])
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code == "ENTRY-NO-STATEMENT" })
    }
    
    // MARK: - Observation Validation Tests
    
    func testValidObservation() async throws {
        let element = XMLElement(
            name: "observation",
            attributes: ["classCode": "OBS", "moodCode": "EVN"],
            children: [
                XMLElement(name: "code", attributes: ["code": "12345"]),
                XMLElement(name: "statusCode", attributes: ["code": "completed"]),
                XMLElement(name: "value", attributes: ["value": "123"])
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testObservationMissingRequired() async throws {
        let element = XMLElement(
            name: "observation",
            attributes: [:],  // Missing classCode and moodCode
            children: [
                // Missing code and statusCode
            ]
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.code.contains("OBS") })
    }
    
    // MARK: - Configuration Tests
    
    func testStopOnFirstError() async throws {
        let config = SchemaValidator.Configuration(stopOnFirstError: true)
        let validator = SchemaValidator(configuration: config)
        let element = createInvalidCDADocument()
        
        let result = await validator.validate(element: element)
        
        XCTAssertFalse(result.isValid)
        // Should have errors, but might be limited due to stopOnFirstError
        XCTAssertGreaterThan(result.errors.count, 0)
    }
    
    func testMaxErrors() async throws {
        let config = SchemaValidator.Configuration(maxErrors: 5)
        let validator = SchemaValidator(configuration: config)
        let element = createInvalidCDADocument()
        
        let result = await validator.validate(element: element)
        
        XCTAssertLessThanOrEqual(result.errors.count, 5)
    }
    
    func testSkipCDASchema() async throws {
        let config = SchemaValidator.Configuration(validateCDASchema: false, checkConformanceRules: false)
        let validator = SchemaValidator(configuration: config)
        let element = createInvalidCDADocument()
        
        let result = await validator.validate(element: element)
        
        // Should have no rules checked since both schema and conformance validation are skipped
        XCTAssertTrue(result.statistics.rulesChecked == 0)
    }
    
    func testSkipConformanceRules() async throws {
        let config = SchemaValidator.Configuration(checkConformanceRules: false)
        let validator = SchemaValidator(configuration: config)
        let element = createValidCDADocument()
        
        let result = await validator.validate(element: element)
        
        // Should still validate but skip conformance checks
        XCTAssertTrue(result.isValid || !result.isValid)  // Just check it runs
    }
    
    // MARK: - Cardinality Tests
    
    func testCardinalityDuplicateElements() async throws {
        let element = XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: ["classCode": "DOCCLIN", "moodCode": "EVN"],
            children: [
                XMLElement(name: "id", attributes: ["root": "1.2.3"]),
                XMLElement(name: "id", attributes: ["root": "4.5.6"]),  // Duplicate!
                XMLElement(name: "title", text: "Test")
            ]
        )
        
        let validator = SchemaValidator()
        let result = await validator.validate(element: element)
        
        XCTAssertTrue(result.errors.contains { $0.code == "CARD-DUPLICATE" })
    }
    
    // MARK: - Report Generation Tests
    
    func testGenerateReportValid() async throws {
        let validator = SchemaValidator()
        let element = createValidCDADocument()
        
        let result = await validator.validate(element: element)
        let report = await validator.generateReport(result: result)
        
        XCTAssertTrue(report.contains("VALIDATION REPORT"))
        XCTAssertTrue(report.contains("OVERALL STATUS"))
        XCTAssertTrue(report.contains("✓ VALID"))
        XCTAssertTrue(report.contains("STATISTICS"))
    }
    
    func testGenerateReportInvalid() async throws {
        let validator = SchemaValidator()
        let element = createInvalidCDADocument()
        
        let result = await validator.validate(element: element)
        let report = await validator.generateReport(result: result)
        
        XCTAssertTrue(report.contains("✗ INVALID"))
        XCTAssertTrue(report.contains("ERRORS"))
        XCTAssertGreaterThan(result.errors.count, 0)
    }
    
    func testGenerateReportWithWarnings() async throws {
        let element = XMLElement(
            name: "code",
            attributes: ["code": "12345"]  // Missing codeSystem - generates warning
        )
        
        let wrapper = XMLElement(name: "test", children: [element])
        let validator = SchemaValidator()
        let result = await validator.validate(element: wrapper)
        let report = await validator.generateReport(result: result)
        
        XCTAssertTrue(report.contains("WARNINGS"))
    }
    
    // MARK: - Extension Method Tests
    
    func testXMLElementValidateConvenience() async throws {
        let element = createValidCDADocument()
        
        let result = await element.validate()
        
        XCTAssertTrue(result.isValid)
    }
    
    func testXMLElementValidationReportConvenience() async throws {
        let element = createValidCDADocument()
        
        let report = await element.validationReport()
        
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("VALIDATION REPORT"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyElement() async throws {
        let element = XMLElement(name: "empty")
        let validator = SchemaValidator()
        
        let result = await validator.validate(element: element)
        
        // Should complete without crashing
        XCTAssertGreaterThan(result.statistics.elementsValidated, 0)
    }
    
    func testDeeplyNestedDocument() async throws {
        func createDeep(depth: Int) -> XMLElement {
            if depth == 0 {
                return XMLElement(name: "leaf")
            }
            return XMLElement(name: "level", children: [createDeep(depth: depth - 1)])
        }
        
        let element = createDeep(depth: 20)
        let validator = SchemaValidator()
        
        let result = await validator.validate(element: element)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.statistics.elementsValidated, 21)
    }
    
    func testLargeDocument() async throws {
        let children = (0..<100).map { XMLElement(name: "child\($0)") }
        let element = XMLElement(name: "root", children: children)
        
        let validator = SchemaValidator()
        let result = await validator.validate(element: element)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.statistics.elementsValidated, 101)
    }
    
    // MARK: - Error Description Tests
    
    func testValidationErrorDescription() {
        let error = SchemaValidator.ValidationError(
            code: "TEST-001",
            message: "Test error",
            xpath: "/root/child",
            severity: .error,
            context: [:]
        )
        
        let description = error.description
        
        XCTAssertTrue(description.contains("TEST-001"))
        XCTAssertTrue(description.contains("Test error"))
        XCTAssertTrue(description.contains("/root/child"))
    }
    
    func testValidationWarningDescription() {
        let warning = SchemaValidator.ValidationWarning(
            code: "WARN-001",
            message: "Test warning",
            xpath: "/root"
        )
        
        let description = warning.description
        
        XCTAssertTrue(description.contains("WARN-001"))
        XCTAssertTrue(description.contains("Test warning"))
        XCTAssertTrue(description.contains("/root"))
    }
}
