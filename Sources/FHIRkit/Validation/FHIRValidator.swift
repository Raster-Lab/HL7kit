/// FHIRValidator.swift
/// Main FHIR validation engine
///
/// Actor-based validator that orchestrates structural validation, cardinality
/// checking, terminology validation, profile validation, FHIRPath evaluation,
/// and custom validation rules. Returns results as FHIRValidationOutcome
/// (convertible to OperationOutcome).

import Foundation
import HL7Core

// MARK: - FHIR Validator

/// Main entry point for FHIR resource validation
///
/// Thread safety: Uses `NSLock` to protect mutable state (`profiles` array).
/// Marked `@unchecked Sendable` because `NSLock` does not conform to `Sendable`
/// but provides the required thread-safe synchronization.
///
/// Usage:
/// ```swift
/// let validator = FHIRValidator()
/// validator.addProfile(patientProfile)
/// let outcome = validator.validate(patient)
/// if outcome.isValid {
///     print("Resource is valid")
/// }
/// ```
public final class FHIRValidator: @unchecked Sendable {
    private let terminologyService: FHIRTerminologyService
    private let ruleRegistry: FHIRValidationRuleRegistry
    private var profiles: [StructureDefinition] = []
    private let lock = NSLock()

    /// Configuration for the validator
    public let configuration: FHIRValidatorConfiguration

    /// Initialize with optional terminology service and configuration
    public init(
        terminologyService: FHIRTerminologyService? = nil,
        configuration: FHIRValidatorConfiguration = .default
    ) {
        self.terminologyService = terminologyService ?? LocalTerminologyService()
        self.ruleRegistry = FHIRValidationRuleRegistry()
        self.configuration = configuration
    }

    // MARK: - Profile Management

    /// Add a profile for validation
    public func addProfile(_ profile: StructureDefinition) {
        lock.lock()
        defer { lock.unlock() }
        profiles.append(profile)
    }

    /// Remove all profiles
    public func clearProfiles() {
        lock.lock()
        defer { lock.unlock() }
        profiles.removeAll()
    }

    /// Get registered profiles
    public var registeredProfiles: [StructureDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return profiles
    }

    // MARK: - Custom Rules

    /// Register a custom validation rule
    public func addRule(_ rule: FHIRValidationRule) {
        ruleRegistry.register(rule)
    }

    /// Remove a custom rule by ID
    public func removeRule(ruleId: String) {
        ruleRegistry.remove(ruleId: ruleId)
    }

    // MARK: - Validation

    /// Validate a Codable resource
    /// - Parameter resource: The resource to validate
    /// - Returns: Validation outcome with issues
    public func validate<T: Codable & Sendable>(_ resource: T) -> FHIRValidationOutcome {
        let collector = ValidationIssueCollector(maxIssues: configuration.maxIssues)

        // Convert resource to dictionary
        guard let data = try? JSONEncoder().encode(resource),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            collector.addError("Failed to serialize resource for validation", code: .processing)
            return collector.toOutcome()
        }

        return validateDictionary(dict, collector: collector)
    }

    /// Validate a resource from a dictionary
    /// - Parameter resourceData: Resource as a dictionary
    /// - Returns: Validation outcome with issues
    public func validateDictionary(_ resourceData: [String: Any]) -> FHIRValidationOutcome {
        let collector = ValidationIssueCollector(maxIssues: configuration.maxIssues)
        return validateDictionary(resourceData, collector: collector)
    }

    private func validateDictionary(
        _ resourceData: [String: Any],
        collector: ValidationIssueCollector
    ) -> FHIRValidationOutcome {
        let resourceType = resourceData["resourceType"] as? String

        // Structural validation
        if configuration.validateStructure {
            validateStructure(resourceData: resourceData, collector: collector)
        }

        // Profile validation
        if configuration.validateProfiles {
            let currentProfiles: [StructureDefinition]
            lock.lock()
            currentProfiles = profiles
            lock.unlock()

            let profileValidator = FHIRProfileValidator(terminologyService: terminologyService)
            let matchingProfiles = currentProfiles.filter { profile in
                resourceType == nil || profile.type == resourceType
            }
            for profile in matchingProfiles {
                profileValidator.validate(
                    resourceData: resourceData,
                    profile: profile,
                    collector: collector
                )
            }
        }

        // Custom rules validation
        if configuration.validateCustomRules {
            ruleRegistry.validate(resourceData: resourceData, collector: collector)
        }

        return collector.toOutcome()
    }

    // MARK: - Structural Validation

    private func validateStructure(
        resourceData: [String: Any],
        collector: ValidationIssueCollector
    ) {
        // Check resourceType is present
        guard let resourceType = resourceData["resourceType"] as? String else {
            collector.addError(
                "Resource must have a 'resourceType' element",
                path: "resourceType",
                code: .required
            )
            return
        }

        // Check resourceType is not empty
        if resourceType.isEmpty {
            collector.addError(
                "resourceType must not be empty",
                path: "resourceType",
                code: .value
            )
        }

        // Validate known resource types
        let knownTypes: Set<String> = [
            "Patient", "Observation", "Practitioner", "Organization",
            "Condition", "AllergyIntolerance", "Encounter",
            "MedicationRequest", "DiagnosticReport", "Appointment",
            "Schedule", "MedicationStatement", "DocumentReference",
            "Bundle", "OperationOutcome"
        ]

        if configuration.strictResourceTypeChecking && !knownTypes.contains(resourceType) {
            collector.addWarning(
                "Unknown resource type '\(resourceType)'",
                path: "resourceType",
                code: .value
            )
        }

        // Validate required fields based on resource type
        validateRequiredFieldsForType(resourceType, resourceData: resourceData, collector: collector)
    }

    private func validateRequiredFieldsForType(
        _ resourceType: String,
        resourceData: [String: Any],
        collector: ValidationIssueCollector
    ) {
        let requiredFields: [String]

        switch resourceType {
        case "Patient":
            requiredFields = []  // Patient has no strictly required fields beyond resourceType
        case "Observation":
            requiredFields = ["status", "code"]
        case "Encounter":
            requiredFields = ["status", "class"]
        case "MedicationRequest":
            requiredFields = ["status", "intent", "medication"]
        case "DiagnosticReport":
            requiredFields = ["status", "code"]
        case "Appointment":
            requiredFields = ["status", "participant"]
        case "Schedule":
            requiredFields = ["actor"]
        case "MedicationStatement":
            requiredFields = ["status", "medication"]
        case "DocumentReference":
            requiredFields = ["status", "content"]
        case "Bundle":
            requiredFields = ["type"]
        case "OperationOutcome":
            requiredFields = ["issue"]
        case "Condition":
            requiredFields = ["subject"]
        case "AllergyIntolerance":
            requiredFields = ["patient"]
        default:
            requiredFields = []
        }

        for field in requiredFields {
            let value = resourceData[field]
            if value == nil || (value is NSNull) {
                collector.addError(
                    "Required element '\(field)' is missing in \(resourceType)",
                    path: "\(resourceType).\(field)",
                    code: .required
                )
            } else if let arr = value as? [Any], arr.isEmpty {
                collector.addError(
                    "Required element '\(field)' is present but empty in \(resourceType)",
                    path: "\(resourceType).\(field)",
                    code: .required
                )
            }
        }
    }
}

// MARK: - Validator Configuration

/// Configuration options for the FHIR validator
public struct FHIRValidatorConfiguration: Sendable {
    /// Whether to validate structural requirements
    public let validateStructure: Bool

    /// Whether to validate against registered profiles
    public let validateProfiles: Bool

    /// Whether to run custom validation rules
    public let validateCustomRules: Bool

    /// Whether to strictly check resource types against known types
    public let strictResourceTypeChecking: Bool

    /// Maximum number of issues to collect
    public let maxIssues: Int

    public init(
        validateStructure: Bool = true,
        validateProfiles: Bool = true,
        validateCustomRules: Bool = true,
        strictResourceTypeChecking: Bool = false,
        maxIssues: Int = 1000
    ) {
        self.validateStructure = validateStructure
        self.validateProfiles = validateProfiles
        self.validateCustomRules = validateCustomRules
        self.strictResourceTypeChecking = strictResourceTypeChecking
        self.maxIssues = maxIssues
    }

    /// Default configuration
    public static let `default` = FHIRValidatorConfiguration()

    /// Strict configuration
    public static let strict = FHIRValidatorConfiguration(
        strictResourceTypeChecking: true
    )
}

// MARK: - Standard Profiles

/// Pre-built standard profiles for common resource types
public enum StandardProfiles {

    /// Basic Patient profile
    public static let patient = StructureDefinition(
        url: "http://hl7.org/fhir/StructureDefinition/Patient",
        name: "Patient",
        title: "Patient",
        status: .active,
        kind: .resource,
        type: "Patient",
        elements: [
            ElementDefinition(
                path: "Patient.identifier",
                min: 0,
                max: "*",
                short: "Patient identifiers",
                types: [ElementType(code: "Identifier")]
            ),
            ElementDefinition(
                path: "Patient.active",
                min: 0,
                max: "1",
                short: "Whether this patient's record is active",
                types: [ElementType(code: "boolean")]
            ),
            ElementDefinition(
                path: "Patient.name",
                min: 0,
                max: "*",
                short: "A name associated with the patient",
                types: [ElementType(code: "HumanName")]
            ),
            ElementDefinition(
                path: "Patient.gender",
                min: 0,
                max: "1",
                short: "male | female | other | unknown",
                types: [ElementType(code: "code")],
                binding: ElementBinding(
                    strength: .required,
                    valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
                )
            ),
            ElementDefinition(
                path: "Patient.birthDate",
                min: 0,
                max: "1",
                short: "Date of birth",
                types: [ElementType(code: "date")]
            )
        ]
    )

    /// Basic Observation profile
    public static let observation = StructureDefinition(
        url: "http://hl7.org/fhir/StructureDefinition/Observation",
        name: "Observation",
        title: "Observation",
        status: .active,
        kind: .resource,
        type: "Observation",
        elements: [
            ElementDefinition(
                path: "Observation.status",
                min: 1,
                max: "1",
                short: "registered | preliminary | final | amended +",
                types: [ElementType(code: "code")],
                binding: ElementBinding(
                    strength: .required,
                    valueSetUri: "http://hl7.org/fhir/ValueSet/observation-status"
                )
            ),
            ElementDefinition(
                path: "Observation.code",
                min: 1,
                max: "1",
                short: "Type of observation",
                types: [ElementType(code: "CodeableConcept")]
            ),
            ElementDefinition(
                path: "Observation.subject",
                min: 0,
                max: "1",
                short: "Who the observation is about",
                types: [ElementType(code: "Reference", targetProfiles: ["http://hl7.org/fhir/StructureDefinition/Patient"])]
            ),
            ElementDefinition(
                path: "Observation.effective",
                min: 0,
                max: "1",
                short: "Clinically relevant time",
                types: [
                    ElementType(code: "dateTime"),
                    ElementType(code: "Period")
                ]
            )
        ]
    )

    /// US Core Patient profile (simplified)
    public static let usCorePatient = StructureDefinition(
        url: "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient",
        name: "USCorePatientProfile",
        title: "US Core Patient Profile",
        status: .active,
        kind: .resource,
        baseDefinition: "http://hl7.org/fhir/StructureDefinition/Patient",
        type: "Patient",
        elements: [
            ElementDefinition(
                path: "Patient.identifier",
                min: 1,
                max: "*",
                short: "At least one identifier required",
                types: [ElementType(code: "Identifier")],
                mustSupport: true
            ),
            ElementDefinition(
                path: "Patient.name",
                min: 1,
                max: "*",
                short: "At least one name required",
                types: [ElementType(code: "HumanName")],
                mustSupport: true
            ),
            ElementDefinition(
                path: "Patient.gender",
                min: 1,
                max: "1",
                short: "Gender is required",
                types: [ElementType(code: "code")],
                mustSupport: true,
                binding: ElementBinding(
                    strength: .required,
                    valueSetUri: "http://hl7.org/fhir/ValueSet/administrative-gender"
                )
            )
        ]
    )
}
