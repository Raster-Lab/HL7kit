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

## Project Structure

```
HL7kit/
├── HL7v2Kit/          # HL7 v2.x toolkit
├── HL7v3Kit/          # HL7 v3.x toolkit
├── FHIRkit/           # HL7 FHIR toolkit
├── HL7Core/           # Shared utilities and protocols
├── Examples/          # Sample applications
├── Tests/             # Comprehensive test suites
└── Documentation/     # API documentation and guides
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

## Contributing

This project is in the planning phase. Once development begins, we'll welcome contributions in:

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