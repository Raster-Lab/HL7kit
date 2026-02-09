/// XMLInspector.swift
/// XML Message Inspector/Debugger for HL7 v3.x
///
/// Provides tools for inspecting, navigating, and analyzing XML messages and CDA documents.
/// Features include tree view display, statistics, search, and CDA-specific analysis.

import Foundation
import HL7Core

// MARK: - XML Inspector

/// A comprehensive XML message inspector and debugger
///
/// The XMLInspector provides tools for analyzing XML documents, with special support
/// for HL7 v3.x and CDA documents. It offers tree view display, statistics,
/// element navigation, and search capabilities.
public actor XMLInspector: Sendable {
    /// Configuration options for the inspector
    public struct Configuration: Sendable {
        /// Maximum depth to display in tree view
        public var maxDepth: Int
        
        /// Whether to show attributes in tree view
        public var showAttributes: Bool
        
        /// Whether to show text content in tree view
        public var showText: Bool
        
        /// Whether to highlight CDA-specific elements
        public var highlightCDA: Bool
        
        /// Indentation string for tree view
        public var indentation: String
        
        /// Maximum text length before truncation
        public var maxTextLength: Int
        
        /// Creates a new configuration with default values
        public init(
            maxDepth: Int = Int.max,
            showAttributes: Bool = true,
            showText: Bool = true,
            highlightCDA: Bool = true,
            indentation: String = "  ",
            maxTextLength: Int = 100
        ) {
            self.maxDepth = maxDepth
            self.showAttributes = showAttributes
            self.showText = showText
            self.highlightCDA = highlightCDA
            self.indentation = indentation
            self.maxTextLength = maxTextLength
        }
    }
    
    /// Statistics about an XML document
    public struct Statistics: Sendable {
        /// Total number of elements
        public let elementCount: Int
        
        /// Total number of attributes
        public let attributeCount: Int
        
        /// Maximum depth of the document
        public let maxDepth: Int
        
        /// Number of elements with text content
        public let textElementCount: Int
        
        /// Total size of text content (in characters)
        public let totalTextLength: Int
        
        /// Number of namespace declarations
        public let namespaceCount: Int
        
        /// Top 10 most common element names
        public let topElements: [(name: String, count: Int)]
        
        /// Average children per element
        public let avgChildrenPerElement: Double
    }
    
    /// CDA-specific inspection results
    public struct CDAInspection: Sendable {
        /// Whether this appears to be a valid CDA document
        public let isCDADocument: Bool
        
        /// CDA document type (from code element)
        public let documentType: String?
        
        /// Template IDs found
        public let templateIds: [String]
        
        /// Number of sections
        public let sectionCount: Int
        
        /// Number of entries
        public let entryCount: Int
        
        /// Number of participants
        public let participantCount: Int
        
        /// Language code
        public let languageCode: String?
        
        /// Conformance level (1, 2, or 3)
        public let conformanceLevel: Int?
    }
    
    private let configuration: Configuration
    
    /// Creates a new XML inspector
    /// - Parameter configuration: Configuration options
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Tree View Display
    
    /// Generates a tree view representation of an XML element
    /// - Parameter element: The root element to display
    /// - Returns: A formatted tree view string
    public func treeView(element: XMLElement) -> String {
        var output = ""
        renderTree(element: element, depth: 0, output: &output)
        return output
    }
    
    private func renderTree(element: XMLElement, depth: Int, output: inout String) {
        guard depth < configuration.maxDepth else {
            output += "\(indent(depth))...\n"
            return
        }
        
        // Element name with highlighting
        let elementName = formatElementName(element)
        output += "\(indent(depth))\(elementName)"
        
        // Attributes
        if configuration.showAttributes && !element.attributes.isEmpty {
            let attrs = element.attributes.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
            output += " [\(attrs)]"
        }
        
        output += "\n"
        
        // Text content
        if configuration.showText, let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            let truncated = truncateText(text)
            output += "\(indent(depth + 1))📝 \(truncated)\n"
        }
        
        // Children
        for child in element.children {
            renderTree(element: child, depth: depth + 1, output: &output)
        }
    }
    
    private func indent(_ depth: Int) -> String {
        String(repeating: configuration.indentation, count: depth)
    }
    
    private func formatElementName(_ element: XMLElement) -> String {
        let name: String
        if let prefix = element.prefix {
            name = "\(prefix):\(element.name)"
        } else {
            name = element.name
        }
        
        // Highlight CDA-specific elements
        if configuration.highlightCDA {
            switch element.name {
            case "ClinicalDocument":
                return "🏥 \(name)"
            case "section":
                return "📋 \(name)"
            case "entry":
                return "📌 \(name)"
            case "observation", "procedure", "substanceAdministration":
                return "💊 \(name)"
            case "patient", "author", "custodian":
                return "👤 \(name)"
            default:
                return name
            }
        }
        
        return name
    }
    
    private func truncateText(_ text: String) -> String {
        if text.count <= configuration.maxTextLength {
            return text
        }
        let truncated = String(text.prefix(configuration.maxTextLength))
        return "\(truncated)..."
    }
    
    // MARK: - Statistics
    
    /// Computes statistics for an XML document
    /// - Parameter element: The root element
    /// - Returns: Document statistics
    public func computeStatistics(element: XMLElement) -> Statistics {
        var elementCount = 0
        var attributeCount = 0
        var maxDepth = 0
        var textElementCount = 0
        var totalTextLength = 0
        var namespaces = Set<String>()
        var elementNames: [String: Int] = [:]
        var totalChildren = 0
        
        func traverse(element: XMLElement, depth: Int) {
            elementCount += 1
            attributeCount += element.attributes.count
            maxDepth = max(maxDepth, depth)
            
            if let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                textElementCount += 1
                totalTextLength += text.count
            }
            
            if let ns = element.namespace {
                namespaces.insert(ns)
            }
            
            elementNames[element.name, default: 0] += 1
            
            if !element.children.isEmpty {
                totalChildren += element.children.count
            }
            
            for child in element.children {
                traverse(element: child, depth: depth + 1)
            }
        }
        
        traverse(element: element, depth: 0)
        
        let topElements = elementNames
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (name: $0.key, count: $0.value) }
        
        let avgChildren = elementCount > 0 ? Double(totalChildren) / Double(elementCount) : 0
        
        return Statistics(
            elementCount: elementCount,
            attributeCount: attributeCount,
            maxDepth: maxDepth,
            textElementCount: textElementCount,
            totalTextLength: totalTextLength,
            namespaceCount: namespaces.count,
            topElements: topElements,
            avgChildrenPerElement: avgChildren
        )
    }
    
    // MARK: - CDA-Specific Inspection
    
    /// Performs CDA-specific inspection
    /// - Parameter element: The root element (should be ClinicalDocument)
    /// - Returns: CDA inspection results
    public func inspectCDA(element: XMLElement) -> CDAInspection {
        let isCDADocument = element.name == "ClinicalDocument"
        
        var documentType: String?
        var templateIds: [String] = []
        var sectionCount = 0
        var entryCount = 0
        var participantCount = 0
        var languageCode: String?
        
        // Extract document type from code element
        if let codeElement = findElement(named: "code", in: element) {
            documentType = codeElement.attributes["displayName"] ?? codeElement.attributes["code"]
        }
        
        // Extract template IDs
        let templateElements = findElements(named: "templateId", in: element)
        templateIds = templateElements.compactMap { $0.attributes["root"] }
        
        // Count sections and entries
        func countStructures(element: XMLElement) {
            if element.name == "section" {
                sectionCount += 1
            }
            if element.name == "entry" {
                entryCount += 1
            }
            if ["author", "custodian", "legalAuthenticator", "authenticator", "recordTarget",
                "dataEnterer", "informant", "informationRecipient"].contains(element.name) {
                participantCount += 1
            }
            
            for child in element.children {
                countStructures(element: child)
            }
        }
        
        countStructures(element: element)
        
        // Extract language code
        if let langElement = findElement(named: "languageCode", in: element) {
            languageCode = langElement.attributes["code"]
        }
        
        // Determine conformance level
        let conformanceLevel = determineConformanceLevel(element: element)
        
        return CDAInspection(
            isCDADocument: isCDADocument,
            documentType: documentType,
            templateIds: templateIds,
            sectionCount: sectionCount,
            entryCount: entryCount,
            participantCount: participantCount,
            languageCode: languageCode,
            conformanceLevel: conformanceLevel
        )
    }
    
    private func determineConformanceLevel(element: XMLElement) -> Int? {
        // Level 1: Must have narrative text
        // Level 2: Must have coded entries
        // Level 3: Must have structured entries with data types
        
        let hasNarrative = findElement(named: "text", in: element) != nil
        let hasEntry = findElement(named: "entry", in: element) != nil
        
        if hasEntry {
            // Check for structured entries with proper data types
            if let entry = findElement(named: "entry", in: element),
               hasStructuredEntry(entry) {
                return 3
            }
            return 2
        }
        
        if hasNarrative {
            return 1
        }
        
        return nil
    }
    
    private func hasStructuredEntry(_ element: XMLElement) -> Bool {
        // Look for observation/procedure with proper structure
        for child in element.children {
            if ["observation", "procedure", "substanceAdministration"].contains(child.name) {
                // Check for required structured elements
                if findElement(named: "code", in: child) != nil,
                   findElement(named: "statusCode", in: child) != nil {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Search and Navigation
    
    /// Finds all elements with the specified name
    /// - Parameters:
    ///   - name: Element name to search for
    ///   - element: Root element to search in
    /// - Returns: Array of matching elements
    public func findElements(named name: String, in element: XMLElement) -> [XMLElement] {
        var results: [XMLElement] = []
        
        func search(element: XMLElement) {
            if element.name == name {
                results.append(element)
            }
            for child in element.children {
                search(element: child)
            }
        }
        
        search(element: element)
        return results
    }
    
    /// Finds the first element with the specified name
    /// - Parameters:
    ///   - name: Element name to search for
    ///   - element: Root element to search in
    /// - Returns: The first matching element, if found
    public func findElement(named name: String, in element: XMLElement) -> XMLElement? {
        if element.name == name {
            return element
        }
        
        for child in element.children {
            if let found = findElement(named: name, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    /// Searches for elements containing the specified text
    /// - Parameters:
    ///   - text: Text to search for
    ///   - element: Root element to search in
    /// - Returns: Array of elements containing the text
    public func searchText(_ searchText: String, in element: XMLElement) -> [XMLElement] {
        var results: [XMLElement] = []
        
        func search(element: XMLElement) {
            if let text = element.text,
               text.localizedCaseInsensitiveContains(searchText) {
                results.append(element)
            }
            for child in element.children {
                search(element: child)
            }
        }
        
        search(element: element)
        return results
    }
    
    // MARK: - Pretty Print
    
    /// Formats an element as pretty-printed XML
    /// - Parameter element: The element to format
    /// - Returns: Pretty-printed XML string
    public func prettyPrint(element: XMLElement) -> String {
        var output = ""
        formatXML(element: element, depth: 0, output: &output)
        return output
    }
    
    private func formatXML(element: XMLElement, depth: Int, output: inout String) {
        let indent = String(repeating: "  ", count: depth)
        
        // Opening tag
        output += "\(indent)<"
        if let prefix = element.prefix {
            output += "\(prefix):"
        }
        output += element.name
        
        // Attributes
        for (key, value) in element.attributes.sorted(by: { $0.key < $1.key }) {
            output += " \(key)=\"\(escapeXML(value))\""
        }
        
        // Self-closing or with content
        if element.children.isEmpty && element.text == nil {
            output += "/>\n"
        } else {
            output += ">"
            
            // Text content (on same line if short)
            if let text = element.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                if text.count < 80 && element.children.isEmpty {
                    output += escapeXML(text)
                } else {
                    output += "\n\(indent)  \(escapeXML(text))\n"
                }
            }
            
            // Children
            if !element.children.isEmpty {
                output += "\n"
                for child in element.children {
                    formatXML(element: child, depth: depth + 1, output: &output)
                }
                output += indent
            }
            
            // Closing tag
            output += "</"
            if let prefix = element.prefix {
                output += "\(prefix):"
            }
            output += "\(element.name)>\n"
        }
    }
    
    private func escapeXML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    // MARK: - Metadata Display
    
    /// Generates a comprehensive inspection report
    /// - Parameter element: The element to inspect
    /// - Returns: A formatted report string
    public func generateReport(element: XMLElement) -> String {
        let stats = computeStatistics(element: element)
        let cdaInfo = inspectCDA(element: element)
        
        var report = """
        ═══════════════════════════════════════════════════════════
        XML INSPECTION REPORT
        ═══════════════════════════════════════════════════════════
        
        GENERAL STATISTICS:
        ───────────────────────────────────────────────────────────
        Elements:           \(stats.elementCount)
        Attributes:         \(stats.attributeCount)
        Max Depth:          \(stats.maxDepth)
        Text Elements:      \(stats.textElementCount)
        Total Text Length:  \(stats.totalTextLength) chars
        Namespaces:         \(stats.namespaceCount)
        Avg Children:       \(String(format: "%.2f", stats.avgChildrenPerElement))
        
        TOP ELEMENTS:
        ───────────────────────────────────────────────────────────
        """
        
        for (name, count) in stats.topElements {
            report += "\n  \(name.padding(toLength: 30, withPad: " ", startingAt: 0)) \(count)"
        }
        
        if cdaInfo.isCDADocument {
            report += """
            
            
            CDA DOCUMENT INFORMATION:
            ───────────────────────────────────────────────────────────
            Document Type:      \(cdaInfo.documentType ?? "Unknown")
            Language:           \(cdaInfo.languageCode ?? "Not specified")
            Conformance Level:  \(cdaInfo.conformanceLevel.map { "Level \($0)" } ?? "Unknown")
            Sections:           \(cdaInfo.sectionCount)
            Entries:            \(cdaInfo.entryCount)
            Participants:       \(cdaInfo.participantCount)
            
            TEMPLATE IDs:
            ───────────────────────────────────────────────────────────
            """
            
            if cdaInfo.templateIds.isEmpty {
                report += "\n  (No template IDs found)"
            } else {
                for templateId in cdaInfo.templateIds {
                    report += "\n  • \(templateId)"
                }
            }
        }
        
        report += "\n═══════════════════════════════════════════════════════════\n"
        
        return report
    }
}

// MARK: - XMLElement Extension for Inspector Support

extension XMLElement {
    /// Convenience method to get a tree view of this element
    public func treeView(configuration: XMLInspector.Configuration = .init()) async -> String {
        let inspector = XMLInspector(configuration: configuration)
        return await inspector.treeView(element: self)
    }
    
    /// Convenience method to get statistics for this element
    public func statistics() async -> XMLInspector.Statistics {
        let inspector = XMLInspector()
        return await inspector.computeStatistics(element: self)
    }
    
    /// Convenience method to inspect as CDA document
    public func inspectCDA() async -> XMLInspector.CDAInspection {
        let inspector = XMLInspector()
        return await inspector.inspectCDA(element: self)
    }
    
    /// Convenience method to generate a full inspection report
    public func inspectionReport() async -> String {
        let inspector = XMLInspector()
        return await inspector.generateReport(element: self)
    }
}
