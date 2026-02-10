/// Tests for CLI Tools
///
/// Covers MessageValidatorCLI, FormatConverterCLI, ConformanceCheckerCLI,
/// BatchProcessorCLI, and CLIOutputFormatter.

import XCTest
@testable import HL7Core

final class CLIToolsTests: XCTestCase {

    // MARK: - Sample Messages

    let validADT =
        "MSH|^~\\&|SENDING|FACILITY|RECEIVING|FACILITY|20230615120000||ADT^A01|MSG001|P|2.5\r"
        + "PID|1||12345^^^MRN||DOE^JOHN||19800101|M\r"
        + "PV1|1|I|ICU^101^A|||||||ATT^DOCTOR\r"
        + "EVN|A01|20230615120000\r"

    let minimalMSH = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|2.5\r"

    // MARK: - MessageValidatorCLI Tests

    func testValidateValidMessage() async throws {
        let validator = MessageValidatorCLI()
        let report = try await validator.validate(input: validADT)
        XCTAssertTrue(report.isValid)
        XCTAssertEqual(report.segmentCount, 4)
        XCTAssertEqual(report.messageType, "ADT^A01")
        XCTAssertEqual(report.version, "2.5")
        XCTAssertTrue(report.errors.isEmpty)
    }

    func testValidateEmptyMessage() async {
        let validator = MessageValidatorCLI()
        do {
            _ = try await validator.validate(input: "")
            XCTFail("Expected error for empty message")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testValidateNoMSH() async {
        let validator = MessageValidatorCLI()
        do {
            _ = try await validator.validate(input: "PID|1||12345\r")
            XCTFail("Expected error for message without MSH")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testValidateMissingEncodingChars() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH||SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|2.5\r"
        let report = try await validator.validate(input: msg)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.location == "MSH-2" })
    }

    func testValidateMissingMessageType() async throws {
        let validator = MessageValidatorCLI()
        // MSH with empty field at position 9
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101|||CTRL1|P|2.5\r"
        let report = try await validator.validate(input: msg)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.description.contains("message type") })
    }

    func testValidateMissingControlID() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01||P|2.5\r"
        let report = try await validator.validate(input: msg)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.description.contains("control ID") })
    }

    func testValidateADTMissingPID() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|2.5\rEVN|A01|20230101\r"
        let report = try await validator.validate(input: msg)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.description.contains("PID") })
    }

    func testValidateUnrecognizedVersion() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|9.9\rPID|1||123\r"
        let report = try await validator.validate(input: msg)
        XCTAssertTrue(report.warnings.contains { $0.description.contains("version") })
    }

    func testValidateNonStandardProcessingID() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|X|2.5\rPID|1||123\r"
        let report = try await validator.validate(input: msg)
        XCTAssertTrue(report.warnings.contains { $0.description.contains("processing ID") })
    }

    func testValidateNewlineDelimiters() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|2.5\nPID|1||123^^^MRN||DOE^JOHN\n"
        let report = try await validator.validate(input: msg)
        XCTAssertEqual(report.segmentCount, 2)
    }

    // MARK: - FormatConverterCLI Tests

    func testConvertHL7v2ToJSON() async throws {
        let converter = FormatConverterCLI()
        let json = try await converter.convert(input: validADT, from: .hl7v2, to: .json)
        XCTAssertTrue(json.contains("\"segments\""))
        XCTAssertTrue(json.contains("\"MSH\""))
        XCTAssertTrue(json.contains("\"PID\""))
    }

    func testConvertHL7v2ToXML() async throws {
        let converter = FormatConverterCLI()
        let xml = try await converter.convert(input: validADT, from: .hl7v2, to: .xml)
        XCTAssertTrue(xml.contains("<hl7message>"))
        XCTAssertTrue(xml.contains("<segment name=\"MSH\">"))
        XCTAssertTrue(xml.contains("</hl7message>"))
    }

    func testConvertHL7v2ToPrettyPrint() async throws {
        let converter = FormatConverterCLI()
        let pp = try await converter.convert(input: validADT, from: .hl7v2, to: .prettyPrint)
        XCTAssertTrue(pp.contains("── MSH ──"))
        XCTAssertTrue(pp.contains("── PID ──"))
        XCTAssertTrue(pp.contains("MSH-"))
    }

    func testConvertHL7v2RoundTrip() async throws {
        let converter = FormatConverterCLI()
        let json = try await converter.convert(input: minimalMSH, from: .hl7v2, to: .json)
        let backToHL7 = try await converter.convert(input: json, from: .json, to: .hl7v2)
        XCTAssertTrue(backToHL7.contains("MSH"))
        XCTAssertTrue(backToHL7.contains("ADT^A01"))
    }

    func testConvertJSONRoundTrip() async throws {
        let converter = FormatConverterCLI()
        let json = try await converter.convert(input: minimalMSH, from: .hl7v2, to: .json)
        let xml = try await converter.convert(input: json, from: .json, to: .xml)
        XCTAssertTrue(xml.contains("<segment name=\"MSH\">"))
    }

    func testConvertXMLToHL7v2() async throws {
        let converter = FormatConverterCLI()
        let xml = try await converter.convert(input: minimalMSH, from: .hl7v2, to: .xml)
        let hl7 = try await converter.convert(input: xml, from: .xml, to: .hl7v2)
        XCTAssertTrue(hl7.hasPrefix("MSH"))
    }

    func testConvertEmptyInput() async {
        let converter = FormatConverterCLI()
        do {
            _ = try await converter.convert(input: "", from: .hl7v2, to: .json)
            XCTFail("Expected error for empty input")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testConvertInvalidJSON() async {
        let converter = FormatConverterCLI()
        do {
            _ = try await converter.convert(input: "not json", from: .json, to: .hl7v2)
            XCTFail("Expected error for invalid JSON")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testConvertInvalidXML() async {
        let converter = FormatConverterCLI()
        do {
            _ = try await converter.convert(input: "not xml", from: .xml, to: .hl7v2)
            XCTFail("Expected error for invalid XML")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    // MARK: - ConformanceCheckerCLI Tests

    func testConformanceValidMessage() async throws {
        let checker = ConformanceCheckerCLI()
        let report = try await checker.checkConformance(message: validADT)
        XCTAssertTrue(report.conformant)
        XCTAssertEqual(report.profileName, "HL7v2-Base")
        XCTAssertGreaterThan(report.score, 0)
    }

    func testConformanceCustomProfile() async throws {
        let checker = ConformanceCheckerCLI()
        let report = try await checker.checkConformance(message: validADT, profile: "CustomProfile")
        XCTAssertEqual(report.profileName, "CustomProfile")
    }

    func testConformanceEmptyMessage() async {
        let checker = ConformanceCheckerCLI()
        do {
            _ = try await checker.checkConformance(message: "")
            XCTFail("Expected error for empty message")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testConformanceMissingDateTime() async throws {
        let checker = ConformanceCheckerCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|||ADT^A01|CTRL1|P|2.5\rPID|1||123^^^MRN||DOE^JOHN\r"
        let report = try await checker.checkConformance(message: msg)
        XCTAssertFalse(report.conformant)
        XCTAssertTrue(report.violations.contains { $0.rule.contains("Date/Time") })
    }

    func testConformanceShortDateTime() async throws {
        let checker = ConformanceCheckerCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|2023||ADT^A01|CTRL1|P|2.5\rPID|1||123^^^MRN||DOE^JOHN\r"
        let report = try await checker.checkConformance(message: msg)
        XCTAssertTrue(report.warnings.contains { $0.description.contains("8 characters") })
    }

    func testConformanceMissingPatientID() async throws {
        let checker = ConformanceCheckerCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|2.5\rPID|1||||DOE^JOHN\r"
        let report = try await checker.checkConformance(message: msg)
        XCTAssertFalse(report.conformant)
        XCTAssertTrue(report.violations.contains { $0.rule.contains("Patient Identifier") })
    }

    func testConformanceScoreRange() async throws {
        let checker = ConformanceCheckerCLI()
        let report = try await checker.checkConformance(message: validADT)
        XCTAssertGreaterThanOrEqual(report.score, 0)
        XCTAssertLessThanOrEqual(report.score, 100)
    }

    // MARK: - BatchProcessorCLI Tests

    func testBatchValidateSingleMessage() async throws {
        let processor = BatchProcessorCLI()
        let report = try await processor.processFile(content: validADT, operation: .validate)
        XCTAssertEqual(report.totalMessages, 1)
        XCTAssertEqual(report.processed, 1)
        XCTAssertEqual(report.passed, 1)
        XCTAssertEqual(report.failed, 0)
    }

    func testBatchValidateMultipleMessages() async throws {
        let processor = BatchProcessorCLI()
        let batch = validADT
            + "MSH|^~\\&|LAB|FAC|RCV|FAC|20230615||ORU^R01|MSG002|P|2.5\r"
            + "PID|1||67890\r"
        let report = try await processor.processFile(content: batch, operation: .validate)
        XCTAssertEqual(report.totalMessages, 2)
        XCTAssertEqual(report.processed, 2)
    }

    func testBatchConvert() async throws {
        let processor = BatchProcessorCLI()
        let report = try await processor.processFile(content: validADT, operation: .convert)
        XCTAssertEqual(report.totalMessages, 1)
        XCTAssertEqual(report.passed, 1)
    }

    func testBatchStatistics() async throws {
        let processor = BatchProcessorCLI()
        let report = try await processor.processFile(content: validADT, operation: .statistics)
        XCTAssertEqual(report.totalMessages, 1)
        XCTAssertEqual(report.passed, 1)
    }

    func testBatchEmptyContent() async {
        let processor = BatchProcessorCLI()
        do {
            _ = try await processor.processFile(content: "", operation: .validate)
            XCTFail("Expected error for empty content")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testBatchDuration() async throws {
        let processor = BatchProcessorCLI()
        let report = try await processor.processFile(content: validADT, operation: .validate)
        XCTAssertGreaterThanOrEqual(report.duration, 0)
    }

    func testBatchWithInvalidMessage() async throws {
        let processor = BatchProcessorCLI()
        let batch = validADT
            + "MSH||SND|FAC|RCV|FAC|20230101|||CTRL2|P|2.5\r"
        let report = try await processor.processFile(content: batch, operation: .validate)
        XCTAssertEqual(report.totalMessages, 2)
        XCTAssertGreaterThan(report.failed, 0)
        XCTAssertFalse(report.errors.isEmpty)
    }

    // MARK: - CLIOutputFormatter Tests

    func testFormatValidationReportText() async throws {
        let validator = MessageValidatorCLI()
        let report = try await validator.validate(input: validADT)
        let formatter = CLIOutputFormatter()
        let text = formatter.formatText(report)
        XCTAssertTrue(text.contains("Validation Report"))
        XCTAssertTrue(text.contains("VALID"))
        XCTAssertTrue(text.contains("ADT^A01"))
    }

    func testFormatValidationReportJSON() async throws {
        let validator = MessageValidatorCLI()
        let report = try await validator.validate(input: validADT)
        let formatter = CLIOutputFormatter()
        let json = formatter.formatJSON(report)
        XCTAssertTrue(json.contains("\"isValid\": true"))
        XCTAssertTrue(json.contains("\"messageType\""))
    }

    func testFormatConformanceReportText() async throws {
        let checker = ConformanceCheckerCLI()
        let report = try await checker.checkConformance(message: validADT)
        let formatter = CLIOutputFormatter()
        let text = formatter.formatText(report)
        XCTAssertTrue(text.contains("Conformance Report"))
        XCTAssertTrue(text.contains("HL7v2-Base"))
    }

    func testFormatConformanceReportJSON() async throws {
        let checker = ConformanceCheckerCLI()
        let report = try await checker.checkConformance(message: validADT)
        let formatter = CLIOutputFormatter()
        let json = formatter.formatJSON(report)
        XCTAssertTrue(json.contains("\"conformant\""))
        XCTAssertTrue(json.contains("\"score\""))
    }

    func testFormatBatchReportText() async throws {
        let processor = BatchProcessorCLI()
        let report = try await processor.processFile(content: validADT, operation: .validate)
        let formatter = CLIOutputFormatter()
        let text = formatter.formatText(report)
        XCTAssertTrue(text.contains("Batch Report"))
        XCTAssertTrue(text.contains("Total Messages: 1"))
    }

    func testFormatBatchReportJSON() async throws {
        let processor = BatchProcessorCLI()
        let report = try await processor.processFile(content: validADT, operation: .validate)
        let formatter = CLIOutputFormatter()
        let json = formatter.formatJSON(report)
        XCTAssertTrue(json.contains("\"totalMessages\": 1"))
        XCTAssertTrue(json.contains("\"passed\": 1"))
    }

    func testFormatConnectionResultText() {
        let formatter = CLIOutputFormatter()
        let result = ConnectionTestResult(reachable: true, responseTime: 0.123, tlsAvailable: false)
        let text = formatter.formatText(result)
        XCTAssertTrue(text.contains("Connection Test"))
        XCTAssertTrue(text.contains("Reachable: YES"))
    }

    func testFormatNetworkResultText() {
        let formatter = CLIOutputFormatter()
        let result = NetworkTestResult(success: true, responseMessage: "ACK", roundTripTime: 0.456)
        let text = formatter.formatText(result)
        XCTAssertTrue(text.contains("Network Test"))
        XCTAssertTrue(text.contains("ACK"))
    }

    // MARK: - NetworkTestCLI Tests

    func testNetworkEmptyHost() async {
        let network = NetworkTestCLI()
        do {
            _ = try await network.testConnection(host: "", port: 2575)
            XCTFail("Expected error for empty host")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testNetworkInvalidPort() async {
        let network = NetworkTestCLI()
        do {
            _ = try await network.testConnection(host: "localhost", port: 0)
            XCTFail("Expected error for invalid port")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testNetworkPortTooHigh() async {
        let network = NetworkTestCLI()
        do {
            _ = try await network.testConnection(host: "localhost", port: 99999)
            XCTFail("Expected error for port > 65535")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testSendMessageEmptyMessage() async {
        let network = NetworkTestCLI()
        do {
            _ = try await network.sendMessage(message: "", host: "localhost", port: 2575)
            XCTFail("Expected error for empty message")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    func testSendMessageEmptyHost() async {
        let network = NetworkTestCLI()
        do {
            _ = try await network.sendMessage(message: "test", host: "", port: 2575)
            XCTFail("Expected error for empty host")
        } catch {
            XCTAssertTrue(error is HL7Error)
        }
    }

    // MARK: - Edge Cases

    func testValidateMessageWithCRLF() async throws {
        let validator = MessageValidatorCLI()
        let msg = "MSH|^~\\&|SND|FAC|RCV|FAC|20230101||ADT^A01|CTRL1|P|2.5\r\nPID|1||123^^^MRN||DOE^JOHN\r\n"
        let report = try await validator.validate(input: msg)
        XCTAssertEqual(report.segmentCount, 2)
    }

    func testBatchOperationEnum() {
        XCTAssertEqual(BatchProcessorCLI.BatchOperation.allCases.count, 3)
        XCTAssertEqual(BatchProcessorCLI.BatchOperation.validate.rawValue, "validate")
        XCTAssertEqual(BatchProcessorCLI.BatchOperation.convert.rawValue, "convert")
        XCTAssertEqual(BatchProcessorCLI.BatchOperation.statistics.rawValue, "statistics")
    }

    func testInputFormatEnum() {
        XCTAssertEqual(FormatConverterCLI.InputFormat.allCases.count, 3)
    }

    func testOutputFormatEnum() {
        XCTAssertEqual(FormatConverterCLI.OutputFormat.allCases.count, 4)
    }
}
