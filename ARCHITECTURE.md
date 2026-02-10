# HL7kit Architecture

Architectural overview of the HL7kit Swift framework.

---

## Table of Contents

- [Module Overview](#module-overview)
- [Dependency Graph](#dependency-graph)
- [Key Design Patterns](#key-design-patterns)
- [Data Flow](#data-flow)
- [Thread Safety Model](#thread-safety-model)
- [Extension Points](#extension-points)

---

## Module Overview

HL7kit is organized into four Swift Package Manager targets. Each toolkit is a separate library that depends only on `HL7Core`.

### HL7Core

The shared foundation layer. Contains no HL7-version-specific logic.

| File | Responsibility |
|------|---------------|
| `HL7Core.swift` | Base protocols (`HL7Message`, `HL7Segment`, `HL7Field`), common error types |
| `Validation.swift` | Validation framework (rules, accumulators, context) |
| `DataProtocols.swift` | `Parseable`, `Serializable`, transformation protocols |
| `ErrorRecovery.swift` | Error types with context, recovery strategies, retry logic |
| `Logging.swift` | `EnhancedLogger` actor, `LogDestination`/`LogFilter` protocols, `PerformanceTracker` |
| `Benchmarking.swift` | Performance measurement utilities |
| `ParsingStrategies.swift` | Lazy, streaming, chunked, and indexed parsing strategies |
| `ActorPatterns.swift` | `MessageProcessor`, `StreamProcessor`, `MessagePipeline`, `MessageRouter` actors |
| `CommonServices.swift` | `UnifiedLogger`, `SecurityService`, `SharedCache` actors |
| `SecurityFramework.swift` | `MessageEncryptor`, `DigitalSigner`, certificate management, RBAC |
| `Persistence.swift` | `MessageArchive`, `ArchiveIndex`, `PersistenceStore`, export/import |
| `TestingInfrastructure.swift` | `IntegrationTestRunner`, `PerformanceBenchmarkRunner`, `ConformanceTestRunner`, mocks, test data generators |

### HL7v2Kit

HL7 v2.x pipe-delimited messaging toolkit.

| Area | Capabilities |
|------|-------------|
| Parser | Configurable parser with encoding detection, delimiter auto-detection, error recovery modes |
| Builder | Fluent API for constructing messages; MSH builder, segment builder, templates (ADT, ORU, ORM, ACK) |
| Message Types | Typed wrappers for ADT, ORM, ORU, ACK, QRY, QBP with segment accessors and validation |
| Data Types | Primitive (ST, TX, NM, DT, TM, DTM, …) and composite (CE, CX, XPN, XAD, XTN, …) types |
| Structure DB | Message structure definitions for v2.1–2.8 with version detection and validation |
| Validation | Conformance profiles, cardinality, data type validation, value sets |
| Networking | MLLP client/server with TLS, connection pooling, Network.framework on Apple platforms |
| Batch/File | FHS/BHS/BTS/FTS support, streaming API, compression (LZFSE, LZ4, ZLIB, LZMA) |
| Z-Segments | Custom segment definitions with registry, builder, and validation |
| Dev Tools | Message inspector, diff tool, pretty printer, search, test utilities |

### HL7v3Kit

HL7 v3.x XML-based messaging and CDA toolkit.

| Area | Capabilities |
|------|-------------|
| RIM | Act, Entity, Role, Participation, ActRelationship, RoleLink with v3 data types |
| XML Parser | Streaming XML parser, DOM-like API, namespace handling, XPath queries, schema validation |
| CDA R2 | Full Clinical Document Architecture R2 with header participants, sections, entries, narrative |
| Templates | 17+ templates (C-CDA, IHE), inheritance, composition, constraint validation, authoring tools |
| Vocabulary | Code system support, value sets, concept lookup with caching (SNOMED, LOINC, ICD) |
| Transforms | Bidirectional v2↔v3 transformation with builder DSL, data loss tracking, quality metrics |
| Networking | SOAP 1.1/1.2, REST, WS-Security, message queuing, connection pooling, TLS |
| Performance | Object pooling, string interning, XPath cache, lazy section content, streaming XML |
| Doc Processing | Rendering (text/HTML), diff, merge with conflict strategies, versioning |
| Dev Tools | XML inspector, schema validator, test utilities |

### FHIRkit

HL7 FHIR R4 RESTful toolkit.

| Area | Capabilities |
|------|-------------|
| Data Model | 17 primitive types, 11 complex types, Element/Resource/DomainResource protocols |
| Resources | 13+ resources (Patient, Observation, Practitioner, …), Bundle, OperationOutcome |
| Serialization | JSON and XML with streaming Bundle parser, polymorphic resource handling |
| REST Client | Actor-based `FHIRClient` with CRUD, search, history, batch/transaction, pagination, retry |
| Search | Type-safe `FHIRSearchQuery` builder, chained/reverse-chained, _include/_revinclude, compartments |
| Validation | StructureDefinition, FHIRPath evaluator, profile validation, custom rules, terminology binding |
| SMART Auth | OAuth 2.0, PKCE, token management, scope handling, server discovery |
| Terminology | CodeSystem, ValueSet, ConceptMap operations with caching and server integration |
| Operations | $everything, $validate, $convert, $meta, $export, custom operation registry |
| Subscriptions | R5 topic-based, WebSocket transport, REST-hook, event filtering, auto-reconnect |
| Performance | Optimized parsers, `FHIRResourceCache`, streaming Bundle processor, connection pool |

---

## Dependency Graph

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│  HL7v2Kit   │   │  HL7v3Kit   │   │   FHIRkit   │
└──────┬──────┘   └──────┬──────┘   └──────┬──────┘
       │                 │                 │
       └────────────┬────┴────────────┬────┘
                    │                 │
                    ▼                 │
              ┌───────────┐          │
              │  HL7Core  │◄─────────┘
              └───────────┘
                    │
                    ▼
              ┌───────────┐
              │ Foundation │  (Swift standard library)
              └───────────┘
```

**Rules**:

1. Each toolkit depends **only** on `HL7Core` — never on another toolkit.
2. `HL7Core` has **zero** external dependencies; it uses only Foundation.
3. Toolkit-specific tests may import other toolkits for cross-module integration tests, but the library targets do not.

---

## Key Design Patterns

### 1. Actors for Concurrency

All mutable shared state is encapsulated in Swift `actor` types. This eliminates data races at compile time under Swift 6 strict concurrency checking.

```
actor MessageProcessor      — single/batch message processing
actor StreamProcessor        — streaming with back-pressure
actor MessagePipeline        — multi-stage orchestration
actor MessageRouter          — type-based routing
actor UnifiedLogger          — structured log buffer
actor SecurityService        — PHI sanitization, hashing
actor SharedCache<K,V>       — generic LRU cache
actor MessageArchive         — message storage
actor ArchiveIndex           — full-text search index
actor FHIRClient             — FHIR REST operations
actor FHIRSubscriptionManager— subscription lifecycle
```

Cross-actor communication uses `async`/`await`. Data crossing actor boundaries must be `Sendable`.

### 2. Protocols for Extensibility

Core behavior is defined by protocols that consumers can implement:

| Protocol | Module | Purpose |
|----------|--------|---------|
| `Parseable` | HL7Core | Types that can be parsed from raw data |
| `Serializable` | HL7Core | Types that can be serialized to data |
| `LogDestination` | HL7Core | Custom log sinks (console, file, remote) |
| `LogFilter` | HL7Core | Custom log filtering logic |
| `PersistenceStore` | HL7Core | Custom storage backends |
| `IntegrationTest` | HL7Core | Custom integration tests |
| `BenchmarkCase` | HL7Core | Custom benchmarks |
| `ConformanceTestCase` | HL7Core | Conformance evaluators |
| `FHIRURLSession` | FHIRkit | HTTP session abstraction for testing |

### 3. Value Types and Copy-on-Write

Message data structures use Swift `struct` types wherever possible. Large containers (e.g., segment arrays, XML DOM trees) use copy-on-write via reference-counted internal storage to avoid unnecessary copies.

### 4. Result Builders and Fluent APIs

Message construction uses fluent builder patterns:

```swift
// HL7 v2.x
let msg = HL7v2MessageBuilder()
    .msh { $0.sendingApplication("MyApp").receivingFacility("Hospital") }
    .segment("PID") { $0.field(3, "12345").field(5, "DOE^JOHN") }
    .build()

// CDA R2
let doc = CDADocumentBuilder()
    .templateId("2.16.840.1.113883.10.20.22.1.1")
    .patient { $0.name("Doe", "John").gender(.male) }
    .section { $0.code("11348-0").title("History of Past Illness") }
    .build()
```

### 5. Strategy Pattern for Parsing

The `ParsingStrategies` module provides interchangeable parsing strategies:

| Strategy | Use Case |
|----------|----------|
| Eager | Small messages, full random access needed |
| Lazy | Large messages, only specific segments accessed |
| Streaming | Very large files, constant memory |
| Chunked | Batch processing with bounded memory |
| Indexed | Repeated random access with fast lookup |

### 6. Observer/Pipeline Pattern

`MessagePipeline` and `MessageRouter` compose actors into processing chains:

```
Input → Router → [V2 Processor] → Pipeline → Archive
                 [V3 Processor]
                 [FHIR Processor]
```

---

## Data Flow

### HL7 v2.x Message Processing

```
┌──────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
│ Raw      │───►│ Parser   │───►│ Validation │───►│ Typed    │
│ Bytes    │    │ (MLLP    │    │ Engine     │    │ Message  │
│ (TCP/    │    │  deframe, │    │ (conformance│    │ (ADT,   │
│  File)   │    │  decode)  │    │  profiles)  │    │  ORU,..)│
└──────────┘    └──────────┘    └────────────┘    └──────────┘
                                                        │
                                                        ▼
                                                  ┌──────────┐
                                                  │ Archive/ │
                                                  │ Transform│
                                                  │ / Route  │
                                                  └──────────┘
```

### HL7 v3.x / CDA Processing

```
┌──────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
│ XML      │───►│ XML      │───►│ Schema +   │───►│ CDA      │
│ Document │    │ Parser   │    │ Template   │    │ Document │
│ (SOAP/   │    │ (stream/ │    │ Validation │    │ Object   │
│  REST)   │    │  DOM)    │    │            │    │          │
└──────────┘    └──────────┘    └────────────┘    └──────────┘
                                                        │
                                                        ▼
                                                  ┌──────────┐
                                                  │ Render/  │
                                                  │ Merge/   │
                                                  │ Version  │
                                                  └──────────┘
```

### FHIR Resource Processing

```
┌──────────┐    ┌──────────┐    ┌────────────┐    ┌──────────┐
│ JSON/XML │───►│ Codable  │───►│ FHIR       │───►│ Typed    │
│ Payload  │    │ Decoder  │    │ Validator  │    │ Resource │
│ (REST    │    │ (stream/ │    │ (profiles, │    │ (Patient,│
│  API)    │    │  batch)  │    │  FHIRPath) │    │  Obs,..) │
└──────────┘    └──────────┘    └────────────┘    └──────────┘
                                                        │
                                                        ▼
                                                  ┌──────────┐
                                                  │ Cache /  │
                                                  │ Subscribe│
                                                  │ / Operate│
                                                  └──────────┘
```

### Cross-Module Data Flow

```
┌──────────┐         ┌────────────┐         ┌──────────┐
│ HL7v2Kit │────────►│ Transform  │────────►│ HL7v3Kit │
│ Message  │  v2→v3  │ Engine     │  CDA    │ Document │
└──────────┘         └────────────┘         └──────────┘
      │                                          │
      │         ┌────────────┐                   │
      └────────►│ Persistence│◄──────────────────┘
                │ (Archive)  │
                └────────────┘
                      │
                      ▼
                ┌────────────┐
                │ Export/    │
                │ Import     │
                │ (JSON)     │
                └────────────┘
```

---

## Thread Safety Model

### Guarantees

1. **No data races**: Swift 6 strict concurrency mode is enabled (`swiftLanguageModes: [.v6]`). The compiler rejects code that could produce data races.
2. **Actor isolation**: All mutable shared state lives inside actors. Access is serialized by the Swift runtime.
3. **Sendable enforcement**: Types that cross actor boundaries conform to `Sendable`. Value types (structs, enums) are `Sendable` by default when all stored properties are `Sendable`.
4. **No locks or mutexes**: The codebase uses zero manual locking primitives. All synchronization is provided by the actor model.

### Actor Hierarchy

```
Application
├── MessageRouter (routes by type)
│   ├── MessageProcessor (v2)
│   ├── MessageProcessor (v3)
│   └── MessageProcessor (fhir)
├── UnifiedLogger (shared)
├── SharedCache (per data type)
├── MessageArchive (shared)
├── ArchiveIndex (shared)
└── SecurityService (shared)
```

### Concurrency Patterns

| Pattern | Where Used | Description |
|---------|-----------|-------------|
| Task groups | `MessageProcessor.processBatch` | Bounded concurrency with `maxConcurrency` parameter |
| AsyncSequence | `StreamProcessor`, `XMLElementStream` | Lazy, demand-driven data processing |
| AsyncThrowingStream | FHIR Subscriptions, MLLP | Continuous event delivery with error propagation |
| Actor composition | `MessagePipeline` | Actors that hold references to other actors |
| Lazy child actors | `MessageRouter` | Actors created on first use |

### Guidelines for Consumers

- Always `await` when calling actor methods.
- Use `Task {}` or `TaskGroup` for concurrent operations, not `DispatchQueue`.
- Pass only `Sendable` types across actor boundaries.
- Prefer `struct` for data models; use `actor` for stateful services.

---

## Extension Points

### Custom Log Destinations

Implement the `LogDestination` protocol to send logs to a remote service, file, or monitoring system:

```swift
struct RemoteLogDestination: LogDestination {
    func write(_ entry: LogEntry) {
        // send to your logging service
    }
}

let logger = EnhancedLogger()
await logger.addDestination(RemoteLogDestination())
```

### Custom Persistence Backends

Implement `PersistenceStore` to use Core Data, CloudKit, SQLite, or any other storage:

```swift
actor CoreDataStore: PersistenceStore {
    func save<T: Codable & Sendable>(_ value: T, forKey key: String) async throws { ... }
    func load<T: Codable & Sendable>(forKey key: String) async throws -> T? { ... }
    func delete(forKey key: String) async throws { ... }
    func allKeys() async throws -> [String] { ... }
    func clear() async throws { ... }
}
```

### Custom Validation Rules

Add domain-specific validation rules for any message type:

```swift
// HL7 v2.x
let rule = CustomValidationRule(
    id: "CHECK-MRN",
    description: "MRN must be numeric",
    validate: { message in
        // validate MRN field
    }
)

// FHIR
let fhirRule = FHIRCustomValidationRule.valueConstraint(
    path: "Patient.birthDate",
    constraint: { value in value != nil }
)
```

### Custom FHIR Operations

Register custom operations with the `FHIROperationRegistry`:

```swift
let registry = FHIROperationRegistry()
await registry.register(
    name: "$my-custom-op",
    operation: MyCustomOperation()
)
```

### Custom Test Cases

Write integration tests and benchmarks using the provided protocols:

```swift
struct MyBenchmark: BenchmarkCase {
    let name = "my-benchmark"
    let warmupCount = 3
    let iterationCount = 50
    func measure() async throws {
        // code to measure
    }
}
```

---

*See also: [CONCURRENCY_MODEL.md](CONCURRENCY_MODEL.md) for deep-dive on the actor architecture, [PERFORMANCE.md](PERFORMANCE.md) for optimization strategies.*
