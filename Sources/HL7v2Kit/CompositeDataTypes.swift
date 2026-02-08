/// HL7 v2.x Composite Data Types
///
/// This file implements HL7 v2.x composite data types which consist of multiple
/// components separated by component delimiters.

import Foundation
@preconcurrency import HL7Core


// MARK: - Helper Functions

/// Helper function to create validation results from issues
private func makeValidationResult(issues: [ValidationIssue]) -> ValidationResult {
    if issues.isEmpty {
        return .valid
    }
    
    let hasErrors = issues.contains { $0.severity == .error }
    if hasErrors {
        return .invalid(issues)
    } else {
        return .warning(issues)
    }
}

// MARK: - Composite Data Types

/// CE - Coded Element
/// Format: Identifier^Text^Name of Coding System^Alternate Identifier^Alternate Text^Name of Alternate Coding System
/// Example: 410623003^Malaria^SNOMED
public struct CE: HL7DataType {
    public let rawValue: String
    
    /// Components split by component delimiter (^)
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Identifier - code value
    public var identifier: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Text - descriptive text
    public var text: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Name of Coding System (e.g., SNOMED, LOINC, ICD)
    public var codingSystem: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// Alternate Identifier
    public var alternateIdentifier: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    /// Alternate Text
    public var alternateText: String? {
        components.indices.contains(4) ? components[4].nilIfEmpty : nil
    }
    
    /// Name of Alternate Coding System
    public var alternateCodingSystem: String? {
        components.indices.contains(5) ? components[5].nilIfEmpty : nil
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(identifier: String?, text: String? = nil, codingSystem: String? = nil,
                alternateIdentifier: String? = nil, alternateText: String? = nil,
                alternateCodingSystem: String? = nil) {
        let parts = [
            identifier ?? "",
            text ?? "",
            codingSystem ?? "",
            alternateIdentifier ?? "",
            alternateText ?? "",
            alternateCodingSystem ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // CE should have at least identifier and coding system for proper use
        if isEmpty {
            return makeValidationResult(issues: issues)
        }
        
        if identifier == nil || identifier?.isEmpty == true {
            issues.append(ValidationIssue(
                severity: .error,
                message: "CE missing identifier",
                location: "CE.1"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// CX - Extended Composite ID
/// Format: ID^Check Digit^Check Digit Scheme^Assigning Authority^Identifier Type Code^Assigning Facility
/// Example: 123456^^^Hospital^MR
public struct CX: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// ID Number
    public var id: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Check Digit
    public var checkDigit: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Check Digit Scheme (e.g., M10, M11)
    public var checkDigitScheme: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// Assigning Authority
    public var assigningAuthority: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    /// Identifier Type Code (e.g., MR, PI, AN)
    public var identifierTypeCode: String? {
        components.indices.contains(4) ? components[4].nilIfEmpty : nil
    }
    
    /// Assigning Facility
    public var assigningFacility: String? {
        components.indices.contains(5) ? components[5].nilIfEmpty : nil
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(id: String, checkDigit: String? = nil, checkDigitScheme: String? = nil,
                assigningAuthority: String? = nil, identifierTypeCode: String? = nil,
                assigningFacility: String? = nil) {
        let parts = [
            id,
            checkDigit ?? "",
            checkDigitScheme ?? "",
            assigningAuthority ?? "",
            identifierTypeCode ?? "",
            assigningFacility ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        if isEmpty {
            return makeValidationResult(issues: issues)
        }
        
        if id == nil || id?.isEmpty == true {
            issues.append(ValidationIssue(
                severity: .error,
                message: "CX missing ID",
                location: "CX.1"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// XPN - Extended Person Name
/// Format: Family Name^Given Name^Middle Name^Suffix^Prefix^Degree^Name Type Code
/// Example: Smith^John^A^Jr^Dr
public struct XPN: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Family Name (Last Name)
    public var familyName: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Given Name (First Name)
    public var givenName: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Middle Name
    public var middleName: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// Suffix (e.g., Jr, Sr, III)
    public var suffix: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    /// Prefix (e.g., Dr, Mr, Ms)
    public var prefix: String? {
        components.indices.contains(4) ? components[4].nilIfEmpty : nil
    }
    
    /// Degree (e.g., MD, PhD)
    public var degree: String? {
        components.indices.contains(5) ? components[5].nilIfEmpty : nil
    }
    
    /// Name Type Code (L=Legal, A=Alias, etc.)
    public var nameTypeCode: String? {
        components.indices.contains(6) ? components[6].nilIfEmpty : nil
    }
    
    /// Formatted full name
    public var fullName: String {
        var parts: [String] = []
        if let prefix = prefix { parts.append(prefix) }
        if let givenName = givenName { parts.append(givenName) }
        if let middleName = middleName { parts.append(middleName) }
        if let familyName = familyName { parts.append(familyName) }
        if let suffix = suffix { parts.append(suffix) }
        if let degree = degree { parts.append(degree) }
        return parts.joined(separator: " ")
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(familyName: String?, givenName: String? = nil, middleName: String? = nil,
                suffix: String? = nil, prefix: String? = nil, degree: String? = nil,
                nameTypeCode: String? = nil) {
        let parts = [
            familyName ?? "",
            givenName ?? "",
            middleName ?? "",
            suffix ?? "",
            prefix ?? "",
            degree ?? "",
            nameTypeCode ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check if truly empty (no value at all, not just empty components)
        if rawValue.isEmpty {
            return makeValidationResult(issues: issues)
        }
        
        // At least family name or given name should be present
        if (familyName == nil || familyName?.isEmpty == true) &&
           (givenName == nil || givenName?.isEmpty == true) {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "XPN should have at least family name or given name",
                location: "XPN"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// XAD - Extended Address
/// Format: Street^Other Designation^City^State^Zip^Country^Address Type^Other Geographic Designation
/// Example: 123 Main St^^Boston^MA^02101^USA
public struct XAD: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Street Address
    public var street: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Other Designation (e.g., Apartment number)
    public var otherDesignation: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// City
    public var city: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// State or Province
    public var state: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    /// Postal Code
    public var postalCode: String? {
        components.indices.contains(4) ? components[4].nilIfEmpty : nil
    }
    
    /// Country
    public var country: String? {
        components.indices.contains(5) ? components[5].nilIfEmpty : nil
    }
    
    /// Address Type (e.g., M=Mailing, H=Home, O=Office)
    public var addressType: String? {
        components.indices.contains(6) ? components[6].nilIfEmpty : nil
    }
    
    /// Other Geographic Designation
    public var otherGeographicDesignation: String? {
        components.indices.contains(7) ? components[7].nilIfEmpty : nil
    }
    
    /// Formatted address
    public var formattedAddress: String {
        var lines: [String] = []
        if let street = street {
            lines.append(street)
        }
        if let otherDesignation = otherDesignation {
            lines.append(otherDesignation)
        }
        let cityLine = [city, state, postalCode].compactMap { $0 }.joined(separator: " ")
        if !cityLine.isEmpty {
            lines.append(cityLine)
        }
        if let country = country {
            lines.append(country)
        }
        return lines.joined(separator: "\n")
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(street: String? = nil, otherDesignation: String? = nil, city: String? = nil,
                state: String? = nil, postalCode: String? = nil, country: String? = nil,
                addressType: String? = nil, otherGeographicDesignation: String? = nil) {
        let parts = [
            street ?? "",
            otherDesignation ?? "",
            city ?? "",
            state ?? "",
            postalCode ?? "",
            country ?? "",
            addressType ?? "",
            otherGeographicDesignation ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        // Address validation is flexible - no required fields
        return .valid
    }
}

/// XTN - Extended Telecommunication
/// Format: [(999)]999-9999[X99999]^Use Code^Equipment Type^Email Address
/// Example: (617)555-1234
public struct XTN: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Telecommunication number (phone, fax, etc.)
    public var number: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Use Code (e.g., WPN=Work Phone, PRN=Primary Residence)
    public var useCode: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Equipment Type (e.g., PH=Phone, FX=Fax, CP=Cell Phone, Internet=Email)
    public var equipmentType: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// Email Address
    public var email: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(number: String?, useCode: String? = nil, equipmentType: String? = nil, email: String? = nil) {
        let parts = [
            number ?? "",
            useCode ?? "",
            equipmentType ?? "",
            email ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check if truly empty (no value at all, not just empty components)
        if rawValue.isEmpty {
            return makeValidationResult(issues: issues)
        }
        
        // Should have at least a number or email
        if (number == nil || number?.isEmpty == true) &&
           (email == nil || email?.isEmpty == true) {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "XTN should have either a number or email",
                location: "XTN"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// EI - Entity Identifier
/// Format: Entity Identifier^Namespace ID^Universal ID^Universal ID Type
/// Example: MSG00001^SendingSystem
public struct EI: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Entity Identifier
    public var entityIdentifier: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Namespace ID
    public var namespaceID: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Universal ID
    public var universalID: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// Universal ID Type (e.g., ISO, DNS, GUID)
    public var universalIDType: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(entityIdentifier: String, namespaceID: String? = nil,
                universalID: String? = nil, universalIDType: String? = nil) {
        let parts = [
            entityIdentifier,
            namespaceID ?? "",
            universalID ?? "",
            universalIDType ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        if isEmpty {
            return makeValidationResult(issues: issues)
        }
        
        if entityIdentifier == nil || entityIdentifier?.isEmpty == true {
            issues.append(ValidationIssue(
                severity: .error,
                message: "EI missing entity identifier",
                location: "EI.1"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// HD - Hierarchic Designator
/// Format: Namespace ID^Universal ID^Universal ID Type
/// Example: Hospital^1.2.3.4^ISO
public struct HD: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Namespace ID
    public var namespaceID: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Universal ID (e.g., OID)
    public var universalID: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Universal ID Type (e.g., ISO, DNS, GUID)
    public var universalIDType: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(namespaceID: String, universalID: String? = nil, universalIDType: String? = nil) {
        let parts = [
            namespaceID,
            universalID ?? "",
            universalIDType ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        if isEmpty {
            return makeValidationResult(issues: issues)
        }
        
        if namespaceID == nil || namespaceID?.isEmpty == true {
            issues.append(ValidationIssue(
                severity: .error,
                message: "HD missing namespace ID",
                location: "HD.1"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// PL - Person Location
/// Format: Point of Care^Room^Bed^Facility^Location Status^Person Location Type^Building^Floor
/// Example: 4E^401^B^Hospital^^N
public struct PL: HL7DataType {
    public let rawValue: String
    private let components: [String]
    
    public var isEmpty: Bool {
        rawValue.isEmpty || components.allSatisfy { $0.isEmpty }
    }
    
    public var description: String {
        rawValue
    }
    
    /// Point of Care (e.g., ward, department)
    public var pointOfCare: String? {
        components.indices.contains(0) ? components[0].nilIfEmpty : nil
    }
    
    /// Room
    public var room: String? {
        components.indices.contains(1) ? components[1].nilIfEmpty : nil
    }
    
    /// Bed
    public var bed: String? {
        components.indices.contains(2) ? components[2].nilIfEmpty : nil
    }
    
    /// Facility
    public var facility: String? {
        components.indices.contains(3) ? components[3].nilIfEmpty : nil
    }
    
    /// Location Status
    public var locationStatus: String? {
        components.indices.contains(4) ? components[4].nilIfEmpty : nil
    }
    
    /// Person Location Type
    public var personLocationType: String? {
        components.indices.contains(5) ? components[5].nilIfEmpty : nil
    }
    
    /// Building
    public var building: String? {
        components.indices.contains(6) ? components[6].nilIfEmpty : nil
    }
    
    /// Floor
    public var floor: String? {
        components.indices.contains(7) ? components[7].nilIfEmpty : nil
    }
    
    /// Formatted location
    public var formattedLocation: String {
        var parts: [String] = []
        if let facility = facility { parts.append(facility) }
        if let building = building { parts.append("Building \(building)") }
        if let floor = floor { parts.append("Floor \(floor)") }
        if let pointOfCare = pointOfCare { parts.append(pointOfCare) }
        if let room = room { parts.append("Room \(room)") }
        if let bed = bed { parts.append("Bed \(bed)") }
        return parts.joined(separator: ", ")
    }
    
    public init(_ value: String, componentDelimiter: Character = "^") {
        self.rawValue = value
        self.components = value.split(separator: componentDelimiter, omittingEmptySubsequences: false).map(String.init)
    }
    
    public init(pointOfCare: String? = nil, room: String? = nil, bed: String? = nil,
                facility: String? = nil, locationStatus: String? = nil, personLocationType: String? = nil,
                building: String? = nil, floor: String? = nil) {
        let parts = [
            pointOfCare ?? "",
            room ?? "",
            bed ?? "",
            facility ?? "",
            locationStatus ?? "",
            personLocationType ?? "",
            building ?? "",
            floor ?? ""
        ]
        self.rawValue = parts.joined(separator: "^")
        self.components = parts
    }
    
    public func validate() -> ValidationResult {
        // Person location validation is flexible - no required fields
        return .valid
    }
}

// MARK: - Helper Extensions

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
