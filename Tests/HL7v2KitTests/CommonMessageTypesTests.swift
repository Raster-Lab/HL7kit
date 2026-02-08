import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for Common HL7 v2.x message types: ADT, ORM, ORU, ACK, QRY, QBP
final class CommonMessageTypesTests: XCTestCase {

    // MARK: - Test Helpers

    /// Build a minimal ADT A01 message
    private func buildADTMessage(triggerEvent: String = "A01") throws -> HL7v2Message {
        return try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("TestApp")
                   .sendingFacility("TestFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: triggerEvent)
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: triggerEvent)
                   .field(2, value: "20240207120000")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "12345^^^Hospital^MR")
                   .field(5, value: "Smith^John^A")
                   .field(7, value: "19800101")
                   .field(8, value: "M")
            }
            .segment("PV1") { seg in
                seg.field(1, value: "1")
                   .field(2, value: "I")
                   .field(3, value: "W^389^1")
                   .field(7, value: "1234^Jones^Sarah")
                   .field(19, value: "V001")
            }
            .build()
    }

    /// Build a minimal ORM O01 message
    private func buildORMMessage() throws -> HL7v2Message {
        return try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("LabApp")
                   .sendingFacility("LabFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ORM", triggerEvent: "O01")
                   .messageControlID("ORM001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "98765^^^Hospital^MR")
                   .field(5, value: "Doe^Jane^B")
            }
            .segment("ORC") { seg in
                seg.field(1, value: "NW")
                   .field(2, value: "ORD001")
                   .field(3, value: "FILL001")
                   .field(5, value: "SC")
            }
            .segment("OBR") { seg in
                seg.field(1, value: "1")
                   .field(4, value: "80053^CMP^L")
                   .field(7, value: "20240207120000")
                   .field(16, value: "5678^Johnson^Robert")
            }
            .build()
    }

    /// Build a minimal ORU R01 message
    private func buildORUMessage() throws -> HL7v2Message {
        return try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("LabApp")
                   .sendingFacility("LabFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ORU", triggerEvent: "R01")
                   .messageControlID("ORU001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "12345^^^Hospital^MR")
                   .field(5, value: "Smith^John^A")
            }
            .segment("OBR") { seg in
                seg.field(1, value: "1")
                   .field(4, value: "80053^CMP^L")
                   .field(7, value: "20240207120000")
            }
            .segment("OBX") { seg in
                seg.field(1, value: "1")
                   .field(2, value: "NM")
                   .field(3, value: "2345-7^Glucose^LN")
                   .field(5, value: "95")
                   .field(6, value: "mg/dL")
                   .field(7, value: "70-100")
                   .field(8, value: "N")
                   .field(11, value: "F")
            }
            .segment("OBX") { seg in
                seg.field(1, value: "2")
                   .field(2, value: "NM")
                   .field(3, value: "718-7^Hemoglobin^LN")
                   .field(5, value: "18.5")
                   .field(6, value: "g/dL")
                   .field(7, value: "13.5-17.5")
                   .field(8, value: "H")
                   .field(11, value: "F")
            }
            .build()
    }

    /// Build a minimal ACK message
    private func buildACKMessage(ackCode: String = "AA", originalControlID: String = "MSG001") throws -> HL7v2Message {
        return try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("RecApp")
                   .sendingFacility("RecFac")
                   .receivingApplication("SendApp")
                   .receivingFacility("SendFac")
                   .dateTime("20240207120001")
                   .messageType("ACK", triggerEvent: "")
                   .messageControlID("ACK001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("MSA") { seg in
                seg.field(1, value: ackCode)
                   .field(2, value: originalControlID)
                   .field(3, value: "Message accepted")
            }
            .build()
    }

    /// Build a minimal QRY message
    private func buildQRYMessage() throws -> HL7v2Message {
        return try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("QueryApp")
                   .sendingFacility("QueryFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("QRY", triggerEvent: "Q01")
                   .messageControlID("QRY001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("QRD") { seg in
                seg.field(1, value: "20240207120000")
                   .field(3, value: "R")
                   .field(8, value: "12345^^^Hospital^MR")
            }
            .build()
    }

    /// Build a minimal QBP message
    private func buildQBPMessage() throws -> HL7v2Message {
        return try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("QueryApp")
                   .sendingFacility("QueryFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("QBP", triggerEvent: "Q22")
                   .messageControlID("QBP001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("QPD") { seg in
                seg.field(1, value: "IHE PDQ Query")
                   .field(2, value: "QRY123")
                   .field(3, value: "@PID.3.1^12345")
            }
            .segment("RCP") { seg in
                seg.field(1, value: "I")
                   .field(2, value: "10^RD")
            }
            .build()
    }

    // MARK: - ADT Tests

    func testADTMessageCreation() throws {
        let msg = try buildADTMessage()
        let adt = try ADTMessage(message: msg)
        XCTAssertEqual(ADTMessage.messageTypeCode, "ADT")
        XCTAssertEqual(adt.triggerEvent, "A01")
    }

    func testADTMessageParse() throws {
        let msg = try buildADTMessage()
        let serialized = try msg.serialize()
        let adt = try ADTMessage.parse(serialized)
        XCTAssertEqual(adt.triggerEvent, "A01")
    }

    func testADTSegmentAccessors() throws {
        let msg = try buildADTMessage()
        let adt = try ADTMessage(message: msg)

        XCTAssertNotNil(adt.eventSegment)
        XCTAssertEqual(adt.eventSegment?.segmentID, "EVN")

        XCTAssertNotNil(adt.patientSegment)
        XCTAssertEqual(adt.patientSegment?.segmentID, "PID")

        XCTAssertNotNil(adt.visitSegment)
        XCTAssertEqual(adt.visitSegment?.segmentID, "PV1")

        // Optional segments not present
        XCTAssertNil(adt.additionalDemographics)
        XCTAssertNil(adt.visitAdditionalInfo)
        XCTAssertTrue(adt.nextOfKinSegments.isEmpty)
        XCTAssertTrue(adt.allergySegments.isEmpty)
        XCTAssertTrue(adt.diagnosisSegments.isEmpty)
        XCTAssertTrue(adt.observationSegments.isEmpty)
    }

    func testADTFieldAccessors() throws {
        let msg = try buildADTMessage()
        let adt = try ADTMessage(message: msg)

        XCTAssertTrue(adt.patientIdentifier.contains("12345"))
        XCTAssertTrue(adt.patientName.contains("Smith"))
        XCTAssertEqual(adt.dateOfBirth, "19800101")
        XCTAssertEqual(adt.sex, "M")
        XCTAssertEqual(adt.patientClass, "I")
        XCTAssertTrue(adt.assignedLocation.contains("W"))
        XCTAssertTrue(adt.attendingDoctor.contains("Jones"))
        XCTAssertEqual(adt.visitNumber, "V001")
    }

    func testADTValidationPasses() throws {
        let msg = try buildADTMessage()
        let adt = try ADTMessage(message: msg)
        XCTAssertNoThrow(try adt.validate())
    }

    func testADTValidationDetailed() throws {
        let msg = try buildADTMessage()
        let adt = try ADTMessage(message: msg)
        let result = adt.validateDetailed()
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testADTValidationFailsMissingEVN() throws {
        // Build without EVN segment
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .segment("PV1") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let adt = try ADTMessage(message: msg)
        XCTAssertThrowsError(try adt.validate())

        let result = adt.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("EVN") }))
    }

    func testADTValidationFailsMissingPID() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
            }
            .segment("PV1") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let adt = try ADTMessage(message: msg)
        let result = adt.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("PID") }))
    }

    func testADTValidationFailsMissingPV1() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let adt = try ADTMessage(message: msg)
        let result = adt.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("PV1") }))
    }

    func testADTRejectsNonADTMessage() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ORU", triggerEvent: "R01")
                   .messageControlID("ORU001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertThrowsError(try ADTMessage(message: msg)) { error in
            guard case HL7Error.validationError(let msg, _) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("ADT"))
        }
    }

    func testADTTriggerEvents() throws {
        // Test multiple trigger events
        for event in ["A01", "A02", "A03", "A04", "A08"] {
            let msg = try buildADTMessage(triggerEvent: event)
            let adt = try ADTMessage(message: msg)
            XCTAssertEqual(adt.triggerEvent, event)
        }
    }

    func testADTTriggerEventEnum() {
        XCTAssertEqual(ADTMessage.TriggerEvent.admit.rawValue, "A01")
        XCTAssertEqual(ADTMessage.TriggerEvent.transfer.rawValue, "A02")
        XCTAssertEqual(ADTMessage.TriggerEvent.discharge.rawValue, "A03")
        XCTAssertEqual(ADTMessage.TriggerEvent.register.rawValue, "A04")
        XCTAssertEqual(ADTMessage.TriggerEvent.preAdmit.rawValue, "A05")
        XCTAssertEqual(ADTMessage.TriggerEvent.updatePatientInfo.rawValue, "A08")
        XCTAssertEqual(ADTMessage.TriggerEvent.cancelAdmit.rawValue, "A11")
        XCTAssertEqual(ADTMessage.TriggerEvent.cancelTransfer.rawValue, "A12")
        XCTAssertEqual(ADTMessage.TriggerEvent.cancelDischarge.rawValue, "A13")
    }

    func testADTWithOptionalSegments() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(5, value: "Smith^John")
            }
            .segment("NK1") { seg in
                seg.field(1, value: "1")
                   .field(2, value: "Smith^Jane")
                   .field(3, value: "SPO")
            }
            .segment("NK1") { seg in
                seg.field(1, value: "2")
                   .field(2, value: "Smith^Bob")
                   .field(3, value: "PAR")
            }
            .segment("PV1") { seg in
                seg.field(1, value: "1")
                   .field(2, value: "I")
            }
            .segment("AL1") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "Penicillin")
            }
            .segment("DG1") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "J06.9^URI^ICD10")
            }
            .build()

        let adt = try ADTMessage(message: msg)

        XCTAssertEqual(adt.nextOfKinSegments.count, 2)
        XCTAssertEqual(adt.allergySegments.count, 1)
        XCTAssertEqual(adt.diagnosisSegments.count, 1)
        XCTAssertNoThrow(try adt.validate())
    }

    // MARK: - ORM Tests

    func testORMMessageCreation() throws {
        let msg = try buildORMMessage()
        let orm = try ORMMessage(message: msg)
        XCTAssertEqual(ORMMessage.messageTypeCode, "ORM")
    }

    func testORMMessageParse() throws {
        let msg = try buildORMMessage()
        let serialized = try msg.serialize()
        let orm = try ORMMessage.parse(serialized)
        XCTAssertEqual(orm.orderControl, "NW")
    }

    func testORMSegmentAccessors() throws {
        let msg = try buildORMMessage()
        let orm = try ORMMessage(message: msg)

        XCTAssertNotNil(orm.patientSegment)
        XCTAssertEqual(orm.patientSegment?.segmentID, "PID")

        XCTAssertEqual(orm.orderControlSegments.count, 1)
        XCTAssertEqual(orm.observationRequestSegments.count, 1)

        XCTAssertNil(orm.visitSegment)
        XCTAssertTrue(orm.noteSegments.isEmpty)
        XCTAssertTrue(orm.insuranceSegments.isEmpty)
        XCTAssertTrue(orm.allergySegments.isEmpty)
    }

    func testORMFieldAccessors() throws {
        let msg = try buildORMMessage()
        let orm = try ORMMessage(message: msg)

        XCTAssertEqual(orm.orderControl, "NW")
        XCTAssertTrue(orm.placerOrderNumber.contains("ORD001"))
        XCTAssertTrue(orm.fillerOrderNumber.contains("FILL001"))
        XCTAssertEqual(orm.orderStatus, "SC")
        XCTAssertTrue(orm.universalServiceID.contains("80053"))
        XCTAssertEqual(orm.observationDateTime, "20240207120000")
        XCTAssertTrue(orm.orderingProvider.contains("Johnson"))
        XCTAssertTrue(orm.patientIdentifier.contains("98765"))
    }

    func testORMValidationPasses() throws {
        let msg = try buildORMMessage()
        let orm = try ORMMessage(message: msg)
        XCTAssertNoThrow(try orm.validate())
    }

    func testORMValidationFailsMissingORC() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ORM", triggerEvent: "O01")
                   .messageControlID("ORM001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let orm = try ORMMessage(message: msg)
        let result = orm.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("ORC") }))
    }

    func testORMValidationFailsMissingPID() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ORM", triggerEvent: "O01")
                   .messageControlID("ORM001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("ORC") { seg in
                seg.field(1, value: "NW")
            }
            .build()

        let orm = try ORMMessage(message: msg)
        let result = orm.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("PID") }))
    }

    func testORMRejectsNonORMMessage() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertThrowsError(try ORMMessage(message: msg))
    }

    func testORMWithMultipleOrders() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ORM", triggerEvent: "O01")
                   .messageControlID("ORM001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .segment("ORC") { seg in
                seg.field(1, value: "NW")
                   .field(2, value: "ORD001")
            }
            .segment("OBR") { seg in
                seg.field(1, value: "1")
                   .field(4, value: "80053^CMP^L")
            }
            .segment("ORC") { seg in
                seg.field(1, value: "NW")
                   .field(2, value: "ORD002")
            }
            .segment("OBR") { seg in
                seg.field(1, value: "2")
                   .field(4, value: "85025^CBC^L")
            }
            .build()

        let orm = try ORMMessage(message: msg)
        XCTAssertEqual(orm.orderControlSegments.count, 2)
        XCTAssertEqual(orm.observationRequestSegments.count, 2)
        XCTAssertNoThrow(try orm.validate())
    }

    // MARK: - ORU Tests

    func testORUMessageCreation() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)
        XCTAssertEqual(ORUMessage.messageTypeCode, "ORU")
    }

    func testORUMessageParse() throws {
        let msg = try buildORUMessage()
        let serialized = try msg.serialize()
        let oru = try ORUMessage.parse(serialized)
        XCTAssertTrue(oru.universalServiceID.contains("80053"))
    }

    func testORUSegmentAccessors() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)

        XCTAssertNotNil(oru.patientSegment)
        XCTAssertEqual(oru.patientSegment?.segmentID, "PID")
        XCTAssertNil(oru.visitSegment)

        XCTAssertEqual(oru.observationRequestSegments.count, 1)
        XCTAssertEqual(oru.observationSegments.count, 2)
        XCTAssertTrue(oru.noteSegments.isEmpty)
    }

    func testORUFieldAccessors() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)

        XCTAssertTrue(oru.universalServiceID.contains("80053"))
        XCTAssertEqual(oru.observationDateTime, "20240207120000")
        XCTAssertTrue(oru.patientIdentifier.contains("12345"))
        XCTAssertTrue(oru.patientName.contains("Smith"))
    }

    func testORUObservationResults() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)

        let observations = oru.observations
        XCTAssertEqual(observations.count, 2)

        // First observation: Glucose
        let glucose = observations[0]
        XCTAssertEqual(glucose.setID, "1")
        XCTAssertEqual(glucose.valueType, "NM")
        XCTAssertTrue(glucose.identifier.contains("2345-7"))
        XCTAssertEqual(glucose.value, "95")
        XCTAssertEqual(glucose.units, "mg/dL")
        XCTAssertEqual(glucose.referenceRange, "70-100")
        XCTAssertEqual(glucose.abnormalFlags, "N")
        XCTAssertEqual(glucose.resultStatus, "F")

        // Second observation: Hemoglobin (high)
        let hgb = observations[1]
        XCTAssertEqual(hgb.setID, "2")
        XCTAssertEqual(hgb.valueType, "NM")
        XCTAssertTrue(hgb.identifier.contains("718-7"))
        XCTAssertEqual(hgb.value, "18.5")
        XCTAssertEqual(hgb.units, "g/dL")
        XCTAssertEqual(hgb.abnormalFlags, "H")
        XCTAssertEqual(hgb.resultStatus, "F")
    }

    func testORUValidationPasses() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)
        XCTAssertNoThrow(try oru.validate())
    }

    func testORUValidationDetailedPasses() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)
        let result = oru.validateDetailed()
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testORUValidationFailsMissingOBR() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ORU", triggerEvent: "R01")
                   .messageControlID("ORU001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .segment("OBX") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let oru = try ORUMessage(message: msg)
        let result = oru.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("OBR") }))
    }

    func testORUValidationFailsMissingOBX() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ORU", triggerEvent: "R01")
                   .messageControlID("ORU001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .segment("OBR") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let oru = try ORUMessage(message: msg)
        let result = oru.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("OBX") }))
    }

    func testORURejectsNonORUMessage() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertThrowsError(try ORUMessage(message: msg))
    }

    // MARK: - ACK Tests

    func testACKMessageCreation() throws {
        let msg = try buildACKMessage()
        let ack = try ACKMessage(message: msg)
        XCTAssertEqual(ACKMessage.messageTypeCode, "ACK")
    }

    func testACKMessageParse() throws {
        let msg = try buildACKMessage()
        let serialized = try msg.serialize()
        let ack = try ACKMessage.parse(serialized)
        XCTAssertEqual(ack.acknowledgmentCode, "AA")
    }

    func testACKSegmentAccessors() throws {
        let msg = try buildACKMessage()
        let ack = try ACKMessage(message: msg)

        XCTAssertNotNil(ack.acknowledgmentSegment)
        XCTAssertEqual(ack.acknowledgmentSegment?.segmentID, "MSA")
        XCTAssertTrue(ack.errorSegments.isEmpty)
    }

    func testACKFieldAccessors() throws {
        let msg = try buildACKMessage()
        let ack = try ACKMessage(message: msg)

        XCTAssertEqual(ack.acknowledgmentCode, "AA")
        XCTAssertEqual(ack.typedAcknowledgmentCode, .accept)
        XCTAssertEqual(ack.acknowledgedMessageControlID, "MSG001")
        XCTAssertEqual(ack.textMessage, "Message accepted")
    }

    func testACKStatusHelpers() throws {
        // Test accept
        let acceptMsg = try buildACKMessage(ackCode: "AA")
        let accept = try ACKMessage(message: acceptMsg)
        XCTAssertTrue(accept.isAccepted)
        XCTAssertFalse(accept.isError)
        XCTAssertFalse(accept.isRejected)

        // Test error
        let errorMsg = try buildACKMessage(ackCode: "AE")
        let ackError = try ACKMessage(message: errorMsg)
        XCTAssertFalse(ackError.isAccepted)
        XCTAssertTrue(ackError.isError)
        XCTAssertFalse(ackError.isRejected)

        // Test reject
        let rejectMsg = try buildACKMessage(ackCode: "AR")
        let reject = try ACKMessage(message: rejectMsg)
        XCTAssertFalse(reject.isAccepted)
        XCTAssertFalse(reject.isError)
        XCTAssertTrue(reject.isRejected)
    }

    func testACKCommitCodes() throws {
        // Test commit accept
        let caMsg = try buildACKMessage(ackCode: "CA")
        let ca = try ACKMessage(message: caMsg)
        XCTAssertTrue(ca.isAccepted)
        XCTAssertEqual(ca.typedAcknowledgmentCode, .commitAccept)

        // Test commit error
        let ceMsg = try buildACKMessage(ackCode: "CE")
        let ce = try ACKMessage(message: ceMsg)
        XCTAssertTrue(ce.isError)
        XCTAssertEqual(ce.typedAcknowledgmentCode, .commitError)

        // Test commit reject
        let crMsg = try buildACKMessage(ackCode: "CR")
        let cr = try ACKMessage(message: crMsg)
        XCTAssertTrue(cr.isRejected)
        XCTAssertEqual(cr.typedAcknowledgmentCode, .commitReject)
    }

    func testACKValidationPasses() throws {
        let msg = try buildACKMessage()
        let ack = try ACKMessage(message: msg)
        XCTAssertNoThrow(try ack.validate())
    }

    func testACKValidationFailsMissingMSA() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ACK", triggerEvent: "")
                   .messageControlID("ACK001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let ack = try ACKMessage(message: msg)
        let result = ack.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("MSA") }))
    }

    func testACKValidationFailsEmptyAckCode() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ACK", triggerEvent: "")
                   .messageControlID("ACK001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("MSA") { seg in
                seg.field(2, value: "MSG001")
            }
            .build()

        let ack = try ACKMessage(message: msg)
        let result = ack.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("acknowledgment code") }))
    }

    func testACKValidationFailsEmptyControlID() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ACK", triggerEvent: "")
                   .messageControlID("ACK001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("MSA") { seg in
                seg.field(1, value: "AA")
            }
            .build()

        let ack = try ACKMessage(message: msg)
        let result = ack.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("message control ID") }))
    }

    func testACKRejectsNonACKMessage() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertThrowsError(try ACKMessage(message: msg))
    }

    func testACKRespondFactory() throws {
        let originalMsg = try buildADTMessage()
        let ack = try ACKMessage.respond(
            to: originalMsg,
            code: .accept,
            textMessage: "Processed successfully",
            sendingApp: "RecApp",
            sendingFacility: "RecFac",
            controlID: "ACK001"
        )

        XCTAssertEqual(ack.acknowledgmentCode, "AA")
        XCTAssertEqual(ack.acknowledgedMessageControlID, "ADT001")
        XCTAssertTrue(ack.isAccepted)
    }

    func testACKRespondWithError() throws {
        let originalMsg = try buildADTMessage()
        let ack = try ACKMessage.respond(
            to: originalMsg,
            code: .error,
            textMessage: "Validation failed"
        )

        XCTAssertEqual(ack.acknowledgmentCode, "AE")
        XCTAssertTrue(ack.isError)
    }

    func testACKAcknowledgmentCodeEnum() {
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.accept.rawValue, "AA")
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.error.rawValue, "AE")
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.reject.rawValue, "AR")
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.commitAccept.rawValue, "CA")
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.commitError.rawValue, "CE")
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.commitReject.rawValue, "CR")
        XCTAssertEqual(ACKMessage.AcknowledgmentCode.allCases.count, 6)
    }

    func testACKWithErrorSegments() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ACK", triggerEvent: "")
                   .messageControlID("ACK001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("MSA") { seg in
                seg.field(1, value: "AE")
                   .field(2, value: "MSG001")
                   .field(3, value: "Segment error")
            }
            .segment("ERR") { seg in
                seg.field(1, value: "PID^1^3")
                   .field(3, value: "101^Required field missing^HL70357")
            }
            .build()

        let ack = try ACKMessage(message: msg)
        XCTAssertEqual(ack.errorSegments.count, 1)
        XCTAssertTrue(ack.isError)
    }

    // MARK: - QRY Tests

    func testQRYMessageCreation() throws {
        let msg = try buildQRYMessage()
        let qry = try QRYMessage(message: msg)
        XCTAssertEqual(QRYMessage.messageTypeCode, "QRY")
    }

    func testQRYMessageParse() throws {
        let msg = try buildQRYMessage()
        let serialized = try msg.serialize()
        let qry = try QRYMessage.parse(serialized)
        XCTAssertEqual(qry.queryDateTime, "20240207120000")
    }

    func testQRYSegmentAccessors() throws {
        let msg = try buildQRYMessage()
        let qry = try QRYMessage(message: msg)

        XCTAssertNotNil(qry.queryDefinition)
        XCTAssertEqual(qry.queryDefinition?.segmentID, "QRD")
        XCTAssertNil(qry.queryFilter)
    }

    func testQRYFieldAccessors() throws {
        let msg = try buildQRYMessage()
        let qry = try QRYMessage(message: msg)

        XCTAssertEqual(qry.queryDateTime, "20240207120000")
        XCTAssertEqual(qry.queryFormatCode, "R")
        XCTAssertTrue(qry.whoSubjectFilter.contains("12345"))
    }

    func testQRYValidationPasses() throws {
        let msg = try buildQRYMessage()
        let qry = try QRYMessage(message: msg)
        XCTAssertNoThrow(try qry.validate())
    }

    func testQRYValidationFailsMissingQRD() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("QRY", triggerEvent: "Q01")
                   .messageControlID("QRY001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let qry = try QRYMessage(message: msg)
        let result = qry.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("QRD") }))
    }

    func testQRYRejectsNonQRYMessage() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertThrowsError(try QRYMessage(message: msg))
    }

    func testQRYWithFilter() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("QRY", triggerEvent: "Q01")
                   .messageControlID("QRY001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("QRD") { seg in
                seg.field(1, value: "20240207120000")
                   .field(3, value: "R")
                   .field(8, value: "12345")
            }
            .segment("QRF") { seg in
                seg.field(1, value: "PID")
                   .field(2, value: "20240101")
                   .field(3, value: "20240207")
            }
            .build()

        let qry = try QRYMessage(message: msg)
        XCTAssertNotNil(qry.queryFilter)
        XCTAssertEqual(qry.queryFilter?.segmentID, "QRF")
        XCTAssertNoThrow(try qry.validate())
    }

    // MARK: - QBP Tests

    func testQBPMessageCreation() throws {
        let msg = try buildQBPMessage()
        let qbp = try QBPMessage(message: msg)
        XCTAssertEqual(QBPMessage.messageTypeCode, "QBP")
    }

    func testQBPMessageParse() throws {
        let msg = try buildQBPMessage()
        let serialized = try msg.serialize()
        let qbp = try QBPMessage.parse(serialized)
        XCTAssertTrue(qbp.messageQueryName.contains("IHE PDQ Query"))
    }

    func testQBPSegmentAccessors() throws {
        let msg = try buildQBPMessage()
        let qbp = try QBPMessage(message: msg)

        XCTAssertNotNil(qbp.queryParameterDefinition)
        XCTAssertEqual(qbp.queryParameterDefinition?.segmentID, "QPD")

        XCTAssertNotNil(qbp.responseControlParameter)
        XCTAssertEqual(qbp.responseControlParameter?.segmentID, "RCP")

        XCTAssertNil(qbp.continuationPointer)
    }

    func testQBPFieldAccessors() throws {
        let msg = try buildQBPMessage()
        let qbp = try QBPMessage(message: msg)

        XCTAssertTrue(qbp.messageQueryName.contains("IHE PDQ Query"))
        XCTAssertEqual(qbp.queryTag, "QRY123")
        XCTAssertEqual(qbp.queryParameters.count, 1)
        XCTAssertTrue(qbp.queryParameters[0].contains("12345"))
    }

    func testQBPValidationPasses() throws {
        let msg = try buildQBPMessage()
        let qbp = try QBPMessage(message: msg)
        XCTAssertNoThrow(try qbp.validate())
    }

    func testQBPValidationFailsMissingQPD() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("QBP", triggerEvent: "Q22")
                   .messageControlID("QBP001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let qbp = try QBPMessage(message: msg)
        let result = qbp.validateDetailed()
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.failures.contains(where: { $0.contains("QPD") }))
    }

    func testQBPRejectsNonQBPMessage() throws {
        let msg = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADT001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertThrowsError(try QBPMessage(message: msg))
    }

    // MARK: - MessageTemplate Extension Tests

    func testQRYTemplate() throws {
        let builder = MessageTemplate.qry(
            triggerEvent: "Q01",
            sendingApp: "QueryApp",
            controlID: "QRY001"
        )
        // Add QRD for validation
        let msg = try builder
            .segment("QRD") { seg in
                seg.field(1, value: "20240207120000")
            }
            .build()

        XCTAssertTrue(msg.messageType().contains("QRY"))
    }

    func testQBPTemplate() throws {
        let builder = MessageTemplate.qbp(
            triggerEvent: "Q22",
            sendingApp: "QueryApp",
            controlID: "QBP001"
        )
        let msg = try builder
            .segment("QPD") { seg in
                seg.field(1, value: "Find Candidates")
            }
            .build()

        XCTAssertTrue(msg.messageType().contains("QBP"))
    }

    // MARK: - MessageValidationResult Tests

    func testMessageValidationResultEquatable() {
        let r1 = MessageValidationResult(isValid: true, failures: [])
        let r2 = MessageValidationResult(isValid: true, failures: [])
        let r3 = MessageValidationResult(isValid: false, failures: ["test"])
        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }

    // MARK: - ObservationResult Tests

    func testObservationResultEquatable() {
        let obs1 = ObservationResult(
            setID: "1", valueType: "NM", identifier: "test",
            value: "95", units: "mg/dL", referenceRange: "70-100",
            abnormalFlags: "N", resultStatus: "F"
        )
        let obs2 = ObservationResult(
            setID: "1", valueType: "NM", identifier: "test",
            value: "95", units: "mg/dL", referenceRange: "70-100",
            abnormalFlags: "N", resultStatus: "F"
        )
        XCTAssertEqual(obs1, obs2)
    }

    // MARK: - Cross-type Tests

    func testTypedMessageProtocol() throws {
        let adtMsg = try buildADTMessage()
        let adt = try ADTMessage(message: adtMsg)

        let ormMsg = try buildORMMessage()
        let orm = try ORMMessage(message: ormMsg)

        let oruMsg = try buildORUMessage()
        let oru = try ORUMessage(message: oruMsg)

        let ackMsg = try buildACKMessage()
        let ack = try ACKMessage(message: ackMsg)

        let qryMsg = try buildQRYMessage()
        let qry = try QRYMessage(message: qryMsg)

        let qbpMsg = try buildQBPMessage()
        let qbp = try QBPMessage(message: qbpMsg)

        // All conform to HL7v2TypedMessage
        XCTAssertEqual(ADTMessage.messageTypeCode, "ADT")
        XCTAssertEqual(ORMMessage.messageTypeCode, "ORM")
        XCTAssertEqual(ORUMessage.messageTypeCode, "ORU")
        XCTAssertEqual(ACKMessage.messageTypeCode, "ACK")
        XCTAssertEqual(QRYMessage.messageTypeCode, "QRY")
        XCTAssertEqual(QBPMessage.messageTypeCode, "QBP")

        // All have valid underlying messages
        XCTAssertTrue(adt.message.segmentCount > 0)
        XCTAssertTrue(orm.message.segmentCount > 0)
        XCTAssertTrue(oru.message.segmentCount > 0)
        XCTAssertTrue(ack.message.segmentCount > 0)
        XCTAssertTrue(qry.message.segmentCount > 0)
        XCTAssertTrue(qbp.message.segmentCount > 0)
    }

    func testRoundTripAllMessageTypes() throws {
        // ADT
        let adtMsg = try buildADTMessage()
        let adtSerialized = try adtMsg.serialize()
        let adtReparsed = try ADTMessage.parse(adtSerialized)
        XCTAssertNoThrow(try adtReparsed.validate())

        // ORM
        let ormMsg = try buildORMMessage()
        let ormSerialized = try ormMsg.serialize()
        let ormReparsed = try ORMMessage.parse(ormSerialized)
        XCTAssertNoThrow(try ormReparsed.validate())

        // ORU
        let oruMsg = try buildORUMessage()
        let oruSerialized = try oruMsg.serialize()
        let oruReparsed = try ORUMessage.parse(oruSerialized)
        XCTAssertNoThrow(try oruReparsed.validate())

        // ACK
        let ackMsg = try buildACKMessage()
        let ackSerialized = try ackMsg.serialize()
        let ackReparsed = try ACKMessage.parse(ackSerialized)
        XCTAssertNoThrow(try ackReparsed.validate())

        // QRY
        let qryMsg = try buildQRYMessage()
        let qrySerialized = try qryMsg.serialize()
        let qryReparsed = try QRYMessage.parse(qrySerialized)
        XCTAssertNoThrow(try qryReparsed.validate())

        // QBP
        let qbpMsg = try buildQBPMessage()
        let qbpSerialized = try qbpMsg.serialize()
        let qbpReparsed = try QBPMessage.parse(qbpSerialized)
        XCTAssertNoThrow(try qbpReparsed.validate())
    }

    // MARK: - Performance Tests

    func testADTCreationPerformance() throws {
        measure {
            for _ in 0..<100 {
                _ = try? buildADTMessage()
            }
        }
    }

    func testORUObservationAccessPerformance() throws {
        let msg = try buildORUMessage()
        let oru = try ORUMessage(message: msg)

        measure {
            for _ in 0..<1000 {
                _ = oru.observations
            }
        }
    }

    func testValidationPerformance() throws {
        let msg = try buildADTMessage()
        let adt = try ADTMessage(message: msg)

        measure {
            for _ in 0..<1000 {
                _ = adt.validateDetailed()
            }
        }
    }
}
