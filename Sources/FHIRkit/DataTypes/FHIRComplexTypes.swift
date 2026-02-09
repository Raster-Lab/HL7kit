/// FHIRComplexTypes.swift
/// Complex data types for FHIR R4 specification
///
/// This file implements the complex data types defined in the FHIR specification.
/// See: http://hl7.org/fhir/R4/datatypes.html

import Foundation

// MARK: - Identifier

/// FHIR Identifier type - unique identifier for resources
public struct Identifier: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// The purpose of this identifier (usual | official | temp | secondary | old)
    public let use: String?
    
    /// Description of identifier
    public let type: CodeableConcept?
    
    /// The namespace for the identifier value
    public let system: String?
    
    /// The value that is unique
    public let value: String?
    
    /// Time period when id is/was valid for use
    public let period: Period?
    
    /// Organization that issued id (reference string to avoid circular dependency)
    public let assigner: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        use: String? = nil,
        type: CodeableConcept? = nil,
        system: String? = nil,
        value: String? = nil,
        period: Period? = nil,
        assigner: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.use = use
        self.type = type
        self.system = system
        self.value = value
        self.period = period
        self.assigner = assigner
    }
}

// MARK: - HumanName

/// FHIR HumanName type - person's name
public struct HumanName: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// The purpose of this name (usual | official | temp | nickname | anonymous | old | maiden)
    public let use: String?
    
    /// Text representation of the full name
    public let text: String?
    
    /// Family name (often called 'Surname')
    public let family: String?
    
    /// Given names (not always 'first'). Includes middle names
    public let given: [String]?
    
    /// Parts that come before the name
    public let prefix: [String]?
    
    /// Parts that come after the name
    public let suffix: [String]?
    
    /// Time period when name was/is in use
    public let period: Period?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        use: String? = nil,
        text: String? = nil,
        family: String? = nil,
        given: [String]? = nil,
        prefix: [String]? = nil,
        suffix: [String]? = nil,
        period: Period? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.use = use
        self.text = text
        self.family = family
        self.given = given
        self.prefix = prefix
        self.suffix = suffix
        self.period = period
    }
}

// MARK: - Address

/// FHIR Address type - physical/postal addresses
public struct Address: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// The purpose of this address (home | work | temp | old | billing)
    public let use: String?
    
    /// Distinguishes between physical addresses and postal addresses (postal | physical | both)
    public let type: String?
    
    /// Text representation of the address
    public let text: String?
    
    /// Street name, number, direction & P.O. Box etc.
    public let line: [String]?
    
    /// Name of city, town etc.
    public let city: String?
    
    /// District name (aka county)
    public let district: String?
    
    /// Sub-unit of country (abbreviations ok)
    public let state: String?
    
    /// Postal code for area
    public let postalCode: String?
    
    /// Country (e.g. can be ISO 3166 2 or 3 letter code)
    public let country: String?
    
    /// Time period when address was/is in use
    public let period: Period?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        use: String? = nil,
        type: String? = nil,
        text: String? = nil,
        line: [String]? = nil,
        city: String? = nil,
        district: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        country: String? = nil,
        period: Period? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.use = use
        self.type = type
        self.text = text
        self.line = line
        self.city = city
        self.district = district
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.period = period
    }
}

// MARK: - ContactPoint

/// FHIR ContactPoint type - contact details (phone, email, etc.)
public struct ContactPoint: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Telecommunications form (phone | fax | email | pager | url | sms | other)
    public let system: String?
    
    /// The actual contact point details
    public let value: String?
    
    /// The purpose of this contact point (home | work | temp | old | mobile)
    public let use: String?
    
    /// Specify preferred order of use (1 = highest)
    public let rank: Int32?
    
    /// Time period when the contact point was/is in use
    public let period: Period?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        system: String? = nil,
        value: String? = nil,
        use: String? = nil,
        rank: Int32? = nil,
        period: Period? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.system = system
        self.value = value
        self.use = use
        self.rank = rank
        self.period = period
    }
}

// MARK: - Period

/// FHIR Period type - time period with start and end
public struct Period: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Starting time with inclusive boundary
    public let start: String?
    
    /// End time with inclusive boundary, if not ongoing
    public let end: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        start: String? = nil,
        end: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.start = start
        self.end = end
    }
}

// MARK: - Range

/// FHIR Range type - set of values bounded by low and high
public struct Range: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Low limit
    public let low: Quantity?
    
    /// High limit
    public let high: Quantity?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        low: Quantity? = nil,
        high: Quantity? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.low = low
        self.high = high
    }
}

// MARK: - Quantity

/// FHIR Quantity type - measured or measurable amount
public struct Quantity: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Numerical value (with implicit precision)
    public let value: Decimal?
    
    /// Comparator (< | <= | >= | >)
    public let comparator: String?
    
    /// Unit representation
    public let unit: String?
    
    /// System that defines coded unit form
    public let system: String?
    
    /// Coded form of the unit
    public let code: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        value: Decimal? = nil,
        comparator: String? = nil,
        unit: String? = nil,
        system: String? = nil,
        code: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.value = value
        self.comparator = comparator
        self.unit = unit
        self.system = system
        self.code = code
    }
}

// MARK: - Coding

/// FHIR Coding type - reference to a code in a code system
public struct Coding: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Identity of the terminology system
    public let system: String?
    
    /// Version of the system - if relevant
    public let version: String?
    
    /// Symbol in syntax defined by the system
    public let code: String?
    
    /// Representation defined by the system
    public let display: String?
    
    /// If this coding was chosen directly by the user
    public let userSelected: Bool?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        system: String? = nil,
        version: String? = nil,
        code: String? = nil,
        display: String? = nil,
        userSelected: Bool? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.system = system
        self.version = version
        self.code = code
        self.display = display
        self.userSelected = userSelected
    }
}

// MARK: - CodeableConcept

/// FHIR CodeableConcept type - concept with human-readable text
public struct CodeableConcept: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Code defined by a terminology system
    public let coding: [Coding]?
    
    /// Plain text representation of the concept
    public let text: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        coding: [Coding]? = nil,
        text: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.coding = coding
        self.text = text
    }
}

// MARK: - Reference

/// FHIR Reference type - link to another resource
public struct Reference: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Literal reference, Relative, internal or absolute URL
    public let reference: String?
    
    /// Type the reference refers to (e.g. "Patient")
    public let type: String?
    
    /// Logical reference when literal reference is not known
    public let identifier: Identifier?
    
    /// Text alternative for the resource
    public let display: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        reference: String? = nil,
        type: String? = nil,
        identifier: Identifier? = nil,
        display: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.reference = reference
        self.type = type
        self.identifier = identifier
        self.display = display
    }
}

// MARK: - Annotation

/// FHIR Annotation type - text note with author and time
public struct Annotation: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Individual responsible for the annotation (reference or string)
    public let authorReference: Reference?
    public let authorString: String?
    
    /// When the annotation was made
    public let time: String?
    
    /// The annotation - text content
    public let text: String
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        authorReference: Reference? = nil,
        authorString: String? = nil,
        time: String? = nil,
        text: String
    ) {
        self.id = id
        self.extension = `extension`
        self.authorReference = authorReference
        self.authorString = authorString
        self.time = time
        self.text = text
    }
}

// MARK: - Attachment

/// FHIR Attachment type - content in a format defined elsewhere
public struct Attachment: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Mime type of the content
    public let contentType: String?
    
    /// Human language of the content (BCP-47)
    public let language: String?
    
    /// Data inline, base64ed
    public let data: String?
    
    /// Uri where the data can be found
    public let url: String?
    
    /// Number of bytes of content (if url provided)
    public let size: Int32?
    
    /// Hash of the data (sha-1, base64ed)
    public let hash: String?
    
    /// Label to display in place of the data
    public let title: String?
    
    /// Date attachment was first created
    public let creation: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        contentType: String? = nil,
        language: String? = nil,
        data: String? = nil,
        url: String? = nil,
        size: Int32? = nil,
        hash: String? = nil,
        title: String? = nil,
        creation: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.contentType = contentType
        self.language = language
        self.data = data
        self.url = url
        self.size = size
        self.hash = hash
        self.title = title
        self.creation = creation
    }
}

// MARK: - Signature

/// FHIR Signature type - digital signature
public struct Signature: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Additional information represented in extensions
    public let `extension`: [Extension]?
    
    /// Indication of the reason the entity signed the object(s)
    public let type: [Coding]
    
    /// When the signature was created
    public let when: String
    
    /// Who signed
    public let who: Reference
    
    /// The party represented
    public let onBehalfOf: Reference?
    
    /// The technical format of the signature
    public let targetFormat: String?
    
    /// The technical format of the signed resources
    public let sigFormat: String?
    
    /// The actual signature content (XML DigSig, JWT, etc.)
    public let data: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        type: [Coding],
        when: String,
        who: Reference,
        onBehalfOf: Reference? = nil,
        targetFormat: String? = nil,
        sigFormat: String? = nil,
        data: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.type = type
        self.when = when
        self.who = who
        self.onBehalfOf = onBehalfOf
        self.targetFormat = targetFormat
        self.sigFormat = sigFormat
        self.data = data
    }
}
