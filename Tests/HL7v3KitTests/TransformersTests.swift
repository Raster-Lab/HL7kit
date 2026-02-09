/// TransformersTests.swift
/// Tests for concrete transformer implementations
///
/// Tests v2.x to v3.x and v3.x to v2.x transformations

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

#if canImport(HL7v2Kit)
import HL7v2Kit

final class TransformersTests: XCTestCase {
    
    // MARK: - ADT to CDA Tests
    
    func testADTToCDABasicTransformation() async throws {
        // Create a sample ADT message
        let adtString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20240101120000||ADT^A01|MSG001|P|2.5
        EVN|A01|20240101120000
        PID|1||12345^^^MRN||DOE^JOHN^M||19800515|M|||123 MAIN ST^^ANYTOWN^CA^12345
        PV1|1|I|W^389^1^UABH^^^^3||||12345^JONES^DOCTOR
        """
        
        let message = try HL7v2Message.parse(adtString)
        let adtMessage = try ADTMessage(message: message)
        
        // Create transformer
        let transformer = ADTToCDATransformer()
        let context = TransformationContext(
            configuration: .default
        )
        
        // Transform
        let result = try await transformer.transform(adtMessage, context: context)
        
        // Verify result
        XCTAssertTrue(result.success, "Transformation should succeed")
        XCTAssertNotNil(result.target, "Should have target document")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
        
        // Verify CDA document structure
        if let cdaDoc = result.target {
            XCTAssertEqual(cdaDoc.recordTarget.count, 1, "Should have one record target")
            XCTAssertEqual(cdaDoc.author.count, 1, "Should have one author")
            XCTAssertNotNil(cdaDoc.custodian, "Should have custodian")
            
            // Verify patient data
            let patient = cdaDoc.recordTarget[0].patientRole
            XCTAssertFalse(patient.id.isEmpty, "Patient should have ID")
            XCTAssertNotNil(patient.patient, "Should have patient person")
            
            if let patientPerson = patient.patient {
                XCTAssertFalse(patientPerson.name?.isEmpty ?? true, "Patient should have name")
                XCTAssertNotNil(patientPerson.administrativeGenderCode, "Should have gender")
                XCTAssertNotNil(patientPerson.birthTime, "Should have birth time")
            }
        }
    }
    
    func testADTToCDAWithMissingPID() async throws {
        // Create an ADT message missing the PID segment
        let adtString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20240101120000||ADT^A01|MSG001|P|2.5
        EVN|A01|20240101120000
        PV1|1|I|W^389^1^UABH^^^^3||||12345^JONES^DOCTOR
        """
        
        let message = try HL7v2Message.parse(adtString)
        let adtMessage = try ADTMessage(message: message)
        
        let transformer = ADTToCDATransformer()
        let context = TransformationContext()
        
        // Transform - should fail due to missing PID
        let result = try await transformer.transform(adtMessage, context: context)
        
        XCTAssertFalse(result.success, "Transformation should fail")
        XCTAssertNil(result.target, "Should not have target document")
        XCTAssertFalse(result.errors.isEmpty, "Should have errors")
        
        // Verify error details
        let hasError = result.errors.contains { $0.code == "MISSING_PID" }
        XCTAssertTrue(hasError, "Should have MISSING_PID error")
    }
    
    func testADTToCDAWithLenientValidation() async throws {
        // Create ADT with some invalid data
        let adtString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20240101120000||ADT^A01|MSG001|P|2.5
        EVN|A01|20240101120000
        PID|1||12345^^^MRN||DOE^JOHN||19800515|M
        PV1|1|I
        """
        
        let message = try HL7v2Message.parse(adtString)
        let adtMessage = try ADTMessage(message: message)
        
        let transformer = ADTToCDATransformer()
        let context = TransformationContext(
            configuration: .lenient
        )
        
        // Transform with lenient mode
        let result = try await transformer.transform(adtMessage, context: context)
        
        // Should succeed with warnings
        XCTAssertTrue(result.success || !result.warnings.isEmpty, "Should succeed or have warnings")
    }
    
    func testADTToCDAMetrics() async throws {
        let adtString = """
        MSH|^~\\&|SENDING_APP|SENDING_FAC|RECEIVING_APP|RECEIVING_FAC|20240101120000||ADT^A01|MSG001|P|2.5
        EVN|A01|20240101120000
        PID|1||12345^^^MRN||DOE^JOHN^M||19800515|M
        PV1|1|I
        """
        
        let message = try HL7v2Message.parse(adtString)
        let adtMessage = try ADTMessage(message: message)
        
        let transformer = ADTToCDATransformer()
        let context = TransformationContext(
            configuration: TransformationConfiguration(trackMetrics: true)
        )
        
        let result = try await transformer.transform(adtMessage, context: context)
        
        XCTAssertNotNil(result.metrics, "Should have metrics")
        if let metrics = result.metrics {
            XCTAssertGreaterThan(metrics.duration, 0, "Should track duration")
            XCTAssertGreaterThan(metrics.fieldsMapped, 0, "Should track mapped fields")
        }
    }
    
    // MARK: - CDA to ADT Tests
    
    func testCDAToADTBasicTransformation() async throws {
        // Create a sample CDA document
        let patientName = EN(
            parts: [
                EN.NamePart(value: "DOE", type: .family),
                EN.NamePart(value: "JOHN", type: .given),
            ],
            use: .legal
        )
        
        let patientEntity = Patient(
            name: [patientName],
            administrativeGenderCode: CD(
                code: "M",
                codeSystem: "2.16.840.1.113883.5.1",
                codeSystemName: "AdministrativeGender",
                displayName: nil
            ),
            birthTime: TS(value: Date(timeIntervalSince1970: 327196800))
        )
        
        let patientRole = PatientRole(
            id: [II(root: "2.16.840.1.113883.19.5", extension: "12345")],
            patient: patientEntity
        )
        
        let recordTarget = RecordTarget(patientRole: patientRole)
        
        let authorPerson = Person(
            name: [EN(parts: [EN.NamePart(value: "TEST_FACILITY", type: .given)], use: .legal)]
        )
        
        let assignedAuthor = AssignedAuthor(
            id: [II(root: "2.16.840.1.113883.19.5", extension: "AUTO")],
            code: nil,
            addr: nil,
            telecom: nil,
            assignedPerson: authorPerson,
            representedOrganization: nil
        )
        
        let author = Author(
            time: TS(value: Date()),
            assignedAuthor: assignedAuthor
        )
        
        let custodianOrg = CustodianOrganization(
            id: [II(root: "2.16.840.1.113883.19.5")],
            name: EN(parts: [EN.NamePart(value: "TEST_FACILITY", type: .given)])
        )
        
        let assignedCustodian = AssignedCustodian(
            representedCustodianOrganization: custodianOrg
        )
        
        let custodian = Custodian(assignedCustodian: assignedCustodian)
        
        let section = Section(
            id: II(root: UUID().uuidString),
            code: CD(code: "11535-2", codeSystem: "2.16.840.1.113883.6.1", codeSystemName: "LOINC", displayName: nil),
            title: .value("Test Section")
        )
        
        let structuredBody = StructuredBody(
            component: [BodyComponent(section: section)]
        )
        
        let component = DocumentComponent(
            body: .structured(structuredBody)
        )
        
        let cdaDoc = ClinicalDocument(
            realmCode: nil,
            typeId: II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040"),
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: II(root: UUID().uuidString),
            code: CD(code: "34133-9", codeSystem: "2.16.840.1.113883.6.1", codeSystemName: "LOINC", displayName: nil),
            title: .value("Test Document"),
            effectiveTime: TS(value: Date()),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25", codeSystemName: "Confidentiality", displayName: nil),
            languageCode: nil,
            setId: nil,
            versionNumber: nil,
            copyTime: nil,
            recordTarget: [recordTarget],
            author: [author],
            dataEnterer: nil,
            informant: nil,
            custodian: custodian,
            informationRecipient: nil,
            legalAuthenticator: nil,
            authenticator: nil,
            relatedDocument: nil,
            authorization: nil,
            component: component
        )
        
        // Create transformer
        let transformer = CDAToADTTransformer()
        let context = TransformationContext()
        
        // Transform
        let result = try await transformer.transform(cdaDoc, context: context)
        
        // Verify result
        XCTAssertTrue(result.success, "Transformation should succeed")
        XCTAssertNotNil(result.target, "Should have target ADT message")
        
        if let adtMessage = result.target {
            // Verify message structure
            XCTAssertEqual(adtMessage.message.messageType(), "ADT^A08")
            XCTAssertNotNil(adtMessage.patientSegment, "Should have PID segment")
            XCTAssertNotNil(adtMessage.visitSegment, "Should have PV1 segment")
            
            // Verify patient name was mapped
            let name = adtMessage.patientName
            XCTAssertTrue(name.contains("DOE"), "Should contain family name")
            XCTAssertTrue(name.contains("JOHN"), "Should contain given name")
            
            // Verify sex was mapped
            let sex = adtMessage.sex
            XCTAssertEqual(sex, "M", "Should map gender correctly")
        }
    }
    
    func testCDAToADTMissingRecordTarget() async throws {
        // Create CDA without recordTarget (invalid)
        let custodianOrg = CustodianOrganization(
            id: [II(root: "2.16.840.1.113883.19.5")],
            name: EN(parts: [EN.NamePart(value: "TEST", type: .given)])
        )
        
        let section = Section(
            id: II(root: UUID().uuidString),
            code: CD(code: "11535-2", codeSystem: "2.16.840.1.113883.6.1", codeSystemName: "LOINC", displayName: nil),
            title: .value("Test")
        )
        
        let structuredBody = StructuredBody(
            component: [BodyComponent(section: section)]
        )
        
        let cdaDoc = ClinicalDocument(
            realmCode: nil,
            typeId: II(root: "2.16.840.1.113883.1.3", extension: "POCD_HD000040"),
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: II(root: UUID().uuidString),
            code: CD(code: "34133-9", codeSystem: "2.16.840.1.113883.6.1", codeSystemName: "LOINC", displayName: nil),
            title: .value("Test"),
            effectiveTime: TS(value: Date()),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25", codeSystemName: "Confidentiality", displayName: nil),
            languageCode: nil,
            setId: nil,
            versionNumber: nil,
            copyTime: nil,
            recordTarget: [],  // Empty!
            author: [],
            dataEnterer: nil,
            informant: nil,
            custodian: Custodian(assignedCustodian: AssignedCustodian(representedCustodianOrganization: custodianOrg)),
            informationRecipient: nil,
            legalAuthenticator: nil,
            authenticator: nil,
            relatedDocument: nil,
            authorization: nil,
            component: DocumentComponent(body: .structured(structuredBody))
        )
        
        let transformer = CDAToADTTransformer()
        let context = TransformationContext()
        
        let result = try await transformer.transform(cdaDoc, context: context)
        
        XCTAssertFalse(result.success, "Should fail without record target")
        XCTAssertNil(result.target)
        XCTAssertFalse(result.errors.isEmpty)
        
        let hasError = result.errors.contains { $0.code == "MISSING_RECORD_TARGET" }
        XCTAssertTrue(hasError, "Should have MISSING_RECORD_TARGET error")
    }
    
    // MARK: - Factory Tests
    
    func testTransformerFactory() {
        // Test v2 to v3 factory
        let adtToCda = TransformerFactory.v2ToV3(
            sourceType: ADTMessage.self,
            targetType: ClinicalDocument.self
        )
        XCTAssertNotNil(adtToCda, "Should create ADT to CDA transformer")
        
        let oruToCda = TransformerFactory.v2ToV3(
            sourceType: ORUMessage.self,
            targetType: ClinicalDocument.self
        )
        XCTAssertNotNil(oruToCda, "Should create ORU to CDA transformer")
        
        let ormToCda = TransformerFactory.v2ToV3(
            sourceType: ORMMessage.self,
            targetType: ClinicalDocument.self
        )
        XCTAssertNotNil(ormToCda, "Should create ORM to CDA transformer")
        
        // Test v3 to v2 factory
        let cdaToAdt = TransformerFactory.v3ToV2(
            sourceType: ClinicalDocument.self,
            targetType: ADTMessage.self
        )
        XCTAssertNotNil(cdaToAdt, "Should create CDA to ADT transformer")
        
        let cdaToOru = TransformerFactory.v3ToV2(
            sourceType: ClinicalDocument.self,
            targetType: ORUMessage.self
        )
        XCTAssertNotNil(cdaToOru, "Should create CDA to ORU transformer")
    }
}

#endif // canImport(HL7v2Kit)
