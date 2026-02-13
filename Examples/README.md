# HL7kit Examples & Tutorials

This directory contains sample code demonstrating how to use HL7kit for common healthcare integration scenarios. Each file is self-contained and covers a specific topic.

## Quick Start

```swift
import HL7v2Kit

// Parse a message
let message = try HL7v2Message.parse("MSH|^~\\&|App|Fac|App|Fac|20240101||ADT^A01|CTL001|P|2.5.1")

// Build a message
let built = try HL7v2MessageBuilder()
    .msh { $0.sendingApplication("App").messageType("ADT", triggerEvent: "A01").messageControlID("ID1").processingID("P").version("2.5.1") }
    .segment("PID") { $0.field(2, value: "MRN001^^^Hosp^MR").field(4, value: "Smith^John") }
    .build()

// Validate
try message.validate()
```

## Files

| File | Topics Covered |
|------|---------------|
| [QuickStart.swift](QuickStart.swift) | Parsing, building, validating, inspecting messages, FHIR overview |
| [CommonUseCases.swift](CommonUseCases.swift) | ADT workflows, ORU lab results, ORM orders, ACK responses, batch processing |
| [IntegrationExamples.swift](IntegrationExamples.swift) | v2→v3 CDA transformation, FHIR resources, JSON/XML serialization, CLI usage |
| [PerformanceOptimization.swift](PerformanceOptimization.swift) | Object pooling, string interning, streaming, compression, benchmarking |
| [iOSExamples.swift](iOSExamples.swift) | SwiftUI/UIKit views, notifications, background processing, local storage |
| [macOSExamples.swift](macOSExamples.swift) | AppKit windows, menu bar, AppleScript, batch processing, CLI integration |

## Platform-Specific Examples

### iOS (iOSExamples.swift)
- **SwiftUI Components**: `HL7MessageView`, `FHIRPatientCard`, `MessageListView`
- **UIKit Controllers**: `HL7MessageViewController` with table view
- **Notifications**: Background processing notifications with `NotificationManager`
- **Background Tasks**: `BackgroundMessageProcessor` for processing while app is not active
- **Local Storage**: `iOSMessageStorage` for document directory file management

### macOS (macOSExamples.swift)
- **AppKit Windows**: `HL7MessageWindowController` with split view and table view
- **Menu Bar**: `HL7MenuBarManager` for status bar integration
- **AppleScript**: `AppleScriptSupport` for automation
- **Service Menu**: `HL7ServiceProvider` for system-wide services
- **Batch Processing**: `BatchFileProcessor` with progress reporting
- **Document-Based**: `HL7Document` class for document-based applications
- **CLI Integration**: `CLIIntegration` for running command-line tools

## Modules

HL7kit is organized into four modules. Import only the ones you need:

```swift
import HL7Core      // Shared protocols, logging, security, persistence
import HL7v2Kit     // HL7 v2.x message parsing, building, validation, MLLP
import HL7v3Kit     // HL7 v3.x / CDA document processing, vocabulary
import FHIRkit      // FHIR R4 resources, REST client, search, validation
```

## Building and Running

```bash
# Build the framework
swift build

# Run the CLI tool
swift run hl7 --help

# Run tests
swift test

# Run tests with coverage
swift test --enable-code-coverage
```

## CLI Tool Quick Reference

```bash
# Validate a message
swift run hl7 validate path/to/message.hl7

# Inspect message structure
swift run hl7 inspect path/to/message.hl7

# Convert formats
swift run hl7 convert path/to/message.hl7

# Batch process a directory
swift run hl7 batch path/to/directory --operation validate

# Conformance check
swift run hl7 conformance path/to/message.hl7 --profile ADT_A01
```

## Further Reading

- [Architecture Guide](../ARCHITECTURE.md) — Module design and data flow
- [Integration Guide](../INTEGRATION_GUIDE.md) — Shared services and common patterns
- [Performance Guide](../PERFORMANCE.md) — Optimization techniques and benchmarks
- [Security Guide](../SECURITY_GUIDE.md) — Encryption, signing, HIPAA compliance
- [Migration Guide](../MIGRATION_GUIDE.md) — Upgrading between versions
- [Character Encoding](../CHARACTER_ENCODING.md) — Multi-encoding support
- [Concurrency Model](../CONCURRENCY_MODEL.md) — Actor-based thread safety
