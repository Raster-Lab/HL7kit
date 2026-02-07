import Testing
@testable import HL7v3

@Suite("RIM Act Tests")
struct ActTests {
    @Test("Default act values")
    func defaultValues() {
        let act = Act()
        #expect(act.classCode == "ACT")
        #expect(act.moodCode == "EVN")
        #expect(act.id == nil)
    }

    @Test("Act with all properties")
    func fullAct() {
        let act = Act(
            id: InstanceIdentifier(root: "2.16.840.1.113883.1.3"),
            classCode: "OBS",
            moodCode: "EVN",
            code: CodedValue(code: "1234", codeSystem: "2.16.840.1.113883.6.1"),
            statusCode: "completed",
            effectiveTime: "20240101",
            text: "Sample observation"
        )
        #expect(act.classCode == "OBS")
        #expect(act.statusCode == "completed")
    }
}

@Suite("RIM Entity Tests")
struct EntityTests {
    @Test("Default entity values")
    func defaultValues() {
        let entity = Entity()
        #expect(entity.classCode == "ENT")
        #expect(entity.determinerCode == "INSTANCE")
    }

    @Test("Person entity")
    func personEntity() {
        let person = Entity(classCode: "PSN", name: "John Doe")
        #expect(person.classCode == "PSN")
        #expect(person.name == "John Doe")
    }
}

@Suite("RIM Role Tests")
struct RoleTests {
    @Test("Patient role")
    func patientRole() {
        let patient = Role(
            classCode: "PAT",
            player: Entity(classCode: "PSN", name: "Jane Smith")
        )
        #expect(patient.classCode == "PAT")
        #expect(patient.player?.name == "Jane Smith")
    }
}

@Suite("V3 Data Type Tests")
struct V3DataTypeTests {
    @Test("Instance identifier")
    func instanceIdentifier() {
        let id = InstanceIdentifier(root: "2.16.840.1.113883.1.3", extension: "12345")
        #expect(id.root == "2.16.840.1.113883.1.3")
        #expect(id.extension == "12345")
    }

    @Test("Coded value")
    func codedValue() {
        let cv = CodedValue(
            code: "55561003",
            codeSystem: "2.16.840.1.113883.6.96",
            codeSystemName: "SNOMED CT",
            displayName: "Active"
        )
        #expect(cv.code == "55561003")
        #expect(cv.displayName == "Active")
    }

    @Test("Null flavor values")
    func nullFlavors() {
        #expect(NullFlavor.unknown.rawValue == "UNK")
        #expect(NullFlavor.noInformation.rawValue == "NI")
        #expect(NullFlavor.masked.rawValue == "MSK")
    }
}

@Suite("CDA Document Tests")
struct CDADocumentTests {
    @Test("Empty CDA document")
    func emptyDocument() {
        let doc = CDADocument()
        #expect(doc.sections.isEmpty)
        #expect(doc.title == nil)
    }

    @Test("CDA document with sections")
    func documentWithSections() {
        let doc = CDADocument(
            title: "Discharge Summary",
            sections: [
                CDASection(title: "History of Present Illness", text: "Patient presented with..."),
                CDASection(title: "Medications", text: "Aspirin 81mg daily"),
            ]
        )
        #expect(doc.title == "Discharge Summary")
        #expect(doc.sections.count == 2)
        #expect(doc.sections[0].title == "History of Present Illness")
    }
}
