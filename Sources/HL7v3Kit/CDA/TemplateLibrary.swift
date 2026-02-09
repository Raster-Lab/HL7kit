/// TemplateLibrary.swift
/// Extended Template Library for CDA Documents
///
/// This file provides additional C-CDA and IHE profile templates beyond the basic
/// templates in CDATemplates.swift.

import Foundation
import HL7Core

// MARK: - Template Library Extension

/// Extended template library with additional C-CDA and IHE templates
public actor ExtendedTemplateLibrary {
    /// Shared instance
    public static let shared = ExtendedTemplateLibrary()
    
    private init() {}
    
    /// Registers all extended templates
    public func registerAllTemplates() async {
        await registerCCDATemplates()
        await registerIHETemplates()
        await registerSectionTemplates()
        await registerEntryTemplates()
    }
    
    // MARK: - C-CDA Document Templates
    
    private func registerCCDATemplates() async {
        let registry = TemplateRegistry.shared
        
        // Procedure Note
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.1.6",
                name: "Procedure Note",
                description: "The Procedure Note is created immediately following a non-surgical procedure.",
                documentType: .procedureNote,
                requiredElements: ["code", "componentOf"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "28570-0",
                        description: "Document type code must be 28570-0 (Procedure note)"
                    )
                ]
            ),
            parentTemplateIds: ["2.16.840.1.113883.10.20.22.1.1"],
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Referral Note
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.1.14",
                name: "Referral Note",
                description: "The Referral Note conveys pertinent information from a provider requesting services of another provider.",
                documentType: .referralNote,
                requiredElements: ["code"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "57133-1",
                        description: "Document type code must be 57133-1 (Referral note)"
                    )
                ]
            ),
            parentTemplateIds: ["2.16.840.1.113883.10.20.22.1.1"],
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Transfer Summary
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.1.13",
                name: "Transfer Summary",
                description: "The Transfer Summary document is used to exchange information with another treating provider when the patient moves between healthcare settings.",
                documentType: .transferSummary,
                requiredElements: ["code"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "18761-7",
                        description: "Document type code must be 18761-7 (Transfer summary note)"
                    )
                ]
            ),
            parentTemplateIds: ["2.16.840.1.113883.10.20.22.1.1"],
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Care Plan
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.1.15",
                name: "Care Plan",
                description: "A Care Plan is a consensus-driven dynamic plan that represents all of a patient's and Care Team Members' prioritized concerns, goals, and planned interventions.",
                requiredElements: ["code"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "52521-2",
                        description: "Document type code must be 52521-2 (Care Plan)"
                    )
                ]
            ),
            parentTemplateIds: ["2.16.840.1.113883.10.20.22.1.1"],
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
    }
    
    // MARK: - IHE Profile Templates
    
    private func registerIHETemplates() async {
        let registry = TemplateRegistry.shared
        
        // IHE XDS-MS Medical Summary
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "1.3.6.1.4.1.19376.1.5.3.1.1.2",
                name: "IHE Medical Summary",
                description: "IHE Patient Care Coordination - Medical Summary document (XDS-MS)",
                requiredElements: ["code", "recordTarget", "author", "custodian"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "11503-0",
                        description: "LOINC code for Medical Summary"
                    )
                ]
            ),
            version: "1.3",
            status: .active,
            author: "IHE"
        ))
        
        // IHE BPPC Basic Patient Privacy Consent
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "1.3.6.1.4.1.19376.1.5.3.1.1.7",
                name: "IHE Basic Patient Privacy Consent",
                description: "IHE IT Infrastructure - Basic Patient Privacy Consent (BPPC)",
                requiredElements: ["code", "recordTarget"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "57016-8",
                        description: "LOINC code for Privacy policy acknowledgment"
                    )
                ]
            ),
            version: "2.0",
            status: .active,
            author: "IHE"
        ))
        
        // IHE PCC Immunization Content
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "1.3.6.1.4.1.19376.1.5.3.1.1.18.1.2",
                name: "IHE Immunization Content",
                description: "IHE Patient Care Coordination - Immunization Content",
                requiredElements: ["code"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "87273-9",
                        description: "LOINC code for Immunization note"
                    )
                ]
            ),
            version: "1.0",
            status: .active,
            author: "IHE"
        ))
        
        // IHE APSR Anatomic Pathology Structured Report
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "1.3.6.1.4.1.19376.1.8.1.1.1",
                name: "IHE Anatomic Pathology Structured Report",
                description: "IHE Anatomic Pathology - Structured Report",
                requiredElements: ["code", "recordTarget", "author"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "11526-1",
                        description: "LOINC code for Pathology study"
                    )
                ]
            ),
            version: "1.0",
            status: .active,
            author: "IHE"
        ))
    }
    
    // MARK: - Section Templates
    
    private func registerSectionTemplates() async {
        let registry = TemplateRegistry.shared
        
        // Allergies and Intolerances Section
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.2.6.1",
                name: "Allergies and Intolerances Section (entries required)",
                description: "This section lists and describes any medication allergies, adverse reactions, or intolerances.",
                requiredElements: ["code", "title", "text"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "48765-2",
                        description: "LOINC code for Allergies"
                    ),
                    TemplateConstraint(
                        elementPath: "entry",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one entry is required"
                    )
                ]
            ),
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Medications Section
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.2.1.1",
                name: "Medications Section (entries required)",
                description: "The Medications section contains information about the patient's current and pertinent historical medications.",
                requiredElements: ["code", "title", "text"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "10160-0",
                        description: "LOINC code for Medications"
                    ),
                    TemplateConstraint(
                        elementPath: "entry",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one entry is required"
                    )
                ]
            ),
            version: "2014-06-09",
            status: .active,
            author: "HL7 International"
        ))
        
        // Problem Section
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.2.5.1",
                name: "Problem Section (entries required)",
                description: "This section lists and describes all relevant clinical problems.",
                requiredElements: ["code", "title", "text"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "11450-4",
                        description: "LOINC code for Problem list"
                    ),
                    TemplateConstraint(
                        elementPath: "entry",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one entry is required"
                    )
                ]
            ),
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Vital Signs Section
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.2.4.1",
                name: "Vital Signs Section (entries required)",
                description: "The Vital Signs section contains relevant vital signs for the context and use case of the document.",
                requiredElements: ["code", "title", "text"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "8716-3",
                        description: "LOINC code for Vital signs"
                    ),
                    TemplateConstraint(
                        elementPath: "entry",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one entry is required"
                    )
                ]
            ),
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Procedures Section
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.2.7.1",
                name: "Procedures Section (entries required)",
                description: "This section describes all interventional, surgical, diagnostic, or therapeutic procedures or treatments pertinent to the patient.",
                requiredElements: ["code", "title", "text"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "code/@code",
                        cardinality: .required,
                        valueConstraint: "47519-4",
                        description: "LOINC code for Procedures"
                    ),
                    TemplateConstraint(
                        elementPath: "entry",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one entry is required"
                    )
                ]
            ),
            version: "2014-06-09",
            status: .active,
            author: "HL7 International"
        ))
    }
    
    // MARK: - Entry Templates
    
    private func registerEntryTemplates() async {
        let registry = TemplateRegistry.shared
        
        // Allergy Concern Act
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.4.30",
                name: "Allergy Concern Act",
                description: "This template groups the allergy or intolerance observations with the same concern.",
                requiredElements: ["classCode", "moodCode", "statusCode"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "@classCode",
                        cardinality: .required,
                        valueConstraint: "ACT"
                    ),
                    TemplateConstraint(
                        elementPath: "@moodCode",
                        cardinality: .required,
                        valueConstraint: "EVN"
                    ),
                    TemplateConstraint(
                        elementPath: "entryRelationship",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one Allergy Intolerance Observation"
                    )
                ]
            ),
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Problem Concern Act
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.4.3",
                name: "Problem Concern Act",
                description: "This template groups one or more problem observations.",
                requiredElements: ["classCode", "moodCode", "statusCode"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "@classCode",
                        cardinality: .required,
                        valueConstraint: "ACT"
                    ),
                    TemplateConstraint(
                        elementPath: "@moodCode",
                        cardinality: .required,
                        valueConstraint: "EVN"
                    ),
                    TemplateConstraint(
                        elementPath: "entryRelationship",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one Problem Observation"
                    )
                ]
            ),
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
        
        // Medication Activity
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.4.16",
                name: "Medication Activity",
                description: "A medication activity describes the medication that a patient is currently taking or has taken.",
                requiredElements: ["classCode", "moodCode", "statusCode"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "@classCode",
                        cardinality: .required,
                        valueConstraint: "SBADM"
                    ),
                    TemplateConstraint(
                        elementPath: "@moodCode",
                        cardinality: .required,
                        valueConstraint: "EVN"
                    ),
                    TemplateConstraint(
                        elementPath: "effectiveTime",
                        cardinality: Cardinality(min: 1, max: nil),
                        description: "At least one effectiveTime is required"
                    ),
                    TemplateConstraint(
                        elementPath: "consumable",
                        cardinality: .required
                    )
                ]
            ),
            version: "2014-06-09",
            status: .active,
            author: "HL7 International"
        ))
        
        // Vital Sign Observation
        await registry.registerEnhanced(EnhancedCDATemplate(
            template: CDATemplate(
                templateId: "2.16.840.1.113883.10.20.22.4.27",
                name: "Vital Sign Observation",
                description: "A vital sign observation measures the patient's vital signs.",
                requiredElements: ["classCode", "moodCode", "code", "value"],
                constraints: [
                    TemplateConstraint(
                        elementPath: "@classCode",
                        cardinality: .required,
                        valueConstraint: "OBS"
                    ),
                    TemplateConstraint(
                        elementPath: "@moodCode",
                        cardinality: .required,
                        valueConstraint: "EVN"
                    ),
                    TemplateConstraint(
                        elementPath: "code/@codeSystem",
                        cardinality: .required,
                        valueConstraint: "2.16.840.1.113883.6.1",
                        description: "Code must be from LOINC"
                    )
                ]
            ),
            version: "2015-08-01",
            status: .active,
            author: "HL7 International"
        ))
    }
}

// MARK: - Template Discovery

/// Template discovery service
public struct TemplateDiscoveryService {
    /// Finds templates by document type
    public func findByDocumentType(_ type: TemplateDocumentType) async -> [EnhancedCDATemplate] {
        let templates = await TemplateRegistry.shared.allEnhancedTemplates()
        return templates.filter { $0.template.documentType == type }
    }
    
    /// Finds templates by status
    public func findByStatus(_ status: TemplateStatus) async -> [EnhancedCDATemplate] {
        let templates = await TemplateRegistry.shared.allEnhancedTemplates()
        return templates.filter { $0.status == status }
    }
    
    /// Finds templates by author/organization
    public func findByAuthor(_ author: String) async -> [EnhancedCDATemplate] {
        let templates = await TemplateRegistry.shared.allEnhancedTemplates()
        return templates.filter { $0.author?.lowercased().contains(author.lowercased()) ?? false }
    }
    
    /// Searches templates by name or description
    public func search(query: String) async -> [EnhancedCDATemplate] {
        let templates = await TemplateRegistry.shared.allEnhancedTemplates()
        let lowercaseQuery = query.lowercased()
        return templates.filter { template in
            template.template.name.lowercased().contains(lowercaseQuery) ||
            (template.template.description?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    /// Gets template hierarchy (parent-child relationships)
    public func getHierarchy(for templateId: String) async -> TemplateHierarchy? {
        guard let enhanced = await TemplateRegistry.shared.enhancedTemplate(for: templateId) else {
            return nil
        }
        
        // Get parents
        var parents: [EnhancedCDATemplate] = []
        for parentId in enhanced.parentTemplateIds {
            if let parent = await TemplateRegistry.shared.enhancedTemplate(for: parentId) {
                parents.append(parent)
            }
        }
        
        // Get children
        let allTemplates = await TemplateRegistry.shared.allEnhancedTemplates()
        let children = allTemplates.filter { $0.parentTemplateIds.contains(templateId) }
        
        return TemplateHierarchy(
            template: enhanced,
            parents: parents,
            children: children
        )
    }
}

/// Template hierarchy information
public struct TemplateHierarchy: Sendable {
    public let template: EnhancedCDATemplate
    public let parents: [EnhancedCDATemplate]
    public let children: [EnhancedCDATemplate]
    
    public init(
        template: EnhancedCDATemplate,
        parents: [EnhancedCDATemplate],
        children: [EnhancedCDATemplate]
    ) {
        self.template = template
        self.parents = parents
        self.children = children
    }
}

// MARK: - Template Metadata

/// Template metadata for documentation and discovery
public struct TemplateMetadata: Sendable, Equatable {
    /// Template identifier
    public let templateId: String
    
    /// Template name
    public let name: String
    
    /// Template description
    public let description: String?
    
    /// Template version
    public let version: String?
    
    /// Template status
    public let status: TemplateStatus
    
    /// Publication date
    public let publicationDate: Date?
    
    /// Author/organization
    public let author: String?
    
    /// Parent templates
    public let parentTemplateIds: [String]
    
    /// Required elements count
    public let requiredElementsCount: Int
    
    /// Optional elements count
    public let optionalElementsCount: Int
    
    /// Constraints count
    public let constraintsCount: Int
    
    public init(from enhanced: EnhancedCDATemplate) {
        self.templateId = enhanced.template.templateId
        self.name = enhanced.template.name
        self.description = enhanced.template.description
        self.version = enhanced.version
        self.status = enhanced.status
        self.publicationDate = enhanced.publicationDate
        self.author = enhanced.author
        self.parentTemplateIds = enhanced.parentTemplateIds
        self.requiredElementsCount = enhanced.template.requiredElements.count
        self.optionalElementsCount = enhanced.template.optionalElements.count
        self.constraintsCount = enhanced.template.constraints.count
    }
}

extension EnhancedCDATemplate {
    /// Gets metadata for this template
    public var metadata: TemplateMetadata {
        TemplateMetadata(from: self)
    }
}
