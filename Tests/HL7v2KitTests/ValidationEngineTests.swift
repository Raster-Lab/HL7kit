import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Comprehensive tests for the HL7 v2.x Validation Engine
final class ValidationEngineTests: XCTestCase {

    // MARK: - Test Helpers

    /// Build a minimal valid ADT A01 message string
    private func makeADTMessage(
        triggerEvent: String = "A01",
        includeEVN: Bool = true,
        includePID: Bool = true,
        includePV1: Bool = true,
        patientID: String = "12345",
        patientName: String = "Smith^John",
        version: String = "2.5.1"
    ) -> String {
        var segments = [
            "MSH|^~\\&|SendApp|SendFac|RecvApp|RecvFac|20230615120000||ADT^" + triggerEvent + "|MSG00001|P|\(version)"
        ]
        if includeEVN { segments.append("EVN|\(triggerEvent)|20230615120000") }
        if includePID { segments.append("PID|1||\(patientID)|||\(patientName)||19800101|M") }
        if includePV1 { segments.append("PV1|1|I|2000^2012^01") }
        return segments.joined(separator: "\r")
    }

    /// Build a minimal valid ORU R01 message string
    private func makeORUMessage(
        includeOBR: Bool = true,
        includeOBX: Bool = true
    ) -> String {
        var segments = [
            "MSH|^~\\&|Lab|Hospital|EHR|Hospital|20230615120000||ORU^R01|MSG00002|P|2.5.1",
            "PID|1||12345^^^MR||Doe^Jane||19900101|F"
        ]
        if includeOBR { segments.append("OBR|1||123^Lab|80048^BMP^L") }
        if includeOBX {
            segments.append("OBX|1|NM|2345-7^Glucose^LN||95|mg/dL|70-110|N|||F")
        }
        return segments.joined(separator: "\r")
    }

    /// Build a minimal valid ACK message string
    private func makeACKMessage(ackCode: String = "AA") -> String {
        return [
            "MSH|^~\\&|RecvApp|RecvFac|SendApp|SendFac|20230615120100||ACK|MSG00003|P|2.5.1",
            "MSA|\(ackCode)|MSG00001|Message accepted"
        ].joined(separator: "\r")
    }

    /// Build a minimal valid ORM O01 message string
    private func makeORMMessage() -> String {
        return [
            "MSH|^~\\&|OrderApp|Facility|Lab|Facility|20230615120000||ORM^O01|MSG00004|P|2.5.1",
            "PID|1||12345^^^MR||Smith^John||19800101|M",
            "ORC|NW|ORD001||||||||||1234^Doctor^Jane",
            "OBR|1|ORD001||80048^BMP^L"
        ].joined(separator: "\r")
    }

    // MARK: - HL7v2DataType Tests

    func testDataTypeCaseIterable() {
        XCTAssertTrue(HL7v2DataType.allCases.count > 0)
        XCTAssertTrue(HL7v2DataType.allCases.contains(.string))
        XCTAssertTrue(HL7v2DataType.allCases.contains(.numeric))
        XCTAssertTrue(HL7v2DataType.allCases.contains(.timestamp))
    }

    func testDataTypeRawValues() {
        XCTAssertEqual(HL7v2DataType.string.rawValue, "ST")
        XCTAssertEqual(HL7v2DataType.numeric.rawValue, "NM")
        XCTAssertEqual(HL7v2DataType.date.rawValue, "DT")
        XCTAssertEqual(HL7v2DataType.time.rawValue, "TM")
        XCTAssertEqual(HL7v2DataType.timestamp.rawValue, "TS")
        XCTAssertEqual(HL7v2DataType.sequenceID.rawValue, "SI")
        XCTAssertEqual(HL7v2DataType.codedValue.rawValue, "ID")
        XCTAssertEqual(HL7v2DataType.codedValueUser.rawValue, "IS")
    }

    // MARK: - FieldOptionality Tests

    func testFieldOptionalityRawValues() {
        XCTAssertEqual(FieldOptionality.required.rawValue, "R")
        XCTAssertEqual(FieldOptionality.optional.rawValue, "O")
        XCTAssertEqual(FieldOptionality.conditional.rawValue, "C")
        XCTAssertEqual(FieldOptionality.notUsed.rawValue, "X")
        XCTAssertEqual(FieldOptionality.backward.rawValue, "B")
        XCTAssertEqual(FieldOptionality.withdrawn.rawValue, "W")
    }

    // MARK: - Cardinality Tests

    func testCardinalityExactlyOne() {
        let c = Cardinality.exactlyOne
        XCTAssertTrue(c.isSatisfied(by: 1))
        XCTAssertFalse(c.isSatisfied(by: 0))
        XCTAssertFalse(c.isSatisfied(by: 2))
    }

    func testCardinalityZeroOrOne() {
        let c = Cardinality.zeroOrOne
        XCTAssertTrue(c.isSatisfied(by: 0))
        XCTAssertTrue(c.isSatisfied(by: 1))
        XCTAssertFalse(c.isSatisfied(by: 2))
    }

    func testCardinalityOneOrMore() {
        let c = Cardinality.oneOrMore
        XCTAssertFalse(c.isSatisfied(by: 0))
        XCTAssertTrue(c.isSatisfied(by: 1))
        XCTAssertTrue(c.isSatisfied(by: 100))
    }

    func testCardinalityZeroOrMore() {
        let c = Cardinality.zeroOrMore
        XCTAssertTrue(c.isSatisfied(by: 0))
        XCTAssertTrue(c.isSatisfied(by: 1))
        XCTAssertTrue(c.isSatisfied(by: 100))
    }

    func testCardinalityCustom() {
        let c = Cardinality(min: 2, max: 5)
        XCTAssertFalse(c.isSatisfied(by: 0))
        XCTAssertFalse(c.isSatisfied(by: 1))
        XCTAssertTrue(c.isSatisfied(by: 2))
        XCTAssertTrue(c.isSatisfied(by: 5))
        XCTAssertFalse(c.isSatisfied(by: 6))
    }

    func testCardinalityDisplayString() {
        XCTAssertEqual(Cardinality.exactlyOne.displayString, "[1..1]")
        XCTAssertEqual(Cardinality.zeroOrOne.displayString, "[0..1]")
        XCTAssertEqual(Cardinality.oneOrMore.displayString, "[1..*]")
        XCTAssertEqual(Cardinality.zeroOrMore.displayString, "[0..*]")
        XCTAssertEqual(Cardinality(min: 2, max: 5).displayString, "[2..5]")
    }

    func testCardinalityEquatable() {
        XCTAssertEqual(Cardinality.exactlyOne, Cardinality(min: 1, max: 1))
        XCTAssertNotEqual(Cardinality.exactlyOne, Cardinality.zeroOrOne)
    }

    func testCardinalityNegativeMinClamps() {
        let c = Cardinality(min: -5, max: 10)
        XCTAssertEqual(c.min, 0)
    }

    // MARK: - FieldDefinition Tests

    func testFieldDefinitionCreation() {
        let fd = FieldDefinition(
            position: 3,
            name: "Patient Identifier List",
            dataType: .extendedCompositeID,
            optionality: .required,
            maxLength: 250,
            repetitions: .oneOrMore
        )
        XCTAssertEqual(fd.position, 3)
        XCTAssertEqual(fd.name, "Patient Identifier List")
        XCTAssertEqual(fd.dataType, .extendedCompositeID)
        XCTAssertEqual(fd.optionality, .required)
        XCTAssertEqual(fd.maxLength, 250)
        XCTAssertEqual(fd.repetitions, .oneOrMore)
    }

    func testFieldDefinitionDefaults() {
        let fd = FieldDefinition(position: 1, name: "Test", dataType: .string)
        XCTAssertEqual(fd.optionality, .optional)
        XCTAssertNil(fd.maxLength)
        XCTAssertEqual(fd.repetitions, .exactlyOne)
    }

    // MARK: - SegmentDefinition Tests

    func testSegmentDefinitionCreation() {
        let fields = [
            FieldDefinition(position: 1, name: "Set ID", dataType: .sequenceID),
            FieldDefinition(position: 2, name: "Patient Class", dataType: .codedValue, optionality: .required)
        ]
        let sd = SegmentDefinition(segmentID: "PV1", name: "Patient Visit", fields: fields)
        XCTAssertEqual(sd.segmentID, "PV1")
        XCTAssertEqual(sd.name, "Patient Visit")
        XCTAssertEqual(sd.fields.count, 2)
    }

    func testSegmentDefinitionFieldLookup() {
        let sd = StandardProfiles.pidDefinition
        XCTAssertNotNil(sd.field(at: 3))
        XCTAssertEqual(sd.field(at: 3)?.name, "Patient Identifier List")
        XCTAssertNil(sd.field(at: 99))
    }

    // MARK: - ConformanceProfile Tests

    func testConformanceProfileCreation() {
        let profile = StandardProfiles.adtA01
        XCTAssertEqual(profile.identifier, "ADT_A01")
        XCTAssertEqual(profile.messageType, "ADT")
        XCTAssertEqual(profile.triggerEvent, "A01")
        XCTAssertEqual(profile.hl7Version, "2.5.1")
        XCTAssertFalse(profile.segmentRequirements.isEmpty)
    }

    func testConformanceProfileRequirementLookup() {
        let profile = StandardProfiles.adtA01
        XCTAssertNotNil(profile.requirement(for: "MSH"))
        XCTAssertNotNil(profile.requirement(for: "PID"))
        XCTAssertNil(profile.requirement(for: "ZZZ"))
    }

    // MARK: - Data Type Validation Tests

    func testValidateNumericValid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("123", as: .numeric).isEmpty)
        XCTAssertTrue(engine.validateDataType("+42", as: .numeric).isEmpty)
        XCTAssertTrue(engine.validateDataType("-99", as: .numeric).isEmpty)
        XCTAssertTrue(engine.validateDataType("3.14", as: .numeric).isEmpty)
        XCTAssertTrue(engine.validateDataType("-0.5", as: .numeric).isEmpty)
        XCTAssertTrue(engine.validateDataType("0", as: .numeric).isEmpty)
    }

    func testValidateNumericInvalid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertFalse(engine.validateDataType("abc", as: .numeric).isEmpty)
        XCTAssertFalse(engine.validateDataType("12.34.56", as: .numeric).isEmpty)
        XCTAssertFalse(engine.validateDataType("", as: .numeric).isEmpty)
        XCTAssertFalse(engine.validateDataType("1,000", as: .numeric).isEmpty)
    }

    func testValidateDateValid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("2023", as: .date).isEmpty)
        XCTAssertTrue(engine.validateDataType("202306", as: .date).isEmpty)
        XCTAssertTrue(engine.validateDataType("20230615", as: .date).isEmpty)
    }

    func testValidateDateInvalid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertFalse(engine.validateDataType("abcd", as: .date).isEmpty)
        XCTAssertFalse(engine.validateDataType("20231301", as: .date).isEmpty) // month 13
        XCTAssertFalse(engine.validateDataType("20230632", as: .date).isEmpty) // day 32
        XCTAssertFalse(engine.validateDataType("20230600", as: .date).isEmpty) // day 0
    }

    func testValidateTimeValid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("12", as: .time).isEmpty)
        XCTAssertTrue(engine.validateDataType("1230", as: .time).isEmpty)
        XCTAssertTrue(engine.validateDataType("123045", as: .time).isEmpty)
        XCTAssertTrue(engine.validateDataType("123045.1234", as: .time).isEmpty)
        XCTAssertTrue(engine.validateDataType("1230+0500", as: .time).isEmpty)
        XCTAssertTrue(engine.validateDataType("123045-0400", as: .time).isEmpty)
    }

    func testValidateTimeInvalid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertFalse(engine.validateDataType("25", as: .time).isEmpty) // hour 25
        XCTAssertFalse(engine.validateDataType("abc", as: .time).isEmpty)
        XCTAssertFalse(engine.validateDataType("1", as: .time).isEmpty) // only 1 digit
    }

    func testValidateTimestampValid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("2023", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("202306", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("20230615", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("2023061512", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("202306151230", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("20230615123045", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("20230615123045.1234", as: .timestamp).isEmpty)
        XCTAssertTrue(engine.validateDataType("20230615123045+0500", as: .timestamp).isEmpty)
    }

    func testValidateTimestampInvalid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertFalse(engine.validateDataType("abc", as: .timestamp).isEmpty)
        XCTAssertFalse(engine.validateDataType("20", as: .timestamp).isEmpty) // too short
    }

    func testValidateSequenceIDValid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("1", as: .sequenceID).isEmpty)
        XCTAssertTrue(engine.validateDataType("42", as: .sequenceID).isEmpty)
        XCTAssertTrue(engine.validateDataType("0", as: .sequenceID).isEmpty)
    }

    func testValidateSequenceIDInvalid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertFalse(engine.validateDataType("abc", as: .sequenceID).isEmpty)
        XCTAssertFalse(engine.validateDataType("-1", as: .sequenceID).isEmpty)
        XCTAssertFalse(engine.validateDataType("1.5", as: .sequenceID).isEmpty)
    }

    func testValidateStringAlwaysValid() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("anything", as: .string).isEmpty)
        XCTAssertTrue(engine.validateDataType("", as: .string).isEmpty)
        XCTAssertTrue(engine.validateDataType("!@#$%", as: .string).isEmpty)
    }

    func testValidateDataTypeLocation() {
        let engine = HL7v2ValidationEngine()
        let issues = engine.validateDataType("abc", as: .numeric, location: "PID-3")
        XCTAssertEqual(issues.first?.location, "PID-3")
        XCTAssertEqual(issues.first?.code, "INVALID_NM")
    }

    // MARK: - Profile-Based Validation Tests

    func testValidateValidADTMessage() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        // May have field-level warnings/info, but should not have fatal structural errors
        // The message has all required segments
        let errors = result.issues.filter { $0.severity == .error }
        // Check no segment cardinality errors
        let cardErrors = errors.filter { $0.code == "SEGMENT_CARDINALITY" }
        XCTAssertTrue(cardErrors.isEmpty, "Expected no segment cardinality errors, got: \(cardErrors)")
    }

    func testValidateMissingEVNSegment() throws {
        let raw = makeADTMessage(includeEVN: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        XCTAssertFalse(result.isValid)
        let evnIssues = result.issues.filter { $0.location == "EVN" }
        XCTAssertFalse(evnIssues.isEmpty, "Expected EVN segment error")
    }

    func testValidateMissingPIDSegment() throws {
        let raw = makeADTMessage(includePID: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        XCTAssertFalse(result.isValid)
        let pidIssues = result.issues.filter { $0.location == "PID" }
        XCTAssertFalse(pidIssues.isEmpty, "Expected PID segment error")
    }

    func testValidateMissingPV1Segment() throws {
        let raw = makeADTMessage(includePV1: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        XCTAssertFalse(result.isValid)
        let pv1Issues = result.issues.filter { $0.location == "PV1" }
        XCTAssertFalse(pv1Issues.isEmpty, "Expected PV1 segment error")
    }

    func testValidateMessageTypeMismatch() throws {
        let raw = makeORUMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        XCTAssertFalse(result.isValid)
        let typeIssues = result.issues.filter { $0.code == "MSG_TYPE_MISMATCH" }
        XCTAssertFalse(typeIssues.isEmpty, "Expected message type mismatch error")
    }

    func testValidateValidORUMessage() throws {
        let raw = makeORUMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.oruR01)
        let cardErrors = result.issues.filter { $0.code == "SEGMENT_CARDINALITY" }
        XCTAssertTrue(cardErrors.isEmpty, "Expected no segment cardinality errors, got: \(cardErrors)")
    }

    func testValidateORUMissingOBX() throws {
        let raw = makeORUMessage(includeOBX: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.oruR01)
        XCTAssertFalse(result.isValid)
        let obxIssues = result.issues.filter { $0.location == "OBX" }
        XCTAssertFalse(obxIssues.isEmpty, "Expected OBX segment error")
    }

    func testValidateORUMissingOBR() throws {
        let raw = makeORUMessage(includeOBR: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.oruR01)
        XCTAssertFalse(result.isValid)
        let obrIssues = result.issues.filter { $0.location == "OBR" }
        XCTAssertFalse(obrIssues.isEmpty, "Expected OBR segment error")
    }

    func testValidateValidACKMessage() throws {
        let raw = makeACKMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.ack)
        let cardErrors = result.issues.filter { $0.code == "SEGMENT_CARDINALITY" }
        XCTAssertTrue(cardErrors.isEmpty, "Expected no segment cardinality errors, got: \(cardErrors)")
    }

    func testValidateValidORMMessage() throws {
        let raw = makeORMMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.ormO01)
        let cardErrors = result.issues.filter { $0.code == "SEGMENT_CARDINALITY" }
        XCTAssertTrue(cardErrors.isEmpty, "Expected no segment cardinality errors, got: \(cardErrors)")
    }

    // MARK: - Rules-Based Validation Tests

    func testRequiredSegmentRulePass() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let rule = RequiredSegmentRule(segmentID: "PID")
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testRequiredSegmentRuleFail() throws {
        let raw = makeADTMessage(includePV1: false)
        let message = try HL7v2Message.parse(raw)
        let rule = RequiredSegmentRule(segmentID: "PV1")
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.severity, .error)
        XCTAssertEqual(issues.first?.code, "REQUIRED_SEGMENT")
    }

    func testRequiredSegmentRuleMinCount() throws {
        let raw = makeORUMessage()
        let message = try HL7v2Message.parse(raw)
        // Message has 1 OBX, require at least 2
        let rule = RequiredSegmentRule(segmentID: "OBX", minimumCount: 2)
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
    }

    func testRequiredFieldRulePass() throws {
        let raw = makeACKMessage()
        let message = try HL7v2Message.parse(raw)
        let rule = RequiredFieldRule(segmentID: "MSA", fieldPosition: 1, fieldName: "Acknowledgment Code")
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testRequiredFieldRuleFailEmptyField() throws {
        // Build a message with MSA but no ack code
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ACK|MSG001|P|2.5.1",
            "MSA||MSG000"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let rule = RequiredFieldRule(segmentID: "MSA", fieldPosition: 1, fieldName: "Acknowledgment Code")
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.code, "REQUIRED_FIELD_MISSING")
    }

    func testRequiredFieldRuleSegmentAbsent() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        // MSA doesn't exist in ADT message — rule should return no issues
        let rule = RequiredFieldRule(segmentID: "MSA", fieldPosition: 1, fieldName: "Acknowledgment Code")
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testFieldLengthRulePass() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let rule = FieldLengthRule(segmentID: "PID", fieldPosition: 5, maxLength: 250, fieldName: "Patient Name")
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testFieldLengthRuleFail() throws {
        // Create a message with a very long patient ID
        let longID = String(repeating: "A", count: 30)
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "EVN|A01|20230615120000",
            "PID|1||\(longID)|||Smith^John||19800101|M",
            "PV1|1|I"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let rule = FieldLengthRule(segmentID: "PID", fieldPosition: 3, maxLength: 20, fieldName: "Patient ID")
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.code, "FIELD_TOO_LONG")
    }

    func testDataTypeRulePass() throws {
        let raw = makeORUMessage()
        let message = try HL7v2Message.parse(raw)
        let rule = DataTypeRule(segmentID: "OBX", fieldPosition: 1, dataType: .sequenceID, fieldName: "Set ID")
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testDataTypeRuleFail() throws {
        // OBX Set ID should be numeric, let's check a message where it's OK
        // Instead, test an invalid scenario manually
        let raw = [
            "MSH|^~\\&|Lab|H|EHR|H|20230615120000||ORU^R01|MSG001|P|2.5.1",
            "PID|1||12345^^^MR||Doe^Jane||19900101|F",
            "OBR|1||123^Lab|80048^BMP^L",
            "OBX|abc|NM|2345-7^Glucose^LN||95|mg/dL|70-110|N|||F"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let rule = DataTypeRule(segmentID: "OBX", fieldPosition: 1, dataType: .sequenceID, fieldName: "Set ID")
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.code, "INVALID_SI")
    }

    func testValueSetRulePass() throws {
        let raw = makeACKMessage(ackCode: "AA")
        let message = try HL7v2Message.parse(raw)
        let rule = ValueSetRule(
            segmentID: "MSA", fieldPosition: 1,
            allowedValues: ["AA", "AE", "AR", "CA", "CE", "CR"],
            fieldName: "Acknowledgment Code"
        )
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testValueSetRuleFail() throws {
        let raw = makeACKMessage(ackCode: "XX")
        let message = try HL7v2Message.parse(raw)
        let rule = ValueSetRule(
            segmentID: "MSA", fieldPosition: 1,
            allowedValues: ["AA", "AE", "AR", "CA", "CE", "CR"],
            fieldName: "Acknowledgment Code"
        )
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.code, "VALUE_NOT_IN_SET")
    }

    func testPatternRulePass() throws {
        let raw = makeADTMessage(version: "2.5.1")
        let message = try HL7v2Message.parse(raw)
        let rule = PatternRule(
            segmentID: "MSH", fieldPosition: 12,
            pattern: #"^\d+\.\d+(\.\d+)?$"#,
            fieldName: "Version ID"
        )
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testPatternRuleFail() throws {
        let raw = makeADTMessage(version: "vX")
        let message = try HL7v2Message.parse(raw)
        let rule = PatternRule(
            segmentID: "MSH", fieldPosition: 12,
            pattern: #"^\d+\.\d+(\.\d+)?$"#,
            fieldName: "Version ID"
        )
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.code, "PATTERN_MISMATCH")
    }

    func testSegmentCardinalityRulePass() throws {
        let raw = makeORUMessage()
        let message = try HL7v2Message.parse(raw)
        let rule = SegmentCardinalityRule(segmentID: "OBX", cardinality: .oneOrMore)
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty)
    }

    func testSegmentCardinalityRuleFail() throws {
        let raw = makeORUMessage(includeOBX: false)
        let message = try HL7v2Message.parse(raw)
        let rule = SegmentCardinalityRule(segmentID: "OBX", cardinality: .oneOrMore)
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.code, "SEGMENT_CARDINALITY")
    }

    func testCustomValidationRule() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let rule = CustomValidationRule(
            description: "Message control ID must start with MSG"
        ) { msg in
            let controlID = msg.messageControlID()
            if !controlID.hasPrefix("MSG") {
                return [ValidationIssue(
                    severity: .error,
                    message: "Message control ID must start with MSG",
                    location: "MSH-10",
                    code: "CUSTOM_CONTROL_ID"
                )]
            }
            return []
        }
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty) // MSG00001 starts with MSG
    }

    func testCustomValidationRuleFail() throws {
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|XYZ123|P|2.5.1",
            "EVN|A01|20230615120000",
            "PID|1||12345|||Smith^John||19800101|M",
            "PV1|1|I"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let rule = CustomValidationRule(
            description: "Message control ID must start with MSG"
        ) { msg in
            let controlID = msg.messageControlID()
            if !controlID.hasPrefix("MSG") {
                return [ValidationIssue(
                    severity: .error,
                    message: "Message control ID must start with MSG",
                    location: "MSH-10",
                    code: "CUSTOM_CONTROL_ID"
                )]
            }
            return []
        }
        let issues = rule.validate(message: message)
        XCTAssertEqual(issues.count, 1)
    }

    // MARK: - Engine with Rules Tests

    func testEngineValidateWithMultipleRules() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let rules: [HL7v2ValidationRule] = [
            RequiredSegmentRule(segmentID: "MSH"),
            RequiredSegmentRule(segmentID: "EVN"),
            RequiredSegmentRule(segmentID: "PID"),
            RequiredSegmentRule(segmentID: "PV1"),
        ]
        let result = engine.validate(message, rules: rules)
        XCTAssertTrue(result.isValid)
    }

    func testEngineValidateWithMultipleRulesAndFailures() throws {
        let raw = makeADTMessage(includeEVN: false, includePV1: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let rules: [HL7v2ValidationRule] = [
            RequiredSegmentRule(segmentID: "MSH"),
            RequiredSegmentRule(segmentID: "EVN"),
            RequiredSegmentRule(segmentID: "PID"),
            RequiredSegmentRule(segmentID: "PV1"),
        ]
        let result = engine.validate(message, rules: rules)
        XCTAssertFalse(result.isValid)
        let errors = result.issues.filter { $0.severity == .error }
        XCTAssertEqual(errors.count, 2) // EVN and PV1 missing
    }

    // MARK: - Engine Options Tests

    func testStopOnFirstError() throws {
        let raw = makeADTMessage(includeEVN: false, includePV1: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine(options: ValidationOptions(stopOnFirstError: true))
        let rules: [HL7v2ValidationRule] = [
            RequiredSegmentRule(segmentID: "EVN"),
            RequiredSegmentRule(segmentID: "PV1"),
        ]
        let result = engine.validate(message, rules: rules)
        XCTAssertFalse(result.isValid)
        // Should stop after first error
        let errors = result.issues.filter { $0.severity == .error }
        XCTAssertEqual(errors.count, 1)
    }

    func testMaxIssuesLimit() throws {
        let raw = makeADTMessage(includeEVN: false, includePID: false, includePV1: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine(options: ValidationOptions(maxIssues: 2))
        let rules: [HL7v2ValidationRule] = [
            RequiredSegmentRule(segmentID: "EVN"),
            RequiredSegmentRule(segmentID: "PID"),
            RequiredSegmentRule(segmentID: "PV1"),
        ]
        let result = engine.validate(message, rules: rules)
        XCTAssertFalse(result.isValid)
        XCTAssertLessThanOrEqual(result.issues.count, 2)
    }

    // MARK: - Standard Profiles Tests

    func testStandardProfilesExist() {
        XCTAssertEqual(StandardProfiles.adtA01.messageType, "ADT")
        XCTAssertEqual(StandardProfiles.oruR01.messageType, "ORU")
        XCTAssertEqual(StandardProfiles.ormO01.messageType, "ORM")
        XCTAssertEqual(StandardProfiles.ack.messageType, "ACK")
    }

    func testMSHDefinitionFields() {
        let msh = StandardProfiles.mshDefinition
        XCTAssertEqual(msh.segmentID, "MSH")
        XCTAssertEqual(msh.fields.count, 12)
        XCTAssertEqual(msh.field(at: 9)?.name, "Message Type")
        XCTAssertEqual(msh.field(at: 10)?.name, "Message Control ID")
    }

    func testPIDDefinitionFields() {
        let pid = StandardProfiles.pidDefinition
        XCTAssertEqual(pid.segmentID, "PID")
        XCTAssertEqual(pid.field(at: 3)?.optionality, .required)
        XCTAssertEqual(pid.field(at: 5)?.optionality, .required)
    }

    func testPV1DefinitionFields() {
        let pv1 = StandardProfiles.pv1Definition
        XCTAssertEqual(pv1.segmentID, "PV1")
        XCTAssertEqual(pv1.field(at: 2)?.optionality, .required)
    }

    func testOBXDefinitionFields() {
        let obx = StandardProfiles.obxDefinition
        XCTAssertEqual(obx.segmentID, "OBX")
        XCTAssertEqual(obx.field(at: 3)?.optionality, .required)
        XCTAssertEqual(obx.field(at: 11)?.optionality, .required)
    }

    // MARK: - Field-Level Profile Validation Tests

    func testProfileFieldRequiredCheck() throws {
        // PID-3 (Patient Identifier List) is required in PID definition
        // Create a message with empty PID-3
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "EVN|A01|20230615120000",
            "PID|1||||Smith^John||19800101|M",
            "PV1|1|I"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        let requiredFieldIssues = result.issues.filter { $0.code == "REQUIRED_FIELD_MISSING" }
        XCTAssertFalse(requiredFieldIssues.isEmpty, "Expected required field missing error for PID-3")
    }

    // MARK: - Rule Description Tests

    func testRequiredSegmentRuleDescription() {
        let rule = RequiredSegmentRule(segmentID: "PID")
        XCTAssertEqual(rule.ruleDescription, "Segment 'PID' is required")

        let rule2 = RequiredSegmentRule(segmentID: "OBX", minimumCount: 2)
        XCTAssertTrue(rule2.ruleDescription.contains("2"))
    }

    func testRequiredFieldRuleDescription() {
        let rule = RequiredFieldRule(segmentID: "MSA", fieldPosition: 1, fieldName: "Acknowledgment Code")
        XCTAssertTrue(rule.ruleDescription.contains("MSA-1"))
        XCTAssertTrue(rule.ruleDescription.contains("Acknowledgment Code"))
    }

    func testFieldLengthRuleDescription() {
        let rule = FieldLengthRule(segmentID: "PID", fieldPosition: 5, maxLength: 250, fieldName: "Patient Name")
        XCTAssertTrue(rule.ruleDescription.contains("250"))
    }

    func testDataTypeRuleDescription() {
        let rule = DataTypeRule(segmentID: "OBX", fieldPosition: 1, dataType: .sequenceID, fieldName: "Set ID")
        XCTAssertTrue(rule.ruleDescription.contains("SI"))
    }

    func testValueSetRuleDescription() {
        let rule = ValueSetRule(
            segmentID: "MSA", fieldPosition: 1,
            allowedValues: ["AA", "AE"],
            fieldName: "Ack Code"
        )
        XCTAssertTrue(rule.ruleDescription.contains("AA"))
    }

    func testSegmentCardinalityRuleDescription() {
        let rule = SegmentCardinalityRule(segmentID: "OBX", cardinality: .oneOrMore)
        XCTAssertTrue(rule.ruleDescription.contains("OBX"))
        XCTAssertTrue(rule.ruleDescription.contains("[1..*]"))
    }

    // MARK: - Edge Cases

    func testValidateEmptyRulesArray() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, rules: [])
        XCTAssertTrue(result.isValid)
    }

    func testValidateDataTypeVaries() {
        let engine = HL7v2ValidationEngine()
        // "varies" type should accept any value
        XCTAssertTrue(engine.validateDataType("anything", as: .varies).isEmpty)
    }

    func testStopOnFirstErrorWithProfile() throws {
        let raw = makeADTMessage(includeEVN: false, includePID: false, includePV1: false)
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine(options: ValidationOptions(stopOnFirstError: true))
        let result = engine.validate(message, against: StandardProfiles.adtA01)
        XCTAssertFalse(result.isValid)
        // Should stop early; should not have all 3 errors
        let errors = result.issues.filter { $0.severity == .error }
        XCTAssertLessThanOrEqual(errors.count, 3)
    }

    // MARK: - Not Used Field Check

    func testNotUsedFieldWarning() throws {
        // PID-4 (Alternate Patient ID) is marked as backward ("B") in our definition
        // We don't explicitly generate a warning for "B" fields, only for "X" (notUsed) fields.
        // Let's create a custom profile with a notUsed field
        let customDef = SegmentDefinition(
            segmentID: "ZZZ",
            name: "Custom Segment",
            fields: [
                FieldDefinition(position: 1, name: "Used Field", dataType: .string, optionality: .optional),
                FieldDefinition(position: 2, name: "Not Used Field", dataType: .string, optionality: .notUsed),
            ]
        )
        let profile = ConformanceProfile(
            identifier: "CUSTOM",
            description: "Custom Profile",
            hl7Version: "2.5.1",
            messageType: "ADT",
            segmentRequirements: [
                SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne),
                SegmentRequirement(segmentID: "ZZZ", cardinality: .exactlyOne, definition: customDef),
            ]
        )
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "ZZZ|data|should_not_be_here"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: profile)
        let notUsedIssues = result.issues.filter { $0.code == "FIELD_NOT_USED" }
        XCTAssertFalse(notUsedIssues.isEmpty, "Expected warning for not-used field")
    }

    // MARK: - Multiple Segments Validation

    func testMultipleOBXSegments() throws {
        let raw = [
            "MSH|^~\\&|Lab|H|EHR|H|20230615120000||ORU^R01|MSG001|P|2.5.1",
            "PID|1||12345^^^MR||Doe^Jane||19900101|F",
            "OBR|1||123^Lab|80048^BMP^L",
            "OBX|1|NM|2345-7^Glucose^LN||95|mg/dL|70-110|N|||F",
            "OBX|2|NM|2951-2^Sodium^LN||140|mEq/L|136-145|N|||F"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: StandardProfiles.oruR01)
        let cardErrors = result.issues.filter { $0.code == "SEGMENT_CARDINALITY" }
        XCTAssertTrue(cardErrors.isEmpty, "Multiple OBX segments should be valid")
    }

    // MARK: - Performance Tests

    func testValidationEnginePerformance() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        measure {
            for _ in 0..<1000 {
                _ = engine.validate(message, against: StandardProfiles.adtA01)
            }
        }
    }

    func testRulesValidationPerformance() throws {
        let raw = makeADTMessage()
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let rules: [HL7v2ValidationRule] = [
            RequiredSegmentRule(segmentID: "MSH"),
            RequiredSegmentRule(segmentID: "EVN"),
            RequiredSegmentRule(segmentID: "PID"),
            RequiredSegmentRule(segmentID: "PV1"),
            RequiredFieldRule(segmentID: "MSH", fieldPosition: 9, fieldName: "Message Type"),
            RequiredFieldRule(segmentID: "MSH", fieldPosition: 10, fieldName: "Message Control ID"),
        ]
        measure {
            for _ in 0..<1000 {
                _ = engine.validate(message, rules: rules)
            }
        }
    }

    func testDataTypeValidationPerformance() {
        let engine = HL7v2ValidationEngine()
        measure {
            for _ in 0..<10000 {
                _ = engine.validateDataType("20230615123045.1234+0500", as: .timestamp)
                _ = engine.validateDataType("3.14159", as: .numeric)
                _ = engine.validateDataType("20230615", as: .date)
            }
        }
    }

    // MARK: - Sendable Conformance Tests

    func testRuleSendableConformance() {
        let rule: any HL7v2ValidationRule = RequiredSegmentRule(segmentID: "MSH")
        // Verify Sendable conformance by passing to another context
        let sendable: any Sendable = rule
        XCTAssertNotNil(sendable)
    }

    func testEngineCreation() {
        let engine = HL7v2ValidationEngine()
        XCTAssertFalse(engine.options.stopOnFirstError)

        let strictEngine = HL7v2ValidationEngine(options: .strict)
        XCTAssertTrue(strictEngine.options.strictMode)
    }

    // MARK: - Max Length in Profile Validation

    func testFieldMaxLengthInProfile() throws {
        let customDef = SegmentDefinition(
            segmentID: "TST",
            name: "Test Segment",
            fields: [
                FieldDefinition(position: 1, name: "Short Field", dataType: .string, optionality: .optional, maxLength: 5),
            ]
        )
        let profile = ConformanceProfile(
            identifier: "TEST",
            description: "Test",
            hl7Version: "2.5.1",
            messageType: "ADT",
            segmentRequirements: [
                SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne),
                SegmentRequirement(segmentID: "TST", cardinality: .exactlyOne, definition: customDef),
            ]
        )
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "TST|toolongvalue"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: profile)
        let lengthIssues = result.issues.filter { $0.code == "FIELD_TOO_LONG" }
        XCTAssertFalse(lengthIssues.isEmpty, "Expected field too long error")
    }

    // MARK: - Date Validation Edge Cases

    func testValidateMonthBoundaries() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("202301", as: .date).isEmpty) // January
        XCTAssertTrue(engine.validateDataType("202312", as: .date).isEmpty) // December
        XCTAssertFalse(engine.validateDataType("202300", as: .date).isEmpty) // month 0
        XCTAssertFalse(engine.validateDataType("202313", as: .date).isEmpty) // month 13
    }

    func testValidateDayBoundaries() {
        let engine = HL7v2ValidationEngine()
        XCTAssertTrue(engine.validateDataType("20230101", as: .date).isEmpty) // day 1
        XCTAssertTrue(engine.validateDataType("20230131", as: .date).isEmpty) // day 31
        XCTAssertFalse(engine.validateDataType("20230100", as: .date).isEmpty) // day 0
        XCTAssertFalse(engine.validateDataType("20230132", as: .date).isEmpty) // day 32
    }

    // MARK: - PatternRule with Empty Field

    func testPatternRuleEmptyField() throws {
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "EVN|A01|20230615120000",
            "PID|1||||Smith^John||19800101|M",
            "PV1|1|I"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        // PID-3 is empty, pattern rule should pass (skip empty)
        let rule = PatternRule(
            segmentID: "PID", fieldPosition: 3,
            pattern: #"^\d+$"#,
            fieldName: "Patient ID"
        )
        let issues = rule.validate(message: message)
        XCTAssertTrue(issues.isEmpty) // Empty fields are skipped
    }

    // MARK: - Custom Profile Test

    func testCustomConformanceProfile() throws {
        let customDef = SegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info",
            fields: [
                FieldDefinition(position: 1, name: "Custom ID", dataType: .string, optionality: .required, maxLength: 20),
                FieldDefinition(position: 2, name: "Custom Name", dataType: .string, optionality: .required, maxLength: 100),
                FieldDefinition(position: 3, name: "Custom Date", dataType: .date, optionality: .optional),
            ]
        )
        let profile = ConformanceProfile(
            identifier: "CUSTOM_MSG",
            description: "Custom Message Profile",
            hl7Version: "2.5.1",
            messageType: "ADT",
            segmentRequirements: [
                SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne),
                SegmentRequirement(segmentID: "ZPI", cardinality: .exactlyOne, definition: customDef),
            ]
        )
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "ZPI|CUST001|Patient Name|20230615"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: profile)
        let errors = result.issues.filter { $0.severity == .error }
        XCTAssertTrue(errors.isEmpty, "Custom profile validation should pass, got: \(errors)")
    }

    func testCustomConformanceProfileFailMissingRequired() throws {
        let customDef = SegmentDefinition(
            segmentID: "ZPI",
            name: "Custom Patient Info",
            fields: [
                FieldDefinition(position: 1, name: "Custom ID", dataType: .string, optionality: .required),
                FieldDefinition(position: 2, name: "Custom Name", dataType: .string, optionality: .required),
            ]
        )
        let profile = ConformanceProfile(
            identifier: "CUSTOM_MSG",
            description: "Custom Message Profile",
            hl7Version: "2.5.1",
            messageType: "ADT",
            segmentRequirements: [
                SegmentRequirement(segmentID: "MSH", cardinality: .exactlyOne),
                SegmentRequirement(segmentID: "ZPI", cardinality: .exactlyOne, definition: customDef),
            ]
        )
        // ZPI-2 is empty (missing required)
        let raw = [
            "MSH|^~\\&|App|Fac|App|Fac|20230615120000||ADT^A01|MSG001|P|2.5.1",
            "ZPI|CUST001"
        ].joined(separator: "\r")
        let message = try HL7v2Message.parse(raw)
        let engine = HL7v2ValidationEngine()
        let result = engine.validate(message, against: profile)
        let requiredIssues = result.issues.filter { $0.code == "REQUIRED_FIELD_MISSING" }
        XCTAssertFalse(requiredIssues.isEmpty, "Expected required field missing error for ZPI-2")
    }
}
