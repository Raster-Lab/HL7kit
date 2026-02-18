// HL7CLITests.swift
// HL7CLITests
//
// Tests for the HL7kit command-line tools argument parsing and command logic.

import XCTest
import HL7Core
import HL7v2Kit
@testable import HL7CLICore

// MARK: - CLI Parser Tests

final class CLIParserTests: XCTestCase {

    // MARK: - Top-level Command Parsing

    func testParseHelp() {
        let result = CLIParser.parse(["hl7", "help"])
        if case .success(.help) = result {
            // pass
        } else {
            XCTFail("Expected .help command")
        }
    }

    func testParseHelpFlag() {
        let result = CLIParser.parse(["hl7", "--help"])
        if case .success(.help) = result {
            // pass
        } else {
            XCTFail("Expected .help command")
        }
    }

    func testParseHelpShortFlag() {
        let result = CLIParser.parse(["hl7", "-h"])
        if case .success(.help) = result {
            // pass
        } else {
            XCTFail("Expected .help command")
        }
    }

    func testParseVersion() {
        let result = CLIParser.parse(["hl7", "--version"])
        if case .success(.version) = result {
            // pass
        } else {
            XCTFail("Expected .version command")
        }
    }

    func testParseVersionShortFlag() {
        let result = CLIParser.parse(["hl7", "-v"])
        if case .success(.version) = result {
            // pass
        } else {
            XCTFail("Expected .version command")
        }
    }

    func testParseNoArguments() {
        let result = CLIParser.parse(["hl7"])
        if case .success(.help) = result {
            // pass
        } else {
            XCTFail("Expected .help command when no arguments")
        }
    }

    func testParseUnknownCommand() {
        let result = CLIParser.parse(["hl7", "foobar"])
        if case .failure(.unknownCommand("foobar")) = result {
            // pass
        } else {
            XCTFail("Expected unknownCommand error")
        }
    }

    // MARK: - Validate Command Parsing

    func testParseValidateWithFile() {
        let result = CLIParser.parse(["hl7", "validate", "message.hl7"])
        if case .success(.validate(let opts)) = result {
            XCTAssertEqual(opts.inputFiles, ["message.hl7"])
            XCTAssertFalse(opts.readStdin)
            XCTAssertFalse(opts.strict)
            XCTAssertEqual(opts.format.rawValue, "text")
        } else {
            XCTFail("Expected validate command")
        }
    }

    func testParseValidateWithMultipleFiles() {
        let result = CLIParser.parse(["hl7", "validate", "a.hl7", "b.hl7", "c.hl7"])
        if case .success(.validate(let opts)) = result {
            XCTAssertEqual(opts.inputFiles, ["a.hl7", "b.hl7", "c.hl7"])
        } else {
            XCTFail("Expected validate command")
        }
    }

    func testParseValidateStdin() {
        let result = CLIParser.parse(["hl7", "validate", "--stdin"])
        if case .success(.validate(let opts)) = result {
            XCTAssertTrue(opts.readStdin)
            XCTAssertTrue(opts.inputFiles.isEmpty)
        } else {
            XCTFail("Expected validate command with stdin")
        }
    }

    func testParseValidateStrict() {
        let result = CLIParser.parse(["hl7", "validate", "--strict", "msg.hl7"])
        if case .success(.validate(let opts)) = result {
            XCTAssertTrue(opts.strict)
        } else {
            XCTFail("Expected validate command with strict")
        }
    }

    func testParseValidateFormatJSON() {
        let result = CLIParser.parse(["hl7", "validate", "--format", "json", "msg.hl7"])
        if case .success(.validate(let opts)) = result {
            XCTAssertEqual(opts.format.rawValue, "json")
        } else {
            XCTFail("Expected validate command with json format")
        }
    }

    func testParseValidateNoFiles() {
        let result = CLIParser.parse(["hl7", "validate"])
        if case .failure(.missingArgument) = result {
            // pass
        } else {
            XCTFail("Expected missingArgument error")
        }
    }

    func testParseValidateInvalidFormat() {
        let result = CLIParser.parse(["hl7", "validate", "--format", "xml", "msg.hl7"])
        if case .failure(.invalidArgument) = result {
            // pass
        } else {
            XCTFail("Expected invalidArgument error")
        }
    }

    func testParseValidateUnknownOption() {
        let result = CLIParser.parse(["hl7", "validate", "--unknown", "msg.hl7"])
        if case .failure(.unknownOption("--unknown")) = result {
            // pass
        } else {
            XCTFail("Expected unknownOption error")
        }
    }

    // MARK: - Convert Command Parsing

    func testParseConvert() {
        let result = CLIParser.parse(["hl7", "convert", "msg.hl7", "--from", "hl7v2", "--to", "hl7v3"])
        if case .success(.convert(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "msg.hl7")
            XCTAssertEqual(opts.fromFormat.rawValue, "hl7v2")
            XCTAssertEqual(opts.toFormat.rawValue, "hl7v3")
            XCTAssertNil(opts.outputFile)
            XCTAssertFalse(opts.pretty)
        } else {
            XCTFail("Expected convert command")
        }
    }

    func testParseConvertWithOutput() {
        let result = CLIParser.parse(["hl7", "convert", "msg.hl7", "-o", "out.xml"])
        if case .success(.convert(let opts)) = result {
            XCTAssertEqual(opts.outputFile, "out.xml")
        } else {
            XCTFail("Expected convert command")
        }
    }

    func testParseConvertPretty() {
        let result = CLIParser.parse(["hl7", "convert", "msg.hl7", "--pretty"])
        if case .success(.convert(let opts)) = result {
            XCTAssertTrue(opts.pretty)
        } else {
            XCTFail("Expected convert command with pretty")
        }
    }

    func testParseConvertNoInput() {
        let result = CLIParser.parse(["hl7", "convert"])
        if case .failure(.missingArgument) = result {
            // pass
        } else {
            XCTFail("Expected missingArgument error")
        }
    }

    func testParseConvertFHIRFormats() {
        let result = CLIParser.parse(["hl7", "convert", "msg.json", "--from", "fhir-json", "--to", "fhir-xml"])
        if case .success(.convert(let opts)) = result {
            XCTAssertEqual(opts.fromFormat.rawValue, "fhir-json")
            XCTAssertEqual(opts.toFormat.rawValue, "fhir-xml")
        } else {
            XCTFail("Expected convert command with FHIR formats")
        }
    }

    // MARK: - Inspect Command Parsing

    func testParseInspect() {
        let result = CLIParser.parse(["hl7", "inspect", "msg.hl7"])
        if case .success(.inspect(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "msg.hl7")
            XCTAssertTrue(opts.showTree)
            XCTAssertFalse(opts.showStats)
            XCTAssertNil(opts.searchTerm)
        } else {
            XCTFail("Expected inspect command")
        }
    }

    func testParseInspectWithStats() {
        let result = CLIParser.parse(["hl7", "inspect", "msg.hl7", "--stats"])
        if case .success(.inspect(let opts)) = result {
            XCTAssertTrue(opts.showStats)
        } else {
            XCTFail("Expected inspect command with stats")
        }
    }

    func testParseInspectNoTree() {
        let result = CLIParser.parse(["hl7", "inspect", "msg.hl7", "--no-tree"])
        if case .success(.inspect(let opts)) = result {
            XCTAssertFalse(opts.showTree)
        } else {
            XCTFail("Expected inspect command without tree")
        }
    }

    func testParseInspectSearch() {
        let result = CLIParser.parse(["hl7", "inspect", "msg.hl7", "--search", "Doe"])
        if case .success(.inspect(let opts)) = result {
            XCTAssertEqual(opts.searchTerm, "Doe")
        } else {
            XCTFail("Expected inspect command with search")
        }
    }

    func testParseInspectSearchShort() {
        let result = CLIParser.parse(["hl7", "inspect", "msg.hl7", "-s", "Doe"])
        if case .success(.inspect(let opts)) = result {
            XCTAssertEqual(opts.searchTerm, "Doe")
        } else {
            XCTFail("Expected inspect command with search")
        }
    }

    func testParseInspectNoInput() {
        let result = CLIParser.parse(["hl7", "inspect"])
        if case .failure(.missingArgument) = result {
            // pass
        } else {
            XCTFail("Expected missingArgument error")
        }
    }

    // MARK: - Batch Command Parsing

    func testParseBatch() {
        let result = CLIParser.parse(["hl7", "batch", "a.hl7", "b.hl7"])
        if case .success(.batch(let opts)) = result {
            XCTAssertEqual(opts.inputFiles, ["a.hl7", "b.hl7"])
            XCTAssertNil(opts.outputDir)
            XCTAssertEqual(opts.operation.rawValue, "validate")
            XCTAssertTrue(opts.continueOnError)
        } else {
            XCTFail("Expected batch command")
        }
    }

    func testParseBatchWithOutputDir() {
        let result = CLIParser.parse(["hl7", "batch", "-d", "/tmp/out", "a.hl7"])
        if case .success(.batch(let opts)) = result {
            XCTAssertEqual(opts.outputDir, "/tmp/out")
        } else {
            XCTFail("Expected batch command with output dir")
        }
    }

    func testParseBatchOperation() {
        let result = CLIParser.parse(["hl7", "batch", "--operation", "inspect", "a.hl7"])
        if case .success(.batch(let opts)) = result {
            XCTAssertEqual(opts.operation.rawValue, "inspect")
        } else {
            XCTFail("Expected batch command with inspect operation")
        }
    }

    func testParseBatchOperationShort() {
        let result = CLIParser.parse(["hl7", "batch", "--op", "convert", "a.hl7"])
        if case .success(.batch(let opts)) = result {
            XCTAssertEqual(opts.operation.rawValue, "convert")
        } else {
            XCTFail("Expected batch command with convert operation")
        }
    }

    func testParseBatchStopOnError() {
        let result = CLIParser.parse(["hl7", "batch", "--stop-on-error", "a.hl7"])
        if case .success(.batch(let opts)) = result {
            XCTAssertFalse(opts.continueOnError)
        } else {
            XCTFail("Expected batch command with stop-on-error")
        }
    }

    func testParseBatchNoFiles() {
        let result = CLIParser.parse(["hl7", "batch"])
        if case .failure(.missingArgument) = result {
            // pass
        } else {
            XCTFail("Expected missingArgument error")
        }
    }

    // MARK: - Conformance Command Parsing

    func testParseConformance() {
        let result = CLIParser.parse(["hl7", "conformance", "msg.hl7"])
        if case .success(.conformance(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "msg.hl7")
            XCTAssertNil(opts.profile)
        } else {
            XCTFail("Expected conformance command")
        }
    }

    func testParseConformanceWithProfile() {
        let result = CLIParser.parse(["hl7", "conformance", "msg.hl7", "--profile", "ADT_A01"])
        if case .success(.conformance(let opts)) = result {
            XCTAssertEqual(opts.profile, "ADT_A01")
        } else {
            XCTFail("Expected conformance command with profile")
        }
    }

    func testParseConformanceProfileShort() {
        let result = CLIParser.parse(["hl7", "conformance", "msg.hl7", "-p", "ORU_R01"])
        if case .success(.conformance(let opts)) = result {
            XCTAssertEqual(opts.profile, "ORU_R01")
        } else {
            XCTFail("Expected conformance command with profile")
        }
    }

    func testParseConformanceNoInput() {
        let result = CLIParser.parse(["hl7", "conformance"])
        if case .failure(.missingArgument) = result {
            // pass
        } else {
            XCTFail("Expected missingArgument error")
        }
    }

    func testParseConformanceFormatJSON() {
        let result = CLIParser.parse(["hl7", "conformance", "msg.hl7", "--format", "json"])
        if case .success(.conformance(let opts)) = result {
            XCTAssertEqual(opts.format.rawValue, "json")
        } else {
            XCTFail("Expected conformance command with json format")
        }
    }

    // MARK: - Benchmark Command Parsing

    func testParseBenchmarkNoArgs() {
        let result = CLIParser.parse(["hl7", "benchmark"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertNil(opts.inputFile)
            XCTAssertEqual(opts.iterations, 100)
            XCTAssertEqual(opts.format.rawValue, "text")
        } else {
            XCTFail("Expected benchmark command")
        }
    }

    func testParseBenchmarkWithFile() {
        let result = CLIParser.parse(["hl7", "benchmark", "message.hl7"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "message.hl7")
            XCTAssertEqual(opts.iterations, 100)
        } else {
            XCTFail("Expected benchmark command")
        }
    }

    func testParseBenchmarkWithIterations() {
        let result = CLIParser.parse(["hl7", "benchmark", "--iterations", "500"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertNil(opts.inputFile)
            XCTAssertEqual(opts.iterations, 500)
        } else {
            XCTFail("Expected benchmark command")
        }
    }

    func testParseBenchmarkShortIterations() {
        let result = CLIParser.parse(["hl7", "benchmark", "-n", "200"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertEqual(opts.iterations, 200)
        } else {
            XCTFail("Expected benchmark command")
        }
    }

    func testParseBenchmarkFormatJSON() {
        let result = CLIParser.parse(["hl7", "benchmark", "--format", "json"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertEqual(opts.format.rawValue, "json")
        } else {
            XCTFail("Expected benchmark command with json format")
        }
    }

    func testParseBenchmarkInvalidIterations() {
        let result = CLIParser.parse(["hl7", "benchmark", "--iterations", "abc"])
        if case .failure(.invalidArgument) = result {
            // pass
        } else {
            XCTFail("Expected invalidArgument error")
        }
    }

    func testParseBenchmarkAllOptions() {
        let result = CLIParser.parse(["hl7", "benchmark", "msg.hl7", "-n", "1000", "--format", "json"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "msg.hl7")
            XCTAssertEqual(opts.iterations, 1000)
            XCTAssertEqual(opts.format.rawValue, "json")
        } else {
            XCTFail("Expected benchmark command with all options")
        }
    }

    func testParseBenchmarkRegressionFlag() {
        let result = CLIParser.parse(["hl7", "benchmark", "--regression"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertTrue(opts.regression)
            XCTAssertNil(opts.inputFile)
            XCTAssertEqual(opts.iterations, 100)
        } else {
            XCTFail("Expected benchmark command with regression flag")
        }
    }

    func testParseBenchmarkRegressionWithIterations() {
        let result = CLIParser.parse(["hl7", "benchmark", "--regression", "-n", "500"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertTrue(opts.regression)
            XCTAssertEqual(opts.iterations, 500)
        } else {
            XCTFail("Expected benchmark command with regression and iterations")
        }
    }

    func testParseBenchmarkRegressionJSON() {
        let result = CLIParser.parse(["hl7", "benchmark", "--regression", "--format", "json"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertTrue(opts.regression)
            XCTAssertEqual(opts.format.rawValue, "json")
        } else {
            XCTFail("Expected benchmark command with regression and json format")
        }
    }

    func testParseBenchmarkNoRegressionByDefault() {
        let result = CLIParser.parse(["hl7", "benchmark"])
        if case .success(.benchmark(let opts)) = result {
            XCTAssertFalse(opts.regression)
        } else {
            XCTFail("Expected benchmark command")
        }
    }
}

// MARK: - CLI Error Tests

final class CLIErrorTests: XCTestCase {

    func testUnknownCommandDescription() {
        let error = CLIError.unknownCommand("foo")
        XCTAssertTrue(error.description.contains("foo"))
        XCTAssertTrue(error.description.contains("Unknown command"))
    }

    func testUnknownOptionDescription() {
        let error = CLIError.unknownOption("--bar")
        XCTAssertTrue(error.description.contains("--bar"))
    }

    func testMissingArgumentDescription() {
        let error = CLIError.missingArgument("input file")
        XCTAssertTrue(error.description.contains("input file"))
    }

    func testInvalidArgumentDescription() {
        let error = CLIError.invalidArgument("bad value")
        XCTAssertTrue(error.description.contains("bad value"))
    }

    func testFileNotFoundDescription() {
        let error = CLIError.fileNotFound("/path/to/file")
        XCTAssertTrue(error.description.contains("/path/to/file"))
    }

    func testReadErrorDescription() {
        let error = CLIError.readError("cannot read")
        XCTAssertTrue(error.description.contains("cannot read"))
    }

    func testProcessingErrorDescription() {
        let error = CLIError.processingError("failure")
        XCTAssertTrue(error.description.contains("failure"))
    }
}

// MARK: - Option Struct Tests

final class OptionStructTests: XCTestCase {

    func testValidateOptionsDefaults() {
        let opts = ValidateOptions(inputFiles: ["test.hl7"])
        XCTAssertEqual(opts.inputFiles, ["test.hl7"])
        XCTAssertFalse(opts.readStdin)
        XCTAssertFalse(opts.strict)
        XCTAssertEqual(opts.format.rawValue, "text")
    }

    func testConvertOptionsDefaults() {
        let opts = ConvertOptions(inputFile: "test.hl7")
        XCTAssertEqual(opts.inputFile, "test.hl7")
        XCTAssertNil(opts.outputFile)
        XCTAssertEqual(opts.fromFormat.rawValue, "hl7v2")
        XCTAssertEqual(opts.toFormat.rawValue, "hl7v2")
        XCTAssertFalse(opts.pretty)
    }

    func testInspectOptionsDefaults() {
        let opts = InspectOptions(inputFile: "test.hl7")
        XCTAssertEqual(opts.inputFile, "test.hl7")
        XCTAssertTrue(opts.showTree)
        XCTAssertFalse(opts.showStats)
        XCTAssertNil(opts.searchTerm)
        XCTAssertEqual(opts.format.rawValue, "text")
    }

    func testBatchOptionsDefaults() {
        let opts = BatchOptions(inputFiles: ["a.hl7", "b.hl7"])
        XCTAssertEqual(opts.inputFiles, ["a.hl7", "b.hl7"])
        XCTAssertNil(opts.outputDir)
        XCTAssertEqual(opts.operation.rawValue, "validate")
        XCTAssertTrue(opts.continueOnError)
    }

    func testConformanceOptionsDefaults() {
        let opts = ConformanceOptions(inputFile: "test.hl7")
        XCTAssertEqual(opts.inputFile, "test.hl7")
        XCTAssertNil(opts.profile)
        XCTAssertEqual(opts.format.rawValue, "text")
    }

    func testMessageFormatRawValues() {
        XCTAssertEqual(MessageFormat.hl7v2.rawValue, "hl7v2")
        XCTAssertEqual(MessageFormat.hl7v3.rawValue, "hl7v3")
        XCTAssertEqual(MessageFormat.fhirJson.rawValue, "fhir-json")
        XCTAssertEqual(MessageFormat.fhirXml.rawValue, "fhir-xml")
    }

    func testBatchOperationRawValues() {
        XCTAssertEqual(BatchOperation.validate.rawValue, "validate")
        XCTAssertEqual(BatchOperation.inspect.rawValue, "inspect")
        XCTAssertEqual(BatchOperation.convert.rawValue, "convert")
    }

    func testOutputFormatRawValues() {
        XCTAssertEqual(OutputFormat.text.rawValue, "text")
        XCTAssertEqual(OutputFormat.json.rawValue, "json")
    }

    func testExitCodeRawValues() {
        XCTAssertEqual(ExitCode.success.rawValue, 0)
        XCTAssertEqual(ExitCode.validationFailure.rawValue, 1)
        XCTAssertEqual(ExitCode.inputError.rawValue, 2)
        XCTAssertEqual(ExitCode.processingError.rawValue, 3)
        XCTAssertEqual(ExitCode.usageError.rawValue, 64)
    }
}

// MARK: - HelpText Tests

final class HelpTextTests: XCTestCase {

    func testMainHelpContainsCommands() {
        XCTAssertTrue(HelpText.main.contains("validate"))
        XCTAssertTrue(HelpText.main.contains("convert"))
        XCTAssertTrue(HelpText.main.contains("inspect"))
        XCTAssertTrue(HelpText.main.contains("batch"))
        XCTAssertTrue(HelpText.main.contains("conformance"))
    }

    func testValidateHelpContainsOptions() {
        XCTAssertTrue(HelpText.validate.contains("--strict"))
        XCTAssertTrue(HelpText.validate.contains("--stdin"))
        XCTAssertTrue(HelpText.validate.contains("--format"))
    }

    func testConvertHelpContainsOptions() {
        XCTAssertTrue(HelpText.convert.contains("--from"))
        XCTAssertTrue(HelpText.convert.contains("--to"))
        XCTAssertTrue(HelpText.convert.contains("--output"))
        XCTAssertTrue(HelpText.convert.contains("--pretty"))
    }

    func testInspectHelpContainsOptions() {
        XCTAssertTrue(HelpText.inspect.contains("--no-tree"))
        XCTAssertTrue(HelpText.inspect.contains("--stats"))
        XCTAssertTrue(HelpText.inspect.contains("--search"))
    }

    func testBatchHelpContainsOptions() {
        XCTAssertTrue(HelpText.batch.contains("--operation"))
        XCTAssertTrue(HelpText.batch.contains("--output-dir"))
        XCTAssertTrue(HelpText.batch.contains("--stop-on-error"))
    }

    func testConformanceHelpContainsOptions() {
        XCTAssertTrue(HelpText.conformance.contains("--profile"))
        XCTAssertTrue(HelpText.conformance.contains("ADT_A01"))
        XCTAssertTrue(HelpText.conformance.contains("ORU_R01"))
    }

    func testVersionString() {
        XCTAssertTrue(HelpText.version.contains("HL7kit"))
        XCTAssertTrue(HelpText.version.contains("1.0.0"))
    }
}

// MARK: - File I/O Tests

final class FileIOTests: XCTestCase {

    func testReadFileSuccess() throws {
        let testPath = "/tmp/hl7cli_test_read.hl7"
        try "MSH|^~\\&|TEST\r".write(toFile: testPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: testPath) }

        let content = try readFile(at: testPath)
        XCTAssertTrue(content.contains("MSH"))
    }

    func testReadFileNotFound() {
        XCTAssertThrowsError(try readFile(at: "/tmp/nonexistent_hl7cli_test.hl7")) { error in
            if let cliError = error as? CLIError {
                XCTAssertTrue(cliError.description.contains("File not found"))
            }
        }
    }

    func testWriteOutputToFile() throws {
        let testPath = "/tmp/hl7cli_test_write.txt"
        defer { try? FileManager.default.removeItem(atPath: testPath) }

        try writeOutput("test content", to: testPath)

        let content = try String(contentsOfFile: testPath, encoding: .utf8)
        XCTAssertEqual(content, "test content")
    }

    func testCreateParser() {
        let parser = createParser()
        XCTAssertNotNil(parser)
    }
}

// MARK: - Command Execution Tests

final class CommandExecutionTests: XCTestCase {

    private var testDir: String!

    override func setUp() {
        super.setUp()
        testDir = "/tmp/hl7cli_test_\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testDir)
        super.tearDown()
    }

    private func createTestFile(_ name: String, content: String) -> String {
        let path = "\(testDir!)/\(name)"
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    // MARK: - Validate Command

    func testValidateValidMessage() {
        let msg = "MSH|^~\\&|SEND|FAC|RECV|FAC|20240101120000||ADT^A01|MSG001|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^HOSP^MR||Doe^John\nPV1|1|I|4E^401"
        let path = createTestFile("valid.hl7", content: msg)

        let options = ValidateOptions(inputFiles: [path])
        let exitCode = runValidate(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testValidateInvalidFile() {
        let options = ValidateOptions(inputFiles: ["/tmp/does_not_exist.hl7"])
        let exitCode = runValidate(options)
        XCTAssertEqual(exitCode, .validationFailure)
    }

    func testValidateMultipleFiles() {
        let msg1 = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let msg2 = "MSH|^~\\&|A|B|C|D|20240101||ACK|M2|P|2.5\nMSA|AA|M1"
        let path1 = createTestFile("msg1.hl7", content: msg1)
        let path2 = createTestFile("msg2.hl7", content: msg2)

        let options = ValidateOptions(inputFiles: [path1, path2])
        let exitCode = runValidate(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testValidateJSONFormat() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ACK|M1|P|2.5\nMSA|AA|M1"
        let path = createTestFile("ack.hl7", content: msg)

        let options = ValidateOptions(inputFiles: [path], format: .json)
        let exitCode = runValidate(options)
        XCTAssertEqual(exitCode, .success)
    }

    // MARK: - Inspect Command

    func testInspectValidMessage() {
        let msg = "MSH|^~\\&|SEND|FAC|RECV|FAC|20240101120000||ADT^A01|MSG001|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^HOSP^MR||Doe^John\nPV1|1|I|4E^401"
        let path = createTestFile("inspect.hl7", content: msg)

        let options = InspectOptions(inputFile: path)
        let exitCode = runInspect(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testInspectWithStats() {
        let msg = "MSH|^~\\&|SEND|FAC|RECV|FAC|20240101120000||ADT^A01|MSG001|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^HOSP^MR||Doe^John\nPV1|1|I|4E^401"
        let path = createTestFile("stats.hl7", content: msg)

        let options = InspectOptions(inputFile: path, showStats: true)
        let exitCode = runInspect(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testInspectWithSearch() {
        let msg = "MSH|^~\\&|SEND|FAC|RECV|FAC|20240101120000||ADT^A01|MSG001|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^HOSP^MR||Doe^John\nPV1|1|I|4E^401"
        let path = createTestFile("search.hl7", content: msg)

        let options = InspectOptions(inputFile: path, searchTerm: "Doe")
        let exitCode = runInspect(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testInspectFileNotFound() {
        let options = InspectOptions(inputFile: "/tmp/nonexistent.hl7")
        let exitCode = runInspect(options)
        XCTAssertEqual(exitCode, .inputError)
    }

    func testInspectJSONFormat() {
        let msg = "MSH|^~\\&|SEND|FAC|RECV|FAC|20240101120000||ADT^A01|MSG001|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^HOSP^MR||Doe^John\nPV1|1|I|4E^401"
        let path = createTestFile("json_inspect.hl7", content: msg)

        let options = InspectOptions(inputFile: path, format: .json)
        let exitCode = runInspect(options)
        XCTAssertEqual(exitCode, .success)
    }

    // MARK: - Convert Command

    func testConvertV2ToV2() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let inPath = createTestFile("convert_in.hl7", content: msg)
        let outPath = "\(testDir!)/convert_out.hl7"

        let options = ConvertOptions(inputFile: inPath, outputFile: outPath, fromFormat: .hl7v2, toFormat: .hl7v2)
        let exitCode = runConvert(options)
        XCTAssertEqual(exitCode, .success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outPath))
    }

    func testConvertV2ToV3() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let inPath = createTestFile("convert_v3.hl7", content: msg)
        let outPath = "\(testDir!)/convert_out.xml"

        let options = ConvertOptions(inputFile: inPath, outputFile: outPath, fromFormat: .hl7v2, toFormat: .hl7v3, pretty: true)
        let exitCode = runConvert(options)
        XCTAssertEqual(exitCode, .success)

        let output = try? String(contentsOfFile: outPath, encoding: .utf8)
        XCTAssertNotNil(output)
        XCTAssertTrue(output?.contains("ClinicalDocument") ?? false)
        // The transformer creates a CDA structure with proper templates and type IDs
        XCTAssertTrue(output?.contains("typeId") ?? false)
        XCTAssertTrue(output?.contains("templateId") ?? false)
    }

    func testConvertUnsupportedFormat() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5"
        let inPath = createTestFile("unsupported.hl7", content: msg)

        let options = ConvertOptions(inputFile: inPath, fromFormat: .fhirJson, toFormat: .fhirXml)
        let exitCode = runConvert(options)
        XCTAssertEqual(exitCode, .processingError)
    }

    func testConvertFileNotFound() {
        let options = ConvertOptions(inputFile: "/tmp/nonexistent.hl7", fromFormat: .hl7v2, toFormat: .hl7v2)
        let exitCode = runConvert(options)
        XCTAssertEqual(exitCode, .inputError)
    }

    // MARK: - Batch Command

    func testBatchValidate() {
        let msg1 = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let msg2 = "MSH|^~\\&|A|B|C|D|20240101||ACK|M2|P|2.5\nMSA|AA|M1"
        let p1 = createTestFile("batch1.hl7", content: msg1)
        let p2 = createTestFile("batch2.hl7", content: msg2)

        let options = BatchOptions(inputFiles: [p1, p2])
        let exitCode = runBatch(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testBatchInspect() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let p1 = createTestFile("batch_insp.hl7", content: msg)
        let outDir = "\(testDir!)/output"

        let options = BatchOptions(inputFiles: [p1], outputDir: outDir, operation: .inspect)
        let exitCode = runBatch(options)
        XCTAssertEqual(exitCode, .success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(outDir)/batch_insp_inspection.txt"))
    }

    func testBatchConvert() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let p1 = createTestFile("batch_conv.hl7", content: msg)
        let outDir = "\(testDir!)/conv_output"

        let options = BatchOptions(inputFiles: [p1], outputDir: outDir, operation: .convert)
        let exitCode = runBatch(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testBatchWithMissingFile() {
        let options = BatchOptions(inputFiles: ["/tmp/nonexistent.hl7"])
        let exitCode = runBatch(options)
        XCTAssertEqual(exitCode, .validationFailure)
    }

    func testBatchStopOnError() {
        let p1 = "/tmp/nonexistent1.hl7"
        let p2 = "/tmp/nonexistent2.hl7"

        let options = BatchOptions(inputFiles: [p1, p2], continueOnError: false)
        let exitCode = runBatch(options)
        XCTAssertEqual(exitCode, .validationFailure)
    }

    func testBatchJSONFormat() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ACK|M1|P|2.5\nMSA|AA|M1"
        let p1 = createTestFile("batch_json.hl7", content: msg)

        let options = BatchOptions(inputFiles: [p1], format: .json)
        let exitCode = runBatch(options)
        XCTAssertEqual(exitCode, .success)
    }

    // MARK: - Conformance Command

    func testConformanceADTA01() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let path = createTestFile("conf_adt.hl7", content: msg)

        let options = ConformanceOptions(inputFile: path, profile: "ADT_A01")
        let exitCode = runConformance(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testConformanceAutoDetect() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let path = createTestFile("conf_auto.hl7", content: msg)

        let options = ConformanceOptions(inputFile: path)
        let exitCode = runConformance(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testConformanceACK() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ACK|M1|P|2.5\nMSA|AA|M1"
        let path = createTestFile("conf_ack.hl7", content: msg)

        let options = ConformanceOptions(inputFile: path, profile: "ACK")
        let exitCode = runConformance(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testConformanceUnknownProfile() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let path = createTestFile("conf_unknown.hl7", content: msg)

        let options = ConformanceOptions(inputFile: path, profile: "UNKNOWN_PROFILE")
        let exitCode = runConformance(options)
        XCTAssertEqual(exitCode, .usageError)
    }

    func testConformanceFileNotFound() {
        let options = ConformanceOptions(inputFile: "/tmp/nonexistent.hl7")
        let exitCode = runConformance(options)
        XCTAssertEqual(exitCode, .inputError)
    }

    func testConformanceJSONFormat() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let path = createTestFile("conf_json.hl7", content: msg)

        let options = ConformanceOptions(inputFile: path, profile: "ADT_A01", format: .json)
        let exitCode = runConformance(options)
        XCTAssertEqual(exitCode, .success)
    }

    // MARK: - Benchmark Command

    func testBenchmarkBuiltIn() {
        let options = BenchmarkOptions()
        let exitCode = runBenchmark(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testBenchmarkWithFile() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let path = createTestFile("bench.hl7", content: msg)

        let options = BenchmarkOptions(inputFile: path, iterations: 50)
        let exitCode = runBenchmark(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testBenchmarkFileNotFound() {
        let options = BenchmarkOptions(inputFile: "/tmp/nonexistent_bench.hl7")
        let exitCode = runBenchmark(options)
        XCTAssertEqual(exitCode, .inputError)
    }

    func testBenchmarkJSONFormat() {
        let options = BenchmarkOptions(iterations: 20, format: .json)
        let exitCode = runBenchmark(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testBenchmarkFileJSONFormat() {
        let msg = "MSH|^~\\&|A|B|C|D|20240101||ADT^A01|M1|P|2.5.1\nEVN|A01|20240101\nPID|1||123^^^H^MR||Doe^John\nPV1|1|I"
        let path = createTestFile("bench_json.hl7", content: msg)

        let options = BenchmarkOptions(inputFile: path, iterations: 20, format: .json)
        let exitCode = runBenchmark(options)
        XCTAssertEqual(exitCode, .success)
    }

    func testBenchmarkRegressionText() {
        let options = BenchmarkOptions(iterations: 50, regression: true)
        let exitCode = runBenchmark(options)
        // Should pass or warn (not fail) since we're running on reasonable hardware
        XCTAssertTrue(exitCode == .success || exitCode == .validationFailure)
    }

    func testBenchmarkRegressionJSON() {
        let options = BenchmarkOptions(iterations: 50, format: .json, regression: true)
        let exitCode = runBenchmark(options)
        XCTAssertTrue(exitCode == .success || exitCode == .validationFailure)
    }
}
