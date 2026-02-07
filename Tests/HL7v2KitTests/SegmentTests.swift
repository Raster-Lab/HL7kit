import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for Segment parsing and serialization
final class SegmentTests: XCTestCase {
    
    // MARK: - Basic Segment Tests
    
    func testParseSimpleSegment() throws {
        let segment = try BaseSegment.parse("PID|1|12345")
        
        XCTAssertEqual(segment.segmentID, "PID")
        XCTAssertEqual(segment.fields.count, 2)
        XCTAssertEqual(segment[0].value.value.raw, "1")
        XCTAssertEqual(segment[1].value.value.raw, "12345")
    }
    
    func testParseSegmentWithComponents() throws {
        let segment = try BaseSegment.parse("PID|1|12345^^^Hospital^MR")
        
        XCTAssertEqual(segment.segmentID, "PID")
        XCTAssertEqual(segment[1][0].value.raw, "12345")
        XCTAssertEqual(segment[1][1].value.raw, "")
        XCTAssertEqual(segment[1][2].value.raw, "")
        XCTAssertEqual(segment[1][3].value.raw, "Hospital")
        XCTAssertEqual(segment[1][4].value.raw, "MR")
    }
    
    func testParseSegmentWithSubcomponents() throws {
        let segment = try BaseSegment.parse("PID|1|Smith&John&A")
        
        XCTAssertEqual(segment.segmentID, "PID")
        XCTAssertEqual(segment[1][0][0].raw, "Smith")
        XCTAssertEqual(segment[1][0][1].raw, "John")
        XCTAssertEqual(segment[1][0][2].raw, "A")
    }
    
    func testParseSegmentWithRepetitions() throws {
        let segment = try BaseSegment.parse("PID|1|Phone1~Phone2~Phone3")
        
        XCTAssertEqual(segment.segmentID, "PID")
        XCTAssertEqual(segment[1].repetitionCount, 3)
        XCTAssertEqual(segment[1].repetition(at: 0)[0].value.raw, "Phone1")
        XCTAssertEqual(segment[1].repetition(at: 1)[0].value.raw, "Phone2")
        XCTAssertEqual(segment[1].repetition(at: 2)[0].value.raw, "Phone3")
    }
    
    // MARK: - MSH Segment Tests
    
    func testParseMSHSegment() throws {
        let msh = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240207120000||ADT^A01|MSG001|P|2.5.1"
        let segment = try BaseSegment.parse(msh)
        
        XCTAssertEqual(segment.segmentID, "MSH")
        XCTAssertEqual(segment[0].value.value.raw, "|")
        XCTAssertEqual(segment[1].value.value.raw, "^~\\&")
        XCTAssertEqual(segment[2].value.value.raw, "SendApp")
        XCTAssertEqual(segment[3].value.value.raw, "SendFac")
        XCTAssertEqual(segment[4].value.value.raw, "RecApp")
        XCTAssertEqual(segment[5].value.value.raw, "RecFac")
    }
    
    func testParseMSHWithMessageType() throws {
        let msh = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240207120000||ADT^A01|MSG001|P|2.5.1"
        let segment = try BaseSegment.parse(msh)
        
        // MSH-9 is the message type (ADT^A01)
        XCTAssertEqual(segment[8][0].value.raw, "ADT")
        XCTAssertEqual(segment[8][1].value.raw, "A01")
    }
    
    func testMSHFieldSeparatorMismatch() {
        let msh = "MSH;^~\\&|SendApp|SendFac"
        
        XCTAssertThrowsError(try BaseSegment.parse(msh)) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("field separator mismatch"))
        }
    }
    
    func testMSHTooShort() {
        let msh = "MSH|^~"
        
        XCTAssertThrowsError(try BaseSegment.parse(msh)) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Error Cases
    
    func testParseSegmentTooShort() {
        let shortSegment = "PI"
        
        XCTAssertThrowsError(try BaseSegment.parse(shortSegment)) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("too short"))
        }
    }
    
    func testParseInvalidSegmentID() {
        let invalidSegment = "P@D|1|12345"
        
        XCTAssertThrowsError(try BaseSegment.parse(invalidSegment)) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Invalid segment ID"))
        }
    }
    
    // MARK: - Serialization Tests
    
    func testSerializeSimpleSegment() throws {
        let segment = try BaseSegment.parse("PID|1|12345")
        let serialized = try segment.serialize()
        
        XCTAssertEqual(serialized, "PID|1|12345")
    }
    
    func testSerializeSegmentWithComponents() throws {
        let segment = try BaseSegment.parse("PID|1|Smith^John^A")
        let serialized = try segment.serialize()
        
        XCTAssertEqual(serialized, "PID|1|Smith^John^A")
    }
    
    func testSerializeMSHSegment() throws {
        let msh = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240207120000||ADT^A01|MSG001|P|2.5.1"
        let segment = try BaseSegment.parse(msh)
        let serialized = try segment.serialize()
        
        XCTAssertEqual(serialized, msh)
    }
    
    func testSerializeMSHInvalidFieldCount() throws {
        // Create an MSH segment with insufficient fields
        let field1 = Field.parse("|")
        let segment = BaseSegment(segmentID: "MSH", fields: [field1])
        
        XCTAssertThrowsError(try segment.serialize()) { error in
            guard case HL7Error.validationError(let message, _) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("at least 2 fields"))
        }
    }
    
    // MARK: - Field Access Tests
    
    func testFieldAccess() throws {
        let segment = try BaseSegment.parse("PID|1|12345|Smith^John")
        
        XCTAssertEqual(segment[0].value.value.raw, "1")
        XCTAssertEqual(segment[1].value.value.raw, "12345")
        XCTAssertEqual(segment[2][0].value.raw, "Smith")
        XCTAssertEqual(segment[2][1].value.raw, "John")
    }
    
    func testOutOfBoundsFieldAccess() throws {
        let segment = try BaseSegment.parse("PID|1|12345")
        
        let field = segment[10]
        XCTAssertTrue(field.isEmpty)
    }
    
    // MARK: - Equatable Tests
    
    func testSegmentEquatable() throws {
        let segment1 = try BaseSegment.parse("PID|1|12345")
        let segment2 = try BaseSegment.parse("PID|1|12345")
        let segment3 = try BaseSegment.parse("PID|1|67890")
        
        XCTAssertEqual(segment1, segment2)
        XCTAssertNotEqual(segment1, segment3)
    }
    
    // MARK: - Description Tests
    
    func testSegmentDescription() throws {
        let segment = try BaseSegment.parse("PID|1|12345")
        XCTAssertEqual(segment.description, "PID|1|12345")
    }
    
    // MARK: - Complex Segment Tests
    
    func testComplexSegment() throws {
        let segment = try BaseSegment.parse("OBX|1|NM|8310-5^Body Temperature^LN||36.5|Cel|35.0-37.5|N|||F")
        
        XCTAssertEqual(segment.segmentID, "OBX")
        XCTAssertEqual(segment[0].value.value.raw, "1")
        XCTAssertEqual(segment[1].value.value.raw, "NM")
        
        // OBX-3: Observation Identifier
        XCTAssertEqual(segment[2][0].value.raw, "8310-5")
        XCTAssertEqual(segment[2][1].value.raw, "Body Temperature")
        XCTAssertEqual(segment[2][2].value.raw, "LN")
        
        // OBX-5: Observation Value
        XCTAssertEqual(segment[4].value.value.raw, "36.5")
        
        // OBX-6: Units
        XCTAssertEqual(segment[5].value.value.raw, "Cel")
    }
    
    func testSegmentWithEmptyFields() throws {
        let segment = try BaseSegment.parse("PID||||||Smith")
        
        XCTAssertEqual(segment.segmentID, "PID")
        XCTAssertEqual(segment.fields.count, 6)
        XCTAssertTrue(segment[0].isEmpty)
        XCTAssertTrue(segment[4].isEmpty)
        XCTAssertEqual(segment[5].value.value.raw, "Smith")
    }
}
