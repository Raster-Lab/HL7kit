// =============================================================================
// HL7kit Common Use Case Examples
// =============================================================================
//
// Real-world healthcare integration scenarios:
//   1. Processing an ADT (Admit/Discharge/Transfer) workflow
//   2. Handling ORU (Lab Result) messages
//   3. Creating and sending ORM (Order) messages
//   4. ACK (Acknowledgment) response handling
//   5. Batch processing multiple messages
//
// =============================================================================

import Foundation
import HL7Core
import HL7v2Kit

// MARK: - 1. ADT Workflow: Patient Admission

/// Simulate receiving a patient admission notification and extracting
/// key demographic and visit information.
func processAdmission() throws {
    let raw = """
    MSH|^~\\&|ADT|HospitalA|EHR|HospitalA|20240201080000||ADT^A01^ADT_A01|ADM001|P|2.5.1
    EVN|A01|20240201080000
    PID|1||MRN-5678^^^HospitalA^MR||Garcia^Maria^L^^^||19751023|F|||789 Elm St^^Dallas^TX^75201||^PRN^PH^^1^214^5551234
    PV1|1|I|ICU^301^A^^^HospitalA||||1234^Johnson^Robert^A^^^MD|5678^Patel^Priya^^^MD||MED|||||||1234^Johnson^Robert^A^^^MD|IN||||||||||||||||||HospitalA|||||20240201080000
    IN1|1|BCBS001^Blue Cross Blue Shield|BC001|Blue Cross Blue Shield|||||||||||Garcia^Maria^L|S|19751023|789 Elm St^^Dallas^TX^75201
    """

    let message = try HL7v2Message.parse(raw)

    // Extract patient demographics from PID segment
    if let pid = message.segments(withID: "PID").first {
        let mrn = pid[2].serialize()
        let name = pid[4].serialize()
        let dob = pid[6].serialize()
        let gender = pid[7].serialize()
        let address = pid[10].serialize()

        print("=== Patient Admission ===")
        print("MRN: \(mrn)")
        print("Name: \(name)")
        print("DOB: \(dob)")
        print("Gender: \(gender)")
        print("Address: \(address)")
    }

    // Extract visit information from PV1 segment
    if let pv1 = message.segments(withID: "PV1").first {
        let patientClass = pv1[1].serialize()
        let location = pv1[2].serialize()
        let attendingDoctor = pv1[6].serialize()

        print("\n=== Visit Information ===")
        print("Class: \(patientClass)")
        print("Location: \(location)")
        print("Attending: \(attendingDoctor)")
    }

    // Extract insurance from IN1 segment
    if let in1 = message.segments(withID: "IN1").first {
        let plan = in1[1].serialize()
        let company = in1[3].serialize()

        print("\n=== Insurance ===")
        print("Plan: \(plan)")
        print("Company: \(company)")
    }
}

// MARK: - 2. Lab Results: Processing ORU Messages

/// Parse an ORU R01 message with multiple lab observations and extract
/// structured results with reference ranges and abnormal flags.
func processLabResults() throws {
    let raw = """
    MSH|^~\\&|LabSystem|MainLab|EHR|Hospital|20240201150000||ORU^R01^ORU_R01|LAB001|P|2.5.1
    PID|1||12345^^^Hospital^MR||Smith^John^A|||M
    ORC|RE|ORD-100|LAB-100||CM
    OBR|1|ORD-100|LAB-100|24323-8^CMP^LN|||20240201140000|||||||20240201140500||1234^Johnson^Robert^A^^^MD
    OBX|1|NM|2345-7^Glucose^LN||95|mg/dL|70-100|N|||F
    OBX|2|NM|2160-0^Creatinine^LN||1.1|mg/dL|0.7-1.3|N|||F
    OBX|3|NM|3094-0^BUN^LN||18|mg/dL|7-20|N|||F
    OBX|4|NM|2951-2^Sodium^LN||142|mmol/L|136-145|N|||F
    OBX|5|NM|2823-3^Potassium^LN||4.2|mmol/L|3.5-5.1|N|||F
    OBX|6|NM|17861-6^Calcium^LN||9.5|mg/dL|8.5-10.5|N|||F
    OBX|7|NM|1742-6^ALT^LN||45|U/L|7-56|N|||F
    OBX|8|NM|1920-8^AST^LN||38|U/L|10-40|N|||F
    """

    let message = try HL7v2Message.parse(raw)

    // Extract order information
    if let obr = message.segments(withID: "OBR").first {
        let orderCode = obr[3].serialize()
        let collectionTime = obr[6].serialize()
        print("=== Lab Order: \(orderCode) ===")
        print("Collection: \(collectionTime)")
    }

    // Extract each observation result
    let observations = message.segments(withID: "OBX")
    print("\n=== Results (\(observations.count) analytes) ===")

    for obx in observations {
        let setID = obx[0].serialize()
        let testCode = obx[2].serialize()
        let value = obx[4].serialize()
        let units = obx[5].serialize()
        let refRange = obx[6].serialize()
        let flag = obx[7].serialize()

        let abnormal = flag != "N" ? " ⚠️" : ""
        print("  [\(setID)] \(testCode): \(value) \(units) (ref: \(refRange))\(abnormal)")
    }
}

// MARK: - 3. Order Entry: Building ORM Messages

/// Build an ORM O01 lab order message for a Complete Blood Count.
func buildLabOrder() throws {
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
               .field(6, value: "19900515")
               .field(7, value: "F")
        }
        .segment("ORC") { orc in
            orc.field(0, value: "NW")      // ORC-1: Order Control (NW = New Order)
               .field(1, value: "ORD-100") // ORC-2: Placer Order Number
        }
        .segment("OBR") { obr in
            obr.field(0, value: "1")                                           // OBR-1: Set ID
               .field(1, value: "ORD-100")                                     // OBR-2: Placer Order Number
               .field(3, value: "58410-2^CBC^LN")                              // OBR-4: Universal Service ID
               .field(6, value: "20240201160000")                              // OBR-7: Observation Date/Time
               .field(15, value: "1234^Johnson^Robert^A^^^MD")                 // OBR-16: Ordering Provider
        }
        .build()

    let output = try message.serialize()
    print("=== Lab Order Message ===")
    print(output)
}

// MARK: - 4. ACK Response: Building Acknowledgments

/// Build an ACK response for a received message.
func buildAcknowledgment() throws {
    // Simulate receiving a message
    let received = try HL7v2Message.parse(
        "MSH|^~\\&|Sender|Fac|Receiver|Fac|20240201||ADT^A01|MSG-123|P|2.5.1"
    )

    let controlID = received.messageControlID()

    // Build the ACK response
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
            msa.field(0, value: "AA")          // Application Accept
               .field(1, value: controlID)     // Reference the original control ID
        }
        .build()

    let output = try ack.serialize()
    print("=== ACK Response ===")
    print(output)
}

// MARK: - 5. Batch Processing

/// Process a batch of HL7 messages, validating each one.
func processBatch() throws {
    let messages = [
        "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M001|P|2.5.1\rPID|1||MRN001^^^Hosp^MR||Smith^John",
        "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M002|P|2.5.1\rPID|1||MRN002^^^Hosp^MR||Doe^Jane",
        "MSH|^~\\&|App|Fac|App|Fac|20240201||ADT^A01|M003|P|2.5.1\rPID|1||MRN003^^^Hosp^MR||Garcia^Maria",
    ]

    var successCount = 0
    var failCount = 0

    print("=== Batch Processing \(messages.count) Messages ===")

    for (index, raw) in messages.enumerated() {
        do {
            let msg = try HL7v2Message.parse(raw)
            try msg.validate()
            let controlID = msg.messageControlID()
            print("  [\(index + 1)] ✅ \(controlID) — valid")
            successCount += 1
        } catch {
            print("  [\(index + 1)] ❌ Error: \(error)")
            failCount += 1
        }
    }

    print("\nResults: \(successCount) succeeded, \(failCount) failed")
}
