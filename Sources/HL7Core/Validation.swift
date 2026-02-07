/// Validation framework for HL7 messages and data
///
/// This module provides protocols and types for validating HL7 data structures
/// across all HL7 standards (v2.x, v3.x, and FHIR).

import Foundation

/// Result of a validation operation
public enum ValidationResult: Sendable {
    /// Validation passed without issues
    case valid
    
    /// Validation passed with warnings
    case warning([ValidationIssue])
    
    /// Validation failed with errors
    case invalid([ValidationIssue])
    
    /// Whether the validation result indicates success (valid or warning)
    public var isValid: Bool {
        switch self {
        case .valid, .warning:
            return true
        case .invalid:
            return false
        }
    }
    
    /// All issues found during validation
    public var issues: [ValidationIssue] {
        switch self {
        case .valid:
            return []
        case .warning(let issues), .invalid(let issues):
            return issues
        }
    }
}

/// Severity level of a validation issue
public enum ValidationSeverity: String, Sendable {
    case error
    case warning
    case info
}

/// A single validation issue
public struct ValidationIssue: Sendable {
    /// Severity of the issue
    public let severity: ValidationSeverity
    
    /// Human-readable description of the issue
    public let message: String
    
    /// Location where the issue was found (e.g., field path, line number)
    public let location: String?
    
    /// Optional error code for categorization
    public let code: String?
    
    public init(
        severity: ValidationSeverity,
        message: String,
        location: String? = nil,
        code: String? = nil
    ) {
        self.severity = severity
        self.message = message
        self.location = location
        self.code = code
    }
}

/// Context for validation operations
public struct ValidationContext: Sendable {
    /// Validation options
    public let options: ValidationOptions
    
    /// Path to the current validation location
    public let path: [String]
    
    public init(
        options: ValidationOptions = ValidationOptions(),
        path: [String] = []
    ) {
        self.options = options
        self.path = path
    }
    
    /// Create a new context with an appended path component
    public func appending(_ component: String) -> ValidationContext {
        ValidationContext(
            options: options,
            path: path + [component]
        )
    }
    
    /// Full path as a string
    public var pathString: String {
        path.joined(separator: ".")
    }
}

/// Options for controlling validation behavior
public struct ValidationOptions: Sendable {
    /// Whether to stop validation on first error
    public let stopOnFirstError: Bool
    
    /// Whether to validate optional fields
    public let validateOptionalFields: Bool
    
    /// Whether to perform strict validation
    public let strictMode: Bool
    
    /// Maximum number of issues to collect
    public let maxIssues: Int
    
    public init(
        stopOnFirstError: Bool = false,
        validateOptionalFields: Bool = true,
        strictMode: Bool = false,
        maxIssues: Int = 100
    ) {
        self.stopOnFirstError = stopOnFirstError
        self.validateOptionalFields = validateOptionalFields
        self.strictMode = strictMode
        self.maxIssues = maxIssues
    }
    
    /// Default validation options
    public static let `default` = ValidationOptions()
    
    /// Strict validation options
    public static let strict = ValidationOptions(strictMode: true)
}

/// Protocol for types that can validate themselves
public protocol Validatable: Sendable {
    /// Validate the instance with the given context
    /// - Parameter context: Validation context
    /// - Returns: Validation result
    func validate(context: ValidationContext) -> ValidationResult
}

/// Protocol for validation rules
public protocol ValidationRule: Sendable {
    /// Apply the validation rule
    /// - Parameter context: Validation context
    /// - Returns: Validation result
    func validate(context: ValidationContext) -> ValidationResult
}

/// Protocol for types that can perform validation
public protocol Validator: Sendable {
    associatedtype Target: Validatable
    
    /// Validate a target value
    /// - Parameters:
    ///   - target: The value to validate
    ///   - context: Validation context
    /// - Returns: Validation result
    func validate(_ target: Target, context: ValidationContext) -> ValidationResult
}

/// Accumulator for collecting validation issues
public actor ValidationAccumulator {
    private var issues: [ValidationIssue] = []
    private let options: ValidationOptions
    
    public init(options: ValidationOptions = .default) {
        self.options = options
    }
    
    /// Add a validation issue
    public func add(_ issue: ValidationIssue) {
        guard issues.count < options.maxIssues else { return }
        issues.append(issue)
    }
    
    /// Add multiple validation issues
    public func add(_ newIssues: [ValidationIssue]) {
        for issue in newIssues {
            add(issue)
        }
    }
    
    /// Get the current validation result
    public func result() -> ValidationResult {
        if issues.isEmpty {
            return .valid
        }
        
        let hasErrors = issues.contains { $0.severity == .error }
        return hasErrors ? .invalid(issues) : .warning(issues)
    }
    
    /// Check if accumulator has reached max issues
    public func hasReachedLimit() -> Bool {
        issues.count >= options.maxIssues
    }
    
    /// Check if should stop validation
    public func shouldStop() -> Bool {
        if options.stopOnFirstError {
            return issues.contains { $0.severity == .error }
        }
        return hasReachedLimit()
    }
}
