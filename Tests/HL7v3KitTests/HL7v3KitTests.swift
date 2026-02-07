import XCTest
@testable import HL7v3Kit
@testable import HL7Core

/// Tests for HL7v3Kit module
final class HL7v3KitTests: XCTestCase {
    
    // MARK: - Version Tests
    
    func testVersionInformation() {
        XCTAssertEqual(HL7v3KitVersion.version, "0.1.0")
    }
    
    // MARK: - Message Creation Tests
    
    func testMessageCreation() {
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
        </ClinicalDocument>
        """
        
        let message = HL7v3Message(
            messageID: "DOC001",
            timestamp: Date(),
            xmlData: xmlString.data(using: .utf8)!
        )
        
        XCTAssertEqual(message.messageID, "DOC001")
        XCTAssertFalse(message.xmlData.isEmpty)
    }
    
    func testMessageTimestamp() {
        let timestamp = Date()
        let xmlData = "<test/>".data(using: .utf8)!
        
        let message = HL7v3Message(
            messageID: "DOC001",
            timestamp: timestamp,
            xmlData: xmlData
        )
        
        XCTAssertEqual(message.timestamp, timestamp)
    }
    
    // MARK: - Message Validation Tests
    
    func testValidMessageValidation() throws {
        let xmlData = "<ClinicalDocument><typeId/></ClinicalDocument>".data(using: .utf8)!
        
        let message = HL7v3Message(
            messageID: "DOC001",
            xmlData: xmlData
        )
        
        XCTAssertNoThrow(try message.validate())
    }
    
    func testEmptyMessageValidation() {
        let message = HL7v3Message(
            messageID: "DOC001",
            xmlData: Data()
        )
        
        XCTAssertThrowsError(try message.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    // MARK: - XML Structure Tests
    
    func testXMLDataParsing() throws {
        let xmlString = """
        <?xml version="1.0"?>
        <root>
            <element>value</element>
        </root>
        """
        
        let message = HL7v3Message(
            messageID: "DOC001",
            xmlData: xmlString.data(using: .utf8)!
        )
        
        let xmlString2 = String(data: message.xmlData, encoding: .utf8)
        XCTAssertNotNil(xmlString2)
        XCTAssertTrue(xmlString2!.contains("<root>"))
    }
    
    func testCDADocumentStructure() {
        let cdaXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
            <id root="1.2.3.4.5" extension="12345"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Document</title>
        </ClinicalDocument>
        """
        
        let message = HL7v3Message(
            messageID: "CDA001",
            xmlData: cdaXML.data(using: .utf8)!
        )
        
        XCTAssertNotNil(message.xmlData)
        let xmlContent = String(data: message.xmlData, encoding: .utf8)
        XCTAssertTrue(xmlContent?.contains("ClinicalDocument") ?? false)
    }
    
    // MARK: - Multiple Message Tests
    
    func testMultipleMessageCreation() {
        let messages = (1...10).map { i in
            HL7v3Message(
                messageID: "DOC\(String(format: "%03d", i))",
                xmlData: "<document id=\"\(i)\"/>".data(using: .utf8)!
            )
        }
        
        XCTAssertEqual(messages.count, 10)
        XCTAssertEqual(messages.first?.messageID, "DOC001")
        XCTAssertEqual(messages.last?.messageID, "DOC010")
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testSendableConformance() async {
        let xmlData = "<test/>".data(using: .utf8)!
        let message = HL7v3Message(
            messageID: "DOC001",
            xmlData: xmlData
        )
        
        await Task {
            XCTAssertEqual(message.messageID, "DOC001")
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testMessageCreationPerformance() {
        let xmlData = "<ClinicalDocument><content/></ClinicalDocument>".data(using: .utf8)!
        
        measure {
            for i in 0..<1000 {
                _ = HL7v3Message(
                    messageID: "DOC\(i)",
                    xmlData: xmlData
                )
            }
        }
    }
    
    func testMessageValidationPerformance() throws {
        let xmlData = "<ClinicalDocument><content/></ClinicalDocument>".data(using: .utf8)!
        let message = HL7v3Message(
            messageID: "DOC001",
            xmlData: xmlData
        )
        
        measure {
            for _ in 0..<1000 {
                try? message.validate()
            }
        }
    }
}
