/// FHIRPrimitive.swift
/// Primitive data types for FHIR R4 specification
///
/// This file implements the primitive data types defined in the FHIR specification.
/// See: http://hl7.org/fhir/R4/datatypes.html#primitive

import Foundation

// MARK: - FHIRPrimitive Protocol

/// Protocol for FHIR primitive data types
public protocol FHIRPrimitive: Codable, Sendable, Hashable {
    associatedtype Value: Codable, Sendable, Hashable
    
    /// The raw value
    var value: Value { get }
    
    /// Element ID for extensions
    var id: String? { get }
    
    /// Additional information represented in extensions
    var `extension`: [Extension]? { get }
    
    /// Validate the primitive value
    func validate() throws
}

// MARK: - FHIRBoolean

/// FHIR boolean type
public struct FHIRBoolean: FHIRPrimitive {
    public let value: Bool
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: Bool, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Boolean values are always valid
    }
}

// MARK: - FHIRInteger

/// FHIR integer type (32-bit signed integer)
public struct FHIRInteger: FHIRPrimitive {
    public let value: Int32
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: Int32, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Integer values are constrained by the type itself
    }
}

// MARK: - FHIRDecimal

/// FHIR decimal type (arbitrary precision decimal number)
public struct FHIRDecimal: FHIRPrimitive {
    public let value: Decimal
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: Decimal, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        guard !value.isNaN else {
            throw FHIRValidationError.invalidValue("Decimal value cannot be NaN")
        }
    }
}

// MARK: - FHIRString

/// FHIR string type (Unicode character sequence)
public struct FHIRString: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Strings up to 1MB in size are allowed
        guard value.utf8.count <= 1_048_576 else {
            throw FHIRValidationError.invalidValue("String exceeds maximum size of 1MB")
        }
    }
}

// MARK: - FHIRUri

/// FHIR URI type (Uniform Resource Identifier)
public struct FHIRUri: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Basic URI validation
        guard !value.isEmpty else {
            throw FHIRValidationError.invalidValue("URI cannot be empty")
        }
        // URI regex pattern: ^[^\s]+$
        guard !value.contains(where: { $0.isWhitespace }) else {
            throw FHIRValidationError.invalidValue("URI cannot contain whitespace")
        }
    }
}

// MARK: - FHIRUrl

/// FHIR URL type (Uniform Resource Locator, a specific type of URI)
public struct FHIRUrl: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // URL validation - must be a valid URL
        guard !value.isEmpty else {
            throw FHIRValidationError.invalidValue("URL cannot be empty")
        }
        guard URL(string: value) != nil else {
            throw FHIRValidationError.invalidValue("Invalid URL format")
        }
    }
}

// MARK: - FHIRCanonical

/// FHIR canonical type (URI that references a resource by canonical URL)
public struct FHIRCanonical: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Canonical URLs must be absolute URIs
        guard !value.isEmpty else {
            throw FHIRValidationError.invalidValue("Canonical URL cannot be empty")
        }
    }
}

// MARK: - FHIRCode

/// FHIR code type (string from a defined set of codes)
public struct FHIRCode: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Code regex: ^[^\s]+(\s[^\s]+)*$
        guard !value.isEmpty else {
            throw FHIRValidationError.invalidValue("Code cannot be empty")
        }
        guard !value.hasPrefix(" ") && !value.hasSuffix(" ") else {
            throw FHIRValidationError.invalidValue("Code cannot start or end with whitespace")
        }
    }
}

// MARK: - FHIRId

/// FHIR id type (logical resource identifier)
public struct FHIRId: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Id regex: ^[A-Za-z0-9\-\.]{1,64}$
        guard !value.isEmpty && value.count <= 64 else {
            throw FHIRValidationError.invalidValue("Id must be 1-64 characters")
        }
        let validCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-.")
        guard value.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            throw FHIRValidationError.invalidValue("Id contains invalid characters")
        }
    }
}

// MARK: - FHIRMarkdown

/// FHIR markdown type (markdown-formatted text)
public struct FHIRMarkdown: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Markdown strings up to 1MB in size are allowed
        guard value.utf8.count <= 1_048_576 else {
            throw FHIRValidationError.invalidValue("Markdown exceeds maximum size of 1MB")
        }
    }
}

// MARK: - FHIRDate

/// FHIR date type (YYYY-MM-DD)
public struct FHIRDate: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    /// The parsed date components (year, month, day)
    public var dateComponents: DateComponents? {
        Self.parseDateComponents(from: value)
    }
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Date regex: ^([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)?$
        guard Self.isValidDate(value) else {
            throw FHIRValidationError.invalidValue("Invalid date format. Expected YYYY, YYYY-MM, or YYYY-MM-DD")
        }
    }
    
    private static func isValidDate(_ string: String) -> Bool {
        let components = string.split(separator: "-")
        guard (1...3).contains(components.count) else { return false }
        
        // Year
        guard let year = Int(components[0]), year >= 1000, year <= 9999 else { return false }
        
        if components.count >= 2 {
            // Month
            guard let month = Int(components[1]), month >= 1, month <= 12 else { return false }
            
            if components.count == 3 {
                // Day
                guard let day = Int(components[2]), day >= 1, day <= 31 else { return false }
            }
        }
        
        return true
    }
    
    private static func parseDateComponents(from string: String) -> DateComponents? {
        let components = string.split(separator: "-")
        guard (1...3).contains(components.count) else { return nil }
        
        var dateComponents = DateComponents()
        dateComponents.year = Int(components[0])
        
        if components.count >= 2 {
            dateComponents.month = Int(components[1])
        }
        if components.count == 3 {
            dateComponents.day = Int(components[2])
        }
        
        return dateComponents
    }
}

// MARK: - FHIRDateTime

/// FHIR dateTime type (date with optional time and timezone)
public struct FHIRDateTime: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // DateTime format: YYYY-MM-DDThh:mm:ss+zz:zz
        guard !value.isEmpty else {
            throw FHIRValidationError.invalidValue("DateTime cannot be empty")
        }
        // Basic validation - proper parsing would be more complex
        guard value.count >= 4 else {
            throw FHIRValidationError.invalidValue("Invalid DateTime format")
        }
    }
}

// MARK: - FHIRTime

/// FHIR time type (time of day HH:MM:SS)
public struct FHIRTime: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Time regex: ^([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\.[0-9]+)?$
        let components = value.split(separator: ":")
        guard components.count == 3 else {
            throw FHIRValidationError.invalidValue("Time must be in format HH:MM:SS")
        }
        
        guard let hour = Int(components[0]), hour >= 0, hour <= 23 else {
            throw FHIRValidationError.invalidValue("Invalid hour in time")
        }
        guard let minute = Int(components[1]), minute >= 0, minute <= 59 else {
            throw FHIRValidationError.invalidValue("Invalid minute in time")
        }
        
        let secondPart = String(components[2])
        let secondValue = secondPart.split(separator: ".").first.map(String.init) ?? secondPart
        guard let second = Int(secondValue), second >= 0, second <= 60 else {
            throw FHIRValidationError.invalidValue("Invalid second in time")
        }
    }
}

// MARK: - FHIRInstant

/// FHIR instant type (precise timestamp)
public struct FHIRInstant: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // Instant format: YYYY-MM-DDThh:mm:ss.sss+zz:zz (always includes timezone)
        guard !value.isEmpty else {
            throw FHIRValidationError.invalidValue("Instant cannot be empty")
        }
        guard value.contains("T") else {
            throw FHIRValidationError.invalidValue("Instant must include time component")
        }
        guard value.contains("+") || value.contains("Z") || value.contains("-") else {
            throw FHIRValidationError.invalidValue("Instant must include timezone")
        }
    }
}

// MARK: - FHIRBase64Binary

/// FHIR base64Binary type (base64-encoded binary data)
public struct FHIRBase64Binary: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    /// Decoded binary data
    public var data: Data? {
        Data(base64Encoded: value)
    }
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        guard Data(base64Encoded: value) != nil else {
            throw FHIRValidationError.invalidValue("Invalid base64 encoding")
        }
    }
}

// MARK: - FHIRUuid

/// FHIR uuid type (UUID/GUID)
public struct FHIRUuid: FHIRPrimitive {
    public let value: String
    public let id: String?
    public let `extension`: [Extension]?
    
    public init(_ value: String, id: String? = nil, extension: [Extension]? = nil) {
        self.value = value
        self.id = id
        self.extension = `extension`
    }
    
    public init(_ uuid: UUID, id: String? = nil, extension: [Extension]? = nil) {
        self.value = "urn:uuid:\(uuid.uuidString.lowercased())"
        self.id = id
        self.extension = `extension`
    }
    
    public func validate() throws {
        // UUID format: urn:uuid:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
        guard value.hasPrefix("urn:uuid:") else {
            throw FHIRValidationError.invalidValue("UUID must start with 'urn:uuid:'")
        }
        let uuidString = String(value.dropFirst("urn:uuid:".count))
        guard UUID(uuidString: uuidString) != nil else {
            throw FHIRValidationError.invalidValue("Invalid UUID format")
        }
    }
}

// MARK: - Validation Error

/// FHIR validation error
public enum FHIRValidationError: Error, Sendable {
    case invalidValue(String)
    case missingRequiredElement(String)
    case invalidCardinality(String)
}
