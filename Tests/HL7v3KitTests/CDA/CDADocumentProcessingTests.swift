/// CDADocumentProcessingTests.swift
/// Unit tests for CDA Document Processing (rendering, comparison, merging, versioning)

import XCTest
@testable import HL7v3Kit
@testable import HL7Core

final class CDADocumentProcessingTests: XCTestCase {

    // MARK: - Test Helpers

    private func makePatient(given: String = "John", family: String = "Doe") -> Patient {
        Patient(
            name: [EN(parts: [
                EN.NamePart(value: given, type: .given),
                EN.NamePart(value: family, type: .family)
            ])],
            administrativeGenderCode: CD(code: "M", displayName: "Male"),
            birthTime: TS(value: Date(timeIntervalSince1970: 315532800), precision: .day)
        )
    }

    private func makeRecordTarget(given: String = "John", family: String = "Doe") -> RecordTarget {
        RecordTarget(patientRole: PatientRole(
            id: [II(root: "2.16.840.1.113883.19.5", extension: "12345")],
            patient: makePatient(given: given, family: family)
        ))
    }

    private func makeAuthor(given: String = "Jane", family: String = "Smith") -> Author {
        Author(
            time: TS(value: Date(timeIntervalSince1970: 1707350400), precision: .second),
            assignedAuthor: AssignedAuthor(
                id: [II(root: "2.16.840.1.113883.4.6", extension: "NPI123")],
                assignedPerson: Person(name: [EN(parts: [
                    EN.NamePart(value: "Dr.", type: .prefix),
                    EN.NamePart(value: given, type: .given),
                    EN.NamePart(value: family, type: .family)
                ])])
            )
        )
    }

    private func makeCustodian(name: String = "Community Hospital") -> Custodian {
        Custodian(assignedCustodian: AssignedCustodian(
            representedCustodianOrganization: CustodianOrganization(
                id: [II(root: "2.16.840.1.113883.4.6")],
                name: EN(parts: [EN.NamePart(value: name, type: .family)])
            )
        ))
    }

    private func makeSection(
        code: CD? = .chiefComplaintSection(),
        title: String = "Chief Complaint",
        text: String = "Patient complains of headache.",
        entries: [Entry]? = nil
    ) -> Section {
        Section(
            code: code,
            title: .value(title),
            text: Narrative.paragraph(text),
            entry: entries
        )
    }

    private func makeObservationEntry(
        code: CD = CD(code: "8867-4", displayName: "Heart Rate"),
        value: ObservationValue = .physicalQuantity(PQ(value: 72, unit: "bpm"))
    ) -> Entry {
        Entry(
            typeCode: .driv,
            clinicalStatement: .observation(ClinicalObservation(
                code: code,
                value: [value]
            ))
        )
    }

    private func makeDocument(
        id: II = II(root: "1.2.3.4", extension: "DOC001"),
        title: String = "Progress Note",
        sections: [Section]? = nil,
        setId: II? = nil,
        versionNumber: INT? = nil,
        relatedDocument: [RelatedDocument]? = nil
    ) -> ClinicalDocument {
        let secs = sections ?? [makeSection()]
        let components = secs.map { BodyComponent(section: $0) }
        let body = StructuredBody(component: components)

        return ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [II(root: "2.16.840.1.113883.10.20.22.1.1")],
            id: id,
            code: .progressNote(),
            title: .value(title),
            effectiveTime: TS(value: Date(timeIntervalSince1970: 1707350400), precision: .second),
            confidentialityCode: CD(code: "N", displayName: "Normal"),
            languageCode: CD(code: "en-US"),
            setId: setId,
            versionNumber: versionNumber,
            recordTarget: [makeRecordTarget()],
            author: [makeAuthor()],
            custodian: makeCustodian(),
            relatedDocument: relatedDocument,
            component: DocumentComponent(body: .structured(body))
        )
    }

    // MARK: - CDARenderingConfiguration Tests

    func testDefaultConfiguration() {
        let config = CDARenderingConfiguration.default
        XCTAssertTrue(config.includeHeader)
        XCTAssertTrue(config.includeSectionTitles)
        XCTAssertTrue(config.renderEntries)
        XCTAssertEqual(config.maxLineWidth, 80)
        XCTAssertEqual(config.indentation, "  ")
    }

    func testCustomConfiguration() {
        let config = CDARenderingConfiguration(
            includeHeader: false,
            includeSectionTitles: false,
            renderEntries: false,
            maxLineWidth: 120,
            indentation: "    "
        )
        XCTAssertFalse(config.includeHeader)
        XCTAssertFalse(config.includeSectionTitles)
        XCTAssertFalse(config.renderEntries)
        XCTAssertEqual(config.maxLineWidth, 120)
        XCTAssertEqual(config.indentation, "    ")
    }

    // MARK: - Text Rendering Tests

    func testRenderToTextIncludesHeader() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Progress Note"))
        XCTAssertTrue(text.contains("Document ID:"))
        XCTAssertTrue(text.contains("1.2.3.4"))
        XCTAssertTrue(text.contains("John Doe"))
    }

    func testRenderToTextIncludesPatientName() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Patient: John Doe"))
    }

    func testRenderToTextIncludesAuthor() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Author: Dr. Jane Smith"))
    }

    func testRenderToTextIncludesCustodian() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Custodian: Community Hospital"))
    }

    func testRenderToTextIncludesSectionTitle() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Chief Complaint"))
    }

    func testRenderToTextIncludesNarrative() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Patient complains of headache."))
    }

    func testRenderToTextNoHeader() {
        let config = CDARenderingConfiguration(includeHeader: false)
        let doc = makeDocument()
        let text = doc.renderToText(configuration: config)
        XCTAssertFalse(text.contains("Document ID:"))
        XCTAssertTrue(text.contains("Chief Complaint"))
    }

    func testRenderToTextNoSectionTitles() {
        let config = CDARenderingConfiguration(includeSectionTitles: false)
        let doc = makeDocument()
        let text = doc.renderToText(configuration: config)
        XCTAssertFalse(text.contains("Chief Complaint"))
        XCTAssertTrue(text.contains("Patient complains of headache."))
    }

    func testRenderToTextWithEntries() {
        let entry = makeObservationEntry()
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Observation: Heart Rate"))
        XCTAssertTrue(text.contains("72.0 bpm"))
    }

    func testRenderToTextNoEntries() {
        let config = CDARenderingConfiguration(renderEntries: false)
        let entry = makeObservationEntry()
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText(configuration: config)
        XCTAssertFalse(text.contains("Observation: Heart Rate"))
    }

    func testRenderToTextProcedureEntry() {
        let entry = Entry(typeCode: .driv, clinicalStatement: .procedure(Procedure(
            code: CD(code: "99213", displayName: "Office Visit"),
            statusCode: .completed
        )))
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Procedure: Office Visit"))
        XCTAssertTrue(text.contains("completed"))
    }

    func testRenderToTextMedicationEntry() {
        let material = ManufacturedMaterial(
            code: CD(code: "197361", displayName: "Aspirin"),
            name: EN(parts: [EN.NamePart(value: "Aspirin 81mg", type: .family)])
        )
        let entry = Entry(typeCode: .driv, clinicalStatement: .substanceAdministration(
            SubstanceAdministration(
                routeCode: CD(code: "PO", displayName: "Oral"),
                doseQuantity: IVL<PQ>(low: PQ(value: 81, unit: "mg")),
                consumable: Consumable(manufacturedProduct: ManufacturedProduct(manufacturedMaterial: material))
            )
        ))
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Medication: Aspirin 81mg"))
        XCTAssertTrue(text.contains("Route: Oral"))
    }

    func testRenderToTextOrganizerEntry() {
        let obs1 = ClinicalObservation(code: CD(code: "8480-6", displayName: "Systolic BP"), value: [.physicalQuantity(PQ(value: 120, unit: "mmHg"))])
        let obs2 = ClinicalObservation(code: CD(code: "8462-4", displayName: "Diastolic BP"), value: [.physicalQuantity(PQ(value: 80, unit: "mmHg"))])
        let organizer = Organizer(
            code: CD(code: "35094-2", displayName: "Blood pressure"),
            component: [
                OrganizerComponent(clinicalStatement: .observation(obs1)),
                OrganizerComponent(clinicalStatement: .observation(obs2))
            ]
        )
        let entry = Entry(typeCode: .driv, clinicalStatement: .organizer(organizer))
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Blood pressure"))
        XCTAssertTrue(text.contains("Systolic BP"))
        XCTAssertTrue(text.contains("Diastolic BP"))
    }

    func testRenderToTextWithNonXMLBody() {
        let nonXML = NonXMLBody(text: ED(mediaType: "application/pdf", reference: .value("report.pdf")))
        let doc = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [],
            id: II(root: "1.2.3"),
            code: .progressNote(),
            effectiveTime: TS(value: Date(), precision: .day),
            confidentialityCode: CD(code: "N"),
            recordTarget: [makeRecordTarget()],
            author: [makeAuthor()],
            custodian: makeCustodian(),
            component: DocumentComponent(body: .nonXML(nonXML))
        )
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("[Non-XML Body (application/pdf)]"))
        XCTAssertTrue(text.contains("Reference: report.pdf"))
    }

    // MARK: - HTML Rendering Tests

    func testRenderToHTMLStructure() {
        let doc = makeDocument()
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<html>"))
        XCTAssertTrue(html.contains("</html>"))
        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("cda-document"))
    }

    func testRenderToHTMLIncludesHeader() {
        let doc = makeDocument()
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("cda-header"))
        XCTAssertTrue(html.contains("Progress Note"))
    }

    func testRenderToHTMLSectionTitles() {
        let doc = makeDocument()
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("<h2>Chief Complaint</h2>"))
    }

    func testRenderToHTMLEscapesSpecialCharacters() {
        let renderer = CDADocumentRenderer()
        XCTAssertEqual(renderer.escapeHTML("<script>"), "&lt;script&gt;")
        XCTAssertEqual(renderer.escapeHTML("A & B"), "A &amp; B")
        XCTAssertEqual(renderer.escapeHTML("\"quoted\""), "&quot;quoted&quot;")
    }

    func testRenderToHTMLWithEntries() {
        let entry = makeObservationEntry()
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("cda-entry"))
        XCTAssertTrue(html.contains("Heart Rate"))
    }

    func testRenderToHTMLNonXMLBody() {
        let nonXML = NonXMLBody(text: ED(mediaType: "text/plain"))
        let doc = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [],
            id: II(root: "1.2.3"),
            code: .progressNote(),
            effectiveTime: TS(value: Date(), precision: .day),
            confidentialityCode: CD(code: "N"),
            recordTarget: [makeRecordTarget()],
            author: [makeAuthor()],
            custodian: makeCustodian(),
            component: DocumentComponent(body: .nonXML(nonXML))
        )
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("non-xml"))
        XCTAssertTrue(html.contains("text/plain"))
    }

    // MARK: - Narrative Rendering Tests

    func testNarrativeTextRendering() {
        let narrative = Narrative(content: [.text("Simple text")])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Simple text"))
    }

    func testNarrativeParagraphRendering() {
        let para = NarrativeParagraph(content: [.text("Paragraph content")])
        let narrative = Narrative(content: [.paragraph(para)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Paragraph content"))
    }

    func testNarrativeListRendering() {
        let list = NarrativeList(
            listType: .unordered,
            item: [
                NarrativeListItem(content: [.text("Item 1")]),
                NarrativeListItem(content: [.text("Item 2")])
            ]
        )
        let narrative = Narrative(content: [.list(list)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("\u{2022} Item 1"))
        XCTAssertTrue(text.contains("\u{2022} Item 2"))
    }

    func testNarrativeOrderedListRendering() {
        let list = NarrativeList(
            listType: .ordered,
            item: [
                NarrativeListItem(content: [.text("First")]),
                NarrativeListItem(content: [.text("Second")])
            ]
        )
        let narrative = Narrative(content: [.list(list)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("1. First"))
        XCTAssertTrue(text.contains("2. Second"))
    }

    func testNarrativeTableRendering() {
        let table = NarrativeTable(
            thead: NarrativeTableHead(tr: [
                NarrativeTableRow(th: [
                    NarrativeTableCell(content: [.text("Name")]),
                    NarrativeTableCell(content: [.text("Value")])
                ])
            ]),
            tbody: NarrativeTableBody(tr: [
                NarrativeTableRow(td: [
                    NarrativeTableCell(content: [.text("HR")]),
                    NarrativeTableCell(content: [.text("72")])
                ])
            ])
        )
        let narrative = Narrative(content: [.table(table)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Name"))
        XCTAssertTrue(text.contains("Value"))
        XCTAssertTrue(text.contains("HR"))
        XCTAssertTrue(text.contains("72"))
    }

    func testNarrativeTableHTMLRendering() {
        let table = NarrativeTable(
            thead: NarrativeTableHead(tr: [
                NarrativeTableRow(th: [
                    NarrativeTableCell(content: [.text("Name")])
                ])
            ]),
            tbody: NarrativeTableBody(tr: [
                NarrativeTableRow(td: [
                    NarrativeTableCell(content: [.text("HR")])
                ])
            ])
        )
        let narrative = Narrative(content: [.table(table)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<thead>"))
        XCTAssertTrue(html.contains("<tbody>"))
        XCTAssertTrue(html.contains("<th>Name</th>"))
    }

    func testNarrativeListHTMLRendering() {
        let list = NarrativeList(
            listType: .unordered,
            item: [NarrativeListItem(content: [.text("Item")])]
        )
        let narrative = Narrative(content: [.list(list)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>Item</li>"))
    }

    func testNarrativeBrRendering() {
        let narrative = Narrative(content: [.text("Line 1"), .br, .text("Line 2")])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Line 1"))
        XCTAssertTrue(text.contains("Line 2"))
    }

    func testNarrativeContentWrapping() {
        let content = NarrativeContent(content: [.text("Wrapped content")], ID: "c1", styleCode: "Bold")
        let narrative = Narrative(content: [.content(content)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("id=\"c1\""))
        XCTAssertTrue(html.contains("class=\"Bold\""))
        XCTAssertTrue(html.contains("Wrapped content"))
    }

    func testNarrativeLinkHTMLRendering() {
        let link = NarrativeLinkHtml(content: [.text("Click here")], href: "http://example.com")
        let narrative = Narrative(content: [.linkHtml(link)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("<a href=\"http://example.com\">Click here</a>"))
    }

    func testNarrativeMultiMediaRendering() {
        let media = NarrativeRenderMultiMedia(
            referencedObject: "img001",
            caption: NarrativeCaption(content: [.text("X-Ray Image")])
        )
        let narrative = Narrative(content: [.renderMultiMedia(media)])
        let section = Section(title: .value("Test"), text: narrative)
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("[Media: img001]"))
        XCTAssertTrue(text.contains("X-Ray Image"))
    }

    // MARK: - Formatting Helper Tests

    func testFormatIdentifier() {
        let renderer = CDADocumentRenderer()
        let id1 = II(root: "1.2.3.4", extension: "ABC")
        XCTAssertEqual(renderer.formatIdentifier(id1), "1.2.3.4^ABC")

        let id2 = II(root: "1.2.3.4")
        XCTAssertEqual(renderer.formatIdentifier(id2), "1.2.3.4")
    }

    func testFormatEntityName() {
        let renderer = CDADocumentRenderer()
        let name = EN(parts: [
            EN.NamePart(value: "Dr.", type: .prefix),
            EN.NamePart(value: "John", type: .given),
            EN.NamePart(value: "Doe", type: .family),
            EN.NamePart(value: "Jr.", type: .suffix)
        ])
        XCTAssertEqual(renderer.formatEntityName(name), "Dr. John Doe Jr.")
    }

    func testFormatEntityNameEmpty() {
        let renderer = CDADocumentRenderer()
        let name = EN(parts: [])
        XCTAssertEqual(renderer.formatEntityName(name), "Unknown")
    }

    func testFormatObservationValues() {
        let renderer = CDADocumentRenderer()

        XCTAssertEqual(renderer.formatObservationValue(.physicalQuantity(PQ(value: 120, unit: "mmHg"))), "120.0 mmHg")
        XCTAssertEqual(renderer.formatObservationValue(.codedValue(CD(displayName: "Normal"))), "Normal")
        XCTAssertEqual(renderer.formatObservationValue(.stringValue(.value("test"))), "test")
        XCTAssertEqual(renderer.formatObservationValue(.integerValue(.value(42))), "42")
        XCTAssertEqual(renderer.formatObservationValue(.realValue(.value(3.14))), "3.14")
        XCTAssertEqual(renderer.formatObservationValue(.booleanValue(.value(true))), "true")
        XCTAssertEqual(renderer.formatObservationValue(.booleanValue(.value(false))), "false")
    }

    func testFormatObservationValueNullFlavors() {
        let renderer = CDADocumentRenderer()
        XCTAssertEqual(renderer.formatObservationValue(.stringValue(.nullFlavor(.unknown))), "N/A")
        XCTAssertEqual(renderer.formatObservationValue(.integerValue(.nullFlavor(.unknown))), "N/A")
        XCTAssertEqual(renderer.formatObservationValue(.realValue(.nullFlavor(.unknown))), "N/A")
        XCTAssertEqual(renderer.formatObservationValue(.booleanValue(.nullFlavor(.unknown))), "N/A")
    }

    func testFormatQuantityInterval() {
        let renderer = CDADocumentRenderer()

        let ivl1 = IVL<PQ>(low: PQ(value: 60, unit: "bpm"), high: PQ(value: 100, unit: "bpm"))
        XCTAssertEqual(renderer.formatQuantityInterval(ivl1), "60.0 bpm - 100.0 bpm")

        let ivl2 = IVL<PQ>(low: PQ(value: 81, unit: "mg"))
        XCTAssertEqual(renderer.formatQuantityInterval(ivl2), "81.0 mg")

        let ivl3 = IVL<PQ>()
        XCTAssertEqual(renderer.formatQuantityInterval(ivl3), "N/A")
    }

    func testFormatPatientNameMissing() {
        let renderer = CDADocumentRenderer()
        let rt = RecordTarget(patientRole: PatientRole(id: [II(root: "1.2.3")]))
        XCTAssertEqual(renderer.formatPatientName(rt), "Unknown Patient")
    }

    func testFormatAuthorNameMissing() {
        let renderer = CDADocumentRenderer()
        let author = Author(
            time: TS(value: Date(), precision: .day),
            assignedAuthor: AssignedAuthor(id: [II(root: "1.2.3")])
        )
        XCTAssertEqual(renderer.formatAuthorName(author), "Unknown Author")
    }

    // MARK: - Comparator Tests

    func testCompareIdenticalDocuments() {
        let doc = makeDocument()
        let result = doc.compare(with: doc)
        XCTAssertTrue(result.areIdentical)
        XCTAssertTrue(result.differences.isEmpty)
    }

    func testCompareHeaderDifferences() {
        let doc1 = makeDocument(title: "Note A")
        let doc2 = makeDocument(title: "Note B")
        let result = doc1.compare(with: doc2)
        XCTAssertFalse(result.areIdentical)
        XCTAssertFalse(result.headerDifferences.isEmpty)
        XCTAssertTrue(result.headerDifferences.contains { $0.path == "header.title" })
    }

    func testCompareBodyDifferences() {
        let section1 = makeSection(title: "Section A")
        let section2 = makeSection(title: "Section B")
        let doc1 = makeDocument(sections: [section1])
        let doc2 = makeDocument(sections: [section2])
        let result = doc1.compare(with: doc2)
        XCTAssertFalse(result.bodyDifferences.isEmpty)
    }

    func testCompareSectionAdded() {
        let section1 = makeSection(title: "Section A")
        let section2 = makeSection(title: "Section B")
        let doc1 = makeDocument(sections: [section1])
        let doc2 = makeDocument(sections: [section1, section2])
        let result = doc1.compare(with: doc2)
        let added = result.differences(ofType: .added)
        XCTAssertFalse(added.isEmpty)
    }

    func testCompareSectionRemoved() {
        let section1 = makeSection(title: "Section A")
        let section2 = makeSection(title: "Section B")
        let doc1 = makeDocument(sections: [section1, section2])
        let doc2 = makeDocument(sections: [section1])
        let result = doc1.compare(with: doc2)
        let removed = result.differences(ofType: .removed)
        XCTAssertFalse(removed.isEmpty)
    }

    func testCompareBodyTypeChange() {
        let structuredDoc = makeDocument()
        let nonXMLDoc = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [],
            id: II(root: "1.2.3.4", extension: "DOC001"),
            code: .progressNote(),
            title: .value("Progress Note"),
            effectiveTime: TS(value: Date(timeIntervalSince1970: 1707350400), precision: .second),
            confidentialityCode: CD(code: "N", displayName: "Normal"),
            languageCode: CD(code: "en-US"),
            recordTarget: [makeRecordTarget()],
            author: [makeAuthor()],
            custodian: makeCustodian(),
            component: DocumentComponent(body: .nonXML(NonXMLBody(text: ED(mediaType: "text/plain"))))
        )
        let result = structuredDoc.compare(with: nonXMLDoc)
        XCTAssertFalse(result.areIdentical)
        XCTAssertTrue(result.bodyDifferences.contains { $0.path == "body" })
    }

    func testComparisonResultFilterByType() {
        let doc1 = makeDocument(title: "A")
        let doc2 = makeDocument(title: "B")
        let result = doc1.compare(with: doc2)
        let modified = result.differences(ofType: .modified)
        XCTAssertFalse(modified.isEmpty)
        let added = result.differences(ofType: .added)
        XCTAssertTrue(added.isEmpty)
    }

    // MARK: - Merger Tests

    func testMergeSectionsKeepPrimary() {
        let section1 = makeSection(code: .chiefComplaintSection(), title: "Chief Complaint", text: "Primary complaint")
        let section2 = makeSection(code: .medicationsSection(), title: "Medications", text: "Aspirin")
        let primary = makeDocument(sections: [section1])
        let secondary = makeDocument(sections: [section2])

        let config = CDAMergeConfiguration(conflictStrategy: .keepPrimary)
        let merger = CDADocumentMerger(configuration: config)
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        // keepPrimary should not add sections only in secondary
        if case .structured(let body) = merged.component.body {
            XCTAssertEqual(body.component.count, 1)
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testMergeSectionsIncludeBoth() {
        let section1 = makeSection(code: .chiefComplaintSection(), title: "Chief Complaint", text: "Primary complaint")
        let section2 = makeSection(code: .medicationsSection(), title: "Medications", text: "Aspirin")
        let primary = makeDocument(sections: [section1])
        let secondary = makeDocument(sections: [section2])

        let config = CDAMergeConfiguration(conflictStrategy: .includeBoth)
        let merger = CDADocumentMerger(configuration: config)
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        if case .structured(let body) = merged.component.body {
            XCTAssertEqual(body.component.count, 2)
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testMergeSectionsWithMatchingSections() {
        let entry1 = makeObservationEntry(code: CD(code: "HR", displayName: "Heart Rate"), value: .physicalQuantity(PQ(value: 72, unit: "bpm")))
        let entry2 = makeObservationEntry(code: CD(code: "BP", displayName: "Blood Pressure"), value: .physicalQuantity(PQ(value: 120, unit: "mmHg")))

        let section1 = makeSection(code: .vitalSignsSection(), title: "Vital Signs", entries: [entry1])
        let section2 = makeSection(code: .vitalSignsSection(), title: "Vital Signs", entries: [entry2])

        let primary = makeDocument(sections: [section1])
        let secondary = makeDocument(sections: [section2])

        let config = CDAMergeConfiguration(conflictStrategy: .keepPrimary, mergeEntries: true)
        let merger = CDADocumentMerger(configuration: config)
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        if case .structured(let body) = merged.component.body {
            XCTAssertEqual(body.component.count, 1)
            let mergedSection = body.component[0].section
            XCTAssertEqual(mergedSection.entry?.count, 2)
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testMergeSectionsDeduplication() {
        let entry = makeObservationEntry()
        let section1 = makeSection(code: .vitalSignsSection(), title: "Vital Signs", entries: [entry])
        let section2 = makeSection(code: .vitalSignsSection(), title: "Vital Signs", entries: [entry])

        let primary = makeDocument(sections: [section1])
        let secondary = makeDocument(sections: [section2])

        let config = CDAMergeConfiguration(conflictStrategy: .includeBoth, mergeEntries: true, deduplicateEntries: true)
        let merger = CDADocumentMerger(configuration: config)
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        if case .structured(let body) = merged.component.body {
            let mergedSection = body.component[0].section
            XCTAssertEqual(mergedSection.entry?.count, 1)
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testMergePreservesPrimaryHeader() {
        let primary = makeDocument(id: II(root: "PRIMARY"), title: "Primary Doc")
        let secondary = makeDocument(id: II(root: "SECONDARY"), title: "Secondary Doc")

        let merger = CDADocumentMerger()
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        XCTAssertEqual(merged.id.root, "PRIMARY")
        XCTAssertEqual(merged.title?.stringValue, "Primary Doc")
    }

    func testMergeNonStructuredBody() {
        let primary = ClinicalDocument(
            typeId: .cdaTypeId,
            templateId: [],
            id: II(root: "1.2.3"),
            code: .progressNote(),
            effectiveTime: TS(value: Date(), precision: .day),
            confidentialityCode: CD(code: "N"),
            recordTarget: [makeRecordTarget()],
            author: [makeAuthor()],
            custodian: makeCustodian(),
            component: DocumentComponent(body: .nonXML(NonXMLBody(text: ED(mediaType: "text/plain"))))
        )
        let secondary = makeDocument()

        let merger = CDADocumentMerger()
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        if case .nonXML = merged.component.body {
            // Expected: keep primary's non-XML body
        } else {
            XCTFail("Expected non-XML body preserved")
        }
    }

    func testMergeKeepSecondaryStrategy() {
        let entry1 = makeObservationEntry(code: CD(code: "HR", displayName: "Heart Rate"))
        let entry2 = makeObservationEntry(code: CD(code: "BP", displayName: "Blood Pressure"))
        let section1 = makeSection(code: .vitalSignsSection(), title: "Vital Signs", entries: [entry1])
        let section2 = makeSection(code: .vitalSignsSection(), title: "Vital Signs", entries: [entry2])
        let primary = makeDocument(sections: [section1])
        let secondary = makeDocument(sections: [section2])

        let config = CDAMergeConfiguration(conflictStrategy: .keepSecondary, mergeEntries: true)
        let merger = CDADocumentMerger(configuration: config)
        let merged = merger.mergeSections(primary: primary, secondary: secondary)

        if case .structured(let body) = merged.component.body {
            let mergedSection = body.component[0].section
            XCTAssertEqual(mergedSection.entry?.count, 1)
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testDefaultMergeConfiguration() {
        let config = CDAMergeConfiguration.default
        XCTAssertEqual(config.conflictStrategy, .keepPrimary)
        XCTAssertTrue(config.mergeEntries)
        XCTAssertTrue(config.deduplicateEntries)
    }

    // MARK: - Version Manager Tests

    func testCreateNewVersion() {
        let original = makeDocument(
            id: II(root: "1.2.3.4", extension: "V1"),
            setId: II(root: "1.2.3.4"),
            versionNumber: .value(1)
        )

        let manager = CDADocumentVersionManager()
        let newDoc = manager.createNewVersion(
            of: original,
            newId: II(root: "1.2.3.4", extension: "V2"),
            newEffectiveTime: TS(value: Date(), precision: .second)
        )

        XCTAssertEqual(newDoc.id.extension, "V2")
        XCTAssertEqual(newDoc.versionNumber?.intValue, 2)
        XCTAssertEqual(newDoc.setId?.root, "1.2.3.4")
        XCTAssertNotNil(newDoc.relatedDocument)
        XCTAssertTrue(newDoc.relatedDocument?.contains { $0.typeCode == "RPLC" } ?? false)
    }

    func testCreateNewVersionWithoutSetId() {
        let original = makeDocument(id: II(root: "1.2.3.4", extension: "V1"))

        let manager = CDADocumentVersionManager()
        let newDoc = manager.createNewVersion(
            of: original,
            newId: II(root: "1.2.3.4", extension: "V2"),
            newEffectiveTime: TS(value: Date(), precision: .second)
        )

        // setId should default to original id
        XCTAssertEqual(newDoc.setId?.root, "1.2.3.4")
        XCTAssertEqual(newDoc.versionNumber?.intValue, 2)
    }

    func testCreateNewVersionAppend() {
        let original = makeDocument(versionNumber: .value(1))
        let manager = CDADocumentVersionManager()
        let newDoc = manager.createNewVersion(
            of: original,
            newId: II(root: "new-id"),
            newEffectiveTime: TS(value: Date(), precision: .second),
            relationshipType: .append
        )
        XCTAssertTrue(newDoc.relatedDocument?.contains { $0.typeCode == "APND" } ?? false)
    }

    func testCreateNewVersionTransform() {
        let original = makeDocument(versionNumber: .value(1))
        let manager = CDADocumentVersionManager()
        let newDoc = manager.createNewVersion(
            of: original,
            newId: II(root: "new-id"),
            newEffectiveTime: TS(value: Date(), precision: .second),
            relationshipType: .transform
        )
        XCTAssertTrue(newDoc.relatedDocument?.contains { $0.typeCode == "XFRM" } ?? false)
    }

    func testCreateNewVersionWithCustomBody() {
        let original = makeDocument()
        let newSection = makeSection(title: "Updated Content", text: "New body content")
        let newBody = DocumentBody.structured(StructuredBody(component: [BodyComponent(section: newSection)]))

        let manager = CDADocumentVersionManager()
        let newDoc = manager.createNewVersion(
            of: original,
            newId: II(root: "new"),
            newEffectiveTime: TS(value: Date(), precision: .second),
            body: newBody
        )

        if case .structured(let body) = newDoc.component.body {
            XCTAssertEqual(body.component[0].section.title?.stringValue, "Updated Content")
        } else {
            XCTFail("Expected structured body")
        }
    }

    func testExtractVersionInfo() {
        let doc = makeDocument(
            setId: II(root: "SET1"),
            versionNumber: .value(3)
        )
        let manager = CDADocumentVersionManager()
        let info = manager.extractVersionInfo(doc)

        XCTAssertEqual(info.versionNumber, 3)
        XCTAssertEqual(info.setId?.root, "SET1")
        XCTAssertEqual(info.document, doc)
    }

    func testIsSuccessorByRelatedDocument() {
        let original = makeDocument(id: II(root: "ORIG"))
        let manager = CDADocumentVersionManager()
        let successor = manager.createNewVersion(
            of: original,
            newId: II(root: "SUCC"),
            newEffectiveTime: TS(value: Date(), precision: .second)
        )

        XCTAssertTrue(manager.isSuccessor(successor, of: original))
        XCTAssertFalse(manager.isSuccessor(original, of: successor))
    }

    func testIsSuccessorByVersionNumber() {
        let doc1 = makeDocument(
            id: II(root: "DOC1"),
            setId: II(root: "SET1"),
            versionNumber: .value(1)
        )
        let doc2 = makeDocument(
            id: II(root: "DOC2"),
            setId: II(root: "SET1"),
            versionNumber: .value(2)
        )

        let manager = CDADocumentVersionManager()
        XCTAssertTrue(manager.isSuccessor(doc2, of: doc1))
        XCTAssertFalse(manager.isSuccessor(doc1, of: doc2))
    }

    func testIsSuccessorDifferentSets() {
        let doc1 = makeDocument(
            id: II(root: "DOC1"),
            setId: II(root: "SET-A"),
            versionNumber: .value(1)
        )
        let doc2 = makeDocument(
            id: II(root: "DOC2"),
            setId: II(root: "SET-B"),
            versionNumber: .value(2)
        )

        let manager = CDADocumentVersionManager()
        XCTAssertFalse(manager.isSuccessor(doc2, of: doc1))
    }

    func testSortByVersion() {
        let doc1 = makeDocument(id: II(root: "1"), versionNumber: .value(3))
        let doc2 = makeDocument(id: II(root: "2"), versionNumber: .value(1))
        let doc3 = makeDocument(id: II(root: "3"), versionNumber: .value(2))

        let manager = CDADocumentVersionManager()
        let sorted = manager.sortByVersion([doc1, doc2, doc3])

        XCTAssertEqual(sorted[0].versionNumber?.intValue, 1)
        XCTAssertEqual(sorted[1].versionNumber?.intValue, 2)
        XCTAssertEqual(sorted[2].versionNumber?.intValue, 3)
    }

    func testSortByVersionWithNilVersions() {
        let doc1 = makeDocument(id: II(root: "1"), versionNumber: .value(2))
        let doc2 = makeDocument(id: II(root: "2"))
        let doc3 = makeDocument(id: II(root: "3"), versionNumber: .value(1))

        let manager = CDADocumentVersionManager()
        let sorted = manager.sortByVersion([doc1, doc2, doc3])

        XCTAssertEqual(sorted[0].versionNumber?.intValue, nil)
        XCTAssertEqual(sorted[1].versionNumber?.intValue, 1)
        XCTAssertEqual(sorted[2].versionNumber?.intValue, 2)
    }

    func testGroupByDocumentSet() {
        let doc1 = makeDocument(id: II(root: "D1"), setId: II(root: "SET-A"), versionNumber: .value(1))
        let doc2 = makeDocument(id: II(root: "D2"), setId: II(root: "SET-A"), versionNumber: .value(2))
        let doc3 = makeDocument(id: II(root: "D3"), setId: II(root: "SET-B"), versionNumber: .value(1))

        let manager = CDADocumentVersionManager()
        let groups = manager.groupByDocumentSet([doc1, doc2, doc3])

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups["SET-A"]?.count, 2)
        XCTAssertEqual(groups["SET-B"]?.count, 1)
        // Should be sorted by version within each group
        XCTAssertEqual(groups["SET-A"]?.first?.versionNumber?.intValue, 1)
        XCTAssertEqual(groups["SET-A"]?.last?.versionNumber?.intValue, 2)
    }

    func testGroupByDocumentSetFallsBackToId() {
        let doc1 = makeDocument(id: II(root: "ID-1"))
        let doc2 = makeDocument(id: II(root: "ID-2"))

        let manager = CDADocumentVersionManager()
        let groups = manager.groupByDocumentSet([doc1, doc2])

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups["ID-1"]?.count, 1)
        XCTAssertEqual(groups["ID-2"]?.count, 1)
    }

    // MARK: - CDA Change Type Tests

    func testCDAChangeTypeRawValues() {
        XCTAssertEqual(CDAChangeType.added.rawValue, "added")
        XCTAssertEqual(CDAChangeType.removed.rawValue, "removed")
        XCTAssertEqual(CDAChangeType.modified.rawValue, "modified")
    }

    // MARK: - CDA Document Relationship Type Tests

    func testDocumentRelationshipTypeRawValues() {
        XCTAssertEqual(CDADocumentRelationshipType.replace.rawValue, "RPLC")
        XCTAssertEqual(CDADocumentRelationshipType.append.rawValue, "APND")
        XCTAssertEqual(CDADocumentRelationshipType.transform.rawValue, "XFRM")
    }

    // MARK: - CDA Output Format Tests

    func testOutputFormatRawValues() {
        XCTAssertEqual(CDAOutputFormat.plainText.rawValue, "plainText")
        XCTAssertEqual(CDAOutputFormat.html.rawValue, "html")
    }

    // MARK: - Convenience Extension Tests

    func testConvenienceRenderToText() {
        let doc = makeDocument()
        let text = doc.renderToText()
        XCTAssertFalse(text.isEmpty)
    }

    func testConvenienceRenderToHTML() {
        let doc = makeDocument()
        let html = doc.renderToHTML()
        XCTAssertTrue(html.contains("<html>"))
    }

    func testConvenienceCompare() {
        let doc1 = makeDocument(title: "A")
        let doc2 = makeDocument(title: "B")
        let result = doc1.compare(with: doc2)
        XCTAssertFalse(result.areIdentical)
    }

    // MARK: - Edge Cases

    func testRenderDocumentWithMultipleSections() {
        let sections = [
            makeSection(code: .chiefComplaintSection(), title: "Chief Complaint", text: "Headache"),
            makeSection(code: .medicationsSection(), title: "Medications", text: "Aspirin"),
            makeSection(code: .vitalSignsSection(), title: "Vital Signs", text: "BP: 120/80")
        ]
        let doc = makeDocument(sections: sections)
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Chief Complaint"))
        XCTAssertTrue(text.contains("Medications"))
        XCTAssertTrue(text.contains("Vital Signs"))
    }

    func testRenderDocumentWithNestedSubsections() {
        let subSection = Section(title: .value("Sub-section"), text: Narrative.text("Sub content"))
        let parentSection = Section(
            title: .value("Parent Section"),
            text: Narrative.text("Parent content"),
            component: [SectionComponent(section: subSection)]
        )
        let doc = makeDocument(sections: [parentSection])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Parent Section"))
        XCTAssertTrue(text.contains("Sub-section"))
    }

    func testRenderEncounterEntry() {
        let entry = Entry(typeCode: .driv, clinicalStatement: .encounter(
            Encounter(code: CD(code: "99213", displayName: "Office Visit"))
        ))
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Encounter: Office Visit"))
    }

    func testRenderActEntry() {
        let entry = Entry(typeCode: .driv, clinicalStatement: .act(
            ClinicalAct(code: CD(code: "48765-2", displayName: "Allergy List"))
        ))
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Act: Allergy List"))
    }

    func testRenderSupplyEntry() {
        let entry = Entry(typeCode: .driv, clinicalStatement: .supply(
            Supply(code: CD(code: "99213", displayName: "Medical Device"))
        ))
        let section = makeSection(entries: [entry])
        let doc = makeDocument(sections: [section])
        let text = doc.renderToText()
        XCTAssertTrue(text.contains("Supply: Medical Device"))
    }

    func testCompareVersionNumberDifference() {
        let doc1 = makeDocument(setId: II(root: "S1"), versionNumber: .value(1))
        let doc2 = makeDocument(setId: II(root: "S1"), versionNumber: .value(2))
        let result = doc1.compare(with: doc2)
        XCTAssertTrue(result.headerDifferences.contains { $0.path == "header.versionNumber" })
    }

    func testCDADifferenceInit() {
        let diff = CDADifference(path: "header.title", changeType: .modified, oldValue: "A", newValue: "B")
        XCTAssertEqual(diff.path, "header.title")
        XCTAssertEqual(diff.changeType, .modified)
        XCTAssertEqual(diff.oldValue, "A")
        XCTAssertEqual(diff.newValue, "B")
    }

    func testCDADocumentVersionInit() {
        let doc = makeDocument()
        let version = CDADocumentVersion(document: doc, versionNumber: 1, setId: II(root: "SET1"), effectiveTime: doc.effectiveTime)
        XCTAssertEqual(version.versionNumber, 1)
        XCTAssertEqual(version.setId?.root, "SET1")
    }

    // MARK: - Performance Tests

    func testRenderToTextPerformance() {
        let doc = makeDocument()
        measure {
            _ = doc.renderToText()
        }
    }

    func testRenderToHTMLPerformance() {
        let doc = makeDocument()
        measure {
            _ = doc.renderToHTML()
        }
    }

    func testComparePerformance() {
        let doc1 = makeDocument(title: "A")
        let doc2 = makeDocument(title: "B")
        measure {
            _ = doc1.compare(with: doc2)
        }
    }
}
