import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for EscapeSequenceProcessor
final class EscapeSequenceProcessorTests: XCTestCase {
    
    // MARK: - Standard Escape Sequences
    
    func testDecodeLineBreak() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Line 1\\.br\\Line 2"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Line 1\nLine 2")
    }
    
    func testDecodeFieldSeparator() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\F\\Continued"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Value|Continued")
    }
    
    func testDecodeComponentSeparator() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\S\\Continued"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Value^Continued")
    }
    
    func testDecodeSubcomponentSeparator() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\T\\Continued"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Value&Continued")
    }
    
    func testDecodeRepetitionSeparator() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\R\\Continued"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Value~Continued")
    }
    
    func testDecodeEscapeCharacter() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\E\\Continued"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Value\\Continued")
    }
    
    // MARK: - Hexadecimal Sequences
    
    func testDecodeHexadecimalSequence() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\X41\\End" // 0x41 = 'A'
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "ValueAEnd")
    }
    
    func testDecodeMultipleHexSequences() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "\\X48\\\\X65\\\\X6C\\\\X6C\\\\X6F\\" // "Hello"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Hello")
    }
    
    // MARK: - Multiple Escape Sequences
    
    func testDecodeMultipleEscapeSequences() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "Line 1\\.br\\Line 2\\F\\Field"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "Line 1\nLine 2|Field")
    }
    
    func testDecodeConsecutiveEscapeSequences() async throws {
        let processor = EscapeSequenceProcessor()
        let input = "\\F\\\\S\\\\T\\"
        let result = try await processor.decode(input)
        
        XCTAssertEqual(result, "|^&")
    }
    
    // MARK: - Error Cases
    
    func testDecodeUnclosedEscapeSequence() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\Fwithout closing"
        
        do {
            _ = try await processor.decode(input)
            XCTFail("Expected error for unclosed escape sequence")
        } catch HL7Error.parsingError(let message, _) {
            XCTAssertTrue(message.contains("Unclosed escape sequence"))
        } catch {
            XCTFail("Expected HL7Error.parsingError, got \(error)")
        }
    }
    
    func testDecodeUnknownEscapeSequence() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\Z\\End"
        
        do {
            _ = try await processor.decode(input)
            XCTFail("Expected error for unknown escape sequence")
        } catch HL7Error.parsingError(let message, _) {
            XCTAssertTrue(message.contains("Unknown escape sequence"))
        } catch {
            XCTFail("Expected HL7Error.parsingError, got \(error)")
        }
    }
    
    func testDecodeInvalidHexSequence() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\XZZ\\End"
        
        do {
            _ = try await processor.decode(input)
            XCTFail("Expected error for invalid hex sequence")
        } catch HL7Error.parsingError(let message, _) {
            XCTAssertTrue(message.contains("Unknown escape sequence"))
        } catch {
            XCTFail("Expected HL7Error.parsingError, got \(error)")
        }
    }
    
    // MARK: - Encoding Tests
    
    func testEncodeFieldSeparator() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value|Continued"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Value\\F\\Continued")
    }
    
    func testEncodeComponentSeparator() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value^Continued"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Value\\S\\Continued")
    }
    
    func testEncodeSubcomponentSeparator() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value&Continued"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Value\\T\\Continued")
    }
    
    func testEncodeRepetitionSeparator() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value~Continued"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Value\\R\\Continued")
    }
    
    func testEncodeEscapeCharacter() async {
        let processor = EscapeSequenceProcessor()
        let input = "Value\\Continued"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Value\\E\\Continued")
    }
    
    func testEncodeLineBreak() async {
        let processor = EscapeSequenceProcessor()
        let input = "Line 1\nLine 2"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Line 1\\.br\\Line 2")
    }
    
    func testEncodeMultipleSpecialCharacters() async {
        let processor = EscapeSequenceProcessor()
        let input = "A|B^C&D~E\\F\nG"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "A\\F\\B\\S\\C\\T\\D\\R\\E\\E\\F\\.br\\G")
    }
    
    func testEncodeNoSpecialCharacters() async {
        let processor = EscapeSequenceProcessor()
        let input = "Simple text"
        let result = await processor.encode(input)
        
        XCTAssertEqual(result, "Simple text")
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripEncodeAndDecode() async throws {
        let processor = EscapeSequenceProcessor()
        let original = "Value with | and ^ and & and ~ and \\ and \n"
        
        let encoded = await processor.encode(original)
        let decoded = try await processor.decode(encoded)
        
        XCTAssertEqual(decoded, original)
    }
    
    func testRoundTripSimpleText() async throws {
        let processor = EscapeSequenceProcessor()
        let original = "Simple text without special characters"
        
        let encoded = await processor.encode(original)
        let decoded = try await processor.decode(encoded)
        
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(encoded, original) // Should be unchanged
    }
}
