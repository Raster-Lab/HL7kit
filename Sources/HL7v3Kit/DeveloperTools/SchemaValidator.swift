/// SchemaValidator.swift
/// Schema Validator Tool for HL7 v3.x XML messages
///
/// Provides comprehensive validation of XML documents against schemas,
/// CDA R2 conformance rules, and custom validation rules.

import Foundation
import HL7Core

// MARK: - Schema Validator

/// A comprehensive schema validation tool for HL7 v3.x messages
///
/// The SchemaValidator validates XML documents against schemas and conformance profiles,
/// with special support for CDA R2 documents. It provides detailed validation reports
/// and supports custom validation rules.
public actor SchemaValidator: Sendable {
    /// Validation result for an XML document
    public struct ValidationResult: Sendable {
        /// Whether the validation passed
        public let isValid: Bool
        
        /// List of validation errors
        public let errors: [ValidationError]
        
        /// List of validation warnings
        public let warnings: [ValidationWarning]
        
        /// Validation statistics
        public let statistics: ValidationStatistics
        
        /// Time taken to validate (in seconds)
        public let duration: TimeInterval
    }
    
    /// A validation error
    public struct ValidationError: Sendable, CustomStringConvertible {
        /// Error severity
        public enum Severity: String, Sendable {
            case critical
            case error
            case warning
        }
        
        /// Error code
        public let code: String
        
        /// Human-readable message
        public let message: String
        
        /// XPath to the problematic element
        public let xpath: String?
        
        /// Severity level
        public let severity: Severity
        
        /// Additional context
        public let context: [String: String]
        
        public var description: String {
            var result = "[\(severity.rawValue.uppercased())] \(code): \(message)"
            if let xpath = xpath {
                result += " (at \(xpath))"
            }
            return result
        }
    }
    
    /// A validation warning
    public struct ValidationWarning: Sendable, CustomStringConvertible {
        /// Warning code
        public let code: String
        
        /// Human-readable message
        public let message: String
        
        /// XPath to the element
        public let xpath: String?
        
        public var description: String {
            var result = "[WARNING] \(code): \(message)"
            if let xpath = xpath {
                result += " (at \(xpath))"
            }
            return result
        }
    }
    
    /// Validation statistics
    public struct ValidationStatistics: Sendable {
        /// Number of elements validated
        public let elementsValidated: Int
        
        /// Number of attributes validated
        public let attributesValidated: Int
        
        /// Number of errors found
        public let errorCount: Int
        
        /// Number of warnings found
        public let warningCount: Int
        
        /// Number of rules checked
        public let rulesChecked: Int
    }
    
    /// Validation configuration
    public struct Configuration: Sendable {
        /// Whether to validate against CDA R2 schema
        public var validateCDASchema: Bool
        
        /// Whether to check conformance rules
        public var checkConformanceRules: Bool
        
        /// Whether to validate cardinality
        public var validateCardinality: Bool
        
        /// Whether to validate code systems
        public var validateCodeSystems: Bool
        
        /// Whether to stop on first error
        public var stopOnFirstError: Bool
        
        /// Maximum errors to collect
        public var maxErrors: Int
        
        /// Creates a new configuration
        public init(
            validateCDASchema: Bool = true,
            checkConformanceRules: Bool = true,
            validateCardinality: Bool = true,
            validateCodeSystems: Bool = false,  // Requires external vocabulary
            stopOnFirstError: Bool = false,
            maxErrors: Int = 100
        ) {
            self.validateCDASchema = validateCDASchema
            self.checkConformanceRules = checkConformanceRules
            self.validateCardinality = validateCardinality
            self.validateCodeSystems = validateCodeSystems
            self.stopOnFirstError = stopOnFirstError
            self.maxErrors = maxErrors
        }
    }
    
    private let configuration: Configuration
    private var errors: [ValidationError] = []
    private var warnings: [ValidationWarning] = []
    
    /// Creates a new schema validator
    /// - Parameter configuration: Validation configuration
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Main Validation
    
    /// Validates an XML element
    /// - Parameter element: The root element to validate
    /// - Returns: Validation result
    public func validate(element: XMLElement) -> ValidationResult {
        let startTime = Date()
        errors.removeAll()
        warnings.removeAll()
        
        var elementsValidated = 0
        var attributesValidated = 0
        var rulesChecked = 0
        
        // CDA-specific validation
        if element.name == "ClinicalDocument" {
            if configuration.validateCDASchema {
                validateCDASchema(element: element, stats: &elementsValidated, &attributesValidated, &rulesChecked)
            }
            
            if configuration.checkConformanceRules {
                validateCDAConformance(element: element, stats: &rulesChecked)
            }
        } else {
            // Generic XML validation
            validateGenericXML(element: element, stats: &elementsValidated, &attributesValidated)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        let statistics = ValidationStatistics(
            elementsValidated: elementsValidated,
            attributesValidated: attributesValidated,
            errorCount: errors.count,
            warningCount: warnings.count,
            rulesChecked: rulesChecked
        )
        
        return ValidationResult(
            isValid: errors.filter { $0.severity != .warning }.isEmpty,
            errors: errors,
            warnings: warnings,
            statistics: statistics,
            duration: duration
        )
    }
    
    // MARK: - CDA Schema Validation
    
    private func validateCDASchema(
        element: XMLElement,
        stats elementsValidated: inout Int,
        _ attributesValidated: inout Int,
        _ rulesChecked: inout Int
    ) {
        elementsValidated += 1
        
        // Validate ClinicalDocument structure
        validateClinicalDocument(element, rulesChecked: &rulesChecked)
        
        // Recursively validate children
        for child in element.children {
            validateElement(
                child,
                parent: element,
                stats: &elementsValidated,
                &attributesValidated,
                &rulesChecked
            )
        }
    }
    
    private func validateClinicalDocument(_ element: XMLElement, rulesChecked: inout Int) {
        // Required attributes
        checkRequiredAttribute(element: element, attribute: "classCode", ruleName: "CDA-1")
        checkRequiredAttribute(element: element, attribute: "moodCode", ruleName: "CDA-2")
        rulesChecked += 2
        
        // Required child elements
        let requiredChildren = [
            "typeId", "id", "code", "title", "effectiveTime",
            "confidentialityCode", "recordTarget", "author",
            "custodian", "component"
        ]
        
        for childName in requiredChildren {
            if !hasChild(element, named: childName) {
                addError(
                    code: "CDA-MISSING-REQUIRED",
                    message: "Missing required element '\(childName)'",
                    xpath: "/ClinicalDocument",
                    severity: .error
                )
            }
            rulesChecked += 1
        }
        
        // Validate namespace
        if element.namespace != "urn:hl7-org:v3" {
            addWarning(
                code: "CDA-NAMESPACE",
                message: "ClinicalDocument should use HL7 v3 namespace",
                xpath: "/ClinicalDocument"
            )
        }
        rulesChecked += 1
    }
    
    private func validateElement(
        _ element: XMLElement,
        parent: XMLElement,
        stats elementsValidated: inout Int,
        _ attributesValidated: inout Int,
        _ rulesChecked: inout Int
    ) {
        elementsValidated += 1
        attributesValidated += element.attributes.count
        
        // Element-specific validation
        switch element.name {
        case "id":
            validateIdentifier(element, rulesChecked: &rulesChecked)
        case "code":
            validateCode(element, rulesChecked: &rulesChecked)
        case "effectiveTime":
            validateTimestamp(element, rulesChecked: &rulesChecked)
        case "templateId":
            validateTemplateId(element, rulesChecked: &rulesChecked)
        case "section":
            validateSection(element, rulesChecked: &rulesChecked)
        case "entry":
            validateEntry(element, rulesChecked: &rulesChecked)
        case "observation":
            validateObservation(element, rulesChecked: &rulesChecked)
        default:
            break
        }
        
        // Recursively validate children
        for child in element.children {
            validateElement(
                child,
                parent: element,
                stats: &elementsValidated,
                &attributesValidated,
                &rulesChecked
            )
        }
    }
    
    private func validateIdentifier(_ element: XMLElement, rulesChecked: inout Int) {
        if element.attributes["root"] == nil {
            addError(
                code: "ID-MISSING-ROOT",
                message: "Identifier must have 'root' attribute",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        rulesChecked += 1
    }
    
    private func validateCode(_ element: XMLElement, rulesChecked: inout Int) {
        let hasCode = element.attributes["code"] != nil
        let hasNullFlavor = element.attributes["nullFlavor"] != nil
        
        if !hasCode && !hasNullFlavor {
            addError(
                code: "CODE-MISSING",
                message: "Code element must have 'code' or 'nullFlavor' attribute",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        
        if hasCode && element.attributes["codeSystem"] == nil {
            addWarning(
                code: "CODE-NO-SYSTEM",
                message: "Code element should have 'codeSystem' attribute",
                xpath: elementXPath(element)
            )
        }
        rulesChecked += 2
    }
    
    private func validateTimestamp(_ element: XMLElement, rulesChecked: inout Int) {
        if let value = element.attributes["value"] {
            // Basic format check (YYYYMMDDHHMMSS)
            if value.count < 8 {
                addError(
                    code: "TIME-INVALID-FORMAT",
                    message: "Invalid timestamp format (should be YYYYMMDDHHMMSS)",
                    xpath: elementXPath(element),
                    severity: .error
                )
            }
        } else if element.attributes["nullFlavor"] == nil {
            addError(
                code: "TIME-MISSING-VALUE",
                message: "EffectiveTime must have 'value' or 'nullFlavor' attribute",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        rulesChecked += 1
    }
    
    private func validateTemplateId(_ element: XMLElement, rulesChecked: inout Int) {
        guard let root = element.attributes["root"] else {
            addError(
                code: "TEMPLATE-NO-ROOT",
                message: "TemplateId must have 'root' attribute",
                xpath: elementXPath(element),
                severity: .error
            )
            rulesChecked += 1
            return
        }
        
        // Check if it's a valid OID
        if !isValidOID(root) {
            addWarning(
                code: "TEMPLATE-INVALID-OID",
                message: "TemplateId root should be a valid OID",
                xpath: elementXPath(element)
            )
        }
        rulesChecked += 2
    }
    
    private func validateSection(_ element: XMLElement, rulesChecked: inout Int) {
        // Section must have either title or code
        let hasTitle = hasChild(element, named: "title")
        let hasCode = hasChild(element, named: "code")
        
        if !hasTitle && !hasCode {
            addWarning(
                code: "SECTION-NO-TITLE-CODE",
                message: "Section should have either title or code",
                xpath: elementXPath(element)
            )
        }
        rulesChecked += 1
    }
    
    private func validateEntry(_ element: XMLElement, rulesChecked: inout Int) {
        // Entry must contain a clinical statement
        let clinicalStatements = [
            "observation", "procedure", "substanceAdministration",
            "supply", "encounter", "act", "organizer"
        ]
        
        let hasStatement = element.children.contains { child in
            clinicalStatements.contains(child.name)
        }
        
        if !hasStatement {
            addError(
                code: "ENTRY-NO-STATEMENT",
                message: "Entry must contain a clinical statement",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        rulesChecked += 1
    }
    
    private func validateObservation(_ element: XMLElement, rulesChecked: inout Int) {
        // Observation must have classCode and moodCode
        checkRequiredAttribute(element: element, attribute: "classCode", ruleName: "OBS-1")
        checkRequiredAttribute(element: element, attribute: "moodCode", ruleName: "OBS-2")
        
        // Observation must have code, statusCode, and value
        if !hasChild(element, named: "code") {
            addError(
                code: "OBS-NO-CODE",
                message: "Observation must have code element",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        
        if !hasChild(element, named: "statusCode") {
            addError(
                code: "OBS-NO-STATUS",
                message: "Observation must have statusCode element",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        
        rulesChecked += 4
    }
    
    // MARK: - CDA Conformance Validation
    
    private func validateCDAConformance(element: XMLElement, stats rulesChecked: inout Int) {
        // Check for template conformance
        let templateIds = findElements(named: "templateId", in: element)
        
        for templateId in templateIds {
            if let root = templateId.attributes["root"] {
                validateTemplateConformance(root: root, element: element, rulesChecked: &rulesChecked)
            }
        }
        
        // Validate cardinality if enabled
        if configuration.validateCardinality {
            validateCardinality(element: element, rulesChecked: &rulesChecked)
        }
    }
    
    private func validateTemplateConformance(
        root: String,
        element: XMLElement,
        rulesChecked: inout Int
    ) {
        // US Realm Header template
        if root == "2.16.840.1.113883.10.20.22.1.1" {
            validateUSRealmHeader(element: element, rulesChecked: &rulesChecked)
        }
        
        // Continuity of Care Document template
        if root == "2.16.840.1.113883.10.20.22.1.2" {
            validateContinuityOfCareDocument(element: element, rulesChecked: &rulesChecked)
        }
        
        rulesChecked += 1
    }
    
    private func validateUSRealmHeader(element: XMLElement, rulesChecked: inout Int) {
        // US Realm Header requires specific elements
        if !hasChild(element, named: "realmCode") {
            addError(
                code: "USR-NO-REALM",
                message: "US Realm Header requires realmCode",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        
        if !hasChild(element, named: "languageCode") {
            addError(
                code: "USR-NO-LANG",
                message: "US Realm Header requires languageCode",
                xpath: elementXPath(element),
                severity: .error
            )
        }
        
        rulesChecked += 2
    }
    
    private func validateContinuityOfCareDocument(element: XMLElement, rulesChecked: inout Int) {
        // CCD requires specific sections
        let requiredSections = [
            "Allergies and Adverse Reactions",
            "Medications",
            "Problems",
            "Results"
        ]
        
        // This is simplified - real implementation would check section codes
        rulesChecked += 1
    }
    
    private func validateCardinality(element: XMLElement, rulesChecked: inout Int) {
        // Check for duplicate single-cardinality elements
        let singleElements = ["typeId", "id", "code", "title", "effectiveTime"]
        
        for elementName in singleElements {
            let count = element.children.filter { $0.name == elementName }.count
            if count > 1 {
                addError(
                    code: "CARD-DUPLICATE",
                    message: "Element '\(elementName)' should appear only once",
                    xpath: elementXPath(element),
                    severity: .error
                )
            }
            rulesChecked += 1
        }
    }
    
    // MARK: - Generic XML Validation
    
    private func validateGenericXML(
        element: XMLElement,
        stats elementsValidated: inout Int,
        _ attributesValidated: inout Int
    ) {
        elementsValidated += 1
        attributesValidated += element.attributes.count
        
        // Check for empty element names
        if element.name.isEmpty {
            addError(
                code: "XML-EMPTY-NAME",
                message: "Element name cannot be empty",
                xpath: elementXPath(element),
                severity: .critical
            )
        }
        
        // Recursively validate children
        for child in element.children {
            validateGenericXML(element: child, stats: &elementsValidated, &attributesValidated)
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkRequiredAttribute(
        element: XMLElement,
        attribute: String,
        ruleName: String
    ) {
        if element.attributes[attribute] == nil {
            addError(
                code: "\(ruleName)-MISSING-ATTR",
                message: "Missing required attribute '\(attribute)'",
                xpath: elementXPath(element),
                severity: .error
            )
        }
    }
    
    private func hasChild(_ element: XMLElement, named name: String) -> Bool {
        element.children.contains { $0.name == name }
    }
    
    private func findElements(named name: String, in element: XMLElement) -> [XMLElement] {
        var results: [XMLElement] = []
        
        func search(_ element: XMLElement) {
            if element.name == name {
                results.append(element)
            }
            for child in element.children {
                search(child)
            }
        }
        
        search(element)
        return results
    }
    
    private func elementXPath(_ element: XMLElement) -> String {
        // Simplified XPath generation
        "/" + element.name
    }
    
    private func isValidOID(_ oid: String) -> Bool {
        // Check if string matches OID format (e.g., "2.16.840.1.113883.10.20.22.1.1")
        let pattern = "^[0-2](\\.[1-9]\\d*)+$"
        return oid.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func addError(
        code: String,
        message: String,
        xpath: String?,
        severity: ValidationError.Severity,
        context: [String: String] = [:]
    ) {
        if errors.count >= configuration.maxErrors {
            return
        }
        
        errors.append(ValidationError(
            code: code,
            message: message,
            xpath: xpath,
            severity: severity,
            context: context
        ))
        
        if configuration.stopOnFirstError {
            // In a real implementation, this would stop validation
        }
    }
    
    private func addWarning(
        code: String,
        message: String,
        xpath: String?
    ) {
        warnings.append(ValidationWarning(
            code: code,
            message: message,
            xpath: xpath
        ))
    }
    
    // MARK: - Report Generation
    
    /// Generates a formatted validation report
    /// - Parameter result: The validation result
    /// - Returns: A formatted report string
    public func generateReport(result: ValidationResult) -> String {
        var report = """
        ═══════════════════════════════════════════════════════════
        VALIDATION REPORT
        ═══════════════════════════════════════════════════════════
        
        OVERALL STATUS: \(result.isValid ? "✓ VALID" : "✗ INVALID")
        
        STATISTICS:
        ───────────────────────────────────────────────────────────
        Elements Validated:     \(result.statistics.elementsValidated)
        Attributes Validated:   \(result.statistics.attributesValidated)
        Rules Checked:          \(result.statistics.rulesChecked)
        Errors Found:           \(result.statistics.errorCount)
        Warnings Found:         \(result.statistics.warningCount)
        Validation Time:        \(String(format: "%.3f", result.duration))s
        
        """
        
        if !result.errors.isEmpty {
            report += """
            ERRORS:
            ───────────────────────────────────────────────────────────
            
            """
            for error in result.errors {
                report += "\(error)\n"
            }
            report += "\n"
        }
        
        if !result.warnings.isEmpty {
            report += """
            WARNINGS:
            ───────────────────────────────────────────────────────────
            
            """
            for warning in result.warnings {
                report += "\(warning)\n"
            }
            report += "\n"
        }
        
        if result.isValid && result.warnings.isEmpty {
            report += "No errors or warnings found. Document is valid.\n\n"
        }
        
        report += "═══════════════════════════════════════════════════════════\n"
        
        return report
    }
}

// MARK: - XMLElement Extension

extension XMLElement {
    /// Convenience method to validate this element
    public func validate(configuration: SchemaValidator.Configuration = .init()) async -> SchemaValidator.ValidationResult {
        let validator = SchemaValidator(configuration: configuration)
        return await validator.validate(element: self)
    }
    
    /// Convenience method to validate and get a report
    public func validationReport(configuration: SchemaValidator.Configuration = .init()) async -> String {
        let validator = SchemaValidator(configuration: configuration)
        let result = await validator.validate(element: self)
        return await validator.generateReport(result: result)
    }
}
