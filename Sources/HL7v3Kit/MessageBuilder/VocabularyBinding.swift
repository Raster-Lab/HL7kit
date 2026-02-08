/// VocabularyBinding.swift
/// Vocabulary binding support for common code systems
///
/// This file provides utilities and constants for working with standard medical vocabularies
/// used in CDA documents (LOINC, SNOMED CT, RxNorm, ICD, etc.).

import Foundation
import HL7Core

// MARK: - Code System Constants

/// Standard code system OIDs and identifiers
public struct CodeSystem {
    // MARK: - Common Code Systems
    
    /// LOINC (Logical Observation Identifiers Names and Codes)
    public static let loinc = "2.16.840.1.113883.6.1"
    
    /// SNOMED CT (Systematized Nomenclature of Medicine Clinical Terms)
    public static let snomedCT = "2.16.840.1.113883.6.96"
    
    /// RxNorm (Medication terminology)
    public static let rxNorm = "2.16.840.1.113883.6.88"
    
    /// ICD-10-CM (International Classification of Diseases, 10th Revision, Clinical Modification)
    public static let icd10CM = "2.16.840.1.113883.6.90"
    
    /// ICD-9-CM (International Classification of Diseases, 9th Revision, Clinical Modification)
    public static let icd9CM = "2.16.840.1.113883.6.103"
    
    /// CPT (Current Procedural Terminology)
    public static let cpt = "2.16.840.1.113883.6.12"
    
    /// CVX (Vaccine Administered)
    public static let cvx = "2.16.840.1.113883.12.292"
    
    /// NDC (National Drug Code)
    public static let ndc = "2.16.840.1.113883.6.69"
    
    /// UCUM (Unified Code for Units of Measure)
    public static let ucum = "2.16.840.1.113883.6.8"
    
    // MARK: - HL7 Code Systems
    
    /// HL7 Administrative Gender
    public static let administrativeGender = "2.16.840.1.113883.5.1"
    
    /// HL7 Marital Status
    public static let maritalStatus = "2.16.840.1.113883.5.2"
    
    /// HL7 Race Category
    public static let raceCategory = "2.16.840.1.113883.6.238"
    
    /// HL7 Ethnicity Group
    public static let ethnicityGroup = "2.16.840.1.113883.6.238"
    
    /// HL7 Language
    public static let language = "2.16.840.1.113883.6.121"
    
    /// HL7 Religious Affiliation
    public static let religiousAffiliation = "2.16.840.1.113883.5.1076"
    
    /// HL7 Confidentiality Code
    public static let confidentiality = "2.16.840.1.113883.5.25"
    
    /// HL7 Act Status
    public static let actStatus = "2.16.840.1.113883.5.14"
    
    /// HL7 Telecommunication Use
    public static let telecomUse = "2.16.840.1.113883.5.1119"
    
    /// HL7 Postal Address Use
    public static let addressUse = "2.16.840.1.113883.5.1119"
}

// MARK: - Vocabulary Helpers

/// Helper methods for creating coded values from common vocabularies
public struct VocabularyHelper {
    
    // MARK: - Document Type Codes (LOINC)
    
    /// Creates a document type code for common document types
    public enum DocumentType {
        case progressNote
        case consultationNote
        case dischargeSummary
        case historyAndPhysical
        case operativeNote
        case procedureNote
        case transferSummary
        case continuityOfCareDocument
        
        public var code: CD {
            switch self {
            case .progressNote:
                return CD(
                    code: "11506-3",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Progress note"
                )
            case .consultationNote:
                return CD(
                    code: "11488-4",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Consultation note"
                )
            case .dischargeSummary:
                return CD(
                    code: "18842-5",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Discharge summary"
                )
            case .historyAndPhysical:
                return CD(
                    code: "34117-2",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "History and physical note"
                )
            case .operativeNote:
                return CD(
                    code: "11504-8",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Surgical operation note"
                )
            case .procedureNote:
                return CD(
                    code: "28570-0",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Procedure note"
                )
            case .transferSummary:
                return CD(
                    code: "18761-7",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Transfer summary note"
                )
            case .continuityOfCareDocument:
                return CD(
                    code: "34133-9",
                    codeSystem: CodeSystem.loinc,
                    codeSystemName: "LOINC",
                    displayName: "Continuity of Care Document"
                )
            }
        }
    }
    
    // MARK: - Section Codes (LOINC)
    
    /// Creates a section code for common CDA sections
    public enum SectionType {
        case chiefComplaint
        case historyOfPresentIllness
        case pastMedicalHistory
        case medications
        case allergies
        case socialHistory
        case familyHistory
        case reviewOfSystems
        case physicalExamination
        case assessmentAndPlan
        case vitalSigns
        case resultsSection
        case problems
        case procedures
        case immunizations
        case advanceDirectives
        
        public var code: CD {
            switch self {
            case .chiefComplaint:
                return CD(code: "10154-3", codeSystem: CodeSystem.loinc, displayName: "Chief complaint")
            case .historyOfPresentIllness:
                return CD(code: "10164-2", codeSystem: CodeSystem.loinc, displayName: "History of present illness")
            case .pastMedicalHistory:
                return CD(code: "11348-0", codeSystem: CodeSystem.loinc, displayName: "History of past illness")
            case .medications:
                return CD(code: "10160-0", codeSystem: CodeSystem.loinc, displayName: "History of Medication use")
            case .allergies:
                return CD(code: "48765-2", codeSystem: CodeSystem.loinc, displayName: "Allergies and adverse reactions")
            case .socialHistory:
                return CD(code: "29762-2", codeSystem: CodeSystem.loinc, displayName: "Social history")
            case .familyHistory:
                return CD(code: "10157-6", codeSystem: CodeSystem.loinc, displayName: "History of family member diseases")
            case .reviewOfSystems:
                return CD(code: "10187-3", codeSystem: CodeSystem.loinc, displayName: "Review of systems")
            case .physicalExamination:
                return CD(code: "29545-1", codeSystem: CodeSystem.loinc, displayName: "Physical examination")
            case .assessmentAndPlan:
                return CD(code: "51847-2", codeSystem: CodeSystem.loinc, displayName: "Assessment and plan")
            case .vitalSigns:
                return CD(code: "8716-3", codeSystem: CodeSystem.loinc, displayName: "Vital signs")
            case .resultsSection:
                return CD(code: "30954-2", codeSystem: CodeSystem.loinc, displayName: "Relevant diagnostic tests/laboratory data")
            case .problems:
                return CD(code: "11450-4", codeSystem: CodeSystem.loinc, displayName: "Problem list")
            case .procedures:
                return CD(code: "47519-4", codeSystem: CodeSystem.loinc, displayName: "History of procedures")
            case .immunizations:
                return CD(code: "11369-6", codeSystem: CodeSystem.loinc, displayName: "History of immunization")
            case .advanceDirectives:
                return CD(code: "42348-3", codeSystem: CodeSystem.loinc, displayName: "Advance directives")
            }
        }
    }
    
    // MARK: - Administrative Codes
    
    /// Creates an administrative gender code
    public static func gender(_ code: GenderCode) -> CD {
        return CD(
            code: code.rawValue,
            codeSystem: CodeSystem.administrativeGender,
            codeSystemName: "AdministrativeGender",
            displayName: code.displayName
        )
    }
    
    /// Creates a confidentiality code
    public static func confidentiality(_ code: ConfidentialityCode) -> CD {
        return CD(
            code: code.rawValue,
            codeSystem: CodeSystem.confidentiality,
            codeSystemName: "Confidentiality",
            displayName: code.displayName
        )
    }
    
    /// Creates a marital status code
    public static func maritalStatus(code: String, displayName: String) -> CD {
        return CD(
            code: code,
            codeSystem: CodeSystem.maritalStatus,
            codeSystemName: "MaritalStatus",
            displayName: displayName
        )
    }
    
    /// Creates a language code (RFC 5646)
    public static func language(_ code: String) -> CD {
        return CD(code: code, codeSystem: "urn:ietf:bcp:47")
    }
}

// MARK: - Common Code Enumerations

/// Standard gender codes
public enum GenderCode: String {
    case male = "M"
    case female = "F"
    case unknown = "UN"
    case undifferentiated = "U"
    
    public var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unknown: return "Unknown"
        case .undifferentiated: return "Undifferentiated"
        }
    }
}

/// Standard confidentiality codes
public enum ConfidentialityCode: String {
    case normal = "N"
    case restricted = "R"
    case veryRestricted = "V"
    case low = "L"
    case moderate = "M"
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .restricted: return "Restricted"
        case .veryRestricted: return "Very Restricted"
        case .low: return "Low"
        case .moderate: return "Moderate"
        }
    }
}

// MARK: - Vocabulary Validator

/// Validates coded values against standard vocabularies
public struct VocabularyValidator {
    
    /// Validates that a code system OID is recognized
    /// - Parameter codeSystem: The code system OID to validate
    /// - Returns: True if the code system is recognized
    public static func isValidCodeSystem(_ codeSystem: String) -> Bool {
        let knownCodeSystems = [
            CodeSystem.loinc,
            CodeSystem.snomedCT,
            CodeSystem.rxNorm,
            CodeSystem.icd10CM,
            CodeSystem.icd9CM,
            CodeSystem.cpt,
            CodeSystem.cvx,
            CodeSystem.ndc,
            CodeSystem.ucum,
            CodeSystem.administrativeGender,
            CodeSystem.maritalStatus,
            CodeSystem.raceCategory,
            CodeSystem.ethnicityGroup,
            CodeSystem.language,
            CodeSystem.religiousAffiliation,
            CodeSystem.confidentiality,
            CodeSystem.actStatus,
            CodeSystem.telecomUse,
            CodeSystem.addressUse
        ]
        
        return knownCodeSystems.contains(codeSystem)
    }
    
    /// Validates that a coded value has required fields
    /// - Parameter code: The coded value to validate
    /// - Returns: True if the code has all required fields
    public static func isValidCode(_ code: CD) -> Bool {
        // Code and code system are required
        guard let codeValue = code.code, !codeValue.isEmpty else {
            return false
        }
        
        guard let codeSystem = code.codeSystem, !codeSystem.isEmpty else {
            return false
        }
        
        // If nullFlavor is present, code and codeSystem are not required
        if code.nullFlavor != nil {
            return true
        }
        
        return true
    }
}

// MARK: - Vocabulary Binding Extensions

extension CD {
    /// Creates a LOINC code
    /// - Parameters:
    ///   - code: LOINC code
    ///   - displayName: Display name
    /// - Returns: A CD with LOINC code system
    public static func loinc(code: String, displayName: String? = nil) -> CD {
        return CD(
            code: code,
            codeSystem: CodeSystem.loinc,
            codeSystemName: "LOINC",
            displayName: displayName
        )
    }
    
    /// Creates a SNOMED CT code
    /// - Parameters:
    ///   - code: SNOMED CT code
    ///   - displayName: Display name
    /// - Returns: A CD with SNOMED CT code system
    public static func snomedCT(code: String, displayName: String? = nil) -> CD {
        return CD(
            code: code,
            codeSystem: CodeSystem.snomedCT,
            codeSystemName: "SNOMED CT",
            displayName: displayName
        )
    }
    
    /// Creates an ICD-10-CM code
    /// - Parameters:
    ///   - code: ICD-10-CM code
    ///   - displayName: Display name
    /// - Returns: A CD with ICD-10-CM code system
    public static func icd10(code: String, displayName: String? = nil) -> CD {
        return CD(
            code: code,
            codeSystem: CodeSystem.icd10CM,
            codeSystemName: "ICD-10-CM",
            displayName: displayName
        )
    }
    
    /// Creates an RxNorm code
    /// - Parameters:
    ///   - code: RxNorm code
    ///   - displayName: Display name
    /// - Returns: A CD with RxNorm code system
    public static func rxNorm(code: String, displayName: String? = nil) -> CD {
        return CD(
            code: code,
            codeSystem: CodeSystem.rxNorm,
            codeSystemName: "RxNorm",
            displayName: displayName
        )
    }
}
