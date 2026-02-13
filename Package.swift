// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HL7kit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        // HL7 v2.x toolkit
        .library(
            name: "HL7v2Kit",
            targets: ["HL7v2Kit"]
        ),
        // HL7 v3.x toolkit
        .library(
            name: "HL7v3Kit",
            targets: ["HL7v3Kit"]
        ),
        // HL7 FHIR toolkit
        .library(
            name: "FHIRkit",
            targets: ["FHIRkit"]
        ),
        // Shared core utilities
        .library(
            name: "HL7Core",
            targets: ["HL7Core"]
        ),
        // Command-line tools
        .executable(
            name: "hl7",
            targets: ["HL7CLI"]
        ),
    ],
    dependencies: [
        // No external dependencies - native Swift only
    ],
    targets: [
        // MARK: - Core Module
        .target(
            name: "HL7Core",
            dependencies: [],
            path: "Sources/HL7Core"
        ),
        .testTarget(
            name: "HL7CoreTests",
            dependencies: ["HL7Core"],
            path: "Tests/HL7CoreTests"
        ),
        
        // MARK: - HL7 v2.x Module
        .target(
            name: "HL7v2Kit",
            dependencies: ["HL7Core"],
            path: "Sources/HL7v2Kit"
        ),
        .testTarget(
            name: "HL7v2KitTests",
            dependencies: ["HL7v2Kit", "HL7Core"],
            path: "Tests/HL7v2KitTests"
        ),
        
        // MARK: - HL7 v3.x Module
        .target(
            name: "HL7v3Kit",
            dependencies: ["HL7Core"],
            path: "Sources/HL7v3Kit"
        ),
        .testTarget(
            name: "HL7v3KitTests",
            dependencies: ["HL7v3Kit", "HL7Core"],
            path: "Tests/HL7v3KitTests"
        ),
        
        // MARK: - FHIR Module
        .target(
            name: "FHIRkit",
            dependencies: ["HL7Core"],
            path: "Sources/FHIRkit"
        ),
        .testTarget(
            name: "FHIRkitTests",
            dependencies: ["FHIRkit", "HL7Core"],
            path: "Tests/FHIRkitTests"
        ),
        
        // MARK: - CLI Executable
        .executableTarget(
            name: "HL7CLI",
            dependencies: ["HL7Core", "HL7v2Kit"],
            path: "Sources/HL7CLI"
        ),
        .testTarget(
            name: "HL7CLITests",
            dependencies: ["HL7Core", "HL7v2Kit"],
            path: "Tests/HL7CLITests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
