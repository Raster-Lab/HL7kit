import XCTest
@testable import HL7v3Kit
@testable import HL7Core

/// Comprehensive tests for HL7v3XMLParser and related types
final class HL7v3XMLParserTests: XCTestCase {

    // MARK: - XMLNamespace Tests

    func testXMLNamespaceCreation() {
        let ns = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")
        XCTAssertEqual(ns.prefix, "hl7")
        XCTAssertEqual(ns.uri, "urn:hl7-org:v3")
    }

    func testXMLNamespaceDefaultPrefix() {
        let ns = XMLNamespace(uri: "urn:hl7-org:v3")
        XCTAssertNil(ns.prefix)
        XCTAssertEqual(ns.uri, "urn:hl7-org:v3")
    }

    func testXMLNamespaceEquality() {
        let ns1 = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")
        let ns2 = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")
        XCTAssertEqual(ns1, ns2)
    }

    func testXMLNamespaceInequality() {
        let ns1 = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")
        let ns2 = XMLNamespace(prefix: "xsi", uri: "http://www.w3.org/2001/XMLSchema-instance")
        XCTAssertNotEqual(ns1, ns2)
    }

    func testXMLNamespaceHashable() {
        let ns1 = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")
        let ns2 = XMLNamespace(prefix: "hl7", uri: "urn:hl7-org:v3")
        let set: Set<XMLNamespace> = [ns1, ns2]
        XCTAssertEqual(set.count, 1)
    }

    func testHL7v3NamespaceConstant() {
        XCTAssertEqual(XMLNamespace.hl7v3.uri, "urn:hl7-org:v3")
        XCTAssertNil(XMLNamespace.hl7v3.prefix)
    }

    func testHL7v3PrefixedNamespaceConstant() {
        XCTAssertEqual(XMLNamespace.hl7v3Prefixed.uri, "urn:hl7-org:v3")
        XCTAssertEqual(XMLNamespace.hl7v3Prefixed.prefix, "hl7")
    }

    func testXSINamespaceConstant() {
        XCTAssertEqual(XMLNamespace.xsi.uri, "http://www.w3.org/2001/XMLSchema-instance")
        XCTAssertEqual(XMLNamespace.xsi.prefix, "xsi")
    }

    func testSDTCNamespaceConstant() {
        XCTAssertEqual(XMLNamespace.sdtc.uri, "urn:hl7-org:sdtc")
        XCTAssertEqual(XMLNamespace.sdtc.prefix, "sdtc")
    }

    func testXMLNamespaceConstant() {
        XCTAssertEqual(XMLNamespace.xml.uri, "http://www.w3.org/XML/1998/namespace")
        XCTAssertEqual(XMLNamespace.xml.prefix, "xml")
    }

    func testXLinkNamespaceConstant() {
        XCTAssertEqual(XMLNamespace.xlink.uri, "http://www.w3.org/1999/xlink")
        XCTAssertEqual(XMLNamespace.xlink.prefix, "xlink")
    }

    // MARK: - XMLElement Tests

    func testXMLElementCreation() {
        let elem = XMLElement(name: "test")
        XCTAssertEqual(elem.name, "test")
        XCTAssertNil(elem.namespace)
        XCTAssertNil(elem.prefix)
        XCTAssertTrue(elem.attributes.isEmpty)
        XCTAssertTrue(elem.children.isEmpty)
        XCTAssertNil(elem.text)
    }

    func testXMLElementFullCreation() {
        let child = XMLElement(name: "child", text: "value")
        let elem = XMLElement(
            name: "parent",
            namespace: "urn:hl7-org:v3",
            prefix: "hl7",
            attributes: ["code": "123"],
            children: [child],
            text: "content"
        )
        XCTAssertEqual(elem.name, "parent")
        XCTAssertEqual(elem.namespace, "urn:hl7-org:v3")
        XCTAssertEqual(elem.prefix, "hl7")
        XCTAssertEqual(elem.attributes["code"], "123")
        XCTAssertEqual(elem.children.count, 1)
        XCTAssertEqual(elem.text, "content")
    }

    func testQualifiedNameWithPrefix() {
        let elem = XMLElement(name: "ClinicalDocument", prefix: "hl7")
        XCTAssertEqual(elem.qualifiedName, "hl7:ClinicalDocument")
    }

    func testQualifiedNameWithoutPrefix() {
        let elem = XMLElement(name: "ClinicalDocument")
        XCTAssertEqual(elem.qualifiedName, "ClinicalDocument")
    }

    func testQualifiedNameEmptyPrefix() {
        let elem = XMLElement(name: "ClinicalDocument", prefix: "")
        XCTAssertEqual(elem.qualifiedName, "ClinicalDocument")
    }

    func testAttributeValue() {
        let elem = XMLElement(name: "code", attributes: ["code": "1234", "codeSystem": "2.16.840"])
        XCTAssertEqual(elem.attributeValue(forName: "code"), "1234")
        XCTAssertEqual(elem.attributeValue(forName: "codeSystem"), "2.16.840")
        XCTAssertNil(elem.attributeValue(forName: "nonexistent"))
    }

    func testChildElements() {
        let children = [
            XMLElement(name: "id"),
            XMLElement(name: "code"),
            XMLElement(name: "id"),
        ]
        let parent = XMLElement(name: "root", children: children)
        XCTAssertEqual(parent.childElements(named: "id").count, 2)
        XCTAssertEqual(parent.childElements(named: "code").count, 1)
        XCTAssertEqual(parent.childElements(named: "missing").count, 0)
    }

    func testFirstChild() {
        let children = [
            XMLElement(name: "id", attributes: ["root": "1.2.3"]),
            XMLElement(name: "id", attributes: ["root": "4.5.6"]),
        ]
        let parent = XMLElement(name: "root", children: children)
        XCTAssertEqual(parent.firstChild(named: "id")?.attributes["root"], "1.2.3")
        XCTAssertNil(parent.firstChild(named: "missing"))
    }

    func testFindElementsByName() {
        let grandchild = XMLElement(name: "target", text: "found")
        let child = XMLElement(name: "wrapper", children: [grandchild])
        let root = XMLElement(name: "root", children: [
            child,
            XMLElement(name: "target", text: "also found"),
        ])

        let results = root.findElements(byName: "target")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].text, "found")
        XCTAssertEqual(results[1].text, "also found")
    }

    func testFindElementsByNameDeepNesting() {
        let deep = XMLElement(name: "deep", text: "value")
        let level3 = XMLElement(name: "l3", children: [deep])
        let level2 = XMLElement(name: "l2", children: [level3])
        let level1 = XMLElement(name: "l1", children: [level2])
        let root = XMLElement(name: "root", children: [level1])

        let results = root.findElements(byName: "deep")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "value")
    }

    func testFindElementsByNameNotFound() {
        let root = XMLElement(name: "root", children: [
            XMLElement(name: "child"),
        ])
        XCTAssertTrue(root.findElements(byName: "nonexistent").isEmpty)
    }

    func testFindElementsByNamespace() {
        let ns = "urn:hl7-org:v3"
        let child1 = XMLElement(name: "id", namespace: ns, text: "match")
        let child2 = XMLElement(name: "id", namespace: "other:ns", text: "no match")
        let root = XMLElement(name: "root", children: [child1, child2])

        let results = root.findElements(byNamespace: ns, name: "id")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "match")
    }

    func testAllText() {
        let child = XMLElement(name: "span", text: " world")
        let root = XMLElement(name: "p", children: [child], text: "hello")
        XCTAssertEqual(root.allText, "hello world")
    }

    func testAllTextEmpty() {
        let root = XMLElement(name: "empty")
        XCTAssertEqual(root.allText, "")
    }

    func testXMLElementEquality() {
        let elem1 = XMLElement(name: "test", attributes: ["key": "value"])
        let elem2 = XMLElement(name: "test", attributes: ["key": "value"])
        XCTAssertEqual(elem1, elem2)
    }

    func testXMLElementInequality() {
        let elem1 = XMLElement(name: "test1")
        let elem2 = XMLElement(name: "test2")
        XCTAssertNotEqual(elem1, elem2)
    }

    // MARK: - XMLDocument Tests

    func testXMLDocumentCreation() {
        let doc = XMLDocument()
        XCTAssertNil(doc.root)
        XCTAssertEqual(doc.xmlVersion, "1.0")
        XCTAssertEqual(doc.encoding, "UTF-8")
    }

    func testXMLDocumentWithRoot() {
        let root = XMLElement(name: "ClinicalDocument")
        let doc = XMLDocument(root: root)
        XCTAssertEqual(doc.root?.name, "ClinicalDocument")
    }

    func testXMLDocumentFindElementsByName() {
        let root = XMLElement(name: "root", children: [
            XMLElement(name: "target"),
            XMLElement(name: "wrapper", children: [
                XMLElement(name: "target"),
            ]),
        ])
        let doc = XMLDocument(root: root)

        let results = doc.findElements(byName: "target")
        XCTAssertEqual(results.count, 2)
    }

    func testXMLDocumentFindElementsByNameIncludesRoot() {
        let root = XMLElement(name: "target")
        let doc = XMLDocument(root: root)

        let results = doc.findElements(byName: "target")
        XCTAssertEqual(results.count, 1)
    }

    func testXMLDocumentFindElementsByNameNoRoot() {
        let doc = XMLDocument()
        XCTAssertTrue(doc.findElements(byName: "anything").isEmpty)
    }

    func testXMLDocumentFindElementsByNamespace() {
        let ns = "urn:hl7-org:v3"
        let root = XMLElement(name: "root", namespace: ns, children: [
            XMLElement(name: "child", namespace: ns),
        ])
        let doc = XMLDocument(root: root)

        let results = doc.findElements(byNamespace: ns, name: "root")
        XCTAssertEqual(results.count, 1)
    }

    func testXMLDocumentFindElementsByNamespaceNoRoot() {
        let doc = XMLDocument()
        XCTAssertTrue(doc.findElements(byNamespace: "urn:test", name: "x").isEmpty)
    }

    func testXMLDocumentEquality() {
        let root = XMLElement(name: "test")
        let doc1 = XMLDocument(root: root)
        let doc2 = XMLDocument(root: root)
        XCTAssertEqual(doc1, doc2)
    }

    // MARK: - XMLParserConfiguration Tests

    func testDefaultConfiguration() {
        let config = XMLParserConfiguration.default
        XCTAssertTrue(config.validateNamespaces)
        XCTAssertFalse(config.resolveExternalEntities)
        XCTAssertEqual(config.maxDepth, 256)
        XCTAssertEqual(config.maxDocumentSize, 50 * 1024 * 1024)
    }

    func testStrictConfiguration() {
        let config = XMLParserConfiguration.strict
        XCTAssertTrue(config.validateNamespaces)
        XCTAssertFalse(config.resolveExternalEntities)
        XCTAssertEqual(config.maxDepth, 128)
        XCTAssertEqual(config.maxDocumentSize, 10 * 1024 * 1024)
    }

    func testCustomConfiguration() {
        let config = XMLParserConfiguration(
            validateNamespaces: false,
            resolveExternalEntities: false,
            maxDepth: 10,
            maxDocumentSize: 1024
        )
        XCTAssertFalse(config.validateNamespaces)
        XCTAssertEqual(config.maxDepth, 10)
        XCTAssertEqual(config.maxDocumentSize, 1024)
    }

    func testConfigurationEquality() {
        let config1 = XMLParserConfiguration.default
        let config2 = XMLParserConfiguration()
        XCTAssertEqual(config1, config2)
    }

    // MARK: - XMLDiagnostic Tests

    func testXMLDiagnosticCreation() {
        let diag = XMLDiagnostic(severity: .error, message: "test error", line: 5, column: 10)
        XCTAssertEqual(diag.severity, .error)
        XCTAssertEqual(diag.message, "test error")
        XCTAssertEqual(diag.line, 5)
        XCTAssertEqual(diag.column, 10)
    }

    func testDiagnosticSeverityRawValue() {
        XCTAssertEqual(XMLDiagnosticSeverity.warning.rawValue, "warning")
        XCTAssertEqual(XMLDiagnosticSeverity.error.rawValue, "error")
        XCTAssertEqual(XMLDiagnosticSeverity.fatal.rawValue, "fatal")
    }

    // MARK: - HL7v3XMLParser Tests

    func testParserCreation() {
        let parser = HL7v3XMLParser()
        XCTAssertEqual(parser.configuration, XMLParserConfiguration.default)
    }

    func testParserWithCustomConfig() {
        let config = XMLParserConfiguration.strict
        let parser = HL7v3XMLParser(configuration: config)
        XCTAssertEqual(parser.configuration, config)
    }

    func testParseSimpleXML() throws {
        let xml = "<root><child>text</child></root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.name, "root")
        XCTAssertEqual(doc.root?.children.count, 1)
        XCTAssertEqual(doc.root?.firstChild(named: "child")?.text, "text")
    }

    func testParseXMLWithDeclaration() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <document><title>Test</title></document>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.name, "document")
        XCTAssertEqual(doc.root?.firstChild(named: "title")?.text, "Test")
    }

    func testParseXMLWithAttributes() throws {
        let xml = """
        <code code="1234" codeSystem="2.16.840.1.113883.6.1" displayName="Test"/>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.attributeValue(forName: "code"), "1234")
        XCTAssertEqual(doc.root?.attributeValue(forName: "codeSystem"), "2.16.840.1.113883.6.1")
        XCTAssertEqual(doc.root?.attributeValue(forName: "displayName"), "Test")
    }

    func testParseXMLWithNamespace() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <id root="1.2.3"/>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.name, "ClinicalDocument")
        XCTAssertEqual(doc.root?.namespace, "urn:hl7-org:v3")
        XCTAssertEqual(doc.root?.firstChild(named: "id")?.namespace, "urn:hl7-org:v3")
    }

    func testParseXMLWithPrefixedNamespace() throws {
        let xml = """
        <hl7:ClinicalDocument xmlns:hl7="urn:hl7-org:v3">
            <hl7:id root="1.2.3"/>
        </hl7:ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.name, "ClinicalDocument")
        XCTAssertEqual(doc.root?.namespace, "urn:hl7-org:v3")
        XCTAssertEqual(doc.root?.prefix, "hl7")
    }

    func testParseXMLMultipleNamespaces() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <id root="1.2.3"/>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.namespace, "urn:hl7-org:v3")
    }

    func testParseXMLNestedElements() throws {
        let xml = """
        <root>
            <level1>
                <level2>
                    <level3>deep value</level3>
                </level2>
            </level1>
        </root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let results = doc.findElements(byName: "level3")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "deep value")
    }

    func testParseSelfClosingElements() throws {
        let xml = "<root><empty/><also-empty /></root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.children.count, 2)
        XCTAssertNil(doc.root?.children[0].text)
        XCTAssertNil(doc.root?.children[1].text)
    }

    func testParseEmptyData() {
        let parser = HL7v3XMLParser()
        XCTAssertThrowsError(try parser.parse(Data())) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
        }
    }

    func testParseMalformedXML() {
        let xml = "<root><a></b></root>"
        let parser = HL7v3XMLParser()
        XCTAssertThrowsError(try parser.parse(xml.data(using: .utf8)!)) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError, got \(error)")
                return
            }
        }
    }

    func testParseDocumentSizeExceeded() {
        let config = XMLParserConfiguration(maxDocumentSize: 10)
        let parser = HL7v3XMLParser(configuration: config)
        let xml = "<root>This is more than 10 bytes of content</root>"

        XCTAssertThrowsError(try parser.parse(xml.data(using: .utf8)!)) { error in
            guard case HL7Error.parsingError(let msg, _) = error else {
                XCTFail("Expected parsingError")
                return
            }
            XCTAssertTrue(msg.contains("exceeds maximum"))
        }
    }

    func testParseMaxDepthExceeded() {
        let config = XMLParserConfiguration(maxDepth: 3)
        let parser = HL7v3XMLParser(configuration: config)
        let xml = "<a><b><c><d>too deep</d></c></b></a>"

        XCTAssertThrowsError(try parser.parse(xml.data(using: .utf8)!)) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError")
                return
            }
        }
    }

    func testParseCDADocument() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
            <id root="1.2.3.4.5" extension="12345"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"
                codeSystemName="LOINC" displayName="Summarization of Episode Note"/>
            <title>Patient Summary</title>
            <effectiveTime value="20230615120000"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.19.5" extension="996-756-495"/>
                    <patient>
                        <name>
                            <given>John</given>
                            <family>Doe</family>
                        </name>
                    </patient>
                </patientRole>
            </recordTarget>
        </ClinicalDocument>
        """

        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.name, "ClinicalDocument")
        XCTAssertEqual(doc.root?.namespace, "urn:hl7-org:v3")

        let typeId = doc.root?.firstChild(named: "typeId")
        XCTAssertNotNil(typeId)
        XCTAssertEqual(typeId?.attributeValue(forName: "extension"), "POCD_HD000040")

        let title = doc.root?.firstChild(named: "title")
        XCTAssertEqual(title?.text, "Patient Summary")

        let givenNames = doc.findElements(byName: "given")
        XCTAssertEqual(givenNames.count, 1)
        XCTAssertEqual(givenNames[0].text, "John")

        let familyNames = doc.findElements(byName: "family")
        XCTAssertEqual(familyNames.count, 1)
        XCTAssertEqual(familyNames[0].text, "Doe")
    }

    func testParseWhitespaceHandling() throws {
        let xml = "<root>  \n  </root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        // Whitespace-only text should be trimmed to nil
        XCTAssertNil(doc.root?.text)
    }

    func testParseWithDiagnostics() throws {
        let xml = "<root><child>text</child></root>"
        let parser = HL7v3XMLParser()
        let (doc, diagnostics) = try parser.parseWithDiagnostics(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.name, "root")
        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testParseWithDiagnosticsEmptyData() {
        let parser = HL7v3XMLParser()
        XCTAssertThrowsError(try parser.parseWithDiagnostics(Data())) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError")
                return
            }
        }
    }

    func testParseWithDiagnosticsSizeExceeded() {
        let config = XMLParserConfiguration(maxDocumentSize: 5)
        let parser = HL7v3XMLParser(configuration: config)
        XCTAssertThrowsError(try parser.parseWithDiagnostics("<root/>".data(using: .utf8)!))
    }

    func testParseCDATA() throws {
        let xml = "<root><![CDATA[some <raw> content & more]]></root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        XCTAssertEqual(doc.root?.text, "some <raw> content & more")
    }

    func testParseMixedContent() throws {
        let xml = "<root>text<child>child text</child></root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.text, "text")
        XCTAssertEqual(doc.root?.firstChild(named: "child")?.text, "child text")
    }

    func testParseMultipleChildren() throws {
        let xml = """
        <root>
            <a>1</a>
            <b>2</b>
            <c>3</c>
            <a>4</a>
        </root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        XCTAssertEqual(doc.root?.children.count, 4)
        XCTAssertEqual(doc.root?.childElements(named: "a").count, 2)
    }

    // MARK: - HL7v3ValidationResult Tests

    func testValidationResultCreation() {
        let result = HL7v3ValidationResult(isValid: true)
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testValidationResultWithErrors() {
        let result = HL7v3ValidationResult(
            isValid: false,
            errors: ["error1", "error2"],
            warnings: ["warning1"]
        )
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.warnings.count, 1)
    }

    // MARK: - HL7v3SchemaValidator Tests

    func testValidatorCreation() {
        let validator = HL7v3SchemaValidator()
        _ = validator // Just verify it compiles and can be created
    }

    func testValidateEmptyDocument() {
        let validator = HL7v3SchemaValidator()
        let doc = XMLDocument()
        let result = validator.validate(doc)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains("Document has no root element"))
    }

    func testValidateValidCDADocument() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5"/>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let validator = HL7v3SchemaValidator()
        let result = validator.validate(doc)
        XCTAssertTrue(result.isValid, "Errors: \(result.errors)")
    }

    func testValidateMissingNamespace() throws {
        let xml = "<ClinicalDocument><typeId/><id/></ClinicalDocument>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let validator = HL7v3SchemaValidator()
        let result = validator.validate(doc)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("namespace") })
    }

    func testValidateMissingRequiredElements() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let validator = HL7v3SchemaValidator()
        let result = validator.validate(doc)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("typeId") })
        XCTAssertTrue(result.errors.contains { $0.contains("id") })
    }

    func testValidateUnrecognizedRootElement() throws {
        let xml = """
        <UnknownRoot xmlns="urn:hl7-org:v3">
            <content/>
        </UnknownRoot>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let validator = HL7v3SchemaValidator()
        let result = validator.validate(doc)
        // Unknown root produces a warning, not an error (namespace is present)
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.contains { $0.contains("not a recognized") })
    }

    func testValidateNonCDADocumentSkipsCDAChecks() throws {
        let xml = """
        <Observation xmlns="urn:hl7-org:v3">
            <code code="test"/>
        </Observation>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let validator = HL7v3SchemaValidator()
        let result = validator.validate(doc)
        XCTAssertTrue(result.isValid)
    }

    func testValidRootElementsList() {
        XCTAssertTrue(HL7v3SchemaValidator.validRootElements.contains("ClinicalDocument"))
        XCTAssertTrue(HL7v3SchemaValidator.validRootElements.contains("Observation"))
        XCTAssertTrue(HL7v3SchemaValidator.validRootElements.contains("Act"))
        XCTAssertFalse(HL7v3SchemaValidator.validRootElements.contains("RandomElement"))
    }

    // MARK: - XMLPathQuery Tests

    func testPathQueryAbsolutePath() throws {
        let xml = "<root><child><grandchild>value</grandchild></child></root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "/root/child/grandchild")
        let results = try query.evaluate(on: doc)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "value")
    }

    func testPathQueryAbsolutePathRootOnly() throws {
        let xml = "<root>text</root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "/root")
        let results = try query.evaluate(on: doc)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "root")
    }

    func testPathQueryAbsolutePathNoMatch() throws {
        let xml = "<root><child/></root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "/other")
        let results = try query.evaluate(on: doc)
        XCTAssertTrue(results.isEmpty)
    }

    func testPathQueryRecursiveSearch() throws {
        let xml = """
        <root>
            <a><target>1</target></a>
            <b><c><target>2</target></c></b>
            <target>3</target>
        </root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "//target")
        let results = try query.evaluate(on: doc)

        XCTAssertEqual(results.count, 3)
    }

    func testPathQueryAttributePredicate() throws {
        let xml = """
        <root>
            <id root="1.2.3" extension="A"/>
            <id root="4.5.6" extension="B"/>
        </root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "//id[@root='4.5.6']")
        let results = try query.evaluate(on: doc)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].attributeValue(forName: "extension"), "B")
    }

    func testPathQueryAttributePredicateDoubleQuotes() throws {
        let xml = """
        <root><code code="1234"/><code code="5678"/></root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "//code[@code=\"1234\"]")
        let results = try query.evaluate(on: doc)

        XCTAssertEqual(results.count, 1)
    }

    func testPathQueryRelativePath() throws {
        let xml = """
        <root>
            <child><name>first</name></child>
            <child><name>second</name></child>
        </root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let query = XMLPathQuery(expression: "child/name")
        let results = try query.evaluate(on: doc)

        XCTAssertEqual(results.count, 2)
    }

    func testPathQueryOnElement() throws {
        let element = XMLElement(name: "root", children: [
            XMLElement(name: "child", text: "test"),
        ])

        let query = XMLPathQuery(expression: "child")
        let results = try query.evaluate(on: element)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "test")
    }

    func testPathQueryEmptyExpression() {
        let doc = XMLDocument(root: XMLElement(name: "root"))
        let query = XMLPathQuery(expression: "")

        XCTAssertThrowsError(try query.evaluate(on: doc)) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError")
                return
            }
        }
    }

    func testPathQueryNoRoot() throws {
        let doc = XMLDocument()
        let query = XMLPathQuery(expression: "/root")
        let results = try query.evaluate(on: doc)
        XCTAssertTrue(results.isEmpty)
    }

    func testPathQueryEquality() {
        let q1 = XMLPathQuery(expression: "//test")
        let q2 = XMLPathQuery(expression: "//test")
        XCTAssertEqual(q1, q2)
    }

    func testPathQueryCDANavigation() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <recordTarget>
                <patientRole>
                    <id root="2.16.840.1.113883.19.5" extension="12345"/>
                    <patient>
                        <name><given>Jane</given><family>Smith</family></name>
                    </patient>
                </patientRole>
            </recordTarget>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        // Find all given names recursively
        let givenQuery = XMLPathQuery(expression: "//given")
        let givenResults = try givenQuery.evaluate(on: doc)
        XCTAssertEqual(givenResults.count, 1)
        XCTAssertEqual(givenResults[0].text, "Jane")

        // Navigate absolute path
        let pathQuery = XMLPathQuery(expression: "/ClinicalDocument/recordTarget/patientRole/patient")
        let pathResults = try pathQuery.evaluate(on: doc)
        XCTAssertEqual(pathResults.count, 1)
    }

    func testPathQueryAbsolutePathInvalidAfterSlash() {
        let doc = XMLDocument(root: XMLElement(name: "root"))
        let query = XMLPathQuery(expression: "/")

        XCTAssertThrowsError(try query.evaluate(on: doc)) { error in
            guard case HL7Error.parsingError = error else {
                XCTFail("Expected parsingError")
                return
            }
        }
    }

    // MARK: - HL7v3XMLSerializer Tests

    func testSerializerCreation() {
        let serializer = HL7v3XMLSerializer()
        XCTAssertFalse(serializer.prettyPrint)
        XCTAssertEqual(serializer.indentation, "  ")
    }

    func testSerializerPrettyPrint() {
        let serializer = HL7v3XMLSerializer(prettyPrint: true)
        XCTAssertTrue(serializer.prettyPrint)
    }

    func testSerializeSimpleElement() {
        let doc = XMLDocument(root: XMLElement(name: "root", text: "hello"))
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.hasPrefix("<?xml"))
        XCTAssertTrue(output.contains("<root>hello</root>"))
    }

    func testSerializeSelfClosingElement() {
        let doc = XMLDocument(root: XMLElement(name: "empty"))
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("<empty/>"))
    }

    func testSerializeWithAttributes() {
        let elem = XMLElement(name: "code", attributes: ["code": "123", "system": "2.16"])
        let doc = XMLDocument(root: elem)
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("code=\"123\""))
        XCTAssertTrue(output.contains("system=\"2.16\""))
    }

    func testSerializeWithNamespace() {
        let elem = XMLElement(name: "ClinicalDocument", namespace: "urn:hl7-org:v3")
        let doc = XMLDocument(root: elem)
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("xmlns=\"urn:hl7-org:v3\""))
    }

    func testSerializeWithPrefixedNamespace() {
        let elem = XMLElement(name: "ClinicalDocument", namespace: "urn:hl7-org:v3", prefix: "hl7")
        let doc = XMLDocument(root: elem)
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("xmlns:hl7=\"urn:hl7-org:v3\""))
        XCTAssertTrue(output.contains("<hl7:ClinicalDocument"))
    }

    func testSerializeNestedElements() {
        let child = XMLElement(name: "child", text: "text")
        let root = XMLElement(name: "root", children: [child])
        let doc = XMLDocument(root: root)
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("<child>text</child>"))
        XCTAssertTrue(output.contains("<root>"))
        XCTAssertTrue(output.contains("</root>"))
    }

    func testSerializePrettyPrint() {
        let child = XMLElement(name: "child", text: "text")
        let root = XMLElement(name: "root", children: [child])
        let doc = XMLDocument(root: root)
        let serializer = HL7v3XMLSerializer(prettyPrint: true)
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("\n"))
        XCTAssertTrue(output.contains("  <child>text</child>"))
    }

    func testSerializeToData() throws {
        let doc = XMLDocument(root: XMLElement(name: "root"))
        let serializer = HL7v3XMLSerializer()
        let data = try serializer.serialize(doc)
        let string = String(data: data, encoding: .utf8)
        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("<root/>"))
    }

    func testSerializeElementToString() {
        let element = XMLElement(name: "test", text: "value")
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeElementToString(element)
        XCTAssertEqual(output, "<test>value</test>")
    }

    func testSerializeSpecialCharacters() {
        let doc = XMLDocument(root: XMLElement(name: "text", text: "a < b & c > d"))
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("a &lt; b &amp; c &gt; d"))
    }

    func testSerializeAttributeSpecialCharacters() {
        let elem = XMLElement(name: "test", attributes: ["value": "a\"b'c&d<e>f"])
        let doc = XMLDocument(root: elem)
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("&quot;"))
        XCTAssertTrue(output.contains("&amp;"))
    }

    func testSerializeNoRoot() {
        let doc = XMLDocument()
        let serializer = HL7v3XMLSerializer()
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.hasPrefix("<?xml"))
        XCTAssertFalse(output.contains("<root"))
    }

    func testSerializeCustomIndentation() {
        let child = XMLElement(name: "child", text: "text")
        let root = XMLElement(name: "root", children: [child])
        let doc = XMLDocument(root: root)
        let serializer = HL7v3XMLSerializer(prettyPrint: true, indentation: "\t")
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("\t<child>text</child>"))
    }

    func testSerializeMixedContent() {
        let child = XMLElement(name: "b", text: "bold")
        let root = XMLElement(name: "p", children: [child], text: "text ")
        let doc = XMLDocument(root: root)
        let serializer = HL7v3XMLSerializer(prettyPrint: true)
        let output = serializer.serializeToString(doc)

        XCTAssertTrue(output.contains("text "))
        XCTAssertTrue(output.contains("<b>bold</b>"))
    }

    // MARK: - Round-Trip Tests

    func testRoundTripSimple() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <root><child>text</child></root>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let serializer = HL7v3XMLSerializer()
        let serialized = serializer.serializeToString(doc)
        XCTAssertTrue(serialized.contains("<root>"))
        XCTAssertTrue(serialized.contains("<child>text</child>"))

        // Re-parse
        let doc2 = try parser.parse(serialized.data(using: .utf8)!)
        XCTAssertEqual(doc2.root?.name, "root")
        XCTAssertEqual(doc2.root?.firstChild(named: "child")?.text, "text")
    }

    func testRoundTripCDA() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3"/>
            <title>Test Doc</title>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)

        let serializer = HL7v3XMLSerializer()
        let data = try serializer.serialize(doc)

        let doc2 = try parser.parse(data)
        XCTAssertEqual(doc2.root?.name, "ClinicalDocument")
        XCTAssertEqual(doc2.root?.firstChild(named: "title")?.text, "Test Doc")
    }

    // MARK: - Sendable Conformance Tests

    func testXMLElementSendable() async {
        let element = XMLElement(name: "test", text: "value")
        let result = await Task {
            return element.name
        }.value
        XCTAssertEqual(result, "test")
    }

    func testXMLDocumentSendable() async {
        let doc = XMLDocument(root: XMLElement(name: "root"))
        let result = await Task {
            return doc.root?.name
        }.value
        XCTAssertEqual(result, "root")
    }

    func testParserSendable() async throws {
        let parser = HL7v3XMLParser()
        let xml = "<root><child>value</child></root>".data(using: .utf8)!
        let result = try await Task {
            return try parser.parse(xml)
        }.value
        XCTAssertEqual(result.root?.name, "root")
    }

    func testSerializerSendable() async {
        let serializer = HL7v3XMLSerializer()
        let doc = XMLDocument(root: XMLElement(name: "test"))
        let result = await Task {
            return serializer.serializeToString(doc)
        }.value
        XCTAssertTrue(result.contains("<test/>"))
    }

    func testValidatorSendable() async throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3"/>
            <id root="1.2.3"/>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        let validator = HL7v3SchemaValidator()

        let result = await Task {
            return validator.validate(doc)
        }.value
        XCTAssertTrue(result.isValid)
    }

    func testConfigurationSendable() async {
        let config = XMLParserConfiguration.strict
        let result = await Task {
            return config.maxDepth
        }.value
        XCTAssertEqual(result, 128)
    }

    func testNamespaceSendable() async {
        let ns = XMLNamespace.hl7v3
        let result = await Task {
            return ns.uri
        }.value
        XCTAssertEqual(result, "urn:hl7-org:v3")
    }

    // MARK: - Edge Case Tests

    func testParseEmptyRoot() throws {
        let xml = "<root/>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        XCTAssertEqual(doc.root?.name, "root")
        XCTAssertTrue(doc.root?.children.isEmpty ?? false)
        XCTAssertNil(doc.root?.text)
    }

    func testParseSpecialCharactersInText() throws {
        let xml = "<root>&amp; &lt; &gt;</root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        XCTAssertEqual(doc.root?.text, "& < >")
    }

    func testParseSpecialCharactersInAttributes() throws {
        let xml = "<root attr=\"a&amp;b\"/>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        XCTAssertEqual(doc.root?.attributeValue(forName: "attr"), "a&b")
    }

    func testParseLargeDocument() throws {
        var xml = "<root>"
        for i in 0..<100 {
            xml += "<item id=\"\(i)\">Value \(i)</item>"
        }
        xml += "</root>"

        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        XCTAssertEqual(doc.root?.children.count, 100)
    }

    func testFindElementsEmptyChildren() {
        let root = XMLElement(name: "root")
        XCTAssertTrue(root.findElements(byName: "anything").isEmpty)
    }

    func testFindElementsByNamespaceEmptyChildren() {
        let root = XMLElement(name: "root")
        XCTAssertTrue(root.findElements(byNamespace: "urn:test", name: "anything").isEmpty)
    }

    // MARK: - Performance Tests

    func testParsePerformance() throws {
        var xml = "<root>"
        for i in 0..<1000 {
            xml += "<item id=\"\(i)\">Value \(i)</item>"
        }
        xml += "</root>"
        let data = xml.data(using: .utf8)!
        let parser = HL7v3XMLParser()

        measure {
            _ = try? parser.parse(data)
        }
    }

    func testSerializePerformance() {
        var children: [XMLElement] = []
        for i in 0..<1000 {
            children.append(XMLElement(name: "item", attributes: ["id": "\(i)"], text: "Value \(i)"))
        }
        let doc = XMLDocument(root: XMLElement(name: "root", children: children))
        let serializer = HL7v3XMLSerializer()

        measure {
            _ = serializer.serializeToString(doc)
        }
    }

    func testQueryPerformance() throws {
        var xml = "<root>"
        for i in 0..<500 {
            xml += "<wrapper><target id=\"\(i)\">Value \(i)</target></wrapper>"
        }
        xml += "</root>"
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        let query = XMLPathQuery(expression: "//target")

        measure {
            _ = try? query.evaluate(on: doc)
        }
    }

    func testValidationPerformance() throws {
        let xml = """
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3"/>
            <id root="1.2.3"/>
            <title>Test</title>
        </ClinicalDocument>
        """
        let parser = HL7v3XMLParser()
        let doc = try parser.parse(xml.data(using: .utf8)!)
        let validator = HL7v3SchemaValidator()

        measure {
            for _ in 0..<1000 {
                _ = validator.validate(doc)
            }
        }
    }
}
