/// CDATemplates.swift
/// CDA R2 Template Processing and C-CDA Support
///
/// This file implements template processing infrastructure for CDA documents,
/// including support for common C-CDA templates.

import Foundation
import HL7Core

// MARK: - Template

/// Template - Represents a CDA template definition
public struct CDATemplate: Sendable, Equatable {
    /// Template identifier (OID)
    public let templateId: String
    
    /// Template name
    public let name: String
    
    /// Template description
    public let description: String?
    
    /// Document type this template applies to
    public let documentType: TemplateDocumentType?
    
    /// Required elements
    public let requiredElements: Set<String>
    
    /// Optional elements
    public let optionalElements: Set<String>
    
    /// Cardinality constraints
    public let constraints: [TemplateConstraint]
    
    /// Value set bindings
    public let valueSetBindings: [String: String]
    
    public init(
        templateId: String,
        name: String,
        description: String? = nil,
        documentType: TemplateDocumentType? = nil,
        requiredElements: Set<String> = [],
        optionalElements: Set<String> = [],
        constraints: [TemplateConstraint] = [],
        valueSetBindings: [String: String] = [:]
    ) {
        self.templateId = templateId
        self.name = name
        self.description = description
        self.documentType = documentType
        self.requiredElements = requiredElements
        self.optionalElements = optionalElements
        self.constraints = constraints
        self.valueSetBindings = valueSetBindings
    }
}

/// Template document type
public enum TemplateDocumentType: String, Sendable, Codable {
    case progressNote
    case dischargeSummary
    case historyAndPhysical
    case consultationNote
    case operativeNote
    case procedureNote
    case continuityOfCareDocument
    case referralNote
    case transferSummary
}

/// Template constraint
public struct TemplateConstraint: Sendable, Equatable {
    /// Element path (XPath-like)
    public let elementPath: String
    
    /// Cardinality (min..max)
    public let cardinality: Cardinality
    
    /// Data type constraint
    public let dataType: String?
    
    /// Value constraint (fixed value or pattern)
    public let valueConstraint: String?
    
    /// Description of the constraint
    public let description: String?
    
    public init(
        elementPath: String,
        cardinality: Cardinality,
        dataType: String? = nil,
        valueConstraint: String? = nil,
        description: String? = nil
    ) {
        self.elementPath = elementPath
        self.cardinality = cardinality
        self.dataType = dataType
        self.valueConstraint = valueConstraint
        self.description = description
    }
}

/// Cardinality constraint
public struct Cardinality: Sendable, Equatable {
    /// Minimum occurrences
    public let min: Int
    
    /// Maximum occurrences (nil = unbounded)
    public let max: Int?
    
    public init(min: Int, max: Int? = nil) {
        self.min = min
        self.max = max
    }
    
    /// Creates a required element (1..1)
    public static var required: Cardinality {
        Cardinality(min: 1, max: 1)
    }
    
    /// Creates an optional element (0..1)
    public static var optional: Cardinality {
        Cardinality(min: 0, max: 1)
    }
    
    /// Creates a required repeating element (1..*)
    public static var requiredRepeating: Cardinality {
        Cardinality(min: 1, max: nil)
    }
    
    /// Creates an optional repeating element (0..*)
    public static var optionalRepeating: Cardinality {
        Cardinality(min: 0, max: nil)
    }
}

// MARK: - Template Registry

/// TemplateRegistry - Registry of known CDA templates
public actor TemplateRegistry {
    /// Shared instance
    public static let shared = TemplateRegistry()
    
    /// Registered templates
    private var templates: [String: CDATemplate] = [:]
    
    /// Indicates whether templates have been loaded
    private var templatesLoaded = false
    
    private init() {
        // Templates will be loaded on first access
    }
    
    /// Ensures templates are loaded (called internally before any access)
    private func ensureTemplatesLoaded() {
        guard !templatesLoaded else { return }
        registerCommonTemplates()
        templatesLoaded = true
    }
    
    /// Registers a template
    public func register(_ template: CDATemplate) {
        ensureTemplatesLoaded()
        templates[template.templateId] = template
    }
    
    /// Gets a template by ID
    public func template(for templateId: String) -> CDATemplate? {
        ensureTemplatesLoaded()
        return templates[templateId]
    }
    
    /// Gets all registered templates
    public func allTemplates() -> [CDATemplate] {
        ensureTemplatesLoaded()
        return Array(templates.values)
    }
    
    /// Registers common C-CDA templates
    private func registerCommonTemplates() {
        // C-CDA R2.1 US Realm Header
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.1",
            name: "US Realm Header",
            description: "This template defines constraints that represent common data elements for use in US Realm clinical documents.",
            requiredElements: [
                "realmCode",
                "typeId",
                "templateId",
                "id",
                "code",
                "effectiveTime",
                "confidentialityCode",
                "recordTarget",
                "author",
                "custodian"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "realmCode/@code",
                    cardinality: .required,
                    valueConstraint: "US"
                ),
                TemplateConstraint(
                    elementPath: "typeId/@root",
                    cardinality: .required,
                    valueConstraint: "2.16.840.1.113883.1.3"
                ),
                TemplateConstraint(
                    elementPath: "recordTarget",
                    cardinality: .requiredRepeating
                ),
                TemplateConstraint(
                    elementPath: "author",
                    cardinality: .requiredRepeating
                )
            ]
        ))
        
        // C-CDA Progress Note
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.9",
            name: "Progress Note",
            description: "The Progress Note represents a patient's clinical status during a hospitalization, outpatient visit, treatment with a post-acute care provider, or other healthcare encounter.",
            documentType: .progressNote,
            requiredElements: [
                "code",
                "componentOf"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "11506-3"
                )
            ]
        ))
        
        // C-CDA Consultation Note
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.4",
            name: "Consultation Note",
            description: "The Consultation Note is generated by a request from a clinician for an opinion or advice from another clinician.",
            documentType: .consultationNote,
            requiredElements: [
                "code"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "11488-4"
                )
            ]
        ))
        
        // C-CDA Discharge Summary
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.8",
            name: "Discharge Summary",
            description: "The Discharge Summary is a document which synopsizes a patient's admission to a hospital, LTPAC provider, or other setting.",
            documentType: .dischargeSummary,
            requiredElements: [
                "code"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "18842-5"
                )
            ]
        ))
        
        // C-CDA History and Physical
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.3",
            name: "History and Physical",
            description: "A History and Physical (H&P) note is a medical report that documents the current and past conditions of the patient.",
            documentType: .historyAndPhysical,
            requiredElements: [
                "code"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "34117-2"
                )
            ]
        ))
        
        // C-CDA Operative Note
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.7",
            name: "Operative Note",
            description: "The Operative Note is a frequently used type of procedure note with specific requirements set forth by regulatory agencies.",
            documentType: .operativeNote,
            requiredElements: [
                "code",
                "componentOf"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "11504-8"
                )
            ]
        ))
        
        // C-CDA Continuity of Care Document (CCD)
        register(CDATemplate(
            templateId: "2.16.840.1.113883.10.20.22.1.2",
            name: "Continuity of Care Document",
            description: "The Continuity of Care Document (CCD) represents a core data set of the most relevant administrative, demographic, and clinical information facts about a patient's healthcare.",
            documentType: .continuityOfCareDocument,
            requiredElements: [
                "code"
            ],
            constraints: [
                TemplateConstraint(
                    elementPath: "code/@code",
                    cardinality: .required,
                    valueConstraint: "34133-9"
                )
            ]
        ))
    }
}

// MARK: - Template Validation

/// TemplateValidator - Validates documents against templates
public struct TemplateValidator {
    /// Validates a document against its declared templates
    public func validate(_ document: ClinicalDocument) async -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Get all template IDs from the document
        let templateIds = document.templateId.map(\.root)
        
        // Validate each template
        for templateId in templateIds {
            guard let template = await TemplateRegistry.shared.template(for: templateId) else {
                issues.append(ValidationIssue(
                    severity: .warning,
                    path: "ClinicalDocument/templateId",
                    message: "Unknown template: \(templateId)"
                ))
                continue
            }
            
            // Validate required elements
            let documentIssues = validateTemplate(template, for: document)
            issues.append(contentsOf: documentIssues)
        }
        
        return ValidationResult(
            isValid: issues.filter { $0.severity == .error }.isEmpty,
            issues: issues
        )
    }
    
    /// Validates a document against a specific template
    private func validateTemplate(_ template: CDATemplate, for document: ClinicalDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate document type code
        if let documentType = template.documentType {
            let expectedCode = codeForDocumentType(documentType)
            if document.code.code != expectedCode {
                issues.append(ValidationIssue(
                    severity: .error,
                    path: "ClinicalDocument/code",
                    message: "Expected code '\(expectedCode)' for template '\(template.name)', found '\(document.code.code ?? "none")'"
                ))
            }
        }
        
        // Validate required elements
        for element in template.requiredElements {
            if !hasElement(element, in: document) {
                issues.append(ValidationIssue(
                    severity: .error,
                    path: "ClinicalDocument/\(element)",
                    message: "Required element '\(element)' is missing for template '\(template.name)'"
                ))
            }
        }
        
        // Validate constraints
        for constraint in template.constraints {
            let constraintIssues = validateConstraint(constraint, for: document)
            issues.append(contentsOf: constraintIssues)
        }
        
        return issues
    }
    
    /// Validates a constraint
    private func validateConstraint(_ constraint: TemplateConstraint, for document: ClinicalDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Simple constraint validation
        // In a full implementation, this would use XPath or a similar query language
        
        if let valueConstraint = constraint.valueConstraint {
            // Check if value matches constraint
            if constraint.elementPath.contains("realmCode") {
                if let realmCodes = document.realmCode, !realmCodes.isEmpty {
                    let hasMatchingCode = realmCodes.contains { $0.code == valueConstraint }
                    if !hasMatchingCode {
                        issues.append(ValidationIssue(
                            severity: .error,
                            path: constraint.elementPath,
                            message: "Expected value '\(valueConstraint)' at path '\(constraint.elementPath)'"
                        ))
                    }
                } else if constraint.cardinality.min > 0 {
                    issues.append(ValidationIssue(
                        severity: .error,
                        path: constraint.elementPath,
                        message: "Required element is missing: '\(constraint.elementPath)'"
                    ))
                }
            }
        }
        
        return issues
    }
    
    /// Checks if a document has an element
    private func hasElement(_ element: String, in document: ClinicalDocument) -> Bool {
        switch element {
        case "realmCode": return document.realmCode != nil && !document.realmCode!.isEmpty
        case "typeId": return true // Always present
        case "templateId": return !document.templateId.isEmpty
        case "id": return true // Always present
        case "code": return true // Always present
        case "effectiveTime": return true // Always present
        case "confidentialityCode": return true // Always present
        case "languageCode": return document.languageCode != nil
        case "recordTarget": return !document.recordTarget.isEmpty
        case "author": return !document.author.isEmpty
        case "custodian": return true // Always present
        case "componentOf": return false // TODO: componentOf is not yet implemented in ClinicalDocument
        default: return false
        }
    }
    
    /// Gets the expected LOINC code for a document type
    private func codeForDocumentType(_ type: TemplateDocumentType) -> String {
        switch type {
        case .progressNote: return "11506-3"
        case .dischargeSummary: return "18842-5"
        case .historyAndPhysical: return "34117-2"
        case .consultationNote: return "11488-4"
        case .operativeNote: return "11504-8"
        case .procedureNote: return "28570-0"
        case .continuityOfCareDocument: return "34133-9"
        case .referralNote: return "57133-1"
        case .transferSummary: return "18761-7"
        }
    }
}

// MARK: - Validation Result

/// ValidationResult - Result of template validation
public struct ValidationResult: Sendable {
    /// Whether the document is valid
    public let isValid: Bool
    
    /// Validation issues found
    public let issues: [ValidationIssue]
    
    public init(isValid: Bool, issues: [ValidationIssue]) {
        self.isValid = isValid
        self.issues = issues
    }
}

/// ValidationIssue - A validation issue
public struct ValidationIssue: Sendable {
    /// Severity of the issue
    public let severity: Severity
    
    /// Path to the element with the issue
    public let path: String
    
    /// Description of the issue
    public let message: String
    
    public init(severity: Severity, path: String, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
    
    /// Issue severity
    public enum Severity: String, Sendable {
        case error
        case warning
        case info
    }
}

// MARK: - Common Template IDs

/// Common C-CDA template identifiers
public extension II {
    /// US Realm Header template ID
    static let usRealmHeader = II(root: "2.16.840.1.113883.10.20.22.1.1")
    
    /// Progress Note template ID
    static let progressNoteTemplate = II(root: "2.16.840.1.113883.10.20.22.1.9")
    
    /// Consultation Note template ID
    static let consultationNoteTemplate = II(root: "2.16.840.1.113883.10.20.22.1.4")
    
    /// Discharge Summary template ID
    static let dischargeSummaryTemplate = II(root: "2.16.840.1.113883.10.20.22.1.8")
    
    /// History and Physical template ID
    static let historyAndPhysicalTemplate = II(root: "2.16.840.1.113883.10.20.22.1.3")
    
    /// Operative Note template ID
    static let operativeNoteTemplate = II(root: "2.16.840.1.113883.10.20.22.1.7")
    
    /// Continuity of Care Document template ID
    static let ccdTemplate = II(root: "2.16.840.1.113883.10.20.22.1.2")
    
    /// Procedure Note template ID
    static let procedureNoteTemplate = II(root: "2.16.840.1.113883.10.20.22.1.6")
}
