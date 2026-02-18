/// FHIRXMLSerialization.swift
/// XML serialization and deserialization for FHIR resources
///
/// This file provides XML parsing and serialization for FHIR R4 resources
/// using Foundation's XMLParser and XMLDocument.

import Foundation
import HL7Core

#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - FHIR XML Namespace

extension String {
    /// FHIR namespace
    public static let fhirNamespace = "http://hl7.org/fhir"
    
    /// XHTML namespace (for narrative)
    public static let xhtmlNamespace = "http://www.w3.org/1999/xhtml"
}

// MARK: - FHIR XML Serializer

/// FHIR XML serialization actor for thread-safe XML operations
public actor FHIRXMLSerializer {
    /// Serialization configuration
    public let configuration: FHIRSerializationConfiguration
    
    public init(configuration: FHIRSerializationConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Encoding to XML
    
    /// Encode a FHIR resource to XML string
    public func encodeToString<T: Encodable & Sendable>(_ resource: T) async throws -> String {
        // First encode to JSON, then convert to XML structure
        // This is a simplified approach - a full implementation would use PropertyListEncoder
        // or custom XML writing
        let jsonSerializer = await FHIRJSONSerializer(configuration: configuration)
        let jsonData = try await jsonSerializer.encode(resource)
        
        // Decode JSON to dictionary
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw FHIRSerializationError.invalidJSON("Failed to decode resource to JSON object")
        }
        
        // Build XML from JSON structure
        let xmlBuilder = XMLBuilder(configuration: configuration)
        return try xmlBuilder.buildXML(from: jsonObject)
    }
    
    /// Encode a FHIR resource to XML data
    public func encode<T: Encodable & Sendable>(_ resource: T) async throws -> Data {
        let xmlString = try await encodeToString(resource)
        guard let data = xmlString.data(using: .utf8) else {
            throw FHIRSerializationError.invalidXML("Failed to convert XML string to UTF-8 data")
        }
        return data
    }
    
    // MARK: - Decoding from XML
    
    /// Decode FHIR resource from XML string
    public func decode<T: Decodable & Sendable>(_ type: T.Type, from xmlString: String) async throws -> T {
        guard let data = xmlString.data(using: .utf8) else {
            throw FHIRSerializationError.invalidXML("Invalid UTF-8 string")
        }
        return try await decode(type, from: data)
    }
    
    /// Decode FHIR resource from XML data
    public func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws -> T {
        // Parse XML to JSON structure first
        let parser = FHIRXMLParser(configuration: configuration)
        let jsonData = try parser.parseXMLToJSON(data)
        
        // Decode using JSON decoder
        let jsonSerializer = await FHIRJSONSerializer(configuration: configuration)
        return try await jsonSerializer.decode(type, from: jsonData)
    }
    
    /// Decode FHIR resource container from XML data (polymorphic)
    public func decodeResource(from data: Data) async throws -> ResourceContainer {
        try await decode(ResourceContainer.self, from: data)
    }
}

// MARK: - XML Builder

/// Internal XML builder for converting JSON structures to XML
private struct XMLBuilder {
    let configuration: FHIRSerializationConfiguration
    
    func buildXML(from jsonObject: [String: Any]) throws -> String {
        guard let resourceType = jsonObject["resourceType"] as? String else {
            throw FHIRSerializationError.invalidResourceType("Missing resourceType in JSON")
        }
        
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<\(resourceType) xmlns=\"\(String.fhirNamespace)\">\n"
        
        // Build element content
        for (key, value) in jsonObject where key != "resourceType" {
            xml += buildElement(name: key, value: value, indent: 1)
        }
        
        xml += "</\(resourceType)>\n"
        
        return xml
    }
    
    private func buildElement(name: String, value: Any, indent: Int) -> String {
        let indentString = String(repeating: "  ", count: indent)
        
        if let boolValue = value as? Bool {
            return "\(indentString)<\(name) value=\"\(boolValue)\"/>\n"
        } else if let stringValue = value as? String {
            return "\(indentString)<\(name) value=\"\(escapeXML(stringValue))\"/>\n"
        } else if let numberValue = value as? NSNumber {
            return "\(indentString)<\(name) value=\"\(numberValue)\"/>\n"
        } else if let arrayValue = value as? [Any] {
            var result = ""
            for item in arrayValue {
                if let dictItem = item as? [String: Any] {
                    result += "\(indentString)<\(name)>\n"
                    for (key, val) in dictItem {
                        result += buildElement(name: key, value: val, indent: indent + 1)
                    }
                    result += "\(indentString)</\(name)>\n"
                } else {
                    // Handle primitive array items (string, number, bool)
                    result += buildElement(name: name, value: item, indent: indent)
                }
            }
            return result
        } else if let dictValue = value as? [String: Any] {
            var result = "\(indentString)<\(name)>\n"
            for (key, val) in dictValue {
                result += buildElement(name: key, value: val, indent: indent + 1)
            }
            result += "\(indentString)</\(name)>\n"
            return result
        }
        
        return ""
    }
    
    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - XML Parser

/// Internal XML parser for converting XML to JSON structure
private struct FHIRXMLParser {
    let configuration: FHIRSerializationConfiguration
    
    func parseXMLToJSON(_ data: Data) throws -> Data {
        let parser = XMLParser(data: data)
        let delegate = FHIRXMLParserDelegate()
        parser.delegate = delegate
        
        guard parser.parse() else {
            throw FHIRSerializationError.invalidXML(parser.parserError?.localizedDescription ?? "Unknown parsing error")
        }
        
        guard let rawResult = delegate.result else {
            throw FHIRSerializationError.invalidXML("Failed to build JSON structure from XML")
        }
        
        // Convert raw XML structure to proper FHIR JSON
        let fhirJSON = convertToFHIRJSON(rawResult)
        
        // Convert to JSON data
        return try JSONSerialization.data(withJSONObject: fhirJSON, options: [])
    }
    
    /// Convert raw XML-parsed dict to proper FHIR JSON structure
    private func convertToFHIRJSON(_ xmlDict: [String: Any]) -> [String: Any] {
        // The raw dict is like {"Patient": {"xmlns": "...", "id": {"value": "x"}, ...}}
        // We need {"resourceType": "Patient", "id": "x", ...}
        guard let (resourceType, innerValue) = xmlDict.first,
              let inner = innerValue as? [String: Any] else {
            return xmlDict
        }
        
        var result: [String: Any] = ["resourceType": resourceType]
        let arrayFields = Self.fhirArrayFields(for: resourceType)
        
        for (key, value) in inner {
            if key == "xmlns" { continue }
            result[key] = convertValue(value, key: key, parentArrayFields: arrayFields)
        }
        
        return result
    }
    
    /// Recursively convert XML-parsed values to FHIR JSON values
    private func convertValue(_ value: Any, key: String, parentArrayFields: Set<String>) -> Any {
        if let dict = value as? [String: Any] {
            let meaningfulKeys = dict.keys.filter { $0 != "xmlns" }
            
            // Simple value attribute → flatten to plain value
            if meaningfulKeys == ["value"] {
                let flatValue = dict["value"]!
                if parentArrayFields.contains(key) {
                    return [flatValue]
                }
                return flatValue
            }
            
            // Complex object → recursively convert children
            let nestedArrayFields = Self.fhirArrayFields(for: key)
            var converted: [String: Any] = [:]
            for (k, v) in dict where k != "xmlns" {
                converted[k] = convertValue(v, key: k, parentArrayFields: nestedArrayFields)
            }
            
            if parentArrayFields.contains(key) {
                return [converted]
            }
            return converted
        }
        
        if let array = value as? [Any] {
            return array.map { item -> Any in
                if let dict = item as? [String: Any] {
                    let meaningfulKeys = dict.keys.filter { $0 != "xmlns" }
                    if meaningfulKeys == ["value"] {
                        return dict["value"]!
                    }
                    let nestedArrayFields = Self.fhirArrayFields(for: key)
                    var converted: [String: Any] = [:]
                    for (k, v) in dict where k != "xmlns" {
                        converted[k] = convertValue(v, key: k, parentArrayFields: nestedArrayFields)
                    }
                    return converted
                }
                return item
            }
        }
        
        // Primitive value
        if parentArrayFields.contains(key) {
            return [value]
        }
        return value
    }
    
    /// Known array fields for FHIR resource types and complex types
    private static func fhirArrayFields(for typeOrField: String) -> Set<String> {
        switch typeOrField.lowercased() {
        // Resource types
        case "patient":
            return ["identifier", "name", "telecom", "address", "contact", "communication",
                    "generalPractitioner", "contained", "extension", "modifierExtension", "link",
                    "photo"]
        case "observation":
            return ["identifier", "basedOn", "partOf", "category", "focus", "performer",
                    "interpretation", "note", "referenceRange", "hasMember", "derivedFrom",
                    "component", "contained", "extension", "modifierExtension"]
        case "practitioner":
            return ["identifier", "name", "telecom", "address", "qualification",
                    "communication", "contained", "extension", "modifierExtension", "photo"]
        case "medicationrequest":
            return ["identifier", "instantiatesCanonical", "instantiatesUri", "basedOn",
                    "category", "supportingInformation", "insurance", "note", "dosageInstruction",
                    "detectedIssue", "eventHistory", "contained", "extension", "modifierExtension",
                    "reasonCode", "reasonReference"]
        case "bundle":
            return ["entry", "link", "contained", "extension", "modifierExtension"]
        case "encounter":
            return ["identifier", "statusHistory", "classHistory", "type", "episodeOfCare",
                    "basedOn", "participant", "reasonCode", "reasonReference", "diagnosis",
                    "account", "location", "contained", "extension", "modifierExtension"]
        // Complex types
        case "name", "humanname":
            return ["given", "prefix", "suffix", "extension"]
        case "identifier":
            return ["extension"]
        case "codeableconcept":
            return ["coding", "extension"]
        case "address":
            return ["line", "extension"]
        case "contactpoint":
            return ["extension"]
        case "coding":
            return ["extension"]
        case "reference":
            return ["extension"]
        case "quantity":
            return ["extension"]
        case "period":
            return ["extension"]
        case "narrative":
            return ["extension"]
        case "meta":
            return ["profile", "security", "tag", "extension"]
        case "extension":
            return ["extension"]
        case "dosage", "dosageinstruction":
            return ["additionalInstruction", "extension"]
        default:
            return ["extension", "modifierExtension", "contained"]
        }
    }
}

// MARK: - XML Parser Delegate

private class FHIRXMLParserDelegate: NSObject, XMLParserDelegate {
    var result: [String: Any]?
    private var stack: [[String: Any]] = []
    private var currentElement: String?
    private var currentValue: String = ""
    private var currentAttributes: [String: String]?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""
        currentAttributes = attributes.isEmpty ? nil : attributes
        
        var element: [String: Any] = [:]
        if !attributes.isEmpty {
            for (key, value) in attributes {
                element[key] = value
            }
        }
        stack.append(element)
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard var element = stack.popLast() else { return }
        
        // Add text content if present
        if !currentValue.isEmpty {
            if let valueAttr = currentAttributes?["value"] {
                element["value"] = valueAttr
            } else {
                element["text"] = currentValue
            }
        }
        
        if stack.isEmpty {
            // Root element
            result = [elementName: element]
        } else {
            // Add to parent
            if var parent = stack.popLast() {
                if var existing = parent[elementName] as? [[String: Any]] {
                    existing.append(element)
                    parent[elementName] = existing
                } else if let existing = parent[elementName] as? [String: Any] {
                    parent[elementName] = [existing, element]
                } else {
                    parent[elementName] = element
                }
                stack.append(parent)
            }
        }
        
        currentValue = ""
        currentAttributes = nil
    }
}

// MARK: - Convenience Functions

/// Global convenience functions for FHIR XML serialization
public enum FHIRXML {
    /// Encode a FHIR resource to XML data
    public static func encode<T: Encodable & Sendable>(_ resource: T, configuration: FHIRSerializationConfiguration = .default) async throws -> Data {
        let serializer = FHIRXMLSerializer(configuration: configuration)
        return try await serializer.encode(resource)
    }
    
    /// Encode a FHIR resource to XML string
    public static func encodeToString<T: Encodable & Sendable>(_ resource: T, configuration: FHIRSerializationConfiguration = .default) async throws -> String {
        let serializer = FHIRXMLSerializer(configuration: configuration)
        return try await serializer.encodeToString(resource)
    }
    
    /// Decode FHIR resource from XML data
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data, configuration: FHIRSerializationConfiguration = .default) async throws -> T {
        let serializer = FHIRXMLSerializer(configuration: configuration)
        return try await serializer.decode(type, from: data)
    }
    
    /// Decode FHIR resource from XML string
    public static func decode<T: Decodable & Sendable>(_ type: T.Type, from string: String, configuration: FHIRSerializationConfiguration = .default) async throws -> T {
        let serializer = FHIRXMLSerializer(configuration: configuration)
        return try await serializer.decode(type, from: string)
    }
    
    /// Decode FHIR resource container (polymorphic)
    public static func decodeResource(from data: Data, configuration: FHIRSerializationConfiguration = .default) async throws -> ResourceContainer {
        let serializer = FHIRXMLSerializer(configuration: configuration)
        return try await serializer.decodeResource(from: data)
    }
}
