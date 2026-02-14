# HL7kit Migration Guide

Step-by-step instructions for migrating to HL7kit 1.0.0 and between internal service patterns.

---

## Table of Contents

- [Migrating to 1.0.0](#migrating-to-100)
- [Migrating from EnhancedLogger to UnifiedLogger](#migrating-from-enhancedlogger-to-unifiedlogger)
- [Migrating from Custom Caching to SharedCache](#migrating-from-custom-caching-to-sharedcache)
- [Adopting the Security Framework](#adopting-the-security-framework)
- [Integrating the Persistence Layer](#integrating-the-persistence-layer)
- [Version Compatibility Notes](#version-compatibility-notes)

---

## Migrating to 1.0.0

### Overview

HL7kit 1.0.0 is the first stable release. If you were using pre-release or development versions, this section covers the key changes and migration paths.

### Breaking Changes from Pre-1.0

**Good News:** Version 1.0.0 represents the first official release with no breaking changes from previous versions, as there were no official pre-1.0 releases. All APIs are now stable and will follow semantic versioning going forward.

### What's New in 1.0.0

1. **API Stability**: All public APIs are now stable and documented
2. **Swift 6.2 Strict Concurrency**: Full Sendable conformance for all public types
3. **Comprehensive Test Coverage**: 2,100+ tests with 90%+ code coverage
4. **Complete Documentation**: DocC documentation for all public APIs
5. **Production Security Guidance**: See [SECURITY_GUIDE.md](SECURITY_GUIDE.md) for production requirements

### Installation

HL7kit 1.0.0 is distributed via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/HL7kit.git", from: "1.0.0")
]
```

### Module Organization

HL7kit is organized into four main modules:

- **HL7Core**: Shared utilities, protocols, and services
- **HL7v2Kit**: HL7 v2.x message processing (versions 2.1-2.8)
- **HL7v3Kit**: HL7 v3.x and CDA R2 document processing
- **FHIRkit**: FHIR R4 resource handling and RESTful client

Import only the modules you need:

```swift
import HL7v2Kit  // For HL7 v2.x
import HL7v3Kit  // For HL7 v3.x / CDA
import FHIRkit   // For FHIR
import HL7Core   // For shared utilities
```

### Swift 6.2 Concurrency

All HL7kit types are designed for Swift 6.2's strict concurrency model:

- All mutable state is protected by actors
- All public types conform to `Sendable` where appropriate
- Async/await is used throughout for asynchronous operations
- No data races or concurrency warnings in strict mode

### Security Requirements for Production

**Important:** The cryptographic implementations in 1.0.0 are suitable for development and testing but **must be upgraded for production** use with Protected Health Information (PHI):

```swift
// ⚠️ Demo-grade encryption (development only)
let encryptor = MessageEncryptor()
let encrypted = try await encryptor.encrypt(data, key: key)

// ✅ Production: Use CryptoKit or OpenSSL
import CryptoKit
let symmetricKey = SymmetricKey(size: .bits256)
let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
```

See [SECURITY_GUIDE.md](SECURITY_GUIDE.md) and [SECURITY_VULNERABILITY_ASSESSMENT.md](SECURITY_VULNERABILITY_ASSESSMENT.md) for complete production security requirements.

### Performance Optimization

HL7kit is optimized for performance out of the box:

- **HL7 v2.x**: 50,000+ messages/second throughput
- **HL7 v3.x**: 5,000+ CDA documents/second
- **FHIR**: 10,000+ resources/second
- **Memory**: <1MB per message for typical ADT/ORU messages

For advanced optimization, see [PERFORMANCE.md](PERFORMANCE.md) and the performance examples in [Examples/PerformanceOptimization.swift](Examples/PerformanceOptimization.swift).

### Getting Help

- **Documentation**: [README.md](README.md)
- **Examples**: [Examples/](Examples/)
- **Standards**: [HL7V2X_STANDARDS.md](HL7V2X_STANDARDS.md), [HL7V3X_STANDARDS.md](HL7V3X_STANDARDS.md), [FHIR_STANDARDS.md](FHIR_STANDARDS.md)
- **Issues**: [GitHub Issues](https://github.com/Raster-Lab/HL7kit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Raster-Lab/HL7kit/discussions)

---

## Migrating from EnhancedLogger to UnifiedLogger

### Why Migrate?

`EnhancedLogger` (in `Logging.swift`) is a general-purpose logging actor with pluggable destinations and filters. `UnifiedLogger` (in `CommonServices.swift`) adds:

- **Subsystem and category tagging** for structured log queries
- **Correlation ID support** for distributed tracing across modules
- **Module metadata** to identify which toolkit generated a log entry
- **Built-in buffer management** with configurable max size and circular eviction
- **Export with filtering** by level, category, and time range

`EnhancedLogger` remains available for consumers who need custom `LogDestination` or `LogFilter` implementations. Both can coexist in the same application.

### Before (EnhancedLogger)

```swift
import HL7Core

let logger = EnhancedLogger()
await logger.addDestination(ConsoleLogDestination())
await logger.addFilter(LevelLogFilter(minimumLevel: .info))

let entry = LogEntry(
    level: .info,
    message: "Parsed ADT message",
    source: LogSource()
)
await logger.log(entry)
```

### After (UnifiedLogger)

```swift
import HL7Core

let logger = UnifiedLogger(subsystem: "com.myapp.hl7", maxBufferSize: 10_000)
await logger.setLogLevel(.info)

let correlationID = CorrelationID.generate()
await logger.log(
    category: "parsing",
    level: .info,
    message: "Parsed ADT message",
    metadata: LogMetadata(
        values: ["messageType": "ADT^A01"],
        correlationID: correlationID,
        module: "HL7v2Kit"
    )
)
```

### Migration Steps

1. **Create a `UnifiedLogger` instance** with a subsystem identifier and buffer size.
2. **Replace `LogEntry` construction** with direct calls to `logger.log(category:level:message:metadata:)`.
3. **Add `CorrelationID`** to trace requests across modules.
4. **Replace `exportLogs()` calls** — `UnifiedLogger.exportLogs(level:category:since:)` supports filtering natively.
5. **Remove `LogDestination` / `LogFilter` setup** unless you need custom routing (in which case keep `EnhancedLogger` alongside `UnifiedLogger`).

### Keeping Both Loggers

If you need custom destinations (e.g., file or remote logging), use both:

```swift
// UnifiedLogger for structured, in-memory logging
let unifiedLogger = UnifiedLogger(subsystem: "com.myapp.hl7")

// EnhancedLogger for custom destinations
let enhancedLogger = EnhancedLogger()
await enhancedLogger.addDestination(FileLogDestination(path: "/var/log/hl7.log"))

// Log to both
func logBoth(message: String, level: LogLevel) async {
    await unifiedLogger.log(category: "app", level: level, message: message)
    await enhancedLogger.log(LogEntry(level: level, message: message, source: LogSource()))
}
```

---

## Migrating from Custom Caching to SharedCache

### Why Migrate?

`SharedCache<Key, Value>` provides:

- **Generic, type-safe** caching with any `Hashable & Sendable` key and `Sendable` value
- **LRU eviction** when the cache exceeds `maxSize`
- **TTL expiration** with per-entry or default TTL
- **Hit/miss statistics** for monitoring cache effectiveness
- **Actor-based** thread safety — no manual locking needed

### Before (Custom Dictionary Cache)

```swift
// Typical hand-rolled cache — not thread-safe!
var cache: [String: ParsedMessage] = [:]
let lock = NSLock()

func getCached(_ key: String) -> ParsedMessage? {
    lock.lock()
    defer { lock.unlock() }
    return cache[key]
}

func setCached(_ key: String, value: ParsedMessage) {
    lock.lock()
    defer { lock.unlock() }
    cache[key] = value
    // No eviction, no TTL, unbounded growth
}
```

### After (SharedCache)

```swift
import HL7Core

let cache = SharedCache<String, ParsedMessage>(
    maxSize: 1_000,
    defaultTTL: 300 // 5 minutes
)

// Get — returns nil if expired or missing
if let msg = await cache.get("msg-key") {
    // use cached message
}

// Set — automatically evicts LRU entry if at capacity
await cache.set("msg-key", value: parsedMessage)

// Set with custom TTL
await cache.set("ref-data", value: codeSystem, ttl: 3600) // 1 hour

// Monitor performance
let stats = await cache.statistics
print("Hit rate: \(stats.hitRate)") // e.g. 0.85
```

### Migration Steps

1. **Replace `Dictionary` + lock** with `SharedCache<Key, Value>`.
2. **Add `await`** to all cache access calls (it is an actor).
3. **Configure `maxSize`** based on expected working set.
4. **Configure `defaultTTL`** based on data freshness requirements.
5. **Remove manual eviction code** — LRU eviction is automatic.
6. **Add statistics monitoring** to tune cache size over time.

---

## Adopting the Security Framework

### Why Adopt?

The security framework centralizes:

- **PHI sanitization** — consistent masking across all modules
- **Input validation** — prevent malformed or malicious input
- **Encryption** — encrypt messages at rest (with production caveats)
- **Digital signatures** — verify message integrity
- **Secure random generation** — cryptographic randomness

### Step 1: PHI Sanitization

Add PHI sanitization to all logging paths:

```swift
import HL7Core

let security = SecurityService()

// Before logging any message content:
let safe = await security.sanitizePHI(in: rawMessageContent)
await logger.log(category: "processing", level: .info, message: safe)
```

### Step 2: Input Validation

Validate all external inputs:

```swift
let validationResult = await security.validateInput(userProvidedData)
guard validationResult.isValid else {
    for error in validationResult.errors {
        await logger.log(category: "validation", level: .warning, message: error)
    }
    throw InputError.invalid
}
```

### Step 3: Encryption at Rest

Encrypt sensitive messages before persisting:

```swift
let key = EncryptionKey.generate()
let encryptor = MessageEncryptor()

// Encrypt
let encrypted = try encryptor.encrypt(string: message.rawContent, using: key)

// Store encrypted content
let entry = ArchiveEntry(
    messageType: message.type,
    version: message.version,
    source: "encrypted",
    tags: ["encrypted"],
    content: encrypted.ciphertext.base64EncodedString()
)
try await archive.store(entry)
```

> **⚠️** Replace `MessageEncryptor` with `CryptoKit.AES.GCM` for production deployments. See [SECURITY_GUIDE.md](SECURITY_GUIDE.md#encryption-caveats).

### Step 4: Digital Signatures

Sign outgoing messages for integrity verification:

```swift
let signingKey = SigningKey.generate()
let signer = DigitalSigner()

let signature = signer.sign(string: outgoingMessage, using: signingKey)
// Attach signature.signatureHex to the message metadata
```

---

## Integrating the Persistence Layer

### Why Integrate?

The persistence layer provides:

- **Thread-safe message archival** via the `MessageArchive` actor
- **Full-text search** with TF-IDF relevance scoring via `ArchiveIndex`
- **JSON export/import** for data portability and backup
- **Pluggable backends** via the `PersistenceStore` protocol

### Step 1: Store Messages

```swift
import HL7Core

let archive = MessageArchive()

let entry = ArchiveEntry(
    messageType: "ADT^A01",
    version: "2.5",
    source: "HIS-System",
    tags: ["admit", "inpatient"],
    content: rawHL7String
)
try await archive.store(entry)
```

### Step 2: Enable Search

```swift
let index = ArchiveIndex()

// Index the entry
await index.addEntry(entry)

// Search
let results = await index.search(query: "admit patient")
for result in results {
    print("\(result.entry.id) — score: \(result.relevanceScore)")
}
```

### Step 3: Export for Backup

```swift
let exporter = DataExporter()
let jsonData = try exporter.exportJSON(from: archive)
// Write jsonData to file or send to backup service
```

### Step 4: Import from Backup

```swift
let importer = DataImporter()
let result = try await importer.importJSON(jsonData, into: archive)
print("Imported \(result.imported) entries, skipped \(result.skipped)")
```

### Step 5: Custom Storage Backend

Implement `PersistenceStore` for your preferred storage engine:

```swift
actor SQLiteStore: PersistenceStore {
    func save<T: Codable & Sendable>(_ value: T, forKey key: String) async throws {
        let data = try JSONEncoder().encode(value)
        // INSERT OR REPLACE into SQLite
    }

    func load<T: Codable & Sendable>(forKey key: String) async throws -> T? {
        // SELECT from SQLite, decode
    }

    func delete(forKey key: String) async throws {
        // DELETE from SQLite
    }

    func allKeys() async throws -> [String] {
        // SELECT DISTINCT key FROM store
    }

    func clear() async throws {
        // DELETE FROM store
    }
}
```

---

## Version Compatibility Notes

### Swift Version

| HL7kit Version | Minimum Swift | Swift Language Mode |
|----------------|---------------|---------------------|
| 1.x | 6.0 | `.v6` (strict concurrency) |

HL7kit requires Swift 6.0+ and runs with strict concurrency checking enabled. All public types are `Sendable`.

### Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| macOS | 13.0 |
| iOS | 16.0 |
| tvOS | 16.0 |
| watchOS | 9.0 |
| visionOS | 1.0 |

### Module Coexistence

All Phase 7 services live in `HL7Core` and do not conflict with earlier APIs:

| Old API | New API | Status |
|---------|---------|--------|
| `EnhancedLogger` | `UnifiedLogger` | Both available; use `UnifiedLogger` for new code |
| `PerformanceTracker` | `PerformanceBenchmarkRunner` | Both available; `PerformanceBenchmarkRunner` adds statistical analysis |
| Custom `Dictionary` caches | `SharedCache` | Migrate to `SharedCache` for thread safety |
| Manual PHI handling | `SecurityService` | Adopt `SecurityService` for consistency |
| N/A | `MessageArchive` | New — no predecessor |
| N/A | `ArchiveIndex` | New — no predecessor |
| N/A | `MessageEncryptor` | New — no predecessor |
| N/A | `DigitalSigner` | New — no predecessor |

### Breaking Changes

Phase 7 introduces **no breaking changes**. All new types are additive. Existing code continues to compile and work without modification.

### Deprecation Plan

No APIs are deprecated in this release. Future releases may deprecate `EnhancedLogger` in favor of `UnifiedLogger` with at least one major version of overlap.

---

*See also: [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) for service usage examples, [SECURITY_GUIDE.md](SECURITY_GUIDE.md) for security best practices, [ARCHITECTURE.md](ARCHITECTURE.md) for system design.*