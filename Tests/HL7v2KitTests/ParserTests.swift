/// Tests for HL7 v2.x Parser infrastructure
///
/// Covers ParserConfiguration, MessageEncoding, SegmentTerminator,
/// ErrorRecoveryMode, HL7v2Parser, HL7v2StreamingParser, and diagnostics.

import XCTest
import Foundation
@testable import HL7v2Kit
@testable import HL7Core

final class ParserTests: XCTestCase {

    // MARK: - Test Data

    /// Standard ADT^A01 message using CR as terminator
    private let sampleMessage = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"

    /// Same message using LF
    private let sampleMessageLF = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5\nPID|||12345^^^MRN||Smith^John||19800101|M\nPV1||I|ICU"

    /// Same message using CRLF
    private let sampleMessageCRLF = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5\r\nPID|||12345^^^MRN||Smith^John||19800101|M\r\nPV1||I|ICU"

    // MARK: - MessageEncoding Tests

    func testMessageEncodingStringEncoding() {
        XCTAssertEqual(MessageEncoding.ascii.stringEncoding, .ascii)
        XCTAssertEqual(MessageEncoding.utf8.stringEncoding, .utf8)
        XCTAssertEqual(MessageEncoding.latin1.stringEncoding, .isoLatin1)
        XCTAssertEqual(MessageEncoding.autoDetect.stringEncoding, .utf8)
    }

    func testMessageEncodingDetectASCII() {
        let data = "MSH|^~\\&|".data(using: .ascii)!
        let detected = MessageEncoding.detect(from: data)
        XCTAssertEqual(detected, .ascii)
    }

    func testMessageEncodingDetectUTF8() {
        // String with non-ASCII UTF-8 characters
        let data = "MSH|^~\\&|Ünit".data(using: .utf8)!
        let detected = MessageEncoding.detect(from: data)
        XCTAssertEqual(detected, .utf8)
    }

    func testMessageEncodingDetectUTF8BOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append("MSH|^~\\&|".data(using: .utf8)!)
        let detected = MessageEncoding.detect(from: data)
        XCTAssertEqual(detected, .utf8)
    }

    func testMessageEncodingDetectLatin1() {
        // Byte sequence invalid in UTF-8 but valid in Latin-1
        let data = Data([0x4D, 0x53, 0x48, 0xC0, 0xC1]) // MSH followed by invalid UTF-8
        let detected = MessageEncoding.detect(from: data)
        XCTAssertEqual(detected, .latin1)
    }

    func testMessageEncodingEquatable() {
        XCTAssertEqual(MessageEncoding.utf8, MessageEncoding.utf8)
        XCTAssertNotEqual(MessageEncoding.utf8, MessageEncoding.ascii)
    }

    // MARK: - SegmentTerminator Tests

    func testSegmentTerminatorCR() {
        let parts = SegmentTerminator.cr.split("MSH|^~\\&|\rPID|||\rPV1||I")
        XCTAssertEqual(parts.count, 3)
        XCTAssertTrue(parts[0].hasPrefix("MSH"))
        XCTAssertTrue(parts[1].hasPrefix("PID"))
        XCTAssertTrue(parts[2].hasPrefix("PV1"))
    }

    func testSegmentTerminatorLF() {
        let parts = SegmentTerminator.lf.split("MSH|^~\\&|\nPID|||\nPV1||I")
        XCTAssertEqual(parts.count, 3)
    }

    func testSegmentTerminatorCRLF() {
        let parts = SegmentTerminator.crlf.split("MSH|^~\\&|\r\nPID|||\r\nPV1||I")
        XCTAssertEqual(parts.count, 3)
    }

    func testSegmentTerminatorAny() {
        // Mixed terminators
        let parts = SegmentTerminator.any.split("MSH|^~\\&|\rPID|||\r\nPV1||I\nOBX||")
        XCTAssertEqual(parts.count, 4)
    }

    func testSegmentTerminatorFiltersEmptyLines() {
        let parts = SegmentTerminator.lf.split("MSH|^~\\&|\n\n\nPID|||")
        XCTAssertEqual(parts.count, 2)
    }

    func testSegmentTerminatorEquatable() {
        XCTAssertEqual(SegmentTerminator.cr, SegmentTerminator.cr)
        XCTAssertNotEqual(SegmentTerminator.cr, SegmentTerminator.lf)
    }

    // MARK: - ErrorRecoveryMode Tests

    func testErrorRecoveryModeEquatable() {
        XCTAssertEqual(ErrorRecoveryMode.strict, ErrorRecoveryMode.strict)
        XCTAssertEqual(ErrorRecoveryMode.skipInvalidSegments, ErrorRecoveryMode.skipInvalidSegments)
        XCTAssertEqual(ErrorRecoveryMode.bestEffort, ErrorRecoveryMode.bestEffort)
        XCTAssertNotEqual(ErrorRecoveryMode.strict, ErrorRecoveryMode.bestEffort)
    }

    // MARK: - ParserLocation Tests

    func testParserLocationInit() {
        let loc = ParserLocation(segmentIndex: 2, segmentID: "PID", fieldIndex: 5, offset: 100)
        XCTAssertEqual(loc.segmentIndex, 2)
        XCTAssertEqual(loc.segmentID, "PID")
        XCTAssertEqual(loc.fieldIndex, 5)
        XCTAssertEqual(loc.offset, 100)
    }

    func testParserLocationDefaults() {
        let loc = ParserLocation(segmentIndex: 0)
        XCTAssertNil(loc.segmentID)
        XCTAssertNil(loc.fieldIndex)
        XCTAssertNil(loc.offset)
    }

    func testParserLocationEquatable() {
        let a = ParserLocation(segmentIndex: 1, segmentID: "PID")
        let b = ParserLocation(segmentIndex: 1, segmentID: "PID")
        let c = ParserLocation(segmentIndex: 2, segmentID: "PID")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - ParserWarning / ParserError Tests

    func testParserWarningInit() {
        let loc = ParserLocation(segmentIndex: 0)
        let warning = ParserWarning(message: "test warning", location: loc)
        XCTAssertEqual(warning.message, "test warning")
        XCTAssertEqual(warning.location, loc)
    }

    func testParserErrorInit() {
        let loc = ParserLocation(segmentIndex: 1, segmentID: "PID")
        let error = ParserError(message: "test error", location: loc)
        XCTAssertEqual(error.message, "test error")
        XCTAssertEqual(error.location, loc)
    }

    // MARK: - ParserDiagnostics Tests

    func testParserDiagnosticsDefaults() {
        let diag = ParserDiagnostics()
        XCTAssertTrue(diag.warnings.isEmpty)
        XCTAssertTrue(diag.errors.isEmpty)
        XCTAssertEqual(diag.segmentsParsed, 0)
        XCTAssertEqual(diag.segmentsSkipped, 0)
        XCTAssertNil(diag.parseTime)
    }

    func testParserDiagnosticsMutation() {
        var diag = ParserDiagnostics()
        diag.segmentsParsed = 3
        diag.segmentsSkipped = 1
        diag.warnings.append(ParserWarning(message: "w", location: ParserLocation(segmentIndex: 0)))
        diag.errors.append(ParserError(message: "e", location: ParserLocation(segmentIndex: 1)))
        XCTAssertEqual(diag.segmentsParsed, 3)
        XCTAssertEqual(diag.segmentsSkipped, 1)
        XCTAssertEqual(diag.warnings.count, 1)
        XCTAssertEqual(diag.errors.count, 1)
    }

    // MARK: - ParserConfiguration Tests

    func testParserConfigurationDefaults() {
        let config = ParserConfiguration()
        XCTAssertEqual(config.strategy, .eager)
        XCTAssertFalse(config.strictMode)
        XCTAssertEqual(config.maxMessageSize, 1_048_576)
        XCTAssertTrue(config.allowCustomSegments)
        XCTAssertEqual(config.encoding, .utf8)
        XCTAssertEqual(config.segmentTerminator, .cr)
        XCTAssertTrue(config.autoDetectDelimiters)
        XCTAssertEqual(config.errorRecovery, .strict)
    }

    func testParserConfigurationCustom() {
        let config = ParserConfiguration(
            strategy: .lazy,
            strictMode: true,
            maxMessageSize: 512,
            allowCustomSegments: false,
            encoding: .ascii,
            segmentTerminator: .lf,
            autoDetectDelimiters: false,
            errorRecovery: .bestEffort
        )
        XCTAssertEqual(config.strategy, .lazy)
        XCTAssertTrue(config.strictMode)
        XCTAssertEqual(config.maxMessageSize, 512)
        XCTAssertFalse(config.allowCustomSegments)
        XCTAssertEqual(config.encoding, .ascii)
        XCTAssertEqual(config.segmentTerminator, .lf)
        XCTAssertFalse(config.autoDetectDelimiters)
        XCTAssertEqual(config.errorRecovery, .bestEffort)
    }

    func testParserConfigurationEquatable() {
        let a = ParserConfiguration()
        let b = ParserConfiguration()
        XCTAssertEqual(a, b)
    }

    // MARK: - ParseResult Tests

    func testParseResultEquatable() throws {
        let parser = HL7v2Parser()
        let r1 = try parser.parse(sampleMessage)
        let r2 = try parser.parse(sampleMessage)
        XCTAssertEqual(r1.message, r2.message)
    }

    // MARK: - HL7v2Parser: Basic Parsing

    func testParseSimpleMessage() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(sampleMessage)
        XCTAssertEqual(result.message.segmentCount, 3)
        XCTAssertEqual(result.message.allSegments[0].segmentID, "MSH")
        XCTAssertEqual(result.message.allSegments[1].segmentID, "PID")
        XCTAssertEqual(result.message.allSegments[2].segmentID, "PV1")
        XCTAssertEqual(result.diagnostics.segmentsParsed, 3)
        XCTAssertEqual(result.diagnostics.segmentsSkipped, 0)
        XCTAssertNotNil(result.diagnostics.parseTime)
    }

    func testParseLFTerminator() throws {
        let config = ParserConfiguration(segmentTerminator: .lf)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(sampleMessageLF)
        XCTAssertEqual(result.message.segmentCount, 3)
    }

    func testParseCRLFTerminator() throws {
        let config = ParserConfiguration(segmentTerminator: .crlf)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(sampleMessageCRLF)
        XCTAssertEqual(result.message.segmentCount, 3)
    }

    func testParseAnyTerminator() throws {
        let config = ParserConfiguration(segmentTerminator: .any)
        let parser = HL7v2Parser(configuration: config)
        // Mix CR and LF
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rPID|||1\nPV1||I"
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.segmentCount, 3)
    }

    func testParseFromData() throws {
        let parser = HL7v2Parser()
        let data = sampleMessage.data(using: .utf8)!
        let result = try parser.parse(data)
        XCTAssertEqual(result.message.segmentCount, 3)
    }

    func testParseFromDataAutoDetectEncoding() throws {
        let config = ParserConfiguration(encoding: .autoDetect)
        let parser = HL7v2Parser(configuration: config)
        let data = sampleMessage.data(using: .utf8)!
        let result = try parser.parse(data)
        XCTAssertEqual(result.message.segmentCount, 3)
    }

    func testParsePreservesMessageContent() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(sampleMessage)
        XCTAssertEqual(result.message.messageType(), "ADT^A01")
        XCTAssertEqual(result.message.messageControlID(), "12345")
        XCTAssertEqual(result.message.version(), "2.5")
    }

    // MARK: - HL7v2Parser: Delimiter Detection

    func testAutoDetectDelimiters() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(sampleMessage)
        XCTAssertEqual(result.message.encodingCharacters, .standard)
    }

    func testAutoDetectCustomDelimiters() throws {
        // Use # as field separator and custom encoding chars
        let msg = "MSH#^~\\&#SendApp#SendFac#RecApp#RecFac#20230101##ADT^A01#1#P#2.5\rPID###1"
        let config = ParserConfiguration(segmentTerminator: .cr)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.encodingCharacters.fieldSeparator, "#")
    }

    func testNoAutoDetectUsesStandard() throws {
        let config = ParserConfiguration(autoDetectDelimiters: false)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(sampleMessage)
        XCTAssertEqual(result.message.encodingCharacters, .standard)
    }

    // MARK: - HL7v2Parser: Error Handling

    func testParseEmptyStringThrows() {
        let parser = HL7v2Parser()
        XCTAssertThrowsError(try parser.parse(""))
    }

    func testParseNoMSHThrows() {
        let parser = HL7v2Parser()
        XCTAssertThrowsError(try parser.parse("PID|||12345"))
    }

    func testParseTooLargeMessageThrows() {
        let config = ParserConfiguration(maxMessageSize: 10)
        let parser = HL7v2Parser(configuration: config)
        XCTAssertThrowsError(try parser.parse(sampleMessage))
    }

    func testParseTooLargeDataThrows() {
        let config = ParserConfiguration(maxMessageSize: 10)
        let parser = HL7v2Parser(configuration: config)
        let data = sampleMessage.data(using: .utf8)!
        XCTAssertThrowsError(try parser.parse(data))
    }

    func testParseInvalidDataEncodingThrows() {
        let config = ParserConfiguration(encoding: .ascii)
        let parser = HL7v2Parser(configuration: config)
        // Create data with non-ASCII bytes that can't decode as ASCII
        var data = Data([0x80, 0x81, 0x82])
        // Pad with enough invalid bytes
        data.append(contentsOf: [UInt8](repeating: 0xFF, count: 10))
        XCTAssertThrowsError(try parser.parse(data))
    }

    // MARK: - HL7v2Parser: Error Recovery

    func testStrictModeFailsOnInvalidSegment() {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r!!INVALID\rPID|||1"
        let config = ParserConfiguration(errorRecovery: .strict)
        let parser = HL7v2Parser(configuration: config)
        XCTAssertThrowsError(try parser.parse(msg))
    }

    func testSkipInvalidSegments() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r!!\rPID|||1"
        let config = ParserConfiguration(errorRecovery: .skipInvalidSegments)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.segmentCount, 2) // MSH + PID
        XCTAssertEqual(result.diagnostics.segmentsSkipped, 1)
        XCTAssertEqual(result.diagnostics.errors.count, 1)
    }

    func testBestEffortRecovery() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r!!\rPID|||1"
        let config = ParserConfiguration(errorRecovery: .bestEffort)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.segmentCount, 2)
        XCTAssertEqual(result.diagnostics.segmentsSkipped, 1)
    }

    // MARK: - HL7v2Parser: Validation

    func testZSegmentAllowed() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rZZZ|custom"
        let config = ParserConfiguration(allowCustomSegments: true)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.segmentCount, 2)
        // No warning about Z-segments being disallowed
        let zWarnings = result.diagnostics.warnings.filter { $0.message.contains("not allowed") }
        XCTAssertTrue(zWarnings.isEmpty)
    }

    func testZSegmentDisallowedWarning() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rZZZ|custom"
        let config = ParserConfiguration(allowCustomSegments: false)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        let zWarnings = result.diagnostics.warnings.filter { $0.message.contains("not allowed") }
        XCTAssertFalse(zWarnings.isEmpty)
    }

    func testStrictModeWarnsEmptyRequiredFields() throws {
        // MSH with empty message type (MSH-9) and control ID (MSH-10)
        let msg = "MSH|^~\\&|A|B|C|D|20230101||||P|2.5"
        let config = ParserConfiguration(strictMode: true)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        let requiredWarnings = result.diagnostics.warnings.filter { $0.message.contains("Required field") }
        XCTAssertFalse(requiredWarnings.isEmpty)
    }

    func testNonStrictModeNoRequiredFieldWarnings() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||||P|2.5"
        let config = ParserConfiguration(strictMode: false)
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(msg)
        let requiredWarnings = result.diagnostics.warnings.filter { $0.message.contains("Required field") }
        XCTAssertTrue(requiredWarnings.isEmpty)
    }

    func testUnknownSegmentWarning() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rXYZ|data"
        let parser = HL7v2Parser()
        let result = try parser.parse(msg)
        let unknownWarnings = result.diagnostics.warnings.filter { $0.message.contains("Unknown segment") }
        XCTAssertFalse(unknownWarnings.isEmpty)
    }

    func testStandardSegmentsNoWarning() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rPID|||1\rPV1||I"
        let parser = HL7v2Parser()
        let result = try parser.parse(msg)
        let unknownWarnings = result.diagnostics.warnings.filter { $0.message.contains("Unknown segment") }
        XCTAssertTrue(unknownWarnings.isEmpty)
    }

    // MARK: - HL7v2Parser: Sendable

    func testParserIsSendable() {
        let parser = HL7v2Parser()
        let _: any Sendable = parser
        let _: any Sendable = parser.configuration
    }

    func testParseResultIsSendable() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(sampleMessage)
        let _: any Sendable = result
        let _: any Sendable = result.diagnostics
    }

    // MARK: - HL7v2StreamingParser: Basic

    func testStreamingParserBasic() throws {
        var sp = HL7v2StreamingParser()
        // Feed all data with a terminator at the end
        let feedData = (sampleMessage + "\r").data(using: .utf8)!
        _ = try sp.feed(feedData)
        try sp.finish()

        var segments: [BaseSegment] = []
        while let seg = try sp.next() {
            segments.append(seg)
        }
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].segmentID, "MSH")
        XCTAssertEqual(segments[1].segmentID, "PID")
        XCTAssertEqual(segments[2].segmentID, "PV1")
    }

    func testStreamingParserIncremental() throws {
        var sp = HL7v2StreamingParser()

        // Feed MSH segment + terminator
        let msh = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r"
        _ = try sp.feed(msh.data(using: .utf8)!)
        let seg1 = try sp.next()
        XCTAssertNotNil(seg1)
        XCTAssertEqual(seg1?.segmentID, "MSH")

        // Feed PID segment + terminator
        let pid = "PID|||12345\r"
        _ = try sp.feed(pid.data(using: .utf8)!)
        let seg2 = try sp.next()
        XCTAssertNotNil(seg2)
        XCTAssertEqual(seg2?.segmentID, "PID")

        // No more segments ready
        XCTAssertNil(try sp.next())
    }

    func testStreamingParserFinishFlushesBuffer() throws {
        var sp = HL7v2StreamingParser()
        // Feed data without trailing terminator
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5".data(using: .utf8)!
        _ = try sp.feed(data)

        // Should be no segments yet (no terminator seen)
        XCTAssertNil(try sp.next())

        // Finish should flush the buffered segment
        try sp.finish()
        let seg = try sp.next()
        XCTAssertNotNil(seg)
        XCTAssertEqual(seg?.segmentID, "MSH")
    }

    func testStreamingParserReset() throws {
        var sp = HL7v2StreamingParser()
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r".data(using: .utf8)!
        _ = try sp.feed(data)
        XCTAssertNotNil(try sp.next())

        sp.reset()
        XCTAssertFalse(sp.isFinished)
        XCTAssertNil(try sp.next())
    }

    func testStreamingParserIsFinished() throws {
        var sp = HL7v2StreamingParser()
        XCTAssertFalse(sp.isFinished)
        try sp.finish()
        XCTAssertTrue(sp.isFinished)
    }

    func testStreamingParserFeedAfterFinishThrows() throws {
        var sp = HL7v2StreamingParser()
        try sp.finish()
        XCTAssertThrowsError(try sp.feed(Data([0x41])))
    }

    func testStreamingParserDoubleFinish() throws {
        var sp = HL7v2StreamingParser()
        try sp.finish()
        // Should not throw on second finish
        try sp.finish()
        XCTAssertTrue(sp.isFinished)
    }

    func testStreamingParserMaxSizeExceeded() {
        let config = ParserConfiguration(maxMessageSize: 20)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = sampleMessage.data(using: .utf8)!
        XCTAssertThrowsError(try sp.feed(data))
    }

    func testStreamingParserErrorRecovery() throws {
        let config = ParserConfiguration(errorRecovery: .skipInvalidSegments)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r!!\rPID|||1\r".data(using: .utf8)!
        _ = try sp.feed(data)
        try sp.finish()

        var segments: [BaseSegment] = []
        while let seg = try sp.next() {
            segments.append(seg)
        }
        XCTAssertEqual(segments.count, 2) // MSH + PID, invalid skipped
    }

    func testStreamingParserStrictModeThrowsOnInvalid() {
        let config = ParserConfiguration(errorRecovery: .strict)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r!!\r".data(using: .utf8)!
        XCTAssertThrowsError(try sp.feed(data))
    }

    func testStreamingParserIsSendable() {
        let sp = HL7v2StreamingParser()
        let _: any Sendable = sp
    }

    // MARK: - HL7v2StreamingParser: LF Terminator

    func testStreamingParserLFTerminator() throws {
        let config = ParserConfiguration(segmentTerminator: .lf)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\nPID|||1\n".data(using: .utf8)!
        _ = try sp.feed(data)
        try sp.finish()

        var count = 0
        while try sp.next() != nil { count += 1 }
        XCTAssertEqual(count, 2)
    }

    // MARK: - HL7v2StreamingParser: CRLF Terminator

    func testStreamingParserCRLFTerminator() throws {
        let config = ParserConfiguration(segmentTerminator: .crlf)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r\nPID|||1\r\n".data(using: .utf8)!
        _ = try sp.feed(data)
        try sp.finish()

        var count = 0
        while try sp.next() != nil { count += 1 }
        XCTAssertEqual(count, 2)
    }

    // MARK: - HL7v2StreamingParser: Any Terminator

    func testStreamingParserAnyTerminator() throws {
        let config = ParserConfiguration(segmentTerminator: .any)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rPID|||1\n".data(using: .utf8)!
        _ = try sp.feed(data)
        try sp.finish()

        var count = 0
        while try sp.next() != nil { count += 1 }
        XCTAssertEqual(count, 2)
    }

    // MARK: - HL7v2Parser: Multiple Segment Types

    func testParseMultipleStandardSegments() throws {
        let msg = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\rEVN|A01\rPID|||1\rNK1|1\rPV1||I\rDG1|1\rOBX|1"
        let parser = HL7v2Parser()
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.segmentCount, 7)
        XCTAssertTrue(result.diagnostics.warnings.filter { $0.message.contains("Unknown") }.isEmpty)
    }

    // MARK: - ParsingStrategy Equatable

    func testParsingStrategyEquatable() {
        XCTAssertEqual(ParsingStrategy.eager, ParsingStrategy.eager)
        XCTAssertEqual(ParsingStrategy.lazy, ParsingStrategy.lazy)
        XCTAssertEqual(ParsingStrategy.indexed, ParsingStrategy.indexed)
        XCTAssertNotEqual(ParsingStrategy.eager, ParsingStrategy.lazy)
        XCTAssertEqual(ParsingStrategy.automatic(threshold: 100), ParsingStrategy.automatic(threshold: 100))
        XCTAssertNotEqual(ParsingStrategy.automatic(threshold: 100), ParsingStrategy.automatic(threshold: 200))
    }

    // MARK: - Edge Cases

    func testParseMinimalMessage() throws {
        let msg = "MSH|^~\\&|||||||||P|2.5"
        let parser = HL7v2Parser()
        let result = try parser.parse(msg)
        XCTAssertEqual(result.message.segmentCount, 1)
    }

    func testParseMSHTooShortThrows() {
        let parser = HL7v2Parser()
        XCTAssertThrowsError(try parser.parse("MSH|^~"))
    }

    func testParseWhitespaceOnlyThrows() {
        let parser = HL7v2Parser()
        XCTAssertThrowsError(try parser.parse("   \r\n   "))
    }

    func testStreamingParserAutoDetectEncoding() throws {
        let config = ParserConfiguration(encoding: .autoDetect)
        var sp = HL7v2StreamingParser(configuration: config)
        let data = "MSH|^~\\&|A|B|C|D|20230101||ADT^A01|1|P|2.5\r".data(using: .utf8)!
        _ = try sp.feed(data)
        try sp.finish()

        let seg = try sp.next()
        XCTAssertNotNil(seg)
        XCTAssertEqual(seg?.segmentID, "MSH")
    }
}
