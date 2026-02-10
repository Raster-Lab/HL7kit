/// FHIRValidation.swift
/// Core FHIR validation engine
///
/// Provides comprehensive resource validation including structural validation,
/// cardinality checking, value set validation, profile validation, FHIRPath
/// expression evaluation, and custom validation rules.

import Foundation
import HL7Core

// MARK: - Element Definition

/// Represents a FHIR ElementDefinition — defines constraints on an element within a StructureDefinition.
public struct ElementDefinition: Sendable, Equatable {
    /// Element path (e.g., "Patient.name")
    public let path: String

    /// Minimum cardinality
    public let min: Int

    /// Maximum cardinality ("*" for unbounded)
    public let max: String

    /// Short description
    public let short: String?

    /// Data types allowed for this element
    public let types: [ElementType]

    /// Fixed value (must match exactly)
    public let fixedValue: String?

    /// Pattern value (resource must contain at least these values)
    public let patternValue: String?

    /// Whether this element is marked as mustSupport
    public let mustSupport: Bool

    /// Binding to a value set
    public let binding: ElementBinding?

    /// Constraints (invariants) on this element
    public let constraints: [ElementConstraint]

    /// Whether this element is a modifier
    public let isModifier: Bool

    /// Whether this element is a summary element
    public let isSummary: Bool

    /// The slice name, if this is a slice definition
    public let sliceName: String?

    /// Maximum cardinality as integer (nil means unbounded)
    public var maxInt: Int? {
        if max == "*" { return nil }
        return Int(max)
    }

    /// Whether the element is required (min >= 1)
    public var isRequired: Bool {
        min >= 1
    }

    /// Whether the element is prohibited (max == "0")
    public var isProhibited: Bool {
        max == "0"
    }

    public init(
        path: String,
        min: Int = 0,
        max: String = "*",
        short: String? = nil,
        types: [ElementType] = [],
        fixedValue: String? = nil,
        patternValue: String? = nil,
        mustSupport: Bool = false,
        binding: ElementBinding? = nil,
        constraints: [ElementConstraint] = [],
        isModifier: Bool = false,
        isSummary: Bool = false,
        sliceName: String? = nil
    ) {
        self.path = path
        self.min = min
        self.max = max
        self.short = short
        self.types = types
        self.fixedValue = fixedValue
        self.patternValue = patternValue
        self.mustSupport = mustSupport
        self.binding = binding
        self.constraints = constraints
        self.isModifier = isModifier
        self.isSummary = isSummary
        self.sliceName = sliceName
    }
}

// MARK: - Element Type

/// A type allowed for an element
public struct ElementType: Sendable, Equatable {
    /// Type code (e.g., "string", "Reference", "CodeableConcept")
    public let code: String

    /// Target profiles for Reference types
    public let targetProfiles: [String]

    public init(code: String, targetProfiles: [String] = []) {
        self.code = code
        self.targetProfiles = targetProfiles
    }
}

// MARK: - Element Binding

/// Binding of an element to a value set
public struct ElementBinding: Sendable, Equatable {
    /// Binding strength
    public let strength: BindingStrength

    /// Value set URI
    public let valueSetUri: String

    /// Description of the binding
    public let description: String?

    public init(
        strength: BindingStrength,
        valueSetUri: String,
        description: String? = nil
    ) {
        self.strength = strength
        self.valueSetUri = valueSetUri
        self.description = description
    }
}

/// Strength of a value set binding
public enum BindingStrength: String, Sendable, Equatable {
    /// Codes MUST come from the specified value set
    case required = "required"
    /// Codes SHOULD come from the specified value set
    case extensible = "extensible"
    /// Codes are recommended from the specified value set
    case preferred = "preferred"
    /// Value set is provided as an example
    case example = "example"
}

// MARK: - Element Constraint

/// A constraint (invariant) on an element
public struct ElementConstraint: Sendable, Equatable {
    /// Constraint key (e.g., "ele-1")
    public let key: String

    /// Severity of the constraint
    public let severity: ConstraintSeverity

    /// Human-readable description
    public let human: String

    /// FHIRPath expression for the constraint
    public let expression: String?

    public init(
        key: String,
        severity: ConstraintSeverity = .error,
        human: String,
        expression: String? = nil
    ) {
        self.key = key
        self.severity = severity
        self.human = human
        self.expression = expression
    }
}

/// Severity of a constraint
public enum ConstraintSeverity: String, Sendable, Equatable {
    case error
    case warning
}

// MARK: - Structure Definition

/// Represents a FHIR StructureDefinition — defines the structure of a resource or profile.
public struct StructureDefinition: Sendable, Equatable {
    /// Canonical URL for the structure definition
    public let url: String

    /// Name of the structure definition
    public let name: String

    /// Human-readable title
    public let title: String?

    /// Status of the definition
    public let status: PublicationStatus

    /// Kind of structure (resource, complex-type, primitive-type, logical)
    public let kind: StructureDefinitionKind

    /// Whether this is abstract
    public let abstract: Bool

    /// The base definition this derives from
    public let baseDefinition: String?

    /// Type of the resource (e.g., "Patient", "Observation")
    public let type: String

    /// Version of the definition
    public let version: String?

    /// Element definitions (the differential or snapshot)
    public let elements: [ElementDefinition]

    public init(
        url: String,
        name: String,
        title: String? = nil,
        status: PublicationStatus = .active,
        kind: StructureDefinitionKind = .resource,
        abstract: Bool = false,
        baseDefinition: String? = nil,
        type: String,
        version: String? = nil,
        elements: [ElementDefinition] = []
    ) {
        self.url = url
        self.name = name
        self.title = title
        self.status = status
        self.kind = kind
        self.abstract = abstract
        self.baseDefinition = baseDefinition
        self.type = type
        self.version = version
        self.elements = elements
    }
}

/// Kind of structure definition
public enum StructureDefinitionKind: String, Sendable, Equatable {
    case primitiveType = "primitive-type"
    case complexType = "complex-type"
    case resource
    case logical
}

/// Publication status
public enum PublicationStatus: String, Sendable, Equatable {
    case draft
    case active
    case retired
    case unknown
}

// MARK: - Validation Issue

/// A single validation issue found during FHIR resource validation
public struct FHIRValidationIssue: Sendable, Equatable {
    /// Severity of the issue
    public let severity: IssueSeverity

    /// Type of issue
    public let code: IssueType

    /// Human-readable description
    public let details: String

    /// FHIRPath expression indicating the location
    public let expression: String?

    /// Constraint key that was violated
    public let constraintKey: String?

    public init(
        severity: IssueSeverity,
        code: IssueType,
        details: String,
        expression: String? = nil,
        constraintKey: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.details = details
        self.expression = expression
        self.constraintKey = constraintKey
    }
}

/// Issue severity (matching OperationOutcome.issue.severity)
public enum IssueSeverity: String, Sendable, Equatable, Comparable {
    case fatal
    case error
    case warning
    case information

    public static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        let order: [IssueSeverity] = [.information, .warning, .error, .fatal]
        let lhsIndex = order.firstIndex(of: lhs) ?? 0
        let rhsIndex = order.firstIndex(of: rhs) ?? 0
        return lhsIndex < rhsIndex
    }
}

/// Issue type codes (subset of OperationOutcome.issue.code)
public enum IssueType: String, Sendable, Equatable {
    case structure
    case required
    case value
    case invariant
    case processing
    case businessRule = "business-rule"
    case codeInvalid = "code-invalid"
    case notFound = "not-found"
    case tooLong = "too-long"
    case invalid
}

// MARK: - Validation Outcome

/// Result of validating a FHIR resource
public struct FHIRValidationOutcome: Sendable {
    /// All issues found during validation
    public let issues: [FHIRValidationIssue]

    /// Whether validation passed (no errors or fatal issues)
    public var isValid: Bool {
        !issues.contains { $0.severity == .error || $0.severity == .fatal }
    }

    /// Only error and fatal issues
    public var errors: [FHIRValidationIssue] {
        issues.filter { $0.severity == .error || $0.severity == .fatal }
    }

    /// Only warning issues
    public var warnings: [FHIRValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    /// Only informational issues
    public var informational: [FHIRValidationIssue] {
        issues.filter { $0.severity == .information }
    }

    /// Convert to OperationOutcome
    public func toOperationOutcome() -> OperationOutcome {
        let outcomeIssues = issues.map { issue in
            OperationOutcomeIssue(
                severity: issue.severity.rawValue,
                code: issue.code.rawValue,
                details: CodeableConcept(text: issue.details),
                diagnostics: issue.constraintKey,
                expression: issue.expression.map { [$0] }
            )
        }
        return OperationOutcome(
            id: nil,
            meta: nil,
            issue: outcomeIssues.isEmpty
                ? [OperationOutcomeIssue(
                    severity: "information",
                    code: "informational",
                    details: CodeableConcept(text: "Validation passed with no issues")
                )]
                : outcomeIssues
        )
    }

    public init(issues: [FHIRValidationIssue] = []) {
        self.issues = issues
    }
}

// MARK: - Issue Collector

/// Collects validation issues during validation.
///
/// Thread safety: Uses `NSLock` to protect the `_issues` array.
/// Marked `@unchecked Sendable` because `NSLock` does not conform to `Sendable`
/// but provides the required thread-safe synchronization.
public final class ValidationIssueCollector: @unchecked Sendable {
    private var _issues: [FHIRValidationIssue] = []
    private let lock = NSLock()
    private let maxIssues: Int

    public init(maxIssues: Int = 1000) {
        self.maxIssues = maxIssues
    }

    public func add(_ issue: FHIRValidationIssue) {
        lock.lock()
        defer { lock.unlock() }
        guard _issues.count < maxIssues else { return }
        _issues.append(issue)
    }

    public func addError(_ details: String, path: String? = nil, code: IssueType = .invalid) {
        add(FHIRValidationIssue(severity: .error, code: code, details: details, expression: path))
    }

    public func addWarning(_ details: String, path: String? = nil, code: IssueType = .invalid) {
        add(FHIRValidationIssue(severity: .warning, code: code, details: details, expression: path))
    }

    public func addInfo(_ details: String, path: String? = nil, code: IssueType = .invalid) {
        add(FHIRValidationIssue(severity: .information, code: code, details: details, expression: path))
    }

    public var issues: [FHIRValidationIssue] {
        lock.lock()
        defer { lock.unlock() }
        return _issues
    }

    public var hasErrors: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _issues.contains { $0.severity == .error || $0.severity == .fatal }
    }

    public func toOutcome() -> FHIRValidationOutcome {
        FHIRValidationOutcome(issues: issues)
    }
}
