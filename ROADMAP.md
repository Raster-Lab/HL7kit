# HL7kit — Comprehensive Roadmap

> A pure-Swift HL7 framework for Apple platforms, inspired by [HAPI](https://hapifhir.github.io/hapi-hl7v2/), targeting HL7 v2.x and v3.x. Optimised for low memory, low CPU, and high network performance. Built with Swift 6.2 structured concurrency.

---

## Table of Contents

1. [Vision & Goals](#vision--goals)
2. [Architecture Overview](#architecture-overview)
3. [Project Structure](#project-structure)
4. [Phase 1 — HL7 v2.x Toolkit](#phase-1--hl7-v2x-toolkit)
5. [Phase 2 — HL7 v3 Toolkit](#phase-2--hl7-v3-toolkit)
6. [Phase 3 — Shared Infrastructure](#phase-3--shared-infrastructure)
7. [Phase 4 — Performance & Hardening](#phase-4--performance--hardening)
8. [Phase 5 — Documentation & Community](#phase-5--documentation--community)
9. [Non-Goals](#non-goals)
10. [Technology Decisions](#technology-decisions)
11. [Milestone Summary](#milestone-summary)

---

## Vision & Goals

| Goal | Description |
|------|-------------|
| **Pure Swift** | No C/Obj-C bridging unless Apple frameworks require it. Target Swift 6.2 with strict concurrency. |
| **Apple Platforms** | macOS, iOS, iPadOS, watchOS, visionOS — use `Foundation`, `Network.framework`, and `XMLParser`/`XMLDocument` directly. |
| **Low Resource Usage** | Zero-copy parsing where possible; value-type models; lazy segment/field evaluation; streaming network I/O. |
| **Two Toolkits** | HL7 v2.x (pipe-delimited) and v3 (XML/RIM-based) as separate library targets sharing a thin common layer. |
| **HAPI-grade Features** | Parsing, encoding, validation, terser-style paths, conformance profiles, MLLP transport, and message building. |
| **FHIR Excluded** | HL7 FHIR is explicitly out of scope and will be a separate project. |

---

## Architecture Overview

```
HL7kit (Swift Package)
├── HL7Core            # Shared types, protocols, errors, utilities
├── HL7v2              # HL7 v2.x parsing, models, validation, transport
├── HL7v3              # HL7 v3 RIM models, CDA parsing, XML encoding
└── Tests
    ├── HL7CoreTests
    ├── HL7v2Tests
    └── HL7v3Tests
```

### Design Principles

- **Protocol-oriented** — core behaviours defined as protocols (`Parsable`, `Encodable`, `Validatable`).
- **Value types first** — messages, segments, fields are structs; actors only for network I/O state.
- **Lazy evaluation** — segments and fields parsed on first access, not up-front.
- **Sendable everywhere** — all models conform to `Sendable` for safe cross-actor use.
- **Swift concurrency native** — `async/await`, `AsyncSequence`, `TaskGroup` for network and bulk processing.

---

## Project Structure

```
Package.swift
Sources/
  HL7Core/
    Protocols/
      Parsable.swift           # Protocol for types that can be parsed from raw data
      Encodable.swift          # Protocol for types that can encode to wire format
      Validatable.swift        # Protocol for types supporting validation
    Models/
      HL7Version.swift         # Enum for HL7 version identification
      HL7Error.swift           # Unified error types
      DataType.swift           # Shared primitive data types (ST, NM, DT, TS, etc.)
    Utilities/
      StringSlicing.swift      # High-performance substring utilities
      DateParsing.swift        # HL7 date/time ↔ Foundation.Date conversion
  HL7v2/
    Parser/
      MessageParser.swift      # Top-level v2 message parser (ER7 + XML)
      SegmentParser.swift      # Segment-level parser
      FieldParser.swift        # Field/component/subcomponent parser
      Terser.swift             # Path-based field accessor (e.g. "PID-3-1")
    Models/
      Message.swift            # HL7 v2 Message model
      Segment.swift            # Segment model (MSH, PID, OBX, …)
      Field.swift              # Field model with component access
      Component.swift          # Component / sub-component model
      EncodingCharacters.swift # MSH-configurable delimiters
    Builder/
      MessageBuilder.swift     # Fluent API for constructing messages
      SegmentBuilder.swift     # Segment-level builder
    Validation/
      MessageValidator.swift   # Structural & content validation
      ConformanceProfile.swift # HL7 conformance profile support
      TableLookup.swift        # HL7 table value validation
    Encoding/
      ER7Encoder.swift         # Encode to pipe-delimited ER7 format
      XMLEncoder.swift         # Encode to HL7 v2 XML format
    Transport/
      MLLPFramer.swift         # MLLP framing (0x0B … 0x1C 0x0D)
      MLLPClient.swift         # Async MLLP client using Network.framework
      MLLPServer.swift         # Async MLLP listener/server
      AckGenerator.swift       # Generate ACK/NAK responses
    Versions/
      v21/ … v28/              # Version-specific segment definitions & tables
  HL7v3/
    RIM/
      Act.swift                # RIM Act class hierarchy
      Entity.swift             # RIM Entity class hierarchy
      Role.swift               # RIM Role class hierarchy
      Participation.swift      # RIM Participation
      ActRelationship.swift    # RIM ActRelationship
      RoleLink.swift           # RIM RoleLink
    DataTypes/
      V3DataType.swift         # HL7 v3 data types (II, CD, CE, TS, etc.)
      NullFlavor.swift         # Null flavour vocabulary
    CDA/
      CDADocument.swift        # CDA R2 document model
      CDAHeader.swift          # CDA header (record target, author, custodian)
      CDABody.swift            # CDA body (sections, entries, narratives)
      CDAParser.swift          # Parse CDA XML → Swift models
      CDAEncoder.swift         # Encode Swift models → CDA XML
    Vocabulary/
      CodeSystem.swift         # OID-based code system registry
      ValueSet.swift           # Value set definitions
    Validation/
      SchemaValidator.swift    # XSD-based validation
      SchematronValidator.swift # Schematron rule validation
    Transport/
      WebServiceClient.swift   # SOAP/HTTP web service client for v3
Tests/
  HL7CoreTests/
  HL7v2Tests/
  HL7v3Tests/
```

---

## Phase 1 — HL7 v2.x Toolkit

> **Goal:** Feature-complete HL7 v2.x parsing, encoding, validation, and MLLP transport.

### Milestone 1.1 — Core Parser & Models

- [ ] Define `Message`, `Segment`, `Field`, `Component` value-type models
- [ ] Implement `EncodingCharacters` (dynamic delimiter support from MSH-1/MSH-2)
- [ ] Build the ER7 (pipe-delimited) parser with lazy field evaluation
- [ ] Implement `Terser` for path-based field access (`PID-3-1`, `OBX(2)-5`)
- [ ] Handle segment repetition and field repetition (`~` delimiter)
- [ ] Handle escape sequences (`\F\`, `\S\`, `\R\`, `\E\`, `\T\`, `\.br\`, `\Xhh\`)
- [ ] Unit tests with real-world ADT, ORM, ORU, MDM message samples

### Milestone 1.2 — Message Builder & Encoding

- [ ] Fluent `MessageBuilder` API for programmatic message construction
- [ ] `SegmentBuilder` with type-safe field setters
- [ ] `ER7Encoder` — serialise models back to pipe-delimited wire format
- [ ] `XMLEncoder` — serialise to HL7 v2 XML representation
- [ ] Round-trip tests: parse → encode → re-parse identity checks

### Milestone 1.3 — Validation Engine

- [ ] Required/optional field validation per message type
- [ ] Data-type validation (length, format, table values)
- [ ] Conformance profile loading (HL7 v2 profiles)
- [ ] Table lookup validation (HL7 Table 0001, 0003, 0076, etc.)
- [ ] Custom validation rule support via protocol extension
- [ ] Validation result model with severity levels (error, warning, info)

### Milestone 1.4 — MLLP Transport

- [ ] `MLLPFramer` — frame/un-frame messages with start (0x0B) and end (0x1C 0x0D) bytes
- [ ] `MLLPClient` using `NWConnection` (Network.framework) with async/await
- [ ] `MLLPServer` using `NWListener` for accepting inbound connections
- [ ] `AckGenerator` — auto-generate MSA-based ACK/NAK messages
- [ ] TLS support via Network.framework `NWProtocolTLS`
- [ ] Connection keep-alive and timeout configuration
- [ ] Backpressure handling using `AsyncStream`

### Milestone 1.5 — Version-Specific Definitions

- [ ] Segment definitions for HL7 v2.1 through v2.8
- [ ] Version-aware validation rules
- [ ] Auto-detection of message version from MSH-12

---

## Phase 2 — HL7 v3 Toolkit

> **Goal:** Model the RIM, parse/encode CDA documents, and support v3 web service transport.

### Milestone 2.1 — RIM Core Models

- [ ] Implement the six RIM backbone classes: `Act`, `Entity`, `Role`, `Participation`, `ActRelationship`, `RoleLink`
- [ ] Model RIM class attributes and associations
- [ ] Implement HL7 v3 data types: `II`, `CD`, `CE`, `CS`, `ST`, `TS`, `PQ`, `IVL`, `PIVL`, `AD`, `TEL`, `EN`, `ON`
- [ ] `NullFlavor` enumeration and handling
- [ ] Protocol-based polymorphism for RIM class specialisations

### Milestone 2.2 — CDA Document Support

- [ ] `CDADocument` model covering CDA R2 structure
- [ ] `CDAHeader` — record target, author, custodian, authenticator, informant
- [ ] `CDABody` — structured body with sections, entries, and narrative blocks
- [ ] `CDAParser` — parse CDA XML using `Foundation.XMLParser` (event-driven, low-memory)
- [ ] `CDAEncoder` — encode CDA models to well-formed XML
- [ ] Support for CDA Levels 1, 2, and 3
- [ ] Namespace-aware parsing (urn:hl7-org:v3)

### Milestone 2.3 — Vocabulary & Code Systems

- [ ] OID-based code system registry
- [ ] Value set definitions and membership checking
- [ ] SNOMED CT, LOINC, ICD-10, RxNorm code system stubs
- [ ] Vocabulary binding validation (CNE, CWE)

### Milestone 2.4 — Validation

- [ ] XSD schema validation (leveraging `libxml2` through Foundation)
- [ ] Schematron-style rule validation
- [ ] Template-based validation (C-CDA templates)
- [ ] Error reporting with XPath locations

### Milestone 2.5 — Transport

- [ ] SOAP/HTTP web service client using `URLSession`
- [ ] WSDL-informed message construction
- [ ] Async request/response with structured concurrency

---

## Phase 3 — Shared Infrastructure

> **Goal:** Cross-cutting concerns shared by both toolkits.

### Milestone 3.1 — Common Data Types & Utilities

- [ ] Shared HL7 primitive types (ST, NM, DT, TS, ID, IS, TX, FT)
- [ ] Date/time parsing and formatting (HL7 `YYYYMMDDHHMMSS.SSS±ZZZZ` ↔ `Date`)
- [ ] High-performance `Substring`-based string slicing (zero-copy where possible)
- [ ] Numeric parsing with overflow protection

### Milestone 3.2 — Error Handling

- [ ] Unified `HL7Error` enum with associated values
- [ ] Structured error context (segment index, field index, component path)
- [ ] Localised error descriptions

### Milestone 3.3 — Logging & Diagnostics

- [ ] Integration with `os.Logger` (Apple Unified Logging)
- [ ] Configurable log levels per subsystem
- [ ] Message hex-dump utility for debugging transport issues
- [ ] Performance signpost integration (`os_signpost`)

### Milestone 3.4 — Security

- [ ] PHI (Protected Health Information) redaction utilities
- [ ] Audit log helpers
- [ ] TLS certificate pinning support for MLLP and HTTP transports

---

## Phase 4 — Performance & Hardening

> **Goal:** Optimise for production workloads and ensure reliability.

### Milestone 4.1 — Performance Optimisation

- [ ] Benchmark suite using `swift-benchmark` or Instruments
- [ ] Profile and optimise hot paths (parser, encoder, MLLP framer)
- [ ] Memory allocation audit — minimise heap allocations in parser
- [ ] Copy-on-write optimisation for large messages
- [ ] Contiguous memory layout for batch processing

### Milestone 4.2 — Concurrency Hardening

- [ ] Full `Sendable` conformance audit
- [ ] Actor re-entrancy review for transport actors
- [ ] Cancellation and timeout handling in all async operations
- [ ] Structured concurrency for bulk message processing (`TaskGroup`)

### Milestone 4.3 — Resilience

- [ ] Graceful handling of malformed messages (partial parse results)
- [ ] Connection retry with exponential backoff (MLLP)
- [ ] Circuit-breaker pattern for transport layer
- [ ] Memory pressure handling (`DispatchSource.makeMemoryPressureSource`)

### Milestone 4.4 — Platform Testing

- [ ] macOS unit and integration tests
- [ ] iOS simulator tests
- [ ] watchOS compatibility validation
- [ ] visionOS compatibility validation

---

## Phase 5 — Documentation & Community

> **Goal:** Make the framework easy to adopt and contribute to.

### Milestone 5.1 — API Documentation

- [ ] DocC documentation catalogue with tutorials
- [ ] Symbol-level documentation for all public APIs
- [ ] Code examples for common workflows (parse, build, validate, send)

### Milestone 5.2 — Guides & Tutorials

- [ ] Getting Started guide
- [ ] Migration guide from HAPI (Java) patterns
- [ ] MLLP integration guide with real-world scenarios
- [ ] CDA document creation walkthrough

### Milestone 5.3 — CI/CD & Releases

- [ ] GitHub Actions CI pipeline (build, test, lint on macOS)
- [ ] Automated DocC documentation deployment
- [ ] Semantic versioning and release automation
- [ ] Swift Package Index registration

### Milestone 5.4 — Community

- [ ] Contributing guidelines (`CONTRIBUTING.md`)
- [ ] Code of conduct
- [ ] Issue and PR templates
- [ ] Sample applications (CLI tool, macOS app)

---

## Non-Goals

| Excluded | Reason |
|----------|--------|
| **HL7 FHIR** | Will be a separate project |
| **Non-Apple platforms** | Linux/Windows not targeted; use native Apple frameworks |
| **Objective-C API surface** | Pure Swift; no `@objc` exports |
| **GUI components** | This is a framework/library, not an application |
| **Database storage** | Persistence is the consumer's responsibility |

---

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | Swift 6.2 | Strict concurrency, actors, structured concurrency |
| Package Manager | Swift Package Manager | Native, no external tooling |
| Networking | `Network.framework` (`NWConnection`, `NWListener`) | Low-level TCP with TLS, zero-copy, Apple-optimised |
| HTTP Client | `URLSession` | Native, async/await support, ATS compliance |
| XML Parsing | `Foundation.XMLParser` (SAX) | Event-driven, low memory footprint |
| XML Writing | `Foundation.XMLDocument` / manual string building | Full control, namespace support |
| Logging | `os.Logger` | Unified logging, zero-cost when disabled |
| Testing | `XCTest` + Swift Testing | Standard Apple test frameworks |
| Documentation | DocC | Native Swift documentation system |
| Benchmarking | `swift-benchmark` / Instruments | Performance profiling |

---

## Milestone Summary

| Phase | Milestone | Target | Status |
|-------|-----------|--------|--------|
| 1.1 | v2 Core Parser & Models | — | 🔲 Not Started |
| 1.2 | v2 Builder & Encoding | — | 🔲 Not Started |
| 1.3 | v2 Validation Engine | — | 🔲 Not Started |
| 1.4 | v2 MLLP Transport | — | 🔲 Not Started |
| 1.5 | v2 Version Definitions | — | 🔲 Not Started |
| 2.1 | v3 RIM Core Models | — | 🔲 Not Started |
| 2.2 | v3 CDA Document Support | — | 🔲 Not Started |
| 2.3 | v3 Vocabulary & Codes | — | 🔲 Not Started |
| 2.4 | v3 Validation | — | 🔲 Not Started |
| 2.5 | v3 Transport | — | 🔲 Not Started |
| 3.1 | Common Data Types | — | 🔲 Not Started |
| 3.2 | Error Handling | — | 🔲 Not Started |
| 3.3 | Logging & Diagnostics | — | 🔲 Not Started |
| 3.4 | Security | — | 🔲 Not Started |
| 4.1 | Performance Optimisation | — | 🔲 Not Started |
| 4.2 | Concurrency Hardening | — | 🔲 Not Started |
| 4.3 | Resilience | — | 🔲 Not Started |
| 4.4 | Platform Testing | — | 🔲 Not Started |
| 5.1 | API Documentation | — | 🔲 Not Started |
| 5.2 | Guides & Tutorials | — | 🔲 Not Started |
| 5.3 | CI/CD & Releases | — | 🔲 Not Started |
| 5.4 | Community | — | 🔲 Not Started |
