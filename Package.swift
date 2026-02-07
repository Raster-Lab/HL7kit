// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HL7kit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "HL7Core", targets: ["HL7Core"]),
        .library(name: "HL7v2", targets: ["HL7v2"]),
        .library(name: "HL7v3", targets: ["HL7v3"]),
    ],
    targets: [
        // MARK: - Core
        .target(
            name: "HL7Core",
            path: "Sources/HL7Core"
        ),

        // MARK: - HL7 v2.x
        .target(
            name: "HL7v2",
            dependencies: ["HL7Core"],
            path: "Sources/HL7v2"
        ),

        // MARK: - HL7 v3
        .target(
            name: "HL7v3",
            dependencies: ["HL7Core"],
            path: "Sources/HL7v3"
        ),

        // MARK: - Tests
        .testTarget(
            name: "HL7CoreTests",
            dependencies: ["HL7Core"],
            path: "Tests/HL7CoreTests"
        ),
        .testTarget(
            name: "HL7v2Tests",
            dependencies: ["HL7v2"],
            path: "Tests/HL7v2Tests"
        ),
        .testTarget(
            name: "HL7v3Tests",
            dependencies: ["HL7v3"],
            path: "Tests/HL7v3Tests"
        ),
    ]
)
