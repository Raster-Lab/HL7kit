import XCTest
@testable import HL7v2Kit
@testable import HL7Core

/// Tests that verify all example code from the Examples/ directory compiles and
/// produces correct results. Each test mirrors a function from the example files.
final class ExampleCodeTests: XCTestCase {

    // MARK: - QuickStart Examples

    func testQuickStartParsing() throws {
        let raw = "MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|20240115120000||ADT^A01^ADT_A01|MSG00001|P|2.5.1\rEVN|A01|20240115120000\rPID|1||12345^^^Hospital^MR||Smith^John^A^^^||19800101|M|||123 Main St^^Anytown^NY^12345\rPV1|1|I|ICU^101^A"

        let message = try HL7v2Message.parse(raw)

        // Verify header information
        XCTAssertTrue(message.messageType().contains("ADT"))
        XCTAssertEqual(message.messageControlID(), "MSG00001")
        XCTAssertEqual(message.version(), "2.5.1")

        // Verify segment access
        let pidSegments = message.segments(withID: "PID")
        XCTAssertEqual(pidSegments.count, 1)
        let pid = pidSegments[0]
        XCTAssertTrue(pid[2].serialize().contains("12345"))
        XCTAssertTrue(pid[4].serialize().contains("Smith"))

        // Verify serialization round-trip
        let serialized = try message.serialize()
        XCTAssertFalse(serialized.isEmpty)
    }

    func testQuickStartBuilding() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("MyEHR")
                   .sendingFacility("MyHospital")
                   .receivingApplication("LabSystem")
                   .receivingFacility("LabFacility")
                   .dateTime(Date())
                   .messageType("ADT", triggerEvent: "A01")
                   .messageControlID("ADM-2024-001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("EVN") { evn in
                evn.field(0, value: "A01")
                   .field(1, value: "20240115120000")
            }
            .segment("PID") { pid in
                pid.field(0, value: "1")
                   .field(2, value: "98765^^^MyHospital^MR")
                   .field(4, value: "Doe^Jane^M^^^")
                   .field(6, value: "19900515")
                   .field(7, value: "F")
                   .field(10, value: "456 Oak Ave^^Springfield^IL^62704")
            }
            .segment("PV1") { pv1 in
                pv1.field(0, value: "1")
                   .field(1, value: "I")
                   .field(2, value: "MED^201^B")
            }
            .build()

        let output = try message.serialize()
        XCTAssertTrue(output.contains("MSH|"))
        XCTAssertTrue(output.contains("ADM-2024-001"))
        XCTAssertTrue(output.contains("Doe^Jane"))
    }

    func testQuickStartValidation() throws {
        let raw = "MSH|^~\\&|App|Fac|App|Fac|20240115||ADT^A01|CTL001|P|2.5.1\rPID|1||MRN001^^^Hosp^MR||Patient^Test"
        let message = try HL7v2Message.parse(raw)

        // Basic validation
        XCTAssertNoThrow(try message.validate())

        // Engine-based validation with rules
        let engine = HL7v2ValidationEngine()
        let requirePID = RequiredSegmentRule(segmentID: "PID")
        let result = engine.validate(message, rules: [requirePID])
        XCTAssertTrue(result.isValid)
    }

    func testQuickStartInspection() throws {
        let raw = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240115120000||ORU^R01|MSG002|P|2.5.1\rPID|1||12345^^^Hospital^MR||Smith^John\rOBR|1|ORD001||CBC^Complete Blood Count^L\rOBX|1|NM|WBC^White Blood Cell Count^L||7.5|10*3/uL|4.5-11.0|N|||F\rOBX|2|NM|HGB^Hemoglobin^L||14.2|g/dL|12.0-17.5|N|||F"
        let message = try HL7v2Message.parse(raw)
        let inspector = MessageInspector(message: message)

        // Verify summary/treeView produce output
        XCTAssertFalse(inspector.summary().isEmpty)
        XCTAssertFalse(inspector.treeView().isEmpty)

        // Verify search works
        let results = inspector.search(for: "Smith")
        XCTAssertFalse(results.isEmpty)

        // Verify statistics
        let stats = inspector.statistics()
        XCTAssertFalse(stats.isEmpty)
    }

    // MARK: - Common Use Case Examples

    func testAdmissionWorkflow() throws {
        let raw = "MSH|^~\\&|ADT|HospitalA|EHR|HospitalA|20240201080000||ADT^A01^ADT_A01|ADM001|P|2.5.1\rEVN|A01|20240201080000\rPID|1||MRN-5678^^^HospitalA^MR||Garcia^Maria^L^^^||19751023|F|||789 Elm St^^Dallas^TX^75201||^PRN^PH^^1^214^5551234\rPV1|1|I|ICU^301^A^^^HospitalA||||1234^Johnson^Robert^A^^^MD\rIN1|1|BCBS001^Blue Cross Blue Shield|BC001|Blue Cross Blue Shield"

        let message = try HL7v2Message.parse(raw)

        // Extract PID
        let pid = message.segments(withID: "PID").first
        XCTAssertNotNil(pid)
        XCTAssertTrue(pid![2].serialize().contains("MRN-5678"))
        XCTAssertTrue(pid![4].serialize().contains("Garcia"))

        // Extract PV1
        let pv1 = message.segments(withID: "PV1").first
        XCTAssertNotNil(pv1)
        XCTAssertTrue(pv1![2].serialize().contains("ICU"))

        // Extract IN1
        let in1 = message.segments(withID: "IN1").first
        XCTAssertNotNil(in1)
    }

    func testLabResultsProcessing() throws {
        let raw = "MSH|^~\\&|LabSystem|MainLab|EHR|Hospital|20240201150000||ORU^R01^ORU_R01|LAB001|P|2.5.1\rPID|1||12345^^^Hospital^MR||Smith^John^A|||M\rORC|RE|ORD-100|LAB-100||CM\rOBR|1|ORD-100|LAB-100|24323-8^CMP^LN|||20240201140000\rOBX|1|NM|2345-7^Glucose^LN||95|mg/dL|70-100|N|||F\rOBX|2|NM|2160-0^Creatinine^LN||1.1|mg/dL|0.7-1.3|N|||F\rOBX|3|NM|3094-0^BUN^LN||18|mg/dL|7-20|N|||F"

        let message = try HL7v2Message.parse(raw)

        // Verify observations
        let observations = message.segments(withID: "OBX")
        XCTAssertEqual(observations.count, 3)

        // First OBX — glucose
        let glucose = observations[0]
        XCTAssertTrue(glucose[2].serialize().contains("Glucose"))
        XCTAssertEqual(glucose[4].serialize(), "95")
        XCTAssertEqual(glucose[5].serialize(), "mg/dL")
    }

    func testBuildLabOrder() throws {
        let message = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("OrderEntry")
                   .sendingFacility("Hospital")
                   .receivingApplication("LabSystem")
                   .receivingFacility("MainLab")
                   .dateTime(Date())
                   .messageType("ORM", triggerEvent: "O01")
                   .messageControlID("ORD-2024-001")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("PID") { pid in
                pid.field(0, value: "1")
                   .field(2, value: "98765^^^Hospital^MR")
                   .field(4, value: "Doe^Jane^M^^^")
            }
            .segment("ORC") { orc in
                orc.field(0, value: "NW")
                   .field(1, value: "ORD-100")
            }
            .segment("OBR") { obr in
                obr.field(0, value: "1")
                   .field(1, value: "ORD-100")
                   .field(3, value: "58410-2^CBC^LN")
            }
            .build()

        let output = try message.serialize()
        XCTAssertTrue(output.contains("ORM"))
        XCTAssertTrue(output.contains("ORD-100"))
        XCTAssertTrue(output.contains("CBC"))
    }

    func testBuildAcknowledgment() throws {
        let received = try HL7v2Message.parse(
            "MSH|^~\\&|Sender|Fac|Receiver|Fac|20240201||ADT^A01|MSG-123|P|2.5.1"
        )
        let controlID = received.messageControlID()

        let ack = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("Receiver")
                   .sendingFacility("Fac")
                   .receivingApplication("Sender")
                   .receivingFacility("Fac")
                   .dateTime(Date())
                   .messageType("ACK", triggerEvent: "A01")
                   .messageControlID("ACK-\(controlID)")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("MSA") { msa in
                msa.field(1, value: "AA")
                   .field(2, value: controlID)
            }
            .build()

        let output = try ack.serialize()
        XCTAssertTrue(output.contains("ACK"))
        XCTAssertTrue(output.contains("AA"))
        XCTAssertTrue(output.contains("MSG-123"))
    }

    func testBatchProcessing() throws {
        let messages = [
            "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1\rPID|1||MRN001^^^Hosp^MR||Smith^John",
            "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M002|P|2.5.1\rPID|1||MRN002^^^Hosp^MR||Doe^Jane",
            "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M003|P|2.5.1\rPID|1||MRN003^^^Hosp^MR||Garcia^Maria",
        ]

        var successCount = 0
        for raw in messages {
            do {
                let msg = try HL7v2Message.parse(raw)
                try msg.validate()
                successCount += 1
            } catch {
                // Expected to pass
            }
        }
        XCTAssertEqual(successCount, messages.count)
    }

    // MARK: - Integration Examples

    func testEndToEndWorkflow() throws {
        let incoming = "MSH|^~\\&|ADT|Hospital|EHR|Hospital|20240201||ADT^A01|MSG100|P|2.5.1\rEVN|A01|20240201\rPID|1||MRN-001^^^Hospital^MR||Smith^John^A|||M|||123 Main St^^Anytown^NY^12345\rPV1|1|I|MED^101^A"

        // Step 1: Parse
        let message = try HL7v2Message.parse(incoming)
        XCTAssertTrue(message.messageType().contains("ADT"))

        // Step 2: Validate
        XCTAssertNoThrow(try message.validate())

        // Step 3: Extract data
        let pid = message.segments(withID: "PID").first
        XCTAssertNotNil(pid)
        XCTAssertTrue(pid![4].serialize().contains("Smith"))

        // Step 4: Build ACK
        let controlID = message.messageControlID()
        let ack = try HL7v2MessageBuilder()
            .msh { msh in
                msh.sendingApplication("EHR")
                   .sendingFacility("Hospital")
                   .receivingApplication("ADT")
                   .receivingFacility("Hospital")
                   .dateTime(Date())
                   .messageType("ACK", triggerEvent: "A01")
                   .messageControlID("ACK-\(controlID)")
                   .processingID("P")
                   .version("2.5.1")
            }
            .segment("MSA") { msa in
                msa.field(1, value: "AA")
                   .field(2, value: controlID)
            }
            .build()

        let ackString = try ack.serialize()
        XCTAssertTrue(ackString.contains("ACK"))
        XCTAssertTrue(ackString.contains("AA"))
    }

    // MARK: - Performance Examples

    func testParserConfiguration() throws {
        let defaultParser = HL7v2Parser(configuration: ParserConfiguration())
        let strictParser = HL7v2Parser(
            configuration: ParserConfiguration(errorRecovery: .strict)
        )
        let lenientParser = HL7v2Parser(
            configuration: ParserConfiguration(errorRecovery: .skipInvalidSegments)
        )
        let bestEffortParser = HL7v2Parser(
            configuration: ParserConfiguration(errorRecovery: .bestEffort)
        )

        let raw = "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1\rPID|1||MRN001||Smith^John"

        // All parsers should successfully parse valid input
        let result1 = try defaultParser.parse(raw)
        XCTAssertEqual(result1.diagnostics.segmentsParsed, 2)

        let result2 = try strictParser.parse(raw)
        XCTAssertEqual(result2.diagnostics.segmentsParsed, 2)

        let result3 = try lenientParser.parse(raw)
        XCTAssertEqual(result3.diagnostics.segmentsParsed, 2)

        let result4 = try bestEffortParser.parse(raw)
        XCTAssertEqual(result4.diagnostics.segmentsParsed, 2)
    }

    func testMessageComparison() throws {
        let original = "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1\rPID|1||MRN001^^^Hosp^MR||Smith^John^A|||M|||123 Main St^^Anytown^NY^12345\rPV1|1|I|ICU^101^A"
        let updated = "MSH|^~\\&|App|Fac|App|Fac|20240202||ADT^A08|M002|P|2.5.1\rPID|1||MRN001^^^Hosp^MR||Smith^John^A|||M|||456 Oak Ave^^Springfield^IL^62704\rPV1|1|I|MED^201^B"

        let msg1 = try HL7v2Message.parse(original)
        let msg2 = try HL7v2Message.parse(updated)

        let inspector = MessageInspector(message: msg1)
        let diff = inspector.compare(with: msg2)
        XCTAssertFalse(diff.isEmpty)
    }

    func testBenchmarkParsing() throws {
        let sampleMessage = "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1\rEVN|A01|20240201\rPID|1||MRN001^^^Hosp^MR||Smith^John^A|||M|||123 Main St^^Anytown^NY^12345\rPV1|1|I|ICU^101^A"

        let iterations = 100
        let start = Date()

        for _ in 0..<iterations {
            let msg = try HL7v2Message.parse(sampleMessage)
            _ = try msg.serialize()
        }

        let elapsed = Date().timeIntervalSince(start)
        let throughput = Double(iterations) / elapsed

        XCTAssertGreaterThan(throughput, 0)
        XCTAssertGreaterThan(elapsed, 0)
    }
}
