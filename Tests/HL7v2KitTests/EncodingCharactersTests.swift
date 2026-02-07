import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for EncodingCharacters structure
final class EncodingCharactersTests: XCTestCase {
    
    // MARK: - Standard Encoding Tests
    
    func testStandardEncodingCharacters() {
        let encoding = EncodingCharacters.standard
        
        XCTAssertEqual(encoding.fieldSeparator, "|")
        XCTAssertEqual(encoding.componentSeparator, "^")
        XCTAssertEqual(encoding.repetitionSeparator, "~")
        XCTAssertEqual(encoding.escapeCharacter, "\\")
        XCTAssertEqual(encoding.subcomponentSeparator, "&")
    }
    
    func testStandardEncodingString() {
        let encoding = EncodingCharacters.standard
        XCTAssertEqual(encoding.toEncodingString(), "^~\\&")
    }
    
    // MARK: - Parsing Tests
    
    func testParseValidEncodingString() throws {
        let encoding = try EncodingCharacters.parse(from: "^~\\&")
        
        XCTAssertEqual(encoding.fieldSeparator, "|")
        XCTAssertEqual(encoding.componentSeparator, "^")
        XCTAssertEqual(encoding.repetitionSeparator, "~")
        XCTAssertEqual(encoding.escapeCharacter, "\\")
        XCTAssertEqual(encoding.subcomponentSeparator, "&")
    }
    
    func testParseCustomFieldSeparator() throws {
        let encoding = try EncodingCharacters.parse(from: "^~\\&", fieldSeparator: "|")
        XCTAssertEqual(encoding.fieldSeparator, "|")
    }
    
    func testParseInvalidEncodingStringTooShort() {
        XCTAssertThrowsError(try EncodingCharacters.parse(from: "^~\\")) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("expected 4 characters"))
        }
    }
    
    func testParseInvalidEncodingStringTooLong() {
        XCTAssertThrowsError(try EncodingCharacters.parse(from: "^~\\&!")) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("expected 4 characters"))
        }
    }
    
    // MARK: - Custom Encoding Tests
    
    func testCustomEncodingCharacters() {
        let encoding = EncodingCharacters(
            fieldSeparator: ";",
            componentSeparator: ":",
            repetitionSeparator: "*",
            escapeCharacter: "/",
            subcomponentSeparator: "#"
        )
        
        XCTAssertEqual(encoding.fieldSeparator, ";")
        XCTAssertEqual(encoding.componentSeparator, ":")
        XCTAssertEqual(encoding.repetitionSeparator, "*")
        XCTAssertEqual(encoding.escapeCharacter, "/")
        XCTAssertEqual(encoding.subcomponentSeparator, "#")
        XCTAssertEqual(encoding.toEncodingString(), ":*/#")
    }
    
    // MARK: - Delimiter Detection Tests
    
    func testIsDelimiter() {
        let encoding = EncodingCharacters.standard
        
        XCTAssertTrue(encoding.isDelimiter("|"))
        XCTAssertTrue(encoding.isDelimiter("^"))
        XCTAssertTrue(encoding.isDelimiter("~"))
        XCTAssertTrue(encoding.isDelimiter("\\"))
        XCTAssertTrue(encoding.isDelimiter("&"))
        
        XCTAssertFalse(encoding.isDelimiter("A"))
        XCTAssertFalse(encoding.isDelimiter("1"))
        XCTAssertFalse(encoding.isDelimiter(" "))
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable() {
        let encoding1 = EncodingCharacters.standard
        let encoding2 = EncodingCharacters.standard
        let encoding3 = EncodingCharacters(
            fieldSeparator: ";",
            componentSeparator: "^",
            repetitionSeparator: "~",
            escapeCharacter: "\\",
            subcomponentSeparator: "&"
        )
        
        XCTAssertEqual(encoding1, encoding2)
        XCTAssertNotEqual(encoding1, encoding3)
    }
}
