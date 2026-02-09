# HL7kit - Swift HL7 Framework

A comprehensive, native Swift 6.2 framework for working with HL7 v2.x, v3.x, and FHIR standards on Apple platforms. This project provides separate toolkits optimized for low memory, CPU utilization, and network performance.

> **Note**: HL7 FHIR is included as a separate package within this suite called **FHIRkit**.

## Overview

HL7kit is designed to be a modern, Swift-native alternative to HAPI, built from the ground up to leverage Apple platform capabilities. Given the fundamental differences between HL7 v2.x (pipe-delimited messaging), v3.x (XML-based messaging), and FHIR (RESTful API-based), this framework is architected as separate but complementary toolkits.

### Key Features (Planned)

- **Native Swift 6.2**: Full utilization of modern Swift features including concurrency, actors, and strict typing
- **Apple Platform Optimization**: Leverages Foundation, Network.framework, and other native Apple frameworks
- **Performance Focused**: Optimized for minimal memory footprint and CPU usage
- **Network Efficient**: Smart caching, connection pooling, and efficient data transmission
- **Type-Safe**: Strong typing for message structures and validation
- **Comprehensive**: Full support for HL7 v2.x, v3.x, and FHIR standards

### Completed Features

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
- **FHIR R4 Resource Implementations**: Full implementations of 9 FHIR R4 resources (Patient, Observation, Practitioner, Organization, Condition, AllergyIntolerance, Encounter, MedicationRequest, DiagnosticReport), plus Bundle (with transaction/batch support) and OperationOutcome for error handling. Enhanced Patient with contact, communication, marital status, and practitioner fields. Enhanced Observation with value types, reference ranges, and components. All resources conform to DomainResource (Bundle to Resource), support Codable serialization, and are Sendable for concurrency safety. ResourceContainer supports polymorphic decoding/encoding of all resource types.
- **Test Data Sets**: Realistic test messages for validation including valid, invalid, and edge cases
- **High Test Coverage**: 1500+ unit tests with 90%+ code coverage

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
│   └── Resources/     # FHIR R4 resource implementations
├── HL7Core/           # Shared utilities and protocols
│   ├── HL7Core.swift          # Base protocols and types
│   ├── Validation.swift       # Validation framework
│   ├── DataProtocols.swift    # Data handling protocols
│   ├── ErrorRecovery.swift    # Error handling and recovery
│   ├── Logging.swift          # Structured logging system
│   ├── Benchmarking.swift     # Performance benchmarking
│   ├── ParsingStrategies.swift # Memory-efficient parsing
│   └── ActorPatterns.swift    # Concurrency patterns
├── Examples/          # Sample applications
├── Tests/             # Comprehensive test suites (1500+ tests, 90%+ coverage)
├── TestData/          # Test messages for validation
│   └── HL7v2x/       # HL7 v2.x test messages
├── Documentation/     # API documentation and guides
├── HL7V2X_STANDARDS.md   # HL7 v2.x standards analysis
├── HL7V3X_STANDARDS.md   # HL7 v3.x standards analysis
├── FHIR_STANDARDS.md     # HL7 FHIR standards analysis (R4, R5)
├── CONCURRENCY_MODEL.md  # Actor-based concurrency architecture
├── PERFORMANCE.md        # Performance optimization guide
└── CODING_STANDARDS.md   # Development standards
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
| Throughput | >10,000 msg/s | 15,000-25,000 msg/s |
| Latency (p50) | <100 μs | 40-80 μs |
| Memory/Message | <10 KB | 4-8 KB |

*Tested on Apple Silicon (M1/M2). See [PERFORMANCE.md](PERFORMANCE.md) for detailed benchmarks.*

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

## Contributing

We welcome contributions! Before contributing, please:

1. Read our [Coding Standards](CODING_STANDARDS.md)
2. Ensure your code passes SwiftLint checks
3. Maintain >90% test coverage for new code
4. Add documentation for public APIs
5. Follow Swift 6.2 concurrency best practices

Contributions welcome in:

- Core implementation
- Documentation
- Testing
- Examples and tutorials
- Bug reports and feature requests

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

---

*This is a work in progress. The framework is currently in the planning and early development phase.*