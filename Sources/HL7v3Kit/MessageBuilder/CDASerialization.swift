/// CDASerialization.swift
/// Integration between CDA document builder and XML serialization
///
/// This file provides utilities for serializing CDA documents to XML format
/// using the existing HL7v3XMLParser infrastructure.

import Foundation
import HL7Core

// MARK: - CDA Document Serialization

extension ClinicalDocument {
    /// Converts the CDA document to XML format
    /// - Parameters:
    ///   - prettyPrint: Whether to format the XML with indentation (default: true)
    ///   - includeXMLDeclaration: Whether to include XML declaration (default: true)
    /// - Returns: XML string representation of the document
    /// - Throws: SerializationError if conversion fails
    public func toXML(prettyPrint: Bool = true, includeXMLDeclaration: Bool = true) throws -> String {
        let element = try toXMLElement()
        let document = XMLDocument(root: element, xmlVersion: "1.0", encoding: "UTF-8")
        
        let serializer = HL7v3XMLSerializer(prettyPrint: prettyPrint)
        var xmlString = serializer.serializeToString(document)
        
        if includeXMLDeclaration && !xmlString.hasPrefix("<?xml") {
            xmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + xmlString
        }
        
        return xmlString
    }
    
    /// Converts the CDA document to XML Data
    /// - Parameters:
    ///   - prettyPrint: Whether to format the XML with indentation (default: true)
    /// - Returns: XML data representation of the document
    /// - Throws: SerializationError if conversion fails
    public func toXMLData(prettyPrint: Bool = true) throws -> Data {
        let xmlString = try toXML(prettyPrint: prettyPrint, includeXMLDeclaration: true)
        guard let data = xmlString.data(using: .utf8) else {
            throw SerializationError.encodingFailed("Failed to convert XML string to UTF-8 data")
        }
        return data
    }
    
    /// Converts the CDA document to XMLElement for serialization
    /// - Returns: XMLElement representation of the document
    /// - Throws: SerializationError if conversion fails
    private func toXMLElement() throws -> XMLElement {
        var attributes: [String: String] = [:]
        
        // Add namespace declaration
        attributes["xmlns"] = "urn:hl7-org:v3"
        attributes["xmlns:xsi"] = "http://www.w3.org/2001/XMLSchema-instance"
        
        // Add class code and mood code
        attributes["classCode"] = classCode.rawValue
        attributes["moodCode"] = moodCode.rawValue
        
        var children: [XMLElement] = []
        
        // Realm code
        if let realmCodes = realmCode {
            for rc in realmCodes {
                children.append(rc.toXMLElement(name: "realmCode"))
            }
        }
        
        // Type ID
        children.append(typeId.toXMLElement(name: "typeId"))
        
        // Template IDs
        for template in templateId {
            children.append(template.toXMLElement(name: "templateId"))
        }
        
        // Document ID
        children.append(id.toXMLElement(name: "id"))
        
        // Code
        children.append(code.toXMLElement(name: "code"))
        
        // Title
        if let title = title {
            children.append(title.toXMLElement(name: "title"))
        }
        
        // Effective time
        children.append(effectiveTime.toXMLElement(name: "effectiveTime"))
        
        // Confidentiality code
        children.append(confidentialityCode.toXMLElement(name: "confidentialityCode"))
        
        // Language code
        if let languageCode = languageCode {
            children.append(languageCode.toXMLElement(name: "languageCode"))
        }
        
        // Set ID
        if let setId = setId {
            children.append(setId.toXMLElement(name: "setId"))
        }
        
        // Version number
        if let versionNumber = versionNumber {
            children.append(versionNumber.toXMLElement(name: "versionNumber"))
        }
        
        // Copy time
        if let copyTime = copyTime {
            children.append(copyTime.toXMLElement(name: "copyTime"))
        }
        
        // Record targets
        for rt in recordTarget {
            children.append(rt.toXMLElement())
        }
        
        // Authors
        for author in author {
            children.append(author.toXMLElement())
        }
        
        // Data enterer
        if let dataEnterer = dataEnterer {
            children.append(dataEnterer.toXMLElement())
        }
        
        // Informants
        if let informants = informant {
            for informant in informants {
                children.append(informant.toXMLElement())
            }
        }
        
        // Custodian
        children.append(custodian.toXMLElement())
        
        // Information recipients
        if let recipients = informationRecipient {
            for recipient in recipients {
                children.append(recipient.toXMLElement())
            }
        }
        
        // Legal authenticator
        if let legalAuthenticator = legalAuthenticator {
            children.append(legalAuthenticator.toXMLElement())
        }
        
        // Authenticators
        if let authenticators = authenticator {
            for auth in authenticators {
                children.append(auth.toXMLElement())
            }
        }
        
        // Component (body)
        children.append(component.toXMLElement())
        
        return XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: attributes,
            children: children
        )
    }
}

// MARK: - Serialization Error

/// Errors that can occur during CDA serialization
public enum SerializationError: Error, CustomStringConvertible {
    case encodingFailed(String)
    case missingRequiredElement(String)
    case invalidStructure(String)
    
    public var description: String {
        switch self {
        case .encodingFailed(let message):
            return "Encoding failed: \(message)"
        case .missingRequiredElement(let element):
            return "Missing required element: \(element)"
        case .invalidStructure(let message):
            return "Invalid structure: \(message)"
        }
    }
}

// MARK: - XML Element Conversion Extensions

// These extensions provide toXMLElement() methods for all CDA types
// This is a simplified implementation - a full implementation would be more comprehensive

extension II {
    func toXMLElement(name: String) -> XMLElement {
        var attributes: [String: String] = [:]
        if let nullFlavor = nullFlavor {
            attributes["nullFlavor"] = nullFlavor.rawValue
        } else {
            attributes["root"] = root
            if let ext = self.extension {
                attributes["extension"] = ext
            }
            if let assigningAuthority = assigningAuthorityName {
                attributes["assigningAuthorityName"] = assigningAuthority
            }
        }
        return XMLElement(name: name, namespace: "urn:hl7-org:v3", attributes: attributes)
    }
}

extension CD {
    func toXMLElement(name: String) -> XMLElement {
        var attributes: [String: String] = [:]
        if let nullFlavor = nullFlavor {
            attributes["nullFlavor"] = nullFlavor.rawValue
        } else {
            if let code = code {
                attributes["code"] = code
            }
            if let codeSystem = codeSystem {
                attributes["codeSystem"] = codeSystem
            }
            if let codeSystemName = codeSystemName {
                attributes["codeSystemName"] = codeSystemName
            }
            if let displayName = displayName {
                attributes["displayName"] = displayName
            }
        }
        return XMLElement(name: name, namespace: "urn:hl7-org:v3", attributes: attributes)
    }
}

extension ST {
    func toXMLElement(name: String) -> XMLElement {
        if case .value(let str) = self {
            return XMLElement(name: name, namespace: "urn:hl7-org:v3", text: str)
        } else if case .nullFlavor(let nf) = self {
            return XMLElement(
                name: name,
                namespace: "urn:hl7-org:v3",
                attributes: ["nullFlavor": nf.rawValue]
            )
        }
        return XMLElement(name: name, namespace: "urn:hl7-org:v3")
    }
}

extension TS {
    func toXMLElement(name: String) -> XMLElement {
        var attributes: [String: String] = [:]
        if let nullFlavor = nullFlavor {
            attributes["nullFlavor"] = nullFlavor.rawValue
        } else if let value = value {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withTimeZone]
            attributes["value"] = formatter.string(from: value).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        }
        return XMLElement(name: name, namespace: "urn:hl7-org:v3", attributes: attributes)
    }
}

extension INT {
    func toXMLElement(name: String) -> XMLElement {
        if case .value(let int) = self {
            return XMLElement(
                name: name,
                namespace: "urn:hl7-org:v3",
                attributes: ["value": String(int)]
            )
        } else if case .nullFlavor(let nf) = self {
            return XMLElement(
                name: name,
                namespace: "urn:hl7-org:v3",
                attributes: ["nullFlavor": nf.rawValue]
            )
        }
        return XMLElement(name: name, namespace: "urn:hl7-org:v3")
    }
}

// Placeholder implementations for complex types
// A full implementation would recursively serialize all nested elements

extension RecordTarget {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "recordTarget", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "RCT"])
    }
}

extension Author {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "author", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "AUT"])
    }
}

extension Custodian {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "custodian", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "CST"])
    }
}

extension DataEnterer {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "dataEnterer", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "ENT"])
    }
}

extension Informant {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "informant", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "INF"])
    }
}

extension InformationRecipient {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "informationRecipient", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "PRCP"])
    }
}

extension LegalAuthenticator {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "legalAuthenticator", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "LA"])
    }
}

extension Authenticator {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "authenticator", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "AUTHEN"])
    }
}

extension DocumentComponent {
    func toXMLElement() -> XMLElement {
        return XMLElement(name: "component", namespace: "urn:hl7-org:v3", attributes: ["typeCode": "COMP"])
    }
}
