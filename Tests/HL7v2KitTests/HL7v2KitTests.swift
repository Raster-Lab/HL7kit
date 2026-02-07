import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for HL7v2Kit module
final class HL7v2KitTests: XCTestCase {
    
    // MARK: - Version Tests
    
    func testVersionInformation() {
        XCTAssertEqual(HL7v2KitVersion.version, "0.1.0")
    }
    
    // MARK: - Message Parsing Tests
    
    func testMessageParsing() throws {
        let rawMessage = "MSH|^~\\&|SYSTEM1|FACILITY1|SYSTEM2|FACILITY2|20240101120000||ADT^A01|MSG001|P|2.5"
        let message = try HL7v2Message.parse(rawMessage)
        
        XCTAssertEqual(message.messageControlID(), "MSG001")
        XCTAssertEqual(message.messageType(), "ADT^A01")
        XCTAssertEqual(message.version(), "2.5")
    }
    
    func testMessageSegmentAccess() throws {
        let rawMessage = "MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20240101120000||ADT^A01|MSG001|P|2.5"
        let message = try HL7v2Message.parse(rawMessage)
        
        XCTAssertEqual(message.messageHeader.segmentID, "MSH")
        XCTAssertEqual(message.messageHeader[2].value.value.raw, "SENDING_APP")
    }
    
    // MARK: - Message Validation Tests
    
    func testValidMessageValidation() throws {
        let rawMessage = "MSH|^~\\&|SYSTEM1|FACILITY1|SYSTEM2|FACILITY2|20240101120000||ADT^A01|MSG001|P|2.5"
        let message = try HL7v2Message.parse(rawMessage)
        
        XCTAssertNoThrow(try message.validate())
    }
    
    // MARK: - Multiple Message Tests
    
    func testMultipleMessageParsing() throws {
        let messages = try (1...10).map { i in
            let raw = "MSH|^~\\&|SYS|FAC|SYS2|FAC2|20240101120000||ADT^A01|MSG\(String(format: "%03d", i))|P|2.5"
            return try HL7v2Message.parse(raw)
        }
        
        XCTAssertEqual(messages.count, 10)
        XCTAssertEqual(messages.first?.messageControlID(), "MSG001")
        XCTAssertEqual(messages.last?.messageControlID(), "MSG010")
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() async throws {
        let rawMessage = "MSH|^~\\&|TEST|FAC|TEST2|FAC2|20240101120000||ADT^A01|MSG001|P|2.5"
        let message = try HL7v2Message.parse(rawMessage)
        
        await Task {
            XCTAssertEqual(message.messageControlID(), "MSG001")
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testMessageParsingPerformance() {
        let rawMessage = "MSH|^~\\&|TEST|FAC|TEST2|FAC2|20240101120000||ADT^A01|MSG001|P|2.5"
        
        measure {
            for _ in 0..<1000 {
                _ = try? HL7v2Message.parse(rawMessage)
            }
        }
    }
    
    func testMessageValidationPerformance() throws {
        let rawMessage = "MSH|^~\\&|TEST|FAC|TEST2|FAC2|20240101120000||ADT^A01|MSG001|P|2.5"
        let message = try HL7v2Message.parse(rawMessage)
        
        measure {
            for _ in 0..<1000 {
                try? message.validate()
            }
        }
    }
}
