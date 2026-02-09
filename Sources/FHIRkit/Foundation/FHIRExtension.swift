/// FHIRExtension.swift
/// FHIR Extension type
///
/// This file implements the Extension structure used throughout FHIR resources
/// See: http://hl7.org/fhir/R4/extensibility.html

import Foundation

// MARK: - Extension

/// Optional Extension Element - defines the extension structure
public struct Extension: Codable, Sendable, Hashable {
    /// Element ID
    public let id: String?
    
    /// Nested extensions
    public let `extension`: [Extension]?
    
    /// Identifies the meaning of the extension
    public let url: String
    
    /// Value of extension - can be various types (value[x])
    public let valueBoolean: Bool?
    public let valueInteger: Int32?
    public let valueDecimal: Decimal?
    public let valueString: String?
    public let valueUri: String?
    public let valueUrl: String?
    public let valueCode: String?
    public let valueDateTime: String?
    public let valueDate: String?
    public let valueTime: String?
    
    public init(
        id: String? = nil,
        extension: [Extension]? = nil,
        url: String,
        valueBoolean: Bool? = nil,
        valueInteger: Int32? = nil,
        valueDecimal: Decimal? = nil,
        valueString: String? = nil,
        valueUri: String? = nil,
        valueUrl: String? = nil,
        valueCode: String? = nil,
        valueDateTime: String? = nil,
        valueDate: String? = nil,
        valueTime: String? = nil
    ) {
        self.id = id
        self.extension = `extension`
        self.url = url
        self.valueBoolean = valueBoolean
        self.valueInteger = valueInteger
        self.valueDecimal = valueDecimal
        self.valueString = valueString
        self.valueUri = valueUri
        self.valueUrl = valueUrl
        self.valueCode = valueCode
        self.valueDateTime = valueDateTime
        self.valueDate = valueDate
        self.valueTime = valueTime
    }
}
