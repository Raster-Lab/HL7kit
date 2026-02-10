/// FHIRSerializationConfiguration.swift
/// Configuration options for FHIR serialization and deserialization
///
/// This file provides configuration options for JSON and XML serialization.

import Foundation

// MARK: - Serialization Configuration

/// Configuration for FHIR serialization
public struct FHIRSerializationConfiguration: Sendable {
    /// Output formatting style
    public enum OutputFormatting: Sendable {
        /// Compact output with minimal whitespace
        case compact
        /// Pretty-printed output with indentation
        case prettyPrinted
    }
    
    /// Date formatting strategy
    public enum DateStrategy: Sendable {
        /// ISO 8601 format (default)
        case iso8601
        /// Custom formatter
        case formatted(DateFormatter)
    }
    
    /// Validation mode during serialization
    public enum ValidationMode: Sendable {
        /// Strict validation - throw errors on validation failures
        case strict
        /// Lenient validation - log warnings but continue
        case lenient
        /// No validation
        case none
    }
    
    /// Output formatting
    public let outputFormatting: OutputFormatting
    
    /// Date encoding strategy
    public let dateStrategy: DateStrategy
    
    /// Validation mode
    public let validationMode: ValidationMode
    
    /// Whether to include null values in output
    public let includeNullValues: Bool
    
    /// Whether to preserve element order
    public let preserveElementOrder: Bool
    
    /// Maximum nesting depth (to prevent stack overflow)
    public let maxNestingDepth: Int
    
    /// Whether to validate choice types (value[x])
    public let validateChoiceTypes: Bool
    
    public init(
        outputFormatting: OutputFormatting = .compact,
        dateStrategy: DateStrategy = .iso8601,
        validationMode: ValidationMode = .lenient,
        includeNullValues: Bool = false,
        preserveElementOrder: Bool = true,
        maxNestingDepth: Int = 100,
        validateChoiceTypes: Bool = true
    ) {
        self.outputFormatting = outputFormatting
        self.dateStrategy = dateStrategy
        self.validationMode = validationMode
        self.includeNullValues = includeNullValues
        self.preserveElementOrder = preserveElementOrder
        self.maxNestingDepth = maxNestingDepth
        self.validateChoiceTypes = validateChoiceTypes
    }
    
    /// Default configuration
    public static let `default` = FHIRSerializationConfiguration()
    
    /// Configuration for pretty-printed output
    public static let prettyPrinted = FHIRSerializationConfiguration(
        outputFormatting: .prettyPrinted
    )
    
    /// Configuration for strict validation
    public static let strict = FHIRSerializationConfiguration(
        validationMode: .strict,
        validateChoiceTypes: true
    )
}

// MARK: - Serialization Errors

/// Errors that can occur during FHIR serialization/deserialization
public enum FHIRSerializationError: Error, Sendable, CustomStringConvertible {
    case invalidJSON(String)
    case invalidXML(String)
    case choiceTypeViolation(String)
    case nestingDepthExceeded(Int)
    case invalidResourceType(String)
    case validationFailed(String)
    case unsupportedFormat(String)
    
    public var description: String {
        switch self {
        case .invalidJSON(let message):
            return "Invalid JSON: \(message)"
        case .invalidXML(let message):
            return "Invalid XML: \(message)"
        case .choiceTypeViolation(let message):
            return "Choice type violation: \(message)"
        case .nestingDepthExceeded(let depth):
            return "Maximum nesting depth exceeded: \(depth)"
        case .invalidResourceType(let type):
            return "Invalid resource type: \(type)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        }
    }
}
