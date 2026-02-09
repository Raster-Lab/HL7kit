/// FHIRResources.swift
/// FHIR R4 Resource implementations
///
/// This file implements common FHIR R4 resources including Practitioner, Organization,
/// Condition, AllergyIntolerance, Encounter, MedicationRequest, DiagnosticReport,
/// Bundle, and OperationOutcome.
/// See: http://hl7.org/fhir/R4/resourcelist.html

import Foundation
import HL7Core

// MARK: - Practitioner

/// Qualification for a Practitioner
public struct PractitionerQualification: Codable, Sendable, Hashable {
    /// Identifiers for the qualification
    public let identifier: [Identifier]?
    /// Coded representation of the qualification
    public let code: CodeableConcept
    /// Period during which the qualification is valid
    public let period: Period?
    /// Organization that regulates and issues the qualification
    public let issuer: Reference?
    
    public init(
        identifier: [Identifier]? = nil,
        code: CodeableConcept,
        period: Period? = nil,
        issuer: Reference? = nil
    ) {
        self.identifier = identifier
        self.code = code
        self.period = period
        self.issuer = issuer
    }
}

/// A person with a formal responsibility in the provisioning of healthcare
public struct Practitioner: DomainResource {
    public let resourceType: String = "Practitioner"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// Identifiers for this practitioner
    public let identifier: [Identifier]?
    /// Whether this practitioner's record is in active use
    public let active: Bool?
    /// The name(s) associated with the practitioner
    public let name: [HumanName]?
    /// Contact details for the practitioner
    public let telecom: [ContactPoint]?
    /// Address(es) of the practitioner
    public let address: [Address]?
    /// Gender (male | female | other | unknown)
    public let gender: String?
    /// The date of birth for the practitioner
    public let birthDate: String?
    /// Certifications, licenses, or training
    public let qualification: [PractitionerQualification]?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        active: Bool? = nil,
        name: [HumanName]? = nil,
        telecom: [ContactPoint]? = nil,
        address: [Address]? = nil,
        gender: String? = nil,
        birthDate: String? = nil,
        qualification: [PractitionerQualification]? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.active = active
        self.name = name
        self.telecom = telecom
        self.address = address
        self.gender = gender
        self.birthDate = birthDate
        self.qualification = qualification
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
    }
}

// MARK: - Organization

/// A formally or informally recognized grouping of people or organizations
public struct Organization: DomainResource {
    public let resourceType: String = "Organization"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// Identifiers for the organization
    public let identifier: [Identifier]?
    /// Whether the organization's record is still in active use
    public let active: Bool?
    /// Kind of organization
    public let type: [CodeableConcept]?
    /// Name used for the organization
    public let name: String?
    /// A list of alternate names for the organization
    public let alias: [String]?
    /// Contact details for the organization
    public let telecom: [ContactPoint]?
    /// Address(es) for the organization
    public let address: [Address]?
    /// The organization of which this organization forms a part
    public let partOf: Reference?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        active: Bool? = nil,
        type: [CodeableConcept]? = nil,
        name: String? = nil,
        alias: [String]? = nil,
        telecom: [ContactPoint]? = nil,
        address: [Address]? = nil,
        partOf: Reference? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.active = active
        self.type = type
        self.name = name
        self.alias = alias
        self.telecom = telecom
        self.address = address
        self.partOf = partOf
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
    }
}

// MARK: - Condition

/// A clinical condition, problem, diagnosis, or other event
public struct Condition: DomainResource {
    public let resourceType: String = "Condition"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// External identifiers for this condition
    public let identifier: [Identifier]?
    /// active | recurrence | relapse | inactive | remission | resolved
    public let clinicalStatus: CodeableConcept?
    /// unconfirmed | provisional | differential | confirmed | refuted | entered-in-error
    public let verificationStatus: CodeableConcept?
    /// problem-list-item | encounter-diagnosis
    public let category: [CodeableConcept]?
    /// Subjective severity of condition
    public let severity: CodeableConcept?
    /// Identification of the condition, problem or diagnosis
    public let code: CodeableConcept?
    /// Anatomical location, if relevant
    public let bodySite: [CodeableConcept]?
    /// Who has the condition (required)
    public let subject: Reference
    /// Encounter created as part of
    public let encounter: Reference?
    /// Estimated or actual date/time (onset[x])
    public let onsetDateTime: String?
    /// Estimated or actual date/time (onset[x])
    public let onsetAge: Quantity?
    /// Estimated or actual date/time (onset[x])
    public let onsetPeriod: Period?
    /// When in resolution/remission (abatement[x])
    public let abatementDateTime: String?
    /// Date record was first recorded
    public let recordedDate: String?
    /// Who recorded the condition
    public let recorder: Reference?
    /// Person who asserts this condition
    public let asserter: Reference?
    /// Additional information about the condition
    public let note: [Annotation]?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        clinicalStatus: CodeableConcept? = nil,
        verificationStatus: CodeableConcept? = nil,
        category: [CodeableConcept]? = nil,
        severity: CodeableConcept? = nil,
        code: CodeableConcept? = nil,
        bodySite: [CodeableConcept]? = nil,
        subject: Reference,
        encounter: Reference? = nil,
        onsetDateTime: String? = nil,
        onsetAge: Quantity? = nil,
        onsetPeriod: Period? = nil,
        abatementDateTime: String? = nil,
        recordedDate: String? = nil,
        recorder: Reference? = nil,
        asserter: Reference? = nil,
        note: [Annotation]? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.clinicalStatus = clinicalStatus
        self.verificationStatus = verificationStatus
        self.category = category
        self.severity = severity
        self.code = code
        self.bodySite = bodySite
        self.subject = subject
        self.encounter = encounter
        self.onsetDateTime = onsetDateTime
        self.onsetAge = onsetAge
        self.onsetPeriod = onsetPeriod
        self.abatementDateTime = abatementDateTime
        self.recordedDate = recordedDate
        self.recorder = recorder
        self.asserter = asserter
        self.note = note
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        // subject is required (enforced by non-optional type)
    }
}

// MARK: - AllergyIntolerance

/// Reaction to an allergy or intolerance
public struct AllergyIntoleranceReaction: Codable, Sendable, Hashable {
    /// Specific substance or pharmaceutical product considered to be responsible for event
    public let substance: CodeableConcept?
    /// Clinical symptoms/signs associated with the event (required)
    public let manifestation: [CodeableConcept]
    /// Description of the event as a whole
    public let description_: String?
    /// Date(/time) when manifestations showed
    public let onset: String?
    /// Severity (mild | moderate | severe)
    public let severity: String?
    /// How the subject was exposed to the substance
    public let exposureRoute: CodeableConcept?
    /// Text about event not captured in other fields
    public let note: [Annotation]?
    
    enum CodingKeys: String, CodingKey {
        case substance, manifestation
        case description_ = "description"
        case onset, severity, exposureRoute, note
    }
    
    public init(
        substance: CodeableConcept? = nil,
        manifestation: [CodeableConcept],
        description_: String? = nil,
        onset: String? = nil,
        severity: String? = nil,
        exposureRoute: CodeableConcept? = nil,
        note: [Annotation]? = nil
    ) {
        self.substance = substance
        self.manifestation = manifestation
        self.description_ = description_
        self.onset = onset
        self.severity = severity
        self.exposureRoute = exposureRoute
        self.note = note
    }
}

/// Risk of harmful or undesirable physiological response
public struct AllergyIntolerance: DomainResource {
    public let resourceType: String = "AllergyIntolerance"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// External identifiers for the allergy
    public let identifier: [Identifier]?
    /// active | inactive | resolved
    public let clinicalStatus: CodeableConcept?
    /// unconfirmed | confirmed | refuted | entered-in-error
    public let verificationStatus: CodeableConcept?
    /// allergy | intolerance
    public let type: String?
    /// food | medication | environment | biologic
    public let category: [String]?
    /// low | high | unable-to-assess
    public let criticality: String?
    /// Code that identifies the allergy or intolerance
    public let code: CodeableConcept?
    /// Who the sensitivity is for (required)
    public let patient: Reference
    /// Encounter when the allergy or intolerance was asserted
    public let encounter: Reference?
    /// When allergy or intolerance was identified (onset[x])
    public let onsetDateTime: String?
    /// Date first version of the resource instance was recorded
    public let recordedDate: String?
    /// Who recorded the sensitivity
    public let recorder: Reference?
    /// Source of the information about the allergy
    public let asserter: Reference?
    /// Date(/time) of last known occurrence of a reaction
    public let lastOccurrence: String?
    /// Additional text not captured in other fields
    public let note: [Annotation]?
    /// Adverse reaction events linked to exposure to substance
    public let reaction: [AllergyIntoleranceReaction]?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        clinicalStatus: CodeableConcept? = nil,
        verificationStatus: CodeableConcept? = nil,
        type: String? = nil,
        category: [String]? = nil,
        criticality: String? = nil,
        code: CodeableConcept? = nil,
        patient: Reference,
        encounter: Reference? = nil,
        onsetDateTime: String? = nil,
        recordedDate: String? = nil,
        recorder: Reference? = nil,
        asserter: Reference? = nil,
        lastOccurrence: String? = nil,
        note: [Annotation]? = nil,
        reaction: [AllergyIntoleranceReaction]? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.clinicalStatus = clinicalStatus
        self.verificationStatus = verificationStatus
        self.type = type
        self.category = category
        self.criticality = criticality
        self.code = code
        self.patient = patient
        self.encounter = encounter
        self.onsetDateTime = onsetDateTime
        self.recordedDate = recordedDate
        self.recorder = recorder
        self.asserter = asserter
        self.lastOccurrence = lastOccurrence
        self.note = note
        self.reaction = reaction
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        // patient is required (enforced by non-optional type)
    }
}

// MARK: - Encounter

/// Status history for Encounter
public struct EncounterStatusHistory: Codable, Sendable, Hashable {
    /// planned | arrived | triaged | in-progress | onleave | finished | cancelled | entered-in-error | unknown
    public let status: String
    /// The time that the episode was in the specified status
    public let period: Period
    
    public init(status: String, period: Period) {
        self.status = status
        self.period = period
    }
}

/// Participant involved in the encounter
public struct EncounterParticipant: Codable, Sendable, Hashable {
    /// Role of participant in encounter
    public let type: [CodeableConcept]?
    /// Period of time during the encounter that the participant participated
    public let period: Period?
    /// Persons involved in the encounter other than the patient
    public let individual: Reference?
    
    public init(
        type: [CodeableConcept]? = nil,
        period: Period? = nil,
        individual: Reference? = nil
    ) {
        self.type = type
        self.period = period
        self.individual = individual
    }
}

/// Details about the admission to a healthcare service
public struct EncounterHospitalization: Codable, Sendable, Hashable {
    /// Pre-admission identifier
    public let preAdmissionIdentifier: Identifier?
    /// The location/organization from which the patient came before admission
    public let origin: Reference?
    /// From where patient was admitted (physician referral, transfer)
    public let admitSource: CodeableConcept?
    /// Category or kind of location after discharge
    public let dischargeDisposition: CodeableConcept?
    /// Location/organization to which the patient is discharged
    public let destination: Reference?
    
    public init(
        preAdmissionIdentifier: Identifier? = nil,
        origin: Reference? = nil,
        admitSource: CodeableConcept? = nil,
        dischargeDisposition: CodeableConcept? = nil,
        destination: Reference? = nil
    ) {
        self.preAdmissionIdentifier = preAdmissionIdentifier
        self.origin = origin
        self.admitSource = admitSource
        self.dischargeDisposition = dischargeDisposition
        self.destination = destination
    }
}

/// Location involved in the encounter
public struct EncounterLocation: Codable, Sendable, Hashable {
    /// Location the encounter takes place
    public let location: Reference
    /// planned | active | reserved | completed
    public let status: String?
    /// Time period during which the patient was present at the location
    public let period: Period?
    
    public init(
        location: Reference,
        status: String? = nil,
        period: Period? = nil
    ) {
        self.location = location
        self.status = status
        self.period = period
    }
}

/// An interaction during which services are provided to the patient
public struct Encounter: DomainResource {
    public let resourceType: String = "Encounter"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// Identifiers for the encounter
    public let identifier: [Identifier]?
    /// Status of the encounter (required)
    public let status: String
    /// List of past encounter statuses
    public let statusHistory: [EncounterStatusHistory]?
    /// Classification of patient encounter (required)
    public let class_: Coding
    /// Specific type of encounter
    public let type: [CodeableConcept]?
    /// Specific type of service
    public let serviceType: CodeableConcept?
    /// Indicates the urgency of the encounter
    public let priority: CodeableConcept?
    /// The patient or group present at the encounter
    public let subject: Reference?
    /// List of participants involved in the encounter
    public let participant: [EncounterParticipant]?
    /// The start and end time of the encounter
    public let period: Period?
    /// Coded reason the encounter takes place
    public let reasonCode: [CodeableConcept]?
    /// Reason the encounter takes place (reference)
    public let reasonReference: [Reference]?
    /// Details about the admission to a healthcare service
    public let hospitalization: EncounterHospitalization?
    /// List of locations where the patient has been
    public let location: [EncounterLocation]?
    /// The organization (facility) responsible for this encounter
    public let serviceProvider: Reference?
    
    enum CodingKeys: String, CodingKey {
        case resourceType, messageID, timestamp, id, meta, implicitRules, language
        case text, contained, modifierExtension
        case `extension`
        case identifier, status, statusHistory
        case class_ = "class"
        case type, serviceType, priority, subject, participant, period
        case reasonCode, reasonReference, hospitalization, location, serviceProvider
    }
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        status: String,
        statusHistory: [EncounterStatusHistory]? = nil,
        class_: Coding,
        type: [CodeableConcept]? = nil,
        serviceType: CodeableConcept? = nil,
        priority: CodeableConcept? = nil,
        subject: Reference? = nil,
        participant: [EncounterParticipant]? = nil,
        period: Period? = nil,
        reasonCode: [CodeableConcept]? = nil,
        reasonReference: [Reference]? = nil,
        hospitalization: EncounterHospitalization? = nil,
        location: [EncounterLocation]? = nil,
        serviceProvider: Reference? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.status = status
        self.statusHistory = statusHistory
        self.class_ = class_
        self.type = type
        self.serviceType = serviceType
        self.priority = priority
        self.subject = subject
        self.participant = participant
        self.period = period
        self.reasonCode = reasonCode
        self.reasonReference = reasonReference
        self.hospitalization = hospitalization
        self.location = location
        self.serviceProvider = serviceProvider
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        guard !status.isEmpty else {
            throw HL7Error.validationError("Encounter requires status")
        }
        // class_ is required (enforced by non-optional type)
    }
}

// MARK: - MedicationRequest

/// Dosage instructions for MedicationRequest
public struct DosageInstruction: Codable, Sendable, Hashable {
    /// The order of the dosage instructions
    public let sequence: Int32?
    /// Free text dosage instructions
    public let text: String?
    /// When medication should be administered
    public let timing: String?
    /// How drug should enter body
    public let route: CodeableConcept?
    /// Amount of medication per dose
    public let doseQuantity: Quantity?
    
    public init(
        sequence: Int32? = nil,
        text: String? = nil,
        timing: String? = nil,
        route: CodeableConcept? = nil,
        doseQuantity: Quantity? = nil
    ) {
        self.sequence = sequence
        self.text = text
        self.timing = timing
        self.route = route
        self.doseQuantity = doseQuantity
    }
}

/// An order or request for a medication
public struct MedicationRequest: DomainResource {
    public let resourceType: String = "MedicationRequest"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// External identifiers for the medication request
    public let identifier: [Identifier]?
    /// Status of the prescription (required)
    public let status: String
    /// Reason for current status
    public let statusReason: CodeableConcept?
    /// Type of medication usage (required)
    public let intent: String
    /// Type of medication request
    public let category: [CodeableConcept]?
    /// routine | urgent | asap | stat
    public let priority: String?
    /// Medication to be taken (CodeableConcept choice)
    public let medicationCodeableConcept: CodeableConcept?
    /// Medication to be taken (Reference choice)
    public let medicationReference: Reference?
    /// Who the prescription is for (required)
    public let subject: Reference
    /// Encounter created as part of
    public let encounter: Reference?
    /// When request was initially authored
    public let authoredOn: String?
    /// Who/What requested the request
    public let requester: Reference?
    /// Reason or indication for ordering or not ordering the medication
    public let reasonCode: [CodeableConcept]?
    /// Condition or observation that supports why the medication was ordered
    public let reasonReference: [Reference]?
    /// Information about the prescription
    public let note: [Annotation]?
    /// How the medication should be taken
    public let dosageInstruction: [DosageInstruction]?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        status: String,
        statusReason: CodeableConcept? = nil,
        intent: String,
        category: [CodeableConcept]? = nil,
        priority: String? = nil,
        medicationCodeableConcept: CodeableConcept? = nil,
        medicationReference: Reference? = nil,
        subject: Reference,
        encounter: Reference? = nil,
        authoredOn: String? = nil,
        requester: Reference? = nil,
        reasonCode: [CodeableConcept]? = nil,
        reasonReference: [Reference]? = nil,
        note: [Annotation]? = nil,
        dosageInstruction: [DosageInstruction]? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.status = status
        self.statusReason = statusReason
        self.intent = intent
        self.category = category
        self.priority = priority
        self.medicationCodeableConcept = medicationCodeableConcept
        self.medicationReference = medicationReference
        self.subject = subject
        self.encounter = encounter
        self.authoredOn = authoredOn
        self.requester = requester
        self.reasonCode = reasonCode
        self.reasonReference = reasonReference
        self.note = note
        self.dosageInstruction = dosageInstruction
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        guard !status.isEmpty else {
            throw HL7Error.validationError("MedicationRequest requires status")
        }
        guard !intent.isEmpty else {
            throw HL7Error.validationError("MedicationRequest requires intent")
        }
        // subject is required (enforced by non-optional type)
    }
}

// MARK: - DiagnosticReport

/// The findings and interpretation of diagnostic tests
public struct DiagnosticReport: DomainResource {
    public let resourceType: String = "DiagnosticReport"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// Business identifier for report
    public let identifier: [Identifier]?
    /// What was requested
    public let basedOn: [Reference]?
    /// Status of the diagnostic report (required)
    public let status: String
    /// Service category
    public let category: [CodeableConcept]?
    /// Name/Code for this diagnostic report (required)
    public let code: CodeableConcept
    /// The subject of the report
    public let subject: Reference?
    /// Health care event when test ordered
    public let encounter: Reference?
    /// Clinically relevant time/time-period for report (dateTime choice)
    public let effectiveDateTime: String?
    /// Clinically relevant time/time-period for report (Period choice)
    public let effectivePeriod: Period?
    /// DateTime this version was made
    public let issued: String?
    /// Responsible diagnostic service
    public let performer: [Reference]?
    /// Observations
    public let result: [Reference]?
    /// Clinical conclusion
    public let conclusion: String?
    /// Codes for the clinical conclusion
    public let conclusionCode: [CodeableConcept]?
    /// Entire report as issued
    public let presentedForm: [Attachment]?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        identifier: [Identifier]? = nil,
        basedOn: [Reference]? = nil,
        status: String,
        category: [CodeableConcept]? = nil,
        code: CodeableConcept,
        subject: Reference? = nil,
        encounter: Reference? = nil,
        effectiveDateTime: String? = nil,
        effectivePeriod: Period? = nil,
        issued: String? = nil,
        performer: [Reference]? = nil,
        result: [Reference]? = nil,
        conclusion: String? = nil,
        conclusionCode: [CodeableConcept]? = nil,
        presentedForm: [Attachment]? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.identifier = identifier
        self.basedOn = basedOn
        self.status = status
        self.category = category
        self.code = code
        self.subject = subject
        self.encounter = encounter
        self.effectiveDateTime = effectiveDateTime
        self.effectivePeriod = effectivePeriod
        self.issued = issued
        self.performer = performer
        self.result = result
        self.conclusion = conclusion
        self.conclusionCode = conclusionCode
        self.presentedForm = presentedForm
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        guard !status.isEmpty else {
            throw HL7Error.validationError("DiagnosticReport requires status")
        }
        // code is required (enforced by non-optional type)
    }
}

// MARK: - Bundle

/// Link in a Bundle
public struct BundleLink: Codable, Sendable, Hashable {
    /// See http://www.iana.org/assignments/link-relations/link-relations.xhtml#link-relations-1
    public let relation: String
    /// Reference details for the link
    public let url: String
    
    public init(relation: String, url: String) {
        self.relation = relation
        self.url = url
    }
}

/// Search information for a Bundle entry
public struct BundleEntrySearch: Codable, Sendable, Hashable {
    /// match | include | outcome
    public let mode: String?
    /// Search ranking (between 0 and 1)
    public let score: Decimal?
    
    public init(mode: String? = nil, score: Decimal? = nil) {
        self.mode = mode
        self.score = score
    }
}

/// Request information for a Bundle entry
public struct BundleEntryRequest: Codable, Sendable, Hashable {
    /// GET | HEAD | POST | PUT | DELETE | PATCH
    public let method: String
    /// URL for HTTP equivalent of this entry
    public let url: String
    
    public init(method: String, url: String) {
        self.method = method
        self.url = url
    }
}

/// Response information for a Bundle entry
public struct BundleEntryResponse: Codable, Sendable, Hashable {
    /// Status response code
    public let status: String
    /// The location (if the operation returns a location)
    public let location: String?
    /// The Etag for the resource
    public let etag: String?
    /// Server's date time modified
    public let lastModified: String?
    
    public init(
        status: String,
        location: String? = nil,
        etag: String? = nil,
        lastModified: String? = nil
    ) {
        self.status = status
        self.location = location
        self.etag = etag
        self.lastModified = lastModified
    }
}

/// Entry in a Bundle
public struct BundleEntry: Codable, Sendable {
    /// URI for resource (Absolute URL server address or URI for UUID/OID)
    public let fullUrl: String?
    /// A resource in the bundle
    public let resource: ResourceContainer?
    /// Search related information
    public let search: BundleEntrySearch?
    /// Additional execution information (transaction/batch/history)
    public let request: BundleEntryRequest?
    /// Results of execution (transaction/batch/history)
    public let response: BundleEntryResponse?
    
    public init(
        fullUrl: String? = nil,
        resource: ResourceContainer? = nil,
        search: BundleEntrySearch? = nil,
        request: BundleEntryRequest? = nil,
        response: BundleEntryResponse? = nil
    ) {
        self.fullUrl = fullUrl
        self.resource = resource
        self.search = search
        self.request = request
        self.response = response
    }
}

/// A container for a collection of resources
public struct Bundle: Resource {
    public let resourceType: String = "Bundle"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    
    /// Persistent identifier for the bundle
    public let identifier: Identifier?
    /// document | message | transaction | transaction-response | batch | batch-response | history | searchset | collection (required)
    public let type: String
    /// If search, the total number of matches
    public let total: Int32?
    /// Links related to this Bundle
    public let link: [BundleLink]?
    /// Entry in the bundle
    public let entry: [BundleEntry]?
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        identifier: Identifier? = nil,
        type: String,
        total: Int32? = nil,
        link: [BundleLink]? = nil,
        entry: [BundleEntry]? = nil
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.identifier = identifier
        self.type = type
        self.total = total
        self.link = link
        self.entry = entry
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        guard !type.isEmpty else {
            throw HL7Error.validationError("Bundle requires type")
        }
    }
}

// MARK: - OperationOutcome

/// Issue in an OperationOutcome
public struct OperationOutcomeIssue: Codable, Sendable, Hashable {
    /// Severity of the issue (required: fatal | error | warning | information)
    public let severity: String
    /// Error or warning code (required)
    public let code: String
    /// Additional details about the error
    public let details: CodeableConcept?
    /// Additional diagnostic information about the issue
    public let diagnostics: String?
    /// Deprecated: Path of element(s) related to issue
    public let location: [String]?
    /// FHIRPath of element(s) related to issue
    public let expression: [String]?
    
    public init(
        severity: String,
        code: String,
        details: CodeableConcept? = nil,
        diagnostics: String? = nil,
        location: [String]? = nil,
        expression: [String]? = nil
    ) {
        self.severity = severity
        self.code = code
        self.details = details
        self.diagnostics = diagnostics
        self.location = location
        self.expression = expression
    }
}

/// A collection of error, warning, or information messages
public struct OperationOutcome: DomainResource {
    public let resourceType: String = "OperationOutcome"
    public let messageID: String
    public let timestamp: Date
    public let id: String?
    public let meta: Meta?
    public let implicitRules: String?
    public let language: String?
    public let text: Narrative?
    public let contained: [ResourceContainer]?
    public let `extension`: [Extension]?
    public let modifierExtension: [Extension]?
    
    /// A single issue associated with the action (required, at least one)
    public let issue: [OperationOutcomeIssue]
    
    public init(
        messageID: String = UUID().uuidString,
        timestamp: Date = Date(),
        id: String? = nil,
        meta: Meta? = nil,
        implicitRules: String? = nil,
        language: String? = nil,
        text: Narrative? = nil,
        contained: [ResourceContainer]? = nil,
        extension: [Extension]? = nil,
        modifierExtension: [Extension]? = nil,
        issue: [OperationOutcomeIssue]
    ) {
        self.messageID = messageID
        self.timestamp = timestamp
        self.id = id
        self.meta = meta
        self.implicitRules = implicitRules
        self.language = language
        self.text = text
        self.contained = contained
        self.extension = `extension`
        self.modifierExtension = modifierExtension
        self.issue = issue
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        guard !issue.isEmpty else {
            throw HL7Error.validationError("OperationOutcome requires at least one issue")
        }
        for issueItem in issue {
            guard !issueItem.severity.isEmpty else {
                throw HL7Error.validationError("OperationOutcome issue requires severity")
            }
            guard !issueItem.code.isEmpty else {
                throw HL7Error.validationError("OperationOutcome issue requires code")
            }
        }
    }
}
