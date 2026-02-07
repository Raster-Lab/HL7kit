import XCTest
@testable import HL7Core

/// Tests for HL7Core module
final class HL7CoreTests: XCTestCase {
    
    // MARK: - Version Tests
    
    func testVersionInformation() {
        XCTAssertEqual(HL7CoreVersion.version, "0.1.0")
        XCTAssertEqual(HL7CoreVersion.swiftVersion, "6.0")
    }
    
    // MARK: - Error Tests
    
    func testHL7ErrorCases() {
        let errors: [HL7Error] = [
            .invalidFormat("test"),
            .missingRequiredField("field"),
            .invalidDataType("type"),
            .parsingError("parse"),
            .validationError("validation"),
            .networkError("network"),
            .unknown("unknown")
        ]
        
        XCTAssertEqual(errors.count, 7)
    }
    
    func testHL7ErrorDescription() {
        let error = HL7Error.invalidFormat("Invalid HL7 message")
        XCTAssertNotNil(error)
    }
    
    // MARK: - Logging Tests
    
    func testLoggerSetLevel() async {
        let logger = HL7Logger.shared
        await logger.setLogLevel(.debug)
        await logger.log(.debug, "Debug message")
        await logger.log(.info, "Info message")
        await logger.log(.warning, "Warning message")
        await logger.log(.error, "Error message")
    }
    
    func testLogLevelOrdering() {
        XCTAssertLessThan(HL7LogLevel.debug.rawValue, HL7LogLevel.info.rawValue)
        XCTAssertLessThan(HL7LogLevel.info.rawValue, HL7LogLevel.warning.rawValue)
        XCTAssertLessThan(HL7LogLevel.warning.rawValue, HL7LogLevel.error.rawValue)
    }
    
    // MARK: - Mock Message Tests
    
    struct MockHL7Message: HL7Message {
        let messageID: String
        let timestamp: Date
        
        func validate() throws {
            if messageID.isEmpty {
                throw HL7Error.validationError("Empty message ID")
            }
        }
    }
    
    func testMockMessageValidation() throws {
        let validMessage = MockHL7Message(messageID: "MSG001", timestamp: Date())
        XCTAssertNoThrow(try validMessage.validate())
        
        let invalidMessage = MockHL7Message(messageID: "", timestamp: Date())
        XCTAssertThrowsError(try invalidMessage.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testMessageTimestamp() {
        let timestamp = Date()
        let message = MockHL7Message(messageID: "MSG001", timestamp: timestamp)
        XCTAssertEqual(message.timestamp, timestamp)
    }
    
    func testMessageIDUniqueness() {
        let message1 = MockHL7Message(messageID: "MSG001", timestamp: Date())
        let message2 = MockHL7Message(messageID: "MSG002", timestamp: Date())
        XCTAssertNotEqual(message1.messageID, message2.messageID)
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() async {
        let message = MockHL7Message(messageID: "MSG001", timestamp: Date())
        
        await Task {
            XCTAssertEqual(message.messageID, "MSG001")
        }.value
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorThrowingAndCatching() {
        do {
            throw HL7Error.parsingError("Parse failed")
        } catch let error as HL7Error {
            if case .parsingError(let message) = error {
                XCTAssertEqual(message, "Parse failed")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }
}
