/// FHIRTerminologyValidator.swift
/// Value set and code system validation for FHIR resources
///
/// Validates coded elements against code systems and value sets,
/// with support for binding strength enforcement (required, extensible,
/// preferred, example).

import Foundation
import HL7Core

// MARK: - Code System

/// A FHIR code system definition for validation
public struct FHIRCodeSystemDefinition: Sendable {
    /// Canonical URL of the code system
    public let url: String

    /// Name of the code system
    public let name: String

    /// Valid codes in this code system
    public let codes: Set<String>

    /// Whether the code system is case-sensitive
    public let caseSensitive: Bool

    public init(
        url: String,
        name: String,
        codes: Set<String>,
        caseSensitive: Bool = true
    ) {
        self.url = url
        self.name = name
        self.codes = codes
        self.caseSensitive = caseSensitive
    }

    /// Check if a code is valid in this code system
    public func contains(_ code: String) -> Bool {
        if caseSensitive {
            return codes.contains(code)
        }
        return codes.contains { $0.lowercased() == code.lowercased() }
    }
}

// MARK: - Value Set

/// A FHIR value set definition for validation
public struct FHIRValueSetDefinition: Sendable {
    /// Canonical URL of the value set
    public let url: String

    /// Name of the value set
    public let name: String

    /// Included codes, keyed by system URL
    public let includes: [String: Set<String>]

    public init(
        url: String,
        name: String,
        includes: [String: Set<String>]
    ) {
        self.url = url
        self.name = name
        self.includes = includes
    }

    /// Check if a code from a system is valid in this value set
    public func contains(system: String, code: String) -> Bool {
        guard let codes = includes[system] else { return false }
        return codes.contains(code)
    }

    /// Check if a code is valid in any system in this value set
    public func containsCode(_ code: String) -> Bool {
        includes.values.contains { $0.contains(code) }
    }
}

// MARK: - Terminology Service

/// Protocol for terminology validation services
public protocol FHIRTerminologyService: Sendable {
    /// Look up a code system by URL
    func codeSystem(for url: String) -> FHIRCodeSystemDefinition?

    /// Look up a value set by URL
    func valueSet(for url: String) -> FHIRValueSetDefinition?

    /// Validate a code against a value set
    func validateCode(system: String?, code: String, valueSetUrl: String) -> Bool
}

// MARK: - Local Terminology Service

/// In-memory terminology service with registered code systems and value sets
public final class LocalTerminologyService: FHIRTerminologyService, @unchecked Sendable {
    private var codeSystems: [String: FHIRCodeSystemDefinition] = [:]
    private var valueSets: [String: FHIRValueSetDefinition] = [:]
    private let lock = NSLock()

    public init() {
        registerStandardValueSets()
    }

    /// Register a code system
    public func register(_ codeSystem: FHIRCodeSystemDefinition) {
        lock.lock()
        defer { lock.unlock() }
        codeSystems[codeSystem.url] = codeSystem
    }

    /// Register a value set
    public func register(_ valueSet: FHIRValueSetDefinition) {
        lock.lock()
        defer { lock.unlock() }
        valueSets[valueSet.url] = valueSet
    }

    public func codeSystem(for url: String) -> FHIRCodeSystemDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return codeSystems[url]
    }

    public func valueSet(for url: String) -> FHIRValueSetDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return valueSets[url]
    }

    public func validateCode(system: String?, code: String, valueSetUrl: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let vs = valueSets[valueSetUrl] else { return true }
        if let system {
            return vs.contains(system: system, code: code)
        }
        return vs.containsCode(code)
    }

    // MARK: - Standard Value Sets

    private func registerStandardValueSets() {
        // AdministrativeGender
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/administrative-gender",
            name: "AdministrativeGender",
            includes: [
                "http://hl7.org/fhir/administrative-gender": ["male", "female", "other", "unknown"]
            ]
        ))

        // Observation Status
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/observation-status",
            name: "ObservationStatus",
            includes: [
                "http://hl7.org/fhir/observation-status": [
                    "registered", "preliminary", "final", "amended",
                    "corrected", "cancelled", "entered-in-error", "unknown"
                ]
            ]
        ))

        // Encounter Status
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/encounter-status",
            name: "EncounterStatus",
            includes: [
                "http://hl7.org/fhir/encounter-status": [
                    "planned", "arrived", "triaged", "in-progress",
                    "onleave", "finished", "cancelled", "entered-in-error",
                    "unknown"
                ]
            ]
        ))

        // Medication Request Status
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/medicationrequest-status",
            name: "MedicationRequestStatus",
            includes: [
                "http://hl7.org/fhir/CodeSystem/medicationrequest-status": [
                    "active", "on-hold", "cancelled", "completed",
                    "entered-in-error", "stopped", "draft", "unknown"
                ]
            ]
        ))

        // Medication Request Intent
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/medicationrequest-intent",
            name: "MedicationRequestIntent",
            includes: [
                "http://hl7.org/fhir/CodeSystem/medicationrequest-intent": [
                    "proposal", "plan", "order", "original-order",
                    "reflex-order", "filler-order", "instance-order", "option"
                ]
            ]
        ))

        // Identifier Use
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/identifier-use",
            name: "IdentifierUse",
            includes: [
                "http://hl7.org/fhir/identifier-use": [
                    "usual", "official", "temp", "secondary", "old"
                ]
            ]
        ))

        // Contact Point System
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/contact-point-system",
            name: "ContactPointSystem",
            includes: [
                "http://hl7.org/fhir/contact-point-system": [
                    "phone", "fax", "email", "pager", "url", "sms", "other"
                ]
            ]
        ))

        // Narrative Status
        register(FHIRValueSetDefinition(
            url: "http://hl7.org/fhir/ValueSet/narrative-status",
            name: "NarrativeStatus",
            includes: [
                "http://hl7.org/fhir/narrative-status": [
                    "generated", "extensions", "additional", "empty"
                ]
            ]
        ))
    }
}

// MARK: - Terminology Validator

/// Validates coded elements against terminology services
public struct FHIRTerminologyValidator: Sendable {
    private let service: FHIRTerminologyService

    public init(service: FHIRTerminologyService) {
        self.service = service
    }

    /// Validate a code against a binding
    /// - Parameters:
    ///   - system: The code system URL
    ///   - code: The code value
    ///   - binding: The element binding
    ///   - path: Element path for diagnostics
    ///   - collector: Issue collector
    public func validate(
        system: String?,
        code: String,
        binding: ElementBinding,
        path: String,
        collector: ValidationIssueCollector
    ) {
        let isValid = service.validateCode(
            system: system,
            code: code,
            valueSetUrl: binding.valueSetUri
        )

        if !isValid {
            switch binding.strength {
            case .required:
                collector.addError(
                    "Code '\(code)' is not valid in required value set '\(binding.valueSetUri)'",
                    path: path,
                    code: .codeInvalid
                )
            case .extensible:
                collector.addWarning(
                    "Code '\(code)' is not from extensible value set '\(binding.valueSetUri)'",
                    path: path,
                    code: .codeInvalid
                )
            case .preferred:
                collector.addInfo(
                    "Code '\(code)' is not from preferred value set '\(binding.valueSetUri)'",
                    path: path,
                    code: .codeInvalid
                )
            case .example:
                // No validation for example bindings
                break
            }
        }
    }

    /// Validate a Coding against a binding
    public func validateCoding(
        _ coding: Coding,
        binding: ElementBinding,
        path: String,
        collector: ValidationIssueCollector
    ) {
        guard let code = coding.code else { return }
        validate(
            system: coding.system,
            code: code,
            binding: binding,
            path: path,
            collector: collector
        )
    }

    /// Validate a CodeableConcept against a binding
    public func validateCodeableConcept(
        _ concept: CodeableConcept,
        binding: ElementBinding,
        path: String,
        collector: ValidationIssueCollector
    ) {
        guard let codings = concept.coding, !codings.isEmpty else {
            if binding.strength == .required {
                collector.addError(
                    "Required coded element '\(path)' has no coding",
                    path: path,
                    code: .required
                )
            }
            return
        }

        // For required binding, at least one coding must match
        var anyValid = false
        for coding in codings {
            guard let code = coding.code else { continue }
            let isValid = service.validateCode(
                system: coding.system,
                code: code,
                valueSetUrl: binding.valueSetUri
            )
            if isValid {
                anyValid = true
                break
            }
        }

        if !anyValid {
            switch binding.strength {
            case .required:
                collector.addError(
                    "None of the codes in '\(path)' are from required value set '\(binding.valueSetUri)'",
                    path: path,
                    code: .codeInvalid
                )
            case .extensible:
                collector.addWarning(
                    "None of the codes in '\(path)' are from extensible value set '\(binding.valueSetUri)'",
                    path: path,
                    code: .codeInvalid
                )
            case .preferred:
                collector.addInfo(
                    "None of the codes in '\(path)' are from preferred value set '\(binding.valueSetUri)'",
                    path: path,
                    code: .codeInvalid
                )
            case .example:
                break
            }
        }
    }
}
