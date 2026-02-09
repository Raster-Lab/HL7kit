/// CDADocumentProcessing.swift
/// CDA Document Processing, Rendering, Comparison, Merging, and Versioning
///
/// Phase 4.4: Implements document rendering (plain text and HTML), structural comparison,
/// section merging, and version management for CDA R2 documents.

import Foundation
import HL7Core

// MARK: - CDA Document Renderer

/// Configuration for CDA document rendering
public struct CDARenderingConfiguration: Sendable, Codable, Equatable {
    /// Whether to include header information in the output
    public let includeHeader: Bool

    /// Whether to include section titles
    public let includeSectionTitles: Bool

    /// Whether to render entries (machine-readable content)
    public let renderEntries: Bool

    /// Maximum line width for text output (0 = no limit)
    public let maxLineWidth: Int

    /// Indentation string for nested content
    public let indentation: String

    public init(
        includeHeader: Bool = true,
        includeSectionTitles: Bool = true,
        renderEntries: Bool = true,
        maxLineWidth: Int = 80,
        indentation: String = "  "
    ) {
        self.includeHeader = includeHeader
        self.includeSectionTitles = includeSectionTitles
        self.renderEntries = renderEntries
        self.maxLineWidth = maxLineWidth
        self.indentation = indentation
    }

    /// Default rendering configuration
    public static let `default` = CDARenderingConfiguration()
}

/// Output format for CDA document rendering
public enum CDAOutputFormat: String, Sendable, Codable {
    case plainText
    case html
}

/// Renders CDA documents to plain text or HTML
public struct CDADocumentRenderer: Sendable {
    /// Rendering configuration
    public let configuration: CDARenderingConfiguration

    public init(configuration: CDARenderingConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Rendering Methods

    /// Renders a ClinicalDocument to plain text
    public func renderToText(_ document: ClinicalDocument) -> String {
        var output = ""

        if configuration.includeHeader {
            output += renderHeaderText(document)
            output += "\n"
        }

        output += renderBodyText(document.component.body)

        return output
    }

    /// Renders a ClinicalDocument to HTML with embedded CSS
    public func renderToHTML(_ document: ClinicalDocument) -> String {
        var html = "<!DOCTYPE html>\n<html>\n<head>\n"
        html += "<meta charset=\"UTF-8\">\n"
        html += "<style>\n"
        html += renderCSS()
        html += "</style>\n"
        html += "</head>\n<body>\n"
        html += "<div class=\"cda-document\">\n"

        if configuration.includeHeader {
            html += renderHeaderHTML(document)
        }

        html += renderBodyHTML(document.component.body)

        html += "</div>\n</body>\n</html>"
        return html
    }

    // MARK: - CSS

    private func renderCSS() -> String {
        """
        body { font-family: Arial, sans-serif; margin: 20px; }
        .cda-document { max-width: 900px; margin: 0 auto; }
        .cda-header { border-bottom: 2px solid #333; padding-bottom: 10px; margin-bottom: 20px; }
        .cda-header h1 { margin: 0 0 10px 0; }
        .cda-header .meta { color: #666; font-size: 0.9em; }
        .cda-section { margin-bottom: 20px; }
        .cda-section h2 { border-bottom: 1px solid #ccc; padding-bottom: 5px; }
        .cda-entry { margin-left: 20px; padding: 5px; background: #f9f9f9; margin-bottom: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
        th { background: #f0f0f0; }
        ul, ol { margin: 5px 0; padding-left: 20px; }

        """
    }

    // MARK: - Header Rendering (Text)

    private func renderHeaderText(_ document: ClinicalDocument) -> String {
        var output = ""
        let separator = String(repeating: "=", count: configuration.maxLineWidth > 0 ? configuration.maxLineWidth : 80)

        output += separator + "\n"

        if let title = document.title?.stringValue {
            output += title + "\n"
        }

        output += separator + "\n"

        output += "Document ID: \(formatIdentifier(document.id))\n"
        output += "Document Type: \(document.code.displayName ?? document.code.code ?? "Unknown")\n"
        output += "Effective Time: \(formatTimestamp(document.effectiveTime))\n"
        output += "Confidentiality: \(document.confidentialityCode.displayName ?? document.confidentialityCode.code ?? "N/A")\n"

        if let lang = document.languageCode {
            output += "Language: \(lang.code ?? "Unknown")\n"
        }

        if let setId = document.setId {
            output += "Set ID: \(formatIdentifier(setId))\n"
        }

        if let version = document.versionNumber?.intValue {
            output += "Version: \(version)\n"
        }

        // Patient information
        for rt in document.recordTarget {
            output += "\nPatient: \(formatPatientName(rt))\n"
            let ids = rt.patientRole.id.map { formatIdentifier($0) }.joined(separator: ", ")
            output += "Patient ID: \(ids)\n"
        }

        // Author information
        for auth in document.author {
            output += "Author: \(formatAuthorName(auth))\n"
        }

        // Custodian
        let custOrg = document.custodian.assignedCustodian.representedCustodianOrganization
        if let name = custOrg.name {
            output += "Custodian: \(formatEntityName(name))\n"
        }

        output += separator + "\n"
        return output
    }

    // MARK: - Header Rendering (HTML)

    private func renderHeaderHTML(_ document: ClinicalDocument) -> String {
        var html = "<div class=\"cda-header\">\n"

        if let title = document.title?.stringValue {
            html += "<h1>\(escapeHTML(title))</h1>\n"
        }

        html += "<div class=\"meta\">\n"
        html += "<p><strong>Document ID:</strong> \(escapeHTML(formatIdentifier(document.id)))</p>\n"
        html += "<p><strong>Type:</strong> \(escapeHTML(document.code.displayName ?? document.code.code ?? "Unknown"))</p>\n"
        html += "<p><strong>Date:</strong> \(escapeHTML(formatTimestamp(document.effectiveTime)))</p>\n"
        html += "<p><strong>Confidentiality:</strong> \(escapeHTML(document.confidentialityCode.displayName ?? document.confidentialityCode.code ?? "N/A"))</p>\n"

        for rt in document.recordTarget {
            html += "<p><strong>Patient:</strong> \(escapeHTML(formatPatientName(rt)))</p>\n"
        }

        for auth in document.author {
            html += "<p><strong>Author:</strong> \(escapeHTML(formatAuthorName(auth)))</p>\n"
        }

        let custOrg = document.custodian.assignedCustodian.representedCustodianOrganization
        if let name = custOrg.name {
            html += "<p><strong>Custodian:</strong> \(escapeHTML(formatEntityName(name)))</p>\n"
        }

        html += "</div>\n</div>\n"
        return html
    }

    // MARK: - Body Rendering (Text)

    private func renderBodyText(_ body: DocumentBody) -> String {
        switch body {
        case .structured(let structuredBody):
            return renderStructuredBodyText(structuredBody)
        case .nonXML(let nonXMLBody):
            return renderNonXMLBodyText(nonXMLBody)
        }
    }

    private func renderStructuredBodyText(_ body: StructuredBody) -> String {
        var output = ""
        for comp in body.component {
            output += renderSectionText(comp.section, depth: 0)
            output += "\n"
        }
        return output
    }

    private func renderNonXMLBodyText(_ body: NonXMLBody) -> String {
        var output = "[Non-XML Body"
        if let mediaType = body.text.mediaType {
            output += " (\(mediaType))"
        }
        output += "]\n"
        if let ref = body.text.reference?.stringValue {
            output += "Reference: \(ref)\n"
        }
        return output
    }

    private func renderSectionText(_ section: Section, depth: Int) -> String {
        var output = ""
        let indent = String(repeating: configuration.indentation, count: depth)

        if configuration.includeSectionTitles {
            if let title = section.title?.stringValue {
                output += indent + title + "\n"
                output += indent + String(repeating: "-", count: title.count) + "\n"
            } else if let code = section.code?.displayName {
                output += indent + code + "\n"
                output += indent + String(repeating: "-", count: code.count) + "\n"
            }
        }

        // Render narrative text
        if let narrative = section.text {
            output += narrativeElementsToText(narrative.content, indent: indent)
            output += "\n"
        }

        // Render entries
        if configuration.renderEntries, let entries = section.entry {
            for entry in entries {
                output += renderEntryText(entry, indent: indent)
            }
        }

        // Render subsections
        if let components = section.component {
            for comp in components {
                output += renderSectionText(comp.section, depth: depth + 1)
            }
        }

        return output
    }

    private func renderEntryText(_ entry: Entry, indent: String) -> String {
        var output = ""
        let entryIndent = indent + configuration.indentation

        switch entry.clinicalStatement {
        case .observation(let obs):
            output += entryIndent + "Observation: \(obs.code.displayName ?? obs.code.code ?? "Unknown")\n"
            if let values = obs.value {
                for val in values {
                    output += entryIndent + "  Value: \(formatObservationValue(val))\n"
                }
            }
            output += entryIndent + "  Status: \(obs.statusCode.rawValue)\n"

        case .procedure(let proc):
            output += entryIndent + "Procedure: \(proc.code?.displayName ?? proc.code?.code ?? "Unknown")\n"
            if let status = proc.statusCode {
                output += entryIndent + "  Status: \(status.rawValue)\n"
            }

        case .substanceAdministration(let sa):
            let medName = sa.consumable.manufacturedProduct.manufacturedMaterial?.name.flatMap { formatEntityName($0) }
                ?? sa.consumable.manufacturedProduct.manufacturedMaterial?.code?.displayName
                ?? "Unknown medication"
            output += entryIndent + "Medication: \(medName)\n"
            if let dose = sa.doseQuantity {
                output += entryIndent + "  Dose: \(formatQuantityInterval(dose))\n"
            }
            if let route = sa.routeCode {
                output += entryIndent + "  Route: \(route.displayName ?? route.code ?? "N/A")\n"
            }

        case .supply(let supply):
            output += entryIndent + "Supply: \(supply.code?.displayName ?? supply.code?.code ?? "Unknown")\n"

        case .encounter(let enc):
            output += entryIndent + "Encounter: \(enc.code?.displayName ?? enc.code?.code ?? "Unknown")\n"

        case .act(let act):
            output += entryIndent + "Act: \(act.code?.displayName ?? act.code?.code ?? "Unknown")\n"

        case .organizer(let org):
            output += entryIndent + "Organizer: \(org.code?.displayName ?? org.code?.code ?? "Group")\n"
            for comp in org.component {
                let subEntry = Entry(typeCode: .comp, clinicalStatement: comp.clinicalStatement)
                output += renderEntryText(subEntry, indent: entryIndent)
            }
        }

        return output
    }

    // MARK: - Body Rendering (HTML)

    private func renderBodyHTML(_ body: DocumentBody) -> String {
        switch body {
        case .structured(let structuredBody):
            return renderStructuredBodyHTML(structuredBody)
        case .nonXML(let nonXMLBody):
            return renderNonXMLBodyHTML(nonXMLBody)
        }
    }

    private func renderStructuredBodyHTML(_ body: StructuredBody) -> String {
        var html = "<div class=\"cda-body\">\n"
        for comp in body.component {
            html += renderSectionHTML(comp.section, depth: 0)
        }
        html += "</div>\n"
        return html
    }

    private func renderNonXMLBodyHTML(_ body: NonXMLBody) -> String {
        var html = "<div class=\"cda-body non-xml\">\n"
        html += "<p><em>Non-XML Body"
        if let mediaType = body.text.mediaType {
            html += " (\(escapeHTML(mediaType)))"
        }
        html += "</em></p>\n"
        if let ref = body.text.reference?.stringValue {
            html += "<p>Reference: <a href=\"\(escapeHTML(ref))\">\(escapeHTML(ref))</a></p>\n"
        }
        html += "</div>\n"
        return html
    }

    private func renderSectionHTML(_ section: Section, depth: Int) -> String {
        var html = "<div class=\"cda-section\">\n"
        let headingLevel = min(depth + 2, 6)

        if configuration.includeSectionTitles {
            let titleText = section.title?.stringValue ?? section.code?.displayName
            if let title = titleText {
                html += "<h\(headingLevel)>\(escapeHTML(title))</h\(headingLevel)>\n"
            }
        }

        // Render narrative text
        if let narrative = section.text {
            html += "<div class=\"narrative\">\n"
            html += narrativeElementsToHTML(narrative.content)
            html += "</div>\n"
        }

        // Render entries
        if configuration.renderEntries, let entries = section.entry {
            for entry in entries {
                html += renderEntryHTML(entry)
            }
        }

        // Render subsections
        if let components = section.component {
            for comp in components {
                html += renderSectionHTML(comp.section, depth: depth + 1)
            }
        }

        html += "</div>\n"
        return html
    }

    private func renderEntryHTML(_ entry: Entry) -> String {
        var html = "<div class=\"cda-entry\">\n"

        switch entry.clinicalStatement {
        case .observation(let obs):
            html += "<strong>Observation:</strong> \(escapeHTML(obs.code.displayName ?? obs.code.code ?? "Unknown"))"
            if let values = obs.value {
                let valStr = values.map { formatObservationValue($0) }.joined(separator: ", ")
                html += " — \(escapeHTML(valStr))"
            }
            html += " <span class=\"status\">[\(escapeHTML(obs.statusCode.rawValue))]</span>"

        case .procedure(let proc):
            html += "<strong>Procedure:</strong> \(escapeHTML(proc.code?.displayName ?? proc.code?.code ?? "Unknown"))"
            if let status = proc.statusCode {
                html += " <span class=\"status\">[\(escapeHTML(status.rawValue))]</span>"
            }

        case .substanceAdministration(let sa):
            let medName = sa.consumable.manufacturedProduct.manufacturedMaterial?.name.flatMap { formatEntityName($0) }
                ?? sa.consumable.manufacturedProduct.manufacturedMaterial?.code?.displayName
                ?? "Unknown medication"
            html += "<strong>Medication:</strong> \(escapeHTML(medName))"
            if let dose = sa.doseQuantity {
                html += " — Dose: \(escapeHTML(formatQuantityInterval(dose)))"
            }
            if let route = sa.routeCode {
                html += " — Route: \(escapeHTML(route.displayName ?? route.code ?? "N/A"))"
            }

        case .supply(let supply):
            html += "<strong>Supply:</strong> \(escapeHTML(supply.code?.displayName ?? supply.code?.code ?? "Unknown"))"

        case .encounter(let enc):
            html += "<strong>Encounter:</strong> \(escapeHTML(enc.code?.displayName ?? enc.code?.code ?? "Unknown"))"

        case .act(let act):
            html += "<strong>Act:</strong> \(escapeHTML(act.code?.displayName ?? act.code?.code ?? "Unknown"))"

        case .organizer(let org):
            html += "<strong>Organizer:</strong> \(escapeHTML(org.code?.displayName ?? org.code?.code ?? "Group"))\n"
            for comp in org.component {
                let subEntry = Entry(typeCode: .comp, clinicalStatement: comp.clinicalStatement)
                html += renderEntryHTML(subEntry)
            }
        }

        html += "\n</div>\n"
        return html
    }

    // MARK: - Narrative Rendering (Text)

    private func narrativeElementsToText(_ elements: [NarrativeElement], indent: String = "") -> String {
        var output = ""
        for element in elements {
            output += narrativeElementToText(element, indent: indent)
        }
        return output
    }

    private func narrativeElementToText(_ element: NarrativeElement, indent: String) -> String {
        switch element {
        case .text(let text):
            return indent + text

        case .paragraph(let para):
            return indent + narrativeElementsToText(para.content, indent: "") + "\n"

        case .br:
            return "\n"

        case .list(let list):
            return renderListText(list, indent: indent)

        case .table(let table):
            return renderTableText(table, indent: indent)

        case .content(let content):
            return narrativeElementsToText(content.content, indent: indent)

        case .linkHtml(let link):
            let text = narrativeElementsToText(link.content, indent: "")
            return text.isEmpty ? link.href : text

        case .renderMultiMedia(let media):
            var result = "[Media: \(media.referencedObject)]"
            if let caption = media.caption {
                result += " " + narrativeElementsToText(caption.content, indent: "")
            }
            return result
        }
    }

    private func renderListText(_ list: NarrativeList, indent: String) -> String {
        var output = ""
        for (index, item) in list.item.enumerated() {
            let prefix: String
            switch list.listType {
            case .ordered:
                prefix = "\(index + 1). "
            case .unordered:
                prefix = "\u{2022} "
            }
            output += indent + prefix + narrativeElementsToText(item.content, indent: "").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        }
        return output
    }

    private func renderTableText(_ table: NarrativeTable, indent: String) -> String {
        var output = ""

        if let caption = table.caption {
            output += indent + narrativeElementsToText(caption.content, indent: "") + "\n"
        }

        if let thead = table.thead {
            for row in thead.tr {
                output += renderTableRowText(row, indent: indent, isHeader: true)
            }
        }

        for row in table.tbody.tr {
            output += renderTableRowText(row, indent: indent, isHeader: false)
        }

        if let tfoot = table.tfoot {
            for row in tfoot.tr {
                output += renderTableRowText(row, indent: indent, isHeader: false)
            }
        }

        return output
    }

    private func renderTableRowText(_ row: NarrativeTableRow, indent: String, isHeader: Bool) -> String {
        var cells: [String] = []

        if let headerCells = row.th {
            cells += headerCells.map { narrativeElementsToText($0.content, indent: "").trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        if let dataCells = row.td {
            cells += dataCells.map { narrativeElementsToText($0.content, indent: "").trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        let line = indent + cells.joined(separator: " | ") + "\n"
        if isHeader {
            let separatorLine = indent + String(repeating: "-", count: cells.joined(separator: " | ").count) + "\n"
            return line + separatorLine
        }
        return line
    }

    // MARK: - Narrative Rendering (HTML)

    private func narrativeElementsToHTML(_ elements: [NarrativeElement]) -> String {
        var html = ""
        for element in elements {
            html += narrativeElementToHTML(element)
        }
        return html
    }

    private func narrativeElementToHTML(_ element: NarrativeElement) -> String {
        switch element {
        case .text(let text):
            return escapeHTML(text)

        case .paragraph(let para):
            var attrs = ""
            if let id = para.ID { attrs += " id=\"\(escapeHTML(id))\"" }
            if let style = para.styleCode { attrs += " class=\"\(escapeHTML(style))\"" }
            return "<p\(attrs)>\(narrativeElementsToHTML(para.content))</p>\n"

        case .br:
            return "<br/>\n"

        case .list(let list):
            return renderListHTML(list)

        case .table(let table):
            return renderTableHTML(table)

        case .content(let content):
            var attrs = ""
            if let id = content.ID { attrs += " id=\"\(escapeHTML(id))\"" }
            if let style = content.styleCode { attrs += " class=\"\(escapeHTML(style))\"" }
            return "<span\(attrs)>\(narrativeElementsToHTML(content.content))</span>"

        case .linkHtml(let link):
            return "<a href=\"\(escapeHTML(link.href))\">\(narrativeElementsToHTML(link.content))</a>"

        case .renderMultiMedia(let media):
            var html = "<div class=\"multimedia\" data-ref=\"\(escapeHTML(media.referencedObject))\">"
            if let caption = media.caption {
                html += "<p class=\"caption\">\(narrativeElementsToHTML(caption.content))</p>"
            }
            html += "</div>"
            return html
        }
    }

    private func renderListHTML(_ list: NarrativeList) -> String {
        let tag = list.listType == .ordered ? "ol" : "ul"
        var html = "<\(tag)>\n"
        for item in list.item {
            html += "<li>\(narrativeElementsToHTML(item.content))</li>\n"
        }
        html += "</\(tag)>\n"
        return html
    }

    private func renderTableHTML(_ table: NarrativeTable) -> String {
        var html = "<table"
        if let border = table.border { html += " border=\"\(escapeHTML(border))\"" }
        if let width = table.width { html += " width=\"\(escapeHTML(width))\"" }
        html += ">\n"

        if let caption = table.caption {
            html += "<caption>\(narrativeElementsToHTML(caption.content))</caption>\n"
        }

        if let thead = table.thead {
            html += "<thead>\n"
            for row in thead.tr {
                html += renderTableRowHTML(row, useHeader: true)
            }
            html += "</thead>\n"
        }

        html += "<tbody>\n"
        for row in table.tbody.tr {
            html += renderTableRowHTML(row, useHeader: false)
        }
        html += "</tbody>\n"

        if let tfoot = table.tfoot {
            html += "<tfoot>\n"
            for row in tfoot.tr {
                html += renderTableRowHTML(row, useHeader: false)
            }
            html += "</tfoot>\n"
        }

        html += "</table>\n"
        return html
    }

    private func renderTableRowHTML(_ row: NarrativeTableRow, useHeader: Bool) -> String {
        var html = "<tr>\n"

        if let headerCells = row.th {
            for cell in headerCells {
                html += renderTableCellHTML(cell, tag: "th")
            }
        }

        if let dataCells = row.td {
            let tag = useHeader ? "th" : "td"
            for cell in dataCells {
                html += renderTableCellHTML(cell, tag: tag)
            }
        }

        html += "</tr>\n"
        return html
    }

    private func renderTableCellHTML(_ cell: NarrativeTableCell, tag: String) -> String {
        var attrs = ""
        if let colspan = cell.colspan { attrs += " colspan=\"\(escapeHTML(colspan))\"" }
        if let rowspan = cell.rowspan { attrs += " rowspan=\"\(escapeHTML(rowspan))\"" }
        if let align = cell.align { attrs += " align=\"\(escapeHTML(align))\"" }
        return "<\(tag)\(attrs)>\(narrativeElementsToHTML(cell.content))</\(tag)>\n"
    }

    // MARK: - Formatting Helpers

    /// Formats a timestamp for display
    public func formatTimestamp(_ ts: TS) -> String {
        guard let date = ts.value else { return "Unknown" }
        let formatter = DateFormatter()
        switch ts.precision {
        case .year:
            formatter.dateFormat = "yyyy"
        case .month:
            formatter.dateFormat = "yyyy-MM"
        case .day:
            formatter.dateFormat = "yyyy-MM-dd"
        case .hour:
            formatter.dateFormat = "yyyy-MM-dd HH"
        case .minute:
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        case .second:
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        case .millisecond:
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        }
        return formatter.string(from: date)
    }

    /// Formats an instance identifier for display
    public func formatIdentifier(_ id: II) -> String {
        if let ext = id.extension {
            return "\(id.root)^\(ext)"
        }
        return id.root
    }

    /// Formats an entity name for display
    public func formatEntityName(_ name: EN) -> String {
        if name.parts.isEmpty { return "Unknown" }

        let prefixes = name.parts.filter { $0.type == .prefix }.map(\.value)
        let givens = name.parts.filter { $0.type == .given }.map(\.value)
        let families = name.parts.filter { $0.type == .family }.map(\.value)
        let suffixes = name.parts.filter { $0.type == .suffix }.map(\.value)

        var components: [String] = []
        components.append(contentsOf: prefixes)
        components.append(contentsOf: givens)
        components.append(contentsOf: families)
        components.append(contentsOf: suffixes)

        return components.joined(separator: " ")
    }

    /// Formats a patient name from a RecordTarget
    public func formatPatientName(_ recordTarget: RecordTarget) -> String {
        guard let patient = recordTarget.patientRole.patient,
              let names = patient.name,
              let firstName = names.first else {
            return "Unknown Patient"
        }
        return formatEntityName(firstName)
    }

    /// Formats an author name from an Author
    public func formatAuthorName(_ author: Author) -> String {
        guard let person = author.assignedAuthor.assignedPerson,
              let names = person.name,
              let firstName = names.first else {
            return "Unknown Author"
        }
        return formatEntityName(firstName)
    }

    /// Formats an observation value for display
    public func formatObservationValue(_ value: ObservationValue) -> String {
        switch value {
        case .physicalQuantity(let pq):
            guard let val = pq.value else { return "N/A" }
            if let unit = pq.unit {
                return "\(val) \(unit)"
            }
            return "\(val)"

        case .codedValue(let cd):
            return cd.displayName ?? cd.code ?? "Unknown"

        case .stringValue(let st):
            return st.stringValue ?? "N/A"

        case .integerValue(let intVal):
            if let val = intVal.intValue {
                return "\(val)"
            }
            return "N/A"

        case .realValue(let real):
            if let val = real.doubleValue {
                return "\(val)"
            }
            return "N/A"

        case .booleanValue(let bl):
            if let val = bl.boolValue {
                return val ? "true" : "false"
            }
            return "N/A"

        case .timestampValue(let ts):
            return formatTimestamp(ts)

        case .intervalValue(let ivl):
            return formatQuantityInterval(ivl)
        }
    }

    /// Formats a quantity interval for display
    public func formatQuantityInterval(_ interval: IVL<PQ>) -> String {
        var parts: [String] = []

        if let low = interval.low, let val = low.value {
            let unit = low.unit ?? ""
            parts.append("\(val) \(unit)".trimmingCharacters(in: .whitespaces))
        }

        if let high = interval.high, let val = high.value {
            let unit = high.unit ?? ""
            parts.append("\(val) \(unit)".trimmingCharacters(in: .whitespaces))
        }

        if parts.count == 2 {
            return "\(parts[0]) - \(parts[1])"
        } else if parts.count == 1 {
            return parts[0]
        }
        return "N/A"
    }

    /// Escapes special HTML characters
    public func escapeHTML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }
}

// MARK: - CDA Document Comparator

/// Types of changes between two CDA documents
public enum CDAChangeType: String, Sendable, Codable, Equatable {
    case added
    case removed
    case modified
}

/// A single difference between two CDA documents
public struct CDADifference: Sendable, Codable, Equatable {
    /// Path describing where the difference occurs (e.g., "header.title")
    public let path: String

    /// Type of change
    public let changeType: CDAChangeType

    /// Value from the original document
    public let oldValue: String?

    /// Value from the revised document
    public let newValue: String?

    public init(path: String, changeType: CDAChangeType, oldValue: String? = nil, newValue: String? = nil) {
        self.path = path
        self.changeType = changeType
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

/// Result of comparing two CDA documents
public struct CDAComparisonResult: Sendable, Codable, Equatable {
    /// All differences found
    public let differences: [CDADifference]

    public init(differences: [CDADifference]) {
        self.differences = differences
    }

    /// Whether the two documents are structurally identical
    public var areIdentical: Bool {
        differences.isEmpty
    }

    /// Returns differences filtered by change type
    public func differences(ofType type: CDAChangeType) -> [CDADifference] {
        differences.filter { $0.changeType == type }
    }

    /// Returns differences in the header (paths starting with "header.")
    public var headerDifferences: [CDADifference] {
        differences.filter { $0.path.hasPrefix("header.") }
    }

    /// Returns differences in the body (paths starting with "body")
    public var bodyDifferences: [CDADifference] {
        differences.filter { $0.path == "body" || $0.path.hasPrefix("body.") }
    }
}

/// Compares two CDA documents for structural differences
public struct CDADocumentComparator: Sendable {
    private let renderer: CDADocumentRenderer

    public init() {
        self.renderer = CDADocumentRenderer()
    }

    /// Compares two ClinicalDocuments and returns the differences
    public func compare(original: ClinicalDocument, revised: ClinicalDocument) -> CDAComparisonResult {
        var diffs: [CDADifference] = []

        diffs += compareHeaders(original: original, revised: revised)
        diffs += compareBodies(original: original.component.body, revised: revised.component.body)

        return CDAComparisonResult(differences: diffs)
    }

    // MARK: - Header Comparison

    private func compareHeaders(original: ClinicalDocument, revised: ClinicalDocument) -> [CDADifference] {
        var diffs: [CDADifference] = []

        // Compare ID
        if original.id != revised.id {
            diffs.append(CDADifference(
                path: "header.id",
                changeType: .modified,
                oldValue: renderer.formatIdentifier(original.id),
                newValue: renderer.formatIdentifier(revised.id)
            ))
        }

        // Compare code
        if original.code != revised.code {
            diffs.append(CDADifference(
                path: "header.code",
                changeType: .modified,
                oldValue: original.code.displayName ?? original.code.code,
                newValue: revised.code.displayName ?? revised.code.code
            ))
        }

        // Compare title
        if original.title != revised.title {
            diffs.append(CDADifference(
                path: "header.title",
                changeType: .modified,
                oldValue: original.title?.stringValue,
                newValue: revised.title?.stringValue
            ))
        }

        // Compare effectiveTime
        if original.effectiveTime != revised.effectiveTime {
            diffs.append(CDADifference(
                path: "header.effectiveTime",
                changeType: .modified,
                oldValue: renderer.formatTimestamp(original.effectiveTime),
                newValue: renderer.formatTimestamp(revised.effectiveTime)
            ))
        }

        // Compare confidentialityCode
        if original.confidentialityCode != revised.confidentialityCode {
            diffs.append(CDADifference(
                path: "header.confidentialityCode",
                changeType: .modified,
                oldValue: original.confidentialityCode.displayName ?? original.confidentialityCode.code,
                newValue: revised.confidentialityCode.displayName ?? revised.confidentialityCode.code
            ))
        }

        // Compare languageCode
        if original.languageCode != revised.languageCode {
            diffs.append(CDADifference(
                path: "header.languageCode",
                changeType: .modified,
                oldValue: original.languageCode?.code,
                newValue: revised.languageCode?.code
            ))
        }

        // Compare versionNumber
        if original.versionNumber != revised.versionNumber {
            diffs.append(CDADifference(
                path: "header.versionNumber",
                changeType: .modified,
                oldValue: original.versionNumber?.intValue.map { "\($0)" },
                newValue: revised.versionNumber?.intValue.map { "\($0)" }
            ))
        }

        // Compare recordTarget count
        if original.recordTarget.count != revised.recordTarget.count {
            diffs.append(CDADifference(
                path: "header.recordTarget",
                changeType: .modified,
                oldValue: "\(original.recordTarget.count) record target(s)",
                newValue: "\(revised.recordTarget.count) record target(s)"
            ))
        }

        // Compare author count
        if original.author.count != revised.author.count {
            diffs.append(CDADifference(
                path: "header.author",
                changeType: .modified,
                oldValue: "\(original.author.count) author(s)",
                newValue: "\(revised.author.count) author(s)"
            ))
        }

        // Compare custodian
        if original.custodian != revised.custodian {
            diffs.append(CDADifference(
                path: "header.custodian",
                changeType: .modified,
                oldValue: original.custodian.assignedCustodian.representedCustodianOrganization.name.map { renderer.formatEntityName($0) },
                newValue: revised.custodian.assignedCustodian.representedCustodianOrganization.name.map { renderer.formatEntityName($0) }
            ))
        }

        return diffs
    }

    // MARK: - Body Comparison

    private func compareBodies(original: DocumentBody, revised: DocumentBody) -> [CDADifference] {
        switch (original, revised) {
        case (.structured(let origBody), .structured(let revBody)):
            return compareStructuredBodies(original: origBody, revised: revBody)

        case (.nonXML, .nonXML):
            if original != revised {
                return [CDADifference(path: "body.nonXML", changeType: .modified, oldValue: "non-XML body", newValue: "non-XML body")]
            }
            return []

        default:
            return [CDADifference(path: "body", changeType: .modified, oldValue: "body type changed", newValue: nil)]
        }
    }

    private func compareStructuredBodies(original: StructuredBody, revised: StructuredBody) -> [CDADifference] {
        var diffs: [CDADifference] = []

        let origSections = original.component
        let revSections = revised.component

        let maxCount = max(origSections.count, revSections.count)

        for i in 0..<maxCount {
            let path = "body.section[\(i)]"

            if i >= origSections.count {
                let title = revSections[i].section.title?.stringValue ?? revSections[i].section.code?.displayName ?? "Section \(i)"
                diffs.append(CDADifference(path: path, changeType: .added, newValue: title))
            } else if i >= revSections.count {
                let title = origSections[i].section.title?.stringValue ?? origSections[i].section.code?.displayName ?? "Section \(i)"
                diffs.append(CDADifference(path: path, changeType: .removed, oldValue: title))
            } else {
                diffs += compareSections(original: origSections[i].section, revised: revSections[i].section, path: path)
            }
        }

        return diffs
    }

    private func compareSections(original: Section, revised: Section, path: String) -> [CDADifference] {
        var diffs: [CDADifference] = []

        // Compare title
        if original.title != revised.title {
            diffs.append(CDADifference(
                path: "\(path).title",
                changeType: .modified,
                oldValue: original.title?.stringValue,
                newValue: revised.title?.stringValue
            ))
        }

        // Compare code
        if original.code != revised.code {
            diffs.append(CDADifference(
                path: "\(path).code",
                changeType: .modified,
                oldValue: original.code?.displayName ?? original.code?.code,
                newValue: revised.code?.displayName ?? revised.code?.code
            ))
        }

        // Compare narrative text
        if original.text != revised.text {
            diffs.append(CDADifference(
                path: "\(path).text",
                changeType: .modified,
                oldValue: "narrative text",
                newValue: "narrative text"
            ))
        }

        // Compare entries
        let origEntryCount = original.entry?.count ?? 0
        let revEntryCount = revised.entry?.count ?? 0
        if origEntryCount != revEntryCount {
            diffs.append(CDADifference(
                path: "\(path).entries",
                changeType: .modified,
                oldValue: "\(origEntryCount) entry(ies)",
                newValue: "\(revEntryCount) entry(ies)"
            ))
        } else if original.entry != revised.entry {
            diffs.append(CDADifference(
                path: "\(path).entries",
                changeType: .modified,
                oldValue: "entries content",
                newValue: "entries content"
            ))
        }

        // Compare subsections
        let origSubCount = original.component?.count ?? 0
        let revSubCount = revised.component?.count ?? 0
        if origSubCount != revSubCount {
            diffs.append(CDADifference(
                path: "\(path).component",
                changeType: .modified,
                oldValue: "\(origSubCount) subsection(s)",
                newValue: "\(revSubCount) subsection(s)"
            ))
        }

        return diffs
    }
}

// MARK: - CDA Document Merger

/// Strategy for resolving merge conflicts between CDA documents
public enum CDAMergeConflictStrategy: String, Sendable, Codable, Equatable {
    /// Keep the primary document's content
    case keepPrimary

    /// Keep the secondary document's content
    case keepSecondary

    /// Include content from both documents
    case includeBoth
}

/// Configuration for CDA document merging
public struct CDAMergeConfiguration: Sendable, Codable, Equatable {
    /// Strategy for handling conflicts
    public let conflictStrategy: CDAMergeConflictStrategy

    /// Whether to merge entries from matching sections
    public let mergeEntries: Bool

    /// Whether to deduplicate entries when merging
    public let deduplicateEntries: Bool

    public init(
        conflictStrategy: CDAMergeConflictStrategy = .keepPrimary,
        mergeEntries: Bool = true,
        deduplicateEntries: Bool = true
    ) {
        self.conflictStrategy = conflictStrategy
        self.mergeEntries = mergeEntries
        self.deduplicateEntries = deduplicateEntries
    }

    /// Default merge configuration
    public static let `default` = CDAMergeConfiguration()
}

/// Merges sections from two CDA documents
public struct CDADocumentMerger: Sendable {
    /// Merge configuration
    public let configuration: CDAMergeConfiguration

    public init(configuration: CDAMergeConfiguration = .default) {
        self.configuration = configuration
    }

    /// Merges sections from a secondary document into the primary document
    ///
    /// The primary document's header is preserved. Sections from the secondary
    /// document are merged based on section code matching.
    public func mergeSections(primary: ClinicalDocument, secondary: ClinicalDocument) -> ClinicalDocument {
        let mergedBody: DocumentBody

        switch (primary.component.body, secondary.component.body) {
        case (.structured(let primaryBody), .structured(let secondaryBody)):
            let mergedComponents = mergeSectionComponents(
                primary: primaryBody.component,
                secondary: secondaryBody.component
            )
            let structuredBody = StructuredBody(
                confidentialityCode: primaryBody.confidentialityCode,
                languageCode: primaryBody.languageCode,
                component: mergedComponents
            )
            mergedBody = .structured(structuredBody)

        default:
            // For non-structured bodies, keep primary
            mergedBody = primary.component.body
        }

        return ClinicalDocument(
            realmCode: primary.realmCode,
            typeId: primary.typeId,
            templateId: primary.templateId,
            id: primary.id,
            code: primary.code,
            title: primary.title,
            effectiveTime: primary.effectiveTime,
            confidentialityCode: primary.confidentialityCode,
            languageCode: primary.languageCode,
            setId: primary.setId,
            versionNumber: primary.versionNumber,
            copyTime: primary.copyTime,
            recordTarget: primary.recordTarget,
            author: primary.author,
            dataEnterer: primary.dataEnterer,
            informant: primary.informant,
            custodian: primary.custodian,
            informationRecipient: primary.informationRecipient,
            legalAuthenticator: primary.legalAuthenticator,
            authenticator: primary.authenticator,
            relatedDocument: primary.relatedDocument,
            authorization: primary.authorization,
            component: DocumentComponent(body: mergedBody)
        )
    }

    // MARK: - Private Merge Helpers

    private func mergeSectionComponents(primary: [BodyComponent], secondary: [BodyComponent]) -> [BodyComponent] {
        var result = primary
        var matchedIndices = Set<Int>()

        for secComp in secondary {
            if let matchIndex = primary.firstIndex(where: { sectionCodesMatch($0.section, secComp.section) }) {
                matchedIndices.insert(matchIndex)
                let merged = mergeSections(primary: primary[matchIndex].section, secondary: secComp.section)
                result[matchIndex] = BodyComponent(section: merged)
            } else {
                // Section only in secondary
                switch configuration.conflictStrategy {
                case .keepPrimary:
                    break
                case .keepSecondary, .includeBoth:
                    result.append(secComp)
                }
            }
        }

        return result
    }

    private func sectionCodesMatch(_ a: Section, _ b: Section) -> Bool {
        // Match by code if available
        if let aCode = a.code?.code, let bCode = b.code?.code {
            return aCode == bCode
        }
        // Fall back to title matching
        if let aTitle = a.title?.stringValue, let bTitle = b.title?.stringValue {
            return aTitle == bTitle
        }
        return false
    }

    private func mergeSections(primary: Section, secondary: Section) -> Section {
        let mergedEntries: [Entry]?

        if configuration.mergeEntries {
            let primaryEntries = primary.entry ?? []
            let secondaryEntries = secondary.entry ?? []
            var combined = primaryEntries

            switch configuration.conflictStrategy {
            case .keepPrimary:
                // Only add entries from secondary that don't exist in primary
                for entry in secondaryEntries {
                    if !primaryEntries.contains(entry) {
                        combined.append(entry)
                    }
                }
            case .keepSecondary:
                combined = secondaryEntries
            case .includeBoth:
                combined += secondaryEntries
            }

            if configuration.deduplicateEntries {
                combined = deduplicateEntries(combined)
            }

            mergedEntries = combined.isEmpty ? nil : combined
        } else {
            mergedEntries = primary.entry
        }

        // Merge subsections
        let mergedComponents: [SectionComponent]?
        if let primaryComps = primary.component, let secondaryComps = secondary.component {
            var merged = primaryComps
            for secComp in secondaryComps {
                if !primaryComps.contains(where: { sectionCodesMatch($0.section, secComp.section) }) {
                    merged.append(secComp)
                }
            }
            mergedComponents = merged
        } else {
            mergedComponents = primary.component ?? secondary.component
        }

        return Section(
            ID: primary.ID,
            templateId: primary.templateId,
            id: primary.id,
            code: primary.code,
            title: primary.title,
            text: primary.text,
            confidentialityCode: primary.confidentialityCode,
            languageCode: primary.languageCode,
            subject: primary.subject,
            author: primary.author,
            informant: primary.informant,
            entry: mergedEntries,
            component: mergedComponents
        )
    }

    private func deduplicateEntries(_ entries: [Entry]) -> [Entry] {
        var unique: [Entry] = []
        for entry in entries {
            if !unique.contains(entry) {
                unique.append(entry)
            }
        }
        return unique
    }
}

// MARK: - CDA Document Version Manager

/// Represents a versioned CDA document
public struct CDADocumentVersion: Sendable, Codable, Equatable {
    /// The document
    public let document: ClinicalDocument

    /// Version number
    public let versionNumber: Int?

    /// Set identifier for the document set
    public let setId: II?

    /// When this version became effective
    public let effectiveTime: TS

    public init(document: ClinicalDocument, versionNumber: Int?, setId: II?, effectiveTime: TS) {
        self.document = document
        self.versionNumber = versionNumber
        self.setId = setId
        self.effectiveTime = effectiveTime
    }
}

/// Type of relationship between document versions
public enum CDADocumentRelationshipType: String, Sendable, Codable, Equatable {
    /// Replace - new document replaces the old one
    case replace = "RPLC"

    /// Append - new document appends to the old one
    case append = "APND"

    /// Transform - new document is a transformation of the old one
    case transform = "XFRM"
}

/// Manages versioning of CDA documents
public struct CDADocumentVersionManager: Sendable {
    public init() {}

    /// Creates a new version of a document with a relationship to the original
    public func createNewVersion(
        of original: ClinicalDocument,
        newId: II,
        newEffectiveTime: TS,
        relationshipType: CDADocumentRelationshipType = .replace,
        body: DocumentBody? = nil
    ) -> ClinicalDocument {
        let currentVersion = original.versionNumber?.intValue ?? 1
        let newVersionNumber: INT = .value(currentVersion + 1)
        let setId = original.setId ?? original.id

        let relatedDoc = RelatedDocument(
            typeCode: relationshipType.rawValue,
            parentDocument: ParentDocument(
                id: [original.id],
                code: original.code,
                setId: original.setId,
                versionNumber: original.versionNumber
            )
        )

        var relatedDocs = original.relatedDocument ?? []
        relatedDocs.append(relatedDoc)

        return ClinicalDocument(
            realmCode: original.realmCode,
            typeId: original.typeId,
            templateId: original.templateId,
            id: newId,
            code: original.code,
            title: original.title,
            effectiveTime: newEffectiveTime,
            confidentialityCode: original.confidentialityCode,
            languageCode: original.languageCode,
            setId: setId,
            versionNumber: newVersionNumber,
            copyTime: original.copyTime,
            recordTarget: original.recordTarget,
            author: original.author,
            dataEnterer: original.dataEnterer,
            informant: original.informant,
            custodian: original.custodian,
            informationRecipient: original.informationRecipient,
            legalAuthenticator: original.legalAuthenticator,
            authenticator: original.authenticator,
            relatedDocument: relatedDocs,
            authorization: original.authorization,
            component: DocumentComponent(body: body ?? original.component.body)
        )
    }

    /// Extracts version information from a document
    public func extractVersionInfo(_ document: ClinicalDocument) -> CDADocumentVersion {
        CDADocumentVersion(
            document: document,
            versionNumber: document.versionNumber?.intValue,
            setId: document.setId,
            effectiveTime: document.effectiveTime
        )
    }

    /// Determines if one document is a successor of another based on version info
    public func isSuccessor(_ candidate: ClinicalDocument, of original: ClinicalDocument) -> Bool {
        // Check if candidate has a relatedDocument pointing to original
        if let relatedDocs = candidate.relatedDocument {
            for relDoc in relatedDocs {
                if relDoc.parentDocument.id.contains(original.id) {
                    return true
                }
            }
        }

        // Check setId and version number
        if let candidateSetId = candidate.setId,
           let originalSetId = original.setId,
           candidateSetId == originalSetId {
            if let candidateVersion = candidate.versionNumber?.intValue,
               let originalVersion = original.versionNumber?.intValue {
                return candidateVersion > originalVersion
            }
        }

        return false
    }

    /// Sorts documents by version number within their document sets
    public func sortByVersion(_ documents: [ClinicalDocument]) -> [ClinicalDocument] {
        documents.sorted { a, b in
            let aVersion = a.versionNumber?.intValue ?? 0
            let bVersion = b.versionNumber?.intValue ?? 0
            return aVersion < bVersion
        }
    }

    /// Groups documents by their document set identifier
    public func groupByDocumentSet(_ documents: [ClinicalDocument]) -> [String: [ClinicalDocument]] {
        var groups: [String: [ClinicalDocument]] = [:]

        for doc in documents {
            let key = doc.setId?.root ?? doc.id.root
            groups[key, default: []].append(doc)
        }

        // Sort each group by version
        for key in groups.keys {
            groups[key] = sortByVersion(groups[key]!)
        }

        return groups
    }
}

// MARK: - ClinicalDocument Convenience Extensions

public extension ClinicalDocument {
    /// Renders this document to plain text
    func renderToText(configuration: CDARenderingConfiguration = .default) -> String {
        let renderer = CDADocumentRenderer(configuration: configuration)
        return renderer.renderToText(self)
    }

    /// Renders this document to HTML
    func renderToHTML(configuration: CDARenderingConfiguration = .default) -> String {
        let renderer = CDADocumentRenderer(configuration: configuration)
        return renderer.renderToHTML(self)
    }

    /// Compares this document with another
    func compare(with other: ClinicalDocument) -> CDAComparisonResult {
        let comparator = CDADocumentComparator()
        return comparator.compare(original: self, revised: other)
    }
}
