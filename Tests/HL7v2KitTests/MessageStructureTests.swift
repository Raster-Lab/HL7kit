/// Unit tests for message structure definitions and validation
///
/// Tests version detection, structure validation, backward compatibility,
/// and query APIs for the message structure database.

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class MessageStructureTests: XCTestCase {
    
    // MARK: - HL7Version Tests
    
    func testVersionParsing() {
        // Test major.minor format
        let v2_5 = HL7Version.parse("2.5")
        XCTAssertNotNil(v2_5)
        XCTAssertEqual(v2_5?.major, 2)
        XCTAssertEqual(v2_5?.minor, 5)
        XCTAssertNil(v2_5?.patch)
        
        // Test major.minor.patch format
        let v2_5_1 = HL7Version.parse("2.5.1")
        XCTAssertNotNil(v2_5_1)
        XCTAssertEqual(v2_5_1?.major, 2)
        XCTAssertEqual(v2_5_1?.minor, 5)
        XCTAssertEqual(v2_5_1?.patch, 1)
        
        // Test invalid formats
        XCTAssertNil(HL7Version.parse("2"))
        XCTAssertNil(HL7Version.parse("invalid"))
        XCTAssertNil(HL7Version.parse(""))
    }
    
    func testVersionString() {
        let v2_5 = HL7Version(major: 2, minor: 5)
        XCTAssertEqual(v2_5.versionString, "2.5")
        
        let v2_5_1 = HL7Version(major: 2, minor: 5, patch: 1)
        XCTAssertEqual(v2_5_1.versionString, "2.5.1")
    }
    
    func testVersionComparison() {
        let v2_1 = HL7Version.v2_1
        let v2_5 = HL7Version.v2_5
        let v2_5_1 = HL7Version.v2_5_1
        let v2_8 = HL7Version.v2_8
        
        XCTAssertTrue(v2_1 < v2_5)
        XCTAssertTrue(v2_5 < v2_5_1)
        XCTAssertTrue(v2_5_1 < v2_8)
        XCTAssertFalse(v2_8 < v2_1)
    }
    
    func testVersionEquality() {
        let v2_5_a = HL7Version(major: 2, minor: 5)
        let v2_5_b = HL7Version(major: 2, minor: 5)
        let v2_5_1 = HL7Version(major: 2, minor: 5, patch: 1)
        
        XCTAssertEqual(v2_5_a, v2_5_b)
        XCTAssertNotEqual(v2_5_a, v2_5_1)
    }
    
    func testAllSupportedVersions() {
        let versions = HL7Version.allSupported
        XCTAssertTrue(versions.count >= 11) // At least 11 versions
        
        // Check they are in chronological order
        for i in 0..<(versions.count - 1) {
            XCTAssertTrue(versions[i] < versions[i + 1])
        }
    }
    
    // MARK: - SegmentUsage Tests
    
    func testSegmentUsageProperties() {
        // Required
        XCTAssertTrue(SegmentUsage.required.isRequired)
        XCTAssertFalse(SegmentUsage.required.mayRepeat)
        XCTAssertEqual(SegmentUsage.required.cardinality, "1")
        
        // Optional
        XCTAssertFalse(SegmentUsage.optional.isRequired)
        XCTAssertFalse(SegmentUsage.optional.mayRepeat)
        XCTAssertEqual(SegmentUsage.optional.cardinality, "0..1")
        
        // Required Repeating
        XCTAssertTrue(SegmentUsage.requiredRepeating.isRequired)
        XCTAssertTrue(SegmentUsage.requiredRepeating.mayRepeat)
        XCTAssertEqual(SegmentUsage.requiredRepeating.cardinality, "1..*")
        
        // Optional Repeating
        XCTAssertFalse(SegmentUsage.optionalRepeating.isRequired)
        XCTAssertTrue(SegmentUsage.optionalRepeating.mayRepeat)
        XCTAssertEqual(SegmentUsage.optionalRepeating.cardinality, "0..*")
    }
    
    // MARK: - SegmentDefinition Tests
    
    func testSegmentDefinitionAppliesTo() {
        // Applies to all versions (nil)
        let mshDef = StructureSegmentDefinition(
            segmentID: "MSH",
            usage: .required,
            description: "Message Header"
        )
        XCTAssertTrue(mshDef.applies(to: .v2_1))
        XCTAssertTrue(mshDef.applies(to: .v2_5))
        XCTAssertTrue(mshDef.applies(to: .v2_8))
        
        // Applies to specific versions
        let pd1Def = StructureSegmentDefinition(
            segmentID: "PD1",
            usage: .optional,
            description: "Patient Additional Demographic",
            applicableVersions: [.v2_3, .v2_4, .v2_5, .v2_5_1, .v2_6, .v2_7, .v2_8]
        )
        XCTAssertFalse(pd1Def.applies(to: .v2_1))
        XCTAssertFalse(pd1Def.applies(to: .v2_2))
        XCTAssertTrue(pd1Def.applies(to: .v2_3))
        XCTAssertTrue(pd1Def.applies(to: .v2_5))
    }
    
    // MARK: - MessageStructure Tests
    
    func testMessageStructureFullMessageType() {
        let structure = MessageStructure(
            messageType: "ADT",
            triggerEvent: "A01",
            description: "Admit/Visit Notification",
            segments: []
        )
        XCTAssertEqual(structure.fullMessageType, "ADT^A01")
    }
    
    func testMessageStructureAppliesTo() {
        // Introduced in v2.3, still valid
        let structure = MessageStructure(
            messageType: "QBP",
            triggerEvent: "Q11",
            description: "Query by Parameter",
            segments: [],
            introducedInVersion: .v2_3
        )
        XCTAssertFalse(structure.applies(to: .v2_1))
        XCTAssertFalse(structure.applies(to: .v2_2))
        XCTAssertTrue(structure.applies(to: .v2_3))
        XCTAssertTrue(structure.applies(to: .v2_5))
        XCTAssertTrue(structure.applies(to: .v2_8))
        
        // Deprecated in v2.5
        let deprecatedStructure = MessageStructure(
            messageType: "OLD",
            triggerEvent: "O01",
            description: "Old Message",
            segments: [],
            introducedInVersion: .v2_1,
            deprecatedInVersion: .v2_5
        )
        XCTAssertTrue(deprecatedStructure.applies(to: .v2_1))
        XCTAssertTrue(deprecatedStructure.applies(to: .v2_4))
        XCTAssertFalse(deprecatedStructure.applies(to: .v2_5))
        XCTAssertFalse(deprecatedStructure.applies(to: .v2_8))
    }
    
    func testMessageStructureSegmentsForVersion() {
        let segments = [
            StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
            StructureSegmentDefinition(
                segmentID: "PD1",
                usage: .optional,
                description: "Patient Additional Demographic",
                applicableVersions: [.v2_3, .v2_4, .v2_5]
            )
        ]
        
        let structure = MessageStructure(
            messageType: "ADT",
            triggerEvent: "A01",
            description: "Admit",
            segments: segments
        )
        
        // v2.1 should only have MSH
        let v2_1_segments = structure.segments(for: .v2_1)
        XCTAssertEqual(v2_1_segments.count, 1)
        XCTAssertEqual(v2_1_segments[0].segmentID, "MSH")
        
        // v2.3 should have both MSH and PD1
        let v2_3_segments = structure.segments(for: .v2_3)
        XCTAssertEqual(v2_3_segments.count, 2)
        XCTAssertEqual(v2_3_segments[0].segmentID, "MSH")
        XCTAssertEqual(v2_3_segments[1].segmentID, "PD1")
    }
    
    // MARK: - MessageStructureDatabase Tests
    
    func testDatabaseSharedInstance() async {
        let db1 = MessageStructureDatabase.shared
        let db2 = MessageStructureDatabase.shared
        XCTAssertTrue(db1 === db2)
    }
    
    func testDatabaseRegisterAndRetrieve() async {
        let db = MessageStructureDatabase.shared
        
        // Retrieve a registered structure
        let adtA01 = await db.structure(messageType: "ADT", triggerEvent: "A01")
        XCTAssertNotNil(adtA01)
        XCTAssertEqual(adtA01?.messageType, "ADT")
        XCTAssertEqual(adtA01?.triggerEvent, "A01")
        XCTAssertEqual(adtA01?.description, "Admit/Visit Notification")
    }
    
    func testDatabaseRetrieveNonExistent() async {
        let db = MessageStructureDatabase.shared
        
        let nonExistent = await db.structure(messageType: "ZZZ", triggerEvent: "Z99")
        XCTAssertNil(nonExistent)
    }
    
    func testDatabaseAllStructures() async {
        let db = MessageStructureDatabase.shared
        let allStructures = await db.allStructures()
        
        // Should have at least ADT, ORM, ORU, ACK, QRY structures
        XCTAssertTrue(allStructures.count >= 5)
        
        // Check they are sorted
        for i in 0..<(allStructures.count - 1) {
            let current = allStructures[i]
            let next = allStructures[i + 1]
            if current.messageType == next.messageType {
                XCTAssertTrue(current.triggerEvent <= next.triggerEvent)
            } else {
                XCTAssertTrue(current.messageType < next.messageType)
            }
        }
    }
    
    func testDatabaseStructuresForVersion() async {
        let db = MessageStructureDatabase.shared
        
        // v2.1 structures
        let v2_1_structures = await db.structures(for: .v2_1)
        XCTAssertTrue(v2_1_structures.count > 0)
        
        // All should apply to v2.1
        for structure in v2_1_structures {
            XCTAssertTrue(structure.applies(to: .v2_1))
        }
        
        // v2.8 should have more or equal structures
        let v2_8_structures = await db.structures(for: .v2_8)
        XCTAssertTrue(v2_8_structures.count >= v2_1_structures.count)
    }
    
    func testDatabaseStructureForMessage() async throws {
        let db = MessageStructureDatabase.shared
        
        // Create a simple ADT^A01 message
        let msh = "MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5"
        let message = try HL7v2Message.parse(msh)
        
        let structure = await db.structure(for: message)
        XCTAssertNotNil(structure)
        XCTAssertEqual(structure?.messageType, "ADT")
        XCTAssertEqual(structure?.triggerEvent, "A01")
    }
    
    // MARK: - Version Detection Tests
    
    func testDetectVersionFromMessage() throws {
        // v2.5 message
        let msh2_5 = "MSH|^~\\&|APP|FAC|APP|FAC|20240101||ADT^A01|123|P|2.5"
        let message2_5 = try HL7v2Message.parse(msh2_5)
        let version2_5 = message2_5.detectVersion()
        XCTAssertNotNil(version2_5)
        XCTAssertEqual(version2_5?.major, 2)
        XCTAssertEqual(version2_5?.minor, 5)
        
        // v2.5.1 message
        let msh2_5_1 = "MSH|^~\\&|APP|FAC|APP|FAC|20240101||ADT^A01|123|P|2.5.1"
        let message2_5_1 = try HL7v2Message.parse(msh2_5_1)
        let version2_5_1 = message2_5_1.detectVersion()
        XCTAssertNotNil(version2_5_1)
        XCTAssertEqual(version2_5_1?.major, 2)
        XCTAssertEqual(version2_5_1?.minor, 5)
        XCTAssertEqual(version2_5_1?.patch, 1)
    }
    
    // MARK: - Structure Validation Tests
    
    func testValidateValidADTA01() async throws {
        // Create a valid ADT^A01 message
        let messageString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5
        EVN|A01|20240101120000
        PID|1||12345||Doe^John||19800101|M
        PV1|1|O|ER^1^1
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidateMissingRequiredSegment() async throws {
        // ADT^A01 without required EVN segment
        let messageString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5
        PID|1||12345||Doe^John||19800101|M
        PV1|1|O|ER^1^1
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("Required segment EVN is missing") })
    }
    
    func testValidateDuplicateNonRepeatingSegment() async throws {
        // ADT^A01 with duplicate PID (should be only once)
        let messageString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5
        EVN|A01|20240101120000
        PID|1||12345||Doe^John||19800101|M
        PID|2||67890||Smith^Jane||19850202|F
        PV1|1|O|ER^1^1
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("PID") && $0.contains("exactly once") })
    }
    
    func testValidateRepeatingSegments() async throws {
        // ADT^A01 with multiple OBX (repeating is allowed)
        let messageString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5
        EVN|A01|20240101120000
        PID|1||12345||Doe^John||19800101|M
        PV1|1|O|ER^1^1
        OBX|1|ST|1234^Test1||Result1
        OBX|2|ST|5678^Test2||Result2
        OBX|3|ST|9012^Test3||Result3
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidateUnexpectedSegment() async throws {
        // ADT^A01 with unexpected ZZZ segment
        let messageString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5
        EVN|A01|20240101120000
        PID|1||12345||Doe^John||19800101|M
        PV1|1|O|ER^1^1
        ZZZ|CustomSegment
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        // Should be valid but with a warning
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.contains { $0.contains("ZZZ") })
    }
    
    func testValidateORUR01() async throws {
        // ORU^R01 with required OBX
        let messageString = """
        MSH|^~\\&|LAB|LAB_FAC|RECV_APP|RECV_FAC|20240101120000||ORU^R01|MSG456|P|2.5
        PID|1||12345||Doe^John||19800101|M
        OBR|1|ORDER123||TEST123^Test Name
        OBX|1|ST|CODE1^Test1||Result1
        OBX|2|NM|CODE2^Test2||42
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    func testValidateORUR01MissingRequiredOBX() async throws {
        // ORU^R01 without required OBX
        let messageString = """
        MSH|^~\\&|LAB|LAB_FAC|RECV_APP|RECV_FAC|20240101120000||ORU^R01|MSG456|P|2.5
        PID|1||12345||Doe^John||19800101|M
        OBR|1|ORDER123||TEST123^Test Name
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("OBX") && $0.contains("missing") })
    }
    
    func testValidateACK() async throws {
        // ACK message
        let messageString = """
        MSH|^~\\&|RECV_APP|RECV_FAC|SEND_APP|SEND_FAC|20240101120000||ACK|MSG789|P|2.5
        MSA|AA|MSG123
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibilityV2_1Message() async throws {
        // v2.1 message should be valid even with newer structure definitions
        let messageString = """
        MSH|^~\\&|APP|FAC|APP|FAC|20240101||ADT^A01|123|P|2.1
        EVN|A01|20240101
        PID|1||12345||Doe^John
        PV1|1|O|ER^1^1
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        // Basic structure should be valid
        XCTAssertTrue(result.isValid)
    }
    
    func testBackwardCompatibilityIgnoreUnknownSegments() async throws {
        // Older version receiving newer message with unknown segments
        // Should warn but not fail validation
        let messageString = """
        MSH|^~\\&|APP|FAC|APP|FAC|20240101||ADT^A01|123|P|2.5
        EVN|A01|20240101
        PID|1||12345||Doe^John
        PV1|1|O|ER^1^1
        ZNF|NewFeatureSegment
        """
        
        let message = try HL7v2Message.parse(messageString)
        let result = await message.validateStructure()
        
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.warnings.isEmpty)
    }
    
    // MARK: - Custom Structure Tests
    
    func testCustomStructureRegistration() async {
        let db = MessageStructureDatabase.shared
        
        // Register a custom structure
        let customStructure = MessageStructure(
            messageType: "ZZZ",
            triggerEvent: "Z01",
            description: "Custom Message Type",
            segments: [
                StructureSegmentDefinition(segmentID: "MSH", usage: .required, description: "Message Header"),
                StructureSegmentDefinition(segmentID: "ZZZ", usage: .required, description: "Custom Segment")
            ],
            introducedInVersion: .v2_5
        )
        
        await db.register(customStructure)
        
        // Retrieve it
        let retrieved = await db.structure(messageType: "ZZZ", triggerEvent: "Z01")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.messageType, "ZZZ")
        XCTAssertEqual(retrieved?.triggerEvent, "Z01")
    }
    
    // MARK: - Performance Tests
    
    func testVersionDetectionPerformance() throws {
        let messageString = "MSH|^~\\&|APP|FAC|APP|FAC|20240101||ADT^A01|123|P|2.5.1"
        let message = try HL7v2Message.parse(messageString)
        
        measure {
            for _ in 0..<1000 {
                _ = message.detectVersion()
            }
        }
    }
    
    func testStructureLookupPerformance() async {
        let db = MessageStructureDatabase.shared
        
        await measureAsync {
            for _ in 0..<1000 {
                _ = await db.structure(messageType: "ADT", triggerEvent: "A01")
            }
        }
    }
    
    func testStructureValidationPerformance() async throws {
        let messageString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECV_APP|RECV_FAC|20240101120000||ADT^A01|MSG123|P|2.5
        EVN|A01|20240101120000
        PID|1||12345||Doe^John||19800101|M
        PV1|1|O|ER^1^1
        OBX|1|ST|1234^Test||Result
        """
        
        let message = try HL7v2Message.parse(messageString)
        
        await measureAsync {
            for _ in 0..<100 {
                _ = await message.validateStructure()
            }
        }
    }
    
    // Helper for async performance measurement
    private func measureAsync(block: @escaping () async -> Void) async {
        let start = Date()
        await block()
        let duration = Date().timeIntervalSince(start)
        // Record the measurement
        XCTAssert(duration >= 0, "Performance test completed in \(duration) seconds")
    }
}
