import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for HL7v2Message container
final class MessageTests: XCTestCase {
    
    // Sample ADT message for testing
    let sampleADT = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240207120000||ADT^A01|MSG001|P|2.5.1\r" +
        "EVN|A01|20240207120000|||USER01\r" +
        "PID|1||12345^^^Hospital^MR||Smith^John^A||19800101|M|||123 Main St^^Boston^MA^02101\r" +
        "PV1|1|I|4E^401^B^Hospital||||1234^Doctor^Jane|||SUR||||1|||1234^Doctor^Jane||Visit001"
    
    // Sample ORU message for testing
    let sampleORU = "MSH|^~\\&|Lab|LabFac|EMR|Hospital|20240207120000||ORU^R01|MSG002|P|2.5.1\r" +
        "PID|1||67890^^^Hospital^MR||Jones^Jane^B||19850615|F\r" +
        "OBR|1||LAB123|CBC^Complete Blood Count|||20240207120000\r" +
        "OBX|1|NM|WBC^White Blood Count||7.5|10*3/uL|4.5-11.0|N|||F\r" +
        "OBX|2|NM|RBC^Red Blood Count||4.8|10*6/uL|4.2-5.4|N|||F"
    
    // MARK: - Basic Message Tests
    
    func testParseSimpleMessage() throws {
        let message = try HL7v2Message.parse(sampleADT)
        
        XCTAssertEqual(message.segmentCount, 4)
        XCTAssertEqual(message.messageHeader.segmentID, "MSH")
    }
    
    func testMessageEncodingCharacters() throws {
        let message = try HL7v2Message.parse(sampleADT)
        
        XCTAssertEqual(message.encodingCharacters.fieldSeparator, "|")
        XCTAssertEqual(message.encodingCharacters.componentSeparator, "^")
        XCTAssertEqual(message.encodingCharacters.repetitionSeparator, "~")
        XCTAssertEqual(message.encodingCharacters.escapeCharacter, "\\")
        XCTAssertEqual(message.encodingCharacters.subcomponentSeparator, "&")
    }
    
    func testMessageHeader() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let msh = message.messageHeader
        
        XCTAssertEqual(msh.segmentID, "MSH")
        XCTAssertEqual(msh[2].value.value.raw, "SendApp")
        XCTAssertEqual(msh[3].value.value.raw, "SendFac")
    }
    
    func testMessageType() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let messageType = message.messageType()
        
        XCTAssertEqual(messageType, "ADT^A01")
    }
    
    func testMessageControlID() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let controlID = message.messageControlID()
        
        XCTAssertEqual(controlID, "MSG001")
    }
    
    func testMessageVersion() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let version = message.version()
        
        XCTAssertEqual(version, "2.5.1")
    }
    
    // MARK: - Segment Access Tests
    
    func testSegmentAccessByIndex() throws {
        let message = try HL7v2Message.parse(sampleADT)
        
        XCTAssertEqual(message[0]?.segmentID, "MSH")
        XCTAssertEqual(message[1]?.segmentID, "EVN")
        XCTAssertEqual(message[2]?.segmentID, "PID")
        XCTAssertEqual(message[3]?.segmentID, "PV1")
        XCTAssertNil(message[10])
    }
    
    func testSegmentsByID() throws {
        let message = try HL7v2Message.parse(sampleORU)
        
        let obxSegments = message.segments(withID: "OBX")
        XCTAssertEqual(obxSegments.count, 2)
        XCTAssertEqual(obxSegments[0][0].value.value.raw, "1")
        XCTAssertEqual(obxSegments[1][0].value.value.raw, "2")
    }
    
    func testAllSegments() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let allSegments = message.allSegments
        
        XCTAssertEqual(allSegments.count, 4)
        XCTAssertEqual(allSegments[0].segmentID, "MSH")
        XCTAssertEqual(allSegments[1].segmentID, "EVN")
        XCTAssertEqual(allSegments[2].segmentID, "PID")
        XCTAssertEqual(allSegments[3].segmentID, "PV1")
    }
    
    // MARK: - Serialization Tests
    
    func testSerializeMessage() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let serialized = try message.serialize()
        
        // Parse the serialized message to verify it's valid
        let reparsed = try HL7v2Message.parse(serialized)
        XCTAssertEqual(reparsed.segmentCount, message.segmentCount)
        XCTAssertEqual(reparsed.messageType(), message.messageType())
    }
    
    func testSerializePreservesData() throws {
        let message = try HL7v2Message.parse(sampleORU)
        let serialized = try message.serialize()
        let reparsed = try HL7v2Message.parse(serialized)
        
        // Check that OBX segments are preserved
        let originalOBX = message.segments(withID: "OBX")
        let reparsedOBX = reparsed.segments(withID: "OBX")
        
        XCTAssertEqual(originalOBX.count, reparsedOBX.count)
        XCTAssertEqual(originalOBX[0][1].value.value.raw, reparsedOBX[0][1].value.value.raw)
    }
    
    // MARK: - Validation Tests
    
    func testValidateValidMessage() throws {
        let message = try HL7v2Message.parse(sampleADT)
        XCTAssertNoThrow(try message.validate())
    }
    
    func testValidateEmptyMessage() throws {
        // Create message with MSH only to test empty validation
        let msh = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240207120000||ADT^A01|MSG001|P|2.5.1"
        let message = try HL7v2Message.parse(msh)
        
        // Should be valid even with just MSH
        XCTAssertNoThrow(try message.validate())
    }
    
    // MARK: - Error Cases
    
    func testParseEmptyMessage() {
        XCTAssertThrowsError(try HL7v2Message.parse("")) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Empty message"))
        }
    }
    
    func testParseMessageWithoutMSH() {
        let noMSH = "PID|1||12345^^^Hospital^MR"
        
        XCTAssertThrowsError(try HL7v2Message.parse(noMSH)) { error in
            guard case HL7Error.parsingError(let message, _) = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("start with MSH"))
        }
    }
    
    func testInitWithoutMSH() {
        let pidSegment = try! BaseSegment.parse("PID|1||12345")
        
        XCTAssertThrowsError(try HL7v2Message(segments: [pidSegment])) { error in
            guard case HL7Error.validationError(let message, _) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("start with MSH"))
        }
    }
    
    // MARK: - Complex Message Tests
    
    func testParseORUMessage() throws {
        let message = try HL7v2Message.parse(sampleORU)
        
        XCTAssertEqual(message.segmentCount, 5)
        XCTAssertEqual(message.messageType(), "ORU^R01")
        
        let obxSegments = message.segments(withID: "OBX")
        XCTAssertEqual(obxSegments.count, 2)
        
        // Check first OBX
        let obx1 = obxSegments[0]
        XCTAssertEqual(obx1[2][0].value.raw, "WBC")
        XCTAssertEqual(obx1[4].value.value.raw, "7.5")
        XCTAssertEqual(obx1[5].value.value.raw, "10*3/uL")
        
        // Check second OBX
        let obx2 = obxSegments[1]
        XCTAssertEqual(obx2[2][0].value.raw, "RBC")
        XCTAssertEqual(obx2[4].value.value.raw, "4.8")
    }
    
    func testParsePIDSegmentDetails() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let pidSegments = message.segments(withID: "PID")
        
        XCTAssertEqual(pidSegments.count, 1)
        
        let pid = pidSegments[0]
        
        // PID-3: Patient ID
        XCTAssertEqual(pid[2][0].value.raw, "12345")
        XCTAssertEqual(pid[2][3].value.raw, "Hospital")
        XCTAssertEqual(pid[2][4].value.raw, "MR")
        
        // PID-5: Patient Name
        XCTAssertEqual(pid[4][0].value.raw, "Smith")
        XCTAssertEqual(pid[4][1].value.raw, "John")
        XCTAssertEqual(pid[4][2].value.raw, "A")
        
        // PID-7: Date of Birth
        XCTAssertEqual(pid[6].value.value.raw, "19800101")
        
        // PID-8: Sex
        XCTAssertEqual(pid[7].value.value.raw, "M")
        
        // PID-11: Address
        XCTAssertEqual(pid[10][0].value.raw, "123 Main St")
        XCTAssertEqual(pid[10][2].value.raw, "Boston")
        XCTAssertEqual(pid[10][3].value.raw, "MA")
        XCTAssertEqual(pid[10][4].value.raw, "02101")
    }
    
    // MARK: - Equatable Tests
    
    func testMessageEquatable() throws {
        let message1 = try HL7v2Message.parse(sampleADT)
        let message2 = try HL7v2Message.parse(sampleADT)
        let message3 = try HL7v2Message.parse(sampleORU)
        
        XCTAssertEqual(message1, message2)
        XCTAssertNotEqual(message1, message3)
    }
    
    // MARK: - Description Tests
    
    func testMessageDescription() throws {
        let message = try HL7v2Message.parse(sampleADT)
        let description = message.description
        
        XCTAssertTrue(description.contains("MSH"))
        XCTAssertTrue(description.contains("PID"))
    }
    
    // MARK: - HL7Message Protocol Tests
    
    func testHL7MessageProtocolCompliance() throws {
        let message = try HL7v2Message.parse(sampleADT)
        
        XCTAssertEqual(message.messageID, "MSG001")
        XCTAssertFalse(message.rawData.isEmpty)
    }
}
