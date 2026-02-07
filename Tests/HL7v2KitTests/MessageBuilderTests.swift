import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests for HL7v2MessageBuilder, SegmentBuilder, MSHSegmentBuilder, and MessageTemplate
final class MessageBuilderTests: XCTestCase {

    // MARK: - Basic Message Builder Tests

    func testBuildMinimalMessage() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("TestApp")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 1)
        XCTAssertEqual(message.messageHeader.segmentID, "MSH")
        XCTAssertEqual(message.messageControlID(), "MSG001")
        XCTAssertEqual(message.version(), "2.5.1")
    }

    func testBuildMessageWithMultipleSegments() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("SendApp")
                   .sendingFacility("SendFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
                   .field(2, value: "20240207120000")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "12345^^^Hospital^MR")
                   .field(5, value: "Smith^John^A")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 3)
        XCTAssertEqual(message[0]?.segmentID, "MSH")
        XCTAssertEqual(message[1]?.segmentID, "EVN")
        XCTAssertEqual(message[2]?.segmentID, "PID")
    }

    func testBuildMessagePreservesEncodingCharacters() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertEqual(message.encodingCharacters.fieldSeparator, "|")
        XCTAssertEqual(message.encodingCharacters.componentSeparator, "^")
        XCTAssertEqual(message.encodingCharacters.repetitionSeparator, "~")
        XCTAssertEqual(message.encodingCharacters.escapeCharacter, "\\")
        XCTAssertEqual(message.encodingCharacters.subcomponentSeparator, "&")
    }

    func testBuildMessageRoundTrip() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("SendApp")
                   .sendingFacility("SendFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "12345")
                   .field(5, value: "Smith^John")
            }
            .build()

        // Serialize and re-parse
        let serialized = try message.serialize()
        let reparsed = try HL7v2Message.parse(serialized)

        XCTAssertEqual(reparsed.segmentCount, message.segmentCount)
        XCTAssertEqual(reparsed.messageType(), message.messageType())
        XCTAssertEqual(reparsed.messageControlID(), message.messageControlID())
        XCTAssertEqual(reparsed.version(), message.version())
    }

    // MARK: - Error Cases

    func testBuildEmptyMessageThrows() {
        let builder = HL7v2MessageBuilder()

        XCTAssertThrowsError(try builder.build()) { error in
            guard case HL7Error.validationError(let message, _) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("at least one segment"))
        }
    }

    func testBuildMessageWithoutMSHThrows() {
        let builder = HL7v2MessageBuilder()
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }

        XCTAssertThrowsError(try builder.build()) { error in
            guard case HL7Error.validationError(let message, _) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("start with MSH"))
        }
    }

    // MARK: - MSH Segment Builder Tests

    func testMSHSendingApplication() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("MyApp")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[2].value.value.raw, "MyApp")
    }

    func testMSHSendingFacility() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingFacility("MyFacility")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[3].value.value.raw, "MyFacility")
    }

    func testMSHReceivingApplication() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.receivingApplication("RecApp")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[4].value.value.raw, "RecApp")
    }

    func testMSHReceivingFacility() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.receivingFacility("RecFac")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[5].value.value.raw, "RecFac")
    }

    func testMSHDateTimeString() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[6].value.value.raw, "20240207120000")
    }

    func testMSHDateTimeDate() throws {
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01 00:00:00 UTC
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.dateTime(date)
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[6].value.value.raw, "19700101000000")
    }

    func testMSHSecurity() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.security("SEC123")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[7].value.value.raw, "SEC123")
    }

    func testMSHMessageType() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertEqual(message.messageType(), "ADT^A01")
    }

    func testMSHMessageTypeWithStructure() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01", messageStructure: "ADT_A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        let msgType = msh[8]
        XCTAssertEqual(msgType[0].value.raw, "ADT")
        XCTAssertEqual(msgType[1].value.raw, "A01")
        XCTAssertEqual(msgType[2].value.raw, "ADT_A01")
    }

    func testMSHProcessingID() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("T")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[10].value.value.raw, "T")
    }

    func testMSHVersion() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.8")
            }
            .build()

        XCTAssertEqual(message.version(), "2.8")
    }

    func testMSHFieldMethod() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
                   .field(13, value: "T1234")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[12].value.value.raw, "T1234")
    }

    func testMSHAllFieldsTogether() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("SendApp")
                   .sendingFacility("SendFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let msh = message.messageHeader
        XCTAssertEqual(msh[2].value.value.raw, "SendApp")
        XCTAssertEqual(msh[3].value.value.raw, "SendFac")
        XCTAssertEqual(msh[4].value.value.raw, "RecApp")
        XCTAssertEqual(msh[5].value.value.raw, "RecFac")
        XCTAssertEqual(msh[6].value.value.raw, "20240207120000")
        XCTAssertEqual(message.messageType(), "ADT^A01")
        XCTAssertEqual(message.messageControlID(), "MSG001")
        XCTAssertEqual(msh[10].value.value.raw, "P")
        XCTAssertEqual(message.version(), "2.5.1")
    }

    // MARK: - Segment Builder Tests

    func testSegmentBuilderField() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "12345")
            }
            .build()

        let pidSegments = message.segments(withID: "PID")
        XCTAssertEqual(pidSegments.count, 1)
        XCTAssertEqual(pidSegments[0][0].value.value.raw, "1")
        XCTAssertEqual(pidSegments[0][2].value.value.raw, "12345")
    }

    func testSegmentBuilderFieldWithComponents() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(5, components: ["Smith", "John", "A"])
            }
            .build()

        let pid = message.segments(withID: "PID")[0]
        XCTAssertEqual(pid[4][0].value.raw, "Smith")
        XCTAssertEqual(pid[4][1].value.raw, "John")
        XCTAssertEqual(pid[4][2].value.raw, "A")
    }

    func testSegmentBuilderFieldWithSubcomponents() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(3, components: [["12345", "check"], ["Hospital"], [""], ["MR"]])
            }
            .build()

        let pid = message.segments(withID: "PID")[0]
        // First component has two subcomponents
        XCTAssertEqual(pid[2][0][0].raw, "12345")
        XCTAssertEqual(pid[2][0][1].raw, "check")
        // Second component
        XCTAssertEqual(pid[2][1].value.raw, "Hospital")
        // Fourth component
        XCTAssertEqual(pid[2][3].value.raw, "MR")
    }

    func testSegmentBuilderFieldWithRepetitions() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(13, repetitions: ["555-1234", "555-5678"])
            }
            .build()

        let pid = message.segments(withID: "PID")[0]
        XCTAssertEqual(pid[12].repetitionCount, 2)
        XCTAssertEqual(pid[12].repetition(at: 0).first?.value.raw, "555-1234")
        XCTAssertEqual(pid[12].repetition(at: 1).first?.value.raw, "555-5678")
    }

    func testSegmentBuilderWithEmptyFields() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(5, value: "Smith^John")
            }
            .build()

        let pid = message.segments(withID: "PID")[0]
        // Fields 2-4 should be empty
        XCTAssertTrue(pid[1].isEmpty)
        XCTAssertTrue(pid[2].isEmpty)
        XCTAssertTrue(pid[3].isEmpty)
        // Field 5 should be populated
        XCTAssertFalse(pid[4].isEmpty)
    }

    // MARK: - Raw Segment Tests

    func testRawSegment() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .rawSegment("PID|1||12345^^^Hospital^MR||Smith^John^A||19800101|M")
            .build()

        let pid = message.segments(withID: "PID")[0]
        XCTAssertEqual(pid[0].value.value.raw, "1")
        XCTAssertEqual(pid[2][0].value.raw, "12345")
        XCTAssertEqual(pid[4][0].value.raw, "Smith")
        XCTAssertEqual(pid[4][1].value.raw, "John")
        XCTAssertEqual(pid[6].value.value.raw, "19800101")
        XCTAssertEqual(pid[7].value.value.raw, "M")
    }

    // MARK: - Complex Message Construction Tests

    func testBuildFullADTMessage() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("SendApp")
                   .sendingFacility("SendFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
                   .field(2, value: "20240207120000")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "12345^^^Hospital^MR")
                   .field(5, components: ["Smith", "John", "A"])
                   .field(7, value: "19800101")
                   .field(8, value: "M")
                   .field(11, components: ["123 Main St", "", "Boston", "MA", "02101"])
            }
            .segment("PV1") { seg in
                seg.field(1, value: "1")
                   .field(2, value: "I")
                   .field(3, value: "4E^401^B^Hospital")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 4)
        XCTAssertEqual(message.messageType(), "ADT^A01")
        XCTAssertEqual(message.messageControlID(), "MSG001")
        XCTAssertEqual(message.version(), "2.5.1")

        // Verify PID
        let pid = message.segments(withID: "PID")[0]
        XCTAssertEqual(pid[4][0].value.raw, "Smith")
        XCTAssertEqual(pid[4][1].value.raw, "John")
        XCTAssertEqual(pid[6].value.value.raw, "19800101")
        XCTAssertEqual(pid[7].value.value.raw, "M")

        // Verify PV1
        let pv1 = message.segments(withID: "PV1")[0]
        XCTAssertEqual(pv1[1].value.value.raw, "I")
    }

    func testBuildORUMessage() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("Lab")
                   .sendingFacility("LabFac")
                   .receivingApplication("EMR")
                   .receivingFacility("Hospital")
                   .dateTime("20240207120000")
                   .messageType("ORU", triggerEvent: "R01")
                   .messageControlID("MSG002")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "67890^^^Hospital^MR")
                   .field(5, components: ["Jones", "Jane", "B"])
                   .field(7, value: "19850615")
                   .field(8, value: "F")
            }
            .segment("OBR") { seg in
                seg.field(1, value: "1")
                   .field(3, value: "LAB123")
                   .field(4, value: "CBC^Complete Blood Count")
            }
            .segment("OBX") { seg in
                seg.field(1, value: "1")
                   .field(2, value: "NM")
                   .field(3, value: "WBC^White Blood Count")
                   .field(5, value: "7.5")
                   .field(6, value: "10*3/uL")
                   .field(7, value: "4.5-11.0")
                   .field(8, value: "N")
                   .field(11, value: "F")
            }
            .segment("OBX") { seg in
                seg.field(1, value: "2")
                   .field(2, value: "NM")
                   .field(3, value: "RBC^Red Blood Count")
                   .field(5, value: "4.8")
                   .field(6, value: "10*6/uL")
                   .field(7, value: "4.2-5.4")
                   .field(8, value: "N")
                   .field(11, value: "F")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 5)
        XCTAssertEqual(message.messageType(), "ORU^R01")

        let obxSegments = message.segments(withID: "OBX")
        XCTAssertEqual(obxSegments.count, 2)
        XCTAssertEqual(obxSegments[0][4].value.value.raw, "7.5")
        XCTAssertEqual(obxSegments[1][4].value.value.raw, "4.8")
    }

    // MARK: - Message Template Tests

    func testADTTemplate() throws {
        let message = try MessageTemplate.adt(
            triggerEvent: "A01",
            sendingApp: "TestApp",
            sendingFacility: "TestFac",
            receivingApp: "RecApp",
            receivingFacility: "RecFac",
            controlID: "CTRL001",
            version: "2.5.1"
        ).build()

        XCTAssertEqual(message.messageType(), "ADT^A01")
        XCTAssertEqual(message.messageControlID(), "CTRL001")
        XCTAssertEqual(message.version(), "2.5.1")

        let msh = message.messageHeader
        XCTAssertEqual(msh[2].value.value.raw, "TestApp")
        XCTAssertEqual(msh[3].value.value.raw, "TestFac")
        XCTAssertEqual(msh[4].value.value.raw, "RecApp")
        XCTAssertEqual(msh[5].value.value.raw, "RecFac")
    }

    func testADTTemplateWithAdditionalSegments() throws {
        let message = try MessageTemplate.adt(
            triggerEvent: "A01",
            sendingApp: "TestApp",
            controlID: "CTRL001"
        )
        .segment("PID") { seg in
            seg.field(1, value: "1")
               .field(5, components: ["Smith", "John"])
        }
        .build()

        XCTAssertEqual(message.segmentCount, 2)
        XCTAssertEqual(message.messageType(), "ADT^A01")

        let pid = message.segments(withID: "PID")[0]
        XCTAssertEqual(pid[4][0].value.raw, "Smith")
    }

    func testORUTemplate() throws {
        let message = try MessageTemplate.oru(
            sendingApp: "Lab",
            sendingFacility: "LabFac",
            receivingApp: "EMR",
            receivingFacility: "Hospital",
            controlID: "CTRL002",
            version: "2.5.1"
        ).build()

        XCTAssertEqual(message.messageType(), "ORU^R01")
        XCTAssertEqual(message.messageControlID(), "CTRL002")
        XCTAssertEqual(message.version(), "2.5.1")
    }

    func testORMTemplate() throws {
        let message = try MessageTemplate.orm(
            sendingApp: "OrderApp",
            controlID: "CTRL003"
        ).build()

        XCTAssertEqual(message.messageType(), "ORM^O01")
        XCTAssertEqual(message.messageControlID(), "CTRL003")
    }

    func testACKTemplate() throws {
        // Create an original message to acknowledge
        let original = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("OrigApp")
                   .sendingFacility("OrigFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ORIG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let ack = try MessageTemplate.ack(
            originalMessage: original,
            ackCode: "AA",
            sendingApp: "AckApp",
            sendingFacility: "AckFac",
            controlID: "ACK001"
        ).build()

        XCTAssertEqual(ack.messageType(), "ACK^")
        XCTAssertEqual(ack.messageControlID(), "ACK001")

        // MSA segment
        let msa = ack.segments(withID: "MSA")
        XCTAssertEqual(msa.count, 1)
        XCTAssertEqual(msa[0][0].value.value.raw, "AA")
        XCTAssertEqual(msa[0][1].value.value.raw, "ORIG001")

        // Receiving application should be the original sending application
        let msh = ack.messageHeader
        XCTAssertEqual(msh[4].value.value.raw, "OrigApp")
        XCTAssertEqual(msh[5].value.value.raw, "OrigFac")
    }

    func testACKTemplateWithErrorCode() throws {
        let original = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("OrigApp")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ORIG002")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let ack = try MessageTemplate.ack(
            originalMessage: original,
            ackCode: "AE",
            sendingApp: "AckApp",
            controlID: "ACK002"
        ).build()

        let msa = ack.segments(withID: "MSA")
        XCTAssertEqual(msa[0][0].value.value.raw, "AE")
    }

    func testACKTemplateWithTextMessage() throws {
        let original = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("OrigApp")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ORIG003")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        let ack = try MessageTemplate.ack(
            originalMessage: original,
            ackCode: "AR",
            sendingApp: "AckApp",
            controlID: "ACK003",
            textMessage: "Invalid message format"
        ).build()

        let msa = ack.segments(withID: "MSA")
        XCTAssertEqual(msa[0][0].value.value.raw, "AR")
        XCTAssertEqual(msa[0][1].value.value.raw, "ORIG003")
        XCTAssertEqual(msa[0][2].value.value.raw, "Invalid message format")
    }

    // MARK: - Static Builder Factory Tests

    func testStaticBuilderFactory() throws {
        let message = try HL7v2Message.builder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 1)
        XCTAssertEqual(message.messageType(), "ADT^A01")
    }

    // MARK: - Custom Encoding Characters Tests

    func testCustomEncodingCharacters() throws {
        let customEnc = EncodingCharacters(
            fieldSeparator: "|",
            componentSeparator: "^",
            repetitionSeparator: "~",
            escapeCharacter: "\\",
            subcomponentSeparator: "&"
        )

        let message = try HL7v2MessageBuilder(encodingCharacters: customEnc)
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertEqual(message.encodingCharacters, customEnc)
        XCTAssertEqual(message.messageType(), "ADT^A01")
    }

    // MARK: - Serialization Consistency Tests

    func testBuiltMessageMatchesParsedMessage() throws {
        // Build a message with the builder
        let built = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("SendApp")
                   .sendingFacility("SendFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        // Parse an equivalent message
        let rawMessage = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240207120000||ADT^A01|MSG001|P|2.5.1"
        let parsed = try HL7v2Message.parse(rawMessage)

        // Compare key fields
        XCTAssertEqual(built.messageType(), parsed.messageType())
        XCTAssertEqual(built.messageControlID(), parsed.messageControlID())
        XCTAssertEqual(built.version(), parsed.version())

        let builtMSH = built.messageHeader
        let parsedMSH = parsed.messageHeader
        XCTAssertEqual(builtMSH[2].value.value.raw, parsedMSH[2].value.value.raw) // Sending App
        XCTAssertEqual(builtMSH[3].value.value.raw, parsedMSH[3].value.value.raw) // Sending Fac
        XCTAssertEqual(builtMSH[4].value.value.raw, parsedMSH[4].value.value.raw) // Receiving App
        XCTAssertEqual(builtMSH[5].value.value.raw, parsedMSH[5].value.value.raw) // Receiving Fac
    }

    // MARK: - Builder Immutability Tests

    func testBuilderImmutability() throws {
        let baseBuilder = HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }

        // Create two different messages from the same base
        let message1 = try baseBuilder
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .build()

        let message2 = try baseBuilder
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
            }
            .build()

        // Both should have MSH + their specific segment
        XCTAssertEqual(message1.segmentCount, 2)
        XCTAssertEqual(message2.segmentCount, 2)
        XCTAssertEqual(message1[1]?.segmentID, "PID")
        XCTAssertEqual(message2[1]?.segmentID, "EVN")
    }

    // MARK: - Multiple Segments of Same Type

    func testMultipleSegmentsOfSameType() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("NK1") { seg in
                seg.field(1, value: "1")
                   .field(2, components: ["Smith", "Jane"])
                   .field(3, value: "SPO")
            }
            .segment("NK1") { seg in
                seg.field(1, value: "2")
                   .field(2, components: ["Smith", "Robert"])
                   .field(3, value: "PAR")
            }
            .build()

        let nk1Segments = message.segments(withID: "NK1")
        XCTAssertEqual(nk1Segments.count, 2)
        XCTAssertEqual(nk1Segments[0][0].value.value.raw, "1")
        XCTAssertEqual(nk1Segments[1][0].value.value.raw, "2")
    }

    // MARK: - Template Customization Tests

    func testADTTemplateTransfer() throws {
        let message = try MessageTemplate.adt(
            triggerEvent: "A02",
            controlID: "CTRL_A02"
        ).build()

        XCTAssertEqual(message.messageType(), "ADT^A02")
    }

    func testADTTemplateDischarge() throws {
        let message = try MessageTemplate.adt(
            triggerEvent: "A03",
            controlID: "CTRL_A03"
        ).build()

        XCTAssertEqual(message.messageType(), "ADT^A03")
    }

    func testTemplateWithDefaultVersion() throws {
        let message = try MessageTemplate.adt(
            triggerEvent: "A01",
            controlID: "CTRL001"
        ).build()

        XCTAssertEqual(message.version(), "2.5.1")
    }

    func testTemplateWithCustomVersion() throws {
        let message = try MessageTemplate.adt(
            triggerEvent: "A01",
            controlID: "CTRL001",
            version: "2.3"
        ).build()

        XCTAssertEqual(message.version(), "2.3")
    }

    // MARK: - Edge Cases

    func testBuildMessageWithOnlyMSH() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 1)
        XCTAssertNoThrow(try message.validate())
    }

    func testSegmentBuilderOverwriteField() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "initial")
                   .field(1, value: "overwritten")
            }
            .build()

        let pid = message.segments(withID: "PID")[0]
        XCTAssertEqual(pid[0].value.value.raw, "overwritten")
    }

    func testSegmentBuilderEmptyValue() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "")
            }
            .build()

        let pid = message.segments(withID: "PID")[0]
        XCTAssertTrue(pid[0].isEmpty)
    }

    func testBuildAndSerialize() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("SendApp")
                   .sendingFacility("SendFac")
                   .receivingApplication("RecApp")
                   .receivingFacility("RecFac")
                   .dateTime("20240207120000")
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
                   .field(5, value: "Smith^John")
            }
            .build()

        let serialized = try message.serialize()
        XCTAssertTrue(serialized.contains("MSH|"))
        XCTAssertTrue(serialized.contains("PID|"))
        XCTAssertTrue(serialized.contains("Smith^John"))
    }

    // MARK: - Fluent Chaining Tests

    func testFluentChainingOrder() throws {
        // Build segments in specific order
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { seg in
                seg.field(1, value: "A01")
            }
            .segment("PID") { seg in
                seg.field(1, value: "1")
            }
            .segment("PV1") { seg in
                seg.field(1, value: "1")
            }
            .segment("NK1") { seg in
                seg.field(1, value: "1")
            }
            .build()

        XCTAssertEqual(message.segmentCount, 5)
        XCTAssertEqual(message[0]?.segmentID, "MSH")
        XCTAssertEqual(message[1]?.segmentID, "EVN")
        XCTAssertEqual(message[2]?.segmentID, "PID")
        XCTAssertEqual(message[3]?.segmentID, "PV1")
        XCTAssertEqual(message[4]?.segmentID, "NK1")
    }

    // MARK: - HL7Message Protocol Compliance Tests

    func testBuiltMessageProtocolCompliance() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("PROTO001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .build()

        // HL7Message protocol
        XCTAssertEqual(message.messageID, "PROTO001")
        XCTAssertFalse(message.rawData.isEmpty)
        XCTAssertNoThrow(try message.validate())
    }

    // MARK: - RawSegment with complex content

    func testRawSegmentWithComponents() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.messageType("ADT", triggerEvent: "A01")
                   .messageControlID("MSG001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .rawSegment("OBX|1|NM|WBC^White Blood Count||7.5|10*3/uL|4.5-11.0|N|||F")
            .build()

        let obx = message.segments(withID: "OBX")[0]
        XCTAssertEqual(obx[0].value.value.raw, "1")
        XCTAssertEqual(obx[1].value.value.raw, "NM")
        XCTAssertEqual(obx[2][0].value.raw, "WBC")
        XCTAssertEqual(obx[2][1].value.raw, "White Blood Count")
        XCTAssertEqual(obx[4].value.value.raw, "7.5")
    }
}
