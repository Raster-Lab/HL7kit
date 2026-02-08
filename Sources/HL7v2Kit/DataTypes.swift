/// HL7 v2.x Data Type System
///
/// This file implements the HL7 v2.x data type system including both primitive
/// and composite data types with validation, conversion, and memory optimization.

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

// MARK: - Base Protocol

/// Base protocol for all HL7 v2.x data types
public protocol HL7DataType: Sendable, CustomStringConvertible {
    /// Raw string value of the data type
    var rawValue: String { get }
    
    /// Validates the data type value according to HL7 specifications
    /// - Returns: ValidationResult indicating success or failure with details
    func validate() -> ValidationResult
    
    /// Indicates if the value is empty or null
    var isEmpty: Bool { get }
}

// MARK: - Primitive Data Types

/// ST - String Data Type
/// General purpose string up to 199 characters
public struct ST: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // ST fields should not exceed 199 characters (v2.x standard)
        if rawValue.count > 199 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "ST value exceeds maximum length of 199 characters",
                location: "ST"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// TX - Text Data Type
/// Long text field up to 65536 characters, may contain formatting
public struct TX: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // TX fields can be very large (up to 65536 characters)
        if rawValue.count > 65536 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "TX value exceeds maximum length of 65536 characters",
                location: "TX"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// FT - Formatted Text Data Type
/// Rich text with formatting escape sequences
public struct FT: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // FT fields can be very large
        if rawValue.count > 65536 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "FT value exceeds maximum length of 65536 characters",
                location: "FT"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
    
    /// Returns the plain text without formatting escape sequences
    public var plainText: String {
        // Remove common HL7 formatting sequences
        rawValue
            .replacingOccurrences(of: "\\.br\\", with: "\n")
            .replacingOccurrences(of: "\\.sp\\", with: " ")
            .replacingOccurrences(of: "\\.fi\\", with: "")
            .replacingOccurrences(of: "\\.nf\\", with: "")
    }
}

/// NM - Numeric Data Type
/// Decimal number
public struct NM: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    /// Numeric value as Decimal for precision
    public var numericValue: Decimal? {
        Decimal(string: rawValue)
    }
    
    /// Numeric value as Double for calculations
    public var doubleValue: Double? {
        Double(rawValue)
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public init(_ value: Decimal) {
        self.rawValue = String(describing: value)
    }
    
    public init(_ value: Double) {
        self.rawValue = String(value)
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Validate that the value is a valid number
        if !rawValue.isEmpty && Decimal(string: rawValue) == nil {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid numeric value: '\(rawValue)'",
                location: "NM"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// SI - Sequence ID Data Type
/// Integer for ordering (1, 2, 3, ...)
public struct SI: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    /// Integer value
    public var intValue: Int? {
        Int(rawValue)
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public init(_ value: Int) {
        self.rawValue = String(value)
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Validate that the value is a valid integer
        if !rawValue.isEmpty && Int(rawValue) == nil {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid sequence ID value: '\(rawValue)'",
                location: "SI"
            ))
        }
        
        // SI should be positive
        if let value = intValue, value < 1 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Sequence ID should be positive: \(value)",
                location: "SI"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// DT - Date Data Type
/// Date in format YYYYMMDD or YYYY[MM[DD]]
public struct DT: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    /// Parse the date into DateComponents
    public var dateComponents: DateComponents? {
        guard rawValue.count >= 4 else { return nil }
        
        let year = Int(rawValue.prefix(4))
        let month = rawValue.count >= 6 ? Int(rawValue.dropFirst(4).prefix(2)) : nil
        let day = rawValue.count >= 8 ? Int(rawValue.dropFirst(6).prefix(2)) : nil
        
        guard let year = year else { return nil }
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        return components
    }
    
    /// Convert to Foundation Date
    public var date: Date? {
        guard let components = dateComponents else { return nil }
        return Calendar.current.date(from: components)
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public init(year: Int, month: Int? = nil, day: Int? = nil) {
        var value = String(format: "%04d", year)
        if let month = month {
            value += String(format: "%02d", month)
            if let day = day {
                value += String(format: "%02d", day)
            }
        }
        self.rawValue = value
    }
    
    public init(_ date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month, day: components.day)
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check format: YYYY, YYYYMM, or YYYYMMDD
        let validLengths = [4, 6, 8]
        if !rawValue.isEmpty && !validLengths.contains(rawValue.count) {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid date format. Expected YYYY, YYYYMM, or YYYYMMDD",
                location: "DT"
            ))
            return makeValidationResult(issues: issues)
        }
        
        // Validate date components
        if let components = dateComponents {
            if let month = components.month, !(1...12).contains(month) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid month: \(month)",
                location: "DT"
            ))
            }
            if let day = components.day, !(1...31).contains(day) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid day: \(day)",
                location: "DT"
            ))
            }
        } else if !rawValue.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid date format",
                location: "DT"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// TM - Time Data Type
/// Time in format HHMM[SS[.S[S[S[S]]]]]
public struct TM: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    /// Parse the time into DateComponents
    public var timeComponents: DateComponents? {
        guard rawValue.count >= 4 else { return nil }
        
        let hour = Int(rawValue.prefix(2))
        let minute = Int(rawValue.dropFirst(2).prefix(2))
        
        var second: Int?
        var nanosecond: Int?
        
        if rawValue.count >= 6 {
            second = Int(rawValue.dropFirst(4).prefix(2))
        }
        
        // Handle fractional seconds
        if rawValue.count > 6 && rawValue.contains(".") {
            let components = rawValue.split(separator: ".")
            if components.count == 2 {
                let fraction = String(components[1])
                // Convert fraction to nanoseconds
                if let fractionValue = Double("0.\(fraction)") {
                    nanosecond = Int(fractionValue * 1_000_000_000)
                }
            }
        }
        
        guard let hour = hour, let minute = minute else { return nil }
        
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = second
        components.nanosecond = nanosecond
        
        return components
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public init(hour: Int, minute: Int, second: Int? = nil, millisecond: Int? = nil) {
        var value = String(format: "%02d%02d", hour, minute)
        if let second = second {
            value += String(format: "%02d", second)
            if let millisecond = millisecond {
                value += String(format: ".%03d", millisecond)
            }
        }
        self.rawValue = value
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check minimum length
        if !rawValue.isEmpty && rawValue.count < 4 {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid time format. Minimum format is HHMM",
                location: "TM"
            ))
            return makeValidationResult(issues: issues)
        }
        
        // Validate time components
        if let components = timeComponents {
            if let hour = components.hour, !(0...23).contains(hour) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid hour: \(hour)",
                location: "TM"
            ))
            }
            if let minute = components.minute, !(0...59).contains(minute) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid minute: \(minute)",
                location: "TM"
            ))
            }
            if let second = components.second, !(0...59).contains(second) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid second: \(second)",
                location: "TM"
            ))
            }
        } else if !rawValue.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid time format",
                location: "TM"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

/// DTM (TS in v2.3) - Date/Time Data Type
/// Combined date and time with optional timezone: YYYY[MM[DD[HHMM[SS[.S[S[S[S]]]]]]]][+/-ZZZZ]
public struct DTM: HL7DataType {
    public let rawValue: String
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        rawValue
    }
    
    /// Parse the datetime into DateComponents with timezone
    public var dateTimeComponents: (components: DateComponents, timezone: TimeZone?)? {
        guard rawValue.count >= 4 else { return nil }
        
        // Extract timezone if present
        var dateTimeString = rawValue
        var timezone: TimeZone?
        
        // Check for timezone offset (+/-ZZZZ)
        if let lastPlusIndex = rawValue.lastIndex(of: "+"),
           lastPlusIndex > rawValue.startIndex {
            let offset = String(rawValue[lastPlusIndex...])
            dateTimeString = String(rawValue[..<lastPlusIndex])
            timezone = parseTimezoneOffset(offset)
        } else if let lastMinusIndex = rawValue.lastIndex(of: "-"),
                  lastMinusIndex > rawValue.startIndex {
            let offset = String(rawValue[lastMinusIndex...])
            dateTimeString = String(rawValue[..<lastMinusIndex])
            timezone = parseTimezoneOffset(offset)
        }
        
        // Parse date components
        let year = Int(dateTimeString.prefix(4))
        let month = dateTimeString.count >= 6 ? Int(dateTimeString.dropFirst(4).prefix(2)) : nil
        let day = dateTimeString.count >= 8 ? Int(dateTimeString.dropFirst(6).prefix(2)) : nil
        let hour = dateTimeString.count >= 10 ? Int(dateTimeString.dropFirst(8).prefix(2)) : nil
        let minute = dateTimeString.count >= 12 ? Int(dateTimeString.dropFirst(10).prefix(2)) : nil
        let second = dateTimeString.count >= 14 ? Int(dateTimeString.dropFirst(12).prefix(2)) : nil
        
        guard let year = year else { return nil }
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timezone
        
        return (components, timezone)
    }
    
    /// Convert to Foundation Date
    public var date: Date? {
        guard let result = dateTimeComponents else { return nil }
        let calendar = Calendar.current
        return calendar.date(from: result.components)
    }
    
    private func parseTimezoneOffset(_ offset: String) -> TimeZone? {
        // Format: +/-HHMM
        guard offset.count == 5 else { return nil }
        let sign = offset.first == "+" ? 1 : -1
        guard let hours = Int(offset.dropFirst().prefix(2)),
              let minutes = Int(offset.dropFirst(3)) else {
            return nil
        }
        let totalSeconds = sign * (hours * 3600 + minutes * 60)
        return TimeZone(secondsFromGMT: totalSeconds)
    }
    
    public init(_ value: String) {
        self.rawValue = value
    }
    
    public init(_ date: Date, timezone: TimeZone? = nil) {
        let calendar = Calendar.current
        let tz = timezone ?? TimeZone.current
        let components = calendar.dateComponents(in: tz, from: date)
        
        var value = String(format: "%04d%02d%02d%02d%02d%02d",
                          components.year!, components.month!, components.day!,
                          components.hour!, components.minute!, components.second!)
        
        // Add timezone offset
        let offset = tz.secondsFromGMT(for: date)
        let hours = abs(offset) / 3600
        let minutes = (abs(offset) % 3600) / 60
        let sign = offset >= 0 ? "+" : "-"
        value += String(format: "%@%02d%02d", sign, hours, minutes)
        
        self.rawValue = value
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // Check minimum length
        if !rawValue.isEmpty && rawValue.count < 4 {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid datetime format. Minimum format is YYYY",
                location: "DTM"
            ))
            return makeValidationResult(issues: issues)
        }
        
        // Validate date/time components
        if let result = dateTimeComponents {
            let components = result.components
            if let month = components.month, !(1...12).contains(month) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid month: \(month)",
                location: "DTM"
            ))
            }
            if let day = components.day, !(1...31).contains(day) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid day: \(day)",
                location: "DTM"
            ))
            }
            if let hour = components.hour, !(0...23).contains(hour) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid hour: \(hour)",
                location: "DTM"
            ))
            }
            if let minute = components.minute, !(0...59).contains(minute) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid minute: \(minute)",
                location: "DTM"
            ))
            }
            if let second = components.second, !(0...59).contains(second) {
                issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid second: \(second)",
                location: "DTM"
            ))
            }
        } else if !rawValue.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Invalid datetime format",
                location: "DTM"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}

// Convenience alias for backward compatibility
public typealias TS = DTM

/// ID - Coded Value (Defined Tables)
/// Predefined code from HL7 tables
public struct ID: HL7DataType {
    public let rawValue: String
    public let tableId: String?
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        if let tableId = tableId {
            return "\(rawValue) (Table: \(tableId))"
        }
        return rawValue
    }
    
    public init(_ value: String, table: String? = nil) {
        self.rawValue = value
        self.tableId = table
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // ID values should be relatively short
        if rawValue.count > 20 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "ID value unusually long: '\(rawValue)'",
                location: "ID"
            ))
        }
        
        // Note: In a production system, we would validate against the specific HL7 table
        // For now, we just ensure it's not empty if required
        
        return makeValidationResult(issues: issues)
    }
}

/// IS - Coded Value (User-Defined Tables)
/// User-defined code or value
public struct IS: HL7DataType {
    public let rawValue: String
    public let tableId: String?
    
    public var isEmpty: Bool {
        rawValue.isEmpty || rawValue == "\"\"" || rawValue == "\"\""
    }
    
    public var description: String {
        if let tableId = tableId {
            return "\(rawValue) (User Table: \(tableId))"
        }
        return rawValue
    }
    
    public init(_ value: String, table: String? = nil) {
        self.rawValue = value
        self.tableId = table
    }
    
    public func validate() -> ValidationResult {
        var issues: [ValidationIssue] = []
        
        // IS values are user-defined, so validation is minimal
        // Just ensure reasonable length
        if rawValue.count > 100 {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "IS value unusually long: '\(rawValue)'",
                location: "IS"
            ))
        }
        
        return makeValidationResult(issues: issues)
    }
}
