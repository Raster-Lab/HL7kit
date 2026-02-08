/// CDADocument.swift
/// Clinical Document Architecture R2 Document Structure
///
/// This file implements the core CDA R2 ClinicalDocument class and its header components.

import Foundation
import HL7Core

// MARK: - ClinicalDocument

/// ClinicalDocument - The root element of a CDA R2 document
///
/// A ClinicalDocument is a complete information object that is the result of an encounter,
/// summarizes an episode of care, or records progress notes. It contains header information
/// about the document itself and a body containing the clinical content.
public struct ClinicalDocument: Sendable, Codable, Equatable {
    /// Type identifier indicating this is a clinical document
    public let classCode: ActClassCode = .document
    
    /// Mood code is always event for a clinical document
    public let moodCode: ActMoodCode = .event
    
    /// Realm code (e.g., "US" for United States)
    public let realmCode: [CD]?
    
    /// Type identifier (e.g., "2.16.840.1.113883.1.3" for CDA R2)
    public let typeId: II
    
    /// Template identifiers for this document
    public let templateId: [II]
    
    /// Unique identifier for this document
    public let id: II
    
    /// Document type code (e.g., LOINC code for document type)
    public let code: CD
    
    /// Human-readable title
    public let title: ST?
    
    /// Date/time when document was created
    public let effectiveTime: TS
    
    /// Confidentiality code
    public let confidentialityCode: CD
    
    /// Language code (e.g., "en-US")
    public let languageCode: CD?
    
    /// Document set identifier for grouping related documents
    public let setId: II?
    
    /// Version number within a document set
    public let versionNumber: INT?
    
    /// When document can no longer be legally amended
    public let copyTime: TS?
    
    // MARK: Header Participants
    
    /// Patient(s) who are the subject of the document
    public let recordTarget: [RecordTarget]
    
    /// Person(s) who authored the document
    public let author: [Author]
    
    /// Data entry person/system
    public let dataEnterer: DataEnterer?
    
    /// Persons who participated in the care documented
    public let informant: [Informant]?
    
    /// Organization responsible for maintaining the document
    public let custodian: Custodian
    
    /// Recipient(s) of the document
    public let informationRecipient: [InformationRecipient]?
    
    /// Person who legally authenticated the document
    public let legalAuthenticator: LegalAuthenticator?
    
    /// Additional authenticators
    public let authenticator: [Authenticator]?
    
    /// Related parent document
    public let relatedDocument: [RelatedDocument]?
    
    /// Document authorization
    public let authorization: [Authorization]?
    
    // MARK: Body
    
    /// Document body containing clinical content
    public let component: DocumentComponent
    
    /// Creates a new clinical document
    public init(
        realmCode: [CD]? = nil,
        typeId: II,
        templateId: [II],
        id: II,
        code: CD,
        title: ST? = nil,
        effectiveTime: TS,
        confidentialityCode: CD,
        languageCode: CD? = nil,
        setId: II? = nil,
        versionNumber: INT? = nil,
        copyTime: TS? = nil,
        recordTarget: [RecordTarget],
        author: [Author],
        dataEnterer: DataEnterer? = nil,
        informant: [Informant]? = nil,
        custodian: Custodian,
        informationRecipient: [InformationRecipient]? = nil,
        legalAuthenticator: LegalAuthenticator? = nil,
        authenticator: [Authenticator]? = nil,
        relatedDocument: [RelatedDocument]? = nil,
        authorization: [Authorization]? = nil,
        component: DocumentComponent
    ) {
        self.realmCode = realmCode
        self.typeId = typeId
        self.templateId = templateId
        self.id = id
        self.code = code
        self.title = title
        self.effectiveTime = effectiveTime
        self.confidentialityCode = confidentialityCode
        self.languageCode = languageCode
        self.setId = setId
        self.versionNumber = versionNumber
        self.copyTime = copyTime
        self.recordTarget = recordTarget
        self.author = author
        self.dataEnterer = dataEnterer
        self.informant = informant
        self.custodian = custodian
        self.informationRecipient = informationRecipient
        self.legalAuthenticator = legalAuthenticator
        self.authenticator = authenticator
        self.relatedDocument = relatedDocument
        self.authorization = authorization
        self.component = component
    }
}

// MARK: - DocumentComponent

/// The component wrapper for the document body
public struct DocumentComponent: Sendable, Codable, Equatable {
    /// The document body
    public let body: DocumentBody
    
    public init(body: DocumentBody) {
        self.body = body
    }
}

// MARK: - DocumentBody

/// The body of a CDA document - either structured or non-XML
public enum DocumentBody: Sendable, Codable, Equatable {
    /// Structured body with sections (CDA Level 2/3)
    case structured(StructuredBody)
    
    /// Non-XML body with narrative only (CDA Level 1)
    case nonXML(NonXMLBody)
}

// MARK: - StructuredBody

/// A structured body containing sections
public struct StructuredBody: Sendable, Codable, Equatable {
    /// Confidentiality code for the body
    public let confidentialityCode: CD?
    
    /// Language code for the body
    public let languageCode: CD?
    
    /// Sections in the body
    public let component: [BodyComponent]
    
    public init(
        confidentialityCode: CD? = nil,
        languageCode: CD? = nil,
        component: [BodyComponent]
    ) {
        self.confidentialityCode = confidentialityCode
        self.languageCode = languageCode
        self.component = component
    }
}

// MARK: - BodyComponent

/// A component wrapper for a section
public struct BodyComponent: Sendable, Codable, Equatable {
    /// The section
    public let section: Section
    
    public init(section: Section) {
        self.section = section
    }
}

// MARK: - NonXMLBody

/// A non-XML body for CDA Level 1 documents
public struct NonXMLBody: Sendable, Codable, Equatable {
    /// Confidentiality code
    public let confidentialityCode: CD?
    
    /// Language code
    public let languageCode: CD?
    
    /// Media type (e.g., "application/pdf", "text/plain")
    public let text: ED
    
    public init(
        confidentialityCode: CD? = nil,
        languageCode: CD? = nil,
        text: ED
    ) {
        self.confidentialityCode = confidentialityCode
        self.languageCode = languageCode
        self.text = text
    }
}

// MARK: - ED (Encapsulated Data)

/// Encapsulated data type for non-XML content
public struct ED: Sendable, Codable, Equatable {
    /// Media type (MIME type)
    public let mediaType: String?
    
    /// Compression algorithm
    public let compression: String?
    
    /// Integrity check algorithm
    public let integrityCheckAlgorithm: String?
    
    /// Binary data (base64 encoded)
    public let data: Data?
    
    /// Reference to external data
    public let reference: ST?
    
    public init(
        mediaType: String? = nil,
        compression: String? = nil,
        integrityCheckAlgorithm: String? = nil,
        data: Data? = nil,
        reference: ST? = nil
    ) {
        self.mediaType = mediaType
        self.compression = compression
        self.integrityCheckAlgorithm = integrityCheckAlgorithm
        self.data = data
        self.reference = reference
    }
}

// MARK: - CDA Vocabulary

/// Standard CDA type ID root
public extension II {
    /// The standard CDA R2 type ID
    static let cdaTypeId = II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040")
}

/// Common document type codes
public extension CD {
    /// Progress Note
    static func progressNote() -> CD {
        CD(code: "11506-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Progress note")
    }
    
    /// Discharge Summary
    static func dischargeSummary() -> CD {
        CD(code: "18842-5", codeSystem: "2.16.840.1.113883.6.1", displayName: "Discharge summary")
    }
    
    /// History and Physical
    static func historyAndPhysical() -> CD {
        CD(code: "34117-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "History and physical note")
    }
    
    /// Consultation Note
    static func consultationNote() -> CD {
        CD(code: "11488-4", codeSystem: "2.16.840.1.113883.6.1", displayName: "Consultation note")
    }
    
    /// Operative Note
    static func operativeNote() -> CD {
        CD(code: "11504-8", codeSystem: "2.16.840.1.113883.6.1", displayName: "Surgical operation note")
    }
}
