/// Error handling and recovery protocols for HL7kit
///
/// This module provides protocols and utilities for handling and recovering from errors
/// during HL7 message processing.

import Foundation

/// Protocol for error recovery strategies
public protocol ErrorRecoveryStrategy: Sendable {
    /// Attempt to recover from an error
    /// - Parameter error: The error to recover from
    /// - Returns: Recovery result
    func recover(from error: HL7Error) -> ErrorRecoveryResult
}

/// Result of error recovery attempt
public enum ErrorRecoveryResult: Sendable {
    /// Recovery succeeded with corrected data
    case recovered(String)
    
    /// Recovery failed, error cannot be recovered
    case failed(reason: String)
    
    /// Recovery requires manual intervention
    case requiresManualIntervention(guidance: String)
}

/// Protocol for error reporting
public protocol ErrorReporter: Sendable {
    /// Report an error
    /// - Parameters:
    ///   - error: The error to report
    ///   - severity: Severity level
    func report(error: HL7Error, severity: ErrorSeverity)
}

/// Severity level for error reporting
public enum ErrorSeverity: String, Sendable {
    case critical
    case high
    case medium
    case low
}

/// Protocol for error listeners
public protocol ErrorListener: Sendable {
    /// Called when an error occurs
    /// - Parameter error: The error that occurred
    func onError(_ error: HL7Error)
}

/// Actor for collecting and aggregating errors
public actor ErrorCollector {
    private var errors: [HL7Error] = []
    private var maxErrors: Int
    
    public init(maxErrors: Int = 100) {
        self.maxErrors = maxErrors
    }
    
    /// Add an error to the collection
    public func add(_ error: HL7Error) {
        guard errors.count < maxErrors else { return }
        errors.append(error)
    }
    
    /// Get all collected errors
    public func allErrors() -> [HL7Error] {
        errors
    }
    
    /// Check if any errors have been collected
    public func hasErrors() -> Bool {
        !errors.isEmpty
    }
    
    /// Get count of collected errors
    public func count() -> Int {
        errors.count
    }
    
    /// Clear all collected errors
    public func clear() {
        errors.removeAll()
    }
    
    /// Check if max errors limit has been reached
    public func hasReachedLimit() -> Bool {
        errors.count >= maxErrors
    }
}

/// Protocol for retry strategies
public protocol RetryStrategy: Sendable {
    /// Determine if operation should be retried
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attemptCount: Number of attempts so far
    /// - Returns: Whether to retry and delay before retry
    func shouldRetry(error: HL7Error, attemptCount: Int) -> (shouldRetry: Bool, delay: TimeInterval?)
}

/// Exponential backoff retry strategy
public struct ExponentialBackoffRetry: RetryStrategy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }
    
    public func shouldRetry(error: HL7Error, attemptCount: Int) -> (shouldRetry: Bool, delay: TimeInterval?) {
        guard attemptCount < maxAttempts else {
            return (false, nil)
        }
        
        // Calculate exponential backoff delay
        let delay = min(baseDelay * pow(2.0, Double(attemptCount)), maxDelay)
        return (true, delay)
    }
}

/// Linear retry strategy
public struct LinearRetry: RetryStrategy {
    public let maxAttempts: Int
    public let delay: TimeInterval
    
    public init(maxAttempts: Int = 3, delay: TimeInterval = 1.0) {
        self.maxAttempts = maxAttempts
        self.delay = delay
    }
    
    public func shouldRetry(error: HL7Error, attemptCount: Int) -> (shouldRetry: Bool, delay: TimeInterval?) {
        guard attemptCount < maxAttempts else {
            return (false, nil)
        }
        return (true, delay)
    }
}

/// No retry strategy
public struct NoRetry: RetryStrategy {
    public init() {}
    
    public func shouldRetry(error: HL7Error, attemptCount: Int) -> (shouldRetry: Bool, delay: TimeInterval?) {
        return (false, nil)
    }
}
