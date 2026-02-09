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
    // Add more resource types as needed
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resourceType = try container.decode(String.self, forKey: .resourceType)
        
        switch resourceType {
        case "Patient":
            self = .patient(try Patient(from: decoder))
        case "Observation":
            self = .observation(try Observation(from: decoder))
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
        case .patient(let patient):
            try patient.encode(to: encoder)
        case .observation(let observation):
            try observation.encode(to: encoder)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case resourceType
    }
}

// MARK: - Forward Declarations

/// Patient resource (simplified for now)
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
    
    // Patient-specific fields (minimal for now)
    public let identifier: [Identifier]?
    public let name: [HumanName]?
    public let telecom: [ContactPoint]?
    public let gender: String?
    public let birthDate: String?
    public let address: [Address]?
    
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
        name: [HumanName]? = nil,
        telecom: [ContactPoint]? = nil,
        gender: String? = nil,
        birthDate: String? = nil,
        address: [Address]? = nil
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
        self.name = name
        self.telecom = telecom
        self.gender = gender
        self.birthDate = birthDate
        self.address = address
    }
    
    public func validate() throws {
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
    }
}

/// Observation resource (simplified for now)
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
    
    // Observation-specific fields (minimal for now)
    public let identifier: [Identifier]?
    public let status: String
    public let code: CodeableConcept
    public let subject: Reference?
    
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
        code: CodeableConcept,
        subject: Reference? = nil
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
        self.code = code
        self.subject = subject
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
