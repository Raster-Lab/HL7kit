/// RIMCore.swift
/// HL7 v3 Reference Information Model Core Classes
///
/// This file implements the core RIM classes: Act, Entity, Role, and Participation

import Foundation
import HL7Core

// MARK: - Act Class Codes

/// Act class codes from HL7 vocabulary
public enum ActClassCode: String, Sendable, Codable {
    case act = "ACT"
    case observation = "OBS"
    case procedure = "PROC"
    case substanceAdministration = "SBADM"
    case supply = "SPLY"
    case encounter = "ENC"
    case registration = "REG"
    case account = "ACCT"
    case invoice = "INVE"
    case battery = "BATTERY"
    case cluster = "CLUSTER"
    case document = "DOC"
    case extract = "EXTRACT"
    case folder = "FOLDER"
}

// MARK: - Act Mood Codes

/// Act mood codes indicating intent/status
public enum ActMoodCode: String, Sendable, Codable {
    case event = "EVN"
    case intent = "INT"
    case promise = "PRMS"
    case request = "RQO"
    case definition = "DEF"
    case goal = "GOL"
    case proposal = "PRPS"
    case recommendation = "RMD"
    case option = "OPT"
    case eventCriterion = "EVN.CRT"
}

// MARK: - Act Status Codes

/// Act status codes
public enum ActStatusCode: String, Sendable, Codable {
    case normal = "normal"
    case aborted = "aborted"
    case active = "active"
    case cancelled = "cancelled"
    case completed = "completed"
    case held = "held"
    case new = "new"
    case suspended = "suspended"
    case nullified = "nullified"
    case obsolete = "obsolete"
}

// MARK: - Act

/// Act - represents any action, event, or occurrence in healthcare
public struct Act: Sendable, Codable, Equatable {
    /// Type of act
    public let classCode: ActClassCode
    
    /// Intent or status of the act
    public let moodCode: ActMoodCode
    
    /// Unique identifier(s) for this act
    public let id: [II]
    
    /// Specific type of the act
    public let code: CD?
    
    /// Negation indicator
    public let negationInd: BL?
    
    /// Human-readable text
    public let text: ST?
    
    /// Current status
    public let statusCode: ActStatusCode?
    
    /// When the act occurred or was planned
    public let effectiveTime: IVL<TS>?
    
    /// Duration of the act
    public let activityTime: IVL<TS>?
    
    /// Why the act was performed
    public let reasonCode: [CD]?
    
    /// Priority code
    public let priorityCode: CD?
    
    /// Language code
    public let languageCode: CD?
    
    public init(
        classCode: ActClassCode,
        moodCode: ActMoodCode,
        id: [II] = [],
        code: CD? = nil,
        negationInd: BL? = nil,
        text: ST? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: IVL<TS>? = nil,
        activityTime: IVL<TS>? = nil,
        reasonCode: [CD]? = nil,
        priorityCode: CD? = nil,
        languageCode: CD? = nil
    ) {
        self.classCode = classCode
        self.moodCode = moodCode
        self.id = id
        self.code = code
        self.negationInd = negationInd
        self.text = text
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.activityTime = activityTime
        self.reasonCode = reasonCode
        self.priorityCode = priorityCode
        self.languageCode = languageCode
    }
}

// MARK: - Entity Class Codes

/// Entity class codes
public enum EntityClassCode: String, Sendable, Codable {
    case entity = "ENT"
    case livingSubject = "LIV"
    case person = "PSN"
    case organization = "ORG"
    case place = "PLC"
    case device = "DEV"
    case material = "MAT"
    case chemicalSubstance = "CHEM"
    case food = "FOOD"
    case container = "CONT"
    case holder = "HOLD"
    case manufactured = "MMAT"
    case nonPerson = "NLIV"
    case animal = "ANM"
    case plant = "PLNT"
    case microorganism = "MIC"
}

// MARK: - Entity Determiner Codes

/// Entity determiner codes (specific vs. generic)
public enum EntityDeterminerCode: String, Sendable, Codable {
    case instance = "INSTANCE"
    case kind = "KIND"
    case quantified = "QUANTIFIED_KIND"
}

// MARK: - Entity

/// Entity - represents physical things or beings in healthcare
public struct Entity: Sendable, Codable, Equatable {
    /// Type of entity
    public let classCode: EntityClassCode
    
    /// Whether specific or generic instance
    public let determinerCode: EntityDeterminerCode
    
    /// Unique identifier(s) for this entity
    public let id: [II]
    
    /// Specific type of the entity
    public let code: CD?
    
    /// Quantity (for materials)
    public let quantity: PQ?
    
    /// Names associated with the entity
    public let name: [EN]?
    
    /// Telecommunication addresses
    public let telecom: [TEL]?
    
    /// Physical addresses
    public let addr: [AD]?
    
    /// Description of the entity
    public let desc: ST?
    
    /// Current status
    public let statusCode: CD?
    
    /// Existence time
    public let existenceTime: IVL<TS>?
    
    public init(
        classCode: EntityClassCode,
        determinerCode: EntityDeterminerCode = .instance,
        id: [II] = [],
        code: CD? = nil,
        quantity: PQ? = nil,
        name: [EN]? = nil,
        telecom: [TEL]? = nil,
        addr: [AD]? = nil,
        desc: ST? = nil,
        statusCode: CD? = nil,
        existenceTime: IVL<TS>? = nil
    ) {
        self.classCode = classCode
        self.determinerCode = determinerCode
        self.id = id
        self.code = code
        self.quantity = quantity
        self.name = name
        self.telecom = telecom
        self.addr = addr
        self.desc = desc
        self.statusCode = statusCode
        self.existenceTime = existenceTime
    }
}

// MARK: - Role Class Codes

/// Role class codes
public enum RoleClassCode: String, Sendable, Codable {
    case role = "ROL"
    case patient = "PAT"
    case provider = "PROV"
    case employee = "EMP"
    case guardian = "GUARD"
    case licensedEntity = "LIC"
    case notaryPublic = "NOT"
    case caregiver = "CAREGIVER"
    case citizen = "CIT"
    case qualifier = "QUAL"
    case assigned = "ASSIGNED"
    case contact = "CON"
    case dependent = "DEPEN"
}

// MARK: - Role

/// Role - defines the capacity or function an entity assumes
public struct Role: Sendable, Codable, Equatable {
    /// Type of role
    public let classCode: RoleClassCode
    
    /// Unique identifier(s) for this role
    public let id: [II]
    
    /// Specific role type
    public let code: CD?
    
    /// Current status of the role
    public let statusCode: CD?
    
    /// When the role is active
    public let effectiveTime: IVL<TS>?
    
    /// Entity playing the role
    public let player: Entity?
    
    /// Entity scoping the role
    public let scoper: Entity?
    
    /// Telecommunication addresses for the role
    public let telecom: [TEL]?
    
    /// Addresses for the role
    public let addr: [AD]?
    
    public init(
        classCode: RoleClassCode,
        id: [II] = [],
        code: CD? = nil,
        statusCode: CD? = nil,
        effectiveTime: IVL<TS>? = nil,
        player: Entity? = nil,
        scoper: Entity? = nil,
        telecom: [TEL]? = nil,
        addr: [AD]? = nil
    ) {
        self.classCode = classCode
        self.id = id
        self.code = code
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.player = player
        self.scoper = scoper
        self.telecom = telecom
        self.addr = addr
    }
}

// MARK: - Participation Type Codes

/// Participation type codes
public enum ParticipationTypeCode: String, Sendable, Codable {
    case author = "AUT"
    case performer = "PRF"
    case subject = "SBJ"
    case informant = "INF"
    case responsibleParty = "RESP"
    case verifier = "VRF"
    case location = "LOC"
    case receiver = "RCV"
    case custodian = "CST"
    case authenticator = "AUTHEN"
    case legalAuthenticator = "LA"
    case witness = "WIT"
    case consultant = "CON"
    case referrer = "REF"
    case device = "DEV"
    case product = "PRD"
    case consumable = "CSM"
}

// MARK: - Participation Mode Codes

/// Participation mode codes
public enum ParticipationModeCode: String, Sendable, Codable {
    case physical = "PHYSICAL"
    case remote = "REMOTE"
    case verbal = "VERBAL"
    case written = "WRITTEN"
    case dictated = "DICTATE"
    case face2face = "FACE"
    case phone = "PHONE"
    case video = "VIDEOCONF"
    case electronic = "ELECTRONIC"
    case mail = "MAILTRN"
    case fax = "FAX"
}

// MARK: - Participation

/// Participation - expresses how an entity (in some role) participates in an act
public struct Participation: Sendable, Codable, Equatable {
    /// Type of participation
    public let typeCode: ParticipationTypeCode
    
    /// When the participation occurred
    public let time: IVL<TS>?
    
    /// Method of participation
    public let modeCode: ParticipationModeCode?
    
    /// Level of awareness
    public let awarenessCode: CD?
    
    /// The role participating in the act
    public let role: Role?
    
    /// Signature or authentication
    public let signatureCode: CD?
    
    /// Signature text
    public let signatureText: ST?
    
    public init(
        typeCode: ParticipationTypeCode,
        time: IVL<TS>? = nil,
        modeCode: ParticipationModeCode? = nil,
        awarenessCode: CD? = nil,
        role: Role? = nil,
        signatureCode: CD? = nil,
        signatureText: ST? = nil
    ) {
        self.typeCode = typeCode
        self.time = time
        self.modeCode = modeCode
        self.awarenessCode = awarenessCode
        self.role = role
        self.signatureCode = signatureCode
        self.signatureText = signatureText
    }
}

// MARK: - Act Relationship Type Codes

/// Act relationship type codes
public enum ActRelationshipTypeCode: String, Sendable, Codable {
    case component = "COMP"
    case subject = "SUBJ"
    case causative = "CAUS"
    case reason = "RSON"
    case fulfills = "FLFS"
    case sequel = "SEQL"
    case replaces = "RPLC"
    case update = "UPDT"
    case hasSupport = "SPRT"
    case documentation = "DOC"
    case derived = "DRIV"
}

// MARK: - ActRelationship

/// ActRelationship - describes relationships between acts
public struct ActRelationship: Sendable, Codable, Equatable {
    /// Type of relationship
    public let typeCode: ActRelationshipTypeCode
    
    /// Whether relationship is inverted
    public let inversionInd: BL?
    
    /// Whether context propagates
    public let contextConductionInd: BL?
    
    /// Sequence number
    public let sequenceNumber: INT?
    
    /// Priority number
    public let priorityNumber: INT?
    
    /// Pause quantity
    public let pauseQuantity: PQ?
    
    /// The source act
    public let source: Act?
    
    /// The target act
    public let target: Act?
    
    public init(
        typeCode: ActRelationshipTypeCode,
        inversionInd: BL? = nil,
        contextConductionInd: BL? = nil,
        sequenceNumber: INT? = nil,
        priorityNumber: INT? = nil,
        pauseQuantity: PQ? = nil,
        source: Act? = nil,
        target: Act? = nil
    ) {
        self.typeCode = typeCode
        self.inversionInd = inversionInd
        self.contextConductionInd = contextConductionInd
        self.sequenceNumber = sequenceNumber
        self.priorityNumber = priorityNumber
        self.pauseQuantity = pauseQuantity
        self.source = source
        self.target = target
    }
}

// MARK: - RoleLink Type Codes

/// RoleLink type codes
public enum RoleLinkTypeCode: String, Sendable, Codable {
    case related = "REL"
    case backup = "BACKUP"
    case part = "PART"
    case identity = "IDENT"
    case replacement = "REPL"
}

// MARK: - RoleLink

/// RoleLink - shows relationships between roles
public struct RoleLink: Sendable, Codable, Equatable {
    /// Type of relationship
    public let typeCode: RoleLinkTypeCode
    
    /// When the relationship is effective
    public let effectiveTime: IVL<TS>?
    
    /// The source role
    public let source: Role?
    
    /// The target role
    public let target: Role?
    
    public init(
        typeCode: RoleLinkTypeCode,
        effectiveTime: IVL<TS>? = nil,
        source: Role? = nil,
        target: Role? = nil
    ) {
        self.typeCode = typeCode
        self.effectiveTime = effectiveTime
        self.source = source
        self.target = target
    }
}
