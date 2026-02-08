/// RIMDataTypes.swift
/// HL7 v3 Reference Information Model Data Types
///
/// This file implements the core HL7 v3 data types as specified in the
/// HL7 Version 3 Data Types Abstract Specification.

import Foundation
import HL7Core

// MARK: - Null Flavor

/// Represents exceptional values for data types
public enum NullFlavor: String, Sendable, Codable {
    /// No information (value not provided)
    case noInformation = "NI"
    
    /// Not applicable (value doesn't apply in this context)
    case notApplicable = "NA"
    
    /// Unknown (value exists but is unknown)
    case unknown = "UNK"
    
    /// Asked but unknown (information was sought but not found)
    case askedButUnknown = "ASKU"
    
    /// Temporarily unavailable (not available at this time)
    case temporarilyUnavailable = "NAV"
    
    /// Not asked (information was not sought)
    case notAsked = "NASK"
    
    /// Masked (value exists but not disclosed for privacy)
    case masked = "MSK"
    
    /// Other (description in originalText)
    case other = "OTH"
}

// MARK: - Boolean (BL)

/// Boolean data type - represents true/false values
public enum BL: Sendable, Codable, Equatable {
    case value(Bool)
    case nullFlavor(NullFlavor)
    
    public var boolValue: Bool? {
        if case .value(let bool) = self {
            return bool
        }
        return nil
    }
    
    public static func == (lhs: BL, rhs: BL) -> Bool {
        switch (lhs, rhs) {
        case (.value(let a), .value(let b)):
            return a == b
        case (.nullFlavor(let a), .nullFlavor(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Integer (INT)

/// Integer data type - represents whole numbers
public enum INT: Sendable, Codable, Equatable {
    case value(Int)
    case nullFlavor(NullFlavor)
    
    public var intValue: Int? {
        if case .value(let int) = self {
            return int
        }
        return nil
    }
}

// MARK: - Real (REAL)

/// Real data type - represents decimal numbers
public enum REAL: Sendable, Codable, Equatable {
    case value(Double)
    case nullFlavor(NullFlavor)
    
    public var doubleValue: Double? {
        if case .value(let double) = self {
            return double
        }
        return nil
    }
}

// MARK: - String (ST)

/// Character string data type
public enum ST: Sendable, Codable, Equatable {
    case value(String)
    case nullFlavor(NullFlavor)
    
    public var stringValue: String? {
        if case .value(let string) = self {
            return string
        }
        return nil
    }
}

// MARK: - Instance Identifier (II)

/// Instance Identifier - uniquely identifies an instance
public struct II: Sendable, Codable, Equatable {
    /// OID or UUID identifying the assigning authority
    public let root: String
    
    /// Optional local identifier within the authority
    public let `extension`: String?
    
    /// Optional human-readable name
    public let assigningAuthorityName: String?
    
    /// Null flavor if identifier is not available
    public let nullFlavor: NullFlavor?
    
    public init(
        root: String,
        extension: String? = nil,
        assigningAuthorityName: String? = nil,
        nullFlavor: NullFlavor? = nil
    ) {
        self.root = root
        self.extension = `extension`
        self.assigningAuthorityName = assigningAuthorityName
        self.nullFlavor = nullFlavor
    }
    
    /// Creates a null-flavored identifier
    public init(nullFlavor: NullFlavor) {
        self.root = ""
        self.extension = nil
        self.assigningAuthorityName = nil
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Timestamp (TS)

/// Point in time data type
public struct TS: Sendable, Codable, Equatable {
    /// The actual timestamp
    public let value: Date?
    
    /// Precision of the timestamp
    public let precision: Precision
    
    /// Null flavor if timestamp is not available
    public let nullFlavor: NullFlavor?
    
    public enum Precision: String, Sendable, Codable {
        case year = "Y"
        case month = "M"
        case day = "D"
        case hour = "H"
        case minute = "MIN"
        case second = "S"
        case millisecond = "MS"
    }
    
    public init(value: Date, precision: Precision = .second) {
        self.value = value
        self.precision = precision
        self.nullFlavor = nil
    }
    
    public init(nullFlavor: NullFlavor) {
        self.value = nil
        self.precision = .second
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Coded Value (CD)

/// Concept Descriptor - comprehensive coded value
public struct CD: Sendable, Codable, Equatable {
    /// The primary code value
    public let code: String?
    
    /// OID of the code system
    public let codeSystem: String?
    
    /// Human-readable code system name
    public let codeSystemName: String?
    
    /// Version of the code system
    public let codeSystemVersion: String?
    
    /// Human-readable display name
    public let displayName: String?
    
    /// Original text the code represents
    public let originalText: String?
    
    /// Alternative codes from other vocabularies
    public let translations: [CD]?
    
    /// Null flavor if code is not available
    public let nullFlavor: NullFlavor?
    
    public init(
        code: String? = nil,
        codeSystem: String? = nil,
        codeSystemName: String? = nil,
        codeSystemVersion: String? = nil,
        displayName: String? = nil,
        originalText: String? = nil,
        translations: [CD]? = nil,
        nullFlavor: NullFlavor? = nil
    ) {
        self.code = code
        self.codeSystem = codeSystem
        self.codeSystemName = codeSystemName
        self.codeSystemVersion = codeSystemVersion
        self.displayName = displayName
        self.originalText = originalText
        self.translations = translations
        self.nullFlavor = nullFlavor
    }
    
    /// Creates a null-flavored code
    public init(nullFlavor: NullFlavor) {
        self.code = nil
        self.codeSystem = nil
        self.codeSystemName = nil
        self.codeSystemVersion = nil
        self.displayName = nil
        self.originalText = nil
        self.translations = nil
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Coded With Equivalents (CE)

/// Simplified coded value with translations
public typealias CE = CD

// MARK: - Interval (IVL)

/// Interval between two values
public struct IVL<T: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    /// Lower bound of the interval
    public let low: T?
    
    /// Upper bound of the interval
    public let high: T?
    
    /// Width/duration of the interval
    public let width: T?
    
    /// Center point of the interval
    public let center: T?
    
    /// Null flavor if interval is not available
    public let nullFlavor: NullFlavor?
    
    public init(
        low: T? = nil,
        high: T? = nil,
        width: T? = nil,
        center: T? = nil,
        nullFlavor: NullFlavor? = nil
    ) {
        self.low = low
        self.high = high
        self.width = width
        self.center = center
        self.nullFlavor = nullFlavor
    }
    
    public init(nullFlavor: NullFlavor) {
        self.low = nil
        self.high = nil
        self.width = nil
        self.center = nil
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Physical Quantity (PQ)

/// Physical quantity with units
public struct PQ: Sendable, Codable, Equatable {
    /// The numeric value
    public let value: Double?
    
    /// Unit of measure (UCUM code)
    public let unit: String?
    
    /// Null flavor if quantity is not available
    public let nullFlavor: NullFlavor?
    
    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
        self.nullFlavor = nil
    }
    
    public init(nullFlavor: NullFlavor) {
        self.value = nil
        self.unit = nil
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Entity Name (EN)

/// Entity name (person or organization)
public struct EN: Sendable, Codable, Equatable {
    /// Name parts (family, given, prefix, suffix)
    public let parts: [NamePart]
    
    /// Name usage (legal, maiden, alias, etc.)
    public let use: NameUse?
    
    /// When the name is valid
    public let validTime: IVL<TS>?
    
    /// Null flavor if name is not available
    public let nullFlavor: NullFlavor?
    
    public struct NamePart: Sendable, Codable, Equatable {
        public let value: String
        public let type: PartType
        
        public enum PartType: String, Sendable, Codable {
            case family = "FAM"
            case given = "GIV"
            case prefix = "PFX"
            case suffix = "SFX"
        }
        
        public init(value: String, type: PartType) {
            self.value = value
            self.type = type
        }
    }
    
    public enum NameUse: String, Sendable, Codable {
        case legal = "L"
        case official = "OR"
        case maiden = "M"
        case nickname = "P"
        case alias = "A"
        case anonymous = "ANON"
        case temp = "TEMP"
    }
    
    public init(
        parts: [NamePart],
        use: NameUse? = nil,
        validTime: IVL<TS>? = nil,
        nullFlavor: NullFlavor? = nil
    ) {
        self.parts = parts
        self.use = use
        self.validTime = validTime
        self.nullFlavor = nullFlavor
    }
    
    public init(nullFlavor: NullFlavor) {
        self.parts = []
        self.use = nil
        self.validTime = nil
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Address (AD)

/// Postal or physical address
public struct AD: Sendable, Codable, Equatable {
    /// Address parts (street, city, state, postal code, country)
    public let parts: [AddressPart]
    
    /// Address usage (home, work, etc.)
    public let use: AddressUse?
    
    /// When the address is valid
    public let validTime: IVL<TS>?
    
    /// Null flavor if address is not available
    public let nullFlavor: NullFlavor?
    
    public struct AddressPart: Sendable, Codable, Equatable {
        public let value: String
        public let type: PartType
        
        public enum PartType: String, Sendable, Codable {
            case streetAddressLine = "SAL"
            case city = "CTY"
            case state = "STA"
            case postalCode = "ZIP"
            case country = "CNT"
        }
        
        public init(value: String, type: PartType) {
            self.value = value
            self.type = type
        }
    }
    
    public enum AddressUse: String, Sendable, Codable {
        case home = "H"
        case work = "WP"
        case temp = "TMP"
        case physical = "PHYS"
        case postal = "PST"
    }
    
    public init(
        parts: [AddressPart],
        use: AddressUse? = nil,
        validTime: IVL<TS>? = nil,
        nullFlavor: NullFlavor? = nil
    ) {
        self.parts = parts
        self.use = use
        self.validTime = validTime
        self.nullFlavor = nullFlavor
    }
    
    public init(nullFlavor: NullFlavor) {
        self.parts = []
        self.use = nil
        self.validTime = nil
        self.nullFlavor = nullFlavor
    }
}

// MARK: - Telecommunication Address (TEL)

/// Phone, email, fax, URL
public struct TEL: Sendable, Codable, Equatable {
    /// The actual address (URI format)
    public let value: String?
    
    /// Usage (home, work, mobile, etc.)
    public let use: TelecommunicationUse?
    
    /// When the address is valid
    public let validTime: IVL<TS>?
    
    /// Null flavor if address is not available
    public let nullFlavor: NullFlavor?
    
    public enum TelecommunicationUse: String, Sendable, Codable {
        case home = "H"
        case work = "WP"
        case mobile = "MC"
        case pager = "PG"
        case fax = "FAX"
        case email = "EMAIL"
    }
    
    public init(
        value: String,
        use: TelecommunicationUse? = nil,
        validTime: IVL<TS>? = nil
    ) {
        self.value = value
        self.use = use
        self.validTime = validTime
        self.nullFlavor = nil
    }
    
    public init(nullFlavor: NullFlavor) {
        self.value = nil
        self.use = nil
        self.validTime = nil
        self.nullFlavor = nullFlavor
    }
}
