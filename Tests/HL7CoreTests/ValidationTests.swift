import XCTest
@testable import HL7Core

/// Tests for validation framework
final class ValidationTests: XCTestCase {
    
    // MARK: - ValidationResult Tests
    
    func testValidationResultValid() {
        let result = ValidationResult.valid
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 0)
    }
    
    func testValidationResultWarning() {
        let issue = ValidationIssue(
            severity: .warning,
            message: "Warning message",
            location: "field.name"
        )
        let result = ValidationResult.warning([issue])
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].severity, .warning)
    }
    
    func testValidationResultInvalid() {
        let issue = ValidationIssue(
            severity: .error,
            message: "Error message",
            location: "field.name"
        )
        let result = ValidationResult.invalid([issue])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].severity, .error)
    }
    
    func testValidationResultMultipleIssues() {
        let issues = [
            ValidationIssue(severity: .error, message: "Error 1"),
            ValidationIssue(severity: .warning, message: "Warning 1"),
            ValidationIssue(severity: .error, message: "Error 2")
        ]
        let result = ValidationResult.invalid(issues)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 3)
    }
    
    // MARK: - ValidationIssue Tests
    
    func testValidationIssueCreation() {
        let issue = ValidationIssue(
            severity: .error,
            message: "Test error",
            location: "segment.field[0]",
            code: "ERR001"
        )
        
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.message, "Test error")
        XCTAssertEqual(issue.location, "segment.field[0]")
        XCTAssertEqual(issue.code, "ERR001")
    }
    
    func testValidationIssueOptionalFields() {
        let issue = ValidationIssue(
            severity: .warning,
            message: "Test warning"
        )
        
        XCTAssertNil(issue.location)
        XCTAssertNil(issue.code)
    }
    
    func testValidationSeverityLevels() {
        XCTAssertEqual(ValidationSeverity.error.rawValue, "error")
        XCTAssertEqual(ValidationSeverity.warning.rawValue, "warning")
        XCTAssertEqual(ValidationSeverity.info.rawValue, "info")
    }
    
    // MARK: - ValidationContext Tests
    
    func testValidationContextCreation() {
        let context = ValidationContext()
        XCTAssertEqual(context.path, [])
        XCTAssertEqual(context.pathString, "")
    }
    
    func testValidationContextAppending() {
        let context = ValidationContext()
        let newContext = context.appending("field")
        XCTAssertEqual(newContext.path, ["field"])
        XCTAssertEqual(newContext.pathString, "field")
    }
    
    func testValidationContextMultipleLevels() {
        let context = ValidationContext()
            .appending("segment")
            .appending("field")
            .appending("component")
        
        XCTAssertEqual(context.path, ["segment", "field", "component"])
        XCTAssertEqual(context.pathString, "segment.field.component")
    }
    
    func testValidationContextOptions() {
        let options = ValidationOptions(
            stopOnFirstError: true,
            validateOptionalFields: false,
            strictMode: true,
            maxIssues: 50
        )
        let context = ValidationContext(options: options)
        
        XCTAssertTrue(context.options.stopOnFirstError)
        XCTAssertFalse(context.options.validateOptionalFields)
        XCTAssertTrue(context.options.strictMode)
        XCTAssertEqual(context.options.maxIssues, 50)
    }
    
    // MARK: - ValidationOptions Tests
    
    func testValidationOptionsDefault() {
        let options = ValidationOptions.default
        XCTAssertFalse(options.stopOnFirstError)
        XCTAssertTrue(options.validateOptionalFields)
        XCTAssertFalse(options.strictMode)
        XCTAssertEqual(options.maxIssues, 100)
    }
    
    func testValidationOptionsStrict() {
        let options = ValidationOptions.strict
        XCTAssertTrue(options.strictMode)
    }
    
    func testValidationOptionsCustom() {
        let options = ValidationOptions(
            stopOnFirstError: true,
            validateOptionalFields: false,
            strictMode: true,
            maxIssues: 10
        )
        
        XCTAssertTrue(options.stopOnFirstError)
        XCTAssertFalse(options.validateOptionalFields)
        XCTAssertTrue(options.strictMode)
        XCTAssertEqual(options.maxIssues, 10)
    }
    
    // MARK: - ValidationAccumulator Tests
    
    func testValidationAccumulatorEmpty() async {
        let accumulator = ValidationAccumulator()
        let result = await accumulator.result()
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 0)
    }
    
    func testValidationAccumulatorAddIssue() async {
        let accumulator = ValidationAccumulator()
        let issue = ValidationIssue(severity: .warning, message: "Test")
        
        await accumulator.add(issue)
        let result = await accumulator.result()
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
    }
    
    func testValidationAccumulatorAddError() async {
        let accumulator = ValidationAccumulator()
        let issue = ValidationIssue(severity: .error, message: "Error")
        
        await accumulator.add(issue)
        let result = await accumulator.result()
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
    }
    
    func testValidationAccumulatorMultipleIssues() async {
        let accumulator = ValidationAccumulator()
        let issues = [
            ValidationIssue(severity: .warning, message: "Warning 1"),
            ValidationIssue(severity: .info, message: "Info 1"),
            ValidationIssue(severity: .warning, message: "Warning 2")
        ]
        
        await accumulator.add(issues)
        let result = await accumulator.result()
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 3)
    }
    
    func testValidationAccumulatorMaxIssues() async {
        let options = ValidationOptions(maxIssues: 3)
        let accumulator = ValidationAccumulator(options: options)
        
        for i in 0..<5 {
            await accumulator.add(ValidationIssue(severity: .warning, message: "Issue \(i)"))
        }
        
        let hasReached = await accumulator.hasReachedLimit()
        XCTAssertTrue(hasReached)
        
        let result = await accumulator.result()
        XCTAssertEqual(result.issues.count, 3) // Should stop at max
    }
    
    func testValidationAccumulatorStopOnFirstError() async {
        let options = ValidationOptions(stopOnFirstError: true)
        let accumulator = ValidationAccumulator(options: options)
        
        await accumulator.add(ValidationIssue(severity: .warning, message: "Warning"))
        var shouldStop = await accumulator.shouldStop()
        XCTAssertFalse(shouldStop)
        
        await accumulator.add(ValidationIssue(severity: .error, message: "Error"))
        shouldStop = await accumulator.shouldStop()
        XCTAssertTrue(shouldStop)
    }
    
    // MARK: - Validatable Protocol Tests
    
    struct TestValidatable: Validatable {
        let value: String
        let shouldFail: Bool
        
        func validate(context: ValidationContext) -> ValidationResult {
            if shouldFail {
                return .invalid([ValidationIssue(
                    severity: .error,
                    message: "Validation failed",
                    location: context.pathString
                )])
            }
            
            if value.isEmpty {
                return .warning([ValidationIssue(
                    severity: .warning,
                    message: "Empty value",
                    location: context.pathString
                )])
            }
            
            return .valid
        }
    }
    
    func testValidatableSuccess() {
        let validatable = TestValidatable(value: "test", shouldFail: false)
        let context = ValidationContext()
        let result = validatable.validate(context: context)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testValidatableWarning() {
        let validatable = TestValidatable(value: "", shouldFail: false)
        let context = ValidationContext()
        let result = validatable.validate(context: context)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].severity, .warning)
    }
    
    func testValidatableFailure() {
        let validatable = TestValidatable(value: "test", shouldFail: true)
        let context = ValidationContext()
        let result = validatable.validate(context: context)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].severity, .error)
    }
    
    func testValidatableWithPath() {
        let validatable = TestValidatable(value: "test", shouldFail: true)
        let context = ValidationContext().appending("field").appending("subfield")
        let result = validatable.validate(context: context)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues[0].location, "field.subfield")
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                let context = ValidationContext()
                    .appending("segment")
                    .appending("field")
                _ = context.pathString
            }
        }
    }
    
    func testValidationAccumulatorPerformance() async {
        let accumulator = ValidationAccumulator()
        
        let start = Date()
        for i in 0..<1000 {
            await accumulator.add(ValidationIssue(
                severity: .warning,
                message: "Issue \(i)"
            ))
        }
        _ = await accumulator.result()
        let duration = Date().timeIntervalSince(start)
        print("Validation accumulator operation took \(duration) seconds")
    }
}
