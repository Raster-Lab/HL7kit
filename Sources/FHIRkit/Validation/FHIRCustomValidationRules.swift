/// FHIRCustomValidationRules.swift
/// Custom validation rules support for FHIR resources
///
/// Provides a protocol and implementations for custom validation rules
/// that can be composed and registered with the FHIRValidator.

import Foundation
import HL7Core

// MARK: - Custom Validation Rule Protocol

/// Protocol for custom FHIR validation rules
public protocol FHIRValidationRule: Sendable {
    /// Unique identifier for this rule
    var ruleId: String { get }

    /// Human-readable description
    var description: String { get }

    /// Resource types this rule applies to (empty means all)
    var applicableResourceTypes: Set<String> { get }

    /// Validate a resource
    /// - Parameters:
    ///   - resourceData: Resource as a dictionary
    ///   - collector: Issue collector for reporting issues
    func validate(resourceData: [String: Any], collector: ValidationIssueCollector)
}

// MARK: - Required Fields Rule

/// Validates that specified fields are present in a resource
public struct RequiredFieldsRule: FHIRValidationRule {
    public let ruleId: String
    public let description: String
    public let applicableResourceTypes: Set<String>
    public let requiredFields: [String]

    public init(
        ruleId: String = "required-fields",
        description: String = "Required fields validation",
        resourceTypes: Set<String> = [],
        requiredFields: [String]
    ) {
        self.ruleId = ruleId
        self.description = description
        self.applicableResourceTypes = resourceTypes
        self.requiredFields = requiredFields
    }

    public func validate(resourceData: [String: Any], collector: ValidationIssueCollector) {
        let resourceType = resourceData["resourceType"] as? String ?? "Unknown"

        if !applicableResourceTypes.isEmpty && !applicableResourceTypes.contains(resourceType) {
            return
        }

        for field in requiredFields {
            if resourceData[field] == nil {
                collector.addError(
                    "Required field '\(field)' is missing in \(resourceType)",
                    path: "\(resourceType).\(field)",
                    code: .required
                )
            }
        }
    }
}

// MARK: - Co-occurrence Rule

/// Validates that if one field is present, another must also be present
public struct CoOccurrenceRule: FHIRValidationRule {
    public let ruleId: String
    public let description: String
    public let applicableResourceTypes: Set<String>

    /// If this field is present...
    public let ifField: String
    /// ...then this field must also be present
    public let thenField: String

    public init(
        ruleId: String,
        description: String = "Co-occurrence validation",
        resourceTypes: Set<String> = [],
        ifField: String,
        thenField: String
    ) {
        self.ruleId = ruleId
        self.description = description
        self.applicableResourceTypes = resourceTypes
        self.ifField = ifField
        self.thenField = thenField
    }

    public func validate(resourceData: [String: Any], collector: ValidationIssueCollector) {
        let resourceType = resourceData["resourceType"] as? String ?? "Unknown"

        if !applicableResourceTypes.isEmpty && !applicableResourceTypes.contains(resourceType) {
            return
        }

        if resourceData[ifField] != nil && resourceData[thenField] == nil {
            collector.addError(
                "When '\(ifField)' is present, '\(thenField)' must also be present in \(resourceType)",
                path: "\(resourceType).\(thenField)",
                code: .businessRule
            )
        }
    }
}

// MARK: - Value Constraint Rule

/// Validates that a field's value matches a specific set of allowed values
public struct ValueConstraintRule: FHIRValidationRule {
    public let ruleId: String
    public let description: String
    public let applicableResourceTypes: Set<String>

    /// Field to check
    public let field: String
    /// Allowed values
    public let allowedValues: Set<String>

    public init(
        ruleId: String,
        description: String = "Value constraint validation",
        resourceTypes: Set<String> = [],
        field: String,
        allowedValues: Set<String>
    ) {
        self.ruleId = ruleId
        self.description = description
        self.applicableResourceTypes = resourceTypes
        self.field = field
        self.allowedValues = allowedValues
    }

    public func validate(resourceData: [String: Any], collector: ValidationIssueCollector) {
        let resourceType = resourceData["resourceType"] as? String ?? "Unknown"

        if !applicableResourceTypes.isEmpty && !applicableResourceTypes.contains(resourceType) {
            return
        }

        guard let value = resourceData[field] as? String else { return }

        if !allowedValues.contains(value) {
            collector.addError(
                "Field '\(field)' has value '\(value)' which is not in the allowed set: \(allowedValues.sorted().joined(separator: ", "))",
                path: "\(resourceType).\(field)",
                code: .codeInvalid
            )
        }
    }
}

// MARK: - Closure-Based Rule

/// A validation rule defined by a closure
public struct ClosureValidationRule: FHIRValidationRule {
    public let ruleId: String
    public let description: String
    public let applicableResourceTypes: Set<String>
    private let _validate: @Sendable ([String: Any], ValidationIssueCollector) -> Void

    public init(
        ruleId: String,
        description: String = "Custom validation",
        resourceTypes: Set<String> = [],
        validate: @escaping @Sendable ([String: Any], ValidationIssueCollector) -> Void
    ) {
        self.ruleId = ruleId
        self.description = description
        self.applicableResourceTypes = resourceTypes
        self._validate = validate
    }

    public func validate(resourceData: [String: Any], collector: ValidationIssueCollector) {
        let resourceType = resourceData["resourceType"] as? String ?? "Unknown"

        if !applicableResourceTypes.isEmpty && !applicableResourceTypes.contains(resourceType) {
            return
        }

        _validate(resourceData, collector)
    }
}

// MARK: - Validation Rule Registry

/// Registry for managing custom validation rules
public final class FHIRValidationRuleRegistry: @unchecked Sendable {
    private var rules: [FHIRValidationRule] = []
    private let lock = NSLock()

    public init() {}

    /// Register a custom validation rule
    public func register(_ rule: FHIRValidationRule) {
        lock.lock()
        defer { lock.unlock() }
        rules.append(rule)
    }

    /// Remove a rule by ID
    public func remove(ruleId: String) {
        lock.lock()
        defer { lock.unlock() }
        rules.removeAll { $0.ruleId == ruleId }
    }

    /// Get all registered rules
    public var allRules: [FHIRValidationRule] {
        lock.lock()
        defer { lock.unlock() }
        return rules
    }

    /// Get rules applicable to a specific resource type
    public func rules(for resourceType: String) -> [FHIRValidationRule] {
        lock.lock()
        defer { lock.unlock() }
        return rules.filter {
            $0.applicableResourceTypes.isEmpty || $0.applicableResourceTypes.contains(resourceType)
        }
    }

    /// Validate a resource against all applicable rules
    public func validate(resourceData: [String: Any], collector: ValidationIssueCollector) {
        let resourceType = resourceData["resourceType"] as? String ?? "Unknown"
        let applicableRules = rules(for: resourceType)
        for rule in applicableRules {
            rule.validate(resourceData: resourceData, collector: collector)
        }
    }
}
