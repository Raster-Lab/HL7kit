/// HL7v3XMLParser - XML parsing, validation, querying, and serialization for HL7 v3.x messages
///
/// Provides a DOM-like XML representation, streaming XML parser using Foundation's XMLParser,
/// HL7 v3 schema validation, XPath-like query support, and XML serialization.
/// All types are `Sendable` for Swift 6 strict concurrency safety.

import Foundation
import HL7Core

#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - XML Namespace

/// Represents an XML namespace with prefix and URI
public struct XMLNamespace: Sendable, Equatable, Hashable {
    /// The namespace prefix (e.g., "hl7")
    public let prefix: String?

    /// The namespace URI (e.g., "urn:hl7-org:v3")
    public let uri: String

    /// Creates a new XML namespace
    /// - Parameters:
    ///   - prefix: The namespace prefix, or nil for the default namespace
    ///   - uri: The namespace URI
    public init(prefix: String? = nil, uri: String) {
        self.prefix = prefix
        self.uri = uri
    }
}

// MARK: - Common HL7 v3 Namespace Constants

extension XMLNamespace {
    /// The HL7 v3 namespace (`urn:hl7-org:v3`)
    public static let hl7v3 = XMLNamespace(prefix: nil, uri: "urn:hl7-org:v3")

    /// The HL7 v3 namespace with explicit prefix
    public static let hl7v3Prefixed = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")

    /// The XML Schema Instance namespace
    public static let xsi = XMLNamespace(
        prefix: "xsi", uri: "http://www.w3.org/2001/XMLSchema-instance"
    )

    /// The SDTC (Structured Document Template Collection) extension namespace
    public static let sdtc = XMLNamespace(
        prefix: "sdtc", uri: "urn:hl7-org:sdtc"
    )

    /// The XML namespace for xml:lang etc.
    public static let xml = XMLNamespace(
        prefix: "xml", uri: "http://www.w3.org/XML/1998/namespace"
    )

    /// The XLink namespace
    public static let xlink = XMLNamespace(
        prefix: "xlink", uri: "http://www.w3.org/1999/xlink"
    )
}

// MARK: - XMLElement

/// A DOM-like representation of an XML element
public struct XMLElement: Sendable, Equatable {
    /// The local name of the element (without namespace prefix)
    public let name: String

    /// The namespace URI of the element, if any
    public let namespace: String?

    /// The namespace prefix of the element, if any
    public let prefix: String?

    /// The element's attributes as key-value pairs
    public var attributes: [String: String]

    /// The child elements
    public var children: [XMLElement]

    /// The text content of the element (direct text, not including child text)
    public var text: String?

    /// Creates a new XML element
    /// - Parameters:
    ///   - name: The local name
    ///   - namespace: The namespace URI
    ///   - prefix: The namespace prefix
    ///   - attributes: The element attributes
    ///   - children: The child elements
    ///   - text: The text content
    public init(
        name: String,
        namespace: String? = nil,
        prefix: String? = nil,
        attributes: [String: String] = [:],
        children: [XMLElement] = [],
        text: String? = nil
    ) {
        self.name = name
        self.namespace = namespace
        self.prefix = prefix
        self.attributes = attributes
        self.children = children
        self.text = text
    }

    // MARK: - Computed Properties

    /// The qualified name including prefix (e.g., "hl7:ClinicalDocument")
    public var qualifiedName: String {
        if let prefix = prefix, !prefix.isEmpty {
            return "\(prefix):\(name)"
        }
        return name
    }

    // MARK: - Query Methods

    /// Returns the value of the attribute with the given name
    /// - Parameter name: The attribute name
    /// - Returns: The attribute value, or nil if not found
    public func attributeValue(forName name: String) -> String? {
        return attributes[name]
    }

    /// Returns child elements matching the given local name
    /// - Parameter name: The local name to match
    /// - Returns: Matching child elements
    public func childElements(named name: String) -> [XMLElement] {
        return children.filter { $0.name == name }
    }

    /// Returns the first child element matching the given local name
    /// - Parameter name: The local name to match
    /// - Returns: The first matching child element, or nil
    public func firstChild(named name: String) -> XMLElement? {
        return children.first { $0.name == name }
    }

    /// Recursively finds all descendant elements matching the given local name
    /// - Parameter name: The local name to match
    /// - Returns: All matching descendant elements (depth-first)
    public func findElements(byName name: String) -> [XMLElement] {
        var results: [XMLElement] = []
        findElementsRecursive(byName: name, results: &results)
        return results
    }

    private func findElementsRecursive(byName name: String, results: inout [XMLElement]) {
        for child in children {
            if child.name == name {
                results.append(child)
            }
            child.findElementsRecursive(byName: name, results: &results)
        }
    }

    /// Finds all descendant elements matching both namespace URI and local name
    /// - Parameters:
    ///   - namespace: The namespace URI to match
    ///   - name: The local name to match
    /// - Returns: All matching descendant elements
    public func findElements(byNamespace namespace: String, name: String) -> [XMLElement] {
        var results: [XMLElement] = []
        findElementsRecursive(byNamespace: namespace, name: name, results: &results)
        return results
    }

    private func findElementsRecursive(
        byNamespace namespace: String, name: String, results: inout [XMLElement]
    ) {
        for child in children {
            if child.name == name && child.namespace == namespace {
                results.append(child)
            }
            child.findElementsRecursive(byNamespace: namespace, name: name, results: &results)
        }
    }

    /// Returns all text content from this element and all descendants, concatenated
    public var allText: String {
        var result = text ?? ""
        for child in children {
            result += child.allText
        }
        return result
    }
}

// MARK: - XMLDocument

/// A DOM-like representation of an XML document
public struct XMLDocument: Sendable, Equatable {
    /// The root element of the document
    public let root: XMLElement?

    /// The XML version (e.g., "1.0")
    public let xmlVersion: String

    /// The character encoding (e.g., "UTF-8")
    public let encoding: String

    /// Creates a new XML document
    /// - Parameters:
    ///   - root: The root element
    ///   - xmlVersion: The XML version string
    ///   - encoding: The document encoding
    public init(root: XMLElement? = nil, xmlVersion: String = "1.0", encoding: String = "UTF-8") {
        self.root = root
        self.xmlVersion = xmlVersion
        self.encoding = encoding
    }

    /// Returns all elements matching the given local name (searches entire document)
    /// - Parameter name: The local name to match
    /// - Returns: All matching elements
    public func findElements(byName name: String) -> [XMLElement] {
        guard let root = root else { return [] }
        var results: [XMLElement] = []
        if root.name == name {
            results.append(root)
        }
        results.append(contentsOf: root.findElements(byName: name))
        return results
    }

    /// Returns all elements matching the given namespace and local name
    /// - Parameters:
    ///   - namespace: The namespace URI
    ///   - name: The local name
    /// - Returns: All matching elements
    public func findElements(byNamespace namespace: String, name: String) -> [XMLElement] {
        guard let root = root else { return [] }
        var results: [XMLElement] = []
        if root.name == name && root.namespace == namespace {
            results.append(root)
        }
        results.append(contentsOf: root.findElements(byNamespace: namespace, name: name))
        return results
    }
}

// MARK: - Parser Configuration

/// Configuration options for the XML parser
public struct XMLParserConfiguration: Sendable, Equatable {
    /// Whether to validate namespace URIs during parsing
    public var validateNamespaces: Bool

    /// Whether to resolve external entities (default false for security)
    public var resolveExternalEntities: Bool

    /// Maximum allowed nesting depth to prevent stack overflow
    public var maxDepth: Int

    /// Maximum allowed document size in bytes to prevent memory exhaustion
    public var maxDocumentSize: Int

    /// Creates a parser configuration with the given options
    /// - Parameters:
    ///   - validateNamespaces: Whether to validate namespaces
    ///   - resolveExternalEntities: Whether to resolve external entities
    ///   - maxDepth: Maximum element nesting depth
    ///   - maxDocumentSize: Maximum document size in bytes
    public init(
        validateNamespaces: Bool = true,
        resolveExternalEntities: Bool = false,
        maxDepth: Int = 256,
        maxDocumentSize: Int = 50 * 1024 * 1024
    ) {
        self.validateNamespaces = validateNamespaces
        self.resolveExternalEntities = resolveExternalEntities
        self.maxDepth = maxDepth
        self.maxDocumentSize = maxDocumentSize
    }

    /// Default configuration suitable for most HL7 v3 documents
    public static let `default` = XMLParserConfiguration()

    /// Strict configuration with namespace validation and conservative limits
    public static let strict = XMLParserConfiguration(
        validateNamespaces: true,
        resolveExternalEntities: false,
        maxDepth: 128,
        maxDocumentSize: 10 * 1024 * 1024
    )
}

// MARK: - Parse Diagnostics

/// Severity level for parse diagnostics
public enum XMLDiagnosticSeverity: String, Sendable, Equatable {
    case warning
    case error
    case fatal
}

/// A diagnostic message from the XML parser
public struct XMLDiagnostic: Sendable, Equatable {
    /// The severity of the diagnostic
    public let severity: XMLDiagnosticSeverity

    /// A human-readable description of the issue
    public let message: String

    /// The line number where the issue was found (1-based)
    public let line: Int

    /// The column number where the issue was found (1-based)
    public let column: Int

    /// Creates a new parse diagnostic
    public init(severity: XMLDiagnosticSeverity, message: String, line: Int, column: Int) {
        self.severity = severity
        self.message = message
        self.line = line
        self.column = column
    }
}

// MARK: - HL7v3XMLParser

/// Streaming XML parser that uses Foundation's XMLParser to build a DOM-like XMLDocument
///
/// Handles namespace-aware parsing with configurable depth and size limits.
/// Thread-safe and `Sendable`-conformant for use across concurrency domains.
///
/// Example usage:
/// ```swift
/// let parser = HL7v3XMLParser()
/// let document = try parser.parse(xmlData)
/// ```
public struct HL7v3XMLParser: Sendable {
    /// The parser configuration
    public let configuration: XMLParserConfiguration

    /// Creates a parser with the given configuration
    /// - Parameter configuration: The parser configuration
    public init(configuration: XMLParserConfiguration = .default) {
        self.configuration = configuration
    }

    /// Parses XML data into an XMLDocument
    /// - Parameter data: The raw XML data
    /// - Returns: A parsed XMLDocument
    /// - Throws: `HL7Error.parsingError` if the XML is malformed or exceeds limits
    public func parse(_ data: Data) throws -> XMLDocument {
        guard !data.isEmpty else {
            throw HL7Error.parsingError(
                "Empty XML data",
                context: ErrorContext(location: "HL7v3XMLParser.parse")
            )
        }

        if data.count > configuration.maxDocumentSize {
            throw HL7Error.parsingError(
                "Document size \(data.count) exceeds maximum allowed size \(configuration.maxDocumentSize)",
                context: ErrorContext(
                    location: "HL7v3XMLParser.parse",
                    metadata: [
                        "documentSize": "\(data.count)",
                        "maxSize": "\(configuration.maxDocumentSize)",
                    ]
                )
            )
        }

        let delegate = XMLParserDelegateImpl(configuration: configuration)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = configuration.resolveExternalEntities

        let success = parser.parse()

        if !success {
            let errorMessage: String
            let line: Int?
            let column: Int?

            if let parserError = parser.parserError {
                errorMessage = parserError.localizedDescription
                line = parser.lineNumber
                column = parser.columnNumber
            } else if let delegateError = delegate.fatalError {
                errorMessage = delegateError
                line = delegate.fatalErrorLine
                column = delegate.fatalErrorColumn
            } else {
                errorMessage = "Unknown XML parsing error"
                line = nil
                column = nil
            }

            throw HL7Error.parsingError(
                errorMessage,
                context: ErrorContext(
                    location: "HL7v3XMLParser.parse",
                    line: line,
                    column: column,
                    metadata: ["diagnosticCount": "\(delegate.diagnostics.count)"]
                )
            )
        }

        return XMLDocument(
            root: delegate.rootElement,
            xmlVersion: "1.0",
            encoding: "UTF-8"
        )
    }

    /// Returns diagnostics from the most recent parse (requires re-parsing)
    /// - Parameter data: The XML data to parse
    /// - Returns: A tuple of the parsed document and any diagnostics
    /// - Throws: `HL7Error.parsingError` if the XML is malformed
    public func parseWithDiagnostics(_ data: Data) throws -> (XMLDocument, [XMLDiagnostic]) {
        guard !data.isEmpty else {
            throw HL7Error.parsingError(
                "Empty XML data",
                context: ErrorContext(location: "HL7v3XMLParser.parseWithDiagnostics")
            )
        }

        if data.count > configuration.maxDocumentSize {
            throw HL7Error.parsingError(
                "Document size \(data.count) exceeds maximum allowed size \(configuration.maxDocumentSize)",
                context: ErrorContext(location: "HL7v3XMLParser.parseWithDiagnostics")
            )
        }

        let delegate = XMLParserDelegateImpl(configuration: configuration)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = configuration.resolveExternalEntities

        let success = parser.parse()

        if !success {
            let errorMessage: String
            if let parserError = parser.parserError {
                errorMessage = parserError.localizedDescription
            } else if let delegateError = delegate.fatalError {
                errorMessage = delegateError
            } else {
                errorMessage = "Unknown XML parsing error"
            }

            throw HL7Error.parsingError(
                errorMessage,
                context: ErrorContext(
                    location: "HL7v3XMLParser.parseWithDiagnostics",
                    line: parser.lineNumber,
                    column: parser.columnNumber
                )
            )
        }

        let document = XMLDocument(
            root: delegate.rootElement,
            xmlVersion: "1.0",
            encoding: "UTF-8"
        )

        return (document, delegate.diagnostics)
    }
}

// MARK: - XMLParser Delegate Implementation

/// Internal delegate for Foundation's XMLParser
/// Note: This class is not Sendable because XMLParserDelegate requires a class,
/// but it is only used within the synchronous scope of `HL7v3XMLParser.parse`.
private final class XMLParserDelegateImpl: NSObject, XMLParserDelegate {
    let configuration: XMLParserConfiguration
    var rootElement: XMLElement?
    var elementStack: [XMLElement] = []
    var currentDepth: Int = 0
    var diagnostics: [XMLDiagnostic] = []
    var fatalError: String?
    var fatalErrorLine: Int?
    var fatalErrorColumn: Int?
    var namespacePrefixMap: [String: String] = [:]
    var textBuffer: String = ""

    init(configuration: XMLParserConfiguration) {
        self.configuration = configuration
        super.init()
    }

    // MARK: - Namespace Handling

    func parser(
        _ parser: XMLParser,
        didStartMappingPrefix prefix: String,
        toURI namespaceURI: String
    ) {
        namespacePrefixMap[namespaceURI] = prefix
    }

    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
        // Clean up prefix mapping when scope ends
        for (uri, p) in namespacePrefixMap where p == prefix {
            namespacePrefixMap.removeValue(forKey: uri)
            break
        }
    }

    // MARK: - Element Handling

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        currentDepth += 1

        if currentDepth > configuration.maxDepth {
            diagnostics.append(
                XMLDiagnostic(
                    severity: .fatal,
                    message:
                        "Maximum nesting depth \(configuration.maxDepth) exceeded",
                    line: parser.lineNumber,
                    column: parser.columnNumber
                )
            )
            parser.abortParsing()
            fatalError = "Maximum nesting depth \(configuration.maxDepth) exceeded"
            fatalErrorLine = parser.lineNumber
            fatalErrorColumn = parser.columnNumber
            return
        }

        // Flush any accumulated text to the parent
        flushText()

        let resolvedPrefix: String?
        if let ns = namespaceURI {
            resolvedPrefix = namespacePrefixMap[ns]
        } else {
            resolvedPrefix = nil
        }

        let element = XMLElement(
            name: elementName,
            namespace: namespaceURI?.isEmpty == true ? nil : namespaceURI,
            prefix: resolvedPrefix?.isEmpty == true ? nil : resolvedPrefix,
            attributes: attributeDict
        )

        elementStack.append(element)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // Flush remaining text
        flushText()

        currentDepth -= 1

        guard var completedElement = elementStack.popLast() else { return }

        // Trim whitespace-only text
        if let text = completedElement.text,
           text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            completedElement.text = nil
        }

        if elementStack.isEmpty {
            rootElement = completedElement
        } else {
            elementStack[elementStack.count - 1].children.append(completedElement)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let cdataString = String(data: CDATABlock, encoding: .utf8) {
            textBuffer += cdataString
        }
    }

    // MARK: - Error Handling

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        let nsError = parseError as NSError
        diagnostics.append(
            XMLDiagnostic(
                severity: .error,
                message: nsError.localizedDescription,
                line: parser.lineNumber,
                column: parser.columnNumber
            )
        )
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        let nsError = validationError as NSError
        diagnostics.append(
            XMLDiagnostic(
                severity: .warning,
                message: nsError.localizedDescription,
                line: parser.lineNumber,
                column: parser.columnNumber
            )
        )
    }

    // MARK: - Helpers

    private func flushText() {
        guard !textBuffer.isEmpty else { return }
        if !elementStack.isEmpty {
            let existing = elementStack[elementStack.count - 1].text ?? ""
            elementStack[elementStack.count - 1].text = existing + textBuffer
        }
        textBuffer = ""
    }
}

// MARK: - HL7v3 Schema Validation

/// Result of an HL7 v3 schema validation
public struct HL7v3ValidationResult: Sendable, Equatable {
    /// Whether the document is valid
    public let isValid: Bool

    /// Validation errors found
    public let errors: [String]

    /// Validation warnings found
    public let warnings: [String]

    /// Creates a new validation result
    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// Validates an XMLDocument against HL7 v3 structural rules
///
/// Checks for valid root elements, required namespaces, and mandatory elements
/// in HL7 v3 / CDA documents.
///
/// Example:
/// ```swift
/// let validator = HL7v3SchemaValidator()
/// let result = validator.validate(document)
/// if !result.isValid {
///     print(result.errors)
/// }
/// ```
public struct HL7v3SchemaValidator: Sendable {
    /// Known valid HL7 v3 root element names
    public static let validRootElements: Set<String> = [
        "ClinicalDocument",
        "PRPA_IN201301UV02",
        "PRPA_IN201302UV02",
        "PRPA_IN201305UV02",
        "RCMR_IN030000UK06",
        "MCCI_IN000002UV01",
        "QUPC_IN043100UV01",
        "POLB_IN224200UV01",
        "Bundle",
        "Act",
        "Observation",
        "Encounter",
        "SubstanceAdministration",
        "Supply",
        "Procedure",
        "Organizer",
    ]

    /// Required child elements for ClinicalDocument
    public static let cdaRequiredElements: [String] = [
        "typeId",
        "id",
    ]

    /// Creates a new schema validator
    public init() {}

    /// Validates an XMLDocument against HL7 v3 rules
    /// - Parameter document: The document to validate
    /// - Returns: A validation result with any errors and warnings
    public func validate(_ document: XMLDocument) -> HL7v3ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        guard let root = document.root else {
            errors.append("Document has no root element")
            return HL7v3ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }

        // Check root element name
        if !HL7v3SchemaValidator.validRootElements.contains(root.name) {
            warnings.append(
                "Root element '\(root.name)' is not a recognized HL7 v3 element"
            )
        }

        // Check HL7 v3 namespace
        let hasHL7Namespace = root.namespace == XMLNamespace.hl7v3.uri
        if !hasHL7Namespace {
            errors.append(
                "Root element missing required HL7 v3 namespace (urn:hl7-org:v3)"
            )
        }

        // CDA-specific validation
        if root.name == "ClinicalDocument" {
            for requiredElement in HL7v3SchemaValidator.cdaRequiredElements {
                if root.firstChild(named: requiredElement) == nil {
                    errors.append("ClinicalDocument missing required element: \(requiredElement)")
                }
            }
        }

        let isValid = errors.isEmpty
        return HL7v3ValidationResult(isValid: isValid, errors: errors, warnings: warnings)
    }
}

// MARK: - XPath-like Query Support

/// A simple XPath-like query for navigating XML documents
///
/// Supports the following path expressions:
/// - `/root/child/grandchild` — absolute path from root
/// - `//element` — recursive descendant search
/// - `element[@attr='value']` — attribute predicate matching
///
/// Example:
/// ```swift
/// let query = XMLPathQuery(expression: "//id[@root='1.2.3']")
/// let matches = query.evaluate(on: document)
/// ```
public struct XMLPathQuery: Sendable, Equatable {
    /// The raw path expression string
    public let expression: String

    /// Creates a new query with the given path expression
    /// - Parameter expression: The XPath-like expression
    public init(expression: String) {
        self.expression = expression
    }

    /// Evaluates the query against an XMLDocument
    /// - Parameter document: The document to query
    /// - Returns: Matching elements
    /// - Throws: `HL7Error.parsingError` if the expression is invalid
    public func evaluate(on document: XMLDocument) throws -> [XMLElement] {
        guard let root = document.root else { return [] }
        return try evaluateOnElement(root, isRoot: true)
    }

    /// Evaluates the query against an XMLElement
    /// - Parameter element: The element to query
    /// - Returns: Matching elements
    /// - Throws: `HL7Error.parsingError` if the expression is invalid
    public func evaluate(on element: XMLElement) throws -> [XMLElement] {
        return try evaluateOnElement(element, isRoot: true)
    }

    private func evaluateOnElement(_ element: XMLElement, isRoot: Bool) throws -> [XMLElement] {
        let expr = expression.trimmingCharacters(in: .whitespaces)

        guard !expr.isEmpty else {
            throw HL7Error.parsingError(
                "Empty XPath expression",
                context: ErrorContext(location: "XMLPathQuery.evaluate")
            )
        }

        // Recursive descendant search: //elementName or //elementName[@attr='value']
        if expr.hasPrefix("//") {
            let remainder = String(expr.dropFirst(2))
            let (name, predicate) = parseStep(remainder)
            return findDescendants(of: element, named: name, predicate: predicate)
        }

        // Absolute path: /root/child/...
        if expr.hasPrefix("/") {
            let pathStr = String(expr.dropFirst())
            let steps = splitPath(pathStr)

            guard !steps.isEmpty else {
                throw HL7Error.parsingError(
                    "Invalid XPath expression: no steps after /",
                    context: ErrorContext(
                        location: "XMLPathQuery.evaluate",
                        metadata: ["expression": expression]
                    )
                )
            }

            // First step must match root
            let (firstName, firstPredicate) = parseStep(steps[0])
            guard matchesElement(element, name: firstName, predicate: firstPredicate) else {
                return []
            }

            if steps.count == 1 {
                return [element]
            }

            return navigateSteps(Array(steps.dropFirst()), from: [element])
        }

        // Relative path: elementName or elementName/child
        let steps = splitPath(expr)
        guard !steps.isEmpty else {
            throw HL7Error.parsingError(
                "Invalid XPath expression",
                context: ErrorContext(
                    location: "XMLPathQuery.evaluate",
                    metadata: ["expression": expression]
                )
            )
        }

        // Start matching from the element's children
        let (firstName, firstPredicate) = parseStep(steps[0])
        var current = element.children.filter { matchesElement($0, name: firstName, predicate: firstPredicate) }

        if steps.count > 1 {
            current = navigateSteps(Array(steps.dropFirst()), from: current)
        }

        return current
    }

    /// Splits a path string by "/" but respects brackets
    private func splitPath(_ path: String) -> [String] {
        var steps: [String] = []
        var current = ""
        var bracketDepth = 0

        for char in path {
            if char == "[" {
                bracketDepth += 1
                current.append(char)
            } else if char == "]" {
                bracketDepth -= 1
                current.append(char)
            } else if char == "/" && bracketDepth == 0 {
                if !current.isEmpty {
                    steps.append(current)
                }
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            steps.append(current)
        }
        return steps
    }

    /// Parses a step like "element[@attr='value']" into (name, predicate)
    private func parseStep(_ step: String) -> (String, AttributePredicate?) {
        guard let bracketStart = step.firstIndex(of: "["),
              let bracketEnd = step.lastIndex(of: "]")
        else {
            return (step, nil)
        }

        let name = String(step[step.startIndex..<bracketStart])
        let predicateStr = String(step[step.index(after: bracketStart)..<bracketEnd])

        // Parse @attr='value' or @attr="value"
        if predicateStr.hasPrefix("@") {
            let attrExpr = String(predicateStr.dropFirst())
            if let equalsIdx = attrExpr.firstIndex(of: "=") {
                let attrName = String(attrExpr[attrExpr.startIndex..<equalsIdx])
                var attrValue = String(attrExpr[attrExpr.index(after: equalsIdx)...])
                // Strip quotes
                attrValue = attrValue.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                return (name, AttributePredicate(attribute: attrName, value: attrValue))
            }
        }

        return (name, nil)
    }

    /// Navigates through path steps from a set of current elements
    private func navigateSteps(_ steps: [String], from elements: [XMLElement]) -> [XMLElement] {
        var current = elements
        for step in steps {
            let (name, predicate) = parseStep(step)
            var next: [XMLElement] = []
            for elem in current {
                for child in elem.children where matchesElement(child, name: name, predicate: predicate) {
                    next.append(child)
                }
            }
            current = next
        }
        return current
    }

    /// Checks whether an element matches a name and optional predicate
    private func matchesElement(
        _ element: XMLElement, name: String, predicate: AttributePredicate?
    ) -> Bool {
        guard element.name == name else { return false }
        if let pred = predicate {
            return element.attributes[pred.attribute] == pred.value
        }
        return true
    }

    /// Finds all descendants matching name and optional predicate
    private func findDescendants(
        of element: XMLElement, named name: String, predicate: AttributePredicate?
    ) -> [XMLElement] {
        var results: [XMLElement] = []
        if matchesElement(element, name: name, predicate: predicate) {
            results.append(element)
        }
        for child in element.children {
            results.append(contentsOf: findDescendants(of: child, named: name, predicate: predicate))
        }
        return results
    }
}

/// A predicate for matching an attribute name to a value
private struct AttributePredicate: Sendable, Equatable {
    let attribute: String
    let value: String
}

// MARK: - XML Serializer

/// Serializes XMLDocument and XMLElement back to XML string or Data
///
/// Supports formatted (indented) and compact output with proper namespace declarations.
///
/// Example:
/// ```swift
/// let serializer = HL7v3XMLSerializer(prettyPrint: true)
/// let xmlString = serializer.serializeToString(document)
/// ```
public struct HL7v3XMLSerializer: Sendable {
    /// Whether to format the output with indentation
    public let prettyPrint: Bool

    /// The indentation string (e.g., "  " for two spaces)
    public let indentation: String

    /// Creates a new serializer
    /// - Parameters:
    ///   - prettyPrint: Whether to produce indented output
    ///   - indentation: The string used for each indent level
    public init(prettyPrint: Bool = false, indentation: String = "  ") {
        self.prettyPrint = prettyPrint
        self.indentation = indentation
    }

    /// Serializes an XMLDocument to a UTF-8 encoded Data
    /// - Parameter document: The document to serialize
    /// - Returns: UTF-8 encoded XML data
    /// - Throws: `HL7Error.encodingError` if serialization fails
    public func serialize(_ document: XMLDocument) throws -> Data {
        let string = serializeToString(document)
        guard let data = string.data(using: .utf8) else {
            throw HL7Error.encodingError(
                "Failed to encode XML string as UTF-8",
                context: ErrorContext(location: "HL7v3XMLSerializer.serialize")
            )
        }
        return data
    }

    /// Serializes an XMLDocument to a string
    /// - Parameter document: The document to serialize
    /// - Returns: An XML string representation
    public func serializeToString(_ document: XMLDocument) -> String {
        var result = "<?xml version=\"\(document.xmlVersion)\" encoding=\"\(document.encoding)\"?>"
        if let root = document.root {
            if prettyPrint {
                result += "\n"
            }
            serializeElement(root, into: &result, depth: 0, isRoot: true)
        }
        return result
    }

    /// Serializes a single XMLElement to a string
    /// - Parameter element: The element to serialize
    /// - Returns: An XML string representation of the element
    public func serializeElementToString(_ element: XMLElement) -> String {
        var result = ""
        serializeElement(element, into: &result, depth: 0, isRoot: true)
        return result
    }

    private func serializeElement(
        _ element: XMLElement,
        into result: inout String,
        depth: Int,
        isRoot: Bool
    ) {
        let indent = prettyPrint ? String(repeating: indentation, count: depth) : ""
        let newline = prettyPrint ? "\n" : ""

        // Opening tag
        result += indent
        result += "<"
        result += element.qualifiedName

        // Namespace declaration on root or when prefix is used
        if isRoot, let ns = element.namespace {
            if let prefix = element.prefix, !prefix.isEmpty {
                result += " xmlns:\(prefix)=\"\(escapeXMLAttribute(ns))\""
            } else {
                result += " xmlns=\"\(escapeXMLAttribute(ns))\""
            }
        }

        // Attributes
        for (key, value) in element.attributes.sorted(by: { $0.key < $1.key }) {
            result += " \(key)=\"\(escapeXMLAttribute(value))\""
        }

        // Self-closing if no content
        let hasContent = element.text != nil || !element.children.isEmpty
        if !hasContent {
            result += "/>"
            result += newline
            return
        }

        result += ">"

        // Text-only elements (no children)
        if element.children.isEmpty, let text = element.text {
            result += escapeXMLText(text)
            result += "</\(element.qualifiedName)>"
            result += newline
            return
        }

        // Mixed content or children
        if prettyPrint {
            result += "\n"
        }

        if let text = element.text {
            let textIndent = prettyPrint ? String(repeating: indentation, count: depth + 1) : ""
            result += textIndent + escapeXMLText(text) + newline
        }

        for child in element.children {
            serializeElement(child, into: &result, depth: depth + 1, isRoot: false)
        }

        result += indent
        result += "</\(element.qualifiedName)>"
        result += newline
    }

    /// Escapes special characters in XML text content using a single pass
    private func escapeXMLText(_ text: String) -> String {
        guard text.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" }) else {
            return text
        }
        var result = ""
        result.reserveCapacity(text.count)
        for char in text {
            switch char {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            default: result.append(char)
            }
        }
        return result
    }

    /// Escapes special characters in XML attribute values using a single pass
    private func escapeXMLAttribute(_ value: String) -> String {
        guard value.contains(where: { $0 == "&" || $0 == "<" || $0 == ">" || $0 == "\"" || $0 == "'" }) else {
            return value
        }
        var result = ""
        result.reserveCapacity(value.count)
        for char in value {
            switch char {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.append(char)
            }
        }
        return result
    }
}
