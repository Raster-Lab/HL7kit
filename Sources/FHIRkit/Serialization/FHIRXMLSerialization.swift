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
        
        if let stringValue = value as? String {
            return "\(indentString)<\(name) value=\"\(escapeXML(stringValue))\"/>\n"
        } else if let numberValue = value as? NSNumber {
            return "\(indentString)<\(name) value=\"\(numberValue)\"/>\n"
        } else if let boolValue = value as? Bool {
            return "\(indentString)<\(name) value=\"\(boolValue)\"/>\n"
        } else if let arrayValue = value as? [Any] {
            var result = ""
            for item in arrayValue {
                if let dictItem = item as? [String: Any] {
                    result += "\(indentString)<\(name)>\n"
                    for (key, val) in dictItem {
                        result += buildElement(name: key, value: val, indent: indent + 1)
                    }
                    result += "\(indentString)</\(name)>\n"
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
        
        guard let jsonObject = delegate.result else {
            throw FHIRSerializationError.invalidXML("Failed to build JSON structure from XML")
        }
        
        // Convert to JSON data
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [])
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
