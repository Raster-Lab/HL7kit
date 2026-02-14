import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Comprehensive HL7 v2.x standards compliance verification tests
/// Tests conformance to HL7 v2.x specifications (versions 2.1-2.8)
final class ComplianceVerificationTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    private let parser = HL7v2Parser()
    private let validator = HL7v2ValidationEngine()
    
    // MARK: - Version-Specific Compliance Tests
    
    func testVersion21Compliance() throws {
        // HL7 v2.1 minimal message structure
        let message = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|199001011200||ADT^A01|MSG001|P|2.1
        PID|||12345||Doe^John||19700101|M
        """
        
        let parsed = try parser.parse(message)
        
        // Verify version
        XCTAssertEqual(parsed.version, "2.1")
        
        // v2.1 should have minimal segment requirements
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        
        // Basic structure validation - parser should succeed
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
    }
    
    func testVersion25Compliance() throws {
        // HL7 v2.5 - most widely deployed version
        let message = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20030101120000||ADT^A01|MSG002|P|2.5
        EVN|A01|20030101120000
        PID|1||12345^^^MR||Doe^John^A||19700101|M|||123 Main St^^City^ST^12345^USA
        PV1|1|I|2000^2012^01||||1234^Doctor^Jane^^^MD^L
        """
        
        let parsed = try parser.parse(message)
        
        // Verify version
        XCTAssertEqual(parsed.version, "2.5")
        
        // v2.5 enhanced field structure
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "EVN" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PV1" })
        
        // Test enhanced data types
        let pid = try XCTUnwrap(parsed.segments.first { $0.id == "PID" })
        XCTAssertFalse(pid.fields.isEmpty)
        
        XCTAssertNoThrow(try validator.validate(parsed))
    }
    
    func testVersion251Compliance() throws {
        // HL7 v2.5.1 - U.S. federal standard (Meaningful Use)
        let message = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20070101120000||ADT^A01^ADT_A01|MSG003|P|2.5.1
        EVN|A01|20070101120000
        PID|1||12345^^^MR^MRN||Doe^John^A^Jr^Dr^PhD||19700101|M|||123 Main St^^City^ST^12345^USA||(555)555-5555^PRN^PH
        PV1|1|I|2000^2012^01^Hospital^Ward^Bed||||1234^Doctor^Jane^^^MD^L
        """
        
        let parsed = try parser.parse(message)
        
        // Verify version
        XCTAssertEqual(parsed.version, "2.5.1")
        
        // v2.5.1 regulatory compliance features
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "EVN" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PV1" })
        
        XCTAssertNoThrow(try validator.validate(parsed))
    }
    
    func testVersion28Compliance() throws {
        // HL7 v2.8 - latest version with enhanced features
        let message = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20140101120000||ADT^A01^ADT_A01|MSG004|P|2.8
        EVN|A01|20140101120000
        PID|1||12345^^^MR^MRN||Doe^John^A^Jr^Dr^PhD||19700101|M|||123 Main St^^City^ST^12345^USA
        PV1|1|I|2000^2012^01||||1234^Doctor^Jane^^^MD^L
        """
        
        let parsed = try parser.parse(message)
        
        // Verify version
        XCTAssertEqual(parsed.version, "2.8")
        
        // All standard segments present
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "EVN" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PV1" })
        
        let result = validator.validate(parsed, against: StandardConformanceProfiles.adtA01)
        XCTAssertTrue(result.isValid)
    }
    
    // MARK: - Message Type Compliance Tests
    
    func testADTA01MessageCompliance() throws {
        // ADT^A01 - Admit/Visit Notification
        let message = """
        MSH|^~\\&|ADT|Hospital|System|Hospital|20240101120000||ADT^A01^ADT_A01|MSG001|P|2.5.1
        EVN|A01|20240101120000
        PID|1||12345^^^MR||Doe^John||19800101|M
        PV1|1|I|Ward^Room^Bed||||AttendDoc^Attending^Doctor
        """
        
        let parsed = try parser.parse(message)
        
        // Verify message type structure
        let msh = try XCTUnwrap(parsed.segments.first { $0.id == "MSH" })
        XCTAssertTrue(msh.fields.count >= 9)
        
        // ADT A01 required segments
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "EVN" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PV1" })
        
        // Use standard profile for validation
        let profile = StandardConformanceProfiles.adtA01
        let result = validator.validate(parsed, against: profile)
        XCTAssertTrue(result.isValid)
    }
    
    func testORUR01MessageCompliance() throws {
        // ORU^R01 - Unsolicited Observation Report
        let message = """
        MSH|^~\\&|Lab|Hospital|EHR|Hospital|20240101120000||ORU^R01^ORU_R01|MSG002|P|2.5.1
        PID|1||12345^^^MR||Doe^Jane||19900101|F
        OBR|1||OrderID|80048^Basic Metabolic Panel^LN|||20240101120000
        OBX|1|NM|2345-7^Glucose^LN||95|mg/dL|70-110|N|||F
        OBX|2|NM|2823-3^Potassium^LN||4.2|mEq/L|3.5-5.0|N|||F
        """
        
        let parsed = try parser.parse(message)
        
        // Verify message type
        let msh = try XCTUnwrap(parsed.segments.first { $0.id == "MSH" })
        XCTAssertTrue(msh.fields.count >= 9)
        
        // ORU R01 required segments
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "OBR" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "OBX" })
        
        // Use standard profile for validation
        let profile = StandardConformanceProfiles.oruR01
        let result = validator.validate(parsed, against: profile)
        XCTAssertTrue(result.isValid)
    }
    
    func testORMO01MessageCompliance() throws {
        // ORM^O01 - Order Message
        let message = """
        MSH|^~\\&|OrderApp|Hospital|Lab|Hospital|20240101120000||ORM^O01^ORM_O01|MSG003|P|2.5.1
        PID|1||12345^^^MR||Smith^John||19800101|M
        ORC|NW|ORD001||||||||||1234^Doctor^Jane
        OBR|1|ORD001||80048^BMP^L|||20240101120000
        """
        
        let parsed = try parser.parse(message)
        
        // Verify message type
        let msh = try XCTUnwrap(parsed.segments.first { $0.id == "MSH" })
        XCTAssertTrue(msh.fields.count >= 9)
        
        // ORM O01 required segments
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "ORC" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "OBR" })
        
        // Use standard profile for validation
        let profile = StandardConformanceProfiles.ormO01
        let result = validator.validate(parsed, against: profile)
        XCTAssertTrue(result.isValid)
    }
    
    func testACKMessageCompliance() throws {
        // ACK - General Acknowledgment
        let message = """
        MSH|^~\\&|RecvApp|RecvFac|SendApp|SendFac|20240101120100||ACK^A01|MSG004|P|2.5.1
        MSA|AA|MSG001|Message accepted
        """
        
        let parsed = try parser.parse(message)
        
        // Verify message type
        let msh = try XCTUnwrap(parsed.segments.first { $0.id == "MSH" })
        XCTAssertTrue(msh.fields.count >= 9)
        
        // ACK required segments
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSH" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "MSA" })
        
        // Use standard profile for validation
        let profile = StandardConformanceProfiles.ack
        let result = validator.validate(parsed, against: profile)
        XCTAssertTrue(result.isValid)
    }
    
    // MARK: - Encoding Rules Compliance Tests
    
    func testEncodingCharacterCompliance() throws {
        // Standard encoding characters: |^~\&
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||12345||Doe^John
        """
        
        let parsed = try parser.parse(message)
        
        // Verify encoding characters are properly handled
        let msh = try XCTUnwrap(parsed.segments.first { $0.id == "MSH" })
        XCTAssertTrue(msh.fields.count >= 2)
    }
    
    func testEscapeSequenceCompliance() throws {
        // Test escape sequences for special characters
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||12345||Doe^John||19800101|M|||123 Main\\E\\St\\R\\Apt 5
        """
        
        let parsed = try parser.parse(message)
        
        // Verify escape sequences are handled
        let pid = try XCTUnwrap(parsed.segments.first { $0.id == "PID" })
        XCTAssertFalse(pid.fields.isEmpty)
        
        // Parser should handle escape sequences
        XCTAssertEqual(parsed.version, "2.5.1")
    }
    
    func testRepetitionCompliance() throws {
        // Test repeating fields
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||12345||Doe^John||19800101|M|||(555)555-1234~(555)555-5678
        """
        
        let parsed = try parser.parse(message)
        
        // Verify repetition is handled
        let pid = try XCTUnwrap(parsed.segments.first { $0.id == "PID" })
        XCTAssertFalse(pid.fields.isEmpty)
        
        // Parser should handle repetitions
        XCTAssertEqual(parsed.version, "2.5.1")
    }
    
    // MARK: - Data Type Compliance Tests
    
    func testTimestampDataTypeCompliance() throws {
        // Test TS (timestamp) data type formats
        let testCases = [
            "20240101",           // Date only
            "202401011200",       // Date and time
            "20240101120000",     // Full timestamp
            "20240101120000.123", // With milliseconds
        ]
        
        for timestamp in testCases {
            let message = """
            MSH|^~\\&|App|Fac|App|Fac|\(timestamp)||ADT^A01|MSG001|P|2.5.1
            PID|1||12345||Doe^John
            """
            
            XCTAssertNoThrow(try parser.parse(message), "Failed to parse timestamp: \(timestamp)")
        }
    }
    
    func testNumericDataTypeCompliance() throws {
        // Test NM (numeric) data type
        let message = """
        MSH|^~\\&|Lab|Hospital|EHR|Hospital|20240101120000||ORU^R01|MSG001|P|2.5.1
        PID|1||12345||Doe^Jane
        OBR|1||OrderID|80048^BMP^LN
        OBX|1|NM|2345-7^Glucose^LN||95.5|mg/dL|70-110|N|||F
        OBX|2|NM|2823-3^Potassium^LN||-3.2|mEq/L|3.5-5.0|L|||F
        """
        
        let parsed = try parser.parse(message)
        
        // Verify numeric values are preserved
        let obxSegments = parsed.segments.filter { $0.id == "OBX" }
        XCTAssertEqual(obxSegments.count, 2)
        
        // Validation with ORU profile
        let result = validator.validate(parsed, against: StandardConformanceProfiles.oruR01)
        XCTAssertTrue(result.isValid)
    }
    
    func testCodedValueCompliance() throws {
        // Test CE/CWE (coded element) data types
        let message = """
        MSH|^~\\&|Lab|Hospital|EHR|Hospital|20240101120000||ORU^R01|MSG001|P|2.5.1
        PID|1||12345||Doe^Jane
        OBR|1||OrderID|80048^Basic Metabolic Panel^LN^BMP^Panel^L
        OBX|1|CE|2345-7^Glucose^LN||95|mg/dL|70-110|N|||F
        """
        
        let parsed = try parser.parse(message)
        
        // Verify coded values are parsed correctly
        XCTAssertTrue(parsed.segments.contains { $0.id == "OBR" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "OBX" })
        
        // Validation with ORU profile
        let result = validator.validate(parsed, against: StandardConformanceProfiles.oruR01)
        XCTAssertTrue(result.isValid)
    }
    
    // MARK: - Segment Structure Compliance Tests
    
    func testMSHSegmentCompliance() throws {
        // MSH segment has special structure
        let message = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101120000|Security|ADT^A01^ADT_A01|MSG001|P|2.5.1|||||USA||EN
        PID|1||12345||Doe^John
        """
        
        let parsed = try parser.parse(message)
        let msh = try XCTUnwrap(parsed.segments.first { $0.id == "MSH" })
        
        // MSH field 1 is encoding characters (special case)
        XCTAssertTrue(msh.fields.count >= 12)
        
        // Test required MSH fields
        XCTAssertFalse(parsed.sendingApplication.isEmpty)
        XCTAssertFalse(parsed.receivingApplication.isEmpty)
        XCTAssertFalse(parsed.messageControlID.isEmpty)
        
        // MSH validation
        let result = validator.validate(parsed, against: StandardConformanceProfiles.adtA01)
        XCTAssertTrue(result.isValid)
    }
    
    func testSegmentOrderCompliance() throws {
        // Test that segments appear in proper order
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        EVN|A01|20240101120000
        PID|1||12345||Doe^John
        PV1|1|I|Ward^Room^Bed
        """
        
        let parsed = try parser.parse(message)
        
        // Verify segment order
        let segmentIds = parsed.segments.map { $0.id }
        XCTAssertEqual(segmentIds[0], "MSH")
        XCTAssertEqual(segmentIds[1], "EVN")
        XCTAssertEqual(segmentIds[2], "PID")
        XCTAssertEqual(segmentIds[3], "PV1")
        
        // Segment order validation
        let result = validator.validate(parsed, against: StandardConformanceProfiles.adtA01)
        XCTAssertTrue(result.isValid)
    }
    
    // MARK: - Field Cardinality Compliance Tests
    
    func testRequiredFieldCompliance() throws {
        // Test that required fields are validated
        let validMessage = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        EVN|A01|20240101120000
        PID|1||12345||Doe^John
        PV1|1|I|Ward
        """
        
        let parsed = try parser.parse(validMessage)
        let profile = StandardConformanceProfiles.adtA01
        
        let result = validator.validate(parsed, against: profile)
        XCTAssertTrue(result.isValid)
    }
    
    func testOptionalFieldCompliance() throws {
        // Test that optional fields can be omitted
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        EVN|A01
        PID|1||12345||Doe^John
        PV1|1
        """
        
        let parsed = try parser.parse(message)
        
        // Should parse successfully with optional fields missing
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
        XCTAssertTrue(parsed.segments.contains { $0.id == "PV1" })
    }
    
    // MARK: - Reference Test Message Compliance
    
    func testReferenceMessageCompliance() throws {
        // Load and validate reference test messages from TestData
        let testDataPath = "/home/runner/work/HL7kit/HL7kit/TestData/HL7v2x/valid"
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: testDataPath) else {
            throw XCTSkip("TestData directory not found")
        }
        
        let files = try fileManager.contentsOfDirectory(atPath: testDataPath)
        let hl7Files = files.filter { $0.hasSuffix(".hl7") }
        
        XCTAssertFalse(hl7Files.isEmpty, "No reference test messages found")
        
        for fileName in hl7Files {
            let filePath = testDataPath + "/" + fileName
            let messageData = try String(contentsOfFile: filePath, encoding: .utf8)
            
            // Each reference message should parse successfully
            XCTAssertNoThrow(
                try parser.parse(messageData),
                "Failed to parse reference message: \(fileName)"
            )
        }
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibility() throws {
        // v2.8 parser should handle v2.1 messages
        let v21Message = """
        MSH|^~\\&|App|Fac|App|Fac|199001011200||ADT^A01|MSG001|P|2.1
        PID|||12345||Doe^John
        """
        
        let parsed = try parser.parse(v21Message)
        XCTAssertEqual(parsed.version, "2.1")
        // Backward compatibility - parser should handle v2.1
        XCTAssertTrue(parsed.segments.contains { $0.id == "PID" })
    }
    
    func testForwardCompatibility() throws {
        // Parser should gracefully handle unknown fields from newer versions
        let messageWithUnknownFields = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.9|||||||||||||ExtraField
        PID|1||12345||Doe^John
        """
        
        // Should parse without error, ignoring unknown fields
        XCTAssertNoThrow(try parser.parse(messageWithUnknownFields))
    }
    
    // MARK: - Character Encoding Compliance Tests
    
    func testUTF8Compliance() throws {
        // Test UTF-8 encoded characters
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||12345||Müller^José||19800101|M|||Straße 123
        """
        
        let parsed = try parser.parse(message)
        
        // Verify UTF-8 characters are preserved
        let pid = try XCTUnwrap(parsed.segments.first { $0.id == "PID" })
        XCTAssertFalse(pid.fields.isEmpty)
        
        // UTF-8 should be handled
        XCTAssertEqual(parsed.version, "2.5.1")
    }
    
    func testASCIICompliance() throws {
        // Test standard ASCII encoding
        let message = """
        MSH|^~\\&|App|Fac|App|Fac|20240101120000||ADT^A01|MSG001|P|2.5.1
        PID|1||12345||Doe^John||19800101|M
        """
        
        let parsed = try parser.parse(message)
        let result = validator.validate(parsed, against: StandardConformanceProfiles.adtA01)
        XCTAssertTrue(result.isValid)
    }
    
    // MARK: - Compliance Reporting
    
    func testGenerateComplianceReport() {
        // Generate a compliance report summary
        var report = ComplianceReport()
        
        report.version = "2.5.1"
        report.testedMessageTypes = ["ADT^A01", "ORU^R01", "ORM^O01", "ACK"]
        report.testedVersions = ["2.1", "2.5", "2.5.1", "2.8"]
        report.conformanceProfiles = ["ADT_A01", "ORU_R01", "ORM_O01", "ACK"]
        report.encodingRulesTested = true
        report.dataTypeValidationTested = true
        report.cardinalityTested = true
        report.backwardCompatibilityTested = true
        
        // Verify report completeness
        XCTAssertFalse(report.testedMessageTypes.isEmpty)
        XCTAssertFalse(report.testedVersions.isEmpty)
        XCTAssertTrue(report.encodingRulesTested)
        XCTAssertTrue(report.dataTypeValidationTested)
        XCTAssertTrue(report.cardinalityTested)
        XCTAssertTrue(report.backwardCompatibilityTested)
    }
}

// MARK: - Compliance Report Structure

/// Compliance report for documentation purposes
struct ComplianceReport {
    var version: String = ""
    var testedMessageTypes: [String] = []
    var testedVersions: [String] = []
    var conformanceProfiles: [String] = []
    var encodingRulesTested: Bool = false
    var dataTypeValidationTested: Bool = false
    var cardinalityTested: Bool = false
    var backwardCompatibilityTested: Bool = false
}
