/// VocabularyServices.swift
/// Comprehensive vocabulary services framework for HL7 v3.x
///
/// This module provides:
/// - Code system support and management
/// - Value set handling with expansion and validation
/// - Concept lookup API with caching
/// - Integration points for SNOMED CT, LOINC, ICD, and other terminologies

import Foundation
import HL7Core

// MARK: - Code System Protocol

/// Protocol defining a code system
public protocol CodeSystemProtocol: Sendable {
    /// Unique identifier (typically an OID or URI)
    var identifier: String { get }
    
    /// Human-readable name
    var name: String { get }
    
    /// Version of the code system
    var version: String? { get }
    
    /// Description of the code system
    var description: String? { get }
    
    /// Publisher of the code system
    var publisher: String? { get }
    
    /// Lookup a concept by code
    /// - Parameter code: The code to lookup
    /// - Returns: The concept if found
    func lookupConcept(code: String) async throws -> Concept?
    
    /// Validate that a code exists in this code system
    /// - Parameter code: The code to validate
    /// - Returns: True if the code is valid
    func validateCode(_ code: String) async throws -> Bool
}

// MARK: - Concept

/// Represents a concept from a code system
public struct Concept: Sendable, Codable, Equatable {
    /// The code
    public let code: String
    
    /// Display name
    public let display: String
    
    /// Definition of the concept
    public let definition: String?
    
    /// Code system this concept belongs to
    public let codeSystem: String
    
    /// Version of the code system
    public let codeSystemVersion: String?
    
    /// Additional properties
    public let properties: [String: String]?
    
    /// Hierarchical parent concepts
    public let parents: [String]?
    
    /// Hierarchical child concepts
    public let children: [String]?
    
    public init(
        code: String,
        display: String,
        definition: String? = nil,
        codeSystem: String,
        codeSystemVersion: String? = nil,
        properties: [String: String]? = nil,
        parents: [String]? = nil,
        children: [String]? = nil
    ) {
        self.code = code
        self.display = display
        self.definition = definition
        self.codeSystem = codeSystem
        self.codeSystemVersion = codeSystemVersion
        self.properties = properties
        self.parents = parents
        self.children = children
    }
}

// MARK: - Value Set Protocol

/// Protocol defining a value set
public protocol ValueSetProtocol: Sendable {
    /// Unique identifier (typically an OID or URI)
    var identifier: String { get }
    
    /// Human-readable name
    var name: String { get }
    
    /// Version of the value set
    var version: String? { get }
    
    /// Description of the value set
    var description: String? { get }
    
    /// Publisher of the value set
    var publisher: String? { get }
    
    /// Expansion status
    var isExpanded: Bool { get }
    
    /// Expand the value set to get all concepts
    /// - Returns: Array of concepts in this value set
    func expand() async throws -> [Concept]
    
    /// Check if a code is in this value set
    /// - Parameters:
    ///   - code: The code to check
    ///   - codeSystem: The code system of the code
    /// - Returns: True if the code is in the value set
    func contains(code: String, codeSystem: String) async throws -> Bool
    
    /// Validate a coded value against this value set
    /// - Parameter codedValue: The coded value to validate
    /// - Returns: Validation result
    func validate(codedValue: CD) async throws -> ValueSetValidationResult
}

// MARK: - Value Set Validation Result

/// Result of value set validation
public struct ValueSetValidationResult: Sendable, Equatable {
    /// Whether the code is valid
    public let isValid: Bool
    
    /// The validated concept if found
    public let concept: Concept?
    
    /// Error message if validation failed
    public let message: String?
    
    public init(isValid: Bool, concept: Concept? = nil, message: String? = nil) {
        self.isValid = isValid
        self.concept = concept
        self.message = message
    }
}

// MARK: - Code System Implementation

/// Basic code system implementation
public struct BasicCodeSystem: CodeSystemProtocol, Sendable {
    public let identifier: String
    public let name: String
    public let version: String?
    public let description: String?
    public let publisher: String?
    
    private let concepts: [String: Concept]
    
    public init(
        identifier: String,
        name: String,
        version: String? = nil,
        description: String? = nil,
        publisher: String? = nil,
        concepts: [Concept] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.publisher = publisher
        
        // Build lookup dictionary
        var conceptMap = [String: Concept]()
        for concept in concepts {
            conceptMap[concept.code] = concept
        }
        self.concepts = conceptMap
    }
    
    public func lookupConcept(code: String) async throws -> Concept? {
        return concepts[code]
    }
    
    public func validateCode(_ code: String) async throws -> Bool {
        return concepts[code] != nil
    }
}

// MARK: - Value Set Implementation

/// Basic value set implementation
public struct BasicValueSet: ValueSetProtocol, Sendable {
    public let identifier: String
    public let name: String
    public let version: String?
    public let description: String?
    public let publisher: String?
    public let isExpanded: Bool
    
    private let concepts: [Concept]
    private let conceptLookup: [ConceptKey: Concept]
    
    private struct ConceptKey: Hashable, Sendable {
        let code: String
        let codeSystem: String
    }
    
    public init(
        identifier: String,
        name: String,
        version: String? = nil,
        description: String? = nil,
        publisher: String? = nil,
        concepts: [Concept] = []
    ) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.description = description
        self.publisher = publisher
        self.isExpanded = !concepts.isEmpty
        self.concepts = concepts
        
        // Build lookup dictionary
        var lookup = [ConceptKey: Concept]()
        for concept in concepts {
            let key = ConceptKey(code: concept.code, codeSystem: concept.codeSystem)
            lookup[key] = concept
        }
        self.conceptLookup = lookup
    }
    
    public func expand() async throws -> [Concept] {
        return concepts
    }
    
    public func contains(code: String, codeSystem: String) async throws -> Bool {
        let key = ConceptKey(code: code, codeSystem: codeSystem)
        return conceptLookup[key] != nil
    }
    
    public func validate(codedValue: CD) async throws -> ValueSetValidationResult {
        guard let code = codedValue.code, let codeSystem = codedValue.codeSystem else {
            return ValueSetValidationResult(
                isValid: false,
                message: "Code and code system are required"
            )
        }
        
        let key = ConceptKey(code: code, codeSystem: codeSystem)
        if let concept = conceptLookup[key] {
            return ValueSetValidationResult(isValid: true, concept: concept)
        } else {
            return ValueSetValidationResult(
                isValid: false,
                message: "Code '\(code)' not found in value set '\(name)'"
            )
        }
    }
}

// MARK: - Vocabulary Service

/// Main vocabulary service for managing code systems and value sets
public actor VocabularyService {
    private var codeSystems: [String: any CodeSystemProtocol]
    private var valueSets: [String: any ValueSetProtocol]
    private var conceptCache: [String: Concept]
    private let maxCacheSize: Int
    
    public init(maxCacheSize: Int = 10000) {
        self.codeSystems = [:]
        self.valueSets = [:]
        self.conceptCache = [:]
        self.maxCacheSize = maxCacheSize
    }
    
    // MARK: - Code System Management
    
    /// Register a code system
    public func registerCodeSystem(_ codeSystem: any CodeSystemProtocol) {
        codeSystems[codeSystem.identifier] = codeSystem
    }
    
    /// Get a registered code system
    public func getCodeSystem(identifier: String) -> (any CodeSystemProtocol)? {
        return codeSystems[identifier]
    }
    
    /// Lookup a concept with caching
    public func lookupConcept(code: String, codeSystem: String) async throws -> Concept? {
        let cacheKey = "\(codeSystem):\(code)"
        
        // Check cache first
        if let cached = conceptCache[cacheKey] {
            return cached
        }
        
        // Lookup in code system
        guard let cs = codeSystems[codeSystem] else {
            throw VocabularyError.codeSystemNotFound(codeSystem)
        }
        
        guard let concept = try await cs.lookupConcept(code: code) else {
            return nil
        }
        
        // Cache the result
        if conceptCache.count >= maxCacheSize {
            // Simple cache eviction: remove oldest entries
            let keysToRemove = Array(conceptCache.keys.prefix(maxCacheSize / 10))
            for key in keysToRemove {
                conceptCache.removeValue(forKey: key)
            }
        }
        conceptCache[cacheKey] = concept
        
        return concept
    }
    
    /// Validate a code in a code system
    public func validateCode(_ code: String, codeSystem: String) async throws -> Bool {
        guard let cs = codeSystems[codeSystem] else {
            throw VocabularyError.codeSystemNotFound(codeSystem)
        }
        
        return try await cs.validateCode(code)
    }
    
    // MARK: - Value Set Management
    
    /// Register a value set
    public func registerValueSet(_ valueSet: any ValueSetProtocol) {
        valueSets[valueSet.identifier] = valueSet
    }
    
    /// Get a registered value set
    public func getValueSet(identifier: String) -> (any ValueSetProtocol)? {
        return valueSets[identifier]
    }
    
    /// Validate a coded value against a value set
    public func validateAgainstValueSet(codedValue: CD, valueSet: String) async throws -> ValueSetValidationResult {
        guard let vs = valueSets[valueSet] else {
            throw VocabularyError.valueSetNotFound(valueSet)
        }
        
        return try await vs.validate(codedValue: codedValue)
    }
    
    /// Check if a code is in a value set
    public func isInValueSet(code: String, codeSystem: String, valueSet: String) async throws -> Bool {
        guard let vs = valueSets[valueSet] else {
            throw VocabularyError.valueSetNotFound(valueSet)
        }
        
        return try await vs.contains(code: code, codeSystem: codeSystem)
    }
    
    // MARK: - Cache Management
    
    /// Clear the concept cache
    public func clearCache() {
        conceptCache.removeAll()
    }
    
    /// Get cache statistics
    public func getCacheStats() -> (size: Int, maxSize: Int) {
        return (conceptCache.count, maxCacheSize)
    }
}

// MARK: - Vocabulary Errors

/// Errors that can occur in vocabulary services
public enum VocabularyError: Error, Sendable {
    case codeSystemNotFound(String)
    case valueSetNotFound(String)
    case conceptNotFound(String, String)
    case invalidCode(String)
    case expansionFailed(String)
    case validationFailed(String)
    
    public var localizedDescription: String {
        switch self {
        case .codeSystemNotFound(let identifier):
            return "Code system not found: \(identifier)"
        case .valueSetNotFound(let identifier):
            return "Value set not found: \(identifier)"
        case .conceptNotFound(let code, let codeSystem):
            return "Concept not found: \(code) in \(codeSystem)"
        case .invalidCode(let message):
            return "Invalid code: \(message)"
        case .expansionFailed(let message):
            return "Value set expansion failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}

// MARK: - External Terminology Integration Points

/// Protocol for integrating with external terminology services
public protocol ExternalTerminologyService: Sendable {
    /// Name of the terminology service
    var serviceName: String { get }
    
    /// Lookup a concept from the external service
    func lookupConcept(code: String, codeSystem: String) async throws -> Concept?
    
    /// Validate a code against the external service
    func validateCode(_ code: String, codeSystem: String) async throws -> Bool
    
    /// Expand a value set using the external service
    func expandValueSet(identifier: String) async throws -> [Concept]
}

/// SNOMED CT integration point (stub for future implementation)
public struct SNOMEDCTService: ExternalTerminologyService {
    public let serviceName = "SNOMED CT"
    private let baseURL: String?
    
    public init(baseURL: String? = nil) {
        self.baseURL = baseURL
    }
    
    public func lookupConcept(code: String, codeSystem: String) async throws -> Concept? {
        // Stub: In production, this would connect to a SNOMED CT terminology server
        throw VocabularyError.expansionFailed("SNOMED CT service not yet implemented")
    }
    
    public func validateCode(_ code: String, codeSystem: String) async throws -> Bool {
        // Stub: In production, this would connect to a SNOMED CT terminology server
        throw VocabularyError.validationFailed("SNOMED CT service not yet implemented")
    }
    
    public func expandValueSet(identifier: String) async throws -> [Concept] {
        // Stub: In production, this would connect to a SNOMED CT terminology server
        throw VocabularyError.expansionFailed("SNOMED CT service not yet implemented")
    }
}

/// LOINC integration point (stub for future implementation)
public struct LOINCService: ExternalTerminologyService {
    public let serviceName = "LOINC"
    private let baseURL: String?
    
    public init(baseURL: String? = nil) {
        self.baseURL = baseURL
    }
    
    public func lookupConcept(code: String, codeSystem: String) async throws -> Concept? {
        // Stub: In production, this would connect to a LOINC terminology server
        throw VocabularyError.expansionFailed("LOINC service not yet implemented")
    }
    
    public func validateCode(_ code: String, codeSystem: String) async throws -> Bool {
        // Stub: In production, this would connect to a LOINC terminology server
        throw VocabularyError.validationFailed("LOINC service not yet implemented")
    }
    
    public func expandValueSet(identifier: String) async throws -> [Concept] {
        // Stub: In production, this would connect to a LOINC terminology server
        throw VocabularyError.expansionFailed("LOINC service not yet implemented")
    }
}

/// ICD integration point (stub for future implementation)
public struct ICDService: ExternalTerminologyService {
    public let serviceName = "ICD"
    private let baseURL: String?
    private let version: String // "ICD-10" or "ICD-9"
    
    public init(version: String = "ICD-10", baseURL: String? = nil) {
        self.version = version
        self.baseURL = baseURL
    }
    
    public func lookupConcept(code: String, codeSystem: String) async throws -> Concept? {
        // Stub: In production, this would connect to an ICD terminology server
        throw VocabularyError.expansionFailed("ICD service not yet implemented")
    }
    
    public func validateCode(_ code: String, codeSystem: String) async throws -> Bool {
        // Stub: In production, this would connect to an ICD terminology server
        throw VocabularyError.validationFailed("ICD service not yet implemented")
    }
    
    public func expandValueSet(identifier: String) async throws -> [Concept] {
        // Stub: In production, this would connect to an ICD terminology server
        throw VocabularyError.expansionFailed("ICD service not yet implemented")
    }
}

// MARK: - Standard Value Sets

/// Standard value sets commonly used in HL7 v3.x documents
public enum StandardValueSets {
    /// Administrative gender value set
    public static func administrativeGender() -> BasicValueSet {
        let concepts = [
            Concept(
                code: "M",
                display: "Male",
                definition: "Male",
                codeSystem: CodeSystem.administrativeGender
            ),
            Concept(
                code: "F",
                display: "Female",
                definition: "Female",
                codeSystem: CodeSystem.administrativeGender
            ),
            Concept(
                code: "UN",
                display: "Unknown",
                definition: "Unknown",
                codeSystem: CodeSystem.administrativeGender
            ),
            Concept(
                code: "U",
                display: "Undifferentiated",
                definition: "Undifferentiated",
                codeSystem: CodeSystem.administrativeGender
            )
        ]
        
        return BasicValueSet(
            identifier: "2.16.840.1.113883.1.11.1",
            name: "AdministrativeGender",
            version: "1.0",
            description: "Administrative gender codes",
            publisher: "HL7",
            concepts: concepts
        )
    }
    
    /// Confidentiality codes value set
    public static func confidentialityCodes() -> BasicValueSet {
        let concepts = [
            Concept(
                code: "N",
                display: "Normal",
                definition: "Normal confidentiality",
                codeSystem: CodeSystem.confidentiality
            ),
            Concept(
                code: "R",
                display: "Restricted",
                definition: "Restricted confidentiality",
                codeSystem: CodeSystem.confidentiality
            ),
            Concept(
                code: "V",
                display: "Very Restricted",
                definition: "Very restricted confidentiality",
                codeSystem: CodeSystem.confidentiality
            )
        ]
        
        return BasicValueSet(
            identifier: "2.16.840.1.113883.1.11.10228",
            name: "ConfidentialityCode",
            version: "1.0",
            description: "Confidentiality classification codes",
            publisher: "HL7",
            concepts: concepts
        )
    }
}
