/// HL7 CLI Example
///
/// Demonstrates how to use the HL7Core CLI tool types to validate,
/// convert, check conformance, and batch-process HL7 v2.x messages.
///
/// Usage:
///   swift HL7CLIExample.swift [command] [options]
///
/// Commands:
///   validate     Validate an HL7 message
///   convert      Convert between formats (hl7v2, json, xml, prettyPrint)
///   conformance  Check conformance against a profile
///   batch        Process a batch of messages
///   demo         Run all demonstrations

import Foundation
import HL7Core

/// Sample HL7 v2.x ADT^A01 message for demonstration
let sampleMessage =
    "MSH|^~\\&|SENDING|FACILITY|RECEIVING|FACILITY|20230615120000||ADT^A01|MSG001|P|2.5\r"
    + "PID|1||12345^^^MRN||DOE^JOHN||19800101|M\r"
    + "PV1|1|I|ICU^101^A|||||||ATT^DOCTOR\r"
    + "EVN|A01|20230615120000\r"

/// Runs the demonstration for the given command
func run() async throws {
    let args = CommandLine.arguments
    let command = args.count > 1 ? args[1] : "demo"

    switch command {
    case "validate":
        try await runValidation()
    case "convert":
        let format = args.count > 2 ? args[2] : "prettyPrint"
        try await runConversion(outputFormat: format)
    case "conformance":
        let profile = args.count > 2 ? args[2] : nil
        try await runConformance(profile: profile)
    case "batch":
        try await runBatch()
    case "demo":
        try await runDemo()
    default:
        printUsage()
    }
}

// MARK: - Commands

func runValidation() async throws {
    print("── Message Validation ──\n")
    let validator = MessageValidatorCLI()
    let report = try await validator.validate(input: sampleMessage)
    let formatter = CLIOutputFormatter()
    print(formatter.formatText(report))
}

func runConversion(outputFormat: String) async throws {
    print("── Format Conversion ──\n")
    let converter = FormatConverterCLI()
    let output: FormatConverterCLI.OutputFormat
    switch outputFormat.lowercased() {
    case "json":       output = .json
    case "xml":        output = .xml
    case "hl7v2":      output = .hl7v2
    default:           output = .prettyPrint
    }
    let result = try await converter.convert(input: sampleMessage, from: .hl7v2, to: output)
    print(result)
}

func runConformance(profile: String?) async throws {
    print("── Conformance Check ──\n")
    let checker = ConformanceCheckerCLI()
    let report = try await checker.checkConformance(message: sampleMessage, profile: profile)
    let formatter = CLIOutputFormatter()
    print(formatter.formatText(report))
}

func runBatch() async throws {
    print("── Batch Processing ──\n")
    // Two messages back-to-back
    let batchContent = sampleMessage
        + "MSH|^~\\&|LAB|FACILITY|RECEIVING|FACILITY|20230615130000||ORU^R01|MSG002|P|2.5\r"
        + "PID|1||67890^^^MRN||SMITH^JANE||19900515|F\r"
        + "OBR|1||LAB123|CBC^Complete Blood Count\r"

    let processor = BatchProcessorCLI()
    let report = try await processor.processFile(content: batchContent, operation: .validate)
    let formatter = CLIOutputFormatter()
    print(formatter.formatText(report))
}

func runDemo() async throws {
    print("╔══════════════════════════════════╗")
    print("║   HL7kit CLI Tools Demo          ║")
    print("╚══════════════════════════════════╝\n")

    // 1. Validation
    try await runValidation()
    print()

    // 2. Format Conversion — JSON
    print("── Conversion to JSON ──\n")
    let converter = FormatConverterCLI()
    let json = try await converter.convert(input: sampleMessage, from: .hl7v2, to: .json)
    print(json)
    print()

    // 3. Format Conversion — Pretty Print
    print("── Pretty Print ──\n")
    let pretty = try await converter.convert(input: sampleMessage, from: .hl7v2, to: .prettyPrint)
    print(pretty)
    print()

    // 4. Conformance
    try await runConformance(profile: nil)
    print()

    // 5. Batch
    try await runBatch()
    print()

    // 6. JSON output format
    print("── Validation Report (JSON) ──\n")
    let validator = MessageValidatorCLI()
    let report = try await validator.validate(input: sampleMessage)
    let formatter = CLIOutputFormatter()
    print(formatter.formatJSON(report))

    print("\n── Demo complete ──")
}

func printUsage() {
    print("""
    Usage: HL7CLIExample [command] [options]

    Commands:
      validate              Validate the sample HL7 message
      convert [format]      Convert to format: json, xml, prettyPrint (default)
      conformance [profile] Check conformance (profile optional)
      batch                 Batch-process multiple messages
      demo                  Run all demonstrations (default)
    """)
}

// MARK: - Entry Point

// Run the async entry point
let semaphore = DispatchSemaphore(value: 0)
Task {
    do {
        try await run()
    } catch {
        print("Error: \(error)")
    }
    semaphore.signal()
}
semaphore.wait()
