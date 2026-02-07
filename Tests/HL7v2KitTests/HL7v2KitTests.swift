import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for HL7v2Kit module
final class HL7v2KitTests: XCTestCase {
    
    // MARK: - Version Tests
    
    func testVersionInformation() {
        XCTAssertEqual(HL7v2KitVersion.version, "0.1.0")
    }
    
    // MARK: - Message Creation Tests
    
    func testMessageCreation() {
        let message = HL7v2Message(
            messageID: "MSG001",
            timestamp: Date(),
            rawData: "MSH|^~\\&|SYSTEM1|FACILITY1|SYSTEM2|FACILITY2|20240101120000||ADT^A01|MSG001|P|2.5"
        )
        
        XCTAssertEqual(message.messageID, "MSG001")
        XCTAssertFalse(message.rawData.isEmpty)
    }
    
    func testMessageTimestamp() {
        let timestamp = Date()
        let message = HL7v2Message(
            messageID: "MSG001",
            timestamp: timestamp,
            rawData: "MSH|^~\\&|TEST"
        )
        
        XCTAssertEqual(message.timestamp, timestamp)
    }
    
    // MARK: - Message Validation Tests
    
    func testValidMessageValidation() throws {
        let message = HL7v2Message(
            messageID: "MSG001",
            rawData: "MSH|^~\\&|SYSTEM1|FACILITY1|SYSTEM2|FACILITY2|20240101120000||ADT^A01|MSG001|P|2.5"
        )
        
        XCTAssertNoThrow(try message.validate())
    }
    
    func testEmptyMessageValidation() {
        let message = HL7v2Message(
            messageID: "MSG001",
            rawData: ""
        )
        
        XCTAssertThrowsError(try message.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    // MARK: - Message Structure Tests
    
    func testMSHSegmentPresence() {
        let message = HL7v2Message(
            messageID: "MSG001",
            rawData: "MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20240101120000||ADT^A01|MSG001|P|2.5"
        )
        
        XCTAssertTrue(message.rawData.hasPrefix("MSH"))
    }
    
    func testMessageDelimiters() {
        let message = HL7v2Message(
            messageID: "MSG001",
            rawData: "MSH|^~\\&|TEST"
        )
        
        XCTAssertTrue(message.rawData.contains("|"))
        XCTAssertTrue(message.rawData.contains("^"))
    }
    
    // MARK: - Multiple Message Tests
    
    func testMultipleMessageCreation() {
        let messages = (1...10).map { i in
            HL7v2Message(
                messageID: "MSG\(String(format: "%03d", i))",
                rawData: "MSH|^~\\&|SYS|FAC|SYS2|FAC2|20240101120000||ADT^A01|MSG\(String(format: "%03d", i))|P|2.5"
            )
        }
        
        XCTAssertEqual(messages.count, 10)
        XCTAssertEqual(messages.first?.messageID, "MSG001")
        XCTAssertEqual(messages.last?.messageID, "MSG010")
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() async {
        let message = HL7v2Message(
            messageID: "MSG001",
            rawData: "MSH|^~\\&|TEST"
        )
        
        await Task {
            XCTAssertEqual(message.messageID, "MSG001")
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testMessageCreationPerformance() {
        measure {
            for i in 0..<1000 {
                _ = HL7v2Message(
                    messageID: "MSG\(i)",
                    rawData: "MSH|^~\\&|TEST|FAC|TEST2|FAC2|20240101120000||ADT^A01|MSG\(i)|P|2.5"
                )
            }
        }
    }
    
    func testMessageValidationPerformance() throws {
        let message = HL7v2Message(
            messageID: "MSG001",
            rawData: "MSH|^~\\&|TEST|FAC|TEST2|FAC2|20240101120000||ADT^A01|MSG001|P|2.5"
        )
        
        measure {
            for _ in 0..<1000 {
                try? message.validate()
            }
        }
    }
}
