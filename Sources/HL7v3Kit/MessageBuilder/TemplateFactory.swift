/// TemplateFactory.swift
/// Template-based document generation for common CDA document types
///
/// This file provides factory methods for quickly creating common CDA document types
/// using predefined templates (Progress Note, Consultation Note, Discharge Summary, etc.).

import Foundation
import HL7Core

// MARK: - Template Factory

/// Factory for creating CDA documents from common templates
public struct CDATemplateFactory {
    
    /// Creates a Progress Note document
    /// - Parameters:
    ///   - patientId: Patient identifier
    ///   - patientName: Patient name (given, family)
    ///   - authorName: Author name (given, family)
    ///   - organizationName: Healthcare organization name
    ///   - note: The progress note content
    /// - Returns: A configured CDADocumentBuilder
    public static func progressNote(
        patientId: (root: String, extension: String),
        patientName: (given: String, family: String),
        authorName: (given: String, family: String),
        organizationName: String,
        note: String
    ) -> CDADocumentBuilder {
        return CDADocumentBuilder()
            // US Realm Header template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1", extension: "2015-08-01")
            // Progress Note template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.9", extension: "2015-08-01")
            .withRealmCode("US")
            .withId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
            .withDocumentCode(
                code: "11506-3",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "Progress note"
            )
            .withTitle("Progress Note")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withLanguage("en-US")
            .withRecordTarget { target in
                target.withPatientId(root: patientId.root, extension: patientId.extension)
                    .withPatientName(given: patientName.given, family: patientName.family)
            }
            .withAuthor { author in
                author.withTime(Date())
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
                    .withAuthorName(given: authorName.given, family: authorName.family)
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName(organizationName)
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withCode(code: "10164-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of Present Illness")
                        .withTitle("History of Present Illness")
                        .withText(note)
                }
            }
    }
    
    /// Creates a Consultation Note document
    /// - Parameters:
    ///   - patientId: Patient identifier
    ///   - patientName: Patient name (given, family)
    ///   - authorName: Author name (given, family)
    ///   - organizationName: Healthcare organization name
    ///   - consultationReason: Reason for consultation
    ///   - consultationNote: The consultation content
    /// - Returns: A configured CDADocumentBuilder
    public static func consultationNote(
        patientId: (root: String, extension: String),
        patientName: (given: String, family: String),
        authorName: (given: String, family: String),
        organizationName: String,
        consultationReason: String,
        consultationNote: String
    ) -> CDADocumentBuilder {
        return CDADocumentBuilder()
            // US Realm Header template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1", extension: "2015-08-01")
            // Consultation Note template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.4", extension: "2015-08-01")
            .withRealmCode("US")
            .withId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
            .withDocumentCode(
                code: "11488-4",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "Consultation note"
            )
            .withTitle("Consultation Note")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withLanguage("en-US")
            .withRecordTarget { target in
                target.withPatientId(root: patientId.root, extension: patientId.extension)
                    .withPatientName(given: patientName.given, family: patientName.family)
            }
            .withAuthor { author in
                author.withTime(Date())
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
                    .withAuthorName(given: authorName.given, family: authorName.family)
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName(organizationName)
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withCode(code: "42349-1", codeSystem: "2.16.840.1.113883.6.1", displayName: "Reason for Referral")
                        .withTitle("Reason for Referral")
                        .withText(consultationReason)
                }
                .addSection { section in
                    section.withCode(code: "10164-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of Present Illness")
                        .withTitle("History of Present Illness")
                        .withText(consultationNote)
                }
            }
    }
    
    /// Creates a Discharge Summary document
    /// - Parameters:
    ///   - patientId: Patient identifier
    ///   - patientName: Patient name (given, family)
    ///   - authorName: Author name (given, family)
    ///   - organizationName: Healthcare organization name
    ///   - admissionDate: Date of admission
    ///   - dischargeDate: Date of discharge
    ///   - hospitalCourse: Description of hospital stay
    ///   - dischargeDiagnosis: Discharge diagnosis
    ///   - dischargeInstructions: Instructions for patient
    /// - Returns: A configured CDADocumentBuilder
    public static func dischargeSummary(
        patientId: (root: String, extension: String),
        patientName: (given: String, family: String),
        authorName: (given: String, family: String),
        organizationName: String,
        admissionDate: Date,
        dischargeDate: Date,
        hospitalCourse: String,
        dischargeDiagnosis: String,
        dischargeInstructions: String
    ) -> CDADocumentBuilder {
        return CDADocumentBuilder()
            // US Realm Header template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1", extension: "2015-08-01")
            // Discharge Summary template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.8", extension: "2015-08-01")
            .withRealmCode("US")
            .withId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
            .withDocumentCode(
                code: "18842-5",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "Discharge summary"
            )
            .withTitle("Discharge Summary")
            .withEffectiveTime(dischargeDate)
            .withConfidentiality("N")
            .withLanguage("en-US")
            .withRecordTarget { target in
                target.withPatientId(root: patientId.root, extension: patientId.extension)
                    .withPatientName(given: patientName.given, family: patientName.family)
            }
            .withAuthor { author in
                author.withTime(dischargeDate)
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
                    .withAuthorName(given: authorName.given, family: authorName.family)
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName(organizationName)
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withCode(code: "10154-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Hospital Course")
                        .withTitle("Hospital Course")
                        .withText(hospitalCourse)
                }
                .addSection { section in
                    section.withCode(code: "11535-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "Hospital Discharge Diagnosis")
                        .withTitle("Discharge Diagnosis")
                        .withText(dischargeDiagnosis)
                }
                .addSection { section in
                    section.withCode(code: "8653-8", codeSystem: "2.16.840.1.113883.6.1", displayName: "Hospital Discharge Instructions")
                        .withTitle("Discharge Instructions")
                        .withText(dischargeInstructions)
                }
            }
    }
    
    /// Creates a History and Physical document
    /// - Parameters:
    ///   - patientId: Patient identifier
    ///   - patientName: Patient name (given, family)
    ///   - authorName: Author name (given, family)
    ///   - organizationName: Healthcare organization name
    ///   - chiefComplaint: Chief complaint
    ///   - historyOfPresentIllness: HPI content
    ///   - physicalExam: Physical examination findings
    /// - Returns: A configured CDADocumentBuilder
    public static func historyAndPhysical(
        patientId: (root: String, extension: String),
        patientName: (given: String, family: String),
        authorName: (given: String, family: String),
        organizationName: String,
        chiefComplaint: String,
        historyOfPresentIllness: String,
        physicalExam: String
    ) -> CDADocumentBuilder {
        return CDADocumentBuilder()
            // US Realm Header template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1", extension: "2015-08-01")
            // History and Physical template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.3", extension: "2015-08-01")
            .withRealmCode("US")
            .withId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
            .withDocumentCode(
                code: "34117-2",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "History and Physical note"
            )
            .withTitle("History and Physical")
            .withEffectiveTime(Date())
            .withConfidentiality("N")
            .withLanguage("en-US")
            .withRecordTarget { target in
                target.withPatientId(root: patientId.root, extension: patientId.extension)
                    .withPatientName(given: patientName.given, family: patientName.family)
            }
            .withAuthor { author in
                author.withTime(Date())
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
                    .withAuthorName(given: authorName.given, family: authorName.family)
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName(organizationName)
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withCode(code: "10154-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Chief Complaint")
                        .withTitle("Chief Complaint")
                        .withText(chiefComplaint)
                }
                .addSection { section in
                    section.withCode(code: "10164-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of Present Illness")
                        .withTitle("History of Present Illness")
                        .withText(historyOfPresentIllness)
                }
                .addSection { section in
                    section.withCode(code: "29545-1", codeSystem: "2.16.840.1.113883.6.1", displayName: "Physical Examination")
                        .withTitle("Physical Examination")
                        .withText(physicalExam)
                }
            }
    }
    
    /// Creates an Operative Note document
    /// - Parameters:
    ///   - patientId: Patient identifier
    ///   - patientName: Patient name (given, family)
    ///   - authorName: Surgeon name (given, family)
    ///   - organizationName: Healthcare organization name
    ///   - procedureName: Name of the procedure
    ///   - procedureDate: Date of procedure
    ///   - preoperativeDiagnosis: Diagnosis before surgery
    ///   - postoperativeDiagnosis: Diagnosis after surgery
    ///   - procedureDescription: Detailed description
    ///   - findings: Operative findings
    /// - Returns: A configured CDADocumentBuilder
    public static func operativeNote(
        patientId: (root: String, extension: String),
        patientName: (given: String, family: String),
        authorName: (given: String, family: String),
        organizationName: String,
        procedureName: String,
        procedureDate: Date,
        preoperativeDiagnosis: String,
        postoperativeDiagnosis: String,
        procedureDescription: String,
        findings: String
    ) -> CDADocumentBuilder {
        return CDADocumentBuilder()
            // US Realm Header template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.1", extension: "2015-08-01")
            // Operative Note template
            .withTemplateId(root: "2.16.840.1.113883.10.20.22.1.7", extension: "2014-06-09")
            .withRealmCode("US")
            .withId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
            .withDocumentCode(
                code: "11504-8",
                codeSystem: "2.16.840.1.113883.6.1",
                codeSystemName: "LOINC",
                displayName: "Surgical operation note"
            )
            .withTitle("Operative Note: \(procedureName)")
            .withEffectiveTime(procedureDate)
            .withConfidentiality("N")
            .withLanguage("en-US")
            .withRecordTarget { target in
                target.withPatientId(root: patientId.root, extension: patientId.extension)
                    .withPatientName(given: patientName.given, family: patientName.family)
            }
            .withAuthor { author in
                author.withTime(procedureDate)
                    .withAuthorId(root: "2.16.840.1.113883.19.5", extension: UUID().uuidString)
                    .withAuthorName(given: authorName.given, family: authorName.family)
            }
            .withCustodian { custodian in
                custodian.withOrganizationId(root: "2.16.840.1.113883.19.5")
                    .withOrganizationName(organizationName)
            }
            .withStructuredBody { body in
                body.addSection { section in
                    section.withCode(code: "10219-4", codeSystem: "2.16.840.1.113883.6.1", displayName: "Preoperative Diagnosis")
                        .withTitle("Preoperative Diagnosis")
                        .withText(preoperativeDiagnosis)
                }
                .addSection { section in
                    section.withCode(code: "10218-6", codeSystem: "2.16.840.1.113883.6.1", displayName: "Postoperative Diagnosis")
                        .withTitle("Postoperative Diagnosis")
                        .withText(postoperativeDiagnosis)
                }
                .addSection { section in
                    section.withCode(code: "29554-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Procedure Description")
                        .withTitle("Procedure Description")
                        .withText(procedureDescription)
                }
                .addSection { section in
                    section.withCode(code: "59776-5", codeSystem: "2.16.840.1.113883.6.1", displayName: "Findings")
                        .withTitle("Findings")
                        .withText(findings)
                }
            }
    }
}
