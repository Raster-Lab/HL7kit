/// Tests for Z-segment (custom segment) support
///
/// Tests for Z-segment definitions, registry, builder, and validation

import XCTest
@testable import HL7v2Kit
@testable import HL7Core

final class ZSegmentSupportTests: XCTestCase {
    
    override func setUp() async throws {
        // Clear registry before each test
        await ZSegmentRegistry.shared.clearAll()
    }
    
    // MARK: - Z-Segment Definition Tests
    
    func testZSegmentDefinitionCreation() throws {
        let definition = try ZSegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info",
            description: "Additional patient information"
        )
        
        XCTAssertEqual(definition.segmentID, "ZPI")
        XCTAssertEqual(definition.name, "Custom Patient Info")
        XCTAssertEqual(definition.description, "Additional patient information")
    }
    
    func testZSegmentDefinitionWithFields() throws {
        let fields = [
            ZFieldDefinition(index: 0, name: "Field 1", required: true),
            ZFieldDefinition(index: 1, name: "Field 2", repeating: true)
        ]
        
        let definition = try ZSegmentDefinition(
            segmentID: "ZTE",
            name: "Test Segment",
            fields: fields
        )
        
        XCTAssertEqual(definition.fields.count, 2)
        XCTAssertTrue(definition.fields[0].required)
        XCTAssertTrue(definition.fields[1].repeating)
    }
    
    func testZSegmentDefinitionInvalidID() throws {
        // Not starting with Z
        XCTAssertThrowsError(try ZSegmentDefinition(
            segmentID: "ABC",
            name: "Invalid"
        ))
        
        // Too short
        XCTAssertThrowsError(try ZSegmentDefinition(
            segmentID: "ZP",
            name: "Invalid"
        ))
        
        // Too long
        XCTAssertThrowsError(try ZSegmentDefinition(
            segmentID: "ZPID",
            name: "Invalid"
        ))
    }
    
    // MARK: - Z-Segment Registry Tests
    
    func testZSegmentRegistryRegisterAndRetrieve() async throws {
        let definition = try ZSegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info"
        )
        
        await ZSegmentRegistry.shared.register(definition)
        
        let retrieved = await ZSegmentRegistry.shared.definition(for: "ZPI")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.segmentID, "ZPI")
    }
    
    func testZSegmentRegistryIsRegistered() async throws {
        let definition = try ZSegmentDefinition(
            segmentID: "ZTE",
            name: "Test"
        )
        
        await ZSegmentRegistry.shared.register(definition)
        
        let isRegistered = await ZSegmentRegistry.shared.isRegistered("ZTE")
        XCTAssertTrue(isRegistered)
        
        let isNotRegistered = await ZSegmentRegistry.shared.isRegistered("ZXX")
        XCTAssertFalse(isNotRegistered)
    }
    
    func testZSegmentRegistryAllSegmentIDs() async throws {
        let def1 = try ZSegmentDefinition(segmentID: "ZTE", name: "Test 1")
        let def2 = try ZSegmentDefinition(segmentID: "ZAB", name: "Test 2")
        
        await ZSegmentRegistry.shared.register(def1)
        await ZSegmentRegistry.shared.register(def2)
        
        let allIDs = await ZSegmentRegistry.shared.allSegmentIDs()
        XCTAssertEqual(allIDs.count, 2)
        XCTAssertTrue(allIDs.contains("ZTE"))
        XCTAssertTrue(allIDs.contains("ZAB"))
    }
    
    func testZSegmentRegistryUnregister() async throws {
        let definition = try ZSegmentDefinition(segmentID: "ZTE", name: "Test")
        
        await ZSegmentRegistry.shared.register(definition)
        XCTAssertTrue(await ZSegmentRegistry.shared.isRegistered("ZTE"))
        
        await ZSegmentRegistry.shared.unregister("ZTE")
        XCTAssertFalse(await ZSegmentRegistry.shared.isRegistered("ZTE"))
    }
    
    func testZSegmentRegistryClearAll() async throws {
        let def1 = try ZSegmentDefinition(segmentID: "ZTE", name: "Test 1")
        let def2 = try ZSegmentDefinition(segmentID: "ZAB", name: "Test 2")
        
        await ZSegmentRegistry.shared.register(def1)
        await ZSegmentRegistry.shared.register(def2)
        
        await ZSegmentRegistry.shared.clearAll()
        
        let allIDs = await ZSegmentRegistry.shared.allSegmentIDs()
        XCTAssertEqual(allIDs.count, 0)
    }
    
    // MARK: - Z-Segment Builder Tests
    
    func testZSegmentBuilderCreation() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
        let segment = builder.build()
        
        XCTAssertEqual(segment.segmentID, "ZPI")
        XCTAssertEqual(segment.fields.count, 0)
    }
    
    func testZSegmentBuilderAddField() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
            .addField("Value1")
            .addField("Value2")
        
        let segment = builder.build()
        
        XCTAssertEqual(segment.fields.count, 2)
        XCTAssertEqual(segment[0].value.value.raw, "Value1")
        XCTAssertEqual(segment[1].value.value.raw, "Value2")
    }
    
    func testZSegmentBuilderAddFieldWithComponents() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
            .addField(components: ["Comp1", "Comp2", "Comp3"])
        
        let segment = builder.build()
        
        XCTAssertEqual(segment.fields.count, 1)
        let field = segment[0]
        // Check that the field has components by serializing
        let serialized = field.serialize()
        XCTAssertTrue(serialized.contains("Comp1"))
        XCTAssertTrue(serialized.contains("Comp2"))
        XCTAssertTrue(serialized.contains("Comp3"))
    }
    
    func testZSegmentBuilderAddEmptyField() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
            .addField("First")
            .addEmptyField()
            .addField("Third")
        
        let segment = builder.build()
        
        XCTAssertEqual(segment.fields.count, 3)
        XCTAssertEqual(segment[0].value.value.raw, "First")
        XCTAssertTrue(segment[1].isEmpty)
        XCTAssertEqual(segment[2].value.value.raw, "Third")
    }
    
    func testZSegmentBuilderAddFields() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
            .addFields(["Field1", "Field2", "Field3"])
        
        let segment = builder.build()
        
        XCTAssertEqual(segment.fields.count, 3)
        XCTAssertEqual(segment[0].value.value.raw, "Field1")
        XCTAssertEqual(segment[1].value.value.raw, "Field2")
        XCTAssertEqual(segment[2].value.value.raw, "Field3")
    }
    
    func testZSegmentBuilderBuildAndSerialize() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
            .addField("TestValue")
            .addField("AnotherValue")
        
        let serialized = try builder.buildAndSerialize()
        
        XCTAssertTrue(serialized.hasPrefix("ZPI|"))
        XCTAssertTrue(serialized.contains("TestValue"))
        XCTAssertTrue(serialized.contains("AnotherValue"))
    }
    
    func testZSegmentBuilderInvalidID() throws {
        XCTAssertThrowsError(try ZSegmentBuilder(segmentID: "MSH"))
        XCTAssertThrowsError(try ZSegmentBuilder(segmentID: "PID"))
        XCTAssertThrowsError(try ZSegmentBuilder(segmentID: "AB"))
    }
    
    // MARK: - Z-Segment Parsing Tests
    
    func testParseZSegment() throws {
        let zSegmentString = "ZPI|1|CustomType|12345|Note1~Note2"
        let segment = try BaseSegment.parse(zSegmentString)
        
        XCTAssertEqual(segment.segmentID, "ZPI")
        XCTAssertTrue(segment.isZSegment)
        XCTAssertEqual(segment[0].value.value.raw, "1")
        XCTAssertEqual(segment[1].value.value.raw, "CustomType")
        XCTAssertEqual(segment[2].value.value.raw, "12345")
    }
    
    func testZSegmentIsZSegment() throws {
        let zSegment = try BaseSegment.parse("ZPI|test")
        XCTAssertTrue(zSegment.isZSegment)
        
        let regularSegment = try BaseSegment.parse("PID|1||12345")
        XCTAssertFalse(regularSegment.isZSegment)
        
        let mshSegment = try BaseSegment.parse("MSH|^~\\&|test")
        XCTAssertFalse(mshSegment.isZSegment)
    }
    
    // MARK: - Z-Segment Validation Tests
    
    func testZSegmentValidationSuccess() throws {
        let fields = [
            ZFieldDefinition(index: 0, name: "ID", required: true),
            ZFieldDefinition(index: 1, name: "Type", required: true),
            ZFieldDefinition(index: 2, name: "Notes", repeating: true)
        ]
        
        let definition = try ZSegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info",
            fields: fields
        )
        
        let segment = try BaseSegment.parse("ZPI|123|TypeA|Note1")
        let result = definition.validate(segment)
        
        XCTAssertTrue(result.isValid)
    }
    
    func testZSegmentValidationMissingRequiredField() throws {
        let fields = [
            ZFieldDefinition(index: 0, name: "ID", required: true),
            ZFieldDefinition(index: 1, name: "Type", required: true)
        ]
        
        let definition = try ZSegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info",
            fields: fields
        )
        
        // Missing the second required field
        let segment = try BaseSegment.parse("ZPI|123")
        let result = definition.validate(segment)
        
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.issues.first?.message.contains("Required field") ?? false)
    }
    
    func testZSegmentValidationWrongSegmentID() throws {
        let definition = try ZSegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info"
        )
        
        let segment = try BaseSegment.parse("ZAB|123")
        let result = definition.validate(segment)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.issues.first?.message.contains("Segment ID mismatch") ?? false)
    }
    
    func testZSegmentValidationUnexpectedRepetition() throws {
        let fields = [
            ZFieldDefinition(index: 0, name: "ID", required: true, repeating: false)
        ]
        
        let definition = try ZSegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info",
            fields: fields
        )
        
        // Field with repetition (~ separator)
        let segment = try BaseSegment.parse("ZPI|123~456")
        let result = definition.validate(segment)
        
        // Should have a warning about repetition
        XCTAssertTrue(result.isValid) // Warnings don't make it invalid
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertEqual(result.issues.first?.severity, .warning)
    }
    
    // MARK: - Predefined Z-Segment Examples Tests
    
    func testPredefinedZPIDefinition() throws {
        let zpi = ZSegmentDefinition.zpi
        
        XCTAssertEqual(zpi.segmentID, "ZPI")
        XCTAssertEqual(zpi.name, "Custom Patient Information")
        XCTAssertEqual(zpi.fields.count, 4)
    }
    
    func testPredefinedZBEDefinition() throws {
        let zbe = ZSegmentDefinition.zbe
        
        XCTAssertEqual(zbe.segmentID, "ZBE")
        XCTAssertEqual(zbe.name, "Custom Billing Extension")
        XCTAssertEqual(zbe.fields.count, 4)
    }
    
    func testPredefinedZOBDefinition() throws {
        let zob = ZSegmentDefinition.zob
        
        XCTAssertEqual(zob.segmentID, "ZOB")
        XCTAssertEqual(zob.name, "Custom Observation Extension")
        XCTAssertEqual(zob.fields.count, 3)
    }
    
    // MARK: - Integration Tests
    
    func testZSegmentWithinMessage() throws {
        let messageString = """
        MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20240101||ADT^A01|MSG001|P|2.5
        PID|1||12345||Doe^John
        ZPI|1|Outpatient|CustomID123|Special notes
        """
        
        let parser = HL7v2Parser()
        let result = try parser.parse(messageString)
        
        XCTAssertEqual(result.message.segmentCount, 3)
        
        let zSegment = result.message.allSegments[2]
        XCTAssertEqual(zSegment.segmentID, "ZPI")
        XCTAssertTrue(zSegment.isZSegment)
    }
    
    func testBuildMessageWithZSegment() throws {
        let builder = try ZSegmentBuilder(segmentID: "ZPI")
            .addField("1")
            .addField("TestType")
            .addField("Note")
        
        let segment = builder.build()
        let serialized = try segment.serialize()
        
        XCTAssertEqual(serialized, "ZPI|1|TestType|Note")
    }
}
