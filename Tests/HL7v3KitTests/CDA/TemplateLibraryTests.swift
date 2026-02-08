/// TemplateLibraryTests.swift
/// Unit tests for the Extended Template Library
///
/// Tests for template library registration, discovery, and metadata.

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class TemplateLibraryTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        // Register all extended templates
        await ExtendedTemplateLibrary.shared.registerAllTemplates()
    }
    
    // MARK: - Template Registration Tests
    
    func testCCDATemplatesRegistered() async {
        let registry = TemplateRegistry.shared
        
        // Check Procedure Note
        let procedureNote = await registry.template(for: "2.16.840.1.113883.10.20.22.1.6")
        XCTAssertNotNil(procedureNote)
        XCTAssertEqual(procedureNote?.name, "Procedure Note")
        
        // Check Referral Note
        let referralNote = await registry.template(for: "2.16.840.1.113883.10.20.22.1.14")
        XCTAssertNotNil(referralNote)
        XCTAssertEqual(referralNote?.name, "Referral Note")
        
        // Check Transfer Summary
        let transferSummary = await registry.template(for: "2.16.840.1.113883.10.20.22.1.13")
        XCTAssertNotNil(transferSummary)
        XCTAssertEqual(transferSummary?.name, "Transfer Summary")
        
        // Check Care Plan
        let carePlan = await registry.template(for: "2.16.840.1.113883.10.20.22.1.15")
        XCTAssertNotNil(carePlan)
        XCTAssertEqual(carePlan?.name, "Care Plan")
    }
    
    func testIHETemplatesRegistered() async {
        let registry = TemplateRegistry.shared
        
        // Check IHE Medical Summary
        let medicalSummary = await registry.template(for: "1.3.6.1.4.1.19376.1.5.3.1.1.2")
        XCTAssertNotNil(medicalSummary)
        XCTAssertEqual(medicalSummary?.name, "IHE Medical Summary")
        
        // Check IHE BPPC
        let bppc = await registry.template(for: "1.3.6.1.4.1.19376.1.5.3.1.1.7")
        XCTAssertNotNil(bppc)
        XCTAssertEqual(bppc?.name, "IHE Basic Patient Privacy Consent")
        
        // Check IHE Immunization Content
        let immunization = await registry.template(for: "1.3.6.1.4.1.19376.1.5.3.1.1.18.1.2")
        XCTAssertNotNil(immunization)
        XCTAssertEqual(immunization?.name, "IHE Immunization Content")
        
        // Check IHE APSR
        let apsr = await registry.template(for: "1.3.6.1.4.1.19376.1.8.1.1.1")
        XCTAssertNotNil(apsr)
        XCTAssertEqual(apsr?.name, "IHE Anatomic Pathology Structured Report")
    }
    
    func testSectionTemplatesRegistered() async {
        let registry = TemplateRegistry.shared
        
        // Check Allergies Section
        let allergies = await registry.template(for: "2.16.840.1.113883.10.20.22.2.6.1")
        XCTAssertNotNil(allergies)
        XCTAssertEqual(allergies?.name, "Allergies and Intolerances Section (entries required)")
        
        // Check Medications Section
        let medications = await registry.template(for: "2.16.840.1.113883.10.20.22.2.1.1")
        XCTAssertNotNil(medications)
        XCTAssertEqual(medications?.name, "Medications Section (entries required)")
        
        // Check Problem Section
        let problems = await registry.template(for: "2.16.840.1.113883.10.20.22.2.5.1")
        XCTAssertNotNil(problems)
        XCTAssertEqual(problems?.name, "Problem Section (entries required)")
        
        // Check Vital Signs Section
        let vitalSigns = await registry.template(for: "2.16.840.1.113883.10.20.22.2.4.1")
        XCTAssertNotNil(vitalSigns)
        XCTAssertEqual(vitalSigns?.name, "Vital Signs Section (entries required)")
        
        // Check Procedures Section
        let procedures = await registry.template(for: "2.16.840.1.113883.10.20.22.2.7.1")
        XCTAssertNotNil(procedures)
        XCTAssertEqual(procedures?.name, "Procedures Section (entries required)")
    }
    
    func testEntryTemplatesRegistered() async {
        let registry = TemplateRegistry.shared
        
        // Check Allergy Concern Act
        let allergyConcern = await registry.template(for: "2.16.840.1.113883.10.20.22.4.30")
        XCTAssertNotNil(allergyConcern)
        XCTAssertEqual(allergyConcern?.name, "Allergy Concern Act")
        
        // Check Problem Concern Act
        let problemConcern = await registry.template(for: "2.16.840.1.113883.10.20.22.4.3")
        XCTAssertNotNil(problemConcern)
        XCTAssertEqual(problemConcern?.name, "Problem Concern Act")
        
        // Check Medication Activity
        let medicationActivity = await registry.template(for: "2.16.840.1.113883.10.20.22.4.16")
        XCTAssertNotNil(medicationActivity)
        XCTAssertEqual(medicationActivity?.name, "Medication Activity")
        
        // Check Vital Sign Observation
        let vitalSign = await registry.template(for: "2.16.840.1.113883.10.20.22.4.27")
        XCTAssertNotNil(vitalSign)
        XCTAssertEqual(vitalSign?.name, "Vital Sign Observation")
    }
    
    // MARK: - Template Discovery Tests
    
    func testFindByDocumentType() async {
        let discovery = TemplateDiscoveryService()
        
        // Find procedure note templates
        let procedureNotes = await discovery.findByDocumentType(.procedureNote)
        XCTAssertGreaterThan(procedureNotes.count, 0)
        XCTAssertTrue(procedureNotes.contains { $0.template.name == "Procedure Note" })
        
        // Find referral note templates
        let referralNotes = await discovery.findByDocumentType(.referralNote)
        XCTAssertGreaterThan(referralNotes.count, 0)
        XCTAssertTrue(referralNotes.contains { $0.template.name == "Referral Note" })
    }
    
    func testFindByStatus() async {
        let discovery = TemplateDiscoveryService()
        
        // Find active templates
        let activeTemplates = await discovery.findByStatus(.active)
        XCTAssertGreaterThan(activeTemplates.count, 0)
        
        // All returned templates should be active
        for template in activeTemplates {
            XCTAssertEqual(template.status, .active)
        }
    }
    
    func testFindByAuthor() async {
        let discovery = TemplateDiscoveryService()
        
        // Find HL7 templates
        let hl7Templates = await discovery.findByAuthor("HL7")
        XCTAssertGreaterThan(hl7Templates.count, 0)
        XCTAssertTrue(hl7Templates.allSatisfy { $0.author?.contains("HL7") ?? false })
        
        // Find IHE templates
        let iheTemplates = await discovery.findByAuthor("IHE")
        XCTAssertGreaterThan(iheTemplates.count, 0)
        XCTAssertTrue(iheTemplates.allSatisfy { $0.author == "IHE" })
    }
    
    func testSearchTemplates() async {
        let discovery = TemplateDiscoveryService()
        
        // Search for "allergy" templates
        let allergyResults = await discovery.search(query: "allergy")
        XCTAssertGreaterThan(allergyResults.count, 0)
        
        // Search for "medication" templates
        let medicationResults = await discovery.search(query: "medication")
        XCTAssertGreaterThan(medicationResults.count, 0)
        
        // Search for "vital" templates
        let vitalResults = await discovery.search(query: "vital")
        XCTAssertGreaterThan(vitalResults.count, 0)
    }
    
    func testGetHierarchy() async {
        let discovery = TemplateDiscoveryService()
        
        // Get hierarchy for Procedure Note (which has US Realm Header as parent)
        if let hierarchy = await discovery.getHierarchy(for: "2.16.840.1.113883.10.20.22.1.6") {
            XCTAssertEqual(hierarchy.template.template.name, "Procedure Note")
            XCTAssertGreaterThan(hierarchy.parents.count, 0)
            
            // Should have US Realm Header as parent
            XCTAssertTrue(hierarchy.parents.contains { $0.template.templateId == "2.16.840.1.113883.10.20.22.1.1" })
        } else {
            XCTFail("Should find hierarchy for Procedure Note")
        }
    }
    
    func testGetHierarchyNonExistent() async {
        let discovery = TemplateDiscoveryService()
        
        // Try to get hierarchy for non-existent template
        let hierarchy = await discovery.getHierarchy(for: "non.existent.template")
        XCTAssertNil(hierarchy)
    }
    
    // MARK: - Template Metadata Tests
    
    func testTemplateMetadata() async {
        let registry = TemplateRegistry.shared
        
        guard let enhanced = await registry.enhancedTemplate(for: "2.16.840.1.113883.10.20.22.1.6") else {
            XCTFail("Should find Procedure Note template")
            return
        }
        
        let metadata = enhanced.metadata
        
        XCTAssertEqual(metadata.templateId, "2.16.840.1.113883.10.20.22.1.6")
        XCTAssertEqual(metadata.name, "Procedure Note")
        XCTAssertNotNil(metadata.description)
        XCTAssertEqual(metadata.version, "2015-08-01")
        XCTAssertEqual(metadata.status, .active)
        XCTAssertEqual(metadata.author, "HL7 International")
        XCTAssertGreaterThan(metadata.parentTemplateIds.count, 0)
        XCTAssertGreaterThan(metadata.requiredElementsCount, 0)
        XCTAssertGreaterThan(metadata.constraintsCount, 0)
    }
    
    func testTemplateMetadataEquality() {
        let template1 = CDATemplate(
            templateId: "test.1",
            name: "Test Template",
            requiredElements: ["id"],
            optionalElements: ["title"],
            constraints: [
                TemplateConstraint(elementPath: "id", cardinality: .required)
            ]
        )
        
        let enhanced1 = EnhancedCDATemplate(
            template: template1,
            version: "1.0",
            status: .active,
            author: "Test"
        )
        
        let enhanced2 = EnhancedCDATemplate(
            template: template1,
            version: "1.0",
            status: .active,
            author: "Test"
        )
        
        let metadata1 = enhanced1.metadata
        let metadata2 = enhanced2.metadata
        
        XCTAssertEqual(metadata1, metadata2)
    }
    
    // MARK: - Template Inheritance with Library Tests
    
    func testLibraryTemplateInheritance() async throws {
        let composer = TemplateComposer.shared
        
        // Clear cache
        await composer.clearCache()
        
        // Compose Procedure Note (should inherit from US Realm Header)
        let composed = try await composer.compose(templateId: "2.16.840.1.113883.10.20.22.1.6")
        
        // Should have required elements from both templates
        XCTAssertTrue(composed.requiredElements.contains("code"))
        XCTAssertTrue(composed.requiredElements.contains("componentOf"))
        
        // Should also have inherited elements from US Realm Header
        XCTAssertTrue(composed.requiredElements.contains("realmCode"))
        XCTAssertTrue(composed.requiredElements.contains("recordTarget"))
        XCTAssertTrue(composed.requiredElements.contains("author"))
        XCTAssertTrue(composed.requiredElements.contains("custodian"))
    }
    
    // MARK: - Section Template Constraints Tests
    
    func testSectionTemplateConstraints() async {
        let registry = TemplateRegistry.shared
        
        // Check Allergies Section constraints
        guard let allergiesSection = await registry.template(for: "2.16.840.1.113883.10.20.22.2.6.1") else {
            XCTFail("Should find Allergies Section template")
            return
        }
        
        // Should have code constraint
        let codeConstraint = allergiesSection.constraints.first { $0.elementPath == "code/@code" }
        XCTAssertNotNil(codeConstraint)
        XCTAssertEqual(codeConstraint?.valueConstraint, "48765-2")
        
        // Should have entry constraint (at least 1)
        let entryConstraint = allergiesSection.constraints.first { $0.elementPath == "entry" }
        XCTAssertNotNil(entryConstraint)
        XCTAssertEqual(entryConstraint?.cardinality.min, 1)
    }
    
    func testEntryTemplateConstraints() async {
        let registry = TemplateRegistry.shared
        
        // Check Medication Activity constraints
        guard let medicationActivity = await registry.template(for: "2.16.840.1.113883.10.20.22.4.16") else {
            XCTFail("Should find Medication Activity template")
            return
        }
        
        // Should have classCode constraint
        let classCodeConstraint = medicationActivity.constraints.first { $0.elementPath == "@classCode" }
        XCTAssertNotNil(classCodeConstraint)
        XCTAssertEqual(classCodeConstraint?.valueConstraint, "SBADM")
        
        // Should have consumable constraint
        let consumableConstraint = medicationActivity.constraints.first { $0.elementPath == "consumable" }
        XCTAssertNotNil(consumableConstraint)
        XCTAssertEqual(consumableConstraint?.cardinality.min, 1)
    }
}
