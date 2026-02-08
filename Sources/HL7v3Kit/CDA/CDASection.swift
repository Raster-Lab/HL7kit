/// CDASection.swift
/// CDA R2 Section and Narrative Support
///
/// This file implements Section structures and narrative text handling for CDA documents.

import Foundation
import HL7Core

// MARK: - Section

/// Section - A section within a CDA document body
///
/// Sections organize clinical content with narrative text and optional structured entries.
/// Sections can be nested to create hierarchical document structures.
public struct Section: Sendable, Codable, Equatable {
    /// Class code (always DOCSECT for document section)
    public let classCode: String = "DOCSECT"
    
    /// Mood code (always EVN for event)
    public let moodCode: String = "EVN"
    
    /// Unique identifier for this section
    public let ID: String?
    
    /// Template identifiers for this section
    public let templateId: [II]?
    
    /// Section identifier
    public let id: II?
    
    /// Section type code (e.g., LOINC code for section type)
    public let code: CD?
    
    /// Section title
    public let title: ST?
    
    /// Human-readable narrative text
    public let text: Narrative?
    
    /// Confidentiality code for this section
    public let confidentialityCode: CD?
    
    /// Language code for this section
    public let languageCode: CD?
    
    /// Subject of this section (if different from document subject)
    public let subject: Subject?
    
    /// Author(s) of this section (if different from document authors)
    public let author: [Author]?
    
    /// Informants for this section
    public let informant: [Informant]?
    
    /// Structured entries containing machine-readable content
    public let entry: [Entry]?
    
    /// Nested subsections
    public let component: [SectionComponent]?
    
    public init(
        ID: String? = nil,
        templateId: [II]? = nil,
        id: II? = nil,
        code: CD? = nil,
        title: ST? = nil,
        text: Narrative? = nil,
        confidentialityCode: CD? = nil,
        languageCode: CD? = nil,
        subject: Subject? = nil,
        author: [Author]? = nil,
        informant: [Informant]? = nil,
        entry: [Entry]? = nil,
        component: [SectionComponent]? = nil
    ) {
        self.ID = ID
        self.templateId = templateId
        self.id = id
        self.code = code
        self.title = title
        self.text = text
        self.confidentialityCode = confidentialityCode
        self.languageCode = languageCode
        self.subject = subject
        self.author = author
        self.informant = informant
        self.entry = entry
        self.component = component
    }
}

// MARK: - SectionComponent

/// SectionComponent - Wrapper for nested sections
public struct SectionComponent: Sendable, Codable, Equatable {
    /// The nested section
    public let section: Section
    
    public init(section: Section) {
        self.section = section
    }
}

// MARK: - Subject

/// Subject - Subject of a section (if different from document subject)
public struct Subject: Sendable, Codable, Equatable {
    /// Type code (always SBJ for subject)
    public let typeCode: String = "SBJ"
    
    /// Context control code
    public let contextControlCode: String = "OP"
    
    /// Awareness code
    public let awarenessCode: CD?
    
    /// Related subject
    public let relatedSubject: RelatedSubject
    
    public init(
        awarenessCode: CD? = nil,
        relatedSubject: RelatedSubject
    ) {
        self.awarenessCode = awarenessCode
        self.relatedSubject = relatedSubject
    }
}

/// RelatedSubject - Details of a related subject
public struct RelatedSubject: Sendable, Codable, Equatable {
    /// Class code indicating type of subject
    public let classCode: String
    
    /// Subject code
    public let code: CD?
    
    /// Subject addresses
    public let addr: [AD]?
    
    /// Subject telecom
    public let telecom: [TEL]?
    
    /// Subject as a person
    public let subject: Person?
    
    public init(
        classCode: String = "PRS",
        code: CD? = nil,
        addr: [AD]? = nil,
        telecom: [TEL]? = nil,
        subject: Person? = nil
    ) {
        self.classCode = classCode
        self.code = code
        self.addr = addr
        self.telecom = telecom
        self.subject = subject
    }
}

// MARK: - Narrative

/// Narrative - Human-readable text content in a section
///
/// Contains HTML-like formatted text with support for tables, lists, paragraphs, etc.
/// The narrative must be in the xhtml namespace and follow CDA narrative constraints.
public struct Narrative: Sendable, Codable, Equatable {
    /// The narrative content as structured XML elements
    public let content: [NarrativeElement]
    
    /// ID attribute for referencing
    public let ID: String?
    
    /// Language code
    public let language: String?
    
    /// Style information
    public let styleCode: String?
    
    public init(
        content: [NarrativeElement],
        ID: String? = nil,
        language: String? = nil,
        styleCode: String? = nil
    ) {
        self.content = content
        self.ID = ID
        self.language = language
        self.styleCode = styleCode
    }
    
    /// Creates a simple narrative with plain text
    public static func text(_ text: String) -> Narrative {
        Narrative(content: [.text(text)])
    }
    
    /// Creates a narrative with a paragraph
    public static func paragraph(_ text: String) -> Narrative {
        Narrative(content: [.paragraph(NarrativeParagraph(content: [.text(text)]))])
    }
}

// MARK: - NarrativeElement

/// NarrativeElement - Elements that can appear in narrative text
public indirect enum NarrativeElement: Sendable, Codable, Equatable {
    /// Plain text content
    case text(String)
    
    /// Paragraph
    case paragraph(NarrativeParagraph)
    
    /// Line break
    case br
    
    /// List
    case list(NarrativeList)
    
    /// Table
    case table(NarrativeTable)
    
    /// Content wrapped in a specific element
    case content(NarrativeContent)
    
    /// Link reference
    case linkHtml(NarrativeLinkHtml)
    
    /// Rendering element (for styling)
    case renderMultiMedia(NarrativeRenderMultiMedia)
}

// MARK: - Narrative Structures

/// NarrativeParagraph - A paragraph in narrative text
public struct NarrativeParagraph: Sendable, Codable, Equatable {
    /// Paragraph content
    public let content: [NarrativeElement]
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    public init(content: [NarrativeElement], ID: String? = nil, styleCode: String? = nil) {
        self.content = content
        self.ID = ID
        self.styleCode = styleCode
    }
}

/// NarrativeList - A list in narrative text
public struct NarrativeList: Sendable, Codable, Equatable {
    /// List type (ordered, unordered)
    public let listType: ListType
    
    /// List items
    public let item: [NarrativeListItem]
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    public init(
        listType: ListType = .unordered,
        item: [NarrativeListItem],
        ID: String? = nil,
        styleCode: String? = nil
    ) {
        self.listType = listType
        self.item = item
        self.ID = ID
        self.styleCode = styleCode
    }
    
    /// List type enumeration
    public enum ListType: String, Sendable, Codable {
        case ordered
        case unordered
    }
}

/// NarrativeListItem - An item in a narrative list
public struct NarrativeListItem: Sendable, Codable, Equatable {
    /// Item content
    public let content: [NarrativeElement]
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    public init(content: [NarrativeElement], ID: String? = nil, styleCode: String? = nil) {
        self.content = content
        self.ID = ID
        self.styleCode = styleCode
    }
}

/// NarrativeTable - A table in narrative text
public struct NarrativeTable: Sendable, Codable, Equatable {
    /// Table caption
    public let caption: NarrativeCaption?
    
    /// Table head
    public let thead: NarrativeTableHead?
    
    /// Table body
    public let tbody: NarrativeTableBody
    
    /// Table footer
    public let tfoot: NarrativeTableFoot?
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    /// Border attribute
    public let border: String?
    
    /// Width attribute
    public let width: String?
    
    public init(
        caption: NarrativeCaption? = nil,
        thead: NarrativeTableHead? = nil,
        tbody: NarrativeTableBody,
        tfoot: NarrativeTableFoot? = nil,
        ID: String? = nil,
        styleCode: String? = nil,
        border: String? = nil,
        width: String? = nil
    ) {
        self.caption = caption
        self.thead = thead
        self.tbody = tbody
        self.tfoot = tfoot
        self.ID = ID
        self.styleCode = styleCode
        self.border = border
        self.width = width
    }
}

/// NarrativeCaption - Table caption
public struct NarrativeCaption: Sendable, Codable, Equatable {
    public let content: [NarrativeElement]
    
    public init(content: [NarrativeElement]) {
        self.content = content
    }
}

/// NarrativeTableHead - Table head
public struct NarrativeTableHead: Sendable, Codable, Equatable {
    public let tr: [NarrativeTableRow]
    
    public init(tr: [NarrativeTableRow]) {
        self.tr = tr
    }
}

/// NarrativeTableBody - Table body
public struct NarrativeTableBody: Sendable, Codable, Equatable {
    public let tr: [NarrativeTableRow]
    
    public init(tr: [NarrativeTableRow]) {
        self.tr = tr
    }
}

/// NarrativeTableFoot - Table footer
public struct NarrativeTableFoot: Sendable, Codable, Equatable {
    public let tr: [NarrativeTableRow]
    
    public init(tr: [NarrativeTableRow]) {
        self.tr = tr
    }
}

/// NarrativeTableRow - Table row
public struct NarrativeTableRow: Sendable, Codable, Equatable {
    /// Row cells
    public let th: [NarrativeTableCell]?
    public let td: [NarrativeTableCell]?
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    public init(
        th: [NarrativeTableCell]? = nil,
        td: [NarrativeTableCell]? = nil,
        ID: String? = nil,
        styleCode: String? = nil
    ) {
        self.th = th
        self.td = td
        self.ID = ID
        self.styleCode = styleCode
    }
}

/// NarrativeTableCell - Table cell (th or td)
public struct NarrativeTableCell: Sendable, Codable, Equatable {
    /// Cell content
    public let content: [NarrativeElement]
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    /// Column span
    public let colspan: String?
    
    /// Row span
    public let rowspan: String?
    
    /// Alignment
    public let align: String?
    
    public init(
        content: [NarrativeElement],
        ID: String? = nil,
        styleCode: String? = nil,
        colspan: String? = nil,
        rowspan: String? = nil,
        align: String? = nil
    ) {
        self.content = content
        self.ID = ID
        self.styleCode = styleCode
        self.colspan = colspan
        self.rowspan = rowspan
        self.align = align
    }
}

/// NarrativeContent - Generic content wrapper
public struct NarrativeContent: Sendable, Codable, Equatable {
    /// Content elements
    public let content: [NarrativeElement]
    
    /// ID attribute
    public let ID: String?
    
    /// Style code
    public let styleCode: String?
    
    /// Revised attribute (for change tracking)
    public let revised: String?
    
    public init(
        content: [NarrativeElement],
        ID: String? = nil,
        styleCode: String? = nil,
        revised: String? = nil
    ) {
        self.content = content
        self.ID = ID
        self.styleCode = styleCode
        self.revised = revised
    }
}

/// NarrativeLinkHtml - HTML link
public struct NarrativeLinkHtml: Sendable, Codable, Equatable {
    /// Link content
    public let content: [NarrativeElement]
    
    /// href attribute
    public let href: String
    
    /// name attribute
    public let name: String?
    
    /// ID attribute
    public let ID: String?
    
    public init(
        content: [NarrativeElement],
        href: String,
        name: String? = nil,
        ID: String? = nil
    ) {
        self.content = content
        self.href = href
        self.name = name
        self.ID = ID
    }
}

/// NarrativeRenderMultiMedia - Multimedia reference
public struct NarrativeRenderMultiMedia: Sendable, Codable, Equatable {
    /// Reference to multimedia object
    public let referencedObject: String
    
    /// Caption
    public let caption: NarrativeCaption?
    
    /// ID attribute
    public let ID: String?
    
    public init(
        referencedObject: String,
        caption: NarrativeCaption? = nil,
        ID: String? = nil
    ) {
        self.referencedObject = referencedObject
        self.caption = caption
        self.ID = ID
    }
}

// MARK: - Common Section Types

/// Common section type codes from LOINC
public extension CD {
    /// Chief Complaint section
    static func chiefComplaintSection() -> CD {
        CD(code: "10154-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Chief complaint")
    }
    
    /// History of Present Illness section
    static func historyOfPresentIllnessSection() -> CD {
        CD(code: "10164-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of present illness")
    }
    
    /// Past Medical History section
    static func pastMedicalHistorySection() -> CD {
        CD(code: "11348-0", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of past illness")
    }
    
    /// Medications section
    static func medicationsSection() -> CD {
        CD(code: "10160-0", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of medication use")
    }
    
    /// Allergies section
    static func allergiesSection() -> CD {
        CD(code: "48765-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "Allergies")
    }
    
    /// Problem List section
    static func problemListSection() -> CD {
        CD(code: "11450-4", codeSystem: "2.16.840.1.113883.6.1", displayName: "Problem list")
    }
    
    /// Procedures section
    static func proceduresSection() -> CD {
        CD(code: "47519-4", codeSystem: "2.16.840.1.113883.6.1", displayName: "History of procedures")
    }
    
    /// Results section
    static func resultsSection() -> CD {
        CD(code: "30954-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "Relevant diagnostic tests/laboratory data")
    }
    
    /// Vital Signs section
    static func vitalSignsSection() -> CD {
        CD(code: "8716-3", codeSystem: "2.16.840.1.113883.6.1", displayName: "Vital signs")
    }
    
    /// Assessment section
    static func assessmentSection() -> CD {
        CD(code: "51848-0", codeSystem: "2.16.840.1.113883.6.1", displayName: "Assessment")
    }
    
    /// Plan of Care section
    static func planOfCareSection() -> CD {
        CD(code: "18776-5", codeSystem: "2.16.840.1.113883.6.1", displayName: "Plan of care")
    }
    
    /// Assessment and Plan section
    static func assessmentAndPlanSection() -> CD {
        CD(code: "51847-2", codeSystem: "2.16.840.1.113883.6.1", displayName: "Assessment and plan")
    }
}
