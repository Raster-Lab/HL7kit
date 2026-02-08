/// CDADocumentBuilderTests.swift
/// Unit tests for CDA Document Builder
///
/// Comprehensive tests for the fluent API builders including CDADocumentBuilder,
/// ParticipantBuilders, BodyBuilders, and TemplateFactory.

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class CDADocumentBuilderTests: XCTestCase {
    
    // MARK: - Basic Document Building
    
    func testMinimalDocument() throws {
        let document = try CDADocumentBuilder()
            .withId(root: "2.16.840.1.113883.19.5", extension: "12345")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Progress note")
            .withTitle("Progress Note")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withRecordTarget { target in
                target.withPatientId(root: "2.16.840.1.113883.19.5", extension: "PT123")
                    .withPatientName(given: "John", family: "Doe")
            }
            .withAuthor { author in
                author.withTime(Date())
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: "DOC456")
                    .withAuthorName(given: "Jane", family: "Smith")
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName("Good Health Clinic")
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withTitle("Chief Complaint")
                        .withCode(code: "10154-3", codeSystem: "2.16.840.1.113883.6.1")
                        .withText("Patient reports headache.")
                }
            }
            .build()
        
        XCTAssertEqual(document.title?.stringValue, "Progress Note")
        XCTAssertEqual(document.code.code, "11506-3")
        XCTAssertEqual(document.recordTarget.count, 1)
        XCTAssertEqual(document.author.count, 1)
        XCTAssertNotNil(document.custodian)
    }
    
    func testMissingRequiredFields() {
        // Missing document ID
        XCTAssertThrowsError(try CDADocumentBuilder()
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Progress Note")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .build()
        ) { error in
            if case let BuilderError.missingRequiredField(field) = error {
                XCTAssertTrue(field.contains("id"))
            } else {
                XCTFail("Expected missingRequiredField error")
            }
        }
    }
    
    // MARK: - Participant Builders
    
    func testRecordTargetBuilder() {
        let recordTarget = RecordTargetBuilder()
            .withPatientId(root: "2.16.840.1.113883.19.5", extension: "PT123")
            .withPatientName(given: "John", family: "Doe", prefix: "Mr.")
            .withGender(code: "M")
            .withBirthDate(Date())
            .withAddress(street: "123 Main St", city: "Springfield", state: "IL", postalCode: "62701")
            .withTelecom(value: "tel:+1-555-1234", use: .home)
            .build()
        
        XCTAssertNotNil(recordTarget)
        XCTAssertEqual(recordTarget?.patientRole.id.count, 1)
        XCTAssertEqual(recordTarget?.patientRole.patient?.name?.count, 1)
    }
    
    func testAuthorBuilder() {
        let author = AuthorBuilder()
            .withTime(Date())
            .withAuthorId(root: "2.16.840.1.113883.19.5", extension: "DOC456")
            .withAuthorName(given: "Jane", family: "Smith", prefix: "Dr.")
            .withTelecom(value: "tel:+1-555-9999", use: .work)
            .withAddress(street: "456 Medical Plaza", city: "Springfield", state: "IL", postalCode: "62701")
            .build()
        
        XCTAssertNotNil(author)
        XCTAssertEqual(author?.assignedAuthor.id.count, 1)
    }
    
    func testCustodianBuilder() {
        let custodian = CustodianBuilder()
            .withOrganizationId(root: "2.16.840.1.113883.19.5")
            .withOrganizationName("Good Health Clinic")
            .withTelecom(value: "tel:+1-555-5555", use: .work)
            .withAddress(street: "789 Hospital Rd", city: "Springfield", state: "IL", postalCode: "62701")
            .build()
        
        XCTAssertNotNil(custodian)
    }
    
    func testLegalAuthenticatorBuilder() {
        let authenticator = LegalAuthenticatorBuilder()
            .withTime(Date())
            .withSignature()
            .withAuthenticatorId(root: "2.16.840.1.113883.19.5", extension: "AUTH789")
            .withAuthenticatorName(given: "Robert", family: "Johnson", prefix: "Dr.")
            .build()
        
        XCTAssertNotNil(authenticator)
    }
    
    // MARK: - Section and Entry Builders
    
    func testSectionBuilder() {
        let section = SectionBuilder()
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.2.1")
            .withCode(code: "10160-0", codeSystem: "2.16.840.1.113883.6.1", displayName: "Medications")
            .withTitle("Medications")
            .withText("Patient is taking aspirin 81mg daily.")
            .build()
        
        XCTAssertNotNil(section)
        XCTAssertEqual(section?.title?.stringValue, "Medications")
        XCTAssertEqual(section?.code?.code, "10160-0")
    }
    
    func testSectionWithObservation() {
        let section = SectionBuilder()
            .withTitle("Vital Signs")
            .withCode(code: "8716-3", codeSystem: "2.16.840.1.113883.6.1")
            .addObservation { obs in
                obs.withCode(code: "8310-5", codeSystem: "2.16.840.1.113883.6.1", displayName: "Body temperature")
                    .withEffectiveTime(Date())
                    .withQuantityValue(value: 98.6, unit: "[degF]")
            }
            .build()
        
        XCTAssertNotNil(section)
        XCTAssertEqual(section?.entry?.count, 1)
    }
    
    func testSectionWithProcedure() {
        let section = SectionBuilder()
            .withTitle("Procedures")
            .withCode(code: "47519-4", codeSystem: "2.16.840.1.113883.6.1")
            .addProcedure { proc in
                proc.withCode(code: "80146", codeSystem: "2.16.840.1.113883.6.12", displayName: "Appendectomy")
                    .withEffectiveTime(Date())
            }
            .build()
        
        XCTAssertNotNil(section)
        XCTAssertEqual(section?.entry?.count, 1)
    }
    
    func testSectionWithSubstanceAdministration() {
        let section = SectionBuilder()
            .withTitle("Medications")
            .withCode(code: "10160-0", codeSystem: "2.16.840.1.113883.6.1")
            .addSubstanceAdministration { med in
                med.withMedication(code: "197361", codeSystem: "2.16.840.1.113883.6.88", displayName: "Aspirin 81 MG")
                    .withEffectiveTime(Date())
                    .withDose(value: 81, unit: "mg")
            }
            .build()
        
        XCTAssertNotNil(section)
        XCTAssertEqual(section?.entry?.count, 1)
    }
    
    func testNestedSections() {
        let section = SectionBuilder()
            .withTitle("History")
            .withCode(code: "11348-0", codeSystem: "2.16.840.1.113883.6.1")
            .addSubsection { subsection in
                subsection.withTitle("Past Medical History")
                    .withText("No significant past medical history.")
            }
            .addSubsection { subsection in
                subsection.withTitle("Past Surgical History")
                    .withText("Appendectomy in 2010.")
            }
            .build()
        
        XCTAssertNotNil(section)
        XCTAssertEqual(section?.component?.count, 2)
    }
    
    // MARK: - Template Factory Tests
    
    func testProgressNoteTemplate() {
        let builder = CDATemplateFactory.progressNote(
            patientId: ("2.16.840.1.113883.19.5", "PT123"),
            patientName: ("John", "Doe"),
            authorName: ("Jane", "Smith"),
            organizationName: "Good Health Clinic",
            note: "Patient presents with headache for 3 days."
        )
        
        let document = try? builder.build()
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.code.code, "11506-3")
        XCTAssertEqual(document?.title?.stringValue, "Progress Note")
    }
    
    func testConsultationNoteTemplate() {
        let builder = CDATemplateFactory.consultationNote(
            patientId: ("2.16.840.1.113883.19.5", "PT123"),
            patientName: ("John", "Doe"),
            authorName: ("Jane", "Smith"),
            organizationName: "Good Health Clinic",
            consultationReason: "Evaluation for chronic headaches",
            consultationNote: "Patient has had persistent headaches for 6 months."
        )
        
        let document = try? builder.build()
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.code.code, "11488-4")
        XCTAssertEqual(document?.title?.stringValue, "Consultation Note")
    }
    
    func testDischargeSummaryTemplate() {
        let admissionDate = Date().addingTimeInterval(-86400 * 5) // 5 days ago
        let dischargeDate = Date()
        
        let builder = CDATemplateFactory.dischargeSummary(
            patientId: ("2.16.840.1.113883.19.5", "PT123"),
            patientName: ("John", "Doe"),
            authorName: ("Jane", "Smith"),
            organizationName: "Good Health Hospital",
            admissionDate: admissionDate,
            dischargeDate: dischargeDate,
            hospitalCourse: "Patient admitted with acute appendicitis.",
            dischargeDiagnosis: "Acute appendicitis",
            dischargeInstructions: "Follow up in 2 weeks."
        )
        
        let document = try? builder.build()
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.code.code, "18842-5")
        XCTAssertEqual(document?.title?.stringValue, "Discharge Summary")
    }
    
    func testHistoryAndPhysicalTemplate() {
        let builder = CDATemplateFactory.historyAndPhysical(
            patientId: ("2.16.840.1.113883.19.5", "PT123"),
            patientName: ("John", "Doe"),
            authorName: ("Jane", "Smith"),
            organizationName: "Good Health Clinic",
            chiefComplaint: "Chest pain",
            historyOfPresentIllness: "Patient presents with chest pain for 2 hours.",
            physicalExam: "BP 120/80, HR 72, RR 16, Temp 98.6F"
        )
        
        let document = try? builder.build()
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.code.code, "34117-2")
        XCTAssertEqual(document?.title?.stringValue, "History and Physical")
    }
    
    func testOperativeNoteTemplate() {
        let procedureDate = Date()
        
        let builder = CDATemplateFactory.operativeNote(
            patientId: ("2.16.840.1.113883.19.5", "PT123"),
            patientName: ("John", "Doe"),
            authorName: ("Robert", "Johnson"),
            organizationName: "Good Health Hospital",
            procedureName: "Laparoscopic Appendectomy",
            procedureDate: procedureDate,
            preoperativeDiagnosis: "Acute appendicitis",
            postoperativeDiagnosis: "Acute appendicitis with perforation",
            procedureDescription: "Laparoscopic appendectomy performed successfully.",
            findings: "Perforated appendix with localized abscess."
        )
        
        let document = try? builder.build()
        XCTAssertNotNil(document)
        XCTAssertEqual(document?.code.code, "11504-8")
        XCTAssertTrue(document?.title?.stringValue?.contains("Operative Note") ?? false)
    }
    
    // MARK: - Vocabulary Binding Tests
    
    func testVocabularyHelperDocumentTypes() {
        let progressNote = VocabularyHelper.DocumentType.progressNote.code
        XCTAssertEqual(progressNote.code, "11506-3")
        XCTAssertEqual(progressNote.codeSystem, CodeSystem.loinc)
        
        let dischargeSummary = VocabularyHelper.DocumentType.dischargeSummary.code
        XCTAssertEqual(dischargeSummary.code, "18842-5")
    }
    
    func testVocabularyHelperSectionTypes() {
        let chiefComplaint = VocabularyHelper.SectionType.chiefComplaint.code
        XCTAssertEqual(chiefComplaint.code, "10154-3")
        
        let medications = VocabularyHelper.SectionType.medications.code
        XCTAssertEqual(medications.code, "10160-0")
    }
    
    func testVocabularyHelperGenderCodes() {
        let male = VocabularyHelper.gender(.male)
        XCTAssertEqual(male.code, "M")
        XCTAssertEqual(male.codeSystem, CodeSystem.administrativeGender)
        
        let female = VocabularyHelper.gender(.female)
        XCTAssertEqual(female.code, "F")
    }
    
    func testVocabularyHelperConfidentialityCodes() {
        let normal = VocabularyHelper.confidentiality(.normal)
        XCTAssertEqual(normal.code, "N")
        
        let restricted = VocabularyHelper.confidentiality(.restricted)
        XCTAssertEqual(restricted.code, "R")
    }
    
    func testVocabularyValidator() {
        XCTAssertTrue(VocabularyValidator.isValidCodeSystem(CodeSystem.loinc))
        XCTAssertTrue(VocabularyValidator.isValidCodeSystem(CodeSystem.snomedCT))
        XCTAssertTrue(VocabularyValidator.isValidCodeSystem(CodeSystem.rxNorm))
        XCTAssertFalse(VocabularyValidator.isValidCodeSystem("invalid.oid"))
    }
    
    func testCodedValueValidation() {
        let validCode = CD(code: "11506-3", codeSystem: CodeSystem.loinc)
        XCTAssertTrue(VocabularyValidator.isValidCode(validCode))
        
        let invalidCode = CD(code: "", codeSystem: CodeSystem.loinc)
        XCTAssertFalse(VocabularyValidator.isValidCode(invalidCode))
    }
    
    func testCDExtensionMethods() {
        let loincCode = CD.loinc(code: "11506-3", displayName: "Progress note")
        XCTAssertEqual(loincCode.code, "11506-3")
        XCTAssertEqual(loincCode.codeSystem, CodeSystem.loinc)
        
        let snomedCode = CD.snomedCT(code: "386661006", displayName: "Fever")
        XCTAssertEqual(snomedCode.code, "386661006")
        XCTAssertEqual(snomedCode.codeSystem, CodeSystem.snomedCT)
    }
    
    // MARK: - Complex Document Building
    
    func testComplexDocumentWithMultipleSections() throws {
        let document = try CDADocumentBuilder()
            .withId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1")
            .withDocumentCode(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1")
            .withTitle("Comprehensive Progress Note")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withLanguage("en-US")
            .withRealmCode("US")
            .withRecordTarget { target in
                target.withPatientId(root: "2.16.840.1.113883.19.5", extension: "PT123")
                    .withPatientName(given: "John", family: "Doe", prefix: "Mr.")
                    .withGender(code: "M")
                    .withAddress(street: "123 Main St", city: "Springfield", state: "IL", postalCode: "62701")
            }
            .withAuthor { author in
                author.withTime(Date())
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: "DOC456")
                    .withAuthorName(given: "Jane", family: "Smith", prefix: "Dr.")
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName("Good Health Clinic")
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withTitle("Chief Complaint")
                        .withCode(code: "10154-3", codeSystem: "2.16.840.1.113883.6.1")
                        .withText("Patient reports headache.")
                }
                .addSection { section in
                    section.withTitle("Vital Signs")
                        .withCode(code: "8716-3", codeSystem: "2.16.840.1.113883.6.1")
                        .addObservation { obs in
                            obs.withCode(code: "8310-5", codeSystem: "2.16.840.1.113883.6.1")
                                .withEffectiveTime(Date())
                                .withQuantityValue(value: 98.6, unit: "[degF]")
                        }
                }
                .addSection { section in
                    section.withTitle("Medications")
                        .withCode(code: "10160-0", codeSystem: "2.16.840.1.113883.6.1")
                        .addSubstanceAdministration { med in
                            med.withMedication(code: "197361", codeSystem: "2.16.840.1.113883.6.88")
                                .withDose(value: 81, unit: "mg")
                        }
                }
            }
            .build()
        
        XCTAssertEqual(document.recordTarget.count, 1)
        XCTAssertEqual(document.author.count, 1)
        XCTAssertNotNil(document.custodian)
        
        if case .structured(let body) = document.component.body {
            XCTAssertEqual(body.component.count, 3)
        } else {
            XCTFail("Expected structured body")
        }
    }
}
