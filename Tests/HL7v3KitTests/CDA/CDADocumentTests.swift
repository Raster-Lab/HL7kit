/// CDADocumentTests.swift
/// Unit tests for CDA document structures

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class CDADocumentTests: XCTestCase {
    
    // MARK: - Test Helper Methods
    
    func createTestPatient() -> Patient {
        let givenName = EN.NamePart(value: "John", type: .given)
        let familyName = EN.NamePart(value: "Doe", type: .family)
        let name = EN(parts: [givenName, familyName])
        
        let birthDate = DateComponents(calendar: .current, year: 1980, month: 1, day: 15).date!
        
        return Patient(
            name: [name],
            administrativeGenderCode: CD(code: "M", codeSystem: "2.16.840.1.113883.5.1", displayName: "Male"),
            birthTime: TS(value: birthDate, precision: .day),
            raceCode: CD(code: "2106-3", codeSystem: "2.16.840.1.113883.6.238", displayName: "White")
        )
    }
    
    func createTestRecordTarget() -> RecordTarget {
        let patient = createTestPatient()
        let patientRole = PatientRole(
            id: [II(root: "2.16.840.1.113883.19.5", extension: "12345")],
            patient: patient
        )
        return RecordTarget(patientRole: patientRole)
    }
    
    func createTestAuthor() -> Author {
        let givenName = EN.NamePart(value: "Jane", type: .given)
        let familyName = EN.NamePart(value: "Smith", type: .family)
        let prefix = EN.NamePart(value: "Dr.", type: .prefix)
        let name = EN(parts: [prefix, givenName, familyName])
        
        let assignedAuthor = AssignedAuthor(
            id: [II(root: "2.16.840.1.113883.4.6", extension: "1234567890")],
            assignedPerson: Person(name: [name])
        )
        
        let authorTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8, hour: 12, minute: 0, second: 0).date!
        
        return Author(
            time: TS(value: authorTime, precision: .second),
            assignedAuthor: assignedAuthor
        )
    }
    
    func createTestCustodian() -> Custodian {
        let orgName = EN.NamePart(value: "Community Health Hospital", type: .family)
        let name = EN(parts: [orgName])
        
        let organization = CustodianOrganization(
            id: [II(root: "2.16.840.1.113883.4.6")],
            name: name
        )
        let assignedCustodian = AssignedCustodian(
            representedCustodianOrganization: organization
        )
        return Custodian(assignedCustodian: assignedCustodian)
    }
    
    func createSimpleStructuredBody() -> StructuredBody {
        let narrative = Narrative.paragraph("Patient presents with chest pain and shortness of breath.")
        
        let section = Section(
            code: .chiefComplaintSection(),
            title: ST.value("Chief Complaint"),
            text: narrative
        )
        
        let component = BodyComponent(section: section)
        
        return StructuredBody(component: [component])
    }
    
    func createTestDocument() -> ClinicalDocument {
        let docTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8, hour: 12, minute: 0, second: 0).date!
        
        return ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [.usRealmHeader, .progressNoteTemplate],
            id: II(root: "2.16.840.1.113883.19.5", extension: "doc123"),
            code: .progressNote(),
            title: ST.value("Progress Note"),
            effectiveTime: TS(value: docTime, precision: .second),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25", displayName: "Normal"),
            languageCode: CD(code: "en-US"),
            recordTarget: [createTestRecordTarget()],
            author: [createTestAuthor()],
            custodian: createTestCustodian(),
            component: DocumentComponent(
                body: .structured(createSimpleStructuredBody())
            )
        )
    }
    
    // MARK: - Tests
    
    func testClinicalDocumentCreation() {
        let document = createTestDocument()
        
        // Verify basic properties
        XCTAssertEqual(document.classCode, .document)
        XCTAssertEqual(document.moodCode, .event)
        XCTAssertEqual(document.typeId.root, "2.16.840.1.113883.1.3")
        XCTAssertEqual(document.templateId.count, 2)
        XCTAssertEqual(document.id.extension, "doc123")
        XCTAssertEqual(document.code.code, "11506-3") // Progress Note
    }
    
    func testDocumentHeader() {
        let document = createTestDocument()
        
        // Verify record target
        XCTAssertEqual(document.recordTarget.count, 1)
        XCTAssertEqual(document.recordTarget[0].patientRole.id.count, 1)
        XCTAssertEqual(document.recordTarget[0].patientRole.patient?.name?.first?.parts.first(where: { $0.type == .given })?.value, "John")
        
        // Verify author
        XCTAssertEqual(document.author.count, 1)
        XCTAssertEqual(document.author[0].assignedAuthor.id.count, 1)
        
        // Verify custodian
        XCTAssertEqual(document.custodian.assignedCustodian.representedCustodianOrganization.name?.parts.first?.value, "Community Health Hospital")
    }
    
    func testStructuredBody() {
        let document = createTestDocument()
        
        guard case .structured(let body) = document.component.body else {
            XCTFail("Expected structured body")
            return
        }
        
        XCTAssertEqual(body.component.count, 1)
        
        let section = body.component[0].section
        XCTAssertEqual(section.code?.code, "10154-3") // Chief Complaint
        XCTAssertEqual(section.title?.stringValue, "Chief Complaint")
        XCTAssertNotNil(section.text)
    }
    
    func testNonXMLBody() {
        let pdfData = Data("Sample PDF content".utf8)
        let ed = ED(mediaType: "application/pdf", data: pdfData)
        let nonXMLBody = NonXMLBody(text: ed)
        
        let docTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8).date!
        
        let document = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [.usRealmHeader],
            id: II(root: "2.16.840.1.113883.19.5", extension: "doc456"),
            code: .dischargeSummary(),
            effectiveTime: TS(value: docTime, precision: .day),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25"),
            recordTarget: [createTestRecordTarget()],
            author: [createTestAuthor()],
            custodian: createTestCustodian(),
            component: DocumentComponent(body: .nonXML(nonXMLBody))
        )
        
        guard case .nonXML(let body) = document.component.body else {
            XCTFail("Expected non-XML body")
            return
        }
        
        XCTAssertEqual(body.text.mediaType, "application/pdf")
        XCTAssertNotNil(body.text.data)
    }
    
    func testDocumentTypeCodes() {
        let progressNote = CD.progressNote()
        XCTAssertEqual(progressNote.code, "11506-3")
        XCTAssertEqual(progressNote.codeSystem, "2.16.840.1.113883.6.1")
        
        let dischargeSummary = CD.dischargeSummary()
        XCTAssertEqual(dischargeSummary.code, "18842-5")
        
        let historyAndPhysical = CD.historyAndPhysical()
        XCTAssertEqual(historyAndPhysical.code, "34117-2")
        
        let consultationNote = CD.consultationNote()
        XCTAssertEqual(consultationNote.code, "11488-4")
        
        let operativeNote = CD.operativeNote()
        XCTAssertEqual(operativeNote.code, "11504-8")
    }
    
    func testPatientDetails() {
        let patient = createTestPatient()
        
        XCTAssertEqual(patient.name?.first?.parts.first(where: { $0.type == .given })?.value, "John")
        XCTAssertEqual(patient.name?.first?.parts.first(where: { $0.type == .family })?.value, "Doe")
        XCTAssertEqual(patient.administrativeGenderCode?.code, "M")
        XCTAssertNotNil(patient.birthTime?.value)
        XCTAssertEqual(patient.raceCode?.code, "2106-3")
    }
    
    func testAuthorTypes() {
        // Test person author
        let personAuthor = createTestAuthor()
        XCTAssertNotNil(personAuthor.assignedAuthor.assignedPerson)
        XCTAssertNil(personAuthor.assignedAuthor.assignedAuthoringDevice)
        
        // Test device author
        let device = AuthoringDevice(
            manufacturerModelName: ST.value("EMR System"),
            softwareName: ST.value("HealthTrack v2.0")
        )
        
        let authorTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8, hour: 12, minute: 0, second: 0).date!
        
        let deviceAuthor = Author(
            time: TS(value: authorTime, precision: .second),
            assignedAuthor: AssignedAuthor(
                id: [II(root: "2.16.840.1.113883.19.5", extension: "system1")],
                assignedAuthoringDevice: device
            )
        )
        
        XCTAssertNil(deviceAuthor.assignedAuthor.assignedPerson)
        XCTAssertNotNil(deviceAuthor.assignedAuthor.assignedAuthoringDevice)
        XCTAssertEqual(deviceAuthor.assignedAuthor.assignedAuthoringDevice?.softwareName?.stringValue, "HealthTrack v2.0")
    }
    
    func testMultipleRecordTargets() {
        let givenName1 = EN.NamePart(value: "John", type: .given)
        let familyName1 = EN.NamePart(value: "Doe", type: .family)
        let name1 = EN(parts: [givenName1, familyName1])
        
        let patient1 = Patient(
            name: [name1],
            administrativeGenderCode: CD(code: "M", codeSystem: "2.16.840.1.113883.5.1")
        )
        let recordTarget1 = RecordTarget(
            patientRole: PatientRole(id: [II(root: "1.2.3", extension: "123")], patient: patient1)
        )
        
        let givenName2 = EN.NamePart(value: "Jane", type: .given)
        let familyName2 = EN.NamePart(value: "Doe", type: .family)
        let name2 = EN(parts: [givenName2, familyName2])
        
        let patient2 = Patient(
            name: [name2],
            administrativeGenderCode: CD(code: "F", codeSystem: "2.16.840.1.113883.5.1")
        )
        let recordTarget2 = RecordTarget(
            patientRole: PatientRole(id: [II(root: "1.2.3", extension: "456")], patient: patient2)
        )
        
        let docTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8).date!
        
        let document = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [.usRealmHeader],
            id: II(root: "1.2.3", extension: "doc789"),
            code: .progressNote(),
            effectiveTime: TS(value: docTime, precision: .day),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25"),
            recordTarget: [recordTarget1, recordTarget2],
            author: [createTestAuthor()],
            custodian: createTestCustodian(),
            component: DocumentComponent(body: .structured(createSimpleStructuredBody()))
        )
        
        XCTAssertEqual(document.recordTarget.count, 2)
        XCTAssertEqual(document.recordTarget[0].patientRole.patient?.name?.first?.parts.first(where: { $0.type == .given })?.value, "John")
        XCTAssertEqual(document.recordTarget[1].patientRole.patient?.name?.first?.parts.first(where: { $0.type == .given })?.value, "Jane")
    }
    
    func testLegalAuthenticator() {
        let givenName = EN.NamePart(value: "Sarah", type: .given)
        let familyName = EN.NamePart(value: "Johnson", type: .family)
        let prefix = EN.NamePart(value: "Dr.", type: .prefix)
        let name = EN(parts: [prefix, givenName, familyName])
        
        let assignedEntity = AssignedEntity(
            id: [II(root: "2.16.840.1.113883.4.6", extension: "9876543210")],
            assignedPerson: Person(name: [name])
        )
        
        let authTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8, hour: 13, minute: 0, second: 0).date!
        
        let legalAuthenticator = LegalAuthenticator(
            signatureCode: CD(code: "S", codeSystem: "2.16.840.1.113883.5.89", displayName: "Signed"),
            time: TS(value: authTime, precision: .second),
            assignedEntity: assignedEntity
        )
        
        let docTime = DateComponents(calendar: .current, year: 2024, month: 2, day: 8).date!
        
        let document = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [.usRealmHeader],
            id: II(root: "1.2.3", extension: "doc999"),
            code: .dischargeSummary(),
            effectiveTime: TS(value: docTime, precision: .day),
            confidentialityCode: CD(code: "N", codeSystem: "2.16.840.1.113883.5.25"),
            recordTarget: [createTestRecordTarget()],
            author: [createTestAuthor()],
            custodian: createTestCustodian(),
            legalAuthenticator: legalAuthenticator,
            component: DocumentComponent(body: .structured(createSimpleStructuredBody()))
        )
        
        XCTAssertNotNil(document.legalAuthenticator)
        XCTAssertEqual(document.legalAuthenticator?.signatureCode.code, "S")
        XCTAssertEqual(document.legalAuthenticator?.assignedEntity.assignedPerson?.name?.first?.parts.first(where: { $0.type == .given })?.value, "Sarah")
    }
    
    func testCodableConformance() throws {
        let document = createTestDocument()
        
        // Test encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(document)
        XCTAssertFalse(jsonData.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedDocument = try decoder.decode(ClinicalDocument.self, from: jsonData)
        
        XCTAssertEqual(decodedDocument.id.extension, document.id.extension)
        XCTAssertEqual(decodedDocument.code.code, document.code.code)
        XCTAssertEqual(decodedDocument.recordTarget.count, document.recordTarget.count)
    }
}
