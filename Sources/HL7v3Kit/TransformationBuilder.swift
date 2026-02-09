/// TransformationBuilder.swift
/// DSL for building custom transformation rules
///
/// Provides a fluent API for defining custom transformation mappings
/// between HL7 v2.x and v3.x message formats.

import Foundation
import HL7Core

// MARK: - Transformation Builder

/// Builder for creating custom transformation rules
public final class TransformationBuilder {
    private var rules: [TransformationRule] = []
    private var currentRule: PartialRule?
    
    /// Creates a new transformation builder
    public init() {}
    
    /// Start defining a new transformation rule
    /// - Parameter sourcePath: Path to source field (e.g., "PID-5" or "recordTarget.patient.name")
    /// - Returns: Self for chaining
    @discardableResult
    public func map(_ sourcePath: String) -> Self {
        // Save any pending rule
        if let rule = currentRule?.build() {
            rules.append(rule)
        }
        
        currentRule = PartialRule(sourcePath: sourcePath)
        return self
    }
    
    /// Set the target path for the current rule
    /// - Parameter targetPath: Path to target field
    /// - Returns: Self for chaining
    @discardableResult
    public func to(_ targetPath: String) -> Self {
        currentRule?.targetPath = targetPath
        return self
    }
    
    /// Add a transformation function to the current rule
    /// - Parameter transform: Function to transform the value
    /// - Returns: Self for chaining
    @discardableResult
    public func transform(_ transform: @escaping @Sendable (String) -> String) -> Self {
        currentRule?.transform = transform
        return self
    }
    
    /// Mark the current rule as required
    /// - Returns: Self for chaining
    @discardableResult
    public func required() -> Self {
        currentRule?.required = true
        return self
    }
    
    /// Add a description to the current rule
    /// - Parameter description: Human-readable description
    /// - Returns: Self for chaining
    @discardableResult
    public func describe(_ description: String) -> Self {
        currentRule?.description = description
        return self
    }
    
    /// Build all transformation rules
    /// - Returns: Array of transformation rules
    public func build() -> [TransformationRule] {
        // Save any pending rule
        if let rule = currentRule?.build() {
            rules.append(rule)
            currentRule = nil
        }
        
        let result = rules
        rules = []
        return result
    }
    
    /// Partial rule being constructed
    private struct PartialRule {
        let sourcePath: String
        var targetPath: String?
        var transform: (@Sendable (String) -> String)?
        var required: Bool = false
        var description: String?
        
        func build() -> TransformationRule? {
            guard let targetPath = targetPath else {
                return nil
            }
            
            return TransformationRule(
                id: UUID().uuidString,
                description: description ?? "Map \(sourcePath) to \(targetPath)",
                sourcePath: sourcePath,
                targetPath: targetPath,
                transform: transform,
                required: required
            )
        }
    }
}

// MARK: - Common Transformations

/// Common transformation functions
public enum CommonTransformations {
    
    /// Convert to uppercase
    public static let uppercase: @Sendable (String) -> String = { $0.uppercased() }
    
    /// Convert to lowercase
    public static let lowercase: @Sendable (String) -> String = { $0.lowercased() }
    
    /// Trim whitespace
    public static let trim: @Sendable (String) -> String = { $0.trimmingCharacters(in: .whitespaces) }
    
    /// Remove all whitespace
    public static let removeWhitespace: @Sendable (String) -> String = {
        $0.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
    }
    
    /// Format as phone number (XXX-XXX-XXXX)
    public static let formatPhone: @Sendable (String) -> String = { raw in
        let digits = raw.filter { $0.isNumber }
        guard digits.count == 10 else { return raw }
        let index1 = digits.index(digits.startIndex, offsetBy: 3)
        let index2 = digits.index(digits.startIndex, offsetBy: 6)
        return "\(digits[..<index1])-\(digits[index1..<index2])-\(digits[index2...])"
    }
    
    /// Format date from YYYYMMDD to YYYY-MM-DD
    public static let formatDate: @Sendable (String) -> String = { raw in
        guard raw.count == 8, raw.allSatisfy({ $0.isNumber }) else { return raw }
        let year = raw.prefix(4)
        let month = raw.dropFirst(4).prefix(2)
        let day = raw.suffix(2)
        return "\(year)-\(month)-\(day)"
    }
    
    /// Convert HL7 v2.x datetime to ISO8601
    public static let v2DateTimeToISO: @Sendable (String) -> String = { raw in
        // YYYYMMDDHHMMSS -> YYYY-MM-DDTHH:MM:SS
        guard raw.count >= 14, raw.allSatisfy({ $0.isNumber }) else { return raw }
        let year = raw.prefix(4)
        let month = raw.dropFirst(4).prefix(2)
        let day = raw.dropFirst(6).prefix(2)
        let hour = raw.dropFirst(8).prefix(2)
        let minute = raw.dropFirst(10).prefix(2)
        let second = raw.dropFirst(12).prefix(2)
        return "\(year)-\(month)-\(day)T\(hour):\(minute):\(second)"
    }
    
    /// Parse component from composite field (e.g., get first component)
    public static func component(_ index: Int, separator: Character = "^") -> @Sendable (String) -> String {
        return { raw in
            let components = raw.split(separator: separator).map(String.init)
            return index < components.count ? components[index] : ""
        }
    }
    
    /// Join multiple values with a separator
    public static func join(_ separator: String) -> @Sendable ([String]) -> String {
        return { values in
            values.joined(separator: separator)
        }
    }
    
    /// Map value using a dictionary
    public static func mapValue(_ mapping: [String: String], default defaultValue: String = "") -> @Sendable (String) -> String {
        return { value in
            mapping[value] ?? defaultValue
        }
    }
}

// MARK: - Transformation Template

/// Pre-built transformation templates for common scenarios
public enum TransformationTemplate {
    
    /// Standard ADT to CDA patient demographics mapping
    public static var adtPatientDemographics: [TransformationRule] {
        let builder = TransformationBuilder()
        
        return builder
            .map("PID-3")
            .to("recordTarget.patient.id")
            .describe("Patient identifier")
            .required()
        
            .map("PID-5")
            .to("recordTarget.patient.name")
            .describe("Patient name")
            .required()
        
            .map("PID-7")
            .to("recordTarget.patient.birthTime")
            .transform(CommonTransformations.formatDate)
            .describe("Date of birth")
        
            .map("PID-8")
            .to("recordTarget.patient.administrativeGenderCode")
            .describe("Administrative sex")
        
            .map("PID-11")
            .to("recordTarget.patient.addr")
            .describe("Patient address")
        
            .map("PID-13")
            .to("recordTarget.patient.telecom")
            .transform(CommonTransformations.formatPhone)
            .describe("Phone number")
        
            .build()
    }
    
    /// Standard ORU to CDA observation mapping
    public static var oruObservations: [TransformationRule] {
        let builder = TransformationBuilder()
        
        return builder
            .map("OBR-1")
            .to("component.structuredBody.section.id")
            .describe("Set ID")
        
            .map("OBR-4")
            .to("component.structuredBody.section.code")
            .describe("Universal service ID")
            .required()
        
            .map("OBR-7")
            .to("component.structuredBody.section.effectiveTime")
            .transform(CommonTransformations.v2DateTimeToISO)
            .describe("Observation date/time")
        
            .map("OBX-2")
            .to("entry.observation.value.type")
            .describe("Value type")
        
            .map("OBX-3")
            .to("entry.observation.code")
            .describe("Observation identifier")
            .required()
        
            .map("OBX-5")
            .to("entry.observation.value")
            .describe("Observation value")
            .required()
        
            .map("OBX-6")
            .to("entry.observation.value.unit")
            .describe("Units")
        
            .build()
    }
    
    /// Standard CDA to ADT patient demographics mapping (reverse)
    public static var cdaToAdtPatientDemographics: [TransformationRule] {
        let builder = TransformationBuilder()
        
        return builder
            .map("recordTarget.patient.id")
            .to("PID-3")
            .describe("Patient identifier")
            .required()
        
            .map("recordTarget.patient.name")
            .to("PID-5")
            .describe("Patient name")
            .required()
        
            .map("recordTarget.patient.birthTime")
            .to("PID-7")
            .describe("Date of birth")
        
            .map("recordTarget.patient.administrativeGenderCode")
            .to("PID-8")
            .describe("Administrative sex")
        
            .map("recordTarget.patient.addr")
            .to("PID-11")
            .describe("Patient address")
        
            .map("recordTarget.patient.telecom")
            .to("PID-13")
            .describe("Phone number")
        
            .build()
    }
}

// MARK: - Example Usage in Documentation

/*
 Example of creating custom transformation rules:
 
 ```swift
 let builder = TransformationBuilder()
 
 let rules = builder
     .map("PID-5")
     .to("recordTarget.patient.name")
     .transform(CommonTransformations.uppercase)
     .required()
     .describe("Patient name (uppercase)")
     
     .map("PID-7")
     .to("recordTarget.patient.birthTime")
     .transform(CommonTransformations.formatDate)
     .describe("Date of birth")
     
     .map("PID-8")
     .to("recordTarget.patient.administrativeGenderCode")
     .transform { gender in
         switch gender {
         case "M": return "Male"
         case "F": return "Female"
         default: return "Unknown"
         }
     }
     .build()
 
 let config = TransformationConfiguration(
     customRules: rules
 )
 ```
 */
