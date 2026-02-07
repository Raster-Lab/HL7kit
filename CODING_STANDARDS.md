# HL7kit Coding Standards

This document outlines the coding standards and best practices for the HL7kit project. These standards ensure consistency, maintainability, and quality across all modules.

## Table of Contents

- [Swift Version](#swift-version)
- [General Principles](#general-principles)
- [Code Style](#code-style)
- [Naming Conventions](#naming-conventions)
- [Swift 6.2 Concurrency](#swift-62-concurrency)
- [Error Handling](#error-handling)
- [Documentation](#documentation)
- [Testing](#testing)
- [Performance](#performance)
- [Security](#security)

---

## Swift Version

HL7kit is built with **Swift 6.2** and leverages its modern language features:

- Strict concurrency checking
- Actor isolation
- Async/await patterns
- Sendable protocol conformance
- Typed throws
- Result builders and property wrappers

---

## General Principles

### SOLID Principles

- **Single Responsibility**: Each type should have one clear responsibility
- **Open/Closed**: Types should be open for extension, closed for modification
- **Liskov Substitution**: Subtypes must be substitutable for their base types
- **Interface Segregation**: Many specific protocols are better than one general-purpose protocol
- **Dependency Inversion**: Depend on abstractions, not concretions

### Code Quality

- **DRY (Don't Repeat Yourself)**: Avoid code duplication
- **YAGNI (You Aren't Gonna Need It)**: Don't add functionality until needed
- **KISS (Keep It Simple, Stupid)**: Prefer simple solutions over complex ones
- **Favor Composition Over Inheritance**: Use protocol composition where possible

---

## Code Style

### File Organization

```swift
// 1. Header comment (if required)
// 2. Import statements
// 3. Type definitions
// 4. Extensions

/// Module description
/// 
/// Detailed explanation of what this module provides.

import Foundation
import HL7Core

// MARK: - Main Types

public struct MyType {
    // MARK: - Properties
    
    // MARK: - Initialization
    
    // MARK: - Public Methods
    
    // MARK: - Private Methods
}

// MARK: - Extensions

extension MyType: SomeProtocol {
    // Protocol conformance
}
```

### Spacing and Indentation

- Use **4 spaces** for indentation (never tabs)
- Maximum **2 blank lines** between sections
- One blank line between methods
- No trailing whitespace

### Line Length

- Prefer **120 characters** or less
- Hard limit at **150 characters**
- Break long lines at logical points

### Braces

- Opening braces on the same line as the statement
- Closing braces on their own line

```swift
// ✅ Good
if condition {
    doSomething()
}

// ❌ Bad
if condition
{
    doSomething()
}
```

---

## Naming Conventions

### Types (PascalCase)

```swift
// ✅ Good
struct HL7v2Message { }
class PatientRecord { }
enum MessageType { }
protocol HL7Parser { }
actor MessageProcessor { }

// ❌ Bad
struct hl7v2message { }
class patient_record { }
```

### Variables and Functions (camelCase)

```swift
// ✅ Good
let messageID: String
var patientName: String
func parseMessage() throws -> HL7v2Message

// ❌ Bad
let MessageID: String
var patient_name: String
func ParseMessage() throws -> HL7v2Message
```

### Constants

```swift
// ✅ Good - Use camelCase, not SCREAMING_SNAKE_CASE
let defaultTimeout: TimeInterval = 30.0
let maxRetryCount: Int = 3

// ❌ Bad
let DEFAULT_TIMEOUT: TimeInterval = 30.0
let MAX_RETRY_COUNT: Int = 3
```

### Protocols

```swift
// ✅ Good - Describe what something is or can do
protocol HL7Message { }
protocol Parseable { }
protocol MessageValidating { }

// ❌ Bad
protocol HL7MessageProtocol { }
protocol ParseableProtocol { }
```

### Abbreviations

Common HL7 abbreviations are allowed and should maintain their standard form:

- HL7, MSH, PID, OBX, ADT, ACK, ORM, ORU
- FHIR, API, URL, URI, ID
- CDA, RIM, CX, CE, XPN, XAD

```swift
// ✅ Good
struct MSHSegment { }
let patientID: String
let apiURL: URL

// ❌ Bad
struct MshSegment { }
let patientId: String
let apiUrl: URL
```

---

## Swift 6.2 Concurrency

### Sendable Conformance

All types that cross isolation boundaries must conform to `Sendable`:

```swift
// ✅ Good
public struct HL7v2Message: HL7Message, Sendable {
    public let messageID: String
    public let timestamp: Date
}

// For classes that need to be Sendable
public final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    
    // Thread-safe operations
}
```

### Actors for Shared State

Use actors for types that manage shared mutable state:

```swift
// ✅ Good
public actor MessageProcessor {
    private var processedCount: Int = 0
    
    public func process(_ message: HL7v2Message) async throws {
        // Safe mutable access
        processedCount += 1
    }
}

// ❌ Bad - Using class with manual locking
public class MessageProcessor {
    private let lock = NSLock()
    private var processedCount: Int = 0
    
    public func process(_ message: HL7v2Message) throws {
        lock.lock()
        defer { lock.unlock() }
        processedCount += 1
    }
}
```

### Async/Await Over Completion Handlers

Prefer async/await for asynchronous operations:

```swift
// ✅ Good
public func fetchMessage(id: String) async throws -> HL7v2Message {
    let data = try await networkClient.fetch(id: id)
    return try parser.parse(data)
}

// ❌ Bad - Using completion handlers
public func fetchMessage(id: String, completion: @escaping (Result<HL7v2Message, Error>) -> Void) {
    networkClient.fetch(id: id) { result in
        // nested callbacks...
    }
}
```

### Main Actor for UI Updates

Use `@MainActor` for types that update UI:

```swift
@MainActor
public class MessageViewController {
    public func displayMessage(_ message: HL7v2Message) {
        // Safe to update UI here
    }
}
```

---

## Error Handling

### Use Typed Throws

```swift
// ✅ Good
public enum ParsingError: Error {
    case invalidFormat(String)
    case missingRequiredField(String)
}

public func parse(_ data: Data) throws -> HL7v2Message {
    guard !data.isEmpty else {
        throw ParsingError.invalidFormat("Empty data")
    }
    // ...
}
```

### Avoid Force Unwrapping

```swift
// ✅ Good
if let value = optionalValue {
    processValue(value)
}

guard let value = optionalValue else {
    throw HL7Error.missingRequiredField("value")
}

// ❌ Bad
let value = optionalValue! // Crash risk
```

### Avoid Force Try

```swift
// ✅ Good
do {
    let message = try parseMessage(data)
    return message
} catch {
    logger.error("Failed to parse: \(error)")
    throw error
}

// ❌ Bad
let message = try! parseMessage(data) // Crash risk
```

---

## Documentation

### Public APIs Must Be Documented

All public APIs require documentation using DocC format:

```swift
/// Parses an HL7 v2.x message from raw data.
///
/// This parser handles HL7 v2.x messages from versions 2.1 through 2.8,
/// automatically detecting the version from the MSH segment.
///
/// - Parameter data: Raw message data in HL7 v2.x format
/// - Returns: Parsed HL7 v2.x message structure
/// - Throws: `HL7Error.parsingError` if the data is malformed
///
/// ## Example
///
/// ```swift
/// let parser = HL7v2Parser()
/// let message = try parser.parse(messageData)
/// print("Message ID: \(message.messageID)")
/// ```
///
/// - Note: The parser uses streaming techniques to minimize memory usage
/// - Warning: Large messages (>10MB) may require significant processing time
public func parse(_ data: Data) throws -> HL7v2Message {
    // Implementation
}
```

### Use Documentation Sections

- `- Parameter`: Describe parameters
- `- Returns`: Describe return values
- `- Throws`: Describe possible errors
- `- Note`: Additional information
- `- Warning`: Important caveats
- `- Important`: Critical information
- `- Example`: Usage examples

### Internal Comments

Use comments for complex logic:

```swift
// ✅ Good - Explains WHY
// We need to process in chunks to avoid memory spikes with large messages
for chunk in data.chunked(size: 1024) {
    process(chunk)
}

// ❌ Bad - Explains WHAT (obvious from code)
// Loop through chunks
for chunk in data.chunked(size: 1024) {
    process(chunk)
}
```

---

## Testing

### Test Coverage

- Maintain **>90% code coverage** for all core modules
- Every public API must have tests
- Test both happy paths and error cases

### Test Organization

```swift
import XCTest
@testable import HL7v2Kit

final class HL7v2ParserTests: XCTestCase {
    // MARK: - Properties
    
    private var parser: HL7v2Parser!
    
    // MARK: - Setup/Teardown
    
    override func setUp() {
        super.setUp()
        parser = HL7v2Parser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path Tests
    
    func testParseValidMessage() throws {
        // Given
        let data = createValidMessageData()
        
        // When
        let message = try parser.parse(data)
        
        // Then
        XCTAssertEqual(message.messageID, "MSG001")
    }
    
    // MARK: - Error Path Tests
    
    func testParseInvalidDataThrowsError() {
        // Given
        let invalidData = Data()
        
        // Then
        XCTAssertThrowsError(try parser.parse(invalidData)) { error in
            XCTAssertTrue(error is HL7Error)
        }
    }
    
    // MARK: - Performance Tests
    
    func testParsingPerformance() {
        measure {
            // Performance testing code
        }
    }
}
```

### Test Naming

- Use descriptive test names: `test<What>_<Condition>_<ExpectedResult>`
- Example: `testParse_WithInvalidData_ThrowsError`

### Mock Objects

Create mock objects for testing:

```swift
struct MockHL7Message: HL7Message {
    let messageID: String
    let timestamp: Date
    
    func validate() throws {
        // Mock implementation
    }
}
```

---

## Performance

### Memory Efficiency

- Use value types (struct) over reference types (class) when appropriate
- Implement copy-on-write for large data structures
- Use lazy parsing for large messages
- Release resources promptly

```swift
// ✅ Good - Value semantics with COW
public struct Message {
    private var storage: MessageStorage
    
    public mutating func addField(_ field: Field) {
        if !isKnownUniquelyReferenced(&storage) {
            storage = storage.copy()
        }
        storage.fields.append(field)
    }
}
```

### CPU Efficiency

- Profile performance-critical paths
- Use appropriate data structures (Dictionary for lookups, Array for sequences)
- Avoid unnecessary allocations
- Cache computed values when appropriate

```swift
// ✅ Good - Cached property
private var _cachedFields: [Field]?
public var fields: [Field] {
    if let cached = _cachedFields {
        return cached
    }
    let computed = computeFields()
    _cachedFields = computed
    return computed
}
```

### Performance Tests

Include performance tests for critical operations:

```swift
func testMessageParsingPerformance() {
    measure {
        for _ in 0..<1000 {
            _ = try? parser.parse(sampleData)
        }
    }
}
```

---

## Security

### Never Commit Secrets

- Use environment variables for sensitive data
- Never hardcode credentials, API keys, or tokens
- Use `.gitignore` to exclude sensitive files

### Input Validation

Always validate input data:

```swift
public func parse(_ data: Data) throws -> HL7v2Message {
    // ✅ Good - Validate input
    guard !data.isEmpty else {
        throw HL7Error.parsingError("Empty data")
    }
    
    guard data.count < maxMessageSize else {
        throw HL7Error.parsingError("Message exceeds size limit")
    }
    
    // Process validated data
}
```

### HIPAA Compliance

For healthcare data:

- Encrypt sensitive data at rest and in transit
- Implement proper access controls
- Log access to PHI (Protected Health Information)
- Follow minimum necessary principle

---

## SwiftLint Integration

This project uses SwiftLint to enforce these standards automatically. The configuration is in `.swiftlint.yml`.

### Running SwiftLint

```bash
# Lint all files
swiftlint

# Lint specific files
swiftlint lint --path Sources/HL7Core

# Auto-correct violations
swiftlint --fix

# Generate baseline
swiftlint --generate-baseline
```

### CI/CD Integration

SwiftLint runs automatically in CI/CD pipeline for all pull requests.

---

## Code Review Checklist

Before submitting code for review, ensure:

- [ ] All tests pass locally
- [ ] Code coverage is at or above 90%
- [ ] SwiftLint passes with no warnings
- [ ] Public APIs have documentation
- [ ] Code follows Swift 6.2 concurrency best practices
- [ ] No force unwrapping or force try in production code
- [ ] Error handling is comprehensive
- [ ] Performance is acceptable for critical paths
- [ ] No security vulnerabilities introduced

---

## References

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Evolution](https://apple.github.io/swift-evolution/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)

---

*These standards are living documents and will evolve as the project grows.*
