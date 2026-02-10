/// FHIRProfileValidator.swift
/// Profile validation for FHIR resources
///
/// Validates FHIR resources against StructureDefinitions (profiles),
/// including constraint checking, extension validation, fixed/pattern
/// value enforcement, and must-support handling.

import Foundation
import HL7Core

// MARK: - Profile Validator

/// Validates a FHIR resource against a StructureDefinition profile
public struct FHIRProfileValidator: Sendable {
    private let cardinalityValidator: FHIRCardinalityValidator
    private let terminologyValidator: FHIRTerminologyValidator?
    private let pathEvaluator: FHIRPathEvaluator

    public init(terminologyService: FHIRTerminologyService? = nil) {
        self.cardinalityValidator = FHIRCardinalityValidator()
        if let service = terminologyService {
            self.terminologyValidator = FHIRTerminologyValidator(service: service)
        } else {
            self.terminologyValidator = nil
        }
        self.pathEvaluator = FHIRPathEvaluator()
    }

    /// Validate a resource against a profile
    /// - Parameters:
    ///   - resourceData: Resource as a dictionary
    ///   - profile: The StructureDefinition to validate against
    ///   - collector: Issue collector
    public func validate(
        resourceData: [String: Any],
        profile: StructureDefinition,
        collector: ValidationIssueCollector
    ) {
        let resourceType = resourceData["resourceType"] as? String ?? profile.type

        // Validate resource type matches
        if resourceType != profile.type {
            collector.addError(
                "Resource type '\(resourceType)' does not match profile type '\(profile.type)'",
                path: "resourceType",
                code: .structure
            )
            return
        }

        // Validate each element definition
        for element in profile.elements {
            validateElement(
                element: element,
                resourceData: resourceData,
                resourceType: resourceType,
                collector: collector
            )
        }
    }

    // MARK: - Element Validation

    private func validateElement(
        element: ElementDefinition,
        resourceData: [String: Any],
        resourceType: String,
        collector: ValidationIssueCollector
    ) {
        let fieldName = cardinalityValidator.extractFieldName(from: element.path, resourceType: resourceType)

        guard let fieldName else { return }

        let value = resourceData[fieldName]
        let count = cardinalityValidator.elementCount(value)

        // Cardinality validation
        cardinalityValidator.validate(definition: element, count: count, collector: collector)

        // Constraint (invariant) validation — always evaluated regardless of presence
        for constraint in element.constraints {
            validateConstraint(
                constraint: constraint,
                resourceData: resourceData,
                path: element.path,
                collector: collector
            )
        }

        // Must-support informational
        if element.mustSupport && count == 0 {
            collector.addInfo(
                "Must-support element '\(element.path)' is not present",
                path: element.path,
                code: .businessRule
            )
        }

        // Skip value-specific checks if element is not present
        guard count > 0 else { return }

        // Fixed value validation
        if let fixedValue = element.fixedValue {
            validateFixedValue(value: value, expected: fixedValue, path: element.path, collector: collector)
        }

        // Pattern value validation
        if let patternValue = element.patternValue {
            validatePatternValue(value: value, pattern: patternValue, path: element.path, collector: collector)
        }

        // Binding validation
        if let binding = element.binding, let terminologyValidator {
            validateBinding(value: value, binding: binding, path: element.path, collector: collector, terminologyValidator: terminologyValidator)
        }
    }

    // MARK: - Fixed Value Validation

    private func validateFixedValue(
        value: Any?,
        expected: String,
        path: String,
        collector: ValidationIssueCollector
    ) {
        guard let value else { return }
        let actual = String(describing: value)
        if actual != expected {
            collector.addError(
                "Element '\(path)' has fixed value '\(expected)' but found '\(actual)'",
                path: path,
                code: .value
            )
        }
    }

    // MARK: - Pattern Value Validation

    private func validatePatternValue(
        value: Any?,
        pattern: String,
        path: String,
        collector: ValidationIssueCollector
    ) {
        guard let value else { return }
        let actual = String(describing: value)
        if !actual.contains(pattern) {
            collector.addError(
                "Element '\(path)' does not match pattern '\(pattern)'; found '\(actual)'",
                path: path,
                code: .value
            )
        }
    }

    // MARK: - Binding Validation

    private func validateBinding(
        value: Any?,
        binding: ElementBinding,
        path: String,
        collector: ValidationIssueCollector,
        terminologyValidator: FHIRTerminologyValidator
    ) {
        guard let value else { return }

        if let codeStr = value as? String {
            terminologyValidator.validate(
                system: nil,
                code: codeStr,
                binding: binding,
                path: path,
                collector: collector
            )
        }
    }

    // MARK: - Constraint Validation

    private func validateConstraint(
        constraint: ElementConstraint,
        resourceData: [String: Any],
        path: String,
        collector: ValidationIssueCollector
    ) {
        guard let expression = constraint.expression else { return }

        let result = pathEvaluator.evaluateBoolean(expression, resource: resourceData)
        if !result {
            let severity: IssueSeverity = constraint.severity == .error ? .error : .warning
            collector.add(FHIRValidationIssue(
                severity: severity,
                code: .invariant,
                details: "\(constraint.human) (key: \(constraint.key))",
                expression: path,
                constraintKey: constraint.key
            ))
        }
    }
}
