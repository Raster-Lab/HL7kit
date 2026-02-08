/// CDAEntry.swift
/// CDA R2 Entry Types and Clinical Statements
///
/// This file implements entry structures for machine-readable clinical content in CDA sections.

import Foundation
import HL7Core

// MARK: - Entry

/// Entry - Wrapper for structured clinical content in a section
public struct Entry: Sendable, Codable, Equatable {
    /// Type code for the entry relationship
    public let typeCode: EntryRelationshipType
    
    /// Context conduction indicator
    public let contextConductionInd: BL?
    
    /// The clinical statement
    public let clinicalStatement: ClinicalStatement
    
    public init(
        typeCode: EntryRelationshipType = .driv,
        contextConductionInd: BL? = nil,
        clinicalStatement: ClinicalStatement
    ) {
        self.typeCode = typeCode
        self.contextConductionInd = contextConductionInd
        self.clinicalStatement = clinicalStatement
    }
}

/// Entry relationship type codes
public enum EntryRelationshipType: String, Sendable, Codable {
    /// Has component (COMP)
    case comp = "COMP"
    
    /// Derived from (DRIV) - default for section entries
    case driv = "DRIV"
    
    /// Has subject (SUBJ)
    case subj = "SUBJ"
    
    /// Has cause (CAUS)
    case caus = "CAUS"
    
    /// Has manifestation (MFST)
    case mfst = "MFST"
    
    /// Has reason (RSON)
    case rson = "RSON"
    
    /// Has reference (REFR)
    case refr = "REFR"
    
    /// Has support (SPRT)
    case sprt = "SPRT"
}

// MARK: - ClinicalStatement

/// ClinicalStatement - Polymorphic type for different kinds of clinical statements
public enum ClinicalStatement: Sendable, Codable, Equatable {
    /// Observation (e.g., vital sign, lab result, assessment)
    case observation(ClinicalObservation)
    
    /// Procedure (e.g., surgery, diagnostic procedure)
    case procedure(Procedure)
    
    /// Substance administration (e.g., medication)
    case substanceAdministration(SubstanceAdministration)
    
    /// Supply (e.g., medical device)
    case supply(Supply)
    
    /// Encounter (e.g., visit, admission)
    case encounter(Encounter)
    
    /// Act (generic clinical act)
    case act(ClinicalAct)
    
    /// Organizer (groups related clinical statements)
    case organizer(Organizer)
}

// MARK: - ClinicalObservation

/// ClinicalObservation - An observation about a patient
public struct ClinicalObservation: Sendable, Codable, Equatable {
    /// Class code (always OBS for observation)
    public let classCode: ActClassCode = .observation
    
    /// Mood code (EVN, INT, GOL, etc.)
    public let moodCode: ActMoodCode
    
    /// Negation indicator
    public let negationInd: BL?
    
    /// Observation identifiers
    public let id: [II]?
    
    /// Observation type code (e.g., LOINC code)
    public let code: CD
    
    /// Derivation expression
    public let derivationExpr: ST?
    
    /// Descriptive text
    public let text: ED?
    
    /// Status code
    public let statusCode: ActStatusCode
    
    /// Observation effective time
    public let effectiveTime: IVL<TS>?
    
    /// Priority code
    public let priorityCode: CD?
    
    /// Repeat number
    public let repeatNumber: IVL<INT>?
    
    /// Language code
    public let languageCode: CD?
    
    /// Observation value(s)
    public let value: [ObservationValue]?
    
    /// Interpretation codes
    public let interpretationCode: [CD]?
    
    /// Method code
    public let methodCode: [CD]?
    
    /// Target site codes
    public let targetSiteCode: [CD]?
    
    /// Performers
    public let performer: [Performer]?
    
    /// Authors
    public let author: [Author]?
    
    /// Informants
    public let informant: [Informant]?
    
    /// Participants
    public let participant: [Participant]?
    
    /// Entry relationships (component observations, etc.)
    public let entryRelationship: [EntryRelationship]?
    
    /// Reference to original text
    public let reference: [Reference]?
    
    /// Preconditions
    public let precondition: [Precondition]?
    
    /// Reference ranges
    public let referenceRange: [ReferenceRange]?
    
    public init(
        moodCode: ActMoodCode = .event,
        negationInd: BL? = nil,
        id: [II]? = nil,
        code: CD,
        derivationExpr: ST? = nil,
        text: ED? = nil,
        statusCode: ActStatusCode = .completed,
        effectiveTime: IVL<TS>? = nil,
        priorityCode: CD? = nil,
        repeatNumber: IVL<INT>? = nil,
        languageCode: CD? = nil,
        value: [ObservationValue]? = nil,
        interpretationCode: [CD]? = nil,
        methodCode: [CD]? = nil,
        targetSiteCode: [CD]? = nil,
        performer: [Performer]? = nil,
        author: [Author]? = nil,
        informant: [Informant]? = nil,
        participant: [Participant]? = nil,
        entryRelationship: [EntryRelationship]? = nil,
        reference: [Reference]? = nil,
        precondition: [Precondition]? = nil,
        referenceRange: [ReferenceRange]? = nil
    ) {
        self.moodCode = moodCode
        self.negationInd = negationInd
        self.id = id
        self.code = code
        self.derivationExpr = derivationExpr
        self.text = text
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.priorityCode = priorityCode
        self.repeatNumber = repeatNumber
        self.languageCode = languageCode
        self.value = value
        self.interpretationCode = interpretationCode
        self.methodCode = methodCode
        self.targetSiteCode = targetSiteCode
        self.performer = performer
        self.author = author
        self.informant = informant
        self.participant = participant
        self.entryRelationship = entryRelationship
        self.reference = reference
        self.precondition = precondition
        self.referenceRange = referenceRange
    }
}

// MARK: - Observation Value Types

/// ObservationValue - Polymorphic observation value
public enum ObservationValue: Sendable, Codable, Equatable {
    /// Physical quantity (e.g., 120 mmHg)
    case physicalQuantity(PQ)
    
    /// Coded value (e.g., "abnormal")
    case codedValue(CD)
    
    /// String value
    case stringValue(ST)
    
    /// Integer value
    case integerValue(INT)
    
    /// Real value
    case realValue(REAL)
    
    /// Boolean value
    case booleanValue(BL)
    
    /// Timestamp value
    case timestampValue(TS)
    
    /// Interval value
    case intervalValue(IVL<PQ>)
}

// MARK: - Reference Range

/// ReferenceRange - Normal range for an observation
public struct ReferenceRange: Sendable, Codable, Equatable {
    /// Type code (always REFV for reference value)
    public let typeCode: String = "REFV"
    
    /// Observation range
    public let observationRange: ObservationRange
    
    public init(observationRange: ObservationRange) {
        self.observationRange = observationRange
    }
}

/// ObservationRange - Range definition
public struct ObservationRange: Sendable, Codable, Equatable {
    /// Class code (always OBS for observation)
    public let classCode: String = "OBS"
    
    /// Mood code (always EVN.CRT for event criterion)
    public let moodCode: String = "EVN.CRT"
    
    /// Range code (e.g., "normal")
    public let code: CD?
    
    /// Range text description
    public let text: ED?
    
    /// Range value
    public let value: IVL<PQ>?
    
    /// Interpretation code
    public let interpretationCode: CD?
    
    public init(
        code: CD? = nil,
        text: ED? = nil,
        value: IVL<PQ>? = nil,
        interpretationCode: CD? = nil
    ) {
        self.code = code
        self.text = text
        self.value = value
        self.interpretationCode = interpretationCode
    }
}

// MARK: - Procedure

/// Procedure - A clinical procedure
public struct Procedure: Sendable, Codable, Equatable {
    /// Class code (always PROC for procedure)
    public let classCode: ActClassCode = .procedure
    
    /// Mood code (EVN, INT, etc.)
    public let moodCode: ActMoodCode
    
    /// Negation indicator
    public let negationInd: BL?
    
    /// Procedure identifiers
    public let id: [II]?
    
    /// Procedure code (e.g., CPT code)
    public let code: CD?
    
    /// Descriptive text
    public let text: ED?
    
    /// Status code
    public let statusCode: ActStatusCode?
    
    /// Procedure effective time
    public let effectiveTime: IVL<TS>?
    
    /// Priority code
    public let priorityCode: CD?
    
    /// Language code
    public let languageCode: CD?
    
    /// Method codes
    public let methodCode: [CD]?
    
    /// Approach site codes
    public let approachSiteCode: [CD]?
    
    /// Target site codes
    public let targetSiteCode: [CD]?
    
    /// Performers
    public let performer: [Performer]?
    
    /// Authors
    public let author: [Author]?
    
    /// Informants
    public let informant: [Informant]?
    
    /// Participants
    public let participant: [Participant]?
    
    /// Entry relationships
    public let entryRelationship: [EntryRelationship]?
    
    public init(
        moodCode: ActMoodCode = .event,
        negationInd: BL? = nil,
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: IVL<TS>? = nil,
        priorityCode: CD? = nil,
        languageCode: CD? = nil,
        methodCode: [CD]? = nil,
        approachSiteCode: [CD]? = nil,
        targetSiteCode: [CD]? = nil,
        performer: [Performer]? = nil,
        author: [Author]? = nil,
        informant: [Informant]? = nil,
        participant: [Participant]? = nil,
        entryRelationship: [EntryRelationship]? = nil
    ) {
        self.moodCode = moodCode
        self.negationInd = negationInd
        self.id = id
        self.code = code
        self.text = text
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.priorityCode = priorityCode
        self.languageCode = languageCode
        self.methodCode = methodCode
        self.approachSiteCode = approachSiteCode
        self.targetSiteCode = targetSiteCode
        self.performer = performer
        self.author = author
        self.informant = informant
        self.participant = participant
        self.entryRelationship = entryRelationship
    }
}

// MARK: - SubstanceAdministration

/// SubstanceAdministration - Administration of a medication or substance
public struct SubstanceAdministration: Sendable, Codable, Equatable {
    /// Class code (always SBADM for substance administration)
    public let classCode: ActClassCode = .substanceAdministration
    
    /// Mood code (EVN, INT, etc.)
    public let moodCode: ActMoodCode
    
    /// Negation indicator (e.g., medication not taken)
    public let negationInd: BL?
    
    /// Administration identifiers
    public let id: [II]?
    
    /// Administration code
    public let code: CD?
    
    /// Descriptive text
    public let text: ED?
    
    /// Status code
    public let statusCode: ActStatusCode?
    
    /// Administration effective times
    public let effectiveTime: [IVL<TS>]?
    
    /// Priority code
    public let priorityCode: CD?
    
    /// Repeat number
    public let repeatNumber: IVL<INT>?
    
    /// Route code
    public let routeCode: CD?
    
    /// Approach site code
    public let approachSiteCode: [CD]?
    
    /// Dose quantity
    public let doseQuantity: IVL<PQ>?
    
    /// Rate quantity
    public let rateQuantity: IVL<PQ>?
    
    /// Maximum dose quantity
    public let maxDoseQuantity: RTO?
    
    /// Administration unit code
    public let administrationUnitCode: CD?
    
    /// The consumable (medication/substance)
    public let consumable: Consumable
    
    /// Performers
    public let performer: [Performer]?
    
    /// Authors
    public let author: [Author]?
    
    /// Informants
    public let informant: [Informant]?
    
    /// Participants
    public let participant: [Participant]?
    
    /// Entry relationships
    public let entryRelationship: [EntryRelationship]?
    
    /// Preconditions
    public let precondition: [Precondition]?
    
    public init(
        moodCode: ActMoodCode = .event,
        negationInd: BL? = nil,
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: [IVL<TS>]? = nil,
        priorityCode: CD? = nil,
        repeatNumber: IVL<INT>? = nil,
        routeCode: CD? = nil,
        approachSiteCode: [CD]? = nil,
        doseQuantity: IVL<PQ>? = nil,
        rateQuantity: IVL<PQ>? = nil,
        maxDoseQuantity: RTO? = nil,
        administrationUnitCode: CD? = nil,
        consumable: Consumable,
        performer: [Performer]? = nil,
        author: [Author]? = nil,
        informant: [Informant]? = nil,
        participant: [Participant]? = nil,
        entryRelationship: [EntryRelationship]? = nil,
        precondition: [Precondition]? = nil
    ) {
        self.moodCode = moodCode
        self.negationInd = negationInd
        self.id = id
        self.code = code
        self.text = text
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.priorityCode = priorityCode
        self.repeatNumber = repeatNumber
        self.routeCode = routeCode
        self.approachSiteCode = approachSiteCode
        self.doseQuantity = doseQuantity
        self.rateQuantity = rateQuantity
        self.maxDoseQuantity = maxDoseQuantity
        self.administrationUnitCode = administrationUnitCode
        self.consumable = consumable
        self.performer = performer
        self.author = author
        self.informant = informant
        self.participant = participant
        self.entryRelationship = entryRelationship
        self.precondition = precondition
    }
}

// MARK: - RTO (Ratio)

/// RTO - Ratio data type
public struct RTO: Sendable, Codable, Equatable {
    /// Numerator
    public let numerator: PQ
    
    /// Denominator
    public let denominator: PQ
    
    public init(numerator: PQ, denominator: PQ) {
        self.numerator = numerator
        self.denominator = denominator
    }
}

// MARK: - Supporting Types for Entries

/// Consumable - The medication or substance being administered
public struct Consumable: Sendable, Codable, Equatable {
    /// Type code (always CSM for consumable)
    public let typeCode: String = "CSM"
    
    /// The manufactured product
    public let manufacturedProduct: ManufacturedProduct
    
    public init(manufacturedProduct: ManufacturedProduct) {
        self.manufacturedProduct = manufacturedProduct
    }
}

/// ManufacturedProduct - A manufactured medication/substance
public struct ManufacturedProduct: Sendable, Codable, Equatable {
    /// Class code (always MANU for manufactured)
    public let classCode: String = "MANU"
    
    /// Template identifiers
    public let templateId: [II]?
    
    /// Product identifiers
    public let id: [II]?
    
    /// The manufactured material
    public let manufacturedMaterial: ManufacturedMaterial?
    
    /// Manufacturer organization
    public let manufacturerOrganization: Organization?
    
    public init(
        templateId: [II]? = nil,
        id: [II]? = nil,
        manufacturedMaterial: ManufacturedMaterial? = nil,
        manufacturerOrganization: Organization? = nil
    ) {
        self.templateId = templateId
        self.id = id
        self.manufacturedMaterial = manufacturedMaterial
        self.manufacturerOrganization = manufacturerOrganization
    }
}

/// ManufacturedMaterial - Material details
public struct ManufacturedMaterial: Sendable, Codable, Equatable {
    /// Class code (always MMAT for manufactured material)
    public let classCode: String = "MMAT"
    
    /// Determiner code
    public let determinerCode: String = "KIND"
    
    /// Material code (e.g., RxNorm code)
    public let code: CD?
    
    /// Material name
    public let name: EN?
    
    /// Lot number text
    public let lotNumberText: ST?
    
    public init(
        code: CD? = nil,
        name: EN? = nil,
        lotNumberText: ST? = nil
    ) {
        self.code = code
        self.name = name
        self.lotNumberText = lotNumberText
    }
}

/// Supply - A supply of materials or equipment
public struct Supply: Sendable, Codable, Equatable {
    /// Class code (always SPLY for supply)
    public let classCode: ActClassCode = .supply
    
    /// Mood code
    public let moodCode: ActMoodCode
    
    /// Supply identifiers
    public let id: [II]?
    
    /// Supply code
    public let code: CD?
    
    /// Status code
    public let statusCode: ActStatusCode?
    
    /// Effective time
    public let effectiveTime: IVL<TS>?
    
    /// Quantity supplied
    public let quantity: PQ?
    
    /// Performers
    public let performer: [Performer]?
    
    /// Authors
    public let author: [Author]?
    
    /// Product
    public let product: Product?
    
    public init(
        moodCode: ActMoodCode = .event,
        id: [II]? = nil,
        code: CD? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: IVL<TS>? = nil,
        quantity: PQ? = nil,
        performer: [Performer]? = nil,
        author: [Author]? = nil,
        product: Product? = nil
    ) {
        self.moodCode = moodCode
        self.id = id
        self.code = code
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.quantity = quantity
        self.performer = performer
        self.author = author
        self.product = product
    }
}

/// Product - Product being supplied
public struct Product: Sendable, Codable, Equatable {
    /// Type code (always PRD for product)
    public let typeCode: String = "PRD"
    
    /// Manufactured product
    public let manufacturedProduct: ManufacturedProduct
    
    public init(manufacturedProduct: ManufacturedProduct) {
        self.manufacturedProduct = manufacturedProduct
    }
}

/// Encounter - A healthcare encounter
public struct Encounter: Sendable, Codable, Equatable {
    /// Class code (always ENC for encounter)
    public let classCode: ActClassCode = .encounter
    
    /// Mood code
    public let moodCode: ActMoodCode
    
    /// Encounter identifiers
    public let id: [II]?
    
    /// Encounter code
    public let code: CD?
    
    /// Status code
    public let statusCode: ActStatusCode?
    
    /// Effective time
    public let effectiveTime: IVL<TS>?
    
    /// Performers
    public let performer: [Performer]?
    
    /// Participants
    public let participant: [Participant]?
    
    public init(
        moodCode: ActMoodCode = .event,
        id: [II]? = nil,
        code: CD? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: IVL<TS>? = nil,
        performer: [Performer]? = nil,
        participant: [Participant]? = nil
    ) {
        self.moodCode = moodCode
        self.id = id
        self.code = code
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.performer = performer
        self.participant = participant
    }
}

/// ClinicalAct - A generic clinical act
public struct ClinicalAct: Sendable, Codable, Equatable {
    /// Class code
    public let classCode: ActClassCode
    
    /// Mood code
    public let moodCode: ActMoodCode
    
    /// Negation indicator
    public let negationInd: BL?
    
    /// Act identifiers
    public let id: [II]?
    
    /// Act code
    public let code: CD?
    
    /// Descriptive text
    public let text: ED?
    
    /// Status code
    public let statusCode: ActStatusCode?
    
    /// Effective time
    public let effectiveTime: IVL<TS>?
    
    /// Entry relationships
    public let entryRelationship: [EntryRelationship]?
    
    public init(
        classCode: ActClassCode = .act,
        moodCode: ActMoodCode = .event,
        negationInd: BL? = nil,
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: IVL<TS>? = nil,
        entryRelationship: [EntryRelationship]? = nil
    ) {
        self.classCode = classCode
        self.moodCode = moodCode
        self.negationInd = negationInd
        self.id = id
        self.code = code
        self.text = text
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.entryRelationship = entryRelationship
    }
}

/// Organizer - Groups related clinical statements
public struct Organizer: Sendable, Codable, Equatable {
    /// Class code (BATTERY or CLUSTER)
    public let classCode: ActClassCode
    
    /// Mood code
    public let moodCode: ActMoodCode
    
    /// Organizer identifiers
    public let id: [II]?
    
    /// Organizer code
    public let code: CD?
    
    /// Status code
    public let statusCode: ActStatusCode?
    
    /// Effective time
    public let effectiveTime: IVL<TS>?
    
    /// Authors
    public let author: [Author]?
    
    /// Component clinical statements
    public let component: [OrganizerComponent]
    
    public init(
        classCode: ActClassCode = .battery,
        moodCode: ActMoodCode = .event,
        id: [II]? = nil,
        code: CD? = nil,
        statusCode: ActStatusCode? = nil,
        effectiveTime: IVL<TS>? = nil,
        author: [Author]? = nil,
        component: [OrganizerComponent]
    ) {
        self.classCode = classCode
        self.moodCode = moodCode
        self.id = id
        self.code = code
        self.statusCode = statusCode
        self.effectiveTime = effectiveTime
        self.author = author
        self.component = component
    }
}

/// OrganizerComponent - Component of an organizer
public struct OrganizerComponent: Sendable, Codable, Equatable {
    /// Type code (always COMP for component)
    public let typeCode: String = "COMP"
    
    /// Context conduction indicator
    public let contextConductionInd: BL?
    
    /// Sequence number
    public let sequenceNumber: INT?
    
    /// Separator indicator
    public let separatorInd: BL?
    
    /// The clinical statement
    public let clinicalStatement: ClinicalStatement
    
    public init(
        contextConductionInd: BL? = nil,
        sequenceNumber: INT? = nil,
        separatorInd: BL? = nil,
        clinicalStatement: ClinicalStatement
    ) {
        self.contextConductionInd = contextConductionInd
        self.sequenceNumber = sequenceNumber
        self.separatorInd = separatorInd
        self.clinicalStatement = clinicalStatement
    }
}

// MARK: - Participation Types

/// Performer - Who performed an act
public struct Performer: Sendable, Codable, Equatable {
    /// Type code
    public let typeCode: ParticipationTypeCode
    
    /// Time of performance
    public let time: IVL<TS>?
    
    /// Mode of participation
    public let modeCode: CD?
    
    /// Assigned entity
    public let assignedEntity: AssignedEntity
    
    public init(
        typeCode: ParticipationTypeCode = .performer,
        time: IVL<TS>? = nil,
        modeCode: CD? = nil,
        assignedEntity: AssignedEntity
    ) {
        self.typeCode = typeCode
        self.time = time
        self.modeCode = modeCode
        self.assignedEntity = assignedEntity
    }
}

/// Participant - Generic participant in an act
public struct Participant: Sendable, Codable, Equatable {
    /// Type code
    public let typeCode: ParticipationTypeCode
    
    /// Context control code
    public let contextControlCode: String?
    
    /// Time of participation
    public let time: IVL<TS>?
    
    /// Awareness code
    public let awarenessCode: CD?
    
    /// Participant role
    public let participantRole: ParticipantRole
    
    public init(
        typeCode: ParticipationTypeCode,
        contextControlCode: String? = nil,
        time: IVL<TS>? = nil,
        awarenessCode: CD? = nil,
        participantRole: ParticipantRole
    ) {
        self.typeCode = typeCode
        self.contextControlCode = contextControlCode
        self.time = time
        self.awarenessCode = awarenessCode
        self.participantRole = participantRole
    }
}

/// ParticipantRole - Role of a participant
public struct ParticipantRole: Sendable, Codable, Equatable {
    /// Class code
    public let classCode: String
    
    /// Role identifiers
    public let id: [II]?
    
    /// Role code
    public let code: CD?
    
    /// Role addresses
    public let addr: [AD]?
    
    /// Role telecom
    public let telecom: [TEL]?
    
    /// Playing entity
    public let playingEntity: PlayingEntity?
    
    public init(
        classCode: String = "ROL",
        id: [II]? = nil,
        code: CD? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        playingEntity: PlayingEntity? = nil
    ) {
        self.classCode = classCode
        self.id = id
        self.code = code
        self.addr = addr
        self.telecom = telecom
        self.playingEntity = playingEntity
    }
}

/// PlayingEntity - Entity playing a role
public struct PlayingEntity: Sendable, Codable, Equatable {
    /// Class code
    public let classCode: String
    
    /// Entity code
    public let code: CD?
    
    /// Entity quantity
    public let quantity: [PQ]?
    
    /// Entity name
    public let name: [EN]?
    
    /// Entity description
    public let desc: ED?
    
    public init(
        classCode: String = "ENT",
        code: CD? = nil,
        quantity: [PQ]? = nil,
        name: [EN]? = nil,
        desc: ED? = nil
    ) {
        self.classCode = classCode
        self.code = code
        self.quantity = quantity
        self.name = name
        self.desc = desc
    }
}

// MARK: - Entry Relationships

/// EntryRelationship - Relationship between clinical statements
public struct EntryRelationship: Sendable, Codable, Equatable {
    /// Type of relationship
    public let typeCode: EntryRelationshipType
    
    /// Inversion indicator
    public let inversionInd: BL?
    
    /// Context conduction indicator
    public let contextConductionInd: BL?
    
    /// Negation indicator
    public let negationInd: BL?
    
    /// Sequence number
    public let sequenceNumber: INT?
    
    /// Separator indicator
    public let separatorInd: BL?
    
    /// Related clinical statement
    public let clinicalStatement: ClinicalStatement
    
    public init(
        typeCode: EntryRelationshipType,
        inversionInd: BL? = nil,
        contextConductionInd: BL? = nil,
        negationInd: BL? = nil,
        sequenceNumber: INT? = nil,
        separatorInd: BL? = nil,
        clinicalStatement: ClinicalStatement
    ) {
        self.typeCode = typeCode
        self.inversionInd = inversionInd
        self.contextConductionInd = contextConductionInd
        self.negationInd = negationInd
        self.sequenceNumber = sequenceNumber
        self.separatorInd = separatorInd
        self.clinicalStatement = clinicalStatement
    }
}

/// Reference - Reference to external content
public struct Reference: Sendable, Codable, Equatable {
    /// Type code (always REFR for refers to)
    public let typeCode: String = "REFR"
    
    /// Separator indicator
    public let separatorInd: BL?
    
    /// External act
    public let externalAct: ExternalAct?
    
    /// External observation
    public let externalObservation: ExternalObservation?
    
    /// External procedure
    public let externalProcedure: ExternalProcedure?
    
    /// External document
    public let externalDocument: ExternalDocument?
    
    public init(
        separatorInd: BL? = nil,
        externalAct: ExternalAct? = nil,
        externalObservation: ExternalObservation? = nil,
        externalProcedure: ExternalProcedure? = nil,
        externalDocument: ExternalDocument? = nil
    ) {
        self.separatorInd = separatorInd
        self.externalAct = externalAct
        self.externalObservation = externalObservation
        self.externalProcedure = externalProcedure
        self.externalDocument = externalDocument
    }
}

/// ExternalAct - Reference to an external act
public struct ExternalAct: Sendable, Codable, Equatable {
    /// Class code
    public let classCode: ActClassCode
    
    /// Mood code
    public let moodCode: String = "EVN"
    
    /// Act identifiers
    public let id: [II]?
    
    /// Act code
    public let code: CD?
    
    /// Act text
    public let text: ED?
    
    public init(
        classCode: ActClassCode = .act,
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil
    ) {
        self.classCode = classCode
        self.id = id
        self.code = code
        self.text = text
    }
}

/// ExternalObservation - Reference to an external observation
public struct ExternalObservation: Sendable, Codable, Equatable {
    /// Class code (always OBS)
    public let classCode: String = "OBS"
    
    /// Mood code
    public let moodCode: String = "EVN"
    
    /// Observation identifiers
    public let id: [II]?
    
    /// Observation code
    public let code: CD?
    
    /// Observation text
    public let text: ED?
    
    public init(
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil
    ) {
        self.id = id
        self.code = code
        self.text = text
    }
}

/// ExternalProcedure - Reference to an external procedure
public struct ExternalProcedure: Sendable, Codable, Equatable {
    /// Class code (always PROC)
    public let classCode: String = "PROC"
    
    /// Mood code
    public let moodCode: String = "EVN"
    
    /// Procedure identifiers
    public let id: [II]?
    
    /// Procedure code
    public let code: CD?
    
    /// Procedure text
    public let text: ED?
    
    public init(
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil
    ) {
        self.id = id
        self.code = code
        self.text = text
    }
}

/// ExternalDocument - Reference to an external document
public struct ExternalDocument: Sendable, Codable, Equatable {
    /// Class code (always DOC or DOCCLIN)
    public let classCode: String
    
    /// Mood code
    public let moodCode: String = "EVN"
    
    /// Document identifiers
    public let id: [II]?
    
    /// Document code
    public let code: CD?
    
    /// Document text
    public let text: ED?
    
    /// Document set ID
    public let setId: II?
    
    /// Document version number
    public let versionNumber: INT?
    
    public init(
        classCode: String = "DOC",
        id: [II]? = nil,
        code: CD? = nil,
        text: ED? = nil,
        setId: II? = nil,
        versionNumber: INT? = nil
    ) {
        self.classCode = classCode
        self.id = id
        self.code = code
        self.text = text
        self.setId = setId
        self.versionNumber = versionNumber
    }
}

/// Precondition - Condition that must be met
public struct Precondition: Sendable, Codable, Equatable {
    /// Type code (always PRCN for precondition)
    public let typeCode: String = "PRCN"
    
    /// Criterion
    public let criterion: Criterion
    
    public init(criterion: Criterion) {
        self.criterion = criterion
    }
}

/// Criterion - A criterion to be met
public struct Criterion: Sendable, Codable, Equatable {
    /// Class code (always OBS)
    public let classCode: String = "OBS"
    
    /// Mood code (always EVN.CRT for event criterion)
    public let moodCode: String = "EVN.CRT"
    
    /// Criterion code
    public let code: CD?
    
    /// Criterion text
    public let text: ED?
    
    /// Criterion value
    public let value: ObservationValue?
    
    public init(
        code: CD? = nil,
        text: ED? = nil,
        value: ObservationValue? = nil
    ) {
        self.code = code
        self.text = text
        self.value = value
    }
}
