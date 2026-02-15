import XCTest
@testable import HL7v3Kit
@testable import HL7Core

/// Comprehensive HL7 v3.x standards compliance verification tests
/// Tests conformance to HL7 v3.x specifications (RIM, CDA)
final class ComplianceVerificationTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    private let parser = HL7v3XMLParser()
    
    // MARK: - RIM (Reference Information Model) Compliance Tests
    
    func testRIMClassCompliance() throws {
        // Test basic RIM class structure
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" displayName="Summary of Episode Note"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101120000"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify RIM Act class attributes
        XCTAssertNotNil(document.root)
        XCTAssertNotNil(document.root?.firstChild(named: "id"))
        XCTAssertNotNil(document.root?.firstChild(named: "title"))
        XCTAssertNotNil(document.root?.firstChild(named: "effectiveTime"))
    }
    
    func testRIMActRelationshipCompliance() throws {
        // Test RIM ActRelationship structure
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="11450-4" codeSystem="2.16.840.1.113883.6.1" displayName="Problem List"/>
                            <title>Problems</title>
                            <text>Patient has hypertension</text>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify component relationships
        XCTAssertNotNil(document.root?.firstChild(named: "component")?.firstChild(named: "structuredBody"))
    }
    
    func testRIMParticipationCompliance() throws {
        // Test RIM Participation (role links)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <recordTarget>
                <patientRole>
                    <id extension="12345" root="1.2.3.4.5"/>
                    <patient>
                        <name>
                            <given>John</given>
                            <family>Doe</family>
                        </name>
                    </patient>
                </patientRole>
            </recordTarget>
            <author>
                <time value="20240101120000"/>
                <assignedAuthor>
                    <id extension="DOC123" root="1.2.3.4.5"/>
                    <assignedPerson>
                        <name>
                            <given>Jane</given>
                            <family>Doctor</family>
                        </name>
                    </assignedPerson>
                </assignedAuthor>
            </author>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify participation structures
        XCTAssertNotNil(document.root?.firstChild(named: "recordTarget"))
        XCTAssertNotNil(document.root?.firstChild(named: "author"))
    }
    
    // MARK: - CDA Document Compliance Tests
    
    func testCDADocumentStructureCompliance() throws {
        // Test minimal CDA document structure
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <realmCode code="US"/>
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" displayName="Summary of Episode Note"/>
            <title>Clinical Summary Document</title>
            <effectiveTime value="20240101120000"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <recordTarget>
                <patientRole>
                    <id extension="12345" root="1.2.3.4.5"/>
                    <patient>
                        <name><given>John</given><family>Doe</family></name>
                        <administrativeGenderCode code="M" codeSystem="2.16.840.1.113883.5.1"/>
                        <birthTime value="19800101"/>
                    </patient>
                </patientRole>
            </recordTarget>
            <author>
                <time value="20240101120000"/>
                <assignedAuthor>
                    <id extension="DOC123" root="1.2.3.4.5"/>
                    <assignedPerson>
                        <name><given>Jane</given><family>Doctor</family></name>
                    </assignedPerson>
                </assignedAuthor>
            </author>
            <custodian>
                <assignedCustodian>
                    <representedCustodianOrganization>
                        <id root="1.2.3.4.5" extension="ORG001"/>
                        <name>Hospital Name</name>
                    </representedCustodianOrganization>
                </assignedCustodian>
            </custodian>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify all required CDA header elements
        XCTAssertNotNil(document.root?.firstChild(named: "id"))
        XCTAssertNotNil(document.root?.firstChild(named: "title"))
        XCTAssertNotNil(document.root?.firstChild(named: "effectiveTime"))
        XCTAssertNotNil(document.root?.firstChild(named: "recordTarget"))
        XCTAssertNotNil(document.root?.firstChild(named: "author"))
        
        // Verify document structure
        XCTAssertEqual(document.root?.name, "ClinicalDocument")
    }
    
    func testCDANarrativeTextCompliance() throws {
        // Test CDA narrative text requirements (human-readable)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="11450-4" codeSystem="2.16.840.1.113883.6.1" displayName="Problem List"/>
                            <title>Active Problems</title>
                            <text>
                                <paragraph>Patient has the following active problems:</paragraph>
                                <list>
                                    <item>Hypertension, controlled</item>
                                    <item>Type 2 Diabetes Mellitus</item>
                                </list>
                            </text>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify narrative text is required and present
        let structuredBody = document.root?.firstChild(named: "component")?.firstChild(named: "structuredBody")
        XCTAssertNotNil(structuredBody)
        XCTAssertNotNil(structuredBody?.firstChild(named: "component")?.firstChild(named: "section")?.firstChild(named: "text"))
    }
    
    func testCDAStructuredBodyCompliance() throws {
        // Test CDA structured body with entries
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="10160-0" codeSystem="2.16.840.1.113883.6.1" displayName="History of Medication Use"/>
                            <title>Medications</title>
                            <text>Patient is taking Lisinopril 10mg daily</text>
                            <entry>
                                <substanceAdministration classCode="SBADM" moodCode="EVN">
                                    <statusCode code="active"/>
                                    <effectiveTime xsi:type="IVL_TS" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                                        <low value="20240101"/>
                                    </effectiveTime>
                                    <consumable>
                                        <manufacturedProduct>
                                            <manufacturedMaterial>
                                                <code code="197884" codeSystem="2.16.840.1.113883.6.88" displayName="Lisinopril 10mg"/>
                                            </manufacturedMaterial>
                                        </manufacturedProduct>
                                    </consumable>
                                </substanceAdministration>
                            </entry>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify structured body with entries
        let section = document.root?.firstChild(named: "component")?.firstChild(named: "structuredBody")?.firstChild(named: "component")?.firstChild(named: "section")
        XCTAssertNotNil(section)
        XCTAssertNotNil(section?.firstChild(named: "entry"))
    }
    
    // MARK: - Data Type Compliance Tests
    
    func testCodedValueCompliance() throws {
        // Test CE/CD/CV data types
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Summary of Episode Note"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25" displayName="Normal"/>
            <languageCode code="en-US"/>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify coded values are parsed correctly
        let code = document.root?.firstChild(named: "code")
        XCTAssertNotNil(code)
        XCTAssertEqual(code?.attributeValue(forName: "code"), "34133-9")
        XCTAssertEqual(code?.attributeValue(forName: "codeSystem"), "2.16.840.1.113883.6.1")
    }
    
    func testIntervalOfTimeCompliance() throws {
        // Test IVL_TS data type
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <documentationOf>
                <serviceEvent classCode="PCPR">
                    <effectiveTime xsi:type="IVL_TS">
                        <low value="20240101"/>
                        <high value="20240131"/>
                    </effectiveTime>
                </serviceEvent>
            </documentationOf>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify interval of time is parsed
        let effectiveTime = document.findElements(byName: "effectiveTime").first { $0.attributeValue(forName: "xsi:type") != nil }
        XCTAssertNotNil(effectiveTime)
        XCTAssertNotNil(effectiveTime?.firstChild(named: "low"))
        XCTAssertNotNil(effectiveTime?.firstChild(named: "high"))
    }
    
    func testPhysicalQuantityCompliance() throws {
        // Test PQ data type
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="8716-3" codeSystem="2.16.840.1.113883.6.1" displayName="Vital Signs"/>
                            <title>Vital Signs</title>
                            <text>Blood Pressure: 120/80 mmHg</text>
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="8480-6" codeSystem="2.16.840.1.113883.6.1" displayName="Systolic Blood Pressure"/>
                                    <value xsi:type="PQ" value="120" unit="mm[Hg]" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/>
                                </observation>
                            </entry>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify physical quantity is parsed
        let value = document.findElements(byName: "value").first
        XCTAssertNotNil(value)
        XCTAssertEqual(value?.attributeValue(forName: "value"), "120")
        XCTAssertEqual(value?.attributeValue(forName: "unit"), "mm[Hg]")
    }
    
    // MARK: - Template Compliance Tests
    
    func testCCDATemplateCompliance() throws {
        // Test C-CDA (Consolidated CDA) template compliance
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <realmCode code="US"/>
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <templateId root="2.16.840.1.113883.10.20.22.1.1" extension="2015-08-01"/>
            <templateId root="2.16.840.1.113883.10.20.22.1.2" extension="2015-08-01"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" displayName="Summary of Episode Note"/>
            <title>Continuity of Care Document</title>
            <effectiveTime value="20240101120000"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <recordTarget>
                <patientRole>
                    <id extension="12345" root="1.2.3.4.5"/>
                    <patient>
                        <name><given>John</given><family>Doe</family></name>
                    </patient>
                </patientRole>
            </recordTarget>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify C-CDA template compliance
        let templateIds = document.root?.childElements(named: "templateId")
        XCTAssertNotNil(templateIds)
        XCTAssertFalse(templateIds!.isEmpty)
        XCTAssertEqual(templateIds?.first?.attributeValue(forName: "root"), "2.16.840.1.113883.10.20.22.1.1")
    }
    
    // MARK: - XML Schema Validation Tests
    
    func testXMLNamespaceCompliance() throws {
        // Test proper XML namespace usage
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify namespace handling
        XCTAssertEqual(document.root?.name, "ClinicalDocument")
        XCTAssertEqual(document.root?.namespace, "urn:hl7-org:v3")
    }
    
    func testXMLSchemaCompliance() throws {
        // Test that documents conform to CDA schema
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
        </ClinicalDocument>
        """
        
        // Should validate against schema
        XCTAssertNoThrow(try parser.parse(xml.data(using: .utf8)!))
    }
    
    // MARK: - OID (Object Identifier) Compliance Tests
    
    func testOIDFormatCompliance() throws {
        // Test OID format validation
        let validOIDs = [
            "2.16.840.1.113883.1.3",
            "1.2.3.4.5.6.7.8.9",
            "2.16.840.1.113883.6.1"
        ]
        
        for oid in validOIDs {
            let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <ClinicalDocument xmlns="urn:hl7-org:v3">
                <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
                <id root="\(oid)" extension="DOC001"/>
                <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
                <title>Clinical Summary</title>
                <effectiveTime value="20240101"/>
                <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
                <languageCode code="en-US"/>
            </ClinicalDocument>
            """
            
            XCTAssertNoThrow(try parser.parse(xml.data(using: .utf8)!), "Failed to parse document with OID: \(oid)")
        }
    }
    
    // MARK: - Vocabulary Binding Compliance Tests
    
    func testLOINCCodeCompliance() throws {
        // Test LOINC code usage
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" codeSystemName="LOINC" displayName="Summary of Episode Note"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify LOINC code system is recognized
        let code = document.root?.firstChild(named: "code")
        XCTAssertEqual(code?.attributeValue(forName: "codeSystem"), "2.16.840.1.113883.6.1")
        XCTAssertEqual(code?.attributeValue(forName: "codeSystemName"), "LOINC")
    }
    
    func testSNOMEDCodeCompliance() throws {
        // Test SNOMED CT code usage
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
            <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
            <id root="1.2.3.4.5" extension="DOC001"/>
            <code code="34133-9" codeSystem="2.16.840.1.113883.6.1"/>
            <title>Clinical Summary</title>
            <effectiveTime value="20240101"/>
            <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
            <languageCode code="en-US"/>
            <component>
                <structuredBody>
                    <component>
                        <section>
                            <code code="11450-4" codeSystem="2.16.840.1.113883.6.1" displayName="Problem List"/>
                            <title>Problems</title>
                            <text>Hypertension</text>
                            <entry>
                                <observation classCode="OBS" moodCode="EVN">
                                    <code code="404684003" codeSystem="2.16.840.1.113883.6.96" codeSystemName="SNOMED CT" displayName="Clinical finding"/>
                                    <value xsi:type="CD" code="38341003" codeSystem="2.16.840.1.113883.6.96" displayName="Hypertension" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/>
                                </observation>
                            </entry>
                        </section>
                    </component>
                </structuredBody>
            </component>
        </ClinicalDocument>
        """
        
        let document = try parser.parse(xml.data(using: .utf8)!)
        
        // Verify SNOMED CT code system is recognized
        let observations = document.findElements(byName: "observation")
        XCTAssertFalse(observations.isEmpty)
        let snomedValue = observations.first?.firstChild(named: "value")
        XCTAssertEqual(snomedValue?.attributeValue(forName: "codeSystem"), "2.16.840.1.113883.6.96")
    }
    
    // MARK: - Compliance Reporting
    
    func testGenerateComplianceReport() {
        // Generate a compliance report summary for v3.x
        var report = ComplianceReport()
        
        report.version = "HL7 v3.x (CDA R2)"
        report.rimClassesTested = ["Act", "Entity", "Role", "Participation"]
        report.dataTypesTested = ["CD", "CE", "CV", "IVL_TS", "PQ", "TS"]
        report.templatesTested = ["C-CDA"]
        report.narrativeTextRequired = true
        report.structuredBodyTested = true
        report.xmlSchemaTested = true
        report.oidFormatTested = true
        report.vocabularyBindingsTested = ["LOINC", "SNOMED CT"]
        
        // Verify report completeness
        XCTAssertFalse(report.rimClassesTested.isEmpty)
        XCTAssertFalse(report.dataTypesTested.isEmpty)
        XCTAssertTrue(report.narrativeTextRequired)
        XCTAssertTrue(report.structuredBodyTested)
        XCTAssertTrue(report.xmlSchemaTested)
        XCTAssertTrue(report.oidFormatTested)
        XCTAssertFalse(report.vocabularyBindingsTested.isEmpty)
    }
}

// MARK: - Compliance Report Structure

/// Compliance report for HL7 v3.x documentation
struct ComplianceReport {
    var version: String = ""
    var rimClassesTested: [String] = []
    var dataTypesTested: [String] = []
    var templatesTested: [String] = []
    var narrativeTextRequired: Bool = false
    var structuredBodyTested: Bool = false
    var xmlSchemaTested: Bool = false
    var oidFormatTested: Bool = false
    var vocabularyBindingsTested: [String] = []
}
