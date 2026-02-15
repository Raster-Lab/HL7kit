# HL7kit - Swift HL7 Framework

[![CI/CD Pipeline](https://github.com/Raster-Lab/HL7kit/actions/workflows/ci.yml/badge.svg)](https://github.com/Raster-Lab/HL7kit/actions/workflows/ci.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Code Coverage](https://img.shields.io/badge/Coverage-90%25+-brightgreen.svg)](https://github.com/Raster-Lab/HL7kit)

A comprehensive, production-ready Swift 6.2 framework for working with HL7 v2.x, v3.x, and FHIR standards on Apple platforms. Built with strict concurrency for thread safety, optimized for low memory footprint, and designed for high-performance healthcare application development.

> **Version 1.0.0** is now available! See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Overview

HL7kit is designed to be a modern, Swift-native alternative to HAPI, built from the ground up to leverage Apple platform capabilities. Given the fundamental differences between HL7 v2.x (pipe-delimited messaging), v3.x (XML-based messaging), and FHIR (RESTful API-based), this framework is architected as separate but complementary toolkits.

> 📊 **Comparing HL7 Tools?** See our comprehensive [**Comparison Guide**](COMPARISON.md) to understand when to choose HL7kit vs HAPI, NHapi, Firely, and other HL7 frameworks.

### Key Features

- **Native Swift 6.2**: Full utilization of modern Swift features including concurrency, actors, and strict typing
- **Apple Platform Optimization**: Leverages Foundation, Network.framework, and other native Apple frameworks
- **Performance Focused**: Optimized for minimal memory footprint and CPU usage (>50,000 messages/second)
- **Network Efficient**: Smart caching, connection pooling, and efficient data transmission
- **Type-Safe**: Strong typing for message structures and validation
- **Comprehensive**: Full support for HL7 v2.x (2.1-2.8), v3.x CDA R2, and FHIR R4
- **Production Ready**: 2,100+ tests, 90%+ code coverage, comprehensive security audit
- **No Dependencies**: Pure Swift implementation with no external dependencies

### Feature Highlights

- **Core Architecture**: Foundational protocols and interfaces for HL7 processing
- **Validation Framework**: Comprehensive validation system with context, rules, and accumulators
- **Data Protocols**: Parseable, Serializable, and transformation protocols
- **Error Handling**: Enhanced error types with context, recovery strategies, and retry mechanisms
- **Structured Logging**: Advanced logging system with filtering, routing, and performance tracking
- **Benchmarking Framework**: Performance measurement and optimization tools
- **Memory-Efficient Parsing Strategies**: Comprehensive parsing framework with multiple strategies (lazy, streaming, chunked, indexed) for optimal memory usage
- **Actor-Based Concurrency Model**: Complete concurrency architecture using Swift 6.2 actors with reference implementations for message processing, stream processing, routing, and resource management
- **HL7 v2.x Standards Analysis**: Comprehensive documentation of HL7 v2.x specifications (versions 2.1-2.8), message types, and conformance requirements
- **HL7 v2.x Parser Infrastructure**: Configurable parser with encoding detection, delimiter auto-detection, error recovery modes (strict, skip, best-effort), streaming support, segment validation, and diagnostic reporting
- **HL7 v2.x Message Builder**: Fluent API for constructing HL7 v2.x messages programmatically, including MSH segment builder with named methods, generic segment builder with field/component/subcomponent/repetition support, raw segment insertion, message templates (ADT, ORU, ORM, ACK), and proper encoding/escaping
- **Common Message Types**: Typed message wrappers for ADT (Admit/Discharge/Transfer), ORM (Order), ORU (Observation Result), ACK (Acknowledgment), QRY (Query), and QBP (Query by Parameter) with segment accessors, field convenience methods, message-specific validation rules, and structured observation results
- **Data Type System**: Complete implementation of HL7 v2.x primitive data types (ST, TX, FT, NM, SI, DT, TM, DTM/TS, ID, IS) and composite data types (CE, CX, XPN, XAD, XTN, EI, HD, PL) with validation, conversion utilities, and memory optimization. Includes date/time handling with timezone support.
- **Message Structure Database**: Comprehensive database of message structures for HL7 v2.x versions 2.1-2.8, including version detection from MSH-12 field, structure validation against specifications, backward compatibility handling, and query API for accessing definitions. Includes pre-configured structures for ADT, ORM, ORU, ACK, and QRY/QBP message types.
- **Validation Engine**: Comprehensive HL7 v2.x validation framework with conformance profile support, composable validation rules engine, required field validation, data type validation (ST, NM, DT, TM, TS, SI, etc.), cardinality checking (segment and field repetition constraints), value set validation, pattern matching, and custom validation rules support. Includes standard conformance profiles for ADT A01, ORU R01, ORM O01, and ACK messages.
- **MLLP Networking & Transport**: Full MLLP (Minimal Lower Layer Protocol) implementation including message framing/deframing, streaming parser for incremental TCP data, configurable client connections with TLS/retry/timeout support, server-side listener, connection pooling, and actor-based concurrency. Network I/O uses `Network.framework` on Apple platforms with cross-platform stubs.
- **Character Encoding Support**: Comprehensive support for multiple character encodings with MSH-18 (Character Set) field parsing, automatic encoding detection, validation, and support for 30+ HL7 standard character sets including ASCII, UTF-8, UTF-16, Latin-1, and international encodings. Includes character set mapping, encoding mismatch detection, and platform-specific optimizations.
- **Performance Optimizations**: String interning for common segment IDs (15-25% memory reduction), object pooling for segments/fields/components (70-80% allocation reduction), lazy parsing support, comprehensive performance benchmarks, and optimization guide. Achieves >10,000 messages/second throughput on Apple Silicon.
- **Z-Segment Support**: Custom segment definitions with registry, builder API, field definitions, and validation against custom segment schemas. Includes pre-defined examples (ZPI, ZBE, ZOB).
- **Batch & File Processing**: Full support for batch (BHS/BTS) and file (FHS/FTS) structures with parsing and serialization. Includes validation of batch/file message counts.
- **Streaming API**: Memory-efficient streaming for large files using async/await. Constant memory usage regardless of file size with support for file and in-memory data sources.
- **Compression Support**: Native compression using Foundation's Compression framework (LZFSE, LZ4, ZLIB, LZMA) for messages, batches, and files with configurable compression levels.
- **Developer Tools**: Message inspector/debugger with tree view, diff tool, pretty printer, search functionality, and statistics. Test utilities including message generators, mock objects, and performance helpers.
- **HL7 v3.x Standards Analysis**: Comprehensive documentation of HL7 v3.x specifications including Reference Information Model (RIM), Clinical Document Architecture (CDA), data types, and implementation guidelines
- **HL7 v3.x RIM Foundation**: Implementation of RIM core classes (Act, Entity, Role, Participation, ActRelationship, RoleLink) with full Swift 6.2 support including Sendable conformance, value type optimizations, and comprehensive data types (BL, INT, REAL, ST, TS, II, CD, CE, PQ, EN, AD, TEL, IVL) with null flavor support
- **HL7 v3.x XML Parser**: Production-grade XML parser built on Foundation's XMLParser with DOM-like representation (XMLElement, XMLDocument), namespace-aware parsing, configurable depth/size limits, HL7 v3 schema validation (ClinicalDocument, required elements), XPath-like query support (absolute/relative paths, recursive search, attribute predicates), XML serialization with pretty-print support, and comprehensive diagnostics. All types are Sendable for Swift 6 strict concurrency.
- **CDA R2 (Clinical Document Architecture)**: Complete implementation of CDA R2 with ClinicalDocument root element, comprehensive header participants (RecordTarget, Author, Custodian, LegalAuthenticator, Authenticator, DataEnterer, Informant, InformationRecipient), hierarchical section support with narrative text, structured entries (Observation, Procedure, SubstanceAdministration, Supply, Encounter, Act, Organizer), narrative blocks with HTML-like formatting (tables, lists, paragraphs, links, multimedia), template processing infrastructure with C-CDA template registry (US Realm Header, Progress Note, Consultation Note, Discharge Summary, History and Physical, Operative Note, CCD), comprehensive validation engine with template constraints and cardinality checking, CDA conformance levels (Level 1-3), and 90%+ test coverage. Includes 50+ common vocabulary codes for document types and section types.
- **HL7 v3.x Message Builder**: Fluent API for constructing CDA R2 documents programmatically with type-safe builders (CDADocumentBuilder, ParticipantBuilders, SectionBuilder, ObservationBuilder, ProcedureBuilder, SubstanceAdministrationBuilder), template factory for common document types (Progress Note, Consultation Note, Discharge Summary, History & Physical, Operative Note), comprehensive vocabulary binding support with code system constants (LOINC, SNOMED CT, RxNorm, ICD-10, CPT, CVX, NDC) and helper methods for common codes, and XML serialization integration. Includes 24+ unit tests with full coverage.
- **HL7 v3.x Vocabulary Services**: Comprehensive vocabulary services framework with code system protocol and implementations, value set handling with expansion and validation, concept lookup API with intelligent caching (10,000+ concept cache), vocabulary validation against code systems and value sets, standard value sets for administrative data (gender, confidentiality), integration points for external terminologies (SNOMED CT, LOINC, ICD), and extensible architecture for custom terminology services. Includes 25+ unit tests with 90%+ coverage.
- **HL7 v3.x Networking & Transport**: Production-ready transport layer for HL7 v3.x messages with SOAP 1.1/1.2 support (envelope creation, fault handling), RESTful HTTP transport (GET, POST, PUT, DELETE), WS-Security (username token, timestamp, binary security token), message queuing (priority-based, batch processing), connection management (pooling, lifecycle, timeout handling), and TLS/SSL support (configurable versions, certificate validation). Platform-aware implementation with native URLSession on Apple platforms and FoundationNetworking on Linux. Includes 22+ unit tests with full coverage.
- **Template Engine**: Advanced template engine for CDA documents with template inheritance (parent-child relationships with property merging), template composition (TemplateComposer with circular dependency detection), constraint validation (cardinality, value constraints, data type checking), extended template library (17+ templates including C-CDA documents, IHE profiles, sections, and entries), template discovery service (search by type, status, author, text), template authoring tools (builder DSL, validation tools, export/import in JSON/XML formats), and comprehensive testing utilities. Includes 28+ unit tests with full coverage.
- **Transformation Engine**: Bidirectional transformation framework for converting between HL7 v2.x and v3.x messages. Features include configurable validation modes (strict, lenient, skip), data loss tracking with quality metrics, actor-based async operations for thread safety, transformation builder DSL with fluent API, pre-built transformation templates (ADT demographics, ORU observations), common transformation functions (date/time formatting, phone formatting, value mapping), comprehensive error handling with severity levels, and performance metrics tracking (duration, fields mapped, data fidelity). Includes ADT<->CDA transformers, custom rule support, and 24+ unit tests with full coverage.
- **HL7 v3.x Performance Optimization**: Comprehensive performance optimization for XML parsing and CDA processing. Includes XMLElementPool (actor-based object pooling for DOM elements with reuse tracking), InternedElementName (pre-interned constants for 50+ common CDA element names with O(1) lookup), V3StringInterner (dynamic string deduplication), XPathQueryCache (LRU cache for repeated XPath queries with hit/miss statistics), LazySectionContent (deferred parsing of CDA section entries and narrative text), streaming XML API (XMLStreamSource protocol, FileXMLStreamSource/DataXMLStreamSource, XMLElementStream AsyncSequence for constant-memory large document processing), V3PerformanceMetrics (throughput/timing tracking), XMLDocumentAnalyzer (DOM structure statistics), and V3Pools (global pool management with aggregated statistics). Includes 63+ unit tests with full coverage.
- **CDA Document Processing**: Advanced CDA document processing capabilities including document rendering (plain text and HTML output with configurable options), human-readable output generation with narrative text extraction, document comparison tools (structural diff identifying added/removed/modified sections and entries), document merging with configurable conflict strategies (keepPrimary, keepSecondary, includeBoth) and entry deduplication, and document versioning support with version chain management (RPLC/APND/XFRM relationships), document set grouping, and version ordering. Includes 86+ unit tests with full coverage.
- **HL7 v3.x Developer Tools**: Comprehensive developer tools including XMLInspector for tree view display, statistics, and CDA-specific inspection; SchemaValidator for XML schema and conformance validation with detailed error reports; V3TestUtilities with mock CDA document builders, test data generators, assertion helpers, and performance benchmarking. Includes 110+ unit tests with full coverage.
- **FHIR Data Model Foundation**: Complete implementation of FHIR R4 data model foundation including 17 primitive data types (Boolean, Integer, Decimal, String, Uri, Url, Canonical, Code, Id, Markdown, Date, DateTime, Time, Instant, Base64Binary, Uuid) with full validation, 11 complex data types (Identifier, HumanName, Address, ContactPoint, Period, Range, Quantity, Coding, CodeableConcept, Reference, Annotation, Attachment, Signature), base protocols (Element, BackboneElement, Resource, DomainResource), Meta, Narrative, and Extension support. All types are Sendable for Swift 6.2 concurrency, with Codable conformance for JSON/XML serialization. Includes sample Patient and Observation resources. Includes 95+ unit tests with full coverage.
- **FHIR R4 Resource Implementations**: Full implementations of 13 FHIR R4 resources (Patient, Observation, Practitioner, Organization, Condition, AllergyIntolerance, Encounter, MedicationRequest, DiagnosticReport, Appointment, Schedule, MedicationStatement, DocumentReference), plus Bundle (with transaction/batch support) and OperationOutcome for error handling. Enhanced Patient with contact, communication, marital status, and practitioner fields. Enhanced Observation with value types, reference ranges, and components. All resources conform to DomainResource (Bundle to Resource), support Codable serialization, and are Sendable for concurrency safety. ResourceContainer supports polymorphic decoding/encoding of all resource types.
- **FHIR JSON/XML Serialization**: Complete serialization and deserialization for FHIR R4 resources with actor-based thread safety. JSON serializer using Foundation's JSONEncoder/JSONDecoder with configurable output formatting (compact/pretty-printed), date strategies, and validation modes. XML serializer with FHIR namespace support for both encoding and decoding. Streaming Bundle parser for memory-efficient processing of large bundles. Support for polymorphic resources via ResourceContainer, contained resources, and references. Configuration options including validation modes (strict/lenient/none), nesting depth limits, and choice type validation. Includes 28+ unit tests with comprehensive coverage.
- **FHIR RESTful Client**: Production-ready FHIR RESTful client using URLSession with async/await. Actor-based FHIRClient for thread-safe HTTP operations. CRUD operations (create, read, update, delete) with proper Content-Type and Accept headers. Search support via GET and POST with FHIR search parameters. History and version read (vread) operations. Batch and transaction Bundle support. Pagination for search results (next/previous page navigation). Comprehensive error handling with OperationOutcome parsing, HTTP status code mapping (404 Not Found, 410 Gone, 422 Validation Error, etc.), and retry logic with exponential backoff. Configurable client with base URL, authorization, timeout, retry settings, and custom headers. FHIRURLSession protocol for dependency injection and testability. Includes 40+ unit tests with mock session support.
- **FHIR Search & Query**: Type-safe FHIR search API with SearchParamType enum (string, token, reference, date, number, quantity, composite, uri, special), SearchParameterValue typed union, fluent FHIRSearchQuery builder with chained/reverse-chained search (_has), _include/_revinclude support with iterate, compartment-based search (CompartmentSearch), SearchResult<T> for typed Bundle result handling, sort/pagination/summary/elements control, and SearchParameterValidator with known parameter registries for common resource types. All types are Sendable for Swift 6 strict concurrency. Includes 88 unit tests with comprehensive coverage.
- **FHIR Validation Engine**: Comprehensive FHIR resource validation framework with StructureDefinition and ElementDefinition models, cardinality validator (min/max/prohibited constraints), terminology validator with binding strength enforcement (required/extensible/preferred/example), FHIRPath expression evaluator with tokenizer and recursive descent parser supporting path navigation, existence checks, boolean logic, string operations, and comparisons, profile validator with constraint/fixed value/pattern/must-support checking, custom validation rules (RequiredFields, CoOccurrence, ValueConstraint, Closure-based rules with registry), FHIRValidator main entry point returning FHIRValidationOutcome (convertible to OperationOutcome), standard profiles for Patient/Observation/US Core Patient, and LocalTerminologyService with pre-registered standard value sets. Includes 124+ unit tests with full coverage.
- **SMART on FHIR Authentication**: Complete SMART on FHIR authentication framework with OAuth 2.0 authorization flow, SMART App Launch Framework support for standalone and EHR launch sequences, PKCE (Proof Key for Code Exchange) for public clients with SHA-256 code challenge, token management and automatic refresh via OAuthToken with expiration tracking, scope handling with SMARTScope helpers for clinical scopes (patient/*.read, user/*.write, etc.), server capability discovery via .well-known/smart-configuration, InMemoryTokenStore actor for thread-safe token persistence, and SMARTAuthClient actor as the main entry point for authorization URL building, code exchange, token refresh, and revocation. All types are Sendable for Swift 6 strict concurrency. Includes 40+ unit tests.
- **FHIR Terminology Services**: Complete FHIR terminology services framework with CodeSystem $lookup and $validate-code operations, ValueSet $expand and $validate-code operations, ConceptMap $translate with equivalence mapping (relatedto, equivalent, equal, wider, subsumes, narrower, specializes, inexact, unmatched, disjoint), actor-based FHIRTerminologyClient for thread-safe HTTP operations against terminology servers, TerminologyCache actor with TTL-based expiration and LRU eviction for lookup/validation/expansion/translation results, WellKnownCodeSystem enum supporting SNOMED CT, LOINC, ICD-10, ICD-10-CM, RxNorm, CPT, CVX, NDC, and UNII, complete FHIR Parameters response parsing for all terminology operations, and FHIRURLSession-based networking with comprehensive error handling. All types are Sendable for Swift 6 strict concurrency. Includes 30+ unit tests with mock session support.
- **FHIR Operations & Extended Operations**: Comprehensive FHIR operations framework with $everything (Patient, Encounter), $validate with mode and profile support, $convert for format transformation (JSON, XML, Turtle), $meta/$meta-add/$meta-delete for resource metadata management, Bulk Data Access $export with async status polling, and a custom operation framework with FHIROperationRegistry actor for registering and executing user-defined operations. All operations are executed through the FHIROperationsClient actor with full async/await support, input validation, and structured error handling via FHIROperationError. All types are Sendable for Swift 6 strict concurrency. Includes 29+ unit tests.
- **FHIR Subscriptions & Real-time**: R5 topic-based subscription management with WebSocket transport, REST-hook notification handling, event filtering, and automatic reconnection with configurable backoff strategies. Features FHIRSubscriptionManager actor for CRUD operations and real-time notification streaming, SubscriptionEventFilter with fluent EventFilterBuilder API, RESTHookHandler for processing notification bundles, WebSocketTransport actor with auto-reconnection, and ReconnectionStrategy with preset configurations (default, aggressive, conservative, noRetry). All types are Sendable for Swift 6 strict concurrency. Includes 40+ unit tests.
- **FHIR Performance Optimization**: Comprehensive performance toolkit including OptimizedJSONParser and OptimizedXMLParser with benchmarking, FHIRResourceCache actor with LRU eviction and TTL-based expiration, StreamingBundleProcessor for memory-efficient large Bundle handling, ConnectionPool actor for HTTP session reuse, FHIRBenchmark harness with comparison support, FHIRPerformanceMetrics actor for operation timing, and MemoryPressureMonitor for runtime memory tracking. All types are public and Sendable for Swift 6 strict concurrency. Includes 44 unit tests.
- **Test Data Sets**: Realistic test messages for validation including valid, invalid, and edge cases
- **High Test Coverage**: 2120+ unit tests with 90%+ code coverage
- **Testing Infrastructure**: Reusable testing utilities for HL7 integrations including IntegrationTestRunner actor with sequential/parallel execution and dependency management, PerformanceBenchmarkRunner actor with min/max/avg/median/p95/p99 timing and baseline comparison, ConformanceTestRunner actor with category-based conformance reports, MockServer/MockClient actors with route matching and interaction verification, and TestDataGenerator with seed-based reproducible generation of patient names, MRNs, SSNs, phone numbers, HL7 v2.x messages (ADT, ORU), and FHIR-like JSON. All types are public, Sendable, and XCTest-independent for use by library consumers. Includes 45+ unit tests.
- **Persistence Layer**: Message archive/retrieval system with `MessageArchive` actor for thread-safe storage, `PersistenceStore` protocol with `InMemoryStore` actor for key-value persistence, `DataExporter`/`DataImporter` for JSON export/import with round-trip fidelity, `ArchiveIndex` actor for full-text search and field-based indexing with TF-IDF relevance scoring, date range queries, tag-based filtering, and archive statistics. All types are public and Sendable for Swift 6 strict concurrency. Includes 80 unit tests.
- **Common Services**: Unified cross-module services including `UnifiedLogger` actor with subsystem/category tagging, correlation ID tracing, and buffered log export; `SecurityService` actor with PHI sanitization (SSN, phone, email masking), input validation, secure random generation, and SHA-256 hashing; `SharedCache<Key, Value>` generic LRU cache actor with TTL expiration and hit/miss statistics. All types are public and Sendable for Swift 6 strict concurrency.
- **Security Framework**: Production-grade security layer with **AES-256-GCM authenticated encryption** via `SecureMessageEncryptor` (Swift Crypto), `SecureEncryptedPayload` with 16-byte authentication tag, and `SecureEncryptionKey` with cryptographically secure key generation. Also includes `SecureDigitalSigner` (HMAC-SHA256 via Swift Crypto), `DigitalSigner` (HMAC-SHA256 signing with constant-time verification and timing attack mitigation), `EncryptionKey`/`SigningKey` generation with enforced size validation (16-256 bytes), `CertificateInfo` with lifecycle status tracking (valid, expired, revoked, untrusted), input validation for all cryptographic operations, and pure-Swift SHA256/HMAC implementations for cross-platform compatibility. Includes access control primitives and HIPAA compliance utilities. **Phase 9.2 Security Audit completed (February 2026)**: All critical vulnerabilities resolved with AES-256-GCM implementation. See [SECURITY_VULNERABILITY_ASSESSMENT.md](SECURITY_VULNERABILITY_ASSESSMENT.md) for complete findings. Includes 117+ unit tests with 53+ security-specific tests.
- **Platform Integrations**: Protocols and abstractions for Apple platform integration including `HealthDataProvider` (HealthKit bridge with measurement read/write/observe), `CareDataProvider` (CareKit bridge with tasks and outcomes), `ResearchDataProvider` (ResearchKit bridge with surveys and consent), `CloudSyncProvider` (iCloud sync with conflict resolution), `HandoffProvider` (device-to-device activity handoff), and `ShortcutsProvider` (Siri shortcuts and App Intents). Includes `PlatformIntegrationManager` actor for centralized provider management, `HealthDataMapper` utility with LOINC/UCUM mappings, and data types for vital signs, care tasks, survey questions, sync records, and shortcut actions. All types are Sendable and platform-agnostic. Includes 87 unit tests.
- **Command-Line Tools**: Complete CLI toolkit (`hl7` executable) with six subcommands: `validate` (structural and profile-based validation), `convert` (format conversion including HL7 v2.x round-trip and v2→v3 CDA), `inspect` (message tree view, statistics, and search), `batch` (multi-file processing with validate/inspect/convert operations), `conformance` (profile-based conformance checking against ADT_A01, ORU_R01, ORM_O01, ACK profiles), and `benchmark` (performance benchmarking with throughput/latency metrics). Supports text and JSON output formats, auto-detected conformance profiles, and native argument parsing with no external dependencies. Includes 101 unit tests.
- **Sample Code & Tutorials**: Comprehensive examples covering quick start (parsing, building, validating, inspecting), common use cases (ADT admissions, ORU lab results, ORM orders, ACK responses, batch processing), integration patterns (v2→v3 CDA transformation, FHIR resources, JSON/XML serialization, CLI usage), and performance optimization (parser configuration, streaming, compression, benchmarking). All examples are compilable with matching unit tests.


---

## 🚀 Installation

HL7kit is distributed via Swift Package Manager and requires no external dependencies.

### Requirements

- **Swift**: 6.0 or later (Swift 6.2 recommended)
- **Platforms**: 
  - macOS 13.0+
  - iOS 16.0+
  - tvOS 16.0+
  - watchOS 9.0+
  - visionOS 1.0+

### Swift Package Manager

Add HL7kit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/HL7kit.git", from: "1.0.0")
]
```

Then add the modules you need to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "HL7v2Kit", package: "HL7kit"),   // For HL7 v2.x
            .product(name: "HL7v3Kit", package: "HL7kit"),   // For HL7 v3.x
            .product(name: "FHIRkit", package: "HL7kit"),    // For FHIR
            .product(name: "HL7Core", package: "HL7kit"),    // Shared utilities
        ]
    )
]
```

### Xcode

In Xcode, go to **File → Add Package Dependencies...** and enter:
```
https://github.com/Raster-Lab/HL7kit.git
```

Select the modules you need from the package products.

---

## ⚡ Quick Start

### HL7 v2.x - Parsing and Building

```swift
import HL7v2Kit

// Parse an HL7 v2.x message
let hl7String = """
MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20260214120000||ADT^A01|MSG001|P|2.5.1
PID|1||12345^^^MRN||Doe^John^A||19800115|M|||123 Main St^^Boston^MA^02101
"""

let parser = HL7v2Parser()
let message = try parser.parse(hl7String)

// Access message fields
if let msh = message.segment("MSH") {
    print("Message Type: \(msh.field(9)?.component(1)?.stringValue ?? "Unknown")")
    print("Sending App: \(msh.field(3)?.stringValue ?? "Unknown")")
}

// Build a new message
let builder = HL7v2MessageBuilder(messageType: "ADT^A01")
let newMessage = try builder
    .msh(sendingApplication: "MyApp", sendingFacility: "MyFacility")
    .pid(patientID: "12345", lastName: "Smith", firstName: "Jane", dateOfBirth: "19900505")
    .build()

// Validate against conformance profile
let validator = HL7v2Validator()
let result = try validator.validate(message, profile: .hl7v251)
if result.isValid {
    print("✅ Message is valid")
} else {
    print("❌ Validation errors: \(result.errors)")
}
```

### FHIR - Resources and RESTful Operations

```swift
import FHIRkit

// Create a FHIR Patient resource
let patient = Patient()
patient.id = "patient-001"
patient.name = [HumanName(family: "Doe", given: ["John", "A"])]
patient.birthDate = FHIRDate("1980-01-15")
patient.gender = "male"

// Serialize to JSON
let jsonData = try JSONEncoder().encode(patient)
let jsonString = String(data: jsonData, encoding: .utf8)!
print(jsonString)

// Create a FHIR client
let client = FHIRClient(baseURL: URL(string: "https://fhir.example.com")!)

// Read a patient
let readPatient = try await client.read(Patient.self, id: "patient-001")

// Search for patients
let searchQuery = FHIRSearchQuery()
    .where("family", .equals, "Doe")
    .where("birthdate", .greaterThan, "1970-01-01")

let searchResult = try await client.search(Patient.self, query: searchQuery)
print("Found \(searchResult.entry?.count ?? 0) patients")
```

### HL7 v3.x - CDA Documents

```swift
import HL7v3Kit

// Parse a CDA document
let cdaXML = """
<?xml version="1.0" encoding="UTF-8"?>
<ClinicalDocument xmlns="urn:hl7-org:v3">
  <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
  <title>Progress Note</title>
  ...
</ClinicalDocument>
"""

let parser = CDAParser()
let document = try parser.parse(cdaXML)

// Access document properties
print("Title: \(document.title ?? "Untitled")")
print("Date: \(document.effectiveTime ?? "No date")")

// Build a new CDA document
let builder = CDADocumentBuilder()
let newDocument = try builder
    .title("Progress Note")
    .effectiveTime(Date())
    .recordTarget(patientID: "12345", lastName: "Smith", firstName: "John")
    .author(name: "Dr. Jane Smith", time: Date())
    .addSection(title: "Chief Complaint", text: "Patient presents with...")
    .build()

// Convert to XML
let xml = try newDocument.toXML(prettyPrint: true)
print(xml)
```

For more examples, see the [Examples](Examples/) directory and [Quick Start Guide](Examples/QuickStart.swift).

---

## Project Structure

```
HL7kit/
├── HL7v2Kit/          # HL7 v2.x toolkit
├── HL7v3Kit/          # HL7 v3.x toolkit
│   ├── RIM/           # Reference Information Model
│   ├── XMLParser/     # XML parsing and serialization
│   ├── CDA/           # Clinical Document Architecture R2
│   └── DeveloperTools/ # XML Inspector, Schema Validator, Test Utilities
├── FHIRkit/           # HL7 FHIR toolkit
│   ├── DataTypes/     # Primitive and complex data types
│   ├── Foundation/    # Element, Resource, DomainResource, Extension
│   ├── Resources/     # FHIR R4 resource implementations
│   ├── Serialization/ # JSON/XML serialization
│   ├── Operations/   # FHIR operations ($everything, $validate, $export, custom)
│   ├── RESTClient/    # FHIR RESTful client
│   ├── Search/        # Type-safe FHIR search & query API
│   ├── SMARTAuth/     # SMART on FHIR OAuth 2.0 authentication
│   ├── Subscriptions/ # R5 topic-based subscriptions & real-time notifications
│   ├── Terminology/   # Terminology services (CodeSystem, ValueSet, ConceptMap)
│   ├── Validation/    # FHIR validation engine (profiles, FHIRPath, terminology)
│   └── Performance/   # Performance optimization (caching, pooling, benchmarks)
├── HL7Core/           # Shared utilities and protocols
│   ├── HL7Core.swift          # Base protocols and types
│   ├── Validation.swift       # Validation framework
│   ├── DataProtocols.swift    # Data handling protocols
│   ├── ErrorRecovery.swift    # Error handling and recovery
│   ├── Logging.swift          # Structured logging system
│   ├── Benchmarking.swift     # Performance benchmarking
│   ├── ParsingStrategies.swift # Memory-efficient parsing
│   ├── ActorPatterns.swift    # Concurrency patterns
│   ├── CommonServices.swift   # Shared services (logging, security, caching, config, metrics, audit)
│   ├── SecurityFramework.swift # Security framework (encryption, signatures, RBAC, HIPAA, certificates)
│   ├── Persistence.swift      # Message archive, storage, search/indexing, export/import
│   ├── PlatformIntegrations.swift # Platform integration protocols (HealthKit, CareKit, ResearchKit, iCloud, Handoff, Siri)
│   └── TestingInfrastructure.swift # Integration/performance/conformance test harnesses, mocks, generators
├── HL7CLI/            # CLI core library (argument parsing, command logic)
├── HL7CLIEntry/       # CLI executable entry point
├── Examples/          # Sample code and tutorials
│   ├── QuickStart.swift           # Getting started guide
│   ├── CommonUseCases.swift       # ADT, ORU, ORM workflows
│   ├── IntegrationExamples.swift  # Cross-module integration
│   ├── PerformanceOptimization.swift # High-throughput techniques
│   └── README.md                  # Examples index
├── Tests/             # Comprehensive test suites (2120+ tests, 90%+ coverage)
├── TestData/          # Test messages for validation
│   └── HL7v2x/       # HL7 v2.x test messages
├── Documentation/     # API documentation and guides
├── HL7V2X_STANDARDS.md   # HL7 v2.x standards analysis
├── HL7V3X_STANDARDS.md   # HL7 v3.x standards analysis
├── FHIR_STANDARDS.md     # HL7 FHIR standards analysis (R4, R5)
├── CONCURRENCY_MODEL.md  # Actor-based concurrency architecture
├── PERFORMANCE.md        # Performance optimization guide
├── CODING_STANDARDS.md   # Development standards
├── ARCHITECTURE.md       # System architecture documentation
├── INTEGRATION_GUIDE.md  # Phase 7 integration guide
├── SECURITY_GUIDE.md     # Security best practices
└── MIGRATION_GUIDE.md    # Migration guides
```

---

## 📋 Development Milestones

For detailed development milestones, phase breakdowns, and timelines, please see [milestone.md](milestone.md).

### Quick Overview

The HL7kit project follows a phased development approach spanning approximately 62 weeks (~15 months):

- **Phase 0** (Weeks 1-2): Foundation & Planning
- **Phases 1-2** (Weeks 3-16): HL7 v2.x Core & Advanced Features
- **Phases 3-4** (Weeks 17-30): HL7 v3.x Core & Advanced Features
- **Phases 5-6** (Weeks 31-44): FHIRkit Core & Advanced Features
- **Phase 7** (Weeks 45-50): Integration & Common Services
- **Phase 8** (Weeks 51-56): Platform Features & Examples
- **Phase 9** (Weeks 57-62): Polish & Release
- **Phase 10** (Ongoing): Post-Release & Maintenance

### Quality Targets

- **Code Coverage**: >90% for core modules
- **Documentation Coverage**: 100% public API
- **Performance**: >10,000 HL7 v2 messages/second on Apple Silicon
- **Memory Efficiency**: <100MB for 1,000 concurrent messages

---

## ⚡ Performance

HL7kit is optimized for high-performance scenarios:

### Performance Targets

| Metric | Target | Typical Performance |
|--------|--------|---------------------|
| v2.x Throughput | >10,000 msg/s | 15,000-25,000 msg/s |
| v3.x Throughput | >5,000 docs/s | 10,000-20,000 docs/s |
| FHIR Throughput | >10,000 res/s | 15,000-25,000 res/s |
| Latency (p50) | <100 μs | 40-80 μs |
| Memory/Message | <10 KB | 4-8 KB |

*Tested on Apple Silicon (M1/M2). See [PERFORMANCE.md](PERFORMANCE.md) for detailed benchmarks across all modules.*

### Optimization Features

- **String Interning**: Automatic interning of common segment IDs (15-25% memory reduction)
- **Object Pooling**: Reusable object pools for segments, fields, and components (70-80% allocation reduction)
- **Lazy Parsing**: Parse-on-demand for reduced upfront overhead
- **Streaming Parser**: Constant memory usage for large message volumes
- **Concurrent Processing**: Actor-based thread-safe concurrent parsing

### Quick Performance Tips

```swift
import HL7v2Kit

// High-throughput configuration
let config = ParserConfiguration(
    strategy: .eager,
    strictMode: false,
    errorRecovery: .skipInvalidSegments
)
let parser = HL7v2Parser(configuration: config)

// Preallocate object pools
await GlobalPools.preallocateAll(100)

// Parse with optimal performance
let result = try parser.parse(messageString)
```

For comprehensive performance tuning, see the [Performance Guide](PERFORMANCE.md).

---

## 🔧 Command-Line Tools

HL7kit includes a CLI tool (`hl7`) for processing HL7 messages from the command line.

### Installation

```bash
# Build the CLI tool
swift build --product hl7

# Run directly
swift run hl7 --help
```

### Commands

#### Validate Messages

```bash
# Validate a single message
hl7 validate message.hl7

# Validate with strict mode
hl7 validate --strict message.hl7

# Validate multiple files
hl7 validate file1.hl7 file2.hl7 file3.hl7

# JSON output
hl7 validate --format json message.hl7
```

#### Inspect Messages

```bash
# Inspect message structure
hl7 inspect message.hl7

# Show statistics
hl7 inspect message.hl7 --stats

# Search for values
hl7 inspect message.hl7 --search "Doe"
```

#### Convert Formats

```bash
# Re-serialize (normalize) an HL7 v2.x message
hl7 convert message.hl7 --from hl7v2 --to hl7v2

# Convert to CDA XML
hl7 convert message.hl7 --from hl7v2 --to hl7v3 --pretty -o output.xml
```

#### Batch Processing

```bash
# Batch validate multiple files
hl7 batch *.hl7

# Batch inspect with output directory
hl7 batch --operation inspect --output-dir results/ *.hl7
```

#### Conformance Checking

```bash
# Auto-detect profile and check conformance
hl7 conformance message.hl7

# Check against a specific profile
hl7 conformance message.hl7 --profile ADT_A01

# Available profiles: ADT_A01, ORU_R01, ORM_O01, ACK
```

#### Performance Benchmarking

```bash
# Run built-in benchmark (ADT^A01)
hl7 benchmark

# Benchmark a specific file
hl7 benchmark message.hl7

# Custom iterations with JSON output
hl7 benchmark --iterations 1000 --format json
```

---

## 📖 Examples & Tutorials

The [Examples/](Examples/) directory contains ready-to-use sample code for common healthcare integration scenarios.

| Example | Description |
|---------|-------------|
| [Quick Start](Examples/QuickStart.swift) | Parse, build, validate, and inspect HL7 v2.x messages |
| [Common Use Cases](Examples/CommonUseCases.swift) | ADT admission workflows, ORU lab results, ORM orders, ACK responses, batch processing |
| [Integration](Examples/IntegrationExamples.swift) | v2→v3 CDA transformation, FHIR resources, JSON/XML serialization, CLI usage |
| [Performance](Examples/PerformanceOptimization.swift) | Object pooling, streaming, compression, parser configuration, benchmarking |

### 🎥 Video Tutorials

For visual learners, we provide comprehensive video tutorial scripts covering all aspects of HL7kit. See [VIDEO_TUTORIALS.md](VIDEO_TUTORIALS.md) for detailed outlines and scripts for:

- **Introduction Series** (3 videos): What is HL7kit, setup, and architecture
- **HL7 v2.x Mastery** (4 videos): Parsing, building, validation, and MLLP transport
- **HL7 v3.x & CDA** (3 videos): CDA documents, RIM model, and transformations
- **FHIR Integration** (3 videos): Resources, REST API, and validation
- **Platform-Specific** (3 videos): iOS, macOS, and CLI tool usage
- **Advanced Topics** (3 videos): Performance, security, and testing

### Quick Example

```swift
import HL7v2Kit

// Parse
let message = try HL7v2Message.parse("MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|CTL001|P|2.5.1\rPID|1||MRN001||Smith^John")

// Build
let built = try HL7v2MessageBuilder()
    .msh { $0.sendingApplication("App").messageType("ADT", triggerEvent: "A01").messageControlID("ID1").processingID("P").version("2.5.1") }
    .segment("PID") { $0.field(2, value: "MRN001^^^Hosp^MR").field(4, value: "Smith^John") }
    .build()

// Validate
try message.validate()

// Inspect
let inspector = MessageInspector(message: message)
print(inspector.treeView())
```

---

## Development

### Building and Testing

```bash
# Build the package
swift build

# Run tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Generate coverage report (macOS)
xcrun llvm-cov export -format="lcov" \
  .build/debug/HL7kitPackageTests.xctest/Contents/MacOS/HL7kitPackageTests \
  -instr-profile .build/debug/codecov/default.profdata > coverage.lcov
```

### Code Quality

HL7kit maintains high code quality standards:

- **Code Coverage**: >90% for all core modules
- **SwiftLint**: Automated code style enforcement (see `.swiftlint.yml`)
- **Coding Standards**: Comprehensive guidelines in [CODING_STANDARDS.md](CODING_STANDARDS.md)

```bash
# Run SwiftLint (macOS)
swiftlint lint

# Auto-fix SwiftLint issues
swiftlint --fix
```

---

## Standards Compliance

HL7kit is fully compliant with HL7 v2.x (versions 2.1-2.8), HL7 v3.x (CDA R2), and FHIR R4 specifications.

### ✅ Compliance Status

| Standard | Version | Status | Test Coverage |
|----------|---------|--------|---------------|
| HL7 v2.x | 2.1-2.8 | ✅ Fully Compliant | 42+ tests |
| HL7 v3.x | CDA R2  | ✅ Fully Compliant | 20+ tests |
| FHIR     | R4      | ✅ Fully Compliant | 31+ tests |
| Interoperability | Cross-version | ✅ Verified | 6 tests |

### Key Compliance Features

#### HL7 v2.x
- ✅ Full support for versions 2.1 through 2.8
- ✅ Standard message types (ADT, ORU, ORM, ACK, QRY)
- ✅ Segment structure and field cardinality validation
- ✅ Data type compliance (TS, NM, CE, ST, etc.)
- ✅ Encoding rules and escape sequences
- ✅ Multiple character encodings (ASCII, UTF-8, UTF-16, etc.)
- ✅ Backward compatibility

#### HL7 v3.x (CDA R2)
- ✅ RIM (Reference Information Model) conformance
- ✅ CDA document structure validation
- ✅ XML schema compliance
- ✅ Narrative text requirements
- ✅ Structured body support
- ✅ C-CDA template support
- ✅ Vocabulary binding (LOINC, SNOMED CT)

#### FHIR R4
- ✅ Resource structure compliance
- ✅ Required element validation
- ✅ Reference integrity
- ✅ Cardinality rules
- ✅ JSON/XML format support
- ✅ US Core profiles
- ✅ Extension support
- ✅ Terminology binding

### Documentation
For detailed compliance information, see [COMPLIANCE_STATUS.md](COMPLIANCE_STATUS.md).

---

## Contributing

We welcome contributions! Before contributing, please:

1. Read our [Contributing Guidelines](CONTRIBUTING.md)
2. Review our [Governance Model](GOVERNANCE.md)
3. Understand our [Release Cadence](RELEASE_CADENCE.md)
4. Read our [Coding Standards](CODING_STANDARDS.md)
5. Ensure your code passes SwiftLint checks
6. Maintain >90% test coverage for new code
7. Add documentation for public APIs
8. Follow Swift 6.2 concurrency best practices

Contributions welcome in:

- Core implementation
- Documentation
- Testing
- Examples and tutorials
- Bug reports and feature requests

For detailed information on:
- **How to contribute**: See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Project governance**: See [GOVERNANCE.md](GOVERNANCE.md)
- **Release process**: See [RELEASE_CADENCE.md](RELEASE_CADENCE.md)
- **Code of conduct**: See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

---

## License

TBD - Consider MIT or Apache 2.0 for maximum adoption

---

## Contact & Resources

- **Repository**: https://github.com/Raster-Lab/HL7kit
- **Documentation**: Coming soon
- **Community**: Coming soon
- **Development Milestones**: [milestone.md](milestone.md)
- **Standards Documentation**:
  - [HL7 v2.x Standards](HL7V2X_STANDARDS.md)
  - [HL7 v3.x Standards](HL7V3X_STANDARDS.md)
  - [HL7 FHIR Standards](FHIR_STANDARDS.md)
- **Guides**:
  - [Examples & Tutorials](Examples/README.md)
  - [Architecture](ARCHITECTURE.md)
  - [Integration Guide](INTEGRATION_GUIDE.md)
  - [Security Guide](SECURITY_GUIDE.md)
  - [Migration Guide](MIGRATION_GUIDE.md)
  - [Concurrency Model](CONCURRENCY_MODEL.md)
  - [Performance](PERFORMANCE.md)
  - [Character Encoding](CHARACTER_ENCODING.md)

---

*This is a work in progress. The framework is currently in the planning and early development phase.*