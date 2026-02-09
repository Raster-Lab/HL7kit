/// FHIRResourcesTests.swift
/// Tests for FHIR R4 resource implementations

import XCTest
@testable import FHIRkit
@testable import HL7Core

final class FHIRResourcesTests: XCTestCase {
    
    // MARK: - Practitioner Tests
    
    func testPractitionerCreation() {
        let practitioner = Practitioner(
            id: "pract-001",
            identifier: [Identifier(system: "http://hospital.org/npi", value: "1234567890")],
            active: true,
            name: [HumanName(family: "Smith", given: ["Alice"])],
            gender: "female",
            birthDate: "1975-05-20"
        )
        
        XCTAssertEqual(practitioner.resourceType, "Practitioner")
        XCTAssertEqual(practitioner.id, "pract-001")
        XCTAssertEqual(practitioner.active, true)
        XCTAssertEqual(practitioner.name?.first?.family, "Smith")
        XCTAssertEqual(practitioner.gender, "female")
        XCTAssertEqual(practitioner.birthDate, "1975-05-20")
    }
    
    func testPractitionerWithQualification() {
        let qualification = PractitionerQualification(
            code: CodeableConcept(
                coding: [Coding(system: "http://terminology.hl7.org/CodeSystem/v2-0360", code: "MD")],
                text: "Doctor of Medicine"
            ),
            period: Period(start: "2000-06-15"),
            issuer: Reference(reference: "Organization/medical-board")
        )
        let practitioner = Practitioner(
            id: "pract-002",
            qualification: [qualification]
        )
        
        XCTAssertEqual(practitioner.qualification?.count, 1)
        XCTAssertEqual(practitioner.qualification?[0].code.text, "Doctor of Medicine")
        XCTAssertNotNil(practitioner.qualification?[0].issuer)
    }
    
    func testPractitionerValidation() throws {
        let practitioner = Practitioner(id: "pract-001", name: [HumanName(family: "Smith")])
        XCTAssertNoThrow(try practitioner.validate())
    }
    
    func testPractitionerCodable() throws {
        let practitioner = Practitioner(
            id: "pract-001",
            active: true,
            name: [HumanName(family: "Smith", given: ["Alice"])],
            gender: "female"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(practitioner)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Practitioner.self, from: data)
        
        XCTAssertEqual(decoded.resourceType, "Practitioner")
        XCTAssertEqual(decoded.id, "pract-001")
        XCTAssertEqual(decoded.active, true)
        XCTAssertEqual(decoded.name?.first?.family, "Smith")
    }
    
    func testPractitionerWithContactInfo() {
        let practitioner = Practitioner(
            id: "pract-003",
            telecom: [ContactPoint(system: "phone", value: "+1-555-000-1234")],
            address: [Address(city: "Boston", state: "MA")]
        )
        
        XCTAssertEqual(practitioner.telecom?.count, 1)
        XCTAssertEqual(practitioner.address?.first?.city, "Boston")
    }
    
    // MARK: - Organization Tests
    
    func testOrganizationCreation() {
        let org = Organization(
            id: "org-001",
            active: true,
            type: [CodeableConcept(text: "Hospital")],
            name: "General Hospital",
            alias: ["GH", "City General"]
        )
        
        XCTAssertEqual(org.resourceType, "Organization")
        XCTAssertEqual(org.id, "org-001")
        XCTAssertEqual(org.active, true)
        XCTAssertEqual(org.name, "General Hospital")
        XCTAssertEqual(org.alias?.count, 2)
    }
    
    func testOrganizationWithPartOf() {
        let org = Organization(
            id: "org-dept",
            name: "Cardiology Department",
            partOf: Reference(reference: "Organization/org-001", display: "General Hospital")
        )
        
        XCTAssertNotNil(org.partOf)
        XCTAssertEqual(org.partOf?.display, "General Hospital")
    }
    
    func testOrganizationValidation() throws {
        let org = Organization(id: "org-001", name: "Test Org")
        XCTAssertNoThrow(try org.validate())
    }
    
    func testOrganizationCodable() throws {
        let org = Organization(
            id: "org-001",
            active: true,
            name: "General Hospital",
            telecom: [ContactPoint(system: "phone", value: "+1-555-000-0000")]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(org)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Organization.self, from: data)
        
        XCTAssertEqual(decoded.name, "General Hospital")
        XCTAssertEqual(decoded.active, true)
    }
    
    // MARK: - Condition Tests
    
    func testConditionCreation() {
        let condition = Condition(
            id: "cond-001",
            clinicalStatus: CodeableConcept(
                coding: [Coding(system: "http://terminology.hl7.org/CodeSystem/condition-clinical", code: "active")]
            ),
            code: CodeableConcept(
                coding: [Coding(system: "http://snomed.info/sct", code: "38341003", display: "Hypertension")],
                text: "Hypertension"
            ),
            subject: Reference(reference: "Patient/patient-123"),
            onsetDateTime: "2020-03-15",
            recordedDate: "2020-03-15"
        )
        
        XCTAssertEqual(condition.resourceType, "Condition")
        XCTAssertEqual(condition.id, "cond-001")
        XCTAssertEqual(condition.code?.text, "Hypertension")
        XCTAssertEqual(condition.subject.reference, "Patient/patient-123")
        XCTAssertEqual(condition.onsetDateTime, "2020-03-15")
    }
    
    func testConditionWithOnsetAge() {
        let condition = Condition(
            id: "cond-002",
            subject: Reference(reference: "Patient/patient-123"),
            onsetAge: Quantity(value: 45, unit: "years")
        )
        
        XCTAssertNotNil(condition.onsetAge)
        XCTAssertEqual(condition.onsetAge?.value, 45)
    }
    
    func testConditionWithOnsetPeriod() {
        let condition = Condition(
            id: "cond-003",
            subject: Reference(reference: "Patient/patient-123"),
            onsetPeriod: Period(start: "2020-01-01", end: "2020-06-01")
        )
        
        XCTAssertNotNil(condition.onsetPeriod)
        XCTAssertEqual(condition.onsetPeriod?.start, "2020-01-01")
    }
    
    func testConditionValidation() throws {
        let condition = Condition(
            id: "cond-001",
            subject: Reference(reference: "Patient/patient-123")
        )
        XCTAssertNoThrow(try condition.validate())
    }
    
    func testConditionCodable() throws {
        let condition = Condition(
            id: "cond-001",
            code: CodeableConcept(text: "Hypertension"),
            subject: Reference(reference: "Patient/patient-123"),
            note: [Annotation(text: "Condition noted during routine visit")]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(condition)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Condition.self, from: data)
        
        XCTAssertEqual(decoded.id, "cond-001")
        XCTAssertEqual(decoded.subject.reference, "Patient/patient-123")
        XCTAssertEqual(decoded.note?.first?.text, "Condition noted during routine visit")
    }
    
    func testConditionWithSeverity() {
        let condition = Condition(
            id: "cond-004",
            severity: CodeableConcept(
                coding: [Coding(system: "http://snomed.info/sct", code: "24484000", display: "Severe")]
            ),
            subject: Reference(reference: "Patient/patient-123")
        )
        
        XCTAssertNotNil(condition.severity)
        XCTAssertEqual(condition.severity?.coding?.first?.display, "Severe")
    }
    
    // MARK: - AllergyIntolerance Tests
    
    func testAllergyIntoleranceCreation() {
        let allergy = AllergyIntolerance(
            id: "allergy-001",
            clinicalStatus: CodeableConcept(
                coding: [Coding(system: "http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical", code: "active")]
            ),
            type: "allergy",
            category: ["medication"],
            criticality: "high",
            code: CodeableConcept(
                coding: [Coding(system: "http://www.nlm.nih.gov/research/umls/rxnorm", code: "7980", display: "Penicillin")],
                text: "Penicillin"
            ),
            patient: Reference(reference: "Patient/patient-123")
        )
        
        XCTAssertEqual(allergy.resourceType, "AllergyIntolerance")
        XCTAssertEqual(allergy.id, "allergy-001")
        XCTAssertEqual(allergy.type, "allergy")
        XCTAssertEqual(allergy.category, ["medication"])
        XCTAssertEqual(allergy.criticality, "high")
        XCTAssertEqual(allergy.code?.text, "Penicillin")
        XCTAssertEqual(allergy.patient.reference, "Patient/patient-123")
    }
    
    func testAllergyIntoleranceWithReaction() {
        let reaction = AllergyIntoleranceReaction(
            substance: CodeableConcept(text: "Penicillin"),
            manifestation: [CodeableConcept(text: "Hives"), CodeableConcept(text: "Anaphylaxis")],
            description_: "Severe allergic reaction",
            onset: "2020-01-15",
            severity: "severe",
            exposureRoute: CodeableConcept(text: "Oral")
        )
        let allergy = AllergyIntolerance(
            id: "allergy-002",
            patient: Reference(reference: "Patient/patient-123"),
            reaction: [reaction]
        )
        
        XCTAssertEqual(allergy.reaction?.count, 1)
        XCTAssertEqual(allergy.reaction?[0].manifestation.count, 2)
        XCTAssertEqual(allergy.reaction?[0].severity, "severe")
        XCTAssertEqual(allergy.reaction?[0].description_, "Severe allergic reaction")
    }
    
    func testAllergyIntoleranceValidation() throws {
        let allergy = AllergyIntolerance(
            id: "allergy-001",
            patient: Reference(reference: "Patient/patient-123")
        )
        XCTAssertNoThrow(try allergy.validate())
    }
    
    func testAllergyIntoleranceCodable() throws {
        let reaction = AllergyIntoleranceReaction(
            manifestation: [CodeableConcept(text: "Hives")],
            description_: "Mild reaction"
        )
        let allergy = AllergyIntolerance(
            id: "allergy-001",
            type: "allergy",
            patient: Reference(reference: "Patient/patient-123"),
            reaction: [reaction]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(allergy)
        
        let jsonString = String(data: data, encoding: .utf8)!
        // Verify "description" is the JSON key (not "description_")
        XCTAssertTrue(jsonString.contains("\"description\""))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AllergyIntolerance.self, from: data)
        
        XCTAssertEqual(decoded.id, "allergy-001")
        XCTAssertEqual(decoded.reaction?[0].description_, "Mild reaction")
    }
    
    // MARK: - Encounter Tests
    
    func testEncounterCreation() {
        let encounter = Encounter(
            id: "enc-001",
            status: "in-progress",
            class_: Coding(
                system: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                code: "IMP",
                display: "inpatient encounter"
            ),
            subject: Reference(reference: "Patient/patient-123"),
            period: Period(start: "2024-01-15T08:00:00Z")
        )
        
        XCTAssertEqual(encounter.resourceType, "Encounter")
        XCTAssertEqual(encounter.id, "enc-001")
        XCTAssertEqual(encounter.status, "in-progress")
        XCTAssertEqual(encounter.class_.code, "IMP")
        XCTAssertEqual(encounter.subject?.reference, "Patient/patient-123")
    }
    
    func testEncounterWithParticipants() {
        let participant = EncounterParticipant(
            type: [CodeableConcept(text: "Attending")],
            individual: Reference(reference: "Practitioner/pract-001")
        )
        let encounter = Encounter(
            id: "enc-002",
            status: "finished",
            class_: Coding(code: "AMB"),
            participant: [participant]
        )
        
        XCTAssertEqual(encounter.participant?.count, 1)
        XCTAssertEqual(encounter.participant?[0].individual?.reference, "Practitioner/pract-001")
    }
    
    func testEncounterWithHospitalization() {
        let hospitalization = EncounterHospitalization(
            admitSource: CodeableConcept(text: "Emergency"),
            dischargeDisposition: CodeableConcept(text: "Home"),
            destination: Reference(reference: "Location/home")
        )
        let encounter = Encounter(
            id: "enc-003",
            status: "finished",
            class_: Coding(code: "IMP"),
            hospitalization: hospitalization
        )
        
        XCTAssertNotNil(encounter.hospitalization)
        XCTAssertEqual(encounter.hospitalization?.admitSource?.text, "Emergency")
        XCTAssertEqual(encounter.hospitalization?.dischargeDisposition?.text, "Home")
    }
    
    func testEncounterWithStatusHistory() {
        let history = [
            EncounterStatusHistory(status: "planned", period: Period(start: "2024-01-14")),
            EncounterStatusHistory(status: "arrived", period: Period(start: "2024-01-15T08:00:00Z")),
            EncounterStatusHistory(status: "in-progress", period: Period(start: "2024-01-15T08:30:00Z"))
        ]
        let encounter = Encounter(
            id: "enc-004",
            status: "in-progress",
            statusHistory: history,
            class_: Coding(code: "IMP")
        )
        
        XCTAssertEqual(encounter.statusHistory?.count, 3)
    }
    
    func testEncounterWithLocation() {
        let location = EncounterLocation(
            location: Reference(reference: "Location/room-101"),
            status: "active"
        )
        let encounter = Encounter(
            id: "enc-005",
            status: "in-progress",
            class_: Coding(code: "IMP"),
            location: [location]
        )
        
        XCTAssertEqual(encounter.location?.count, 1)
        XCTAssertEqual(encounter.location?[0].status, "active")
    }
    
    func testEncounterValidation() throws {
        let encounter = Encounter(
            id: "enc-001",
            status: "in-progress",
            class_: Coding(code: "IMP")
        )
        XCTAssertNoThrow(try encounter.validate())
    }
    
    func testEncounterValidationEmptyStatus() {
        let encounter = Encounter(
            id: "enc-001",
            status: "",
            class_: Coding(code: "IMP")
        )
        
        XCTAssertThrowsError(try encounter.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testEncounterCodableWithClassCodingKey() throws {
        let encounter = Encounter(
            id: "enc-001",
            status: "in-progress",
            class_: Coding(code: "IMP", display: "inpatient")
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(encounter)
        
        let jsonString = String(data: data, encoding: .utf8)!
        // Verify "class" is the JSON key (not "class_")
        XCTAssertTrue(jsonString.contains("\"class\""))
        XCTAssertFalse(jsonString.contains("\"class_\""))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Encounter.self, from: data)
        
        XCTAssertEqual(decoded.class_.code, "IMP")
        XCTAssertEqual(decoded.class_.display, "inpatient")
    }
    
    // MARK: - MedicationRequest Tests
    
    func testMedicationRequestCreation() {
        let medRequest = MedicationRequest(
            id: "med-001",
            status: "active",
            intent: "order",
            medicationCodeableConcept: CodeableConcept(
                coding: [Coding(system: "http://www.nlm.nih.gov/research/umls/rxnorm", code: "1049502", display: "Lisinopril 10mg")],
                text: "Lisinopril 10mg"
            ),
            subject: Reference(reference: "Patient/patient-123"),
            authoredOn: "2024-01-15"
        )
        
        XCTAssertEqual(medRequest.resourceType, "MedicationRequest")
        XCTAssertEqual(medRequest.id, "med-001")
        XCTAssertEqual(medRequest.status, "active")
        XCTAssertEqual(medRequest.intent, "order")
        XCTAssertEqual(medRequest.medicationCodeableConcept?.text, "Lisinopril 10mg")
        XCTAssertEqual(medRequest.subject.reference, "Patient/patient-123")
    }
    
    func testMedicationRequestWithDosage() {
        let dosage = DosageInstruction(
            sequence: 1,
            text: "Take 1 tablet by mouth once daily",
            route: CodeableConcept(text: "Oral"),
            doseQuantity: Quantity(value: 10, unit: "mg")
        )
        let medRequest = MedicationRequest(
            id: "med-002",
            status: "active",
            intent: "order",
            subject: Reference(reference: "Patient/patient-123"),
            dosageInstruction: [dosage]
        )
        
        XCTAssertEqual(medRequest.dosageInstruction?.count, 1)
        XCTAssertEqual(medRequest.dosageInstruction?[0].doseQuantity?.value, 10)
        XCTAssertEqual(medRequest.dosageInstruction?[0].text, "Take 1 tablet by mouth once daily")
    }
    
    func testMedicationRequestWithMedicationReference() {
        let medRequest = MedicationRequest(
            id: "med-003",
            status: "active",
            intent: "order",
            medicationReference: Reference(reference: "Medication/med-lisinopril"),
            subject: Reference(reference: "Patient/patient-123")
        )
        
        XCTAssertNotNil(medRequest.medicationReference)
        XCTAssertNil(medRequest.medicationCodeableConcept)
    }
    
    func testMedicationRequestValidation() throws {
        let medRequest = MedicationRequest(
            id: "med-001",
            status: "active",
            intent: "order",
            subject: Reference(reference: "Patient/patient-123")
        )
        XCTAssertNoThrow(try medRequest.validate())
    }
    
    func testMedicationRequestValidationEmptyStatus() {
        let medRequest = MedicationRequest(
            id: "med-001",
            status: "",
            intent: "order",
            subject: Reference(reference: "Patient/patient-123")
        )
        
        XCTAssertThrowsError(try medRequest.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testMedicationRequestValidationEmptyIntent() {
        let medRequest = MedicationRequest(
            id: "med-001",
            status: "active",
            intent: "",
            subject: Reference(reference: "Patient/patient-123")
        )
        
        XCTAssertThrowsError(try medRequest.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testMedicationRequestCodable() throws {
        let medRequest = MedicationRequest(
            id: "med-001",
            status: "active",
            intent: "order",
            priority: "routine",
            subject: Reference(reference: "Patient/patient-123")
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(medRequest)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MedicationRequest.self, from: data)
        
        XCTAssertEqual(decoded.status, "active")
        XCTAssertEqual(decoded.intent, "order")
        XCTAssertEqual(decoded.priority, "routine")
    }
    
    // MARK: - DiagnosticReport Tests
    
    func testDiagnosticReportCreation() {
        let report = DiagnosticReport(
            id: "report-001",
            status: "final",
            category: [CodeableConcept(text: "Laboratory")],
            code: CodeableConcept(
                coding: [Coding(system: "http://loinc.org", code: "58410-2", display: "CBC panel")],
                text: "Complete Blood Count"
            ),
            subject: Reference(reference: "Patient/patient-123"),
            effectiveDateTime: "2024-01-15T10:00:00Z",
            conclusion: "Normal results"
        )
        
        XCTAssertEqual(report.resourceType, "DiagnosticReport")
        XCTAssertEqual(report.id, "report-001")
        XCTAssertEqual(report.status, "final")
        XCTAssertEqual(report.code.text, "Complete Blood Count")
        XCTAssertEqual(report.conclusion, "Normal results")
    }
    
    func testDiagnosticReportWithResults() {
        let report = DiagnosticReport(
            id: "report-002",
            status: "final",
            code: CodeableConcept(text: "CBC"),
            result: [
                Reference(reference: "Observation/obs-wbc"),
                Reference(reference: "Observation/obs-rbc"),
                Reference(reference: "Observation/obs-hgb")
            ]
        )
        
        XCTAssertEqual(report.result?.count, 3)
    }
    
    func testDiagnosticReportWithPresentedForm() {
        let report = DiagnosticReport(
            id: "report-003",
            status: "final",
            code: CodeableConcept(text: "Radiology"),
            presentedForm: [Attachment(contentType: "application/pdf", title: "Report.pdf")]
        )
        
        XCTAssertEqual(report.presentedForm?.count, 1)
        XCTAssertEqual(report.presentedForm?[0].contentType, "application/pdf")
    }
    
    func testDiagnosticReportValidation() throws {
        let report = DiagnosticReport(
            id: "report-001",
            status: "final",
            code: CodeableConcept(text: "CBC")
        )
        XCTAssertNoThrow(try report.validate())
    }
    
    func testDiagnosticReportValidationEmptyStatus() {
        let report = DiagnosticReport(
            id: "report-001",
            status: "",
            code: CodeableConcept(text: "CBC")
        )
        
        XCTAssertThrowsError(try report.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testDiagnosticReportCodable() throws {
        let report = DiagnosticReport(
            id: "report-001",
            status: "final",
            code: CodeableConcept(text: "CBC"),
            conclusion: "Normal"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiagnosticReport.self, from: data)
        
        XCTAssertEqual(decoded.status, "final")
        XCTAssertEqual(decoded.conclusion, "Normal")
    }
    
    // MARK: - Bundle Tests
    
    func testBundleCreation() {
        let bundle = Bundle(
            id: "bundle-001",
            type: "searchset",
            total: 2
        )
        
        XCTAssertEqual(bundle.resourceType, "Bundle")
        XCTAssertEqual(bundle.id, "bundle-001")
        XCTAssertEqual(bundle.type, "searchset")
        XCTAssertEqual(bundle.total, 2)
    }
    
    func testBundleWithLinks() {
        let bundle = Bundle(
            id: "bundle-002",
            type: "searchset",
            link: [
                BundleLink(relation: "self", url: "http://example.com/fhir/Patient?name=Smith"),
                BundleLink(relation: "next", url: "http://example.com/fhir/Patient?name=Smith&page=2")
            ]
        )
        
        XCTAssertEqual(bundle.link?.count, 2)
        XCTAssertEqual(bundle.link?[0].relation, "self")
    }
    
    func testBundleWithEntries() {
        let patientEntry = BundleEntry(
            fullUrl: "http://example.com/fhir/Patient/123",
            resource: .patient(Patient(id: "123", name: [HumanName(family: "Doe")])),
            search: BundleEntrySearch(mode: "match", score: 1.0)
        )
        let bundle = Bundle(
            id: "bundle-003",
            type: "searchset",
            total: 1,
            entry: [patientEntry]
        )
        
        XCTAssertEqual(bundle.entry?.count, 1)
        XCTAssertEqual(bundle.entry?[0].fullUrl, "http://example.com/fhir/Patient/123")
        XCTAssertEqual(bundle.entry?[0].search?.mode, "match")
    }
    
    func testBundleTransactionEntry() {
        let entry = BundleEntry(
            fullUrl: "urn:uuid:12345",
            resource: .patient(Patient(id: "new-patient")),
            request: BundleEntryRequest(method: "POST", url: "Patient")
        )
        let bundle = Bundle(
            id: "bundle-tx",
            type: "transaction",
            entry: [entry]
        )
        
        XCTAssertEqual(bundle.type, "transaction")
        XCTAssertEqual(bundle.entry?[0].request?.method, "POST")
    }
    
    func testBundleResponseEntry() {
        let entry = BundleEntry(
            response: BundleEntryResponse(
                status: "201 Created",
                location: "Patient/123/_history/1",
                etag: "W/\"1\"",
                lastModified: "2024-01-15T10:00:00Z"
            )
        )
        let bundle = Bundle(
            id: "bundle-resp",
            type: "transaction-response",
            entry: [entry]
        )
        
        XCTAssertEqual(bundle.entry?[0].response?.status, "201 Created")
        XCTAssertEqual(bundle.entry?[0].response?.location, "Patient/123/_history/1")
    }
    
    func testBundleValidation() throws {
        let bundle = Bundle(id: "bundle-001", type: "searchset")
        XCTAssertNoThrow(try bundle.validate())
    }
    
    func testBundleValidationEmptyType() {
        let bundle = Bundle(id: "bundle-001", type: "")
        
        XCTAssertThrowsError(try bundle.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testBundleCodable() throws {
        let bundle = Bundle(
            id: "bundle-001",
            type: "searchset",
            total: 0,
            link: [BundleLink(relation: "self", url: "http://example.com/fhir/Patient")]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Bundle.self, from: data)
        
        XCTAssertEqual(decoded.type, "searchset")
        XCTAssertEqual(decoded.total, 0)
        XCTAssertEqual(decoded.link?.first?.relation, "self")
    }
    
    func testBundleIsNotDomainResource() {
        // Bundle conforms to Resource but NOT DomainResource
        let bundle = Bundle(id: "bundle-001", type: "searchset")
        XCTAssertTrue(bundle is any Resource)
        // Bundle should have no text, contained, extension, or modifierExtension at resource level
        XCTAssertEqual(bundle.resourceType, "Bundle")
    }
    
    // MARK: - OperationOutcome Tests
    
    func testOperationOutcomeCreation() {
        let outcome = OperationOutcome(
            id: "oo-001",
            issue: [
                OperationOutcomeIssue(
                    severity: "error",
                    code: "not-found",
                    diagnostics: "Patient/999 not found"
                )
            ]
        )
        
        XCTAssertEqual(outcome.resourceType, "OperationOutcome")
        XCTAssertEqual(outcome.id, "oo-001")
        XCTAssertEqual(outcome.issue.count, 1)
        XCTAssertEqual(outcome.issue[0].severity, "error")
        XCTAssertEqual(outcome.issue[0].code, "not-found")
    }
    
    func testOperationOutcomeMultipleIssues() {
        let outcome = OperationOutcome(
            issue: [
                OperationOutcomeIssue(severity: "error", code: "required", diagnostics: "Field 'status' is required"),
                OperationOutcomeIssue(severity: "warning", code: "business-rule", diagnostics: "Record may be duplicate"),
                OperationOutcomeIssue(severity: "information", code: "informational", diagnostics: "Processing complete")
            ]
        )
        
        XCTAssertEqual(outcome.issue.count, 3)
        XCTAssertEqual(outcome.issue[0].severity, "error")
        XCTAssertEqual(outcome.issue[1].severity, "warning")
        XCTAssertEqual(outcome.issue[2].severity, "information")
    }
    
    func testOperationOutcomeIssueWithDetails() {
        let issue = OperationOutcomeIssue(
            severity: "error",
            code: "invalid",
            details: CodeableConcept(text: "Invalid date format"),
            diagnostics: "The date '2024-13-45' is not valid",
            location: ["Patient.birthDate"],
            expression: ["Patient.birthDate"]
        )
        
        XCTAssertEqual(issue.details?.text, "Invalid date format")
        XCTAssertEqual(issue.location?.count, 1)
        XCTAssertEqual(issue.expression?.count, 1)
    }
    
    func testOperationOutcomeValidation() throws {
        let outcome = OperationOutcome(
            issue: [OperationOutcomeIssue(severity: "error", code: "not-found")]
        )
        XCTAssertNoThrow(try outcome.validate())
    }
    
    func testOperationOutcomeValidationEmptyIssues() {
        let outcome = OperationOutcome(issue: [])
        
        XCTAssertThrowsError(try outcome.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testOperationOutcomeValidationEmptySeverity() {
        let outcome = OperationOutcome(
            issue: [OperationOutcomeIssue(severity: "", code: "not-found")]
        )
        
        XCTAssertThrowsError(try outcome.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testOperationOutcomeValidationEmptyCode() {
        let outcome = OperationOutcome(
            issue: [OperationOutcomeIssue(severity: "error", code: "")]
        )
        
        XCTAssertThrowsError(try outcome.validate()) { error in
            guard case HL7Error.validationError = error else {
                XCTFail("Expected validation error")
                return
            }
        }
    }
    
    func testOperationOutcomeCodable() throws {
        let outcome = OperationOutcome(
            id: "oo-001",
            issue: [OperationOutcomeIssue(severity: "error", code: "not-found", diagnostics: "Not found")]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(outcome)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(OperationOutcome.self, from: data)
        
        XCTAssertEqual(decoded.issue.count, 1)
        XCTAssertEqual(decoded.issue[0].severity, "error")
        XCTAssertEqual(decoded.issue[0].diagnostics, "Not found")
    }
    
    // MARK: - Enhanced Patient Tests
    
    func testPatientWithNewFields() {
        let contact = PatientContact(
            relationship: [CodeableConcept(text: "Emergency Contact")],
            name: HumanName(family: "Doe", given: ["Jane"]),
            telecom: [ContactPoint(system: "phone", value: "+1-555-999-0000")],
            gender: "female"
        )
        let communication = PatientCommunication(
            language: CodeableConcept(
                coding: [Coding(system: "urn:ietf:bcp:47", code: "en", display: "English")]
            ),
            preferred: true
        )
        let patient = Patient(
            id: "patient-enhanced",
            active: true,
            name: [HumanName(family: "Doe", given: ["John"])],
            gender: "male",
            deceased: false,
            maritalStatus: CodeableConcept(text: "Married"),
            multipleBirth: false,
            contact: [contact],
            communication: [communication],
            generalPractitioner: [Reference(reference: "Practitioner/pract-001")],
            managingOrganization: Reference(reference: "Organization/org-001")
        )
        
        XCTAssertEqual(patient.active, true)
        XCTAssertEqual(patient.deceased, false)
        XCTAssertEqual(patient.maritalStatus?.text, "Married")
        XCTAssertEqual(patient.multipleBirth, false)
        XCTAssertEqual(patient.contact?.count, 1)
        XCTAssertEqual(patient.contact?[0].name?.family, "Doe")
        XCTAssertEqual(patient.communication?.count, 1)
        XCTAssertEqual(patient.communication?[0].preferred, true)
        XCTAssertEqual(patient.generalPractitioner?.count, 1)
        XCTAssertNotNil(patient.managingOrganization)
    }
    
    func testPatientContactCodable() throws {
        let contact = PatientContact(
            name: HumanName(family: "Smith"),
            gender: "female"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(contact)
        let decoded = try JSONDecoder().decode(PatientContact.self, from: data)
        
        XCTAssertEqual(decoded.name?.family, "Smith")
        XCTAssertEqual(decoded.gender, "female")
    }
    
    func testPatientCommunicationCodable() throws {
        let comm = PatientCommunication(
            language: CodeableConcept(coding: [Coding(code: "en")]),
            preferred: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(comm)
        let decoded = try JSONDecoder().decode(PatientCommunication.self, from: data)
        
        XCTAssertEqual(decoded.preferred, true)
    }
    
    // MARK: - Enhanced Observation Tests
    
    func testObservationWithNewFields() {
        let refRange = ObservationReferenceRange(
            low: Quantity(value: 36.1, unit: "°C"),
            high: Quantity(value: 37.2, unit: "°C"),
            text: "Normal body temperature"
        )
        let component = ObservationComponent(
            code: CodeableConcept(text: "Systolic"),
            valueQuantity: Quantity(value: 120, unit: "mmHg")
        )
        let observation = Observation(
            id: "obs-enhanced",
            basedOn: [Reference(reference: "ServiceRequest/sr-001")],
            status: "final",
            category: [CodeableConcept(text: "Vital Signs")],
            code: CodeableConcept(text: "Blood Pressure"),
            subject: Reference(reference: "Patient/patient-123"),
            effectiveDateTime: "2024-01-15T10:00:00Z",
            issued: "2024-01-15T10:05:00Z",
            performer: [Reference(reference: "Practitioner/pract-001")],
            valueQuantity: Quantity(value: 37.0, unit: "°C"),
            interpretation: [CodeableConcept(text: "Normal")],
            note: [Annotation(text: "Measured in clinic")],
            bodySite: CodeableConcept(text: "Oral"),
            method: CodeableConcept(text: "Digital thermometer"),
            referenceRange: [refRange],
            component: [component]
        )
        
        XCTAssertEqual(observation.basedOn?.count, 1)
        XCTAssertEqual(observation.category?.first?.text, "Vital Signs")
        XCTAssertEqual(observation.effectiveDateTime, "2024-01-15T10:00:00Z")
        XCTAssertEqual(observation.valueQuantity?.value, 37.0)
        XCTAssertEqual(observation.interpretation?.first?.text, "Normal")
        XCTAssertEqual(observation.bodySite?.text, "Oral")
        XCTAssertEqual(observation.method?.text, "Digital thermometer")
        XCTAssertEqual(observation.referenceRange?.count, 1)
        XCTAssertEqual(observation.component?.count, 1)
        XCTAssertEqual(observation.component?[0].valueQuantity?.value, 120)
    }
    
    func testObservationValueTypes() {
        let obsStr = Observation(
            id: "obs-str", status: "final",
            code: CodeableConcept(text: "Note"),
            valueString: "Patient reports feeling well"
        )
        let obsBool = Observation(
            id: "obs-bool", status: "final",
            code: CodeableConcept(text: "Pregnant"),
            valueBoolean: false
        )
        let obsCC = Observation(
            id: "obs-cc", status: "final",
            code: CodeableConcept(text: "Blood Type"),
            valueCodeableConcept: CodeableConcept(text: "A+")
        )
        
        XCTAssertEqual(obsStr.valueString, "Patient reports feeling well")
        XCTAssertEqual(obsBool.valueBoolean, false)
        XCTAssertEqual(obsCC.valueCodeableConcept?.text, "A+")
    }
    
    func testObservationReferenceRangeCodable() throws {
        let refRange = ObservationReferenceRange(
            low: Quantity(value: 3.5, unit: "g/dL"),
            high: Quantity(value: 5.5, unit: "g/dL"),
            type: CodeableConcept(text: "Normal"),
            text: "3.5-5.5 g/dL"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(refRange)
        let decoded = try JSONDecoder().decode(ObservationReferenceRange.self, from: data)
        
        XCTAssertEqual(decoded.low?.value, 3.5)
        XCTAssertEqual(decoded.high?.value, 5.5)
        XCTAssertEqual(decoded.text, "3.5-5.5 g/dL")
    }
    
    func testObservationComponentCodable() throws {
        let component = ObservationComponent(
            code: CodeableConcept(text: "Diastolic"),
            valueQuantity: Quantity(value: 80, unit: "mmHg"),
            interpretation: [CodeableConcept(text: "Normal")]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(component)
        let decoded = try JSONDecoder().decode(ObservationComponent.self, from: data)
        
        XCTAssertEqual(decoded.code.text, "Diastolic")
        XCTAssertEqual(decoded.valueQuantity?.value, 80)
    }
    
    // MARK: - ResourceContainer Tests
    
    func testResourceContainerPractitioner() throws {
        let container = ResourceContainer.practitioner(Practitioner(id: "pract-001"))
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .practitioner(let pract) = decoded {
            XCTAssertEqual(pract.id, "pract-001")
        } else {
            XCTFail("Expected practitioner container")
        }
    }
    
    func testResourceContainerOrganization() throws {
        let container = ResourceContainer.organization(Organization(id: "org-001", name: "Test Org"))
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .organization(let org) = decoded {
            XCTAssertEqual(org.id, "org-001")
            XCTAssertEqual(org.name, "Test Org")
        } else {
            XCTFail("Expected organization container")
        }
    }
    
    func testResourceContainerCondition() throws {
        let container = ResourceContainer.condition(
            Condition(id: "cond-001", subject: Reference(reference: "Patient/123"))
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .condition(let cond) = decoded {
            XCTAssertEqual(cond.id, "cond-001")
        } else {
            XCTFail("Expected condition container")
        }
    }
    
    func testResourceContainerAllergyIntolerance() throws {
        let container = ResourceContainer.allergyIntolerance(
            AllergyIntolerance(id: "ai-001", patient: Reference(reference: "Patient/123"))
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .allergyIntolerance(let ai) = decoded {
            XCTAssertEqual(ai.id, "ai-001")
        } else {
            XCTFail("Expected allergyIntolerance container")
        }
    }
    
    func testResourceContainerEncounter() throws {
        let container = ResourceContainer.encounter(
            Encounter(id: "enc-001", status: "in-progress", class_: Coding(code: "IMP"))
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .encounter(let enc) = decoded {
            XCTAssertEqual(enc.id, "enc-001")
            XCTAssertEqual(enc.status, "in-progress")
        } else {
            XCTFail("Expected encounter container")
        }
    }
    
    func testResourceContainerMedicationRequest() throws {
        let container = ResourceContainer.medicationRequest(
            MedicationRequest(id: "med-001", status: "active", intent: "order", subject: Reference(reference: "Patient/123"))
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .medicationRequest(let mr) = decoded {
            XCTAssertEqual(mr.id, "med-001")
        } else {
            XCTFail("Expected medicationRequest container")
        }
    }
    
    func testResourceContainerDiagnosticReport() throws {
        let container = ResourceContainer.diagnosticReport(
            DiagnosticReport(id: "dr-001", status: "final", code: CodeableConcept(text: "CBC"))
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .diagnosticReport(let dr) = decoded {
            XCTAssertEqual(dr.id, "dr-001")
        } else {
            XCTFail("Expected diagnosticReport container")
        }
    }
    
    func testResourceContainerBundle() throws {
        let container = ResourceContainer.bundle(
            Bundle(id: "bundle-001", type: "collection")
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .bundle(let b) = decoded {
            XCTAssertEqual(b.id, "bundle-001")
            XCTAssertEqual(b.type, "collection")
        } else {
            XCTFail("Expected bundle container")
        }
    }
    
    func testResourceContainerOperationOutcome() throws {
        let container = ResourceContainer.operationOutcome(
            OperationOutcome(id: "oo-001", issue: [OperationOutcomeIssue(severity: "error", code: "invalid")])
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResourceContainer.self, from: data)
        
        if case .operationOutcome(let oo) = decoded {
            XCTAssertEqual(oo.id, "oo-001")
            XCTAssertEqual(oo.issue[0].severity, "error")
        } else {
            XCTFail("Expected operationOutcome container")
        }
    }
    
    func testResourceContainerUnknownType() {
        let json = """
        {
            "resourceType": "UnknownResource",
            "id": "unknown-001"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        XCTAssertThrowsError(try decoder.decode(ResourceContainer.self, from: json))
    }
    
    // MARK: - Sendable Conformance Tests
    
    func testPractitionerSendable() async {
        let practitioner = Practitioner(id: "pract-001", name: [HumanName(family: "Smith")])
        await Task {
            XCTAssertEqual(practitioner.resourceType, "Practitioner")
        }.value
    }
    
    func testEncounterSendable() async {
        let encounter = Encounter(id: "enc-001", status: "in-progress", class_: Coding(code: "IMP"))
        await Task {
            XCTAssertEqual(encounter.resourceType, "Encounter")
        }.value
    }
    
    func testBundleSendable() async {
        let bundle = Bundle(id: "bundle-001", type: "searchset")
        await Task {
            XCTAssertEqual(bundle.resourceType, "Bundle")
        }.value
    }
    
    // MARK: - Performance Tests
    
    func testPractitionerCreationPerformance() {
        measure {
            for i in 0..<100 {
                _ = Practitioner(
                    id: "pract-\(i)",
                    name: [HumanName(family: "Smith", given: ["Alice"])]
                )
            }
        }
    }
    
    func testBundleCreationPerformance() {
        measure {
            for i in 0..<100 {
                _ = Bundle(id: "bundle-\(i)", type: "searchset", total: Int32(i))
            }
        }
    }
    
    func testEncounterEncodingPerformance() throws {
        let encounter = Encounter(
            id: "enc-001",
            status: "in-progress",
            class_: Coding(code: "IMP"),
            participant: [EncounterParticipant(individual: Reference(reference: "Practitioner/pract-001"))]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        measure {
            for _ in 0..<100 {
                _ = try? encoder.encode(encounter)
            }
        }
    }
    
    func testOperationOutcomeValidationPerformance() {
        let outcome = OperationOutcome(
            issue: [
                OperationOutcomeIssue(severity: "error", code: "not-found"),
                OperationOutcomeIssue(severity: "warning", code: "business-rule"),
                OperationOutcomeIssue(severity: "information", code: "informational")
            ]
        )
        
        measure {
            for _ in 0..<1000 {
                try? outcome.validate()
            }
        }
    }
}
