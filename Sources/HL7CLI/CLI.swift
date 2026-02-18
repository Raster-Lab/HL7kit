// CLI.swift
// HL7CLI
//
// Main entry point and argument parsing for the HL7kit command-line tools.
// Provides subcommands for validating, converting, inspecting, batch processing,
// and conformance checking of HL7 messages.

import Foundation

/// Represents a parsed command-line invocation
public enum Command: Sendable {
    case validate(ValidateOptions)
    case convert(ConvertOptions)
    case inspect(InspectOptions)
    case batch(BatchOptions)
    case conformance(ConformanceOptions)
    case benchmark(BenchmarkOptions)
    case help
    case version
}

/// Exit codes for the CLI
public enum ExitCode: Int32 {
    case success = 0
    case validationFailure = 1
    case inputError = 2
    case processingError = 3
    case usageError = 64
}

/// Options for the validate command
public struct ValidateOptions: Sendable {
    public let inputFiles: [String]
    public let readStdin: Bool
    public let strict: Bool
    public let format: OutputFormat

    public init(inputFiles: [String], readStdin: Bool = false, strict: Bool = false, format: OutputFormat = .text) {
        self.inputFiles = inputFiles
        self.readStdin = readStdin
        self.strict = strict
        self.format = format
    }
}

/// Options for the convert command
public struct ConvertOptions: Sendable {
    public let inputFile: String
    public let outputFile: String?
    public let fromFormat: MessageFormat
    public let toFormat: MessageFormat
    public let pretty: Bool

    public init(inputFile: String, outputFile: String? = nil, fromFormat: MessageFormat = .hl7v2,
         toFormat: MessageFormat = .hl7v2, pretty: Bool = false) {
        self.inputFile = inputFile
        self.outputFile = outputFile
        self.fromFormat = fromFormat
        self.toFormat = toFormat
        self.pretty = pretty
    }
}

/// Options for the inspect command
public struct InspectOptions: Sendable {
    public let inputFile: String
    public let showTree: Bool
    public let showStats: Bool
    public let searchTerm: String?
    public let format: OutputFormat

    public init(inputFile: String, showTree: Bool = true, showStats: Bool = false,
         searchTerm: String? = nil, format: OutputFormat = .text) {
        self.inputFile = inputFile
        self.showTree = showTree
        self.showStats = showStats
        self.searchTerm = searchTerm
        self.format = format
    }
}

/// Options for the batch command
public struct BatchOptions: Sendable {
    public let inputFiles: [String]
    public let outputDir: String?
    public let operation: BatchOperation
    public let continueOnError: Bool
    public let format: OutputFormat

    public init(inputFiles: [String], outputDir: String? = nil,
         operation: BatchOperation = .validate, continueOnError: Bool = true,
         format: OutputFormat = .text) {
        self.inputFiles = inputFiles
        self.outputDir = outputDir
        self.operation = operation
        self.continueOnError = continueOnError
        self.format = format
    }
}

/// Options for the conformance command
public struct ConformanceOptions: Sendable {
    public let inputFile: String
    public let profile: String?
    public let format: OutputFormat

    public init(inputFile: String, profile: String? = nil, format: OutputFormat = .text) {
        self.inputFile = inputFile
        self.profile = profile
        self.format = format
    }
}

/// Options for the benchmark command
public struct BenchmarkOptions: Sendable {
    public let inputFile: String?
    public let iterations: Int
    public let format: OutputFormat
    public let regression: Bool

    public init(inputFile: String? = nil, iterations: Int = 100, format: OutputFormat = .text, regression: Bool = false) {
        self.inputFile = inputFile
        self.iterations = iterations
        self.format = format
        self.regression = regression
    }
}

/// Output formats
public enum OutputFormat: String, Sendable {
    case text
    case json
}

/// Message formats for conversion
public enum MessageFormat: String, Sendable {
    case hl7v2
    case hl7v3
    case fhirJson = "fhir-json"
    case fhirXml = "fhir-xml"
}

/// Batch operations
public enum BatchOperation: String, Sendable {
    case validate
    case inspect
    case convert
}

/// Parses command-line arguments into a Command
public enum CLIParser {

    /// Parse command-line arguments into a Command
    public static func parse(_ arguments: [String]) -> Result<Command, CLIError> {
        // arguments[0] is the executable name
        let args = Array(arguments.dropFirst())

        guard let subcommand = args.first else {
            return .success(.help)
        }

        switch subcommand.lowercased() {
        case "validate":
            return parseValidate(Array(args.dropFirst()))
        case "convert":
            return parseConvert(Array(args.dropFirst()))
        case "inspect":
            return parseInspect(Array(args.dropFirst()))
        case "batch":
            return parseBatch(Array(args.dropFirst()))
        case "conformance":
            return parseConformance(Array(args.dropFirst()))
        case "benchmark":
            return parseBenchmark(Array(args.dropFirst()))
        case "help", "--help", "-h":
            return .success(.help)
        case "version", "--version", "-v":
            return .success(.version)
        default:
            return .failure(.unknownCommand(subcommand))
        }
    }

    // MARK: - Subcommand Parsers

    private static func parseValidate(_ args: [String]) -> Result<Command, CLIError> {
        var files: [String] = []
        var strict = false
        var format: OutputFormat = .text
        var readStdin = false

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--strict":
                strict = true
            case "--format":
                i += 1
                guard i < args.count, let f = OutputFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--format requires 'text' or 'json'"))
                }
                format = f
            case "--stdin", "-":
                readStdin = true
            case "--help", "-h":
                return .success(.help)
            default:
                if args[i].hasPrefix("-") {
                    return .failure(.unknownOption(args[i]))
                }
                files.append(args[i])
            }
            i += 1
        }

        if files.isEmpty && !readStdin {
            return .failure(.missingArgument("validate requires at least one input file or --stdin"))
        }

        return .success(.validate(ValidateOptions(
            inputFiles: files, readStdin: readStdin, strict: strict, format: format
        )))
    }

    private static func parseConvert(_ args: [String]) -> Result<Command, CLIError> {
        var inputFile: String?
        var outputFile: String?
        var fromFormat: MessageFormat = .hl7v2
        var toFormat: MessageFormat = .hl7v2
        var pretty = false

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--from":
                i += 1
                guard i < args.count, let f = MessageFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--from requires 'hl7v2', 'hl7v3', 'fhir-json', or 'fhir-xml'"))
                }
                fromFormat = f
            case "--to":
                i += 1
                guard i < args.count, let f = MessageFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--to requires 'hl7v2', 'hl7v3', 'fhir-json', or 'fhir-xml'"))
                }
                toFormat = f
            case "--output", "-o":
                i += 1
                guard i < args.count else {
                    return .failure(.invalidArgument("--output requires a file path"))
                }
                outputFile = args[i]
            case "--pretty":
                pretty = true
            case "--help", "-h":
                return .success(.help)
            default:
                if args[i].hasPrefix("-") {
                    return .failure(.unknownOption(args[i]))
                }
                if inputFile == nil {
                    inputFile = args[i]
                } else {
                    return .failure(.invalidArgument("Unexpected argument: \(args[i])"))
                }
            }
            i += 1
        }

        guard let input = inputFile else {
            return .failure(.missingArgument("convert requires an input file"))
        }

        return .success(.convert(ConvertOptions(
            inputFile: input, outputFile: outputFile,
            fromFormat: fromFormat, toFormat: toFormat, pretty: pretty
        )))
    }

    private static func parseInspect(_ args: [String]) -> Result<Command, CLIError> {
        var inputFile: String?
        var showTree = true
        var showStats = false
        var searchTerm: String?
        var format: OutputFormat = .text

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--no-tree":
                showTree = false
            case "--stats":
                showStats = true
            case "--search", "-s":
                i += 1
                guard i < args.count else {
                    return .failure(.invalidArgument("--search requires a search term"))
                }
                searchTerm = args[i]
            case "--format":
                i += 1
                guard i < args.count, let f = OutputFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--format requires 'text' or 'json'"))
                }
                format = f
            case "--help", "-h":
                return .success(.help)
            default:
                if args[i].hasPrefix("-") {
                    return .failure(.unknownOption(args[i]))
                }
                if inputFile == nil {
                    inputFile = args[i]
                } else {
                    return .failure(.invalidArgument("Unexpected argument: \(args[i])"))
                }
            }
            i += 1
        }

        guard let input = inputFile else {
            return .failure(.missingArgument("inspect requires an input file"))
        }

        return .success(.inspect(InspectOptions(
            inputFile: input, showTree: showTree, showStats: showStats,
            searchTerm: searchTerm, format: format
        )))
    }

    private static func parseBatch(_ args: [String]) -> Result<Command, CLIError> {
        var files: [String] = []
        var outputDir: String?
        var operation: BatchOperation = .validate
        var continueOnError = true
        var format: OutputFormat = .text

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--output-dir", "-d":
                i += 1
                guard i < args.count else {
                    return .failure(.invalidArgument("--output-dir requires a directory path"))
                }
                outputDir = args[i]
            case "--operation", "--op":
                i += 1
                guard i < args.count, let op = BatchOperation(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--operation requires 'validate', 'inspect', or 'convert'"))
                }
                operation = op
            case "--stop-on-error":
                continueOnError = false
            case "--format":
                i += 1
                guard i < args.count, let f = OutputFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--format requires 'text' or 'json'"))
                }
                format = f
            case "--help", "-h":
                return .success(.help)
            default:
                if args[i].hasPrefix("-") {
                    return .failure(.unknownOption(args[i]))
                }
                files.append(args[i])
            }
            i += 1
        }

        if files.isEmpty {
            return .failure(.missingArgument("batch requires at least one input file"))
        }

        return .success(.batch(BatchOptions(
            inputFiles: files, outputDir: outputDir,
            operation: operation, continueOnError: continueOnError, format: format
        )))
    }

    private static func parseConformance(_ args: [String]) -> Result<Command, CLIError> {
        var inputFile: String?
        var profile: String?
        var format: OutputFormat = .text

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--profile", "-p":
                i += 1
                guard i < args.count else {
                    return .failure(.invalidArgument("--profile requires a profile name"))
                }
                profile = args[i]
            case "--format":
                i += 1
                guard i < args.count, let f = OutputFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--format requires 'text' or 'json'"))
                }
                format = f
            case "--help", "-h":
                return .success(.help)
            default:
                if args[i].hasPrefix("-") {
                    return .failure(.unknownOption(args[i]))
                }
                if inputFile == nil {
                    inputFile = args[i]
                } else {
                    return .failure(.invalidArgument("Unexpected argument: \(args[i])"))
                }
            }
            i += 1
        }

        guard let input = inputFile else {
            return .failure(.missingArgument("conformance requires an input file"))
        }

        return .success(.conformance(ConformanceOptions(
            inputFile: input, profile: profile, format: format
        )))
    }

    private static func parseBenchmark(_ args: [String]) -> Result<Command, CLIError> {
        var inputFile: String?
        var iterations = 100
        var format: OutputFormat = .text
        var regression = false

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--iterations", "-n":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    return .failure(.invalidArgument("--iterations requires a positive integer"))
                }
                iterations = n
            case "--format":
                i += 1
                guard i < args.count, let f = OutputFormat(rawValue: args[i]) else {
                    return .failure(.invalidArgument("--format requires 'text' or 'json'"))
                }
                format = f
            case "--regression":
                regression = true
            case "--help", "-h":
                return .success(.help)
            default:
                if args[i].hasPrefix("-") {
                    return .failure(.unknownOption(args[i]))
                }
                if inputFile == nil {
                    inputFile = args[i]
                } else {
                    return .failure(.invalidArgument("Unexpected argument: \(args[i])"))
                }
            }
            i += 1
        }

        return .success(.benchmark(BenchmarkOptions(
            inputFile: inputFile, iterations: iterations, format: format, regression: regression
        )))
    }
}

/// CLI-specific errors
public enum CLIError: Error, CustomStringConvertible, Sendable {
    case unknownCommand(String)
    case unknownOption(String)
    case missingArgument(String)
    case invalidArgument(String)
    case fileNotFound(String)
    case readError(String)
    case processingError(String)

    public var description: String {
        switch self {
        case .unknownCommand(let cmd):
            return "Unknown command: '\(cmd)'. Run 'hl7 help' for usage information."
        case .unknownOption(let opt):
            return "Unknown option: '\(opt)'."
        case .missingArgument(let msg):
            return "Missing argument: \(msg)"
        case .invalidArgument(let msg):
            return "Invalid argument: \(msg)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .readError(let msg):
            return "Read error: \(msg)"
        case .processingError(let msg):
            return "Processing error: \(msg)"
        }
    }
}
