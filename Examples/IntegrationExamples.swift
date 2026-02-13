// =============================================================================
// HL7kit Integration Examples
// =============================================================================
//
// Cross-module integration scenarios:
//   1. HL7 v2.x to v3.x CDA transformation
//   2. FHIR resource creation and serialization
//   3. FHIR search queries
//   4. FHIR validation with profiles
//   5. CLI tool usage guide
//
// =============================================================================

import Foundation
import HL7Core
import HL7v2Kit

// MARK: - 1. HL7 v2.x → v3.x CDA Transformation

/// Transform an ADT A01 message into a CDA clinical document.
///
/// Requires: `import HL7v3Kit`
///
/// ```swift
/// import HL7v3Kit
///
/// // Parse the v2.x source message
/// let v2Message = try HL7v2Message.parse(adtRaw)
///
/// // Define transformation rules using the builder DSL
/// let rules = TransformationBuilder()
///     .map("PID.5").to("recordTarget.patientRole.patient.name")
///         .describe("Patient name mapping")
///         .required()
///     .map("PID.7").to("recordTarget.patientRole.patient.birthTime")
///         .transform(CommonTransformations.v2DateTimeToISO)
///         .describe("Date of birth")
///     .map("PID.8").to("recordTarget.patientRole.patient.administrativeGenderCode")
///         .transform(CommonTransformations.mapValue(["M": "male", "F": "female"], default: "unknown"))
///         .describe("Gender mapping")
///     .build()
///
/// // Build the CDA document
/// let cdaDocument = try CDADocumentBuilder()
///     .withId(root: "2.16.840.1.113883.19.5", extension: "DOC-001")
///     .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1")
///     .withDocumentCode(
///         code: "34133-9",
///         codeSystem: "2.16.840.1.113883.6.1",
///         codeSystemName: "LOINC",
///         displayName: "Summarization of Episode Note"
///     )
///     .withTitle("Patient Admission Summary")
///     .withEffectiveTime(Date())
///     .withConfidentiality("N")
///     .withLanguage("en-US")
///     .withRecordTarget { rt in
///         rt.withPatientId(root: "2.16.840.1.113883.19.5", extension: "12345")
///           .withPatientName(family: "Smith", given: "John")
///           .withBirthTime("19800101")
///           .withGender(code: "M", codeSystem: "2.16.840.1.113883.5.1")
///     }
///     .withAuthor { author in
///         author.withTime(Date())
///               .withId(root: "2.16.840.1.113883.4.6", extension: "1234567890")
///               .withName(family: "Johnson", given: "Robert")
///     }
///     .withCustodian { custodian in
///         custodian.withOrganizationId(root: "2.16.840.1.113883.19.5", extension: "HOSP-001")
///                  .withOrganizationName("General Hospital")
///     }
///     .build()
///
/// print("CDA document created: \(cdaDocument.id?.root ?? "?")")
/// ```

// MARK: - 2. FHIR Resource Creation and Serialization

/// Create FHIR R4 resources and serialize to JSON/XML.
///
/// Requires: `import FHIRkit`
///
/// ```swift
/// import FHIRkit
///
/// // Create a Patient resource
/// let patient = Patient(
///     id: "patient-001",
///     identifier: [
///         Identifier(
///             system: "http://hospital.example.org/mrn",
///             value: "MRN-12345"
///         )
///     ],
///     active: true,
///     name: [
///         HumanName(
///             use: "official",
///             family: "Smith",
///             given: ["John", "Andrew"]
///         )
///     ],
///     gender: "male",
///     birthDate: "1980-01-01",
///     address: [
///         Address(
///             use: "home",
///             line: ["123 Main Street"],
///             city: "Anytown",
///             state: "NY",
///             postalCode: "12345",
///             country: "US"
///         )
///     ],
///     telecom: [
///         ContactPoint(system: "phone", value: "555-0100", use: "home"),
///         ContactPoint(system: "email", value: "john.smith@email.com", use: "home")
///     ]
/// )
///
/// // Serialize to JSON
/// let jsonData = try await FHIRJSON.encode(patient)
/// let jsonString = String(data: jsonData, encoding: .utf8)!
/// print(jsonString)
///
/// // Serialize to XML
/// let xmlString = try await FHIRXML.encodeToString(patient)
/// print(xmlString)
///
/// // Deserialize from JSON
/// let decoded = try await FHIRJSON.decode(Patient.self, from: jsonData)
/// print("Decoded: \(decoded.name?.first?.family ?? "?")")
/// ```

// MARK: - 3. FHIR Observation with Lab Results

/// Create a FHIR Observation resource for a blood glucose measurement.
///
/// ```swift
/// import FHIRkit
///
/// let observation = Observation(
///     id: "obs-glucose-001",
///     status: "final",
///     category: [
///         CodeableConcept(
///             coding: [
///                 Coding(
///                     system: "http://terminology.hl7.org/CodeSystem/observation-category",
///                     code: "laboratory",
///                     display: "Laboratory"
///                 )
///             ]
///         )
///     ],
///     code: CodeableConcept(
///         coding: [
///             Coding(
///                 system: "http://loinc.org",
///                 code: "2345-7",
///                 display: "Glucose [Mass/volume] in Serum or Plasma"
///             )
///         ],
///         text: "Blood Glucose"
///     ),
///     subject: Reference(reference: "Patient/patient-001", display: "John Smith"),
///     effectiveDateTime: "2024-02-01T14:30:00Z",
///     valueQuantity: Quantity(value: 95, unit: "mg/dL", system: "http://unitsofmeasure.org", code: "mg/dL"),
///     referenceRange: [
///         ObservationReferenceRange(
///             low: Quantity(value: 70, unit: "mg/dL"),
///             high: Quantity(value: 100, unit: "mg/dL"),
///             text: "70-100 mg/dL"
///         )
///     ]
/// )
///
/// let json = try await FHIRJSON.encodeToString(observation)
/// print(json)
/// ```

// MARK: - 4. FHIR Bundle (Transaction)

/// Create a FHIR Bundle with multiple resources for a transaction.
///
/// ```swift
/// import FHIRkit
///
/// // Create a transaction Bundle with a Patient and an Observation
/// let bundle = Bundle(
///     type: "transaction",
///     entry: [
///         BundleEntry(
///             fullUrl: "urn:uuid:patient-001",
///             resource: ResourceContainer(patient),
///             request: BundleEntryRequest(method: "POST", url: "Patient")
///         ),
///         BundleEntry(
///             fullUrl: "urn:uuid:obs-001",
///             resource: ResourceContainer(observation),
///             request: BundleEntryRequest(method: "POST", url: "Observation")
///         )
///     ]
/// )
///
/// let bundleJSON = try await FHIRJSON.encodeToString(bundle)
/// print(bundleJSON)
/// ```

// MARK: - 5. FHIR Validation

/// Validate a FHIR resource against profiles and custom rules.
///
/// ```swift
/// import FHIRkit
///
/// // Create a validator with default configuration
/// let validator = FHIRValidator()
///
/// // Validate a Patient resource
/// let outcome = validator.validate(patient)
/// if outcome.isValid {
///     print("✅ Resource is valid")
/// } else {
///     print("❌ Validation errors:")
///     for issue in outcome.issues {
///         print("  [\(issue.severity)] \(issue.details)")
///     }
/// }
///
/// // Validate with strict configuration
/// let strictValidator = FHIRValidator(configuration: .strict)
/// let strictOutcome = strictValidator.validate(patient)
/// print("Strict validation: \(strictOutcome.issues.count) issues")
/// ```

// MARK: - 6. CLI Tool Usage

/// The `hl7` command-line tool provides five subcommands for message processing.
///
/// ## Validate a Message
/// ```bash
/// # Validate a single file
/// swift run hl7 validate path/to/message.hl7
///
/// # Validate with JSON output
/// swift run hl7 validate path/to/message.hl7 --format json
///
/// # Validate a string directly
/// echo "MSH|^~\\&|..." | swift run hl7 validate -
/// ```
///
/// ## Convert Between Formats
/// ```bash
/// # Convert HL7 v2.x to pretty-printed format
/// swift run hl7 convert path/to/message.hl7
///
/// # Convert with JSON output
/// swift run hl7 convert path/to/message.hl7 --format json
/// ```
///
/// ## Inspect a Message
/// ```bash
/// # Inspect message structure (tree view)
/// swift run hl7 inspect path/to/message.hl7
///
/// # Search for a value in the message
/// swift run hl7 inspect path/to/message.hl7 --search "Smith"
/// ```
///
/// ## Batch Processing
/// ```bash
/// # Validate all .hl7 files in a directory
/// swift run hl7 batch path/to/directory --operation validate
///
/// # Inspect all files with JSON output
/// swift run hl7 batch path/to/directory --operation inspect --format json
/// ```
///
/// ## Conformance Checking
/// ```bash
/// # Check conformance against a standard profile
/// swift run hl7 conformance path/to/message.hl7
///
/// # Check with a specific profile
/// swift run hl7 conformance path/to/message.hl7 --profile ADT_A01
/// ```

// MARK: - Example: End-to-End Integration

/// A complete workflow that parses, validates, transforms, and responds.
func endToEndWorkflow() throws {
    // Step 1: Receive and parse an ADT message
    let incoming = """
    MSH|^~\\&|ADT|Hospital|EHR|Hospital|20240201||ADT^A01|MSG100|P|2.5.1
    EVN|A01|20240201
    PID|1||MRN-001^^^Hospital^MR||Smith^John^A|||M|||123 Main St^^Anytown^NY^12345
    PV1|1|I|MED^101^A
    """
    let message = try HL7v2Message.parse(incoming)
    print("Step 1: Parsed \(message.messageType()) message")

    // Step 2: Validate the message
    do {
        try message.validate()
        print("Step 2: Message is valid ✅")
    } catch {
        print("Step 2: Validation failed — \(error)")
        return
    }

    // Step 3: Extract patient data
    if let pid = message.segments(withID: "PID").first {
        let name = pid[4].serialize()
        let mrn = pid[2].serialize()
        print("Step 3: Patient \(name) (MRN: \(mrn))")
    }

    // Step 4: Build and send ACK response
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
            msa.field(0, value: "AA")
               .field(1, value: controlID)
        }
        .build()

    let ackString = try ack.serialize()
    print("Step 4: ACK built (\(ackString.count) chars)")
    print("\nWorkflow complete ✅")
}
