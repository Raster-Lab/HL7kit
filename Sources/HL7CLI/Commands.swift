// Commands.swift
// HL7CLI
//
// Command implementations for the HL7kit CLI tools.
// Each command processes HL7 messages using the HL7v2Kit library.

import Foundation
import HL7Core
import HL7v2Kit

// MARK: - File I/O Utilities

/// Creates a parser configured to accept any segment terminator style
public func createParser() -> HL7v2Parser {
    let config = ParserConfiguration(segmentTerminator: .any)
    return HL7v2Parser(configuration: config)
}

/// Reads the contents of a file at the given path
public func readFile(at path: String) throws -> String {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CLIError.fileNotFound(path)
    }
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        throw CLIError.readError("Cannot read file '\(path)': \(error.localizedDescription)")
    }
}

/// Reads all available input from standard input
public func readStandardInput() -> String {
    var lines: [String] = []
    while let line = readLine(strippingNewline: false) {
        lines.append(line)
    }
    return lines.joined()
}

/// Writes content to a file or stdout
public func writeOutput(_ content: String, to path: String?) throws {
    if let path = path {
        let url = URL(fileURLWithPath: path)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw CLIError.processingError("Cannot write to '\(path)': \(error.localizedDescription)")
        }
    } else {
        print(content)
    }
}

// MARK: - Validate Command

/// Executes the validate command
public func runValidate(_ options: ValidateOptions) -> ExitCode {
    var allValid = true
    var results: [[String: Any]] = []

    // Collect input sources
    var inputs: [(name: String, content: String)] = []

    for file in options.inputFiles {
        do {
            let content = try readFile(at: file)
            inputs.append((name: file, content: content))
        } catch {
            printError("\(error)")
            allValid = false
            if options.format == .json {
                results.append(["file": file, "valid": false, "error": "\(error)"])
            }
        }
    }

    if options.readStdin {
        let content = readStandardInput()
        inputs.append((name: "<stdin>", content: content))
    }

    let parser = createParser()
    let engine = HL7v2ValidationEngine()

    for input in inputs {
        let result = validateMessage(
            input.content, name: input.name,
            parser: parser, engine: engine,
            strict: options.strict
        )

        switch options.format {
        case .text:
            printValidationResult(result, name: input.name)
        case .json:
            results.append(result.toDict(name: input.name))
        }

        if !result.isValid {
            allValid = false
        }
    }

    if options.format == .json {
        printJSON(["results": results])
    }

    return allValid ? .success : .validationFailure
}

/// Result of validating a single message
struct MessageValidationResult {
    let name: String
    let isValid: Bool
    let segmentCount: Int
    let messageType: String?
    let issues: [ValidationIssue]
    let parseError: String?

    func toDict(name: String) -> [String: Any] {
        var dict: [String: Any] = [
            "file": name,
            "valid": isValid
        ]
        if let messageType = messageType { dict["messageType"] = messageType }
        dict["segmentCount"] = segmentCount
        if let error = parseError { dict["error"] = error }
        if !issues.isEmpty {
            dict["issues"] = issues.map { issue -> [String: Any] in
                var d: [String: Any] = [
                    "severity": issue.severity.rawValue,
                    "message": issue.message
                ]
                if let loc = issue.location { d["location"] = loc }
                if let code = issue.code { d["code"] = code }
                return d
            }
        }
        return dict
    }
}

/// Validates a single message
private func validateMessage(
    _ content: String, name: String,
    parser: HL7v2Parser, engine: HL7v2ValidationEngine,
    strict: Bool
) -> MessageValidationResult {
    do {
        let parseResult = try parser.parse(content)
        let message = parseResult.message
        let msgType = message.messageType()

        // Auto-detect profile and validate against it
        let validationResult: ValidationResult
        if let profile = resolveProfile(msgType) {
            validationResult = engine.validate(message, against: profile)
        } else {
            // No matching profile; apply basic structural validation using rules
            let rules: [HL7v2ValidationRule] = [
                RequiredSegmentRule(segmentID: "MSH"),
            ]
            validationResult = engine.validate(message, rules: rules)
        }

        var issues = validationResult.issues

        // Add parser warnings as validation issues
        for warning in parseResult.diagnostics.warnings {
            issues.append(ValidationIssue(
                severity: .warning,
                message: warning.message,
                location: nil,
                code: "PARSE_WARNING"
            ))
        }

        let isValid: Bool
        if strict {
            isValid = issues.isEmpty
        } else {
            isValid = !issues.contains { $0.severity == .error }
        }

        return MessageValidationResult(
            name: name,
            isValid: isValid,
            segmentCount: message.segmentCount,
            messageType: msgType,
            issues: issues,
            parseError: nil
        )
    } catch {
        return MessageValidationResult(
            name: name,
            isValid: false,
            segmentCount: 0,
            messageType: nil,
            issues: [],
            parseError: "\(error)"
        )
    }
}

/// Prints validation result in text format
private func printValidationResult(_ result: MessageValidationResult, name: String) {
    let icon = result.isValid ? "✓" : "✗"
    let status = result.isValid ? "VALID" : "INVALID"
    print("\(icon) \(name): \(status)")

    if let msgType = result.messageType {
        print("  Message Type: \(msgType)")
    }
    print("  Segments: \(result.segmentCount)")

    if let error = result.parseError {
        print("  Parse Error: \(error)")
    }

    for issue in result.issues {
        let prefix: String
        switch issue.severity {
        case .error: prefix = "  ERROR"
        case .warning: prefix = "  WARN "
        case .info: prefix = "  INFO "
        }
        let location = issue.location.map { " [\($0)]" } ?? ""
        print("\(prefix):\(location) \(issue.message)")
    }

    if !result.isValid || !result.issues.isEmpty {
        print("")
    }
}

// MARK: - Inspect Command

/// Executes the inspect command
public func runInspect(_ options: InspectOptions) -> ExitCode {
    let content: String
    do {
        content = try readFile(at: options.inputFile)
    } catch {
        printError("\(error)")
        return .inputError
    }

    let parser = createParser()
    let parseResult: ParseResult
    do {
        parseResult = try parser.parse(content)
    } catch {
        printError("Failed to parse '\(options.inputFile)': \(error)")
        return .processingError
    }

    let message = parseResult.message
    let inspector = MessageInspector(message: message)

    switch options.format {
    case .text:
        printInspection(inspector, options: options)
    case .json:
        printInspectionJSON(inspector, options: options)
    }

    return .success
}

/// Prints inspection output in text format
private func printInspection(_ inspector: MessageInspector, options: InspectOptions) {
    // Always show summary
    print(inspector.summary())

    if options.showTree {
        print("")
        print("Message Tree:")
        print(inspector.treeView())
    }

    if options.showStats {
        print("")
        print("Statistics:")
        let stats = inspector.statistics()
        for (key, value) in stats.sorted(by: { $0.key < $1.key }) {
            print("  \(key): \(value)")
        }
    }

    if let term = options.searchTerm {
        print("")
        print("Search Results for '\(term)':")
        let results = inspector.search(for: term)
        if results.isEmpty {
            print("  No matches found.")
        } else {
            for result in results {
                print("  \(result.segment) Field \(result.field): \(result.value)")
            }
        }
    }
}

/// Prints inspection output in JSON format
private func printInspectionJSON(_ inspector: MessageInspector, options: InspectOptions) {
    var dict: [String: Any] = [
        "summary": inspector.summary()
    ]

    if options.showTree {
        dict["tree"] = inspector.treeView()
    }

    if options.showStats {
        dict["statistics"] = inspector.statistics()
    }

    if let term = options.searchTerm {
        let results = inspector.search(for: term)
        dict["searchResults"] = results.map { r -> [String: Any] in
            ["segment": r.segment, "field": r.field, "value": r.value]
        }
    }

    printJSON(dict)
}

// MARK: - Convert Command

/// Executes the convert command
public func runConvert(_ options: ConvertOptions) -> ExitCode {
    let content: String
    do {
        content = try readFile(at: options.inputFile)
    } catch {
        printError("\(error)")
        return .inputError
    }

    // Currently support HL7 v2.x round-trip conversion (parse and re-serialize)
    switch (options.fromFormat, options.toFormat) {
    case (.hl7v2, .hl7v2):
        return convertV2ToV2(content, options: options)
    case (.hl7v2, .hl7v3):
        return convertV2ToV3(content, options: options)
    default:
        // Other conversions are not yet fully supported
        printError("Conversion from \(options.fromFormat.rawValue) to \(options.toFormat.rawValue) is not yet supported.")
        printError("Supported conversions: hl7v2 -> hl7v2, hl7v2 -> hl7v3")
        return .processingError
    }
}

/// Re-serializes an HL7 v2.x message (useful for normalization)
private func convertV2ToV2(_ content: String, options: ConvertOptions) -> ExitCode {
    let parser = createParser()
    do {
        let result = try parser.parse(content)
        let output = try result.message.serialize()
        try writeOutput(output, to: options.outputFile)
        return .success
    } catch {
        printError("Conversion failed: \(error)")
        return .processingError
    }
}

/// Converts an HL7 v2.x message to v3.x CDA format
private func convertV2ToV3(_ content: String, options: ConvertOptions) -> ExitCode {
    let parser = createParser()
    do {
        let result = try parser.parse(content)
        let message = result.message

        // Build a basic CDA-like XML representation from the v2.x message
        let xml = buildBasicCDAFromV2(message, pretty: options.pretty)
        try writeOutput(xml, to: options.outputFile)
        return .success
    } catch {
        printError("Conversion failed: \(error)")
        return .processingError
    }
}

/// Builds a basic CDA XML document from an HL7 v2.x message
private func buildBasicCDAFromV2(_ message: HL7v2Message, pretty: Bool) -> String {
    let indent = pretty ? "  " : ""
    let nl = pretty ? "\n" : ""

    var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\(nl)"
    xml += "<ClinicalDocument xmlns=\"urn:hl7-org:v3\">\(nl)"

    // Extract message info
    let msgType = message.messageType()
    let controlId = message.messageControlID()
    let version = message.version()

    xml += "\(indent)<typeId root=\"2.16.840.1.113883.1.3\" extension=\"POCD_HD000040\"/>\(nl)"
    xml += "\(indent)<id root=\"\(controlId)\"/>\(nl)"
    xml += "\(indent)<code code=\"\(msgType)\" codeSystem=\"2.16.840.1.113883.6.1\"/>\(nl)"
    xml += "\(indent)<title>Converted from HL7 v\(version) \(msgType)</title>\(nl)"

    // Extract patient info from PID segment if present
    let pidSegments = message.segments(withID: "PID")
    if let pid = pidSegments.first {
        xml += "\(indent)<recordTarget>\(nl)"
        xml += "\(indent)\(indent)<patientRole>\(nl)"

        // Patient name (PID-5, 0-based index 4)
        if pid.fields.count > 5 {
            let nameField = "\(pid[4])"
            xml += "\(indent)\(indent)\(indent)<patient>\(nl)"
            xml += "\(indent)\(indent)\(indent)\(indent)<name>\(nl)"
            let nameComponents = nameField.split(separator: "^").map(String.init)
            if nameComponents.count > 1 {
                xml += "\(indent)\(indent)\(indent)\(indent)\(indent)<given>\(escapeXML(nameComponents[1]))</given>\(nl)"
            }
            if !nameComponents.isEmpty {
                xml += "\(indent)\(indent)\(indent)\(indent)\(indent)<family>\(escapeXML(nameComponents[0]))</family>\(nl)"
            }
            xml += "\(indent)\(indent)\(indent)\(indent)</name>\(nl)"
            xml += "\(indent)\(indent)\(indent)</patient>\(nl)"
        }

        xml += "\(indent)\(indent)</patientRole>\(nl)"
        xml += "\(indent)</recordTarget>\(nl)"
    }

    // Include all segments as a structured body
    xml += "\(indent)<component>\(nl)"
    xml += "\(indent)\(indent)<structuredBody>\(nl)"

    for i in 0..<message.segmentCount {
        if let segment = message[i] {
            let segId = segment.segmentID
            xml += "\(indent)\(indent)\(indent)<component>\(nl)"
            xml += "\(indent)\(indent)\(indent)\(indent)<section>\(nl)"
            xml += "\(indent)\(indent)\(indent)\(indent)\(indent)<code code=\"\(escapeXML(segId))\"/>\(nl)"
            xml += "\(indent)\(indent)\(indent)\(indent)\(indent)<title>\(escapeXML(segId)) Segment</title>\(nl)"

            // Add fields as text content
            xml += "\(indent)\(indent)\(indent)\(indent)\(indent)<text>\(nl)"
            let fieldLimit = min(segment.fields.count, 50)
            for fieldIdx in 0..<fieldLimit {
                let fieldValue = "\(segment[fieldIdx])"
                if !fieldValue.isEmpty {
                    xml += "\(indent)\(indent)\(indent)\(indent)\(indent)\(indent)<paragraph>\(escapeXML(segId))-\(fieldIdx + 1): \(escapeXML(fieldValue))</paragraph>\(nl)"
                }
            }
            xml += "\(indent)\(indent)\(indent)\(indent)\(indent)</text>\(nl)"
            xml += "\(indent)\(indent)\(indent)\(indent)</section>\(nl)"
            xml += "\(indent)\(indent)\(indent)</component>\(nl)"
        }
    }

    xml += "\(indent)\(indent)</structuredBody>\(nl)"
    xml += "\(indent)</component>\(nl)"
    xml += "</ClinicalDocument>\(nl)"

    return xml
}

/// Escapes special characters for XML
private func escapeXML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

// MARK: - Batch Command

/// Executes the batch command
public func runBatch(_ options: BatchOptions) -> ExitCode {
    var totalFiles = 0
    var successCount = 0
    var failureCount = 0
    var batchResults: [[String: Any]] = []

    // Create output directory if needed
    if let outputDir = options.outputDir {
        let fm = FileManager.default
        if !fm.fileExists(atPath: outputDir) {
            do {
                try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
            } catch {
                printError("Cannot create output directory '\(outputDir)': \(error)")
                return .processingError
            }
        }
    }

    for file in options.inputFiles {
        totalFiles += 1

        let result = processBatchFile(file, operation: options.operation, outputDir: options.outputDir)

        switch options.format {
        case .text:
            printBatchResult(result)
        case .json:
            batchResults.append(result.toDict())
        }

        if result.success {
            successCount += 1
        } else {
            failureCount += 1
            if !options.continueOnError {
                if options.format == .text {
                    print("\nStopped due to error (--stop-on-error)")
                }
                break
            }
        }
    }

    // Print summary
    switch options.format {
    case .text:
        print("")
        print("Batch Summary:")
        print("  Total files: \(totalFiles)")
        print("  Succeeded:   \(successCount)")
        print("  Failed:      \(failureCount)")
    case .json:
        printJSON([
            "results": batchResults,
            "summary": [
                "total": totalFiles,
                "succeeded": successCount,
                "failed": failureCount
            ] as [String: Any]
        ])
    }

    return failureCount == 0 ? .success : .validationFailure
}

/// Result of processing a single batch file
struct BatchFileResult {
    let file: String
    let success: Bool
    let operation: String
    let detail: String
    let error: String?

    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "file": file,
            "success": success,
            "operation": operation,
            "detail": detail
        ]
        if let error = error { dict["error"] = error }
        return dict
    }
}

/// Processes a single file in a batch operation
private func processBatchFile(_ file: String, operation: BatchOperation, outputDir: String?) -> BatchFileResult {
    let content: String
    do {
        content = try readFile(at: file)
    } catch {
        return BatchFileResult(
            file: file, success: false,
            operation: operation.rawValue, detail: "", error: "\(error)"
        )
    }

    let parser = createParser()

    switch operation {
    case .validate:
        let engine = HL7v2ValidationEngine()
        let result = validateMessage(
            content, name: file, parser: parser, engine: engine, strict: false
        )
        return BatchFileResult(
            file: file, success: result.isValid,
            operation: "validate",
            detail: result.isValid ? "Valid (\(result.segmentCount) segments)" : "Invalid (\(result.issues.count) issues)",
            error: result.parseError
        )

    case .inspect:
        do {
            let parseResult = try parser.parse(content)
            let inspector = MessageInspector(message: parseResult.message)
            let summary = inspector.summary()

            if let outputDir = outputDir {
                let baseName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                let outputPath = "\(outputDir)/\(baseName)_inspection.txt"
                let fullOutput = summary + "\n\n" + inspector.treeView()
                try writeOutput(fullOutput, to: outputPath)
                return BatchFileResult(
                    file: file, success: true,
                    operation: "inspect", detail: "Written to \(outputPath)", error: nil
                )
            }

            return BatchFileResult(
                file: file, success: true,
                operation: "inspect", detail: summary, error: nil
            )
        } catch {
            return BatchFileResult(
                file: file, success: false,
                operation: "inspect", detail: "", error: "\(error)"
            )
        }

    case .convert:
        do {
            let parseResult = try parser.parse(content)
            let serialized = try parseResult.message.serialize()

            if let outputDir = outputDir {
                let baseName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
                let outputPath = "\(outputDir)/\(baseName)_converted.hl7"
                try writeOutput(serialized, to: outputPath)
                return BatchFileResult(
                    file: file, success: true,
                    operation: "convert", detail: "Written to \(outputPath)", error: nil
                )
            }

            return BatchFileResult(
                file: file, success: true,
                operation: "convert",
                detail: "Converted (\(parseResult.message.segmentCount) segments)",
                error: nil
            )
        } catch {
            return BatchFileResult(
                file: file, success: false,
                operation: "convert", detail: "", error: "\(error)"
            )
        }
    }
}

/// Prints a batch result in text format
private func printBatchResult(_ result: BatchFileResult) {
    let icon = result.success ? "✓" : "✗"
    print("\(icon) [\(result.operation)] \(result.file): \(result.detail)")
    if let error = result.error {
        print("  Error: \(error)")
    }
}

// MARK: - Conformance Command

/// Executes the conformance command
public func runConformance(_ options: ConformanceOptions) -> ExitCode {
    let content: String
    do {
        content = try readFile(at: options.inputFile)
    } catch {
        printError("\(error)")
        return .inputError
    }

    let parser = createParser()
    let parseResult: ParseResult
    do {
        parseResult = try parser.parse(content)
    } catch {
        printError("Failed to parse '\(options.inputFile)': \(error)")
        return .processingError
    }

    let message = parseResult.message
    let engine = HL7v2ValidationEngine()

    // Determine the profile to use
    let profile: ConformanceProfile
    if let profileName = options.profile {
        guard let p = resolveProfile(profileName) else {
            printError("Unknown profile: '\(profileName)'. Available profiles: ADT_A01, ORU_R01, ORM_O01, ACK")
            return .usageError
        }
        profile = p
    } else {
        // Auto-detect profile from message type
        let msgType = message.messageType()
        guard let p = resolveProfile(msgType) else {
            printError("Cannot auto-detect profile for message type '\(msgType)'. Use --profile to specify one.")
            printError("Available profiles: ADT_A01, ORU_R01, ORM_O01, ACK")
            return .usageError
        }
        profile = p
    }

    let result = engine.validate(message, against: profile)

    switch options.format {
    case .text:
        printConformanceResult(result, profile: profile, file: options.inputFile, message: message)
    case .json:
        printConformanceJSON(result, profile: profile, file: options.inputFile, message: message)
    }

    return result.isValid ? .success : .validationFailure
}

/// Resolves a profile name to a ConformanceProfile
private func resolveProfile(_ name: String) -> ConformanceProfile? {
    switch name.uppercased() {
    case "ADT_A01", "ADT^A01":
        return StandardProfiles.adtA01
    case "ORU_R01", "ORU^R01":
        return StandardProfiles.oruR01
    case "ORM_O01", "ORM^O01":
        return StandardProfiles.ormO01
    case "ACK":
        return StandardProfiles.ack
    default:
        return nil
    }
}

/// Prints conformance result in text format
private func printConformanceResult(
    _ result: ValidationResult, profile: ConformanceProfile,
    file: String, message: HL7v2Message
) {
    let icon = result.isValid ? "✓" : "✗"
    let status = result.isValid ? "CONFORMANT" : "NON-CONFORMANT"

    print("\(icon) Conformance Check: \(status)")
    print("  File:    \(file)")
    print("  Profile: \(profile.identifier) - \(profile.description)")
    print("  Version: \(profile.hl7Version)")
    print("  Message: \(message.messageType())")
    print("")

    let issues = result.issues
    if issues.isEmpty {
        print("  No conformance issues found.")
    } else {
        let errors = issues.filter { $0.severity == .error }
        let warnings = issues.filter { $0.severity == .warning }
        let infos = issues.filter { $0.severity == .info }

        if !errors.isEmpty {
            print("  Errors (\(errors.count)):")
            for issue in errors {
                let loc = issue.location.map { " [\($0)]" } ?? ""
                print("    ✗\(loc) \(issue.message)")
            }
        }

        if !warnings.isEmpty {
            print("  Warnings (\(warnings.count)):")
            for issue in warnings {
                let loc = issue.location.map { " [\($0)]" } ?? ""
                print("    ⚠\(loc) \(issue.message)")
            }
        }

        if !infos.isEmpty {
            print("  Info (\(infos.count)):")
            for issue in infos {
                let loc = issue.location.map { " [\($0)]" } ?? ""
                print("    ℹ\(loc) \(issue.message)")
            }
        }
    }
}

/// Prints conformance result in JSON format
private func printConformanceJSON(
    _ result: ValidationResult, profile: ConformanceProfile,
    file: String, message: HL7v2Message
) {
    let issues = result.issues
    let dict: [String: Any] = [
        "file": file,
        "conformant": result.isValid,
        "profile": [
            "identifier": profile.identifier,
            "description": profile.description,
            "version": profile.hl7Version
        ] as [String: Any],
        "messageType": message.messageType(),
        "issues": issues.map { issue -> [String: Any] in
            var d: [String: Any] = [
                "severity": issue.severity.rawValue,
                "message": issue.message
            ]
            if let loc = issue.location { d["location"] = loc }
            if let code = issue.code { d["code"] = code }
            return d
        }
    ]
    printJSON(dict)
}

// MARK: - Output Helpers

/// Prints an error message to stderr
public func printError(_ message: String) {
    let stderr = FileHandle.standardError
    stderr.write(Data("Error: \(message)\n".utf8))
}

/// Prints a dictionary as JSON to stdout
public func printJSON(_ dict: [String: Any]) {
    do {
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        if let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } catch {
        printError("Failed to serialize JSON: \(error)")
    }
}
