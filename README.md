# HL7kit

A pure-Swift HL7 framework for Apple platforms — parse, build, validate, and transmit HL7 v2.x and v3 messages with zero external dependencies.

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20iPadOS%20|%20watchOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

**HL7kit** is a comprehensive HL7 toolkit written entirely in Swift, inspired by [HAPI](https://hapifhir.github.io/hapi-hl7v2/). It provides two independent library targets for the fundamentally different HL7 standard families:

| Library | Standard | Format | Use Case |
|---------|----------|--------|----------|
| **HL7v2** | HL7 v2.1–v2.8 | Pipe-delimited (ER7) + XML | ADT, ORM, ORU, MDM and other clinical messaging |
| **HL7v3** | HL7 v3 / CDA R2 | XML (RIM-based) | Clinical Document Architecture, structured documents |

Both libraries share a thin common layer (**HL7Core**) for data types, error handling, and utilities.

> **Note:** HL7 FHIR is explicitly excluded from this project and will be developed separately.

## Key Features

- **Pure Swift 6.2** — strict concurrency with actors, `Sendable`, and structured concurrency
- **Apple-native** — uses `Network.framework`, `Foundation.XMLParser`, `os.Logger`, and `URLSession`
- **Low resource usage** — zero-copy parsing, lazy evaluation, value-type models
- **MLLP transport** — async client and server with TLS support via `Network.framework`
- **Validation** — structural, data-type, conformance profile, and HL7 table validation
- **Terser** — HAPI-style path access (`PID-3-1`, `OBX(2)-5`)
- **Message builder** — fluent API for programmatic message construction
- **CDA support** — parse and generate CDA R2 documents with RIM models

## Package Structure

```
HL7kit
├── HL7Core     # Shared protocols, data types, errors, utilities
├── HL7v2       # v2.x parser, encoder, validator, MLLP transport
└── HL7v3       # v3 RIM models, CDA parser/encoder, SOAP transport
```

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+, iPadOS 18+, watchOS 11+, visionOS 2+

## Installation

Add HL7kit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/HL7kit.git", from: "0.1.0")
]
```

Then add the targets you need:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "HL7v2", package: "HL7kit"),
        .product(name: "HL7v3", package: "HL7kit"),
    ]
)
```

## Quick Start

### Parse an HL7 v2 Message

```swift
import HL7v2

let raw = """
MSH|^~\\&|EPIC|HOSPITAL|LAB|LAB|202401011200||ADT^A04|00001|P|2.5
PID|1||12345^^^MRN||DOE^JOHN^A||19800101|M
"""

let message = try HL7v2.Message(parsing: raw)
let patientName = message.terser["PID-5-1"]  // "DOE"
```

### Build an HL7 v2 Message

```swift
import HL7v2

let message = HL7v2.MessageBuilder(version: .v25, type: "ADT", trigger: "A04")
    .msh { $0.sendingApplication("MyApp").sendingFacility("Hospital") }
    .pid { $0.patientName(family: "DOE", given: "JOHN") }
    .build()

let encoded = message.encodeER7()  // pipe-delimited string
```

### Send via MLLP

```swift
import HL7v2

let client = MLLPClient(host: "hl7server.local", port: 2575)
let ack = try await client.send(message)
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the comprehensive development plan covering all phases from core parsing through CDA support, validation, transport, performance optimisation, and documentation.

## Contributing

Contributions are welcome! Please see the roadmap for areas where help is needed.

## License

HL7kit is available under the MIT License. See [LICENSE](LICENSE) for details.