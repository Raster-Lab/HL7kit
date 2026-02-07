import XCTest
@testable import HL7Core

/// Tests for error recovery and handling
final class ErrorRecoveryTests: XCTestCase {
    
    // MARK: - ErrorContext Tests
    
    func testErrorContextCreation() {
        let context = ErrorContext(
            location: "segment.field",
            line: 10,
            column: 5,
            metadata: ["type": "validation"],
            underlyingError: nil
        )
        
        XCTAssertEqual(context.location, "segment.field")
        XCTAssertEqual(context.line, 10)
        XCTAssertEqual(context.column, 5)
        XCTAssertEqual(context.metadata["type"], "validation")
        XCTAssertNil(context.underlyingError)
    }
    
    func testErrorContextWithUnderlyingError() {
        struct TestError: Error {}
        let underlying = TestError()
        let context = ErrorContext(underlyingError: underlying)
        
        XCTAssertNotNil(context.underlyingError)
    }
    
    // MARK: - HL7Error Tests
    
    func testHL7ErrorWithContext() {
        let context = ErrorContext(location: "MSH.9", line: 1)
        let error = HL7Error.parsingError("Invalid message type", context: context)
        
        XCTAssertNotNil(error.context)
        XCTAssertEqual(error.context?.location, "MSH.9")
        XCTAssertEqual(error.context?.line, 1)
        XCTAssertEqual(error.message, "Invalid message type")
    }
    
    func testHL7ErrorMessage() {
        let error = HL7Error.validationError("Required field missing")
        XCTAssertEqual(error.message, "Required field missing")
    }
    
    func testHL7ErrorTypes() {
        let errors: [HL7Error] = [
            .invalidFormat("test"),
            .missingRequiredField("test"),
            .invalidDataType("test"),
            .parsingError("test"),
            .validationError("test"),
            .networkError("test"),
            .encodingError("test"),
            .timeout("test"),
            .authenticationError("test"),
            .configurationError("test"),
            .unknown("test")
        ]
        
        XCTAssertEqual(errors.count, 11)
    }
    
    // MARK: - ErrorRecoveryResult Tests
    
    func testErrorRecoveryResultRecovered() {
        let result = ErrorRecoveryResult.recovered("corrected data")
        if case .recovered(let data) = result {
            XCTAssertEqual(data, "corrected data")
        } else {
            XCTFail("Expected recovered result")
        }
    }
    
    func testErrorRecoveryResultFailed() {
        let result = ErrorRecoveryResult.failed(reason: "Cannot recover")
        if case .failed(let reason) = result {
            XCTAssertEqual(reason, "Cannot recover")
        } else {
            XCTFail("Expected failed result")
        }
    }
    
    func testErrorRecoveryResultManual() {
        let result = ErrorRecoveryResult.requiresManualIntervention(guidance: "Check format")
        if case .requiresManualIntervention(let guidance) = result {
            XCTAssertEqual(guidance, "Check format")
        } else {
            XCTFail("Expected manual intervention result")
        }
    }
    
    // MARK: - ErrorRecoveryStrategy Tests
    
    struct TestRecoveryStrategy: ErrorRecoveryStrategy {
        func recover(from error: HL7Error) -> ErrorRecoveryResult {
            switch error {
            case .parsingError(let msg, _):
                if msg.contains("recoverable") {
                    return .recovered("fixed: \(msg)")
                }
                return .failed(reason: "Cannot recover from: \(msg)")
            default:
                return .requiresManualIntervention(guidance: "Manual check needed")
            }
        }
    }
    
    func testRecoveryStrategyRecoverable() {
        let strategy = TestRecoveryStrategy()
        let error = HL7Error.parsingError("recoverable error")
        let result = strategy.recover(from: error)
        
        if case .recovered(let data) = result {
            XCTAssertTrue(data.contains("fixed:"))
        } else {
            XCTFail("Expected recovery")
        }
    }
    
    func testRecoveryStrategyNonRecoverable() {
        let strategy = TestRecoveryStrategy()
        let error = HL7Error.parsingError("fatal error")
        let result = strategy.recover(from: error)
        
        if case .failed(let reason) = result {
            XCTAssertTrue(reason.contains("Cannot recover"))
        } else {
            XCTFail("Expected failure")
        }
    }
    
    func testRecoveryStrategyManualIntervention() {
        let strategy = TestRecoveryStrategy()
        let error = HL7Error.validationError("validation failed")
        let result = strategy.recover(from: error)
        
        if case .requiresManualIntervention = result {
            // Expected
        } else {
            XCTFail("Expected manual intervention")
        }
    }
    
    // MARK: - ErrorSeverity Tests
    
    func testErrorSeverityLevels() {
        XCTAssertEqual(ErrorSeverity.critical.rawValue, "critical")
        XCTAssertEqual(ErrorSeverity.high.rawValue, "high")
        XCTAssertEqual(ErrorSeverity.medium.rawValue, "medium")
        XCTAssertEqual(ErrorSeverity.low.rawValue, "low")
    }
    
    // MARK: - ErrorCollector Tests
    
    func testErrorCollectorEmpty() async {
        let collector = ErrorCollector()
        let hasErrors = await collector.hasErrors()
        XCTAssertFalse(hasErrors)
        
        let count = await collector.count()
        XCTAssertEqual(count, 0)
    }
    
    func testErrorCollectorAddError() async {
        let collector = ErrorCollector()
        let error = HL7Error.validationError("test")
        
        await collector.add(error)
        
        let hasErrors = await collector.hasErrors()
        XCTAssertTrue(hasErrors)
        
        let count = await collector.count()
        XCTAssertEqual(count, 1)
    }
    
    func testErrorCollectorMultipleErrors() async {
        let collector = ErrorCollector()
        
        await collector.add(HL7Error.validationError("error1"))
        await collector.add(HL7Error.parsingError("error2"))
        await collector.add(HL7Error.networkError("error3"))
        
        let count = await collector.count()
        XCTAssertEqual(count, 3)
        
        let errors = await collector.allErrors()
        XCTAssertEqual(errors.count, 3)
    }
    
    func testErrorCollectorMaxLimit() async {
        let collector = ErrorCollector(maxErrors: 3)
        
        for i in 0..<5 {
            await collector.add(HL7Error.validationError("error\(i)"))
        }
        
        let count = await collector.count()
        XCTAssertEqual(count, 3) // Should stop at max
        
        let hasReached = await collector.hasReachedLimit()
        XCTAssertTrue(hasReached)
    }
    
    func testErrorCollectorClear() async {
        let collector = ErrorCollector()
        
        await collector.add(HL7Error.validationError("test"))
        await collector.clear()
        
        let hasErrors = await collector.hasErrors()
        XCTAssertFalse(hasErrors)
    }
    
    // MARK: - RetryStrategy Tests
    
    func testExponentialBackoffRetry() {
        let strategy = ExponentialBackoffRetry(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 10.0
        )
        
        let error = HL7Error.networkError("timeout")
        
        // First attempt
        let (shouldRetry1, delay1) = strategy.shouldRetry(error: error, attemptCount: 0)
        XCTAssertTrue(shouldRetry1)
        XCTAssertEqual(delay1, 1.0)
        
        // Second attempt
        let (shouldRetry2, delay2) = strategy.shouldRetry(error: error, attemptCount: 1)
        XCTAssertTrue(shouldRetry2)
        XCTAssertEqual(delay2, 2.0)
        
        // Third attempt
        let (shouldRetry3, delay3) = strategy.shouldRetry(error: error, attemptCount: 2)
        XCTAssertTrue(shouldRetry3)
        XCTAssertEqual(delay3, 4.0)
        
        // Fourth attempt (should not retry)
        let (shouldRetry4, _) = strategy.shouldRetry(error: error, attemptCount: 3)
        XCTAssertFalse(shouldRetry4)
    }
    
    func testExponentialBackoffMaxDelay() {
        let strategy = ExponentialBackoffRetry(
            maxAttempts: 10,
            baseDelay: 1.0,
            maxDelay: 5.0
        )
        
        let error = HL7Error.networkError("timeout")
        let (_, delay) = strategy.shouldRetry(error: error, attemptCount: 5)
        
        XCTAssertNotNil(delay)
        XCTAssertLessThanOrEqual(delay!, 5.0) // Should be capped at maxDelay
    }
    
    func testLinearRetry() {
        let strategy = LinearRetry(maxAttempts: 3, delay: 2.0)
        let error = HL7Error.networkError("timeout")
        
        // First attempt
        let (shouldRetry1, delay1) = strategy.shouldRetry(error: error, attemptCount: 0)
        XCTAssertTrue(shouldRetry1)
        XCTAssertEqual(delay1, 2.0)
        
        // Second attempt
        let (shouldRetry2, delay2) = strategy.shouldRetry(error: error, attemptCount: 1)
        XCTAssertTrue(shouldRetry2)
        XCTAssertEqual(delay2, 2.0)
        
        // Third attempt
        let (shouldRetry3, delay3) = strategy.shouldRetry(error: error, attemptCount: 2)
        XCTAssertTrue(shouldRetry3)
        XCTAssertEqual(delay3, 2.0)
        
        // Fourth attempt (should not retry)
        let (shouldRetry4, _) = strategy.shouldRetry(error: error, attemptCount: 3)
        XCTAssertFalse(shouldRetry4)
    }
    
    func testNoRetry() {
        let strategy = NoRetry()
        let error = HL7Error.networkError("timeout")
        
        let (shouldRetry, _) = strategy.shouldRetry(error: error, attemptCount: 0)
        XCTAssertFalse(shouldRetry)
    }
    
    // MARK: - Performance Tests
    
    func testErrorCollectorPerformance() async {
        let collector = ErrorCollector()
        
        let start = Date()
        for i in 0..<1000 {
            await collector.add(HL7Error.validationError("error\(i)"))
        }
        let duration = Date().timeIntervalSince(start)
        print("Error collector operation took \(duration) seconds")
    }
    
    func testRetryStrategyPerformance() {
        let strategy = ExponentialBackoffRetry()
        let error = HL7Error.networkError("timeout")
        
        measure {
            for i in 0..<1000 {
                _ = strategy.shouldRetry(error: error, attemptCount: i % 3)
            }
        }
    }
}
