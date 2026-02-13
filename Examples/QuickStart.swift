// =============================================================================
// HL7kit Quick Start Guide
// =============================================================================
//
// This file demonstrates the essential HL7kit operations:
//   1. Parsing an HL7 v2.x message
//   2. Building a message with the fluent API
//   3. Validating messages
//   4. Inspecting message contents
//   5. Creating FHIR resources
//   6. JSON serialization
//
// Import the modules you need:
//   import HL7Core      — shared protocols, logging, security
//   import HL7v2Kit     — HL7 v2.x parsing, building, validation
//   import HL7v3Kit     — HL7 v3.x / CDA document processing
//   import FHIRkit      — FHIR R4 resources, REST client, search
//
// =============================================================================

import Foundation
import HL7Core
import HL7v2Kit

// MARK: - 1. Parse an HL7 v2.x Message

/// Parse a raw HL7 v2.x pipe-delimited string into a structured message.
func parseHL7v2Message() throws {
    let raw = """
    MSH|^~\\&|SendingApp|SendingFac|ReceivingApp|ReceivingFac|\
    20240115120000||ADT^A01^ADT_A01|MSG00001|P|2.5.1
    EVN|A01|20240115120000
    PID|1||12345^^^Hospital^MR||Smith^John^A^^^||19800101|M|||123 Main St^^Anytown^NY^12345
    PV1|1|I|ICU^101^A
    """

    // Quick parse — throws on invalid input
    let message = try HL7v2Message.parse(raw)

    // Access header information
    let messageType = message.messageType()    // "ADT^A01^ADT_A01"
    let controlID = message.messageControlID() // "MSG00001"
    let version = message.version()            // "2.5.1"
    print("Parsed \(messageType) (ID: \(controlID), v\(version))")

    // Access segments by ID
    let pidSegments = message.segments(withID: "PID")
    if let pid = pidSegments.first {
        let patientID = pid[2].serialize()    // "12345^^^Hospital^MR"
        let name = pid[4].serialize()         // "Smith^John^A^^^"
        print("Patient: \(name), MRN: \(patientID)")
    }

    // Serialize back to string
    let serialized = try message.serialize()
    print("Serialized length: \(serialized.count) characters")
}

// MARK: - 2. Build an HL7 v2.x Message

/// Build an ADT A01 admission message from scratch using the fluent builder API.
func buildHL7v2Message() throws {
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
            evn.field(0, value: "A01")             // EVN-1: Event Type Code
               .field(1, value: "20240115120000")  // EVN-2: Recorded Date/Time
        }
        .segment("PID") { pid in
            pid.field(0, value: "1")                                      // PID-1: Set ID
               .field(2, value: "98765^^^MyHospital^MR")                  // PID-3: Patient Identifier
               .field(4, value: "Doe^Jane^M^^^")                         // PID-5: Patient Name
               .field(6, value: "19900515")                               // PID-7: Date of Birth
               .field(7, value: "F")                                      // PID-8: Sex
               .field(10, value: "456 Oak Ave^^Springfield^IL^62704")     // PID-11: Address
        }
        .segment("PV1") { pv1 in
            pv1.field(0, value: "1")
               .field(1, value: "I")
               .field(2, value: "MED^201^B")
        }
        .build()

    let output = try message.serialize()
    print("Built message:\n\(output)")
}

// MARK: - 3. Validate a Message

/// Validate an HL7 v2.x message against built-in and custom rules.
func validateMessage() throws {
    let raw = """
    MSH|^~\\&|App|Fac|App|Fac|20240115||ADT^A01|CTL001|P|2.5.1
    PID|1||MRN001^^^Hosp^MR||Patient^Test
    """
    let message = try HL7v2Message.parse(raw)

    // Basic structural validation
    do {
        try message.validate()
        print("Message passes basic validation")
    } catch {
        print("Validation error: \(error)")
    }

    // Advanced validation with an engine and rules
    let engine = HL7v2ValidationEngine()

    // Require that PID segment is present
    let requirePID = RequiredSegmentRule(segmentID: "PID")
    let result = engine.validate(message, rules: [requirePID])
    print("Validation issues: \(result.issues.count)")
    for issue in result.issues {
        print("  [\(issue.severity)] \(issue.message)")
    }
}

// MARK: - 4. Inspect a Message

/// Use MessageInspector to view message structure and search for values.
func inspectMessage() throws {
    let raw = """
    MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20240115120000||ORU^R01|MSG002|P|2.5.1
    PID|1||12345^^^Hospital^MR||Smith^John
    OBR|1|ORD001||CBC^Complete Blood Count^L
    OBX|1|NM|WBC^White Blood Cell Count^L||7.5|10*3/uL|4.5-11.0|N|||F
    OBX|2|NM|HGB^Hemoglobin^L||14.2|g/dL|12.0-17.5|N|||F
    OBX|3|NM|PLT^Platelets^L||250|10*3/uL|150-400|N|||F
    """
    let message = try HL7v2Message.parse(raw)
    let inspector = MessageInspector(message: message)

    // Print a summary
    print(inspector.summary())

    // Print the tree view (hierarchical structure)
    print(inspector.treeView())

    // Search for specific values
    let results = inspector.search(for: "Smith")
    for match in results {
        print("Found '\(match.value)' in \(match.segment) field \(match.field)")
    }

    // Get statistics
    let stats = inspector.statistics()
    print("Message statistics: \(stats)")
}

// MARK: - 5. Create a FHIR Patient Resource

/// Create a FHIR R4 Patient resource with demographic information.
func createFHIRPatient() {
    // Import FHIRkit to use these types
    // import FHIRkit

    // Example of a Patient resource (shown as pseudo-code — requires FHIRkit import):
    //
    //   let patient = Patient(
    //       id: "patient-123",
    //       identifier: [
    //           Identifier(system: "http://hospital.example.org/mrn", value: "MRN12345")
    //       ],
    //       active: true,
    //       name: [
    //           HumanName(use: "official", family: "Smith", given: ["John", "A"])
    //       ],
    //       gender: "male",
    //       birthDate: "1980-01-01",
    //       address: [
    //           Address(
    //               use: "home",
    //               line: ["123 Main St"],
    //               city: "Anytown",
    //               state: "NY",
    //               postalCode: "12345",
    //               country: "US"
    //           )
    //       ],
    //       telecom: [
    //           ContactPoint(system: "phone", value: "555-0100", use: "home")
    //       ]
    //   )
    //
    //   // Serialize to JSON
    //   let json = try await FHIRJSON.encodeToString(patient)
    //   print(json)
    //
    //   // Validate
    //   let validator = FHIRValidator()
    //   let outcome = validator.validate(patient)
    //   print("Valid: \(outcome.isValid)")

    print("FHIR Patient example — see FHIRkit module for full implementation")
}
