/// FHIRkit - HL7 FHIR resource handling toolkit
///
/// This module provides FHIR resource modeling, RESTful client functionality,
/// and support for FHIR R4 and R5 specifications.

import Foundation
import HL7Core

// MARK: - Version

/// Version information for FHIRkit
public struct FHIRkitVersion {
    /// The current version of FHIRkit
    public static let version = "0.1.0"
    
    /// Supported FHIR version
    public static let fhirVersion = "4.0.1"
}

// MARK: - FHIR Resource Protocol

/// FHIR resource base protocol
public protocol FHIRResource: HL7Message, Codable {
    /// Resource type (e.g., "Patient", "Observation")
    var resourceType: String { get }
    
    /// Resource ID
    var id: String? { get }
}

// MARK: - Basic Resource (for backward compatibility)

/// Basic FHIR resource implementation (legacy support)
public struct FHIRBasicResource: FHIRResource {
    public let resourceType: String
    public let id: String?
    public let messageID: String
    public let timestamp: Date
    
    public init(resourceType: String, id: String? = nil, messageID: String, timestamp: Date = Date()) {
        self.resourceType = resourceType
        self.id = id
        self.messageID = messageID
        self.timestamp = timestamp
    }
    
    public func validate() throws {
        // Basic validation - will be expanded in future phases
        guard !resourceType.isEmpty else {
            throw HL7Error.validationError("Empty resource type")
        }
    }
}
