/// XMLInspectorTests.swift
/// Unit tests for XMLInspector

import XCTest
@testable import HL7v3Kit

final class XMLInspectorTests: XCTestCase {
    // MARK: - Test Helpers
    
    func createSimpleElement() -> XMLElement {
        XMLElement(
            name: "root",
            attributes: ["id": "1", "type": "test"],
            children: [
                XMLElement(
                    name: "child1",
                    attributes: ["name": "first"],
                    text: "Hello World"
                ),
                XMLElement(
                    name: "child2",
                    children: [
                        XMLElement(name: "grandchild", text: "Nested text")
                    ]
                )
            ]
        )
    }
    
    func createCDADocument() -> XMLElement {
        XMLElement(
            name: "ClinicalDocument",
            namespace: "urn:hl7-org:v3",
            attributes: [:],
            children: [
                XMLElement(name: "typeId", attributes: ["root": "2.16.840.1.113883.1.3"]),
                XMLElement(name: "templateId", attributes: ["root": "2.16.840.1.113883.10.20.22.1.1"]),
                XMLElement(name: "templateId", attributes: ["root": "2.16.840.1.113883.10.20.22.1.2"]),
                XMLElement(
                    name: "code",
                    attributes: [
                        "code": "34133-9",
                        "displayName": "Summarization of Episode Note",
                        "codeSystem": "2.16.840.1.113883.6.1"
                    ]
                ),
                XMLElement(name: "title", text: "Continuity of Care Document"),
                XMLElement(name: "languageCode", attributes: ["code": "en-US"]),
                XMLElement(name: "recordTarget"),
                XMLElement(name: "author"),
                XMLElement(name: "custodian"),
                XMLElement(
                    name: "component",
                    children: [
                        XMLElement(
                            name: "structuredBody",
                            children: [
                                XMLElement(
                                    name: "component",
                                    children: [
                                        XMLElement(
                                            name: "section",
                                            children: [
                                                XMLElement(name: "title", text: "Medications"),
                                                XMLElement(
                                                    name: "text",
                                                    text: "Patient is taking aspirin 81mg daily"
                                                ),
                                                XMLElement(
                                                    name: "entry",
                                                    children: [
                                                        XMLElement(
                                                            name: "substanceAdministration",
                                                            children: [
                                                                XMLElement(name: "code", attributes: ["code": "10"]),
                                                                XMLElement(name: "statusCode", attributes: ["code": "completed"])
                                                            ]
                                                        )
                                                    ]
                                                )
                                            ]
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    }
    
    // MARK: - Tree View Tests
    
    func testTreeViewBasic() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let treeView = await inspector.treeView(element: element)
        
        XCTAssertTrue(treeView.contains("root"))
        XCTAssertTrue(treeView.contains("child1"))
        XCTAssertTrue(treeView.contains("child2"))
        XCTAssertTrue(treeView.contains("grandchild"))
        XCTAssertTrue(treeView.contains("Hello World"))
    }
    
    func testTreeViewWithAttributes() async throws {
        let config = XMLInspector.Configuration(showAttributes: true)
        let inspector = XMLInspector(configuration: config)
        let element = createSimpleElement()
        
        let treeView = await inspector.treeView(element: element)
        
        XCTAssertTrue(treeView.contains("id=\"1\""))
        XCTAssertTrue(treeView.contains("type=\"test\""))
        XCTAssertTrue(treeView.contains("name=\"first\""))
    }
    
    func testTreeViewWithoutAttributes() async throws {
        let config = XMLInspector.Configuration(showAttributes: false)
        let inspector = XMLInspector(configuration: config)
        let element = createSimpleElement()
        
        let treeView = await inspector.treeView(element: element)
        
        XCTAssertFalse(treeView.contains("id=\"1\""))
        XCTAssertFalse(treeView.contains("type=\"test\""))
    }
    
    func testTreeViewMaxDepth() async throws {
        let config = XMLInspector.Configuration(maxDepth: 2)
        let inspector = XMLInspector(configuration: config)
        let element = createSimpleElement()
        
        let treeView = await inspector.treeView(element: element)
        
        XCTAssertTrue(treeView.contains("root"))
        XCTAssertTrue(treeView.contains("child1"))
        XCTAssertTrue(treeView.contains("child2"))
        // Grandchild should be truncated due to maxDepth
        XCTAssertTrue(treeView.contains("...") || !treeView.contains("Nested text"))
    }
    
    func testTreeViewCDAHighlighting() async throws {
        let config = XMLInspector.Configuration(highlightCDA: true)
        let inspector = XMLInspector(configuration: config)
        let element = createCDADocument()
        
        let treeView = await inspector.treeView(element: element)
        
        // Should contain emoji highlights for CDA elements
        XCTAssertTrue(treeView.contains("🏥"))  // ClinicalDocument
        XCTAssertTrue(treeView.contains("📋"))  // section
        XCTAssertTrue(treeView.contains("📌"))  // entry
        XCTAssertTrue(treeView.contains("💊"))  // substanceAdministration
        XCTAssertTrue(treeView.contains("👤"))  // author/custodian
    }
    
    func testTreeViewTextTruncation() async throws {
        let longText = String(repeating: "A", count: 200)
        let element = XMLElement(name: "test", text: longText)
        
        let config = XMLInspector.Configuration(maxTextLength: 50)
        let inspector = XMLInspector(configuration: config)
        
        let treeView = await inspector.treeView(element: element)
        
        XCTAssertTrue(treeView.contains("..."))
        XCTAssertTrue(treeView.count < longText.count + 100)  // Should be truncated
    }
    
    // MARK: - Statistics Tests
    
    func testComputeStatisticsSimple() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let stats = await inspector.computeStatistics(element: element)
        
        XCTAssertEqual(stats.elementCount, 4)  // root + 2 children + 1 grandchild
        XCTAssertEqual(stats.attributeCount, 3)  // id, type, name
        XCTAssertEqual(stats.maxDepth, 2)  // root -> child2 -> grandchild
        XCTAssertEqual(stats.textElementCount, 2)  // child1 and grandchild
        XCTAssertGreaterThan(stats.totalTextLength, 0)
    }
    
    func testComputeStatisticsCDA() async throws {
        let inspector = XMLInspector()
        let element = createCDADocument()
        
        let stats = await inspector.computeStatistics(element: element)
        
        XCTAssertGreaterThan(stats.elementCount, 10)
        XCTAssertGreaterThan(stats.maxDepth, 5)
        XCTAssertGreaterThan(stats.namespaceCount, 0)
        XCTAssertFalse(stats.topElements.isEmpty)
    }
    
    func testStatisticsTopElements() async throws {
        let element = XMLElement(
            name: "root",
            children: [
                XMLElement(name: "item"),
                XMLElement(name: "item"),
                XMLElement(name: "item"),
                XMLElement(name: "data"),
                XMLElement(name: "data")
            ]
        )
        
        let inspector = XMLInspector()
        let stats = await inspector.computeStatistics(element: element)
        
        XCTAssertEqual(stats.topElements.first?.name, "item")
        XCTAssertEqual(stats.topElements.first?.count, 3)
    }
    
    func testStatisticsAverageChildren() async throws {
        let element = XMLElement(
            name: "root",
            children: [
                XMLElement(name: "parent1", children: [
                    XMLElement(name: "child1"),
                    XMLElement(name: "child2")
                ]),
                XMLElement(name: "parent2", children: [
                    XMLElement(name: "child3"),
                    XMLElement(name: "child4")
                ])
            ]
        )
        
        let inspector = XMLInspector()
        let stats = await inspector.computeStatistics(element: element)
        
        // 5 total elements: root (2 children) + parent1 (2 children) + parent2 (2 children) + 4 leaf nodes
        // Total children: 6 (2 + 2 + 2)
        // Average: 6 / 5 = 1.2
        XCTAssertEqual(stats.avgChildrenPerElement, 1.2, accuracy: 0.01)
    }
    
    // MARK: - CDA Inspection Tests
    
    func testInspectCDADocument() async throws {
        let inspector = XMLInspector()
        let element = createCDADocument()
        
        let cdaInfo = await inspector.inspectCDA(element: element)
        
        XCTAssertTrue(cdaInfo.isCDADocument)
        XCTAssertEqual(cdaInfo.documentType, "Summarization of Episode Note")
        XCTAssertEqual(cdaInfo.languageCode, "en-US")
        XCTAssertEqual(cdaInfo.templateIds.count, 2)
        XCTAssertTrue(cdaInfo.templateIds.contains("2.16.840.1.113883.10.20.22.1.1"))
        XCTAssertEqual(cdaInfo.sectionCount, 1)
        XCTAssertEqual(cdaInfo.entryCount, 1)
        XCTAssertEqual(cdaInfo.participantCount, 3)  // recordTarget, author, custodian
    }
    
    func testInspectNonCDADocument() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let cdaInfo = await inspector.inspectCDA(element: element)
        
        XCTAssertFalse(cdaInfo.isCDADocument)
        XCTAssertNil(cdaInfo.documentType)
        XCTAssertEqual(cdaInfo.sectionCount, 0)
        XCTAssertEqual(cdaInfo.entryCount, 0)
    }
    
    func testCDAConformanceLevel1() async throws {
        // Level 1: Has narrative text only
        let element = XMLElement(
            name: "ClinicalDocument",
            children: [
                XMLElement(name: "component", children: [
                    XMLElement(name: "section", children: [
                        XMLElement(name: "text", text: "Some narrative")
                    ])
                ])
            ]
        )
        
        let inspector = XMLInspector()
        let cdaInfo = await inspector.inspectCDA(element: element)
        
        XCTAssertEqual(cdaInfo.conformanceLevel, 1)
    }
    
    func testCDAConformanceLevel2() async throws {
        // Level 2: Has entries without proper structure
        let element = XMLElement(
            name: "ClinicalDocument",
            children: [
                XMLElement(name: "component", children: [
                    XMLElement(name: "section", children: [
                        XMLElement(name: "entry", children: [
                            XMLElement(name: "observation")  // Missing required elements
                        ])
                    ])
                ])
            ]
        )
        
        let inspector = XMLInspector()
        let cdaInfo = await inspector.inspectCDA(element: element)
        
        XCTAssertEqual(cdaInfo.conformanceLevel, 2)
    }
    
    func testCDAConformanceLevel3() async throws {
        // Level 3: Has structured entries with data types
        let element = XMLElement(
            name: "ClinicalDocument",
            children: [
                XMLElement(name: "component", children: [
                    XMLElement(name: "section", children: [
                        XMLElement(name: "entry", children: [
                            XMLElement(name: "observation", children: [
                                XMLElement(name: "code", attributes: ["code": "12345"]),
                                XMLElement(name: "statusCode", attributes: ["code": "completed"])
                            ])
                        ])
                    ])
                ])
            ]
        )
        
        let inspector = XMLInspector()
        let cdaInfo = await inspector.inspectCDA(element: element)
        
        XCTAssertEqual(cdaInfo.conformanceLevel, 3)
    }
    
    // MARK: - Search Tests
    
    func testFindElements() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let found = await inspector.findElements(named: "child1", in: element)
        
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.name, "child1")
    }
    
    func testFindElementsMultiple() async throws {
        let element = XMLElement(
            name: "root",
            children: [
                XMLElement(name: "item"),
                XMLElement(name: "item"),
                XMLElement(name: "other"),
                XMLElement(name: "item")
            ]
        )
        
        let inspector = XMLInspector()
        let found = await inspector.findElements(named: "item", in: element)
        
        XCTAssertEqual(found.count, 3)
    }
    
    func testFindElement() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let found = await inspector.findElement(named: "grandchild", in: element)
        
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "grandchild")
    }
    
    func testFindElementNotFound() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let found = await inspector.findElement(named: "nonexistent", in: element)
        
        XCTAssertNil(found)
    }
    
    func testSearchText() async throws {
        let element = XMLElement(
            name: "root",
            children: [
                XMLElement(name: "item1", text: "Hello world"),
                XMLElement(name: "item2", text: "Goodbye"),
                XMLElement(name: "item3", text: "Hello again")
            ]
        )
        
        let inspector = XMLInspector()
        let found = await inspector.searchText("Hello", in: element)
        
        XCTAssertEqual(found.count, 2)
        XCTAssertTrue(found.allSatisfy { $0.text?.contains("Hello") == true })
    }
    
    func testSearchTextCaseInsensitive() async throws {
        let element = XMLElement(name: "root", text: "Hello World")
        
        let inspector = XMLInspector()
        let found = await inspector.searchText("hello", in: element)
        
        XCTAssertEqual(found.count, 1)
    }
    
    // MARK: - Pretty Print Tests
    
    func testPrettyPrintSimple() async throws {
        let element = XMLElement(
            name: "root",
            attributes: ["id": "1"],
            children: [
                XMLElement(name: "child", text: "Test")
            ]
        )
        
        let inspector = XMLInspector()
        let xml = await inspector.prettyPrint(element: element)
        
        XCTAssertTrue(xml.contains("<root id=\"1\">"))
        XCTAssertTrue(xml.contains("<child>Test</child>"))
        XCTAssertTrue(xml.contains("</root>"))
    }
    
    func testPrettyPrintSelfClosing() async throws {
        let element = XMLElement(name: "empty", attributes: ["test": "value"])
        
        let inspector = XMLInspector()
        let xml = await inspector.prettyPrint(element: element)
        
        XCTAssertTrue(xml.contains("<empty test=\"value\"/>"))
    }
    
    func testPrettyPrintWithPrefix() async throws {
        let element = XMLElement(
            name: "document",
            namespace: "urn:hl7-org:v3",
            prefix: "hl7"
        )
        
        let inspector = XMLInspector()
        let xml = await inspector.prettyPrint(element: element)
        
        XCTAssertTrue(xml.contains("<hl7:document"))
        XCTAssertTrue(xml.contains("</hl7:document>"))
    }
    
    func testPrettyPrintEscaping() async throws {
        let element = XMLElement(
            name: "test",
            attributes: ["attr": "value & \"quoted\""],
            text: "Text with <tags> & ampersands"
        )
        
        let inspector = XMLInspector()
        let xml = await inspector.prettyPrint(element: element)
        
        XCTAssertTrue(xml.contains("&amp;"))
        XCTAssertTrue(xml.contains("&lt;"))
        XCTAssertTrue(xml.contains("&gt;"))
        XCTAssertTrue(xml.contains("&quot;"))
    }
    
    // MARK: - Report Generation Tests
    
    func testGenerateReport() async throws {
        let inspector = XMLInspector()
        let element = createCDADocument()
        
        let report = await inspector.generateReport(element: element)
        
        XCTAssertTrue(report.contains("XML INSPECTION REPORT"))
        XCTAssertTrue(report.contains("GENERAL STATISTICS"))
        XCTAssertTrue(report.contains("Elements:"))
        XCTAssertTrue(report.contains("CDA DOCUMENT INFORMATION"))
        XCTAssertTrue(report.contains("TEMPLATE IDs"))
    }
    
    func testGenerateReportNonCDA() async throws {
        let inspector = XMLInspector()
        let element = createSimpleElement()
        
        let report = await inspector.generateReport(element: element)
        
        XCTAssertTrue(report.contains("XML INSPECTION REPORT"))
        XCTAssertTrue(report.contains("GENERAL STATISTICS"))
        XCTAssertFalse(report.contains("CDA DOCUMENT INFORMATION"))
    }
    
    // MARK: - Extension Method Tests
    
    func testXMLElementTreeViewConvenience() async throws {
        let element = createSimpleElement()
        
        let treeView = await element.treeView()
        
        XCTAssertFalse(treeView.isEmpty)
        XCTAssertTrue(treeView.contains("root"))
    }
    
    func testXMLElementStatisticsConvenience() async throws {
        let element = createSimpleElement()
        
        let stats = await element.statistics()
        
        XCTAssertGreaterThan(stats.elementCount, 0)
    }
    
    func testXMLElementInspectCDAConvenience() async throws {
        let element = createCDADocument()
        
        let cdaInfo = await element.inspectCDA()
        
        XCTAssertTrue(cdaInfo.isCDADocument)
    }
    
    func testXMLElementInspectionReportConvenience() async throws {
        let element = createCDADocument()
        
        let report = await element.inspectionReport()
        
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("XML INSPECTION REPORT"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyElement() async throws {
        let element = XMLElement(name: "empty")
        let inspector = XMLInspector()
        
        let stats = await inspector.computeStatistics(element: element)
        
        XCTAssertEqual(stats.elementCount, 1)
        XCTAssertEqual(stats.attributeCount, 0)
        XCTAssertEqual(stats.maxDepth, 0)
        XCTAssertEqual(stats.textElementCount, 0)
    }
    
    func testDeepNesting() async throws {
        func createDeepElement(depth: Int) -> XMLElement {
            if depth == 0 {
                return XMLElement(name: "leaf", text: "Bottom")
            }
            return XMLElement(name: "level\(depth)", children: [createDeepElement(depth: depth - 1)])
        }
        
        let element = createDeepElement(depth: 10)
        let inspector = XMLInspector()
        
        let stats = await inspector.computeStatistics(element: element)
        
        XCTAssertEqual(stats.maxDepth, 10)
        XCTAssertEqual(stats.elementCount, 11)  // 10 levels + 1 leaf
    }
    
    func testManyChildren() async throws {
        let children = (0..<100).map { XMLElement(name: "child\($0)") }
        let element = XMLElement(name: "root", children: children)
        
        let inspector = XMLInspector()
        let stats = await inspector.computeStatistics(element: element)
        
        XCTAssertEqual(stats.elementCount, 101)  // root + 100 children
    }
}
