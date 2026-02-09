/// TemplateAuthoring.swift
/// Template Authoring Tools and DSL
///
/// This file provides tools for authoring custom CDA templates, including
/// a DSL for template creation, validation, export/import, and testing utilities.

import Foundation
import HL7Core

// MARK: - Template Builder DSL

/// Builder for creating custom CDA templates with a fluent API
public struct TemplateBuilder {
    private var templateId: String
    private var name: String
    private var description: String?
    private var documentType: TemplateDocumentType?
    private var requiredElements: Set<String> = []
    private var optionalElements: Set<String> = []
    private var constraints: [TemplateConstraint] = []
    private var valueSetBindings: [String: String] = [:]
    private var parentTemplateIds: [String] = []
    private var version: String?
    private var status: TemplateStatus = .draft
    private var author: String?
    
    /// Initializes a new template builder
    /// - Parameters:
    ///   - templateId: Unique template identifier (OID)
    ///   - name: Template name
    public init(templateId: String, name: String) {
        self.templateId = templateId
        self.name = name
    }
    
    /// Sets the template description
    public func withDescription(_ description: String) -> TemplateBuilder {
        var builder = self
        builder.description = description
        return builder
    }
    
    /// Sets the document type
    public func withDocumentType(_ type: TemplateDocumentType) -> TemplateBuilder {
        var builder = self
        builder.documentType = type
        return builder
    }
    
    /// Adds a required element
    public func withRequiredElement(_ element: String) -> TemplateBuilder {
        var builder = self
        builder.requiredElements.insert(element)
        return builder
    }
    
    /// Adds multiple required elements
    public func withRequiredElements(_ elements: String...) -> TemplateBuilder {
        var builder = self
        builder.requiredElements.formUnion(elements)
        return builder
    }
    
    /// Adds an optional element
    public func withOptionalElement(_ element: String) -> TemplateBuilder {
        var builder = self
        builder.optionalElements.insert(element)
        return builder
    }
    
    /// Adds multiple optional elements
    public func withOptionalElements(_ elements: String...) -> TemplateBuilder {
        var builder = self
        builder.optionalElements.formUnion(elements)
        return builder
    }
    
    /// Adds a constraint
    public func withConstraint(_ constraint: TemplateConstraint) -> TemplateBuilder {
        var builder = self
        builder.constraints.append(constraint)
        return builder
    }
    
    /// Adds a constraint using a builder
    public func withConstraint(
        elementPath: String,
        cardinality: Cardinality,
        dataType: String? = nil,
        valueConstraint: String? = nil,
        description: String? = nil
    ) -> TemplateBuilder {
        let constraint = TemplateConstraint(
            elementPath: elementPath,
            cardinality: cardinality,
            dataType: dataType,
            valueConstraint: valueConstraint,
            description: description
        )
        return withConstraint(constraint)
    }
    
    /// Adds a value set binding
    public func withValueSetBinding(element: String, valueSetId: String) -> TemplateBuilder {
        var builder = self
        builder.valueSetBindings[element] = valueSetId
        return builder
    }
    
    /// Adds a parent template
    public func withParentTemplate(_ parentId: String) -> TemplateBuilder {
        var builder = self
        builder.parentTemplateIds.append(parentId)
        return builder
    }
    
    /// Sets the template version
    public func withVersion(_ version: String) -> TemplateBuilder {
        var builder = self
        builder.version = version
        return builder
    }
    
    /// Sets the template status
    public func withStatus(_ status: TemplateStatus) -> TemplateBuilder {
        var builder = self
        builder.status = status
        return builder
    }
    
    /// Sets the template author
    public func withAuthor(_ author: String) -> TemplateBuilder {
        var builder = self
        builder.author = author
        return builder
    }
    
    /// Builds the CDA template
    public func build() -> CDATemplate {
        CDATemplate(
            templateId: templateId,
            name: name,
            description: description,
            documentType: documentType,
            requiredElements: requiredElements,
            optionalElements: optionalElements,
            constraints: constraints,
            valueSetBindings: valueSetBindings
        )
    }
    
    /// Builds an enhanced CDA template
    public func buildEnhanced() -> EnhancedCDATemplate {
        EnhancedCDATemplate(
            template: build(),
            parentTemplateIds: parentTemplateIds,
            version: version,
            status: status,
            author: author
        )
    }
}

// MARK: - Template Validation Tools

/// Tools for validating template definitions
public struct TemplateValidationTools {
    /// Validates a template definition for common issues
    /// - Parameter template: The template to validate
    /// - Returns: Validation result with any issues found
    public func validateDefinition(_ template: CDATemplate) -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check for valid template ID (should be OID format)
        if !isValidOID(template.templateId) {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "templateId",
                message: "Template ID '\(template.templateId)' is not a valid OID format"
            ))
        }
        
        // Check for empty required elements
        if template.requiredElements.isEmpty && template.constraints.isEmpty {
            issues.append(ValidationIssue(
                severity: .warning,
                path: "template",
                message: "Template has no required elements or constraints"
            ))
        }
        
        // Check for duplicate elements in required and optional
        let duplicates = template.requiredElements.intersection(template.optionalElements)
        if !duplicates.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                path: "elements",
                message: "Elements appear in both required and optional: \(duplicates.joined(separator: ", "))"
            ))
        }
        
        // Validate constraints
        for constraint in template.constraints {
            let constraintIssues = validateConstraint(constraint)
            issues.append(contentsOf: constraintIssues)
        }
        
        return ValidationResult(
            isValid: issues.filter { $0.severity == .error }.isEmpty,
            issues: issues
        )
    }
    
    /// Validates a constraint definition
    private func validateConstraint(_ constraint: TemplateConstraint) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Check cardinality
        if constraint.cardinality.min < 0 {
            issues.append(ValidationIssue(
                severity: .error,
                path: constraint.elementPath,
                message: "Minimum cardinality cannot be negative"
            ))
        }
        
        if let max = constraint.cardinality.max, max < constraint.cardinality.min {
            issues.append(ValidationIssue(
                severity: .error,
                path: constraint.elementPath,
                message: "Maximum cardinality (\(max)) is less than minimum (\(constraint.cardinality.min))"
            ))
        }
        
        // Check for empty element path
        if constraint.elementPath.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                path: "constraint",
                message: "Constraint has empty element path"
            ))
        }
        
        return issues
    }
    
    /// Validates an OID format
    private func isValidOID(_ oid: String) -> Bool {
        // OID should be in format: digits.digits.digits...
        let components = oid.split(separator: ".")
        guard components.count >= 2 else { return false }
        return components.allSatisfy { Int($0) != nil }
    }
}

// MARK: - Template Export/Import

/// Template serialization format
public enum TemplateFormat {
    case json
    case xml
}

/// Template export/import service
public struct TemplateExporter {
    /// Exports a template to JSON format
    /// - Parameter template: The template to export
    /// - Returns: JSON data
    /// - Throws: Encoding error
    public func exportJSON(_ template: EnhancedCDATemplate) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let exportable = ExportableTemplate(from: template)
        return try encoder.encode(exportable)
    }
    
    /// Imports a template from JSON format
    /// - Parameter data: The JSON data
    /// - Returns: Enhanced template
    /// - Throws: Decoding error
    public func importJSON(_ data: Data) throws -> EnhancedCDATemplate {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportable = try decoder.decode(ExportableTemplate.self, from: data)
        return exportable.toEnhancedTemplate()
    }
    
    /// Exports a template to XML format
    /// - Parameter template: The template to export
    /// - Returns: XML string
    public func exportXML(_ template: EnhancedCDATemplate) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<template>\n"
        xml += "  <templateId>\(escapeXML(template.template.templateId))</templateId>\n"
        xml += "  <name>\(escapeXML(template.template.name))</name>\n"
        
        if let description = template.template.description {
            xml += "  <description>\(escapeXML(description))</description>\n"
        }
        
        if let version = template.version {
            xml += "  <version>\(escapeXML(version))</version>\n"
        }
        
        xml += "  <status>\(template.status.rawValue)</status>\n"
        
        if let author = template.author {
            xml += "  <author>\(escapeXML(author))</author>\n"
        }
        
        // Parent templates
        if !template.parentTemplateIds.isEmpty {
            xml += "  <parents>\n"
            for parentId in template.parentTemplateIds {
                xml += "    <parent>\(escapeXML(parentId))</parent>\n"
            }
            xml += "  </parents>\n"
        }
        
        // Required elements
        if !template.template.requiredElements.isEmpty {
            xml += "  <requiredElements>\n"
            for element in template.template.requiredElements.sorted() {
                xml += "    <element>\(escapeXML(element))</element>\n"
            }
            xml += "  </requiredElements>\n"
        }
        
        // Optional elements
        if !template.template.optionalElements.isEmpty {
            xml += "  <optionalElements>\n"
            for element in template.template.optionalElements.sorted() {
                xml += "    <element>\(escapeXML(element))</element>\n"
            }
            xml += "  </optionalElements>\n"
        }
        
        // Constraints
        if !template.template.constraints.isEmpty {
            xml += "  <constraints>\n"
            for constraint in template.template.constraints {
                xml += "    <constraint>\n"
                xml += "      <elementPath>\(escapeXML(constraint.elementPath))</elementPath>\n"
                xml += "      <cardinality min=\"\(constraint.cardinality.min)\""
                if let max = constraint.cardinality.max {
                    xml += " max=\"\(max)\""
                }
                xml += "/>\n"
                if let dataType = constraint.dataType {
                    xml += "      <dataType>\(escapeXML(dataType))</dataType>\n"
                }
                if let valueConstraint = constraint.valueConstraint {
                    xml += "      <valueConstraint>\(escapeXML(valueConstraint))</valueConstraint>\n"
                }
                xml += "    </constraint>\n"
            }
            xml += "  </constraints>\n"
        }
        
        xml += "</template>"
        return xml
    }
    
    /// Escapes XML special characters
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Exportable Template (Codable)

/// Codable wrapper for template export/import
struct ExportableTemplate: Codable {
    let templateId: String
    let name: String
    let description: String?
    let documentType: String?
    let requiredElements: [String]
    let optionalElements: [String]
    let constraints: [ExportableConstraint]
    let valueSetBindings: [String: String]
    let parentTemplateIds: [String]
    let version: String?
    let status: String
    let author: String?
    let publicationDate: Date?
    
    init(from template: EnhancedCDATemplate) {
        self.templateId = template.template.templateId
        self.name = template.template.name
        self.description = template.template.description
        self.documentType = template.template.documentType?.rawValue
        self.requiredElements = Array(template.template.requiredElements).sorted()
        self.optionalElements = Array(template.template.optionalElements).sorted()
        self.constraints = template.template.constraints.map { ExportableConstraint(from: $0) }
        self.valueSetBindings = template.template.valueSetBindings
        self.parentTemplateIds = template.parentTemplateIds
        self.version = template.version
        self.status = template.status.rawValue
        self.author = template.author
        self.publicationDate = template.publicationDate
    }
    
    func toEnhancedTemplate() -> EnhancedCDATemplate {
        let template = CDATemplate(
            templateId: templateId,
            name: name,
            description: description,
            documentType: documentType.flatMap { TemplateDocumentType(rawValue: $0) },
            requiredElements: Set(requiredElements),
            optionalElements: Set(optionalElements),
            constraints: constraints.map { $0.toTemplateConstraint() },
            valueSetBindings: valueSetBindings
        )
        
        return EnhancedCDATemplate(
            template: template,
            parentTemplateIds: parentTemplateIds,
            version: version,
            status: TemplateStatus(rawValue: status) ?? .draft,
            publicationDate: publicationDate,
            author: author
        )
    }
}

struct ExportableConstraint: Codable {
    let elementPath: String
    let cardinalityMin: Int
    let cardinalityMax: Int?
    let dataType: String?
    let valueConstraint: String?
    let description: String?
    
    init(from constraint: TemplateConstraint) {
        self.elementPath = constraint.elementPath
        self.cardinalityMin = constraint.cardinality.min
        self.cardinalityMax = constraint.cardinality.max
        self.dataType = constraint.dataType
        self.valueConstraint = constraint.valueConstraint
        self.description = constraint.description
    }
    
    func toTemplateConstraint() -> TemplateConstraint {
        TemplateConstraint(
            elementPath: elementPath,
            cardinality: Cardinality(min: cardinalityMin, max: cardinalityMax),
            dataType: dataType,
            valueConstraint: valueConstraint,
            description: description
        )
    }
}

// MARK: - Template Testing Utilities

/// Utilities for testing templates
public struct TemplateTestingUtilities {
    /// Creates a mock ClinicalDocument for testing a template
    /// - Parameters:
    ///   - template: The template to test against
    ///   - includeAllRequired: Whether to include all required elements
    /// - Returns: A test document
    /// - Throws: Build error
    public func createMockDocument(
        for template: CDATemplate,
        includeAllRequired: Bool = true
    ) throws -> ClinicalDocument {
        var builder = CDADocumentBuilder()
            .withId(root: "2.16.840.1.113883.19.5", extension: "TEST123")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Test Document for \(template.name)")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withRecordTarget { target in
                target.withPatientId(root: "test", extension: "PT123")
                    .withPatientName(given: "Test", family: "Patient")
            }
            .withAuthor { author in
                author.withTime(Date())
                    .withAuthorId(root: "test", extension: "AUTH123")
                    .withAuthorName(given: "Test", family: "Author")
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "test")
                    .withOrganizationName("Test Organization")
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withTitle("Test Section")
                        .withText("Test content")
                }
            }
        
        // Add template-specific elements if needed
        if includeAllRequired {
            for element in template.requiredElements {
                // Handle specific required elements
                switch element {
                case "realmCode":
                    builder = builder.withRealmCode("US")
                case "languageCode":
                    builder = builder.withLanguage("en-US")
                default:
                    break
                }
            }
        }
        
        return try builder.build()
    }
    
    /// Validates a document against a template and returns a detailed report
    /// - Parameters:
    ///   - document: The document to validate
    ///   - template: The template to validate against
    /// - Returns: Detailed validation report
    public func validateAndReport(
        document: ClinicalDocument,
        against template: CDATemplate
    ) -> TemplateValidationReport {
        let validator = TemplateValidator()
        
        // Create a temporary document with this template
        var testDoc = document
        testDoc.templateId.append(II(root: template.templateId))
        
        // Validate
        let result = validator.validateTemplate(template, for: testDoc)
        
        // Generate report
        return TemplateValidationReport(
            templateId: template.templateId,
            templateName: template.name,
            isValid: result.isEmpty,
            issues: result,
            summary: generateSummary(for: result)
        )
    }
    
    /// Generates a summary of validation issues
    private func generateSummary(for issues: [ValidationIssue]) -> String {
        if issues.isEmpty {
            return "✓ Document is valid according to template"
        }
        
        let errors = issues.filter { $0.severity == .error }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        
        return "✗ Validation failed: \(errors) error(s), \(warnings) warning(s)"
    }
}

/// Template validation report
public struct TemplateValidationReport: Sendable {
    public let templateId: String
    public let templateName: String
    public let isValid: Bool
    public let issues: [ValidationIssue]
    public let summary: String
    
    /// Generates a formatted report string
    public var formattedReport: String {
        var report = """
        Template Validation Report
        ==========================
        Template: \(templateName) (\(templateId))
        Status: \(isValid ? "VALID" : "INVALID")
        \(summary)
        
        """
        
        if !issues.isEmpty {
            report += "Issues:\n"
            for (index, issue) in issues.enumerated() {
                report += "\(index + 1). [\(issue.severity.rawValue.uppercased())] \(issue.path): \(issue.message)\n"
            }
        }
        
        return report
    }
}
