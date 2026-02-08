/// Tests for character encoding support
///
/// Tests for multiple character encoding detection and conversion

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class EncodingTests: XCTestCase {
    
    // MARK: - Encoding Detection Tests
    
    func testDetectASCII() {
        let asciiData = Data("MSH|test".utf8)
        let detected = MessageEncoding.detect(from: asciiData)
        
        XCTAssertEqual(detected, .ascii)
    }
    
    func testDetectUTF8WithBOM() {
        var utf8Data = Data([0xEF, 0xBB, 0xBF]) // UTF-8 BOM
        utf8Data.append("MSH|test".data(using: .utf8)!)
        
        let detected = MessageEncoding.detect(from: utf8Data)
        
        XCTAssertEqual(detected, .utf8)
    }
    
    func testDetectUTF8NonASCII() {
        let utf8Data = "MSH|tëst".data(using: .utf8)!
        let detected = MessageEncoding.detect(from: utf8Data)
        
        XCTAssertEqual(detected, .utf8)
    }
    
    func testDetectUTF16LEWithBOM() {
        var utf16Data = Data([0xFF, 0xFE]) // UTF-16 LE BOM
        utf16Data.append("MSH|test".data(using: .utf16LittleEndian)!)
        
        let detected = MessageEncoding.detect(from: utf16Data)
        
        XCTAssertEqual(detected, .utf16)
    }
    
    func testDetectUTF16BEWithBOM() {
        var utf16Data = Data([0xFE, 0xFF]) // UTF-16 BE BOM
        utf16Data.append("MSH|test".data(using: .utf16BigEndian)!)
        
        let detected = MessageEncoding.detect(from: utf16Data)
        
        XCTAssertEqual(detected, .utf16BigEndian)
    }
    
    func testDetectWindows1252() {
        // Windows-1252 has printable characters in 0x80-0x9F range
        var data = Data("MSH|test".utf8)
        data.append(0x80) // Euro sign in Windows-1252
        
        let detected = MessageEncoding.detect(from: data)
        
        XCTAssertEqual(detected, .windows1252)
    }
    
    func testDetectLatin1Fallback() {
        // Invalid UTF-8 sequence that should fall back to Latin-1
        let data = Data([0xFF, 0xFE, 0x00, 0x01]) // Invalid UTF-8, not UTF-16 BOM
        
        let detected = MessageEncoding.detect(from: data)
        
        // Should fall back to Latin-1
        XCTAssertTrue([.latin1, .windows1252].contains(detected))
    }
    
    // MARK: - String Encoding Conversion Tests
    
    func testASCIIStringEncoding() {
        let encoding = MessageEncoding.ascii
        XCTAssertEqual(encoding.stringEncoding, .ascii)
    }
    
    func testUTF8StringEncoding() {
        let encoding = MessageEncoding.utf8
        XCTAssertEqual(encoding.stringEncoding, .utf8)
    }
    
    func testUTF16StringEncoding() {
        let encoding = MessageEncoding.utf16
        XCTAssertEqual(encoding.stringEncoding, .utf16LittleEndian)
    }
    
    func testUTF16BigEndianStringEncoding() {
        let encoding = MessageEncoding.utf16BigEndian
        XCTAssertEqual(encoding.stringEncoding, .utf16BigEndian)
    }
    
    func testLatin1StringEncoding() {
        let encoding = MessageEncoding.latin1
        XCTAssertEqual(encoding.stringEncoding, .isoLatin1)
    }
    
    func testWindows1252StringEncoding() {
        let encoding = MessageEncoding.windows1252
        XCTAssertEqual(encoding.stringEncoding, .windowsCP1252)
    }
    
    func testAutoDetectStringEncoding() {
        let encoding = MessageEncoding.autoDetect
        // Auto-detect defaults to UTF-8
        XCTAssertEqual(encoding.stringEncoding, .utf8)
    }
    
    // MARK: - Parser with Different Encodings Tests
    
    func testParseASCIIMessage() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5"
        let config = ParserConfiguration(encoding: .ascii)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(message)
        
        XCTAssertNotNil(result.message.msh())
        XCTAssertEqual(result.message.msh()?.messageControlID, "MSG001")
    }
    
    func testParseUTF8Message() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\rPID|1||12345||Döe^Jöhn"
        let config = ParserConfiguration(encoding: .utf8)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(message)
        
        XCTAssertEqual(result.message.segments.count, 2)
    }
    
    func testParseUTF16Message() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5"
        guard let utf16Data = message.data(using: .utf16LittleEndian) else {
            XCTFail("Failed to encode message as UTF-16")
            return
        }
        
        let config = ParserConfiguration(encoding: .utf16)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(utf16Data)
        
        XCTAssertNotNil(result.message.msh())
    }
    
    func testParseWithAutoDetect() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5"
        guard let data = message.data(using: .utf8) else {
            XCTFail("Failed to encode message")
            return
        }
        
        let config = ParserConfiguration(encoding: .autoDetect)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(data)
        
        XCTAssertNotNil(result.message.msh())
        XCTAssertEqual(result.message.msh()?.messageControlID, "MSG001")
    }
    
    // MARK: - Special Character Tests
    
    func testParseMessageWithAccentedCharacters() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\rPID|1||12345||Müller^François"
        let config = ParserConfiguration(encoding: .utf8)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(message)
        
        XCTAssertEqual(result.message.segments.count, 2)
        
        let pidSegment = result.message.segments[1]
        XCTAssertTrue(pidSegment.serialize().contains("Müller"))
        XCTAssertTrue(pidSegment.serialize().contains("François"))
    }
    
    func testParseMessageWithChineseCharacters() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\rPID|1||12345||张^伟"
        let config = ParserConfiguration(encoding: .utf8)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(message)
        
        XCTAssertEqual(result.message.segments.count, 2)
        
        let pidSegment = result.message.segments[1]
        let serialized = pidSegment.serialize()
        XCTAssertTrue(serialized.contains("张") || serialized.contains("Wei"))
    }
    
    func testParseMessageWithEmoji() throws {
        let message = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\rNTE|1||Patient is happy 😊"
        let config = ParserConfiguration(encoding: .utf8)
        let parser = HL7v2Parser(configuration: config)
        
        let result = try parser.parse(message)
        
        XCTAssertEqual(result.message.segments.count, 2)
    }
    
    // MARK: - Encoding Preservation Tests
    
    func testRoundTripUTF8() throws {
        let originalMessage = "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5\rPID|1||12345||Müller^José"
        let config = ParserConfiguration(encoding: .utf8)
        let parser = HL7v2Parser(configuration: config)
        
        let parseResult = try parser.parse(originalMessage)
        let serialized = try parseResult.message.serialize()
        
        // Parse the serialized message again
        let reparsed = try parser.parse(serialized)
        
        XCTAssertEqual(reparsed.message.segments.count, parseResult.message.segments.count)
    }
    
    // MARK: - Mixed Encoding Tests
    
    func testMultipleEncodingDetections() throws {
        let testCases: [(Data, MessageEncoding)] = [
            (Data("MSH|test".utf8), .ascii),
            (Data([0xEF, 0xBB, 0xBF]) + Data("MSH|test".utf8), .utf8),
            (Data([0xFF, 0xFE]) + "MSH".data(using: .utf16LittleEndian)!, .utf16),
            (Data([0xFE, 0xFF]) + "MSH".data(using: .utf16BigEndian)!, .utf16BigEndian)
        ]
        
        for (data, expectedEncoding) in testCases {
            let detected = MessageEncoding.detect(from: data)
            
            if expectedEncoding == .ascii {
                // ASCII or UTF-8 are both valid for pure ASCII
                XCTAssertTrue([.ascii, .utf8].contains(detected))
            } else {
                XCTAssertEqual(detected, expectedEncoding)
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyDataEncoding() {
        let emptyData = Data()
        let detected = MessageEncoding.detect(from: emptyData)
        
        // Empty data should default to Latin-1 (always succeeds)
        XCTAssertEqual(detected, .latin1)
    }
    
    func testSingleByteEncoding() {
        let singleByte = Data([0x4D]) // 'M' in ASCII
        let detected = MessageEncoding.detect(from: singleByte)
        
        XCTAssertEqual(detected, .ascii)
    }
    
    // MARK: - Encoding Equality Tests
    
    func testEncodingEquality() {
        XCTAssertEqual(MessageEncoding.ascii, MessageEncoding.ascii)
        XCTAssertEqual(MessageEncoding.utf8, MessageEncoding.utf8)
        XCTAssertEqual(MessageEncoding.utf16, MessageEncoding.utf16)
        XCTAssertNotEqual(MessageEncoding.ascii, MessageEncoding.utf8)
        XCTAssertNotEqual(MessageEncoding.utf16, MessageEncoding.utf16BigEndian)
    }
    
    // MARK: - Configuration Tests
    
    func testParserConfigurationWithDifferentEncodings() {
        let encodings: [MessageEncoding] = [.ascii, .utf8, .utf16, .utf16BigEndian, .latin1, .windows1252, .autoDetect]
        
        for encoding in encodings {
            let config = ParserConfiguration(encoding: encoding)
            XCTAssertEqual(config.encoding, encoding)
            
            let parser = HL7v2Parser(configuration: config)
            XCTAssertEqual(parser.configuration.encoding, encoding)
        }
    }
}
