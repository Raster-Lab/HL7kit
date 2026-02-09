/// TemplateEngineTests.swift
/// Unit tests for the Template Engine
///
/// Tests for template inheritance, composition, constraint validation,
/// and advanced template features.

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class TemplateEngineTests: XCTestCase {
    
    // MARK: - Template Inheritance Tests
    
    func testTemplateMerging() {
        // Create a parent template
        let parent = CDATemplate(
            templateId: "parent.1",
            name: "Parent Template",
            requiredElements: ["id", "code"],
            optionalElements: ["title"],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "12345"
                )
            ],
            valueSetBindings: ["code": "valueSet1"]
        )
        
        // Create a child template
        let child = CDATemplate(
            templateId: "child.1",
            name: "Child Template",
            requiredElements: ["effectiveTime"],
            optionalElements: ["confidentialityCode"],
            constraints: [
                TemplateConstraint(
                    elementPath: "effectiveTime",
                    cardinality: .required
                )
            ],
            valueSetBindings: ["status": "valueSet2"]
        )
        
        // Merge child with parent
        let merged = child.merged(with: parent)
        
        // Verify merged required elements
        XCTAssertTrue(merged.requiredElements.contains("id"))
        XCTAssertTrue(merged.requiredElements.contains("code"))
        XCTAssertTrue(merged.requiredElements.contains("effectiveTime"))
        
        // Verify merged optional elements
        XCTAssertTrue(merged.optionalElements.contains("title"))
        XCTAssertTrue(merged.optionalElements.contains("confidentialityCode"))
        
        // Verify merged constraints (parent first, then child)
        XCTAssertEqual(merged.constraints.count, 2)
        XCTAssertEqual(merged.constraints[0].elementPath, "code/@code")
        XCTAssertEqual(merged.constraints[1].elementPath, "effectiveTime")
        
        // Verify merged value set bindings (child overrides parent)
        XCTAssertEqual(merged.valueSetBindings["code"], "valueSet1")
        XCTAssertEqual(merged.valueSetBindings["status"], "valueSet2")
    }
    
    func testEnhancedTemplateCreation() {
        let template = CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.1",
            name: "US Realm Header"
        )
        
        let enhanced = EnhancedCDATemplate(
            template: template,
            parentTemplateIds: [],
            version: "2015-08-01",
            status: .active,
            publicationDate: Date(),
            author: "HL7 International"
        )
        
        XCTAssertEqual(enhanced.template.templateId, "2.16.840.1.113883.10.20.22.1.1")
        XCTAssertEqual(enhanced.version, "2015-08-01")
        XCTAssertEqual(enhanced.status, .active)
        XCTAssertEqual(enhanced.author, "HL7 International")
    }
    
    // MARK: - Template Composition Tests
    
    func testSimpleTemplateComposition() async throws {
        let registry = TemplateRegistry.shared
        let composer = TemplateComposer.shared
        
        // Register a simple template
        let template = CDATemplate(
            templateId: "test.template.1",
            name: "Test Template",
            requiredElements: ["id", "code"]
        )
        
        await registry.register(template)
        
        // Compose (should return as-is since no parents)
        let composed = try await composer.compose(templateId: "test.template.1", using: registry)
        
        XCTAssertEqual(composed.templateId, "test.template.1")
        XCTAssertEqual(composed.requiredElements.count, 2)
    }
    
    func testTemplateCompositionWithInheritance() async throws {
        let registry = TemplateRegistry.shared
        let composer = TemplateComposer.shared
        
        // Clear cache
        await composer.clearCache()
        
        // Create parent template
        let parent = CDATemplate(
            templateId: "parent.template",
            name: "Parent Template",
            requiredElements: ["id", "code"],
            optionalElements: ["title"]
        )
        
        await registry.register(parent)
        
        // Create child template
        let child = CDATemplate(
            templateId: "child.template",
            name: "Child Template",
            requiredElements: ["effectiveTime"],
            optionalElements: ["confidentialityCode"]
        )
        
        await registry.register(child)
        
        // Register enhanced child with parent reference
        let enhanced = EnhancedCDATemplate(
            template: child,
            parentTemplateIds: ["parent.template"]
        )
        
        await registry.registerEnhanced(enhanced)
        
        // Compose child (should include parent's elements)
        let composed = try await composer.compose(templateId: "child.template", using: registry)
        
        XCTAssertTrue(composed.requiredElements.contains("id"))
        XCTAssertTrue(composed.requiredElements.contains("code"))
        XCTAssertTrue(composed.requiredElements.contains("effectiveTime"))
        XCTAssertTrue(composed.optionalElements.contains("title"))
        XCTAssertTrue(composed.optionalElements.contains("confidentialityCode"))
    }
    
    func testTemplateCompositionCircularDependency() async throws {
        let registry = TemplateRegistry.shared
        let composer = TemplateComposer.shared
        
        // Clear cache
        await composer.clearCache()
        
        // Create template A
        let templateA = CDATemplate(
            templateId: "template.a",
            name: "Template A"
        )
        
        await registry.register(templateA)
        
        // Create template B that references A
        let templateB = CDATemplate(
            templateId: "template.b",
            name: "Template B"
        )
        
        await registry.register(templateB)
        
        let enhancedB = EnhancedCDATemplate(
            template: templateB,
            parentTemplateIds: ["template.a"]
        )
        
        await registry.registerEnhanced(enhancedB)
        
        // Create enhanced A that references B (circular)
        let enhancedA = EnhancedCDATemplate(
            template: templateA,
            parentTemplateIds: ["template.b"]
        )
        
        await registry.registerEnhanced(enhancedA)
        
        // Should detect circular dependency
        do {
            _ = try await composer.compose(templateId: "template.a", using: registry)
            XCTFail("Should have thrown circular dependency error")
        } catch TemplateError.circularDependency {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testTemplateNotFound() async {
        let composer = TemplateComposer.shared
        
        do {
            _ = try await composer.compose(templateId: "non.existent.template")
            XCTFail("Should have thrown templateNotFound error")
        } catch TemplateError.templateNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Constraint Validation Tests
    
    func testConstraintValidatorCardinality() throws {
        let validator = ConstraintValidator()
        
        // Create a test document
        let document = try CDADocumentBuilder()
            .withId(root: "2.16.840.1.113883.19.5", extension: "12345")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Test Document")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withRecordTarget { $0.withPatientId(root: "test", extension: "123")
                .withPatientName(given: "John", family: "Doe") }
            .withAuthor { $0.withTime(Date()).withAuthorId(root: "test", extension: "456")
                .withAuthorName(given: "Jane", family: "Smith") }
            .withCustodian { $0.withOrganizationId(root: "test")
                .withOrganizationName("Test Org") }
            .withStructuredBody { body in
                body.addSection { $0.withTitle("Test").withText("Test content") }
            }
            .build()
        
        // Test constraint requiring at least 1 author
        let constraint = TemplateConstraint(
            elementPath: "author",
            cardinality: Cardinality(min: 1, max: 3)
        )
        
        let result = validator.validate(constraints: [constraint], against: document)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 0)
    }
    
    func testConstraintValidatorCardinalityViolation() throws {
        let validator = ConstraintValidator()
        
        // Create a minimal document
        let document = try CDADocumentBuilder()
            .withId(root: "2.16.840.1.113883.19.5", extension: "12345")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Test Document")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withRecordTarget { $0.withPatientId(root: "test", extension: "123")
                .withPatientName(given: "John", family: "Doe") }
            .withAuthor { $0.withTime(Date()).withAuthorId(root: "test", extension: "456")
                .withAuthorName(given: "Jane", family: "Smith") }
            .withCustodian { $0.withOrganizationId(root: "test")
                .withOrganizationName("Test Org") }
            .withStructuredBody { body in
                body.addSection { $0.withTitle("Test").withText("Test content") }
            }
            .build()
        
        // Test constraint requiring at least 2 authors (should fail)
        let constraint = TemplateConstraint(
            elementPath: "author",
            cardinality: Cardinality(min: 2, max: nil)
        )
        
        let result = validator.validate(constraints: [constraint], against: document)
        
        XCTAssertFalse(result.isValid)
        XCTAssertGreaterThan(result.issues.count, 0)
        XCTAssertTrue(result.issues.contains { $0.severity == .error })
    }
    
    func testConstraintValidatorValueConstraint() throws {
        let validator = ConstraintValidator()
        
        // Create a document with realm code
        let document = try CDADocumentBuilder()
            .withRealmCode("US")
            .withId(root: "2.16.840.1.113883.19.5", extension: "12345")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Test Document")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withRecordTarget { $0.withPatientId(root: "test", extension: "123")
                .withPatientName(given: "John", family: "Doe") }
            .withAuthor { $0.withTime(Date()).withAuthorId(root: "test", extension: "456")
                .withAuthorName(given: "Jane", family: "Smith") }
            .withCustodian { $0.withOrganizationId(root: "test")
                .withOrganizationName("Test Org") }
            .withStructuredBody { body in
                body.addSection { $0.withTitle("Test").withText("Test content") }
            }
            .build()
        
        // Test constraint requiring realm code = "US"
        let constraint = TemplateConstraint(
            elementPath: "realmCode/@code",
            cardinality: .required,
            valueConstraint: "US"
        )
        
        let result = validator.validate(constraints: [constraint], against: document)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testConstraintValidatorValueConstraintViolation() throws {
        let validator = ConstraintValidator()
        
        // Create a document with different realm code
        let document = try CDADocumentBuilder()
            .withRealmCode("CA")
            .withId(root: "2.16.840.1.113883.19.5", extension: "12345")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Test Document")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withRecordTarget { $0.withPatientId(root: "test", extension: "123")
                .withPatientName(given: "John", family: "Doe") }
            .withAuthor { $0.withTime(Date()).withAuthorId(root: "test", extension: "456")
                .withAuthorName(given: "Jane", family: "Smith") }
            .withCustodian { $0.withOrganizationId(root: "test")
                .withOrganizationName("Test Org") }
            .withStructuredBody { body in
                body.addSection { $0.withTitle("Test").withText("Test content") }
            }
            .build()
        
        // Test constraint requiring realm code = "US" (should fail)
        let constraint = TemplateConstraint(
            elementPath: "realmCode/@code",
            cardinality: .required,
            valueConstraint: "US"
        )
        
        let result = validator.validate(constraints: [constraint], against: document)
        
        XCTAssertFalse(result.isValid)
        XCTAssertGreaterThan(result.issues.count, 0)
    }
    
    // MARK: - Template Comparison Tests
    
    func testTemplateDifferences() {
        let template1 = CDATemplate(
            templateId: "template.1",
            name: "Template 1",
            requiredElements: ["id", "code"],
            optionalElements: ["title"]
        )
        
        let template2 = CDATemplate(
            templateId: "template.2",
            name: "Template 2",
            requiredElements: ["id", "effectiveTime"],
            optionalElements: ["title", "confidentialityCode"]
        )
        
        let diffs = template2.differences(from: template1)
        
        // Should have:
        // - effectiveTime added to required
        // - code removed from required
        // - confidentialityCode added to optional
        XCTAssertGreaterThan(diffs.count, 0)
        
        // Check for specific differences
        XCTAssertTrue(diffs.contains(.requiredElementAdded("effectiveTime")))
        XCTAssertTrue(diffs.contains(.requiredElementRemoved("code")))
        XCTAssertTrue(diffs.contains(.optionalElementAdded("confidentialityCode")))
    }
    
    func testNoDifferences() {
        let template1 = CDATemplate(
            templateId: "template.1",
            name: "Template 1",
            requiredElements: ["id", "code"],
            optionalElements: ["title"]
        )
        
        let template2 = CDATemplate(
            templateId: "template.2",
            name: "Template 2",
            requiredElements: ["id", "code"],
            optionalElements: ["title"]
        )
        
        let diffs = template2.differences(from: template1)
        
        // Should have no differences
        XCTAssertEqual(diffs.count, 0)
    }
    
    // MARK: - Template Error Tests
    
    func testTemplateErrorDescriptions() {
        let error1 = TemplateError.templateNotFound("test.template")
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription?.contains("not found") ?? false)
        
        let error2 = TemplateError.circularDependency("child", "parent")
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertTrue(error2.errorDescription?.contains("Circular") ?? false)
        
        let error3 = TemplateError.invalidConstraint("test constraint")
        XCTAssertNotNil(error3.errorDescription)
        XCTAssertTrue(error3.errorDescription?.contains("Invalid") ?? false)
        
        let issues = [ValidationIssue(severity: .error, path: "test", message: "test")]
        let error4 = TemplateError.validationFailed(issues)
        XCTAssertNotNil(error4.errorDescription)
        XCTAssertTrue(error4.errorDescription?.contains("Validation failed") ?? false)
    }
}
