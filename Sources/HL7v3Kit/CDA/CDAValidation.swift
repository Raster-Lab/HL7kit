/// CDAValidation.swift
/// CDA R2 Validation Rules
///
/// This file implements CDA-specific validation rules beyond template validation.

import Foundation
import HL7Core

// MARK: - CDAValidator

/// CDAValidator - Validates CDA documents
public struct CDAValidator {
    /// Validates a CDA document
    public func validate(_ document: ClinicalDocument) async -> CDAValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Validate header
        validateHeader(document, errors: &errors, warnings: &warnings)
        
        // Validate body
        validateBody(document, errors: &errors, warnings: &warnings)
        
        // Validate templates
        let templateResult = await TemplateValidator().validate(document)
        for issue in templateResult.issues {
            switch issue.severity {
            case .error:
                errors.append("\(issue.path): \(issue.message)")
            case .warning:
                warnings.append("\(issue.path): \(issue.message)")
            case .info:
                break
            }
        }
        
        return CDAValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Header Validation
    
    private func validateHeader(_ document: ClinicalDocument, errors: inout [String], warnings: inout [String]) {
        // Validate type ID
        if document.typeId.root != "2.16.840.1.113883.1.3" {
            errors.append("typeId: Invalid CDA R2 type ID root, expected '2.16.840.1.113883.1.3'")
        }
        
        // Validate template IDs
        if document.templateId.isEmpty {
            warnings.append("templateId: No template IDs specified")
        }
        
        // Validate code
        if document.code.codeSystem != "2.16.840.1.113883.6.1" {
            warnings.append("code: Expected LOINC code system '2.16.840.1.113883.6.1'")
        }
        
        // Validate record target
        if document.recordTarget.isEmpty {
            errors.append("recordTarget: At least one record target (patient) is required")
        }
        
        for (index, recordTarget) in document.recordTarget.enumerated() {
            validateRecordTarget(recordTarget, index: index, errors: &errors, warnings: &warnings)
        }
        
        // Validate authors
        if document.author.isEmpty {
            errors.append("author: At least one author is required")
        }
        
        for (index, author) in document.author.enumerated() {
            validateAuthor(author, index: index, errors: &errors, warnings: &warnings)
        }
        
        // Validate custodian
        validateCustodian(document.custodian, errors: &errors, warnings: &warnings)
        
        // Validate authenticators
        if let legalAuthenticator = document.legalAuthenticator {
            validateLegalAuthenticator(legalAuthenticator, errors: &errors, warnings: &warnings)
        }
    }
    
    private func validateRecordTarget(_ recordTarget: RecordTarget, index: Int, errors: inout [String], warnings: inout [String]) {
        let prefix = "recordTarget[\(index)]"
        
        // Validate patient role
        if recordTarget.patientRole.id.isEmpty {
            errors.append("\(prefix)/patientRole/id: At least one patient identifier is required")
        }
        
        // Validate patient if present
        if let patient = recordTarget.patientRole.patient {
            if patient.name?.isEmpty ?? true {
                warnings.append("\(prefix)/patientRole/patient/name: Patient name is recommended")
            }
            
            if patient.administrativeGenderCode == nil {
                warnings.append("\(prefix)/patientRole/patient/administrativeGenderCode: Gender code is recommended")
            }
            
            if patient.birthTime == nil {
                warnings.append("\(prefix)/patientRole/patient/birthTime: Birth date is recommended")
            }
        }
    }
    
    private func validateAuthor(_ author: Author, index: Int, errors: inout [String], warnings: inout [String]) {
        let prefix = "author[\(index)]"
        
        // Validate assigned author
        if author.assignedAuthor.id.isEmpty {
            errors.append("\(prefix)/assignedAuthor/id: At least one author identifier is required")
        }
        
        // Author must be either a person or a device
        if author.assignedAuthor.assignedPerson == nil && author.assignedAuthor.assignedAuthoringDevice == nil {
            errors.append("\(prefix)/assignedAuthor: Must have either assignedPerson or assignedAuthoringDevice")
        }
    }
    
    private func validateCustodian(_ custodian: Custodian, errors: inout [String], warnings: inout [String]) {
        let prefix = "custodian"
        
        // Validate custodian organization
        if custodian.assignedCustodian.representedCustodianOrganization.id.isEmpty {
            errors.append("\(prefix)/assignedCustodian/representedCustodianOrganization/id: At least one organization identifier is required")
        }
        
        if custodian.assignedCustodian.representedCustodianOrganization.name == nil {
            warnings.append("\(prefix)/assignedCustodian/representedCustodianOrganization/name: Organization name is recommended")
        }
    }
    
    private func validateLegalAuthenticator(_ authenticator: LegalAuthenticator, errors: inout [String], warnings: inout [String]) {
        let prefix = "legalAuthenticator"
        
        // Validate signature code
        if authenticator.signatureCode.code == nil {
            errors.append("\(prefix)/signatureCode: Signature code value is required")
        }
        
        // Validate assigned entity
        if authenticator.assignedEntity.id.isEmpty {
            errors.append("\(prefix)/assignedEntity/id: At least one identifier is required")
        }
    }
    
    // MARK: - Body Validation
    
    private func validateBody(_ document: ClinicalDocument, errors: inout [String], warnings: inout [String]) {
        switch document.component.body {
        case .structured(let structuredBody):
            validateStructuredBody(structuredBody, errors: &errors, warnings: &warnings)
        case .nonXML(let nonXMLBody):
            validateNonXMLBody(nonXMLBody, errors: &errors, warnings: &warnings)
        }
    }
    
    private func validateStructuredBody(_ body: StructuredBody, errors: inout [String], warnings: inout [String]) {
        if body.component.isEmpty {
            warnings.append("structuredBody: No sections found in body")
            return
        }
        
        for (index, component) in body.component.enumerated() {
            validateSection(component.section, path: "component[\(index)]/section", errors: &errors, warnings: &warnings)
        }
    }
    
    private func validateSection(_ section: Section, path: String, errors: inout [String], warnings: inout [String]) {
        // Validate section code
        if section.code == nil {
            warnings.append("\(path)/code: Section code is recommended")
        }
        
        // Validate section title
        if section.title == nil {
            warnings.append("\(path)/title: Section title is recommended")
        }
        
        // Validate narrative text
        if section.text == nil {
            warnings.append("\(path)/text: Section narrative text is recommended")
        }
        
        // Validate nested sections
        if let components = section.component {
            for (index, component) in components.enumerated() {
                validateSection(component.section, path: "\(path)/component[\(index)]/section", errors: &errors, warnings: &warnings)
            }
        }
        
        // Validate entries
        if let entries = section.entry {
            for (index, entry) in entries.enumerated() {
                validateEntry(entry, path: "\(path)/entry[\(index)]", errors: &errors, warnings: &warnings)
            }
        }
    }
    
    private func validateEntry(_ entry: Entry, path: String, errors: inout [String], warnings: inout [String]) {
        // Validate clinical statement
        switch entry.clinicalStatement {
        case .observation(let observation):
            validateObservation(observation, path: "\(path)/observation", errors: &errors, warnings: &warnings)
        case .procedure(let procedure):
            validateProcedure(procedure, path: "\(path)/procedure", errors: &errors, warnings: &warnings)
        case .substanceAdministration(let substanceAdmin):
            validateSubstanceAdministration(substanceAdmin, path: "\(path)/substanceAdministration", errors: &errors, warnings: &warnings)
        case .supply, .encounter, .act, .organizer:
            // Basic validation for other types
            break
        }
    }
    
    private func validateObservation(_ observation: ClinicalObservation, path: String, errors: inout [String], warnings: inout [String]) {
        // Validate observation code
        if observation.code.code == nil {
            warnings.append("\(path)/code: Observation code is recommended")
        }
        
        // Validate status code
        if observation.statusCode == .new || observation.statusCode == .held {
            warnings.append("\(path)/statusCode: Unusual status code '\(observation.statusCode.rawValue)'")
        }
        
        // Validate effective time
        if observation.effectiveTime == nil {
            warnings.append("\(path)/effectiveTime: Observation effective time is recommended")
        }
        
        // Validate value
        if observation.value?.isEmpty ?? true {
            warnings.append("\(path)/value: Observation value is recommended")
        }
    }
    
    private func validateProcedure(_ procedure: Procedure, path: String, errors: inout [String], warnings: inout [String]) {
        // Validate procedure code
        if procedure.code == nil {
            warnings.append("\(path)/code: Procedure code is recommended")
        }
        
        // Validate status code
        if procedure.statusCode == nil {
            warnings.append("\(path)/statusCode: Procedure status code is recommended")
        }
        
        // Validate effective time
        if procedure.effectiveTime == nil {
            warnings.append("\(path)/effectiveTime: Procedure effective time is recommended")
        }
    }
    
    private func validateSubstanceAdministration(_ substanceAdmin: SubstanceAdministration, path: String, errors: inout [String], warnings: inout [String]) {
        // Validate status code
        if substanceAdmin.statusCode == nil {
            warnings.append("\(path)/statusCode: Status code is recommended")
        }
        
        // Validate effective time
        if substanceAdmin.effectiveTime?.isEmpty ?? true {
            warnings.append("\(path)/effectiveTime: Effective time is recommended")
        }
        
        // Validate route code
        if substanceAdmin.routeCode == nil {
            warnings.append("\(path)/routeCode: Route code is recommended")
        }
        
        // Validate dose quantity
        if substanceAdmin.doseQuantity == nil {
            warnings.append("\(path)/doseQuantity: Dose quantity is recommended")
        }
        
        // Validate consumable
        if substanceAdmin.consumable.manufacturedProduct.manufacturedMaterial == nil {
            warnings.append("\(path)/consumable/manufacturedProduct/manufacturedMaterial: Material information is recommended")
        }
    }
    
    private func validateNonXMLBody(_ body: NonXMLBody, errors: inout [String], warnings: inout [String]) {
        // Validate media type
        if body.text.mediaType == nil {
            warnings.append("nonXMLBody/text: Media type is recommended")
        }
        
        // Validate content
        if body.text.data == nil && body.text.reference == nil {
            errors.append("nonXMLBody/text: Either data or reference is required")
        }
    }
}

// MARK: - CDAValidationResult

/// CDAValidationResult - Result of CDA validation
public struct CDAValidationResult: Sendable {
    /// Whether the document is valid (no errors)
    public let isValid: Bool
    
    /// Validation errors
    public let errors: [String]
    
    /// Validation warnings
    public let warnings: [String]
    
    public init(isValid: Bool, errors: [String], warnings: [String]) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - CDA Conformance Levels

/// CDAConformanceLevel - CDA conformance levels
public enum CDAConformanceLevel: Int, Sendable {
    /// Level 1: Non-structured body (narrative only)
    case level1 = 1
    
    /// Level 2: Structured sections with narrative
    case level2 = 2
    
    /// Level 3: Structured sections with coded entries
    case level3 = 3
    
    /// Determines the conformance level of a document
    public static func level(of document: ClinicalDocument) -> CDAConformanceLevel {
        switch document.component.body {
        case .nonXML:
            return .level1
        case .structured(let body):
            // Check if any section has entries
            let hasEntries = body.component.contains { component in
                hasEntriesInSection(component.section)
            }
            return hasEntries ? .level3 : .level2
        }
    }
    
    private static func hasEntriesInSection(_ section: Section) -> Bool {
        // Check if this section has entries
        if section.entry?.isEmpty == false {
            return true
        }
        
        // Check nested sections
        if let components = section.component {
            return components.contains { component in
                hasEntriesInSection(component.section)
            }
        }
        
        return false
    }
}

// MARK: - Validation Extensions

extension ClinicalDocument {
    /// Validates the document
    public func validate() async -> CDAValidationResult {
        await CDAValidator().validate(self)
    }
    
    /// Gets the conformance level of the document
    public var conformanceLevel: CDAConformanceLevel {
        CDAConformanceLevel.level(of: self)
    }
}

extension Section {
    /// Checks if the section has narrative content
    public var hasNarrative: Bool {
        text != nil
    }
    
    /// Checks if the section has structured entries
    public var hasEntries: Bool {
        entry?.isEmpty == false
    }
    
    /// Checks if the section has nested sections
    public var hasSubsections: Bool {
        component?.isEmpty == false
    }
}
