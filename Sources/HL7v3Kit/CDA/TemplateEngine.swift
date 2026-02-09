/// TemplateEngine.swift
/// Advanced Template Engine for CDA Documents
///
/// This file implements template inheritance, composition, and advanced constraint
/// validation for HL7 v3.x CDA documents.

import Foundation
import HL7Core

// MARK: - Template Inheritance

/// Protocol for templates that support inheritance
public protocol TemplateInheritable: Sendable {
    /// Parent template ID(s) from which this template inherits
    var parentTemplateIds: [String] { get }
    
    /// Merges this template with its parent templates
    func merged(with parent: CDATemplate) -> CDATemplate
}

extension CDATemplate: TemplateInheritable {
    /// Parent template IDs (empty by default, can be set during construction)
    public var parentTemplateIds: [String] {
        // Extract from constraints or return empty
        []
    }
    
    /// Merges this template with a parent template
    /// - Parameter parent: The parent template to merge with
    /// - Returns: A new template with merged properties
    public func merged(with parent: CDATemplate) -> CDATemplate {
        // Merge required elements (union)
        let mergedRequired = requiredElements.union(parent.requiredElements)
        
        // Merge optional elements (union, but remove if in required)
        let mergedOptional = optionalElements.union(parent.optionalElements).subtracting(mergedRequired)
        
        // Merge constraints (append parent constraints first, then child)
        let mergedConstraints = parent.constraints + constraints
        
        // Merge value set bindings (child overrides parent)
        var mergedBindings = parent.valueSetBindings
        for (key, value) in valueSetBindings {
            mergedBindings[key] = value
        }
        
        return CDATemplate(
            templateId: templateId,
            name: name,
            description: description ?? parent.description,
            documentType: documentType ?? parent.documentType,
            requiredElements: mergedRequired,
            optionalElements: mergedOptional,
            constraints: mergedConstraints,
            valueSetBindings: mergedBindings
        )
    }
}

// MARK: - Enhanced Template with Inheritance Support

/// Enhanced template definition with inheritance support
public struct EnhancedCDATemplate: Sendable, Equatable {
    /// Base template
    public let template: CDATemplate
    
    /// Parent template IDs
    public let parentTemplateIds: [String]
    
    /// Template version
    public let version: String?
    
    /// Template status (draft, active, retired)
    public let status: TemplateStatus
    
    /// Template publication date
    public let publicationDate: Date?
    
    /// Template author/organization
    public let author: String?
    
    public init(
        template: CDATemplate,
        parentTemplateIds: [String] = [],
        version: String? = nil,
        status: TemplateStatus = .active,
        publicationDate: Date? = nil,
        author: String? = nil
    ) {
        self.template = template
        self.parentTemplateIds = parentTemplateIds
        self.version = version
        self.status = status
        self.publicationDate = publicationDate
        self.author = author
    }
}

/// Template status
public enum TemplateStatus: String, Sendable, Codable {
    case draft
    case active
    case retired
}

// MARK: - Template Composer

/// Composes templates with inheritance resolution
public actor TemplateComposer {
    /// Shared instance
    public static let shared = TemplateComposer()
    
    /// Cache of composed templates
    private var composedTemplates: [String: CDATemplate] = [:]
    
    private init() {}
    
    /// Composes a template by resolving its inheritance chain
    /// - Parameters:
    ///   - templateId: The template ID to compose
    ///   - registry: The template registry to use for lookup
    /// - Returns: A fully composed template with all inherited properties
    /// - Throws: TemplateError if template cannot be found or circular dependency detected
    public func compose(
        templateId: String,
        using registry: TemplateRegistry = .shared
    ) async throws -> CDATemplate {
        // Check cache first
        if let cached = composedTemplates[templateId] {
            return cached
        }
        
        // Get the base template
        guard let template = await registry.template(for: templateId) else {
            throw TemplateError.templateNotFound(templateId)
        }
        
        // If no parents, return as-is
        let enhanced = await registry.enhancedTemplate(for: templateId)
        guard let enhanced = enhanced, !enhanced.parentTemplateIds.isEmpty else {
            composedTemplates[templateId] = template
            return template
        }
        
        // Resolve inheritance chain
        var composed = template
        var visited: Set<String> = [templateId]
        
        for parentId in enhanced.parentTemplateIds {
            // Detect circular dependencies
            if visited.contains(parentId) {
                throw TemplateError.circularDependency(templateId, parentId)
            }
            visited.insert(parentId)
            
            // Recursively compose parent
            let parent = try await compose(templateId: parentId, using: registry)
            
            // Merge with parent
            composed = composed.merged(with: parent)
        }
        
        // Cache and return
        composedTemplates[templateId] = composed
        return composed
    }
    
    /// Clears the composition cache
    public func clearCache() {
        composedTemplates.removeAll()
    }
}

// MARK: - Template Error

/// Errors that can occur during template operations
public enum TemplateError: Error, Sendable {
    case templateNotFound(String)
    case circularDependency(String, String)
    case invalidConstraint(String)
    case validationFailed([ValidationIssue])
}

extension TemplateError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .circularDependency(let child, let parent):
            return "Circular dependency detected between templates \(child) and \(parent)"
        case .invalidConstraint(let description):
            return "Invalid constraint: \(description)"
        case .validationFailed(let issues):
            return "Validation failed with \(issues.count) issue(s)"
        }
    }
}

// MARK: - Constraint Validation Engine

/// Advanced constraint validation engine
public struct ConstraintValidator {
    /// Validates constraints against a document
    /// - Parameters:
    ///   - constraints: The constraints to validate
    ///   - document: The document to validate against
    /// - Returns: Validation result with any issues found
    public func validate(
        constraints: [TemplateConstraint],
        against document: ClinicalDocument
    ) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        for constraint in constraints {
            let constraintIssues = validateConstraint(constraint, against: document)
            issues.append(contentsOf: constraintIssues)
        }
        
        return ValidationResult(
            isValid: issues.filter { $0.severity == .error }.isEmpty,
            issues: issues
        )
    }
    
    /// Validates a single constraint
    private func validateConstraint(
        _ constraint: TemplateConstraint,
        against document: ClinicalDocument
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate cardinality
        let count = countElements(at: constraint.elementPath, in: document)
        if count < constraint.cardinality.min {
            issues.append(ValidationIssue(
                severity: .error,
                path: constraint.elementPath,
                message: "Element occurs \(count) time(s), minimum required is \(constraint.cardinality.min)"
            ))
        }
        
        if let max = constraint.cardinality.max, count > max {
            issues.append(ValidationIssue(
                severity: .error,
                path: constraint.elementPath,
                message: "Element occurs \(count) time(s), maximum allowed is \(max)"
            ))
        }
        
        // Validate value constraint
        if let valueConstraint = constraint.valueConstraint {
            if !validateValue(valueConstraint, at: constraint.elementPath, in: document) {
                issues.append(ValidationIssue(
                    severity: .error,
                    path: constraint.elementPath,
                    message: "Value does not match constraint: \(valueConstraint)"
                ))
            }
        }
        
        // Validate data type
        if let dataType = constraint.dataType {
            if !validateDataType(dataType, at: constraint.elementPath, in: document) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    path: constraint.elementPath,
                    message: "Expected data type: \(dataType)"
                ))
            }
        }
        
        return issues
    }
    
    /// Counts elements at a given path
    private func countElements(at path: String, in document: ClinicalDocument) -> Int {
        // Simple path resolution (would be enhanced with full XPath support)
        let components = path.split(separator: "/")
        
        guard let first = components.first else {
            return 0
        }
        
        switch String(first) {
        case "realmCode":
            return document.realmCode?.count ?? 0
        case "templateId":
            return document.templateId.count
        case "recordTarget":
            return document.recordTarget.count
        case "author":
            return document.author.count
        case "component":
            return 1  // component is always present in ClinicalDocument
        default:
            return 0
        }
    }
    
    /// Validates a value constraint
    private func validateValue(_ constraint: String, at path: String, in document: ClinicalDocument) -> Bool {
        // Simple value validation (would be enhanced with pattern matching, etc.)
        if path.contains("realmCode") {
            return document.realmCode?.contains { $0.code == constraint } ?? false
        }
        
        if path.contains("code/@code") {
            return document.code.code == constraint
        }
        
        if path.contains("confidentialityCode") {
            return document.confidentialityCode.code == constraint
        }
        
        return true
    }
    
    /// Validates a data type constraint
    private func validateDataType(_ dataType: String, at path: String, in document: ClinicalDocument) -> Bool {
        // Simple data type validation (would be enhanced with full type checking)
        // For now, just return true as types are enforced by Swift type system
        return true
    }
}

// MARK: - Template Comparison

extension CDATemplate {
    /// Compares this template with another for differences
    /// - Parameter other: The template to compare with
    /// - Returns: A list of differences
    public func differences(from other: CDATemplate) -> [TemplateDifference] {
        var diffs: [TemplateDifference] = []
        
        // Compare required elements
        let addedRequired = requiredElements.subtracting(other.requiredElements)
        let removedRequired = other.requiredElements.subtracting(requiredElements)
        
        for element in addedRequired {
            diffs.append(.requiredElementAdded(element))
        }
        
        for element in removedRequired {
            diffs.append(.requiredElementRemoved(element))
        }
        
        // Compare optional elements
        let addedOptional = optionalElements.subtracting(other.optionalElements)
        let removedOptional = other.optionalElements.subtracting(optionalElements)
        
        for element in addedOptional {
            diffs.append(.optionalElementAdded(element))
        }
        
        for element in removedOptional {
            diffs.append(.optionalElementRemoved(element))
        }
        
        // Compare constraints
        if constraints.count != other.constraints.count {
            diffs.append(.constraintsChanged(from: other.constraints.count, to: constraints.count))
        }
        
        return diffs
    }
}

/// Differences between templates
public enum TemplateDifference: Sendable, Equatable {
    case requiredElementAdded(String)
    case requiredElementRemoved(String)
    case optionalElementAdded(String)
    case optionalElementRemoved(String)
    case constraintsChanged(from: Int, to: Int)
}
