/// V3TestUtilities.swift
/// Test utilities for HL7 v3.x development
///
/// Provides helper classes and methods for creating test data, mock objects,
/// and assertions for HL7 v3.x and CDA R2 testing.

import Foundation
import HL7Core

// MARK: - Test Utilities

/// Comprehensive test utilities for HL7 v3.x development
///
/// V3TestUtilities provides builders for mock CDA documents, test data generators,
/// assertion helpers, and performance testing tools to make testing easier.
public actor V3TestUtilities: Sendable {
    
    // MARK: - Mock CDA Document Builders
    
    /// Creates a minimal valid CDA R2 document for testing
    /// - Parameters:
    ///   - documentType: The LOINC code for document type
    ///   - title: The document title
    ///   - patientName: The patient name
    ///   - includeBody: Whether to include a structured body
    /// - Returns: A minimal valid CDA document
    public static func createMinimalCDADocument(
        documentType: String = "34133-9",
        title: String = "Test Document",
        patientName: String = "John Doe",
        includeBody: Bool = true
    ) -> XMLElement {
        var children: [XMLElement] = [
            XMLElement(name: "typeId", attributes: [
                "root": "2.16.840.1.113883.1.3",
                "extension": "POCD_HD000040"
            ]),
            XMLElement(name: "id", attributes: [
                "root": "2.16.840.1.113883.19.5.99999.1",
                "extension": "TT988"
            ]),
            XMLElement(name: "code", attributes: [
                "code": documentType,
                "codeSystem": "2.16.840.1.113883.6.1",
                "codeSystemName": "LOINC",
                "displayName": title
            ]),
            XMLElement(name: "title", text: title),
            XMLElement(name: "effectiveTime", attributes: ["value": "20240101120000"]),
            XMLElement(name: "confidentialityCode", attributes: [
                "code": "N",
                "codeSystem": "2.16.840.1.113883.5.25"
            ]),
            XMLElement(name: "languageCode", attributes: ["code": "en-US"]),
            createMockRecordTarget(patientName: patientName),
            createMockAuthor(),
            createMockCustodian()
        ]
        
        if includeBody {
            children.append(createMockComponent())
        }
        
        return XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: ["classCode": "DOCCLIN", "moodCode": "EVN"],
            children: children
        )
    }
    
    /// Creates a mock RecordTarget element
    public static func createMockRecordTarget(patientName: String = "John Doe") -> XMLElement {
        let names = patientName.split(separator: " ")
        let firstName = names.first.map(String.init) ?? "John"
        let lastName = names.dropFirst().joined(separator: " ").isEmpty ? "Doe" : names.dropFirst().joined(separator: " ")
        
        return XMLElement(
            name: "recordTarget",
            children: [
                XMLElement(name: "patientRole", children: [
                    XMLElement(name: "id", attributes: [
                        "root": "2.16.840.1.113883.19.5.99999.2",
                        "extension": "998991"
                    ]),
                    XMLElement(name: "patient", children: [
                        XMLElement(name: "name", children: [
                            XMLElement(name: "given", text: firstName),
                            XMLElement(name: "family", text: lastName)
                        ]),
                        XMLElement(name: "administrativeGenderCode", attributes: [
                            "code": "M",
                            "codeSystem": "2.16.840.1.113883.5.1"
                        ]),
                        XMLElement(name: "birthTime", attributes: ["value": "19800101"])
                    ])
                ])
            ]
        )
    }
    
    /// Creates a mock Author element
    public static func createMockAuthor(authorName: String = "Dr. Smith") -> XMLElement {
        XMLElement(
            name: "author",
            children: [
                XMLElement(name: "time", attributes: ["value": "20240101120000"]),
                XMLElement(name: "assignedAuthor", children: [
                    XMLElement(name: "id", attributes: [
                        "root": "2.16.840.1.113883.19.5.99999.456",
                        "extension": "2981824"
                    ]),
                    XMLElement(name: "assignedPerson", children: [
                        XMLElement(name: "name", text: authorName)
                    ])
                ])
            ]
        )
    }
    
    /// Creates a mock Custodian element
    public static func createMockCustodian(orgName: String = "Test Hospital") -> XMLElement {
        XMLElement(
            name: "custodian",
            children: [
                XMLElement(name: "assignedCustodian", children: [
                    XMLElement(name: "representedCustodianOrganization", children: [
                        XMLElement(name: "id", attributes: [
                            "root": "2.16.840.1.113883.19.5"
                        ]),
                        XMLElement(name: "name", text: orgName)
                    ])
                ])
            ]
        )
    }
    
    /// Creates a mock Component with structured body
    public static func createMockComponent(sections: [XMLElement]? = nil) -> XMLElement {
        let sectionElements = sections ?? [createMockSection()]
        
        return XMLElement(
            name: "component",
            children: [
                XMLElement(
                    name: "structuredBody",
                    children: sectionElements.map { section in
                        XMLElement(name: "component", children: [section])
                    }
                )
            ]
        )
    }
    
    /// Creates a mock Section element
    public static func createMockSection(
        title: String = "Test Section",
        code: String = "10160-0",
        narrative: String = "Test narrative content",
        entries: [XMLElement]? = nil
    ) -> XMLElement {
        var children: [XMLElement] = [
            XMLElement(name: "templateId", attributes: ["root": "2.16.840.1.113883.10.20.22.2.1"]),
            XMLElement(name: "code", attributes: [
                "code": code,
                "codeSystem": "2.16.840.1.113883.6.1",
                "codeSystemName": "LOINC"
            ]),
            XMLElement(name: "title", text: title),
            XMLElement(name: "text", text: narrative)
        ]
        
        if let entries = entries {
            children.append(contentsOf: entries)
        }
        
        return XMLElement(name: "section", children: children)
    }
    
    /// Creates a mock Entry with Observation
    public static func createMockObservationEntry(
        code: String = "8310-5",
        displayName: String = "Body temperature",
        value: String = "37.0",
        unit: String = "Cel"
    ) -> XMLElement {
        XMLElement(
            name: "entry",
            attributes: ["typeCode": "DRIV"],
            children: [
                XMLElement(
                    name: "observation",
                    attributes: ["classCode": "OBS", "moodCode": "EVN"],
                    children: [
                        XMLElement(name: "templateId", attributes: ["root": "2.16.840.1.113883.10.20.22.4.2"]),
                        XMLElement(name: "id", attributes: ["root": "c6f88321-67ad-11db-bd13-0800200c9a66"]),
                        XMLElement(name: "code", attributes: [
                            "code": code,
                            "displayName": displayName,
                            "codeSystem": "2.16.840.1.113883.6.1",
                            "codeSystemName": "LOINC"
                        ]),
                        XMLElement(name: "statusCode", attributes: ["code": "completed"]),
                        XMLElement(name: "effectiveTime", attributes: ["value": "20240101120000"]),
                        XMLElement(name: "value", attributes: [
                            "xsi:type": "PQ",
                            "value": value,
                            "unit": unit
                        ])
                    ]
                )
            ]
        )
    }
    
    /// Creates a mock Entry with Procedure
    public static func createMockProcedureEntry(
        code: String = "80146002",
        displayName: String = "Appendectomy"
    ) -> XMLElement {
        XMLElement(
            name: "entry",
            children: [
                XMLElement(
                    name: "procedure",
                    attributes: ["classCode": "PROC", "moodCode": "EVN"],
                    children: [
                        XMLElement(name: "templateId", attributes: ["root": "2.16.840.1.113883.10.20.22.4.14"]),
                        XMLElement(name: "id", attributes: ["root": "d68b7e32-7810-4f5b-9cc2-acd54b0fd85d"]),
                        XMLElement(name: "code", attributes: [
                            "code": code,
                            "displayName": displayName,
                            "codeSystem": "2.16.840.1.113883.6.96",
                            "codeSystemName": "SNOMED CT"
                        ]),
                        XMLElement(name: "statusCode", attributes: ["code": "completed"]),
                        XMLElement(name: "effectiveTime", attributes: ["value": "20231215"])
                    ]
                )
            ]
        )
    }
    
    // MARK: - Test Data Generators
    
    /// Generates a random OID
    public static func randomOID() -> String {
        let parts = (0..<5).map { _ in Int.random(in: 1...999) }
        return "2.16.840.1.\(parts.map(String.init).joined(separator: "."))"
    }
    
    /// Generates a random HL7 timestamp
    public static func randomTimestamp() -> String {
        let year = Int.random(in: 2020...2024)
        let month = String(format: "%02d", Int.random(in: 1...12))
        let day = String(format: "%02d", Int.random(in: 1...28))
        let hour = String(format: "%02d", Int.random(in: 0...23))
        let minute = String(format: "%02d", Int.random(in: 0...59))
        let second = String(format: "%02d", Int.random(in: 0...59))
        return "\(year)\(month)\(day)\(hour)\(minute)\(second)"
    }
    
    /// Generates a random patient name
    public static func randomPatientName() -> String {
        let firstNames = ["John", "Jane", "Michael", "Sarah", "David", "Emily", "Robert", "Lisa"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"]
        
        let firstName = firstNames.randomElement() ?? "John"
        let lastName = lastNames.randomElement() ?? "Doe"
        
        return "\(firstName) \(lastName)"
    }
    
    /// Generates a set of test CDA documents
    /// - Parameter count: Number of documents to generate
    /// - Returns: Array of test CDA documents
    public static func generateTestDocuments(count: Int) -> [XMLElement] {
        (0..<count).map { index in
            createMinimalCDADocument(
                title: "Test Document \(index + 1)",
                patientName: randomPatientName()
            )
        }
    }
    
    // MARK: - XML Assertion Helpers
    
    /// Asserts that an element has a required child element
    /// - Parameters:
    ///   - element: The parent element
    ///   - childName: The expected child element name
    ///   - message: Optional custom message
    /// - Throws: AssertionError if child is not found
    public static func assertHasChild(
        _ element: XMLElement,
        named childName: String,
        message: String? = nil
    ) throws {
        let hasChild = element.children.contains { $0.name == childName }
        guard hasChild else {
            let msg = message ?? "Element '\(element.name)' missing required child '\(childName)'"
            throw AssertionError(message: msg)
        }
    }
    
    /// Asserts that an element has a required attribute
    /// - Parameters:
    ///   - element: The element
    ///   - attribute: The expected attribute name
    ///   - message: Optional custom message
    /// - Throws: AssertionError if attribute is not found
    public static func assertHasAttribute(
        _ element: XMLElement,
        named attribute: String,
        message: String? = nil
    ) throws {
        guard element.attributes[attribute] != nil else {
            let msg = message ?? "Element '\(element.name)' missing required attribute '\(attribute)'"
            throw AssertionError(message: msg)
        }
    }
    
    /// Asserts that an element's attribute has a specific value
    /// - Parameters:
    ///   - element: The element
    ///   - attribute: The attribute name
    ///   - expectedValue: The expected value
    ///   - message: Optional custom message
    /// - Throws: AssertionError if values don't match
    public static func assertAttributeEquals(
        _ element: XMLElement,
        attribute: String,
        expectedValue: String,
        message: String? = nil
    ) throws {
        guard let actualValue = element.attributes[attribute] else {
            throw AssertionError(message: "Element '\(element.name)' missing attribute '\(attribute)'")
        }
        
        guard actualValue == expectedValue else {
            let msg = message ?? "Attribute '\(attribute)' expected '\(expectedValue)' but got '\(actualValue)'"
            throw AssertionError(message: msg)
        }
    }
    
    /// Asserts that an element's text content matches expected
    /// - Parameters:
    ///   - element: The element
    ///   - expectedText: The expected text
    ///   - message: Optional custom message
    /// - Throws: AssertionError if text doesn't match
    public static func assertTextEquals(
        _ element: XMLElement,
        expectedText: String,
        message: String? = nil
    ) throws {
        guard let actualText = element.text else {
            throw AssertionError(message: "Element '\(element.name)' has no text content")
        }
        
        guard actualText == expectedText else {
            let msg = message ?? "Text expected '\(expectedText)' but got '\(actualText)'"
            throw AssertionError(message: msg)
        }
    }
    
    /// Asserts that an XPath query returns expected number of results
    /// - Parameters:
    ///   - element: The root element
    ///   - elementName: The element name to search for
    ///   - expectedCount: The expected count
    ///   - message: Optional custom message
    /// - Throws: AssertionError if counts don't match
    public static func assertElementCount(
        in element: XMLElement,
        named elementName: String,
        equals expectedCount: Int,
        message: String? = nil
    ) throws {
        let count = countElements(named: elementName, in: element)
        
        guard count == expectedCount else {
            let msg = message ?? "Expected \(expectedCount) '\(elementName)' elements but found \(count)"
            throw AssertionError(message: msg)
        }
    }
    
    private static func countElements(named name: String, in element: XMLElement) -> Int {
        var count = 0
        
        func traverse(_ element: XMLElement) {
            if element.name == name {
                count += 1
            }
            for child in element.children {
                traverse(child)
            }
        }
        
        traverse(element)
        return count
    }
    
    // MARK: - Performance Test Utilities
    
    /// Measures the time taken to execute a block of code
    /// - Parameter block: The code to measure
    /// - Returns: The duration in seconds
    public static func measureTime(_ block: () -> Void) -> TimeInterval {
        let start = Date()
        block()
        return Date().timeIntervalSince(start)
    }
    
    /// Measures the time taken to execute an async block of code
    /// - Parameter block: The async code to measure
    /// - Returns: The duration in seconds
    public static func measureTimeAsync(_ block: () async -> Void) async -> TimeInterval {
        let start = Date()
        await block()
        return Date().timeIntervalSince(start)
    }
    
    /// Performance test helper that runs a block multiple times
    /// - Parameters:
    ///   - iterations: Number of times to run the block
    ///   - block: The code to benchmark
    /// - Returns: Performance statistics
    public static func benchmark(
        iterations: Int,
        _ block: () -> Void
    ) -> PerformanceMetrics {
        var durations: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let duration = measureTime(block)
            durations.append(duration)
        }
        
        return PerformanceMetrics(durations: durations)
    }
    
    /// Performance test helper for async code
    /// - Parameters:
    ///   - iterations: Number of times to run the block
    ///   - block: The async code to benchmark
    /// - Returns: Performance statistics
    public static func benchmarkAsync(
        iterations: Int,
        _ block: () async -> Void
    ) async -> PerformanceMetrics {
        var durations: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let duration = await measureTimeAsync(block)
            durations.append(duration)
        }
        
        return PerformanceMetrics(durations: durations)
    }
    
    /// Performance metrics from benchmark runs
    public struct PerformanceMetrics: Sendable {
        /// All duration measurements
        public let durations: [TimeInterval]
        
        /// Average duration
        public var average: TimeInterval {
            durations.reduce(0, +) / Double(durations.count)
        }
        
        /// Minimum duration
        public var min: TimeInterval {
            durations.min() ?? 0
        }
        
        /// Maximum duration
        public var max: TimeInterval {
            durations.max() ?? 0
        }
        
        /// Standard deviation
        public var standardDeviation: TimeInterval {
            let avg = average
            let variance = durations.map { pow($0 - avg, 2) }.reduce(0, +) / Double(durations.count)
            return sqrt(variance)
        }
        
        /// Median duration
        public var median: TimeInterval {
            let sorted = durations.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                return (sorted[mid - 1] + sorted[mid]) / 2
            } else {
                return sorted[mid]
            }
        }
        
        /// Formatted summary string
        public var summary: String {
            """
            Performance Metrics:
              Average: \(String(format: "%.3f", average * 1000))ms
              Median:  \(String(format: "%.3f", median * 1000))ms
              Min:     \(String(format: "%.3f", min * 1000))ms
              Max:     \(String(format: "%.3f", max * 1000))ms
              StdDev:  \(String(format: "%.3f", standardDeviation * 1000))ms
              Runs:    \(durations.count)
            """
        }
    }
    
    // MARK: - Comparison Utilities
    
    /// Compares two XML elements for structural equality
    /// - Parameters:
    ///   - element1: First element
    ///   - element2: Second element
    ///   - ignoreOrder: Whether to ignore child element order
    /// - Returns: True if elements are structurally equal
    public static func elementsEqual(
        _ element1: XMLElement,
        _ element2: XMLElement,
        ignoreOrder: Bool = false
    ) -> Bool {
        // Compare names
        guard element1.name == element2.name else { return false }
        
        // Compare namespaces
        guard element1.namespace == element2.namespace else { return false }
        
        // Compare attributes
        guard element1.attributes == element2.attributes else { return false }
        
        // Compare text
        guard element1.text == element2.text else { return false }
        
        // Compare children
        guard element1.children.count == element2.children.count else { return false }
        
        if ignoreOrder {
            // Compare children regardless of order (expensive)
            for child1 in element1.children {
                let hasMatch = element2.children.contains { child2 in
                    elementsEqual(child1, child2, ignoreOrder: true)
                }
                if !hasMatch { return false }
            }
        } else {
            // Compare children in order
            for (child1, child2) in zip(element1.children, element2.children) {
                if !elementsEqual(child1, child2, ignoreOrder: false) {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Custom assertion error
    public struct AssertionError: Error {
        public let message: String
        
        public init(message: String) {
            self.message = message
        }
    }
}
