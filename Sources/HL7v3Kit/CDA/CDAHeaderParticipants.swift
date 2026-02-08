/// CDAHeaderParticipants.swift
/// CDA R2 Header Participant Types
///
/// This file implements the various participant types that appear in CDA document headers:
/// RecordTarget, Author, Custodian, Authenticator, etc.

import Foundation
import HL7Core

// MARK: - RecordTarget

/// RecordTarget - The patient who is the subject of the clinical document
public struct RecordTarget: Sendable, Codable, Equatable {
    /// Type code (always RCT for record target)
    public let typeCode: String = "RCT"
    
    /// Context control code
    public let contextControlCode: String = "OP"
    
    /// The patient role
    public let patientRole: PatientRole
    
    public init(patientRole: PatientRole) {
        self.patientRole = patientRole
    }
}

/// PatientRole - Role of the patient
public struct PatientRole: Sendable, Codable, Equatable {
    /// Patient identifiers
    public let id: [II]
    
    /// Patient addresses
    public let addr: [AD]?
    
    /// Patient telecom addresses
    public let telecom: [TEL]?
    
    /// The patient entity
    public let patient: Patient?
    
    /// Healthcare provider organization
    public let providerOrganization: Organization?
    
    public init(
        id: [II],
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        patient: Patient? = nil,
        providerOrganization: Organization? = nil
    ) {
        self.id = id
        self.addr = addr
        self.telecom = telecom
        self.patient = patient
        self.providerOrganization = providerOrganization
    }
}

/// Patient - The patient entity
public struct Patient: Sendable, Codable, Equatable {
    /// Patient name(s)
    public let name: [EN]?
    
    /// Administrative gender code
    public let administrativeGenderCode: CD?
    
    /// Birth time
    public let birthTime: TS?
    
    /// Marital status code
    public let maritalStatusCode: CD?
    
    /// Religious affiliation code
    public let religiousAffiliationCode: CD?
    
    /// Race code
    public let raceCode: CD?
    
    /// Ethnicity code
    public let ethnicGroupCode: CD?
    
    /// Guardian(s)
    public let guardian: [Guardian]?
    
    /// Birth place
    public let birthplace: Birthplace?
    
    /// Language communication
    public let languageCommunication: [LanguageCommunication]?
    
    public init(
        name: [EN]? = nil,
        administrativeGenderCode: CD? = nil,
        birthTime: TS? = nil,
        maritalStatusCode: CD? = nil,
        religiousAffiliationCode: CD? = nil,
        raceCode: CD? = nil,
        ethnicGroupCode: CD? = nil,
        guardian: [Guardian]? = nil,
        birthplace: Birthplace? = nil,
        languageCommunication: [LanguageCommunication]? = nil
    ) {
        self.name = name
        self.administrativeGenderCode = administrativeGenderCode
        self.birthTime = birthTime
        self.maritalStatusCode = maritalStatusCode
        self.religiousAffiliationCode = religiousAffiliationCode
        self.raceCode = raceCode
        self.ethnicGroupCode = ethnicGroupCode
        self.guardian = guardian
        self.birthplace = birthplace
        self.languageCommunication = languageCommunication
    }
}

// MARK: - Author

/// Author - Person or device who created the document content
public struct Author: Sendable, Codable, Equatable {
    /// Type code (always AUT for author)
    public let typeCode: String = "AUT"
    
    /// Context control code
    public let contextControlCode: String = "OP"
    
    /// Function code (role of author)
    public let functionCode: CD?
    
    /// When this author participated
    public let time: TS
    
    /// The author role
    public let assignedAuthor: AssignedAuthor
    
    public init(
        functionCode: CD? = nil,
        time: TS,
        assignedAuthor: AssignedAuthor
    ) {
        self.functionCode = functionCode
        self.time = time
        self.assignedAuthor = assignedAuthor
    }
}

/// AssignedAuthor - Role of the author
public struct AssignedAuthor: Sendable, Codable, Equatable {
    /// Author identifiers
    public let id: [II]
    
    /// Author code (e.g., specialty)
    public let code: CD?
    
    /// Author addresses
    public let addr: [AD]?
    
    /// Author telecom
    public let telecom: [TEL]?
    
    /// The person author
    public let assignedPerson: Person?
    
    /// The authoring device (if not a person)
    public let assignedAuthoringDevice: AuthoringDevice?
    
    /// Represented organization
    public let representedOrganization: Organization?
    
    public init(
        id: [II],
        code: CD? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        assignedPerson: Person? = nil,
        assignedAuthoringDevice: AuthoringDevice? = nil,
        representedOrganization: Organization? = nil
    ) {
        self.id = id
        self.code = code
        self.addr = addr
        self.telecom = telecom
        self.assignedPerson = assignedPerson
        self.assignedAuthoringDevice = assignedAuthoringDevice
        self.representedOrganization = representedOrganization
    }
}

// MARK: - Custodian

/// Custodian - Organization that maintains the document
public struct Custodian: Sendable, Codable, Equatable {
    /// Type code (always CST for custodian)
    public let typeCode: String = "CST"
    
    /// The custodian role
    public let assignedCustodian: AssignedCustodian
    
    public init(assignedCustodian: AssignedCustodian) {
        self.assignedCustodian = assignedCustodian
    }
}

/// AssignedCustodian - Role of the custodian
public struct AssignedCustodian: Sendable, Codable, Equatable {
    /// The custodian organization
    public let representedCustodianOrganization: CustodianOrganization
    
    public init(representedCustodianOrganization: CustodianOrganization) {
        self.representedCustodianOrganization = representedCustodianOrganization
    }
}

/// CustodianOrganization - The custodian organization details
public struct CustodianOrganization: Sendable, Codable, Equatable {
    /// Organization identifiers
    public let id: [II]
    
    /// Organization name
    public let name: EN?
    
    /// Organization telecom
    public let telecom: TEL?
    
    /// Organization address
    public let addr: AD?
    
    public init(
        id: [II],
        name: EN? = nil,
        telecom: TEL? = nil,
        addr: AD? = nil
    ) {
        self.id = id
        self.name = name
        self.telecom = telecom
        self.addr = addr
    }
}

// MARK: - Authenticator

/// LegalAuthenticator - Person who legally authenticated the document
public struct LegalAuthenticator: Sendable, Codable, Equatable {
    /// Type code (always AUTHEN for authenticator)
    public let typeCode: String = "AUTHEN"
    
    /// Context control code
    public let contextControlCode: String = "OP"
    
    /// Signature code
    public let signatureCode: CD
    
    /// When authentication occurred
    public let time: TS
    
    /// The authenticator
    public let assignedEntity: AssignedEntity
    
    public init(
        signatureCode: CD,
        time: TS,
        assignedEntity: AssignedEntity
    ) {
        self.signatureCode = signatureCode
        self.time = time
        self.assignedEntity = assignedEntity
    }
}

/// Authenticator - Additional authenticators
public struct Authenticator: Sendable, Codable, Equatable {
    /// Type code (always AUTHEN for authenticator)
    public let typeCode: String = "AUTHEN"
    
    /// Signature code
    public let signatureCode: CD
    
    /// When authentication occurred
    public let time: TS
    
    /// The authenticator
    public let assignedEntity: AssignedEntity
    
    public init(
        signatureCode: CD,
        time: TS,
        assignedEntity: AssignedEntity
    ) {
        self.signatureCode = signatureCode
        self.time = time
        self.assignedEntity = assignedEntity
    }
}

// MARK: - Other Participants

/// DataEnterer - Person who entered the data
public struct DataEnterer: Sendable, Codable, Equatable {
    /// Type code (always ENT for data enterer)
    public let typeCode: String = "ENT"
    
    /// Context control code
    public let contextControlCode: String = "OP"
    
    /// When data was entered
    public let time: TS?
    
    /// The data enterer
    public let assignedEntity: AssignedEntity
    
    public init(
        time: TS? = nil,
        assignedEntity: AssignedEntity
    ) {
        self.time = time
        self.assignedEntity = assignedEntity
    }
}

/// Informant - Person who provided information
public struct Informant: Sendable, Codable, Equatable {
    /// Type code (always INF for informant)
    public let typeCode: String = "INF"
    
    /// Context control code
    public let contextControlCode: String = "OP"
    
    /// The informant (either assigned entity or related entity)
    public let informantChoice: InformantChoice
    
    public init(informantChoice: InformantChoice) {
        self.informantChoice = informantChoice
    }
}

/// InformantChoice - Either an assigned entity or related entity
public enum InformantChoice: Sendable, Codable, Equatable {
    case assignedEntity(AssignedEntity)
    case relatedEntity(RelatedEntity)
}

/// InformationRecipient - Intended recipient of the document
public struct InformationRecipient: Sendable, Codable, Equatable {
    /// Type code (always PRCP for primary recipient)
    public let typeCode: String = "PRCP"
    
    /// The recipient
    public let intendedRecipient: IntendedRecipient
    
    public init(intendedRecipient: IntendedRecipient) {
        self.intendedRecipient = intendedRecipient
    }
}

/// IntendedRecipient - Details of the intended recipient
public struct IntendedRecipient: Sendable, Codable, Equatable {
    /// Recipient identifiers
    public let id: [II]?
    
    /// Recipient addresses
    public let addr: [AD]?
    
    /// Recipient telecom
    public let telecom: [TEL]?
    
    /// Person recipient
    public let informationRecipient: Person?
    
    /// Organization recipient
    public let receivedOrganization: Organization?
    
    public init(
        id: [II]? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        informationRecipient: Person? = nil,
        receivedOrganization: Organization? = nil
    ) {
        self.id = id
        self.addr = addr
        self.telecom = telecom
        self.informationRecipient = informationRecipient
        self.receivedOrganization = receivedOrganization
    }
}

// MARK: - Supporting Types

/// Person - A person entity
public struct Person: Sendable, Codable, Equatable {
    /// Person name(s)
    public let name: [EN]?
    
    public init(name: [EN]? = nil) {
        self.name = name
    }
}

/// Organization - An organization entity
public struct Organization: Sendable, Codable, Equatable {
    /// Organization identifiers
    public let id: [II]?
    
    /// Organization name(s)
    public let name: [EN]?
    
    /// Organization telecom
    public let telecom: [TEL]?
    
    /// Organization address
    public let addr: [AD]?
    
    public init(
        id: [II]? = nil,
        name: [EN]? = nil,
        telecom: [TEL]? = nil,
        addr: [AD]? = nil
    ) {
        self.id = id
        self.name = name
        self.telecom = telecom
        self.addr = addr
    }
}

/// AssignedEntity - Generic assigned entity
public struct AssignedEntity: Sendable, Codable, Equatable {
    /// Entity identifiers
    public let id: [II]
    
    /// Entity code
    public let code: CD?
    
    /// Entity addresses
    public let addr: [AD]?
    
    /// Entity telecom
    public let telecom: [TEL]?
    
    /// Person
    public let assignedPerson: Person?
    
    /// Represented organization
    public let representedOrganization: Organization?
    
    public init(
        id: [II],
        code: CD? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        assignedPerson: Person? = nil,
        representedOrganization: Organization? = nil
    ) {
        self.id = id
        self.code = code
        self.addr = addr
        self.telecom = telecom
        self.assignedPerson = assignedPerson
        self.representedOrganization = representedOrganization
    }
}

/// RelatedEntity - An entity related to the patient
public struct RelatedEntity: Sendable, Codable, Equatable {
    /// Relationship code
    public let classCode: CD
    
    /// Entity code
    public let code: CD?
    
    /// Entity addresses
    public let addr: [AD]?
    
    /// Entity telecom
    public let telecom: [TEL]?
    
    /// Effective time of relationship
    public let effectiveTime: IVL<TS>?
    
    /// Related person
    public let relatedPerson: Person?
    
    public init(
        classCode: CD,
        code: CD? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        effectiveTime: IVL<TS>? = nil,
        relatedPerson: Person? = nil
    ) {
        self.classCode = classCode
        self.code = code
        self.addr = addr
        self.telecom = telecom
        self.effectiveTime = effectiveTime
        self.relatedPerson = relatedPerson
    }
}

/// AuthoringDevice - A device that authored content
public struct AuthoringDevice: Sendable, Codable, Equatable {
    /// Device code
    public let code: CD?
    
    /// Manufacturer model name
    public let manufacturerModelName: ST?
    
    /// Software name
    public let softwareName: ST?
    
    public init(
        code: CD? = nil,
        manufacturerModelName: ST? = nil,
        softwareName: ST? = nil
    ) {
        self.code = code
        self.manufacturerModelName = manufacturerModelName
        self.softwareName = softwareName
    }
}

/// Guardian - Legal guardian of the patient
public struct Guardian: Sendable, Codable, Equatable {
    /// Guardian code
    public let code: CD?
    
    /// Guardian addresses
    public let addr: [AD]?
    
    /// Guardian telecom
    public let telecom: [TEL]?
    
    /// Guardian person
    public let guardianPerson: Person?
    
    /// Guardian organization
    public let guardianOrganization: Organization?
    
    public init(
        code: CD? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        guardianPerson: Person? = nil,
        guardianOrganization: Organization? = nil
    ) {
        self.code = code
        self.addr = addr
        self.telecom = telecom
        self.guardianPerson = guardianPerson
        self.guardianOrganization = guardianOrganization
    }
}

/// Birthplace - Patient's place of birth
public struct Birthplace: Sendable, Codable, Equatable {
    /// Place
    public let place: Place
    
    public init(place: Place) {
        self.place = place
    }
}

/// Place - A physical place
public struct Place: Sendable, Codable, Equatable {
    /// Place name
    public let name: EN?
    
    /// Place address
    public let addr: AD?
    
    public init(name: EN? = nil, addr: AD? = nil) {
        self.name = name
        self.addr = addr
    }
}

/// LanguageCommunication - Patient's language preferences
public struct LanguageCommunication: Sendable, Codable, Equatable {
    /// Language code (e.g., "en", "es")
    public let languageCode: CD?
    
    /// Mode code (spoken, written, etc.)
    public let modeCode: CD?
    
    /// Proficiency level code
    public let proficiencyLevelCode: CD?
    
    /// Preference indicator
    public let preferenceInd: BL?
    
    public init(
        languageCode: CD? = nil,
        modeCode: CD? = nil,
        proficiencyLevelCode: CD? = nil,
        preferenceInd: BL? = nil
    ) {
        self.languageCode = languageCode
        self.modeCode = modeCode
        self.proficiencyLevelCode = proficiencyLevelCode
        self.preferenceInd = preferenceInd
    }
}

// MARK: - Document Relationships

/// RelatedDocument - Reference to a parent or replaced document
public struct RelatedDocument: Sendable, Codable, Equatable {
    /// Type of relationship (APND=append, RPLC=replace, XFRM=transform)
    public let typeCode: String
    
    /// The parent document
    public let parentDocument: ParentDocument
    
    public init(typeCode: String, parentDocument: ParentDocument) {
        self.typeCode = typeCode
        self.parentDocument = parentDocument
    }
}

/// ParentDocument - Details of a parent document
public struct ParentDocument: Sendable, Codable, Equatable {
    /// Parent document identifiers
    public let id: [II]
    
    /// Parent document code
    public let code: CD?
    
    /// Parent document title
    public let text: ST?
    
    /// Parent document set ID
    public let setId: II?
    
    /// Parent document version number
    public let versionNumber: INT?
    
    public init(
        id: [II],
        code: CD? = nil,
        text: ST? = nil,
        setId: II? = nil,
        versionNumber: INT? = nil
    ) {
        self.id = id
        self.code = code
        self.text = text
        self.setId = setId
        self.versionNumber = versionNumber
    }
}

/// Authorization - Consent or authorization for the document
public struct Authorization: Sendable, Codable, Equatable {
    /// Type code (always AUTH for authorization)
    public let typeCode: String = "AUTH"
    
    /// The consent
    public let consent: Consent
    
    public init(consent: Consent) {
        self.consent = consent
    }
}

/// Consent - Details of patient consent
public struct Consent: Sendable, Codable, Equatable {
    /// Consent identifiers
    public let id: [II]?
    
    /// Consent code
    public let code: CD?
    
    /// Status code
    public let statusCode: CD
    
    public init(
        id: [II]? = nil,
        code: CD? = nil,
        statusCode: CD
    ) {
        self.id = id
        self.code = code
        self.statusCode = statusCode
    }
}
