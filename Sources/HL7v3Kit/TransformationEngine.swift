/// TransformationEngine.swift
/// HL7 v2.x to v3.x Bidirectional Transformation Framework
///
/// This module provides a comprehensive transformation framework for converting
/// between HL7 v2.x messages (pipe-delimited) and HL7 v3.x messages (XML-based CDA).
/// Supports bidirectional transformations with validation and quality tracking.

import Foundation
import HL7Core

// MARK: - Transformation Core Protocols

/// Protocol for transforming between HL7 message formats
///
/// Implementations handle the conversion of messages from one HL7 standard
/// to another (e.g., v2.x to v3.x or vice versa).
public protocol Transformer: Sendable {
    /// The source message type
    associatedtype Source: Sendable
    /// The target message type
    associatedtype Target: Sendable
    
    /// Transform a source message to target format
    /// - Parameters:
    ///   - source: The source message to transform
    ///   - context: Transformation context with configuration and state
    /// - Returns: Transformation result containing target message or errors
    /// - Throws: HL7Error if transformation fails critically
    func transform(_ source: Source, context: TransformationContext) async throws -> TransformationResult<Target>
}

/// Context for transformation operations
///
/// Provides configuration, state management, and tracking for transformations.
public struct TransformationContext: Sendable {
    /// Configuration options for transformation behavior
    public let configuration: TransformationConfiguration
    
    /// User-provided metadata for this transformation
    public let metadata: [String: String]
    
    /// Timestamp when transformation started
    public let timestamp: Date
    
    /// Unique identifier for this transformation operation
    public let operationId: String
    
    /// Creates a new transformation context
    /// - Parameters:
    ///   - configuration: Configuration for transformation behavior
    ///   - metadata: Optional user metadata
    ///   - operationId: Optional unique identifier (auto-generated if not provided)
    public init(
        configuration: TransformationConfiguration = .default,
        metadata: [String: String] = [:],
        operationId: String? = nil
    ) {
        self.configuration = configuration
        self.metadata = metadata
        self.timestamp = Date()
        self.operationId = operationId ?? UUID().uuidString
    }
}

/// Configuration options for transformation behavior
public struct TransformationConfiguration: Sendable {
    /// Validation mode for transformation
    public enum ValidationMode: Sendable {
        /// Strict validation - fail on any validation error
        case strict
        /// Lenient validation - continue with warnings
        case lenient
        /// Skip validation entirely
        case skip
    }
    
    /// Data loss handling mode
    public enum DataLossMode: Sendable {
        /// Fail transformation if data loss detected
        case fail
        /// Warn about data loss but continue
        case warn
        /// Ignore data loss
        case ignore
    }
    
    /// How to validate messages during transformation
    public let validationMode: ValidationMode
    
    /// How to handle data loss during transformation
    public let dataLossMode: DataLossMode
    
    /// Whether to track detailed metrics
    public let trackMetrics: Bool
    
    /// Maximum time allowed for transformation (seconds)
    public let timeout: TimeInterval
    
    /// Custom transformation rules to apply
    public let customRules: [TransformationRule]
    
    /// Default configuration with strict validation
    public static let `default` = TransformationConfiguration(
        validationMode: .strict,
        dataLossMode: .warn,
        trackMetrics: true,
        timeout: 30.0,
        customRules: []
    )
    
    /// Lenient configuration for compatibility
    public static let lenient = TransformationConfiguration(
        validationMode: .lenient,
        dataLossMode: .ignore,
        trackMetrics: false,
        timeout: 60.0,
        customRules: []
    )
    
    /// Creates a new transformation configuration
    public init(
        validationMode: ValidationMode = .strict,
        dataLossMode: DataLossMode = .warn,
        trackMetrics: Bool = true,
        timeout: TimeInterval = 30.0,
        customRules: [TransformationRule] = []
    ) {
        self.validationMode = validationMode
        self.dataLossMode = dataLossMode
        self.trackMetrics = trackMetrics
        self.timeout = timeout
        self.customRules = customRules
    }
}

/// A single transformation rule that maps data from source to target
public struct TransformationRule: Sendable {
    /// Unique identifier for this rule
    public let id: String
    
    /// Human-readable description
    public let description: String
    
    /// Source path or identifier (e.g., "PID-5" for v2.x patient name)
    public let sourcePath: String
    
    /// Target path or identifier (e.g., "recordTarget.patient.name" for CDA)
    public let targetPath: String
    
    /// Optional transformation function to apply to the value
    public let transform: (@Sendable (String) -> String)?
    
    /// Whether this rule is required (fail transformation if source not found)
    public let required: Bool
    
    /// Creates a transformation rule
    public init(
        id: String,
        description: String,
        sourcePath: String,
        targetPath: String,
        transform: (@Sendable (String) -> String)? = nil,
        required: Bool = false
    ) {
        self.id = id
        self.description = description
        self.sourcePath = sourcePath
        self.targetPath = targetPath
        self.transform = transform
        self.required = required
    }
}

/// Result of a transformation operation
public struct TransformationResult<T: Sendable>: Sendable {
    /// The transformed target message (if successful)
    public let target: T?
    
    /// Whether the transformation was successful
    public let success: Bool
    
    /// Errors encountered during transformation
    public let errors: [TransformationError]
    
    /// Warnings encountered during transformation
    public let warnings: [String]
    
    /// Information messages about the transformation
    public let info: [String]
    
    /// Metrics about the transformation process
    public let metrics: TransformationMetrics?
    
    /// Creates a successful transformation result
    public static func success(
        _ target: T,
        warnings: [String] = [],
        info: [String] = [],
        metrics: TransformationMetrics? = nil
    ) -> TransformationResult<T> {
        TransformationResult(
            target: target,
            success: true,
            errors: [],
            warnings: warnings,
            info: info,
            metrics: metrics
        )
    }
    
    /// Creates a failed transformation result
    public static func failure(
        errors: [TransformationError],
        warnings: [String] = [],
        info: [String] = [],
        metrics: TransformationMetrics? = nil
    ) -> TransformationResult<T> {
        TransformationResult(
            target: nil,
            success: false,
            errors: errors,
            warnings: warnings,
            info: info,
            metrics: metrics
        )
    }
    
    /// Internal initializer
    private init(
        target: T?,
        success: Bool,
        errors: [TransformationError],
        warnings: [String],
        info: [String],
        metrics: TransformationMetrics?
    ) {
        self.target = target
        self.success = success
        self.errors = errors
        self.warnings = warnings
        self.info = info
        self.metrics = metrics
    }
}

/// Error encountered during transformation
public struct TransformationError: Sendable, Error, Equatable {
    /// Error severity level
    public enum Severity: String, Sendable {
        case error = "error"
        case warning = "warning"
        case info = "info"
    }
    
    /// Error code for programmatic handling
    public let code: String
    
    /// Human-readable error message
    public let message: String
    
    /// Severity level
    public let severity: Severity
    
    /// Source location where error occurred (e.g., field path)
    public let location: String?
    
    /// Creates a transformation error
    public init(
        code: String,
        message: String,
        severity: Severity = .error,
        location: String? = nil
    ) {
        self.code = code
        self.message = message
        self.severity = severity
        self.location = location
    }
}

/// Metrics collected during transformation
public struct TransformationMetrics: Sendable {
    /// Time spent on transformation (seconds)
    public let duration: TimeInterval
    
    /// Number of fields successfully mapped
    public let fieldsMapped: Int
    
    /// Number of fields that could not be mapped
    public let fieldsUnmapped: Int
    
    /// Number of data elements lost in transformation
    public let dataLossCount: Int
    
    /// Percentage of data successfully transferred (0.0 to 1.0)
    public let dataFidelity: Double
    
    /// Memory used during transformation (bytes)
    public let memoryUsed: Int64?
    
    /// Creates transformation metrics
    public init(
        duration: TimeInterval,
        fieldsMapped: Int,
        fieldsUnmapped: Int,
        dataLossCount: Int,
        memoryUsed: Int64? = nil
    ) {
        self.duration = duration
        self.fieldsMapped = fieldsMapped
        self.fieldsUnmapped = fieldsUnmapped
        self.dataLossCount = dataLossCount
        
        let total = fieldsMapped + fieldsUnmapped
        self.dataFidelity = total > 0 ? Double(fieldsMapped) / Double(total) : 1.0
        self.memoryUsed = memoryUsed
    }
}

// MARK: - Metrics Builder

/// Helper for building transformation metrics
actor TransformationMetricsBuilder {
    private var startTime: Date?
    private var fieldsMapped = 0
    private var fieldsUnmapped = 0
    private var dataLossCount = 0
    
    /// Start timing
    func start() {
        startTime = Date()
    }
    
    /// Record a successfully mapped field
    func recordMappedField() {
        fieldsMapped += 1
    }
    
    /// Record an unmapped field
    func recordUnmappedField() {
        fieldsUnmapped += 1
    }
    
    /// Record data loss
    func recordDataLoss() {
        dataLossCount += 1
    }
    
    /// Build final metrics
    func build() -> TransformationMetrics {
        let duration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        return TransformationMetrics(
            duration: duration,
            fieldsMapped: fieldsMapped,
            fieldsUnmapped: fieldsUnmapped,
            dataLossCount: dataLossCount,
            memoryUsed: nil
        )
    }
}
