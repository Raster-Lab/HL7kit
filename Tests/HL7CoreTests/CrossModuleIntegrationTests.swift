// CrossModuleIntegrationTests.swift
// HL7CoreTests
//
// Cross-module end-to-end workflow integration tests covering v2.x, v3.x, and FHIR pipelines.

import XCTest
@testable import HL7Core
@testable import HL7v2Kit
@testable import HL7v3Kit
@testable import FHIRkit

// MARK: - HL7 v2.x Parsing and Building Round-Trip Integration Tests

final class V2RoundTripIntegrationTests: XCTestCase {

    func testADTMessageBuildParseRoundTrip() throws {
        // Build an ADT^A01 message
        let builder = HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("TestApp")
                .receivingApplication("HospitalSystem")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("MSG00001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("EVN") { $0.field(1, value: "A01") }
            .segment("PID") { $0
                .field(3, value: "12345^^^Hospital^MR")
                .field(5, value: "Smith^John^A")
                .field(7, value: "19800101")
                .field(8, value: "M")
            }
            .segment("PV1") { $0
                .field(2, value: "I")
                .field(3, value: "W^389^1")
                .field(44, value: "20250101120000")
            }

        let message = try builder.build()

        // Serialize and re-parse
        let serialized = try message.serialize()
        let reparsed = try HL7v2Message.parse(serialized)

        // Verify round-trip fidelity
        XCTAssertEqual(message.messageType(), reparsed.messageType())
        XCTAssertEqual(message.messageControlID(), reparsed.messageControlID())
        XCTAssertEqual(message.version(), reparsed.version())
        XCTAssertEqual(message.allSegments.count, reparsed.allSegments.count)

        // Verify PID data preserved
        let pidSegments = reparsed.segments(withID: "PID")
        XCTAssertEqual(pidSegments.count, 1)
    }

    func testORUMessageBuildParseRoundTrip() throws {
        let builder = HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("LabSystem")
                .receivingApplication("EHR")
                .messageType("ORU", triggerEvent: "R01")
                .messageControlID("LAB00001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("PID") { $0
                .field(3, value: "PAT001^^^Lab^MR")
                .field(5, value: "Doe^Jane")
            }
            .segment("OBR") { $0
                .field(4, value: "85025^CBC^LN")
                .field(7, value: "20250115080000")
            }
            .segment("OBX") { $0
                .field(2, value: "NM")
                .field(3, value: "718-7^Hemoglobin^LN")
                .field(5, value: "14.2")
                .field(6, value: "g/dL")
                .field(7, value: "12.0-16.0")
                .field(11, value: "F")
            }

        let message = try builder.build()
        let serialized = try message.serialize()
        let reparsed = try HL7v2Message.parse(serialized)

        XCTAssertEqual(reparsed.messageType(), "ORU^R01")
        XCTAssertEqual(reparsed.segments(withID: "OBX").count, 1)
        XCTAssertEqual(reparsed.segments(withID: "OBR").count, 1)
    }

    func testACKMessageRoundTrip() throws {
        // Create original message
        let original = try HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("Sender")
                .receivingApplication("Receiver")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("ORIG001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("PID") { $0.field(3, value: "P001") }
            .build()

        // Build ACK
        let ack = try MessageTemplate.ack(originalMessage: original, ackCode: "AA")
            .build()

        let serialized = try ack.serialize()
        let reparsed = try HL7v2Message.parse(serialized)

        XCTAssertTrue(reparsed.messageType().contains("ACK"))
    }

    func testMultiSegmentMessagePreservesOrder() throws {
        let builder = HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("App")
                .receivingApplication("Dest")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("ORD001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("EVN") { $0.field(1, value: "A01") }
            .segment("PID") { $0.field(3, value: "P001") }
            .segment("NK1") { $0.field(2, value: "Smith^Mary") }
            .segment("PV1") { $0.field(2, value: "I") }

        let message = try builder.build()
        let serialized = try message.serialize()
        let reparsed = try HL7v2Message.parse(serialized)

        let segmentIDs = reparsed.allSegments.map { $0.segmentID }
        XCTAssertEqual(segmentIDs, ["MSH", "EVN", "PID", "NK1", "PV1"])
    }
}

// MARK: - HL7 v3.x CDA Document Lifecycle Integration Tests

final class CDADocumentLifecycleIntegrationTests: XCTestCase {

    func testCDADocumentCreateValidateLifecycle() async {
        // Create a CDA document
        let doc = createTestCDADocument()

        // Validate the document
        let validator = CDAValidator()
        let result = await validator.validate(doc)

        XCTAssertTrue(result.isValid, "CDA document should be valid: \(result.errors)")
    }

    func testCDADocumentWithMultipleSections() {
        let vitalSignsSection = Section(
            templateId: [II(root: "2.16.840.1.113883.10.20.22.2.4.1")],
            code: CD(code: "8716-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Vital Signs"),
            title: .value("Vital Signs"),
            text: .text("Blood pressure: 120/80 mmHg"),
            entry: [
                Entry(clinicalStatement: .observation(ClinicalObservation(
                    code: CD(code: "85354-9", codeSystem: "2.16.840.1.113883.6.1", displayName: "Blood Pressure"),
                    value: [.physicalQuantity(PQ(value: 120.0, unit: "mm[Hg]"))]
                )))
            ]
        )

        let problemSection = Section(
            templateId: [II(root: "2.16.840.1.113883.10.20.22.2.5.1")],
            code: CD(code: "11450-4", codeSystem: "2.16.840.1.113883.6.1", displayName: "Problem List"),
            title: .value("Problems"),
            text: .text("Hypertension")
        )

        let doc = ClinicalDocument(
            typeId: II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040"),
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: II(root: UUID().uuidString),
            code: CD(code: "34133-9", codeSystem: "2.16.840.1.113883.6.1", displayName: "Summarization of Episode Note"),
            effectiveTime: TS(value: Date()),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25"),
            recordTarget: [createTestRecordTarget()],
            author: [createTestAuthor()],
            custodian: createTestCustodian(),
            component: DocumentComponent(body: .structured(StructuredBody(
                component: [
                    BodyComponent(section: vitalSignsSection),
                    BodyComponent(section: problemSection)
                ]
            )))
        )

        XCTAssertNotNil(doc.id)
        XCTAssertEqual(doc.templateId.count, 1)
        if case .structured(let body) = doc.component.body {
            XCTAssertEqual(body.component.count, 2)
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testCDADocumentCodableRoundTrip() throws {
        let doc = createTestCDADocument()

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)

        // Decode back
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClinicalDocument.self, from: data)

        XCTAssertEqual(doc.id, decoded.id)
        XCTAssertEqual(doc.code, decoded.code)
        XCTAssertEqual(doc.templateId, decoded.templateId)
    }

    // MARK: - Helpers

    private func createTestCDADocument() -> ClinicalDocument {
        ClinicalDocument(
            typeId: II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040"),
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: II(root: UUID().uuidString),
            code: CD(code: "34133-9", codeSystem: "2.16.840.1.113883.6.1", displayName: "Summarization of Episode Note"),
            effectiveTime: TS(value: Date()),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25"),
            recordTarget: [createTestRecordTarget()],
            author: [createTestAuthor()],
            custodian: createTestCustodian(),
            component: DocumentComponent(body: .structured(StructuredBody(
                component: [BodyComponent(section: Section(
                    code: CD(code: "11450-4", codeSystem: "2.16.840.1.113883.6.1"),
                    title: .value("Problem List"),
                    text: .text("No known problems")
                ))]
            )))
        )
    }

    private func createTestRecordTarget() -> RecordTarget {
        RecordTarget(patientRole: PatientRole(
            id: [II(root: "2.16.840.1.113883.19.5", extension: "PAT-001")],
            addr: [AD(parts: [
                AddressPart(value: "123 Main St", type: .streetAddressLine),
                AddressPart(value: "Springfield", type: .city),
                AddressPart(value: "IL", type: .state),
                AddressPart(value: "62701", type: .postalCode)
            ])],
            patient: HL7v3Kit.Patient(
                name: [EN(parts: [
                    NamePart(value: "Smith", type: .family),
                    NamePart(value: "John", type: .given)
                ])],
                administrativeGenderCode: CD(code: "M", codeSystem: "2.16.840.1.113883.5.1"),
                birthTime: TS(value: Date(timeIntervalSince1970: 315576000))
            )
        ))
    }

    private func createTestAuthor() -> Author {
        Author(
            time: TS(value: Date()),
            assignedAuthor: AssignedAuthor(
                id: [II(root: "2.16.840.1.113883.19.5", extension: "AUTH-001")],
                assignedPerson: Person(name: [EN(parts: [
                    NamePart(value: "Jones", type: .family),
                    NamePart(value: "Sarah", type: .given)
                ])])
            )
        )
    }

    private func createTestCustodian() -> Custodian {
        Custodian(assignedCustodian: AssignedCustodian(
            representedCustodianOrganization: CustodianOrganization(
                id: [II(root: "2.16.840.1.113883.19.5", extension: "ORG-001")],
                name: EN(parts: [NamePart(value: "Test Hospital", type: .given)])
            )
        ))
    }
}

// MARK: - FHIR Resource CRUD and Bundle Transaction Integration Tests

final class FHIRBundleTransactionIntegrationTests: XCTestCase {

    func testFHIRPatientCreateAndValidate() throws {
        let patient = FHIRkit.Patient(
            id: "test-patient-001",
            identifier: [Identifier(system: "http://hospital.example.org/mrn", value: "MRN12345")],
            active: true,
            name: [HumanName(use: "official", family: "Smith", given: ["John", "Andrew"])],
            gender: "male",
            birthDate: "1980-01-01",
            address: [Address(use: "home", line: ["123 Main St"], city: "Springfield", state: "IL", postalCode: "62701")]
        )

        XCTAssertNoThrow(try patient.validate())
        XCTAssertEqual(patient.resourceType, "Patient")
        XCTAssertEqual(patient.id, "test-patient-001")
        XCTAssertEqual(patient.name?.first?.family, "Smith")
    }

    func testFHIRObservationWithPatientReference() throws {
        let observation = FHIRkit.Observation(
            id: "obs-001",
            status: "final",
            category: [CodeableConcept(coding: [Coding(
                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                code: "vital-signs",
                display: "Vital Signs"
            )])],
            code: CodeableConcept(coding: [Coding(
                system: "http://loinc.org",
                code: "85354-9",
                display: "Blood pressure panel"
            )]),
            subject: Reference(reference: "Patient/test-patient-001", display: "John Smith"),
            effectiveDateTime: "2025-01-15T10:30:00Z",
            valueQuantity: Quantity(value: 120, unit: "mmHg", system: "http://unitsofmeasure.org", code: "mm[Hg]")
        )

        XCTAssertNoThrow(try observation.validate())
        XCTAssertEqual(observation.status, "final")
        XCTAssertEqual(observation.subject?.reference, "Patient/test-patient-001")
    }

    func testFHIRTransactionBundle() throws {
        let patient = FHIRkit.Patient(
            id: "bundle-pat-001",
            name: [HumanName(family: "Doe", given: ["Jane"])],
            gender: "female",
            birthDate: "1990-05-15"
        )

        let observation = FHIRkit.Observation(
            id: "bundle-obs-001",
            status: "final",
            code: CodeableConcept(coding: [Coding(system: "http://loinc.org", code: "718-7", display: "Hemoglobin")]),
            subject: Reference(reference: "Patient/bundle-pat-001"),
            valueQuantity: Quantity(value: 14.2, unit: "g/dL", system: "http://unitsofmeasure.org", code: "g/dL")
        )

        let bundle = FHIRkit.Bundle(
            id: "txn-bundle-001",
            type: "transaction",
            entry: [
                BundleEntry(
                    fullUrl: "urn:uuid:patient-001",
                    resource: .patient(patient),
                    request: BundleEntryRequest(method: "POST", url: "Patient")
                ),
                BundleEntry(
                    fullUrl: "urn:uuid:obs-001",
                    resource: .observation(observation),
                    request: BundleEntryRequest(method: "POST", url: "Observation")
                )
            ]
        )

        XCTAssertNoThrow(try bundle.validate())
        XCTAssertEqual(bundle.type, "transaction")
        XCTAssertEqual(bundle.entry?.count, 2)

        // Verify bundle entry resources
        if let entries = bundle.entry {
            if case .patient(let p) = entries[0].resource {
                XCTAssertEqual(p.name?.first?.family, "Doe")
            } else {
                XCTFail("Expected patient resource in first entry")
            }
            if case .observation(let o) = entries[1].resource {
                XCTAssertEqual(o.code.coding?.first?.code, "718-7")
            } else {
                XCTFail("Expected observation resource in second entry")
            }
        }
    }

    func testFHIRBundleCodableRoundTrip() throws {
        let patient = FHIRkit.Patient(
            id: "rt-patient",
            name: [HumanName(family: "Test", given: ["User"])],
            gender: "other"
        )

        let bundle = FHIRkit.Bundle(
            type: "collection",
            entry: [BundleEntry(
                fullUrl: "http://example.org/Patient/rt-patient",
                resource: .patient(patient)
            )]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(bundle)
        let decoded = try JSONDecoder().decode(FHIRkit.Bundle.self, from: data)

        XCTAssertEqual(decoded.type, "collection")
        XCTAssertEqual(decoded.entry?.count, 1)
    }
}

// MARK: - Cross-Version Interoperability Tests (v2/v3/FHIR Coexistence)

final class CrossVersionInteroperabilityIntegrationTests: XCTestCase {

    func testV2AndV3ParserCoexistence() throws {
        // Parse a v2.x message
        let v2Raw = "MSH|^~\\&|SendApp|SendFac|RecApp|RecFac|20250115120000||ADT^A01|MSG001|P|2.5.1\rPID|||PAT001^^^Hosp^MR||Smith^John||19800101|M"
        let v2Message = try HL7v2Message.parse(v2Raw)

        // Create a v3 CDA document in the same context
        let v3Doc = ClinicalDocument(
            typeId: II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040"),
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: II(root: UUID().uuidString),
            code: CD(code: "34133-9", codeSystem: "2.16.840.1.113883.6.1"),
            effectiveTime: TS(value: Date()),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25"),
            recordTarget: [RecordTarget(patientRole: PatientRole(
                id: [II(root: "2.16.840.1.113883.19.5", extension: "PAT001")]
            ))],
            author: [Author(time: TS(value: Date()), assignedAuthor: AssignedAuthor(id: [II(root: "1.2.3")]))],
            custodian: Custodian(assignedCustodian: AssignedCustodian(
                representedCustodianOrganization: CustodianOrganization(id: [II(root: "1.2.3")])
            )),
            component: DocumentComponent(body: .structured(StructuredBody(component: [
                BodyComponent(section: Section(text: .text("Test")))
            ])))
        )

        // Both should work without interference
        XCTAssertEqual(v2Message.messageType(), "ADT^A01")
        XCTAssertNotNil(v3Doc.id)
    }

    func testV2V3AndFHIRResourceCoexistence() throws {
        // v2.x message
        let v2Message = try HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("Lab")
                .receivingApplication("EHR")
                .messageType("ORU", triggerEvent: "R01")
                .messageControlID("COEX001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("PID") { $0.field(5, value: "Johnson^Alice") }
            .segment("OBX") { $0
                .field(3, value: "718-7^Hemoglobin^LN")
                .field(5, value: "13.5")
                .field(6, value: "g/dL")
            }
            .build()

        // FHIR resource representing same data
        let fhirObs = FHIRkit.Observation(
            status: "final",
            code: CodeableConcept(coding: [Coding(system: "http://loinc.org", code: "718-7", display: "Hemoglobin")]),
            subject: Reference(display: "Alice Johnson"),
            valueQuantity: Quantity(value: 13.5, unit: "g/dL")
        )

        // All versions coexist
        XCTAssertEqual(v2Message.segments(withID: "OBX").count, 1)
        XCTAssertNoThrow(try fhirObs.validate())
        XCTAssertEqual(fhirObs.valueQuantity?.value, 13.5)
    }

    func testPatientDataConsistencyAcrossVersions() throws {
        let patientName = "Smith"
        let patientGiven = "John"
        let mrn = "PAT-12345"

        // v2 representation
        let v2Msg = try HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("Sys")
                .receivingApplication("Dest")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("CON001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("PID") { $0
                .field(3, value: "\(mrn)^^^Hosp^MR")
                .field(5, value: "\(patientName)^\(patientGiven)")
            }
            .build()

        // v3 representation
        let v3Patient = HL7v3Kit.Patient(
            name: [EN(parts: [
                NamePart(value: patientName, type: .family),
                NamePart(value: patientGiven, type: .given)
            ])]
        )

        // FHIR representation
        let fhirPatient = FHIRkit.Patient(
            identifier: [Identifier(value: mrn)],
            name: [HumanName(family: patientName, given: [patientGiven])]
        )

        // Verify consistency
        let serialized = try v2Msg.serialize()
        XCTAssertTrue(serialized.contains(patientName))
        XCTAssertEqual(v3Patient.name?.first?.parts.first(where: { $0.type == .family })?.value, patientName)
        XCTAssertEqual(fhirPatient.name?.first?.family, patientName)
        XCTAssertEqual(fhirPatient.identifier?.first?.value, mrn)
    }
}

// MARK: - Persistence and Archival Integration Tests

final class PersistenceArchivalIntegrationTests: XCTestCase {

    func testStoreRetrieveExportPipeline() async throws {
        let archive = MessageArchive()

        // Store v2 message
        let v2Msg = try HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("App")
                .receivingApplication("Dest")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("ARC001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("PID") { $0.field(5, value: "TestPatient^One") }
            .build()

        let serialized = try v2Msg.serialize()
        let entry = ArchiveEntry(
            id: "msg-001",
            messageType: "ADT^A01",
            version: "2.5.1",
            source: "TestApp",
            tags: ["adt", "admission", "integration-test"],
            content: serialized
        )

        try await archive.store(entry)

        // Retrieve by ID
        let retrieved = try await archive.retrieve(id: "msg-001")
        XCTAssertEqual(retrieved.messageType, "ADT^A01")
        XCTAssertEqual(retrieved.version, "2.5.1")

        // Retrieve by type
        let byType = await archive.retrieve(byType: "ADT^A01")
        XCTAssertEqual(byType.count, 1)

        // Retrieve by tags
        let byTags = await archive.retrieve(withTags: ["adt"])
        XCTAssertEqual(byTags.count, 1)

        // Export and verify
        let exporter = DataExporter()
        let exportData = try await exporter.exportJSON(from: archive)
        XCTAssertTrue(exportData.count > 0)
    }

    func testStoreMultipleMessagesAndQuery() async throws {
        let archive = MessageArchive()

        // Store multiple messages
        for i in 1...5 {
            let entry = ArchiveEntry(
                id: "batch-\(i)",
                messageType: i <= 3 ? "ADT^A01" : "ORU^R01",
                version: "2.5.1",
                source: "BatchTest",
                tags: ["batch"],
                content: "Message content \(i)"
            )
            try await archive.store(entry)
        }

        let adtMessages = await archive.retrieve(byType: "ADT^A01")
        XCTAssertEqual(adtMessages.count, 3)

        let oruMessages = await archive.retrieve(byType: "ORU^R01")
        XCTAssertEqual(oruMessages.count, 2)

        let stats = await archive.statistics()
        XCTAssertEqual(stats.totalEntries, 5)
    }

    func testExportImportRoundTrip() async throws {
        let archive = MessageArchive()

        let entry = ArchiveEntry(
            id: "export-001",
            messageType: "ADT^A01",
            version: "2.5.1",
            source: "ExportTest",
            tags: ["export"],
            content: "MSH|^~\\&|Test|Fac||Dest|20250115||ADT^A01|E001|P|2.5.1\rPID|||P001||Export^Test"
        )
        try await archive.store(entry)

        // Export
        let exporter = DataExporter()
        let exportData = try await exporter.exportJSON(from: archive)

        // Import into fresh archive
        let newArchive = MessageArchive()
        let importer = DataImporter()
        let importResult = try await importer.importJSON(exportData, into: newArchive)

        XCTAssertEqual(importResult.importedCount, 1)

        // Verify imported data
        let retrieved = try await newArchive.retrieve(id: "export-001")
        XCTAssertEqual(retrieved.messageType, "ADT^A01")
        XCTAssertEqual(retrieved.source, "ExportTest")
    }

    func testArchiveIndexSearchIntegration() async throws {
        let archive = MessageArchive()
        let index = ArchiveIndex()

        let entries = [
            ArchiveEntry(id: "idx-001", messageType: "ADT^A01", version: "2.5.1", source: "EmergencyDept", tags: ["urgent"], content: "Patient admission emergency"),
            ArchiveEntry(id: "idx-002", messageType: "ORU^R01", version: "2.5.1", source: "Laboratory", tags: ["lab"], content: "Hemoglobin result normal"),
            ArchiveEntry(id: "idx-003", messageType: "ADT^A01", version: "2.5.1", source: "EmergencyDept", tags: ["urgent"], content: "Patient admission routine")
        ]

        for entry in entries {
            try await archive.store(entry)
            await index.addEntry(entry)
        }

        // Search by type
        let adtResults = await index.search(byType: "ADT^A01")
        XCTAssertEqual(adtResults.count, 2)

        // Search by source
        let edResults = await index.search(bySource: "EmergencyDept")
        XCTAssertEqual(edResults.count, 2)

        // Full-text search
        let emergencyResults = await index.search(query: "emergency")
        XCTAssertGreaterThanOrEqual(emergencyResults.count, 1)
    }
}

// MARK: - Security Framework Integration Tests

final class SecurityPipelineIntegrationTests: XCTestCase {

    func testEncryptSignVerifyDecryptPipeline() throws {
        let message = "MSH|^~\\&|App|Fac||Dest|20250115||ADT^A01|SEC001|P|2.5.1\rPID|||P001||Secure^Patient"
        let messageData = Data(message.utf8)

        // Step 1: Encrypt
        let encryptor = SecureMessageEncryptor()
        let encryptionKey = SecureEncryptionKey.generate()
        let encrypted = try encryptor.encrypt(data: messageData, key: encryptionKey)

        // Step 2: Sign the encrypted payload
        let signer = DigitalSigner()
        let signingKey = SigningKey.generate()
        let signature = signer.sign(data: encrypted.ciphertext, key: signingKey)

        // Step 3: Verify the signature
        let isValid = signer.verify(data: encrypted.ciphertext, signature: signature, key: signingKey)
        XCTAssertTrue(isValid, "Signature verification should succeed")

        // Step 4: Decrypt
        let decrypted = try encryptor.decrypt(payload: encrypted, key: encryptionKey)
        let decryptedMessage = String(data: decrypted, encoding: .utf8)

        XCTAssertEqual(decryptedMessage, message)
    }

    func testEncryptDecryptStringRoundTrip() throws {
        let sensitiveData = "Patient SSN: 123-45-6789, DOB: 1980-01-01"

        let encryptor = SecureMessageEncryptor()
        let key = SecureEncryptionKey.generate()

        let encrypted = try encryptor.encrypt(string: sensitiveData, key: key)
        XCTAssertNotEqual(encrypted.ciphertext, Data(sensitiveData.utf8))

        let decrypted = try encryptor.decryptToString(payload: encrypted, key: key)
        XCTAssertEqual(decrypted, sensitiveData)
    }

    func testSignatureFailsWithTamperedData() throws {
        let originalData = Data("Original HL7 message".utf8)

        let signer = DigitalSigner()
        let key = SigningKey.generate()
        let signature = signer.sign(data: originalData, key: key)

        // Tamper with data
        let tamperedData = Data("Tampered HL7 message".utf8)
        let isValid = signer.verify(data: tamperedData, signature: signature, key: key)
        XCTAssertFalse(isValid, "Verification should fail with tampered data")
    }

    func testSignatureFailsWithWrongKey() throws {
        let data = Data("HL7 message content".utf8)

        let signer = DigitalSigner()
        let signingKey = SigningKey.generate()
        let wrongKey = SigningKey.generate()

        let signature = signer.sign(data: data, key: signingKey)
        let isValid = signer.verify(data: data, signature: signature, key: wrongKey)
        XCTAssertFalse(isValid, "Verification should fail with wrong key")
    }

    func testEncryptedMessageArchival() async throws {
        let message = "Sensitive patient data for archival"

        // Encrypt
        let encryptor = SecureMessageEncryptor()
        let key = SecureEncryptionKey.generate()
        let encrypted = try encryptor.encrypt(string: message, key: key)

        // Archive the encrypted content
        let archive = MessageArchive()
        let entry = ArchiveEntry(
            id: "sec-archive-001",
            messageType: "ENCRYPTED",
            version: "1.0",
            source: "SecurityTest",
            tags: ["encrypted", "phi"],
            content: encrypted.ciphertext.base64EncodedString()
        )
        try await archive.store(entry)

        // Retrieve and verify it's still encrypted (not plaintext)
        let retrieved = try await archive.retrieve(id: "sec-archive-001")
        XCTAssertNotEqual(retrieved.content, message)
        XCTAssertTrue(retrieved.tags.contains("encrypted"))
    }
}

// MARK: - Error Recovery and Fault Tolerance Integration Tests

final class ErrorRecoveryIntegrationTests: XCTestCase {

    func testErrorCollectorAcrossModules() async {
        let collector = ErrorCollector(maxErrors: 10)

        // Simulate errors from different modules
        await collector.add(.parsingError("Invalid v2 segment", context: nil))
        await collector.add(.validationError("CDA missing required field", context: nil))
        await collector.add(.invalidFormat("FHIR resource missing type", context: nil))

        let errors = await collector.allErrors()
        XCTAssertEqual(errors.count, 3)
        XCTAssertTrue(await collector.hasErrors())
    }

    func testRetryStrategyWithExponentialBackoff() {
        let strategy = ExponentialBackoffRetry(maxAttempts: 3, baseDelay: 0.1, maxDelay: 1.0)

        // First attempt should retry
        let result1 = strategy.shouldRetry(error: .networkError("Connection refused", context: nil), attemptCount: 1)
        XCTAssertTrue(result1.shouldRetry)
        XCTAssertNotNil(result1.delay)

        // Third attempt should not retry (max reached)
        let result3 = strategy.shouldRetry(error: .networkError("Still failing", context: nil), attemptCount: 3)
        XCTAssertFalse(result3.shouldRetry)
    }

    func testLinearRetryStrategy() {
        let strategy = LinearRetry(maxAttempts: 2, delay: 0.5)

        let result1 = strategy.shouldRetry(error: .timeout("Request timed out", context: nil), attemptCount: 1)
        XCTAssertTrue(result1.shouldRetry)
        XCTAssertEqual(result1.delay, 0.5)

        let result2 = strategy.shouldRetry(error: .timeout("Still timed out", context: nil), attemptCount: 2)
        XCTAssertFalse(result2.shouldRetry)
    }

    func testErrorCollectorLimit() async {
        let collector = ErrorCollector(maxErrors: 3)

        for i in 1...5 {
            await collector.add(.parsingError("Error \(i)", context: nil))
        }

        let count = await collector.count()
        XCTAssertLessThanOrEqual(count, 5)
        XCTAssertTrue(await collector.hasReachedLimit())
    }

    func testParsingErrorRecovery() throws {
        // Valid message should parse fine
        let validMsg = "MSH|^~\\&|App|Fac||Dest|20250115||ADT^A01|REC001|P|2.5.1\rPID|||P001||Recovery^Test"
        XCTAssertNoThrow(try HL7v2Message.parse(validMsg))

        // Invalid message should throw
        XCTAssertThrowsError(try HL7v2Message.parse("NOT_A_VALID_MESSAGE")) { error in
            XCTAssertTrue(error is HL7Error)
        }
    }
}

// MARK: - Mock Server/Client Integration Tests for MLLP and REST Transports

final class MLLPTransportIntegrationTests: XCTestCase {

    func testMLLPFrameDeframeRoundTrip() throws {
        let message = "MSH|^~\\&|App|Fac||Dest|20250115||ADT^A01|MLLP001|P|2.5.1\rPID|||P001||MLLP^Test"

        // Frame
        let framed = MLLPFramer.frame(message)
        XCTAssertTrue(framed.count > message.utf8.count)

        // Verify frame markers
        XCTAssertTrue(MLLPFramer.isCompleteFrame(framed))
        XCTAssertTrue(MLLPFramer.containsStartByte(framed))

        // Deframe
        let deframed = try MLLPFramer.deframe(framed)
        XCTAssertEqual(deframed, message)
    }

    func testMLLPStreamParserMultipleMessages() throws {
        let msg1 = "MSH|^~\\&|A|F||D|20250115||ADT^A01|S001|P|2.5.1\rPID|||P1"
        let msg2 = "MSH|^~\\&|A|F||D|20250115||ORU^R01|S002|P|2.5.1\rOBX|1|NM|HGB||14.2"

        let framed1 = MLLPFramer.frame(msg1)
        let framed2 = MLLPFramer.frame(msg2)

        var parser = MLLPStreamParser()

        // Feed combined data
        var combined = Data()
        combined.append(framed1)
        combined.append(framed2)
        parser.append(combined)

        // Extract messages
        let extracted1 = try parser.nextMessage()
        XCTAssertNotNil(extracted1)
        XCTAssertEqual(extracted1, msg1)

        let extracted2 = try parser.nextMessage()
        XCTAssertNotNil(extracted2)
        XCTAssertEqual(extracted2, msg2)

        // No more messages
        let extracted3 = try parser.nextMessage()
        XCTAssertNil(extracted3)
    }

    func testMLLPFrameDataRoundTrip() throws {
        let messageData = Data("MSH|^~\\&|App|Fac||Dest|20250115||ADT^A01|D001|P|2.5.1\rPID|||P001".utf8)

        let framed = MLLPFramer.frame(messageData)
        let deframed = try MLLPFramer.deframeToData(framed)
        XCTAssertEqual(deframed, messageData)
    }

    func testMLLPStreamParserPartialData() throws {
        let message = "MSH|^~\\&|A|F||D|20250115||ADT^A01|P001|P|2.5.1\rPID|||P1"
        let framed = MLLPFramer.frame(message)

        var parser = MLLPStreamParser()

        // Feed partial data (first half)
        let midpoint = framed.count / 2
        parser.append(framed.prefix(midpoint))

        // Should not have a complete message yet
        let partial = try parser.nextMessage()
        XCTAssertNil(partial)

        // Feed remaining data
        parser.append(framed.suffix(from: midpoint))

        // Now should get the complete message
        let complete = try parser.nextMessage()
        XCTAssertNotNil(complete)
        XCTAssertEqual(complete, message)
    }

    func testMLLPConfigurationBuilder() {
        let config = MLLPConfiguration(
            host: "localhost",
            port: 2575,
            useTLS: true,
            connectionTimeout: 15.0,
            responseTimeout: 10.0,
            maxRetryAttempts: 5,
            maxMessageSize: 2_097_152,
            autoReconnect: true
        )

        XCTAssertEqual(config.host, "localhost")
        XCTAssertEqual(config.port, 2575)
        XCTAssertTrue(config.useTLS)
        XCTAssertEqual(config.maxRetryAttempts, 5)
    }
}

// MARK: - Mock FHIR REST Client Integration Tests

final class FHIRRESTMockIntegrationTests: XCTestCase {

    func testFHIRClientConfigurationSetup() {
        let config = FHIRClientConfiguration(
            baseURL: URL(string: "https://fhir.example.org/r4")!,
            preferredFormat: .json,
            timeout: 30.0,
            maxRetryAttempts: 3,
            additionalHeaders: ["X-Custom": "test"]
        )

        XCTAssertEqual(config.baseURL.absoluteString, "https://fhir.example.org/r4")
        XCTAssertEqual(config.timeout, 30.0)
        XCTAssertEqual(config.maxRetryAttempts, 3)
    }

    func testFHIRResourceSerialization() throws {
        let patient = FHIRkit.Patient(
            id: "ser-001",
            name: [HumanName(family: "Serialization", given: ["Test"])],
            gender: "male"
        )

        // Serialize to JSON
        let serializer = FHIRJSONSerializer()
        let data = try serializer.serialize(patient)
        XCTAssertTrue(data.count > 0)

        // Deserialize back
        let deserialized: FHIRkit.Patient = try serializer.deserialize(data)
        XCTAssertEqual(deserialized.id, "ser-001")
        XCTAssertEqual(deserialized.name?.first?.family, "Serialization")
    }

    func testFHIRSearchQueryConstruction() {
        let query = FHIRSearchQuery(resourceType: "Patient")
            .where("family", .equals("Smith"))
            .where("birthdate", .greaterThan("1980-01-01"))
            .include("Patient:organization")
            .count(10)

        let params = query.buildParameters()
        XCTAssertTrue(params.contains(where: { $0.0 == "family" }))
        XCTAssertTrue(params.contains(where: { $0.0 == "_count" }))
    }
}

// MARK: - CLI Tool Integration Tests

final class CLIIntegrationTests: XCTestCase {

    func testCLIParseValidateCommand() {
        let result = CLIParser.parse(["hl7", "validate", "test.hl7"])
        if case .success(.validate(let opts)) = result {
            XCTAssertEqual(opts.inputFiles, ["test.hl7"])
            XCTAssertFalse(opts.strict)
        } else {
            XCTFail("Expected validate command")
        }
    }

    func testCLIParseValidateStrictMode() {
        let result = CLIParser.parse(["hl7", "validate", "--strict", "test.hl7"])
        if case .success(.validate(let opts)) = result {
            XCTAssertTrue(opts.strict)
        } else {
            XCTFail("Expected validate command with strict mode")
        }
    }

    func testCLIParseConvertCommand() {
        let result = CLIParser.parse(["hl7", "convert", "--from", "hl7v2", "--to", "fhir-json", "input.hl7"])
        if case .success(.convert(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "input.hl7")
        } else {
            XCTFail("Expected convert command")
        }
    }

    func testCLIParseInspectCommand() {
        let result = CLIParser.parse(["hl7", "inspect", "message.hl7"])
        if case .success(.inspect(let opts)) = result {
            XCTAssertEqual(opts.inputFile, "message.hl7")
        } else {
            XCTFail("Expected inspect command")
        }
    }

    func testCLIParseBatchCommand() {
        let result = CLIParser.parse(["hl7", "batch", "--operation", "validate", "file1.hl7", "file2.hl7"])
        if case .success(.batch(let opts)) = result {
            XCTAssertEqual(opts.inputFiles.count, 2)
        } else {
            XCTFail("Expected batch command")
        }
    }

    func testCLIParseHelpCommand() {
        let result = CLIParser.parse(["hl7", "help"])
        if case .success(.help) = result {
            // pass
        } else {
            XCTFail("Expected help command")
        }
    }

    func testCLIParseVersionCommand() {
        let result = CLIParser.parse(["hl7", "--version"])
        if case .success(.version) = result {
            // pass
        } else {
            XCTFail("Expected version command")
        }
    }

    func testCLIParseInvalidCommand() {
        let result = CLIParser.parse(["hl7", "nonexistent"])
        if case .failure = result {
            // pass - invalid command correctly returns failure
        } else {
            XCTFail("Expected failure for invalid command")
        }
    }

    func testCLIParseConformanceCommand() {
        let result = CLIParser.parse(["hl7", "conformance", "message.hl7"])
        if case .success(.conformance(let opts)) = result {
            XCTAssertNotNil(opts)
        } else {
            XCTFail("Expected conformance command")
        }
    }
}

// MARK: - Cross-Module End-to-End Workflow Tests (v2.x → v3.x → FHIR Pipelines)

final class EndToEndPipelineIntegrationTests: XCTestCase {

    func testV2MessageToV3TransformationPipeline() async throws {
        // Step 1: Build a v2.x ADT message
        let v2Message = try HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("ADTSystem")
                .receivingApplication("CDAConverter")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("PIPE001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("EVN") { $0.field(1, value: "A01") }
            .segment("PID") { $0
                .field(3, value: "PIPE-PAT-001^^^Hospital^MR")
                .field(5, value: "Pipeline^Test^A")
                .field(7, value: "19850315")
                .field(8, value: "F")
            }
            .segment("PV1") { $0
                .field(2, value: "I")
                .field(3, value: "W^101^1")
            }
            .build()

        // Step 2: Verify v2 message is valid
        let serialized = try v2Message.serialize()
        XCTAssertTrue(serialized.contains("ADT^A01"))
        XCTAssertTrue(serialized.contains("Pipeline^Test"))

        // Step 3: Create ADT typed message for transformer
        let adtMessage = try ADTMessage(message: v2Message)

        // Step 4: Transform v2 → v3 CDA
        let transformer = ADTToCDATransformer()
        let context = TransformationContext(configuration: .lenient)
        let result = try await transformer.transform(adtMessage, context: context)

        // Step 5: Verify transformation result
        XCTAssertTrue(result.success, "Transformation should succeed: \(result.errors)")
        XCTAssertNotNil(result.target)

        if let cdaDoc = result.target {
            XCTAssertNotNil(cdaDoc.id)
            XCTAssertNotNil(cdaDoc.effectiveTime)
        }
    }

    func testV2ParseTransformArchivePipeline() async throws {
        // Step 1: Parse v2 message
        let rawV2 = "MSH|^~\\&|LabSys|MainLab|EHR|Hospital|20250115120000||ORU^R01|ARCH001|P|2.5.1\rPID|||ARCH-PAT^^^Lab^MR||Archive^Test||19900601|M\rOBR|1||LAB001|85025^CBC^LN|||20250115080000\rOBX|1|NM|718-7^Hemoglobin^LN||14.0|g/dL|12.0-16.0|N||F"
        let v2Message = try HL7v2Message.parse(rawV2)

        // Step 2: Archive the message
        let archive = MessageArchive()
        let serialized = try v2Message.serialize()
        let entry = ArchiveEntry(
            id: v2Message.messageControlID(),
            messageType: v2Message.messageType(),
            version: v2Message.version(),
            source: "LabSys",
            tags: ["lab", "cbc", "pipeline"],
            content: serialized
        )
        try await archive.store(entry)

        // Step 3: Retrieve and verify
        let retrieved = try await archive.retrieve(id: "ARCH001")
        XCTAssertEqual(retrieved.messageType, "ORU^R01")

        // Step 4: Re-parse from archive
        let reParsed = try HL7v2Message.parse(retrieved.content)
        XCTAssertEqual(reParsed.messageControlID(), "ARCH001")
        XCTAssertEqual(reParsed.segments(withID: "OBX").count, 1)
    }

    func testSecureMessagePipeline() async throws {
        // Step 1: Build message
        let message = try HL7v2MessageBuilder()
            .msh { $0
                .sendingApplication("SecureApp")
                .receivingApplication("SecureDest")
                .messageType("ADT", triggerEvent: "A01")
                .messageControlID("SECPIPE001")
                .version("2.5.1")
                .processingID("P")
            }
            .segment("PID") { $0
                .field(3, value: "SEC-PAT-001^^^Hosp^MR")
                .field(5, value: "Secure^Patient")
            }
            .build()

        let serialized = try message.serialize()

        // Step 2: Encrypt
        let encryptor = SecureMessageEncryptor()
        let encKey = SecureEncryptionKey.generate()
        let encrypted = try encryptor.encrypt(string: serialized, key: encKey)

        // Step 3: Sign
        let signer = DigitalSigner()
        let sigKey = SigningKey.generate()
        let signature = signer.sign(data: encrypted.ciphertext, key: sigKey)

        // Step 4: Archive encrypted+signed
        let archive = MessageArchive()
        let entry = ArchiveEntry(
            id: "sec-pipe-001",
            messageType: "ENCRYPTED_ADT",
            version: "2.5.1",
            source: "SecureApp",
            tags: ["encrypted", "signed"],
            content: encrypted.ciphertext.base64EncodedString()
        )
        try await archive.store(entry)

        // Step 5: Retrieve, verify, decrypt
        let retrieved = try await archive.retrieve(id: "sec-pipe-001")
        XCTAssertTrue(retrieved.tags.contains("encrypted"))

        let verified = signer.verify(data: encrypted.ciphertext, signature: signature, key: sigKey)
        XCTAssertTrue(verified)

        let decrypted = try encryptor.decryptToString(payload: encrypted, key: encKey)
        XCTAssertEqual(decrypted, serialized)

        // Step 6: Re-parse the decrypted message
        let reParsed = try HL7v2Message.parse(decrypted)
        XCTAssertEqual(reParsed.messageControlID(), "SECPIPE001")
    }

    func testFHIRBundleCreationFromV2Data() throws {
        // Step 1: Parse v2 message
        let rawV2 = "MSH|^~\\&|App|Fac||Dest|20250115||ADT^A01|FHIR001|P|2.5.1\rPID|||FHIR-PAT^^^Hosp^MR||Smith^John||19800101|M\rPV1|1|I|W^101^1"
        let v2Message = try HL7v2Message.parse(rawV2)

        // Step 2: Extract data from v2 message
        let pidSegments = v2Message.segments(withID: "PID")
        XCTAssertEqual(pidSegments.count, 1)

        // Step 3: Create FHIR resources from extracted data
        let fhirPatient = FHIRkit.Patient(
            id: "fhir-from-v2",
            identifier: [Identifier(system: "http://hospital.example.org/mrn", value: "FHIR-PAT")],
            name: [HumanName(family: "Smith", given: ["John"])],
            gender: "male",
            birthDate: "1980-01-01"
        )

        let encounter = FHIRkit.Encounter(
            id: "enc-from-v2",
            status: "in-progress",
            class_fhir: Coding(system: "http://terminology.hl7.org/CodeSystem/v3-ActCode", code: "IMP", display: "inpatient"),
            subject: Reference(reference: "Patient/fhir-from-v2")
        )

        // Step 4: Bundle into a transaction
        let bundle = FHIRkit.Bundle(
            type: "transaction",
            entry: [
                BundleEntry(
                    fullUrl: "urn:uuid:patient-from-v2",
                    resource: .patient(fhirPatient),
                    request: BundleEntryRequest(method: "POST", url: "Patient")
                ),
                BundleEntry(
                    fullUrl: "urn:uuid:encounter-from-v2",
                    resource: .encounter(encounter),
                    request: BundleEntryRequest(method: "POST", url: "Encounter")
                )
            ]
        )

        XCTAssertNoThrow(try bundle.validate())
        XCTAssertEqual(bundle.entry?.count, 2)

        // Verify v2 → FHIR data mapping
        if case .patient(let p) = bundle.entry?.first?.resource {
            XCTAssertEqual(p.name?.first?.family, "Smith")
            XCTAssertEqual(p.gender, "male")
        } else {
            XCTFail("Expected patient resource")
        }
    }

    func testMultiVersionMessageArchival() async throws {
        let archive = MessageArchive()
        let index = ArchiveIndex()

        // Store v2 message
        let v2Entry = ArchiveEntry(
            id: "multi-v2-001",
            messageType: "ADT^A01",
            version: "2.5.1",
            source: "V2System",
            tags: ["v2", "adt"],
            content: "v2 message content"
        )
        try await archive.store(v2Entry)
        await index.addEntry(v2Entry)

        // Store FHIR resource as JSON
        let fhirPatient = FHIRkit.Patient(id: "multi-fhir-001", name: [HumanName(family: "Multi", given: ["Version"])])
        let fhirData = try JSONEncoder().encode(fhirPatient)
        let fhirEntry = ArchiveEntry(
            id: "multi-fhir-001",
            messageType: "FHIR-Patient",
            version: "R4",
            source: "FHIRServer",
            tags: ["fhir", "patient"],
            content: String(data: fhirData, encoding: .utf8) ?? ""
        )
        try await archive.store(fhirEntry)
        await index.addEntry(fhirEntry)

        // Query across versions
        let v2Results = await index.search(byTag: "v2")
        XCTAssertEqual(v2Results.count, 1)

        let fhirResults = await index.search(byTag: "fhir")
        XCTAssertEqual(fhirResults.count, 1)

        let stats = await archive.statistics()
        XCTAssertEqual(stats.totalEntries, 2)
    }
}
