/// FHIRFoundation.swift
/// Base structures for FHIR resources
///
/// This file implements Element, BackboneElement, Resource, and DomainResource
/// See: http://hl7.org/fhir/R4/resource.html

import Foundation
import HL7Core

// MARK: - Element Protocol

/// Base definition for all FHIR elements
public protocol Element: Codable, Sendable {
    /// Unique id for inter-element referencing
    var id: String? { get }
    
    /// Additional content defined by implementations
    var `extension`: [Extension]? { get }
}

// MARK: - BackboneElement Protocol

/// Base definition for backbone elements (nested elements within a resource)
public protocol BackboneElement: Element {
    /// Extensions that cannot be ignored even if unrecognized
    var modifierExtension: [Extension]? { get }
}

// MARK: - Resource Protocol

/// Base definition for all FHIR resources
public protocol Resource: FHIRResource {
    /// Logical id of this artifact
    var id: String? { get }
    
    /// Metadata about the resource
    var meta: Meta? { get }
    
    /// A set of rules under which this content was created
    var implicitRules: String? { get }
    
    /// Language of the resource content
    var language: String? { get }
}

// MARK: - DomainResource Protocol

/// Base for all resources that can contain narrative and extensions
public protocol DomainResource: Resource {
    /// Text summary of the resource, for human interpretation
    var text: Narrative? { get }
    
    /// Contained, inline Resources
    var contained: [ResourceContainer]? { get }
    
    /// Additional content defined by implementations
    var `extension`: [Extension]? { get }
    
    /// Extensions that cannot be ignored
    var modifierExtension: [Extension]? { get }
}

// MARK: - Meta

/// Metadata about a resource
public struct Meta: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Version specific identifier
    public let versionId: String?
    
    /// When the resource version last changed
    public let lastUpdated: String?
    
    /// Identifies where the resource comes from
    public let source: String?
    
    /// Profiles this resource claims to conform to
    public let profile: [String]?
    
    /// Security Labels applied to this resource
    public let security: [Coding]?
    
    /// Tags applied to this resource
    public let tag: [Coding]?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        versionId: String? = nil,
        lastUpdated: String? = nil,
        source: String? = nil,
        profile: [String]? = nil,
        security: [Coding]? = nil,
        tag: [Coding]? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.versionId = versionId
        self.lastUpdated = lastUpdated
        self.source = source
        self.profile = profile
        self.security = security
        self.tag = tag
    }
}

// MARK: - Narrative

/// Human-readable summary of the resource (for human interpretation)
public struct Narrative: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Status of the narrative (generated | extensions | additional | empty)
    public let status: String
    
    /// Limited xhtml content
    public let div: String
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        status: String,
        div: String
    ) {
        self.id = id
        self.extension = `extension`
        self.status = status
        self.div = div
    }
}

// MARK: - ResourceContainer

/// Container for any FHIR resource (used for contained resources)
public enum ResourceContainer: Codable, Sendable {
    case patient(Patient)
    case observation(Observation)
    case practitioner(Practitioner)
    case organization(Organization)
    case condition(Condition)
    case allergyIntolerance(AllergyIntolerance)
    case encounter(Encounter)
    case medicationRequest(MedicationRequest)
    case diagnosticReport(DiagnosticReport)
    case bundle(Bundle)
    case operationOutcome(OperationOutcome)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resourceType = try container.decode(String.self, forKey: .resourceType)
        
        switch resourceType {
        case "Patient":
            self = .patient(try Patient(from: decoder))
        case "Observation":
            self = .observation(try Observation(from: decoder))
        case "Practitioner":
            self = .practitioner(try Practitioner(from: decoder))
        case "Organization":
            self = .organization(try Organization(from: decoder))
        case "Condition":
            self = .condition(try Condition(from: decoder))
        case "AllergyIntolerance":
            self = .allergyIntolerance(try AllergyIntolerance(from: decoder))
        case "Encounter":
            self = .encounter(try Encounter(from: decoder))
        case "MedicationRequest":
            self = .medicationRequest(try MedicationRequest(from: decoder))
        case "DiagnosticReport":
            self = .diagnosticReport(try DiagnosticReport(from: decoder))
        case "Bundle":
            self = .bundle(try Bundle(from: decoder))
        case "OperationOutcome":
            self = .operationOutcome(try OperationOutcome(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .resourceType,
                in: container,
                debugDescription: "Unknown resource type: \(resourceType)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .patient(let resource):
            try resource.encode(to: encoder)
        case .observation(let resource):
            try resource.encode(to: encoder)
        case .practitioner(let resource):
            try resource.encode(to: encoder)
        case .organization(let resource):
            try resource.encode(to: encoder)
        case .condition(let resource):
            try resource.encode(to: encoder)
        case .allergyIntolerance(let resource):
            try resource.encode(to: encoder)
        case .encounter(let resource):
            try resource.encode(to: encoder)
        case .medicationRequest(let resource):
            try resource.encode(to: encoder)
        case .diagnosticReport(let resource):
            try resource.encode(to: encoder)
        case .bundle(let resource):
            try resource.encode(to: encoder)
        case .operationOutcome(let resource):
            try resource.encode(to: encoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case resourceType
    }
}

// MARK: - Patient Contact

/// Contact party for Patient resource
public struct PatientContact: Codable, Sendable, Hashable {
    /// Relationship to the patient
    public let relationship: [CodeableConcept]?
    /// Contact person's name
    public let name: HumanName?
    /// Contact details
    public let telecom: [ContactPoint]?
    /// Address
    public let address: Address?
    /// Gender (male | female | other | unknown)
    public let gender: String?
    /// Organization that is associated with the contact
    public let organization: Reference?
    /// Period during which this contact is valid
    public let period: Period?
    
    public init(
        relationship: [CodeableConcept]? = nil,
        name: HumanName? = nil,
        telecom: [ContactPoint]? = nil,
        address: Address? = nil,
        gender: String? = nil,
        organization: Reference? = nil,
        period: Period? = nil
    ) {
        self.relationship = relationship
        self.name = name
        self.telecom = telecom
        self.address = address
        self.gender = gender
        self.organization = organization
        self.period = period
    }
}

// MARK: - Patient Communication

/// Language communication for Patient resource
public struct PatientCommunication: Codable, Sendable, Hashable {
    /// The language (required)
    public let language: CodeableConcept
    /// Language preference indicator
    public let preferred: Bool?
    
    public init(
        language: CodeableConcept,
        preferred: Bool? = nil
    ) {
        self.language = language
        self.preferred = preferred
    }
}

// MARK: - Observation Supporting Types

/// Reference range for Observation values
public struct ObservationReferenceRange: Codable, Sendable, Hashable {
    /// Low bound of reference range
    public let low: Quantity?
    /// High bound of reference range
    public let high: Quantity?
    /// Reference range qualifier
    public let type: CodeableConcept?
    /// Text based reference range
    public let text: String?
    
    public init(
        low: Quantity? = nil,
        high: Quantity? = nil,
        type: CodeableConcept? = nil,
        text: String? = nil
    ) {
        self.low = low
        self.high = high
        self.type = type
        self.text = text
    }
}

/// Component results for Observation
public struct ObservationComponent: Codable, Sendable, Hashable {
    /// Type of component observation (required)
    public let code: CodeableConcept
    /// Actual component result (value[x])
    public let valueQuantity: Quantity?
    public let valueCodeableConcept: CodeableConcept?
    public let valueString: String?
    /// High, low, normal, etc.
    public let interpretation: [CodeableConcept]?
    /// Provides guide for interpretation of component result
    public let referenceRange: [ObservationReferenceRange]?
    
    public init(
        code: CodeableConcept,
        valueQuantity: Quantity? = nil,
        valueCodeableConcept: CodeableConcept? = nil,
        valueString: String? = nil,
        interpretation: [CodeableConcept]? = nil,
        referenceRange: [ObservationReferenceRange]? = nil
    ) {
        self.code = code
        self.valueQuantity = valueQuantity
        self.valueCodeableConcept = valueCodeableConcept
        self.valueString = valueString
        self.interpretation = interpretation
        self.referenceRange = referenceRange
    }
}

// MARK: - Forward Declarations

/// Patient resource
public struct Patient: DomainResource {
    public let resourceType: String = "Patient"
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
    
    // Patient-specific fields
    public let identifier: [Identifier]?
    public let active: Bool?
    public let name: [HumanName]?
    public let telecom: [ContactPoint]?
    public let gender: String?
    public let birthDate: String?
    public let deceased: Bool?
    public let address: [Address]?
    public let maritalStatus: CodeableConcept?
    public let multipleBirth: Bool?
    public let contact: [PatientContact]?
    public let communication: [PatientCommunication]?
    public let generalPractitioner: [Reference]?
    public let managingOrganization: Reference?
    
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
        gender: String? = nil,
        birthDate: String? = nil,
        deceased: Bool? = nil,
        address: [Address]? = nil,
        maritalStatus: CodeableConcept? = nil,
        multipleBirth: Bool? = nil,
        contact: [PatientContact]? = nil,
        communication: [PatientCommunication]? = nil,
        generalPractitioner: [Reference]? = nil,
        managingOrganization: Reference? = nil
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
        self.gender = gender
        self.birthDate = birthDate
        self.deceased = deceased
        self.address = address
        self.maritalStatus = maritalStatus
        self.multipleBirth = multipleBirth
        self.contact = contact
        self.communication = communication
        self.generalPractitioner = generalPractitioner
        self.managingOrganization = managingOrganization
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
    }
}

/// Observation resource
public struct Observation: DomainResource {
    public let resourceType: String = "Observation"
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
    
    // Observation-specific fields
    public let identifier: [Identifier]?
    public let basedOn: [Reference]?
    public let status: String
    public let category: [CodeableConcept]?
    public let code: CodeableConcept
    public let subject: Reference?
    public let effectiveDateTime: String?
    public let effectivePeriod: Period?
    public let issued: String?
    public let performer: [Reference]?
    public let valueQuantity: Quantity?
    public let valueCodeableConcept: CodeableConcept?
    public let valueString: String?
    public let valueBoolean: Bool?
    public let interpretation: [CodeableConcept]?
    public let note: [Annotation]?
    public let bodySite: CodeableConcept?
    public let method: CodeableConcept?
    public let referenceRange: [ObservationReferenceRange]?
    public let component: [ObservationComponent]?
    
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
        effectiveDateTime: String? = nil,
        effectivePeriod: Period? = nil,
        issued: String? = nil,
        performer: [Reference]? = nil,
        valueQuantity: Quantity? = nil,
        valueCodeableConcept: CodeableConcept? = nil,
        valueString: String? = nil,
        valueBoolean: Bool? = nil,
        interpretation: [CodeableConcept]? = nil,
        note: [Annotation]? = nil,
        bodySite: CodeableConcept? = nil,
        method: CodeableConcept? = nil,
        referenceRange: [ObservationReferenceRange]? = nil,
        component: [ObservationComponent]? = nil
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
        self.effectiveDateTime = effectiveDateTime
        self.effectivePeriod = effectivePeriod
        self.issued = issued
        self.performer = performer
        self.valueQuantity = valueQuantity
        self.valueCodeableConcept = valueCodeableConcept
        self.valueString = valueString
        self.valueBoolean = valueBoolean
        self.interpretation = interpretation
        self.note = note
        self.bodySite = bodySite
        self.method = method
        self.referenceRange = referenceRange
        self.component = component
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
        guard !status.isEmpty else {
            throw HL7Error.validationError("Observation requires status")
        }
    }
}
