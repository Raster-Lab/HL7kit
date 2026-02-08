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
- **Test Data Sets**: Realistic test messages for validation including valid, invalid, and edge cases
- **High Test Coverage**: 468 unit tests with 90%+ code coverage

## Project Structure

```
HL7kit/
├── HL7v2Kit/          # HL7 v2.x toolkit
├── HL7v3Kit/          # HL7 v3.x toolkit
├── FHIRkit/           # HL7 FHIR toolkit
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
├── Tests/             # Comprehensive test suites (397 tests, 90%+ coverage)
├── TestData/          # Test messages for validation
│   └── HL7v2x/       # HL7 v2.x test messages
├── Documentation/     # API documentation and guides
├── HL7V2X_STANDARDS.md   # HL7 v2.x standards analysis
├── CONCURRENCY_MODEL.md  # Actor-based concurrency architecture
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

---

*This is a work in progress. The framework is currently in the planning and early development phase.*