/// FHIRCardinalityValidator.swift
/// Cardinality and required field validation for FHIR resources
///
/// Validates element cardinality constraints (min..max), required fields,
/// and prohibited elements based on StructureDefinition element definitions.

import Foundation
import HL7Core

// MARK: - Cardinality Validator

/// Validates cardinality constraints on FHIR resource elements
public struct FHIRCardinalityValidator: Sendable {

    public init() {}

    /// Validate cardinality for a single element
    /// - Parameters:
    ///   - definition: The element definition with cardinality constraints
    ///   - count: The actual count of occurrences
    ///   - collector: Issue collector
    public func validate(
        definition: ElementDefinition,
        count: Int,
        collector: ValidationIssueCollector
    ) {
        let path = definition.path

        // Check prohibited elements (max == "0")
        if definition.isProhibited {
            if count > 0 {
                collector.addError(
                    "Element '\(path)' is prohibited but found \(count) occurrence(s)",
                    path: path,
                    code: .structure
                )
            }
            return
        }

        // Check minimum cardinality
        if count < definition.min {
            collector.addError(
                "Element '\(path)' requires minimum \(definition.min) but found \(count)",
                path: path,
                code: .required
            )
        }

        // Check maximum cardinality
        if let maxVal = definition.maxInt, count > maxVal {
            collector.addError(
                "Element '\(path)' allows maximum \(maxVal) but found \(count)",
                path: path,
                code: .structure
            )
        }
    }

    /// Validate required fields in a resource dictionary
    /// - Parameters:
    ///   - elements: Element definitions to check
    ///   - resourceData: Dictionary representation of the resource
    ///   - collector: Issue collector
    public func validateRequiredFields(
        elements: [ElementDefinition],
        resourceData: [String: Any],
        resourceType: String,
        collector: ValidationIssueCollector
    ) {
        for element in elements {
            let fieldName = extractFieldName(from: element.path, resourceType: resourceType)
            guard let fieldName else { continue }

            let value = resourceData[fieldName]
            let count = elementCount(value)

            validate(definition: element, count: count, collector: collector)
        }
    }

    // MARK: - Helpers

    /// Extract the field name from an element path relative to the resource type
    func extractFieldName(from path: String, resourceType: String) -> String? {
        let prefix = "\(resourceType)."
        guard path.hasPrefix(prefix) else { return nil }
        let fieldPath = String(path.dropFirst(prefix.count))
        // Only consider top-level fields (no dots)
        if fieldPath.contains(".") { return nil }
        return fieldPath
    }

    /// Count the number of elements in a value
    func elementCount(_ value: Any?) -> Int {
        guard let value else { return 0 }
        if let array = value as? [Any] {
            return array.count
        }
        // Check for NSNull or nil-like values
        if value is NSNull {
            return 0
        }
        return 1
    }
}
