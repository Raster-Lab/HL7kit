# HL7kit Integration Guide

Developer guide for Phase 7 — Integration & Common Services.

---

## Table of Contents

- [Overview](#overview)
- [Shared Services](#shared-services)
  - [UnifiedLogger](#unifiedlogger)
  - [SecurityService](#securityservice)
  - [SharedCache](#sharedcache)
  - [Persistence Layer](#persistence-layer)
  - [Testing Infrastructure](#testing-infrastructure)
- [Common Integration Patterns](#common-integration-patterns)
- [Configuration Examples](#configuration-examples)
- [Migrating to Unified Services](#migrating-to-unified-services)

---

## Overview

Phase 7 introduces a set of **shared services** in `HL7Core` that every module (`HL7v2Kit`, `HL7v3Kit`, `FHIRkit`) can use consistently. The services are designed around Swift 6 strict concurrency: all stateful components are `actor`-based, all data types are `Sendable`, and all operations are `async`.

| Service | Source File | Purpose |
|---------|-------------|---------|
| `UnifiedLogger` | `CommonServices.swift` | Cross-module structured logging with correlation IDs |
| `SecurityService` | `CommonServices.swift` | PHI sanitization, input validation, hashing |
| `SharedCache` | `CommonServices.swift` | Generic LRU cache with TTL expiration |
| `MessageEncryptor` / `DigitalSigner` | `SecurityFramework.swift` | Encryption, signing, certificate management |
| `MessageArchive` / `ArchiveIndex` | `Persistence.swift` | Message storage, search, export/import |
| `IntegrationTestRunner` / `PerformanceBenchmarkRunner` | `TestingInfrastructure.swift` | Reusable test harnesses |

---

## Shared Services

### UnifiedLogger

`UnifiedLogger` is an actor that provides structured, buffered logging with subsystem and category tagging, correlation IDs for request tracing, and configurable log levels.

#### Quick Start

```swift
import HL7Core

// Create a logger
let logger = UnifiedLogger(subsystem: "com.myapp.hl7", maxBufferSize: 5_000)

// Log with metadata
let correlationID = CorrelationID.generate()
let metadata = LogMetadata(
    values: ["patientID": "masked"],
    correlationID: correlationID,
    module: "HL7v2Kit"
)
await logger.log(
    category: "parsing",
    level: .info,
    message: "Parsed ADT A01 message",
    metadata: metadata
)

// Filter and export logs
let recentLogs = await logger.exportLogs(
    level: .warning,
    category: "parsing",
    since: Date().addingTimeInterval(-3600)
)
```

#### Key API

| Method | Description |
|--------|-------------|
| `log(category:level:message:metadata:)` | Add a log entry |
| `setLogLevel(_:)` | Change the minimum log level |
| `exportLogs(level:category:since:)` | Retrieve filtered log entries |
| `clearLogs()` | Remove all buffered entries |
| `logCount` | Current number of buffered entries |

---

### SecurityService

`SecurityService` is an actor that provides PHI detection and masking, input validation, secure random byte generation, and SHA-256 hashing.

#### Quick Start

```swift
import HL7Core

let security = SecurityService()

// Sanitize PHI from a string (masks SSNs, phone numbers, emails)
let sanitized = await security.sanitizePHI(
    in: "Patient SSN: 123-45-6789, Phone: 555-123-4567"
)
// Result: "Patient SSN: [REDACTED-SSN], Phone: [REDACTED-PHONE]"

// Validate input
let result = await security.validateInput("hello world")
if result.isValid {
    // safe to use
}

// Generate secure random bytes
let randomHex = await security.generateSecureRandomHex(length: 16)

// Hash data
let hash = await security.sha256(data: Data("secret".utf8))
```

---

### SharedCache

`SharedCache` is a generic, actor-based LRU cache with optional TTL-based expiration.

#### Quick Start

```swift
import HL7Core

// Create a cache with max 500 entries and 5-minute default TTL
let cache = SharedCache<String, Data>(
    maxSize: 500,
    defaultTTL: 300
)

// Store a value (uses default TTL)
await cache.set("patient-123", value: patientData)

// Store with custom TTL (10 minutes)
await cache.set("observation-456", value: obsData, ttl: 600)

// Retrieve
if let data = await cache.get("patient-123") {
    // use cached data
}

// Check statistics
let stats = await cache.statistics
print("Hit rate: \(stats.hitRate)")
```

#### Eviction Behavior

- When the cache reaches `maxSize`, the **least recently used** entry is evicted.
- Entries whose TTL has expired are removed on the next `get` call and do not count toward the hit rate.

---

### Persistence Layer

The persistence layer provides message archival, full-text search, and JSON export/import.

#### Quick Start — Message Archive

```swift
import HL7Core

let archive = MessageArchive()

// Store a message
let entry = ArchiveEntry(
    messageType: "ADT^A01",
    version: "2.5",
    source: "HIS",
    tags: ["inpatient", "admit"],
    content: rawHL7String
)
try await archive.store(entry)

// Retrieve by ID
let retrieved = try await archive.retrieve(id: entry.id)

// Query by type or date range
let adtMessages = await archive.retrieve(
    byType: "ADT^A01",
    from: startDate,
    to: endDate
)

// Get statistics
let stats = await archive.statistics()
print("Total entries: \(stats.totalEntries)")
```

#### Quick Start — Full-Text Search

```swift
let index = ArchiveIndex()

// Index an entry
await index.addEntry(entry)

// Full-text search with TF-IDF relevance scoring
let results = await index.search(query: "admit patient")
for result in results {
    print("\(result.entry.messageType) — relevance: \(result.relevanceScore)")
}
```

#### Quick Start — Export / Import

```swift
// Export to JSON
let exporter = DataExporter()
let jsonData = try exporter.exportJSON(from: archive)

// Import from JSON
let importer = DataImporter()
let importResult = try await importer.importJSON(jsonData, into: archive)
print("Imported: \(importResult.imported), Skipped: \(importResult.skipped)")
```

---

### Testing Infrastructure

Reusable test harnesses that are **XCTest-independent** so library consumers can use them too.

#### Integration Tests

```swift
import HL7Core

struct MyIntegrationTest: IntegrationTest {
    let name = "ADT round-trip"
    let dependencies: [String] = []

    func execute() async throws -> IntegrationTestStatus {
        // test logic here
        return .passed
    }
}

let runner = IntegrationTestRunner()
let result = await runner.run(test: MyIntegrationTest())
print("Passed: \(result.passed)")
```

#### Performance Benchmarks

```swift
struct ParserBenchmark: BenchmarkCase {
    let name = "parse-adt-a01"
    let warmupCount = 5
    let iterationCount = 100

    func measure() async throws {
        // code to benchmark
    }
}

let benchmarkRunner = PerformanceBenchmarkRunner()
let timing = await benchmarkRunner.run(benchmarkCase: ParserBenchmark())
print("p95: \(timing.p95)s, median: \(timing.median)s")
```

#### Conformance Tests

```swift
struct RequiredFieldConformance: ConformanceTestCase {
    let requirement = ConformanceRequirement(
        id: "MSH-REQUIRED",
        description: "MSH segment required fields present",
        category: .messageStructure,
        mandatory: true
    )

    func evaluate() async throws -> ConformanceTestResult {
        // evaluate conformance
        return ConformanceTestResult(
            requirement: requirement,
            passed: true,
            details: "All required MSH fields present"
        )
    }
}
```

---

## Common Integration Patterns

### Cross-Module Logging with Correlation IDs

Use a single `UnifiedLogger` instance across all modules with `CorrelationID` to trace a request end-to-end:

```swift
let logger = UnifiedLogger(subsystem: "com.hospital.integration")
let correlationID = CorrelationID.generate()

// In HL7v2Kit parsing
await logger.log(
    category: "v2-parser",
    level: .info,
    message: "Received ADT^A01",
    metadata: LogMetadata(
        values: ["segmentCount": "12"],
        correlationID: correlationID,
        module: "HL7v2Kit"
    )
)

// In transformation layer
await logger.log(
    category: "transform",
    level: .info,
    message: "Transforming to CDA",
    metadata: LogMetadata(
        values: [:],
        correlationID: correlationID,
        module: "HL7v3Kit"
    )
)

// Later: query all logs for a specific correlation ID
let allLogs = await logger.exportLogs()
let traceLogs = allLogs.filter { $0.metadata?.correlationID == correlationID }
```

### Caching Parsed Messages

Cache expensive parsing results to avoid re-parsing:

```swift
let parseCache = SharedCache<String, ParsedMessage>(maxSize: 1_000, defaultTTL: 300)

func parseWithCache(_ rawMessage: String) async throws -> ParsedMessage {
    let key = await SecurityService().sha256(data: Data(rawMessage.utf8)).base64EncodedString()
    if let cached = await parseCache.get(key) {
        return cached
    }
    let parsed = try parser.parse(rawMessage)
    await parseCache.set(key, value: parsed)
    return parsed
}
```

### Secure Message Pipeline

Encrypt messages before persistence and decrypt on retrieval:

```swift
let encryptionKey = EncryptionKey.generate()
let encryptor = MessageEncryptor()

// Encrypt before storing
let encrypted = try encryptor.encrypt(string: rawHL7, using: encryptionKey)

// Store the encrypted payload
let entry = ArchiveEntry(
    messageType: "ADT^A01",
    version: "2.5",
    source: "HIS",
    tags: ["encrypted"],
    content: encrypted.ciphertext.base64EncodedString()
)
try await archive.store(entry)

// Decrypt on retrieval
let retrieved = try await archive.retrieve(id: entry.id)
let decrypted = try encryptor.decryptToString(encrypted, using: encryptionKey)
```

### Audit Trail

Combine logging with the persistence layer for a durable audit trail:

```swift
let logger = UnifiedLogger(subsystem: "com.hospital.audit")
let archive = MessageArchive()

func auditAccess(user: String, resource: String, action: String) async {
    let correlationID = CorrelationID.generate()

    // Log the event
    await logger.log(
        category: "audit",
        level: .info,
        message: "\(user) \(action) \(resource)",
        metadata: LogMetadata(
            values: ["user": user, "action": action, "resource": resource],
            correlationID: correlationID,
            module: "Audit"
        )
    )

    // Persist for compliance
    let entry = ArchiveEntry(
        messageType: "AUDIT",
        version: "1.0",
        source: "AuditService",
        tags: ["audit", action, user],
        content: "\(user) \(action) \(resource) at \(Date())"
    )
    try? await archive.store(entry)
}
```

---

## Configuration Examples

### Logging Configuration

```swift
// Development — verbose logging, small buffer
let devLogger = UnifiedLogger(subsystem: "com.myapp", maxBufferSize: 1_000)
await devLogger.setLogLevel(.debug)

// Production — warnings and above, larger buffer
let prodLogger = UnifiedLogger(subsystem: "com.myapp", maxBufferSize: 50_000)
await prodLogger.setLogLevel(.warning)
```

### Cache Configuration

```swift
// High-throughput — large cache, short TTL
let hotCache = SharedCache<String, Data>(maxSize: 10_000, defaultTTL: 60)

// Reference data — smaller cache, long TTL
let refCache = SharedCache<String, CodeSystem>(maxSize: 500, defaultTTL: 3600)
```

### Security Configuration

```swift
// Generate keys at application startup
let encKey = EncryptionKey.generate(size: 32)   // 256-bit
let signKey = SigningKey.generate(size: 32)      // 256-bit

// Store keys securely (Keychain on Apple platforms)
// Never hardcode or log key material
```

---

## Migrating to Unified Services

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for step-by-step migration instructions covering:

- Replacing `EnhancedLogger` with `UnifiedLogger`
- Adopting `SharedCache` in place of custom caching
- Integrating the `SecurityFramework`
- Using the `Persistence` layer

---

*For architecture details see [ARCHITECTURE.md](ARCHITECTURE.md). For security best practices see [SECURITY_GUIDE.md](SECURITY_GUIDE.md).*
