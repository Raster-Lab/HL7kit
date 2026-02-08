/// Tests for HL7 v2.x Character Encoding Support (MSH-18)
///
/// Covers CharacterSet parsing, MSH-18 field extraction, encoding validation,
/// and parser configuration for respecting character set declarations.

import XCTest
import Foundation
@testable import HL7v2Kit
@testable import HL7Core

final class CharacterEncodingTests: XCTestCase {
    
    // MARK: - Test Data
    
    /// Message with UTF-8 character set in MSH-18
    private let messageWithUTF8 = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||UNICODE UTF-8\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    /// Message with ISO IR192 (UTF-8) in MSH-18
    private let messageWithISOIR192 = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||ISO IR192\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    /// Message with Latin-1 (8859/1) in MSH-18
    private let messageWithLatin1 = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||8859/1\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    /// Message with ASCII in MSH-18
    private let messageWithASCII = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||ASCII\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    /// Message without MSH-18 (empty field)
    private let messageWithoutCharSet = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    /// Message with multiple character sets in MSH-18 (repeating field)
    private let messageWithMultipleCharSets = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||ASCII~UNICODE UTF-8\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    /// Message with unsupported character set
    private let messageWithUnsupportedCharSet = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20230101120000||ADT^A01|12345|P|2.5|||||||GB 18030\rPID|||12345^^^MRN||Smith^John||19800101|M\rPV1||I|ICU"
    
    // MARK: - CharacterSet Tests
    
    func testCharacterSetParseUTF8Variants() {
        XCTAssertEqual(CharacterSet.parse("UNICODE UTF-8"), .unicodeUTF8)
        XCTAssertEqual(CharacterSet.parse("UTF-8"), .unicodeUTF8)
        XCTAssertEqual(CharacterSet.parse("UTF8"), .unicodeUTF8)
        XCTAssertEqual(CharacterSet.parse("ISO IR192"), .isoIR192)
        XCTAssertEqual(CharacterSet.parse("utf-8"), .unicodeUTF8) // case insensitive
    }
    
    func testCharacterSetParseUTF16Variants() {
        XCTAssertEqual(CharacterSet.parse("UNICODE UTF-16"), .unicodeUTF16)
        XCTAssertEqual(CharacterSet.parse("UTF-16"), .unicodeUTF16)
        XCTAssertEqual(CharacterSet.parse("UTF16"), .unicodeUTF16)
        XCTAssertEqual(CharacterSet.parse("UNICODE"), .unicode)
    }
    
    func testCharacterSetParseASCII() {
        XCTAssertEqual(CharacterSet.parse("ASCII"), .ascii)
        XCTAssertEqual(CharacterSet.parse("ISO IR6"), .isoIR6)
    }
    
    func testCharacterSetParseLatin1() {
        XCTAssertEqual(CharacterSet.parse("8859/1"), .iso88591)
        XCTAssertEqual(CharacterSet.parse("ISO IR100"), .isoIR100)
        XCTAssertEqual(CharacterSet.parse("ISO-8859-1"), .iso88591)
        XCTAssertEqual(CharacterSet.parse("LATIN1"), .iso88591)
        XCTAssertEqual(CharacterSet.parse("LATIN-1"), .iso88591)
    }
    
    func testCharacterSetParseLatin2() {
        XCTAssertEqual(CharacterSet.parse("8859/2"), .iso88592)
        XCTAssertEqual(CharacterSet.parse("ISO IR101"), .isoIR101)
        XCTAssertEqual(CharacterSet.parse("ISO-8859-2"), .iso88592)
    }
    
    func testCharacterSetParseUnknown() {
        XCTAssertNil(CharacterSet.parse("UNKNOWN"))
        XCTAssertNil(CharacterSet.parse(""))
        XCTAssertNil(CharacterSet.parse("   "))
    }
    
    func testCharacterSetToMessageEncoding() {
        XCTAssertEqual(CharacterSet.ascii.toMessageEncoding(), .ascii)
        XCTAssertEqual(CharacterSet.isoIR6.toMessageEncoding(), .ascii)
        XCTAssertEqual(CharacterSet.unicodeUTF8.toMessageEncoding(), .utf8)
        XCTAssertEqual(CharacterSet.isoIR192.toMessageEncoding(), .utf8)
        XCTAssertEqual(CharacterSet.iso88591.toMessageEncoding(), .latin1)
        XCTAssertEqual(CharacterSet.isoIR100.toMessageEncoding(), .latin1)
        XCTAssertEqual(CharacterSet.unicode.toMessageEncoding(), .utf16)
        XCTAssertEqual(CharacterSet.unicodeUTF16.toMessageEncoding(), .utf16)
    }
    
    func testCharacterSetToMessageEncodingUnsupported() {
        // Character sets with no direct MessageEncoding mapping
        XCTAssertNil(CharacterSet.iso88592.toMessageEncoding())
        XCTAssertNil(CharacterSet.gb18030.toMessageEncoding())
        XCTAssertNil(CharacterSet.big5.toMessageEncoding())
    }
    
    func testCharacterSetToStringEncoding() {
        XCTAssertEqual(CharacterSet.ascii.toStringEncoding(), .ascii)
        XCTAssertEqual(CharacterSet.unicodeUTF8.toStringEncoding(), .utf8)
        XCTAssertEqual(CharacterSet.iso88591.toStringEncoding(), .isoLatin1)
        XCTAssertEqual(CharacterSet.iso88592.toStringEncoding(), .isoLatin2)
        XCTAssertEqual(CharacterSet.unicode.toStringEncoding(), .utf16)
    }
    
    // MARK: - Message Character Set Extraction Tests
    
    func testMessageCharacterSetsUTF8() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithUTF8)
        let message = result.message
        
        let charsets = message.characterSets()
        XCTAssertEqual(charsets.count, 1)
        XCTAssertEqual(charsets.first, .unicodeUTF8)
    }
    
    func testMessageCharacterSetsISOIR192() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithISOIR192)
        let message = result.message
        
        let charsets = message.characterSets()
        XCTAssertEqual(charsets.count, 1)
        XCTAssertEqual(charsets.first, .isoIR192)
    }
    
    func testMessageCharacterSetsLatin1() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithLatin1)
        let message = result.message
        
        let charsets = message.characterSets()
        XCTAssertEqual(charsets.count, 1)
        XCTAssertEqual(charsets.first, .iso88591)
    }
    
    func testMessageCharacterSetsASCII() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithASCII)
        let message = result.message
        
        let charsets = message.characterSets()
        XCTAssertEqual(charsets.count, 1)
        XCTAssertEqual(charsets.first, .ascii)
    }
    
    func testMessageCharacterSetsEmpty() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithoutCharSet)
        let message = result.message
        
        let charsets = message.characterSets()
        XCTAssertTrue(charsets.isEmpty)
    }
    
    func testMessageCharacterSetsMultiple() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithMultipleCharSets)
        let message = result.message
        
        let charsets = message.characterSets()
        XCTAssertEqual(charsets.count, 2)
        XCTAssertEqual(charsets[0], .ascii)
        XCTAssertEqual(charsets[1], .unicodeUTF8)
    }
    
    func testMessagePrimaryCharacterSet() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithUTF8)
        let message = result.message
        
        let primaryCharset = message.primaryCharacterSet()
        XCTAssertEqual(primaryCharset, .unicodeUTF8)
    }
    
    func testMessagePrimaryCharacterSetEmpty() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithoutCharSet)
        let message = result.message
        
        let primaryCharset = message.primaryCharacterSet()
        XCTAssertNil(primaryCharset)
    }
    
    func testMessagePrimaryEncoding() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithUTF8)
        let message = result.message
        
        let encoding = message.primaryEncoding()
        XCTAssertEqual(encoding, .utf8)
    }
    
    func testMessagePrimaryEncodingLatin1() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithLatin1)
        let message = result.message
        
        let encoding = message.primaryEncoding()
        XCTAssertEqual(encoding, .latin1)
    }
    
    // MARK: - Parser Configuration Tests
    
    func testParserConfigurationDefaultValues() {
        let config = ParserConfiguration()
        XCTAssertTrue(config.respectMSH18)
        XCTAssertFalse(config.validateEncoding)
    }
    
    func testParserConfigurationCustomValues() {
        let config = ParserConfiguration(
            respectMSH18: false,
            validateEncoding: true
        )
        XCTAssertFalse(config.respectMSH18)
        XCTAssertTrue(config.validateEncoding)
    }
    
    func testParserConfigurationEquatable() {
        let config1 = ParserConfiguration(respectMSH18: true, validateEncoding: false)
        let config2 = ParserConfiguration(respectMSH18: true, validateEncoding: false)
        let config3 = ParserConfiguration(respectMSH18: false, validateEncoding: true)
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    // MARK: - Encoding Validation Tests
    
    func testEncodingValidationNoWarningWhenMatching() throws {
        let config = ParserConfiguration(
            encoding: .utf8,
            validateEncoding: true
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithUTF8)
        
        // Should have no warnings when encoding matches
        XCTAssertTrue(result.diagnostics.warnings.isEmpty)
    }
    
    func testEncodingValidationWarningWhenMismatch() throws {
        let config = ParserConfiguration(
            encoding: .ascii,
            validateEncoding: true
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithUTF8)
        
        // Should have warning about encoding mismatch
        XCTAssertFalse(result.diagnostics.warnings.isEmpty)
        let hasEncodingWarning = result.diagnostics.warnings.contains { warning in
            warning.message.contains("Encoding mismatch")
        }
        XCTAssertTrue(hasEncodingWarning)
    }
    
    func testEncodingValidationNoWarningWhenAutoDetect() throws {
        let config = ParserConfiguration(
            encoding: .autoDetect,
            validateEncoding: true
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithUTF8)
        
        // Should have no warnings when using autoDetect
        let hasEncodingWarning = result.diagnostics.warnings.contains { warning in
            warning.message.contains("Encoding mismatch")
        }
        XCTAssertFalse(hasEncodingWarning)
    }
    
    func testEncodingValidationWarningForUnsupportedCharset() throws {
        let config = ParserConfiguration(
            encoding: .utf8,
            validateEncoding: true
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithUnsupportedCharSet)
        
        // Should have warning about unsupported character set
        XCTAssertFalse(result.diagnostics.warnings.isEmpty)
        let hasUnsupportedWarning = result.diagnostics.warnings.contains { warning in
            warning.message.contains("not directly supported")
        }
        XCTAssertTrue(hasUnsupportedWarning)
    }
    
    func testEncodingValidationWarningForMultipleCharsets() throws {
        let config = ParserConfiguration(
            encoding: .ascii,
            validateEncoding: true
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithMultipleCharSets)
        
        // Should have warning about multiple character sets
        XCTAssertFalse(result.diagnostics.warnings.isEmpty)
        let hasMultiEncodingWarning = result.diagnostics.warnings.contains { warning in
            warning.message.contains("declares 2 character sets")
        }
        XCTAssertTrue(hasMultiEncodingWarning)
    }
    
    func testEncodingValidationDisabled() throws {
        let config = ParserConfiguration(
            encoding: .ascii,
            validateEncoding: false
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithUTF8)
        
        // Should have no warnings when validation is disabled
        let hasEncodingWarning = result.diagnostics.warnings.contains { warning in
            warning.message.contains("Encoding mismatch")
        }
        XCTAssertFalse(hasEncodingWarning)
    }
    
    func testEncodingValidationNoWarningWhenNoMSH18() throws {
        let config = ParserConfiguration(
            encoding: .ascii,
            validateEncoding: true
        )
        let parser = HL7v2Parser(configuration: config)
        let result = try parser.parse(messageWithoutCharSet)
        
        // Should have no warnings when MSH-18 is empty
        let hasEncodingWarning = result.diagnostics.warnings.contains { warning in
            warning.message.contains("Encoding mismatch")
        }
        XCTAssertFalse(hasEncodingWarning)
    }
    
    // MARK: - Integration Tests
    
    func testParseWithLatin1CharacterSet() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithLatin1)
        
        XCTAssertEqual(result.message.segmentCount, 3)
        XCTAssertEqual(result.message.primaryCharacterSet(), .iso88591)
        XCTAssertEqual(result.message.primaryEncoding(), .latin1)
    }
    
    func testParseAndSerializeWithEncoding() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithUTF8)
        let message = result.message
        
        // Serialize and verify
        let serialized = try message.serialize()
        XCTAssertTrue(serialized.contains("UNICODE UTF-8"))
        
        // Parse again
        let result2 = try parser.parse(serialized)
        XCTAssertEqual(result2.message.primaryCharacterSet(), .unicodeUTF8)
    }
    
    func testRoundTripWithMultipleEncodings() throws {
        let parser = HL7v2Parser()
        let result = try parser.parse(messageWithMultipleCharSets)
        let message = result.message
        
        // Verify multiple charsets were preserved
        let charsets = message.characterSets()
        XCTAssertEqual(charsets.count, 2)
        
        // Serialize and re-parse
        let serialized = try message.serialize()
        let result2 = try parser.parse(serialized)
        let charsets2 = result2.message.characterSets()
        XCTAssertEqual(charsets2.count, 2)
        XCTAssertEqual(charsets2, charsets)
    }
}
