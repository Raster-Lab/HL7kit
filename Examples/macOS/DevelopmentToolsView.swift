/// DevelopmentToolsView.swift
/// Development and debugging tools for HL7 message analysis.
///
/// Provides a message inspector with tree view, encoding character
/// analyzer, escape sequence decoder, message template generator,
/// and connection diagnostics panel.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit
import FHIRkit
import HL7v3Kit

// MARK: - Development Tools View

/// A tabbed panel exposing HL7-specific development and debugging
/// utilities for message authoring and troubleshooting.
@MainActor
struct DevelopmentToolsView: View {
    @Environment(WorkstationState.self) private var appState

    @State private var selectedTool: DevTool = .inspector

    var body: some View {
        VStack(spacing: 0) {
            toolPicker

            Divider()

            switch selectedTool {
            case .inspector:        MessageInspectorPanel()
            case .encodingAnalyzer: EncodingAnalyzerPanel()
            case .escapeDecoder:    EscapeDecoderPanel()
            case .templateGenerator: TemplateGeneratorPanel()
            case .diagnostics:      DiagnosticsPanel()
            }
        }
        .navigationTitle("Development Tools")
    }

    /// Segmented picker for switching between developer tools.
    private var toolPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DevTool.allCases) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Label(tool.label, systemImage: tool.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

/// Available developer tools in the panel.
enum DevTool: String, CaseIterable, Identifiable, Sendable {
    case inspector        = "Inspector"
    case encodingAnalyzer = "Encoding"
    case escapeDecoder    = "Escapes"
    case templateGenerator = "Templates"
    case diagnostics      = "Diagnostics"

    var id: String { rawValue }

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .inspector:         return "filemenu.and.cursorarrow"
        case .encodingAnalyzer:  return "textformat.abc"
        case .escapeDecoder:     return "character.textbox"
        case .templateGenerator: return "doc.badge.gearshape"
        case .diagnostics:       return "stethoscope"
        }
    }
}

// MARK: - Message Inspector Panel

/// Tree-based message inspector showing hierarchical segment → field →
/// component → subcomponent structure.
@MainActor
struct MessageInspectorPanel: View {
    @Environment(WorkstationState.self) private var appState

    @State private var expandedNodes: Set<String> = []
    @State private var selectedNodePath: String?

    var body: some View {
        HSplitView {
            treeView
                .frame(minWidth: 300)
            detailPane
                .frame(minWidth: 300)
        }
    }

    /// Left side: hierarchical tree of message components.
    private var treeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Message Tree", systemImage: "list.bullet.indent")
                    .font(.headline)
                Spacer()
                Button("Expand All") {
                    expandAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Collapse All") {
                    expandedNodes.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let msg = appState.parsedMessage {
                List {
                    ForEach(Array(msg.allSegments.enumerated()), id: \.offset) { segIdx, segment in
                        let segPath = "seg-\(segIdx)"
                        DisclosureGroup(
                            isExpanded: binding(for: segPath)
                        ) {
                            fieldNodes(segment: segment, segmentIndex: segIdx)
                        } label: {
                            treeNodeLabel(
                                path: segPath,
                                icon: "rectangle.3.group",
                                title: segment.segmentID,
                                subtitle: "\(segment.fields.count) fields",
                                color: .blue
                            )
                        }
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
            } else {
                ContentUnavailableView(
                    "No Message Loaded",
                    systemImage: "doc.text",
                    description: Text("Parse a message in the Message Processing tab first.")
                )
            }
        }
    }

    /// Field-level tree nodes within a segment.
    private func fieldNodes(segment: BaseSegment, segmentIndex: Int) -> some View {
        ForEach(Array(segment.fields.enumerated()), id: \.offset) { fieldIdx, field in
            let fieldPath = "seg-\(segmentIndex).field-\(fieldIdx)"
            let value = field.serialize()
            let components = value.split(separator: "^")

            if components.count > 1 {
                DisclosureGroup(isExpanded: binding(for: fieldPath)) {
                    componentNodes(components: components, fieldPath: fieldPath)
                } label: {
                    treeNodeLabel(
                        path: fieldPath,
                        icon: "text.line.first.and.arrowtriangle.forward",
                        title: "\(segment.segmentID)-\(fieldIdx)",
                        subtitle: value.prefix(60) + (value.count > 60 ? "…" : ""),
                        color: .orange
                    )
                }
            } else if !value.isEmpty {
                treeNodeLabel(
                    path: fieldPath,
                    icon: "text.cursor",
                    title: "\(segment.segmentID)-\(fieldIdx)",
                    subtitle: value,
                    color: .green
                )
                .onTapGesture { selectedNodePath = fieldPath }
            }
        }
    }

    /// Component-level tree nodes within a field.
    private func componentNodes(components: [Substring], fieldPath: String) -> some View {
        ForEach(Array(components.enumerated()), id: \.offset) { compIdx, component in
            let compPath = "\(fieldPath).comp-\(compIdx)"
            treeNodeLabel(
                path: compPath,
                icon: "character.textbox",
                title: "Component \(compIdx + 1)",
                subtitle: String(component),
                color: .purple
            )
            .onTapGesture { selectedNodePath = compPath }
        }
    }

    /// Styled label for a tree node with icon, title, subtitle, and color.
    private func treeNodeLabel(
        path: String,
        icon: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12, design: .monospaced).bold())
                .foregroundStyle(selectedNodePath == path ? .white : .primary)

            Text(subtitle)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(selectedNodePath == path ? .white.opacity(0.8) : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(selectedNodePath == path ? color.opacity(0.6) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Right side: detail pane for the selected node.
    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Inspector Detail", systemImage: "info.circle")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            if let path = selectedNodePath {
                inspectorDetail(for: path)
            } else {
                ContentUnavailableView(
                    "Select a Node",
                    systemImage: "cursorarrow.click",
                    description: Text("Click a node in the tree to inspect its details.")
                )
            }
        }
    }

    /// Displays metadata for the selected tree node path.
    private func inspectorDetail(for path: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                WorkstationDetailRow(label: "Path", value: path)
                WorkstationDetailRow(label: "Depth", value: "\(path.split(separator: ".").count)")
                WorkstationDetailRow(label: "Type", value: nodeType(for: path))

                Divider()

                Text("Raw Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(resolveNodeValue(path))
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Divider()

                Text("Hex Dump")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hexDump(resolveNodeValue(path)))
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()
        }
    }

    // MARK: - Helpers

    /// Creates a binding for tracking expansion state of a tree node.
    private func binding(for path: String) -> Binding<Bool> {
        Binding(
            get: { expandedNodes.contains(path) },
            set: { expanded in
                if expanded { expandedNodes.insert(path) }
                else { expandedNodes.remove(path) }
            }
        )
    }

    /// Expands all segment-level nodes.
    private func expandAll() {
        guard let msg = appState.parsedMessage else { return }
        for i in 0..<msg.allSegments.count {
            expandedNodes.insert("seg-\(i)")
        }
    }

    /// Returns a human-readable type name for a tree path.
    private func nodeType(for path: String) -> String {
        if path.contains("comp") { return "Component" }
        if path.contains("field") { return "Field" }
        return "Segment"
    }

    /// Resolves the raw value for a given tree node path.
    private func resolveNodeValue(_ path: String) -> String {
        guard let msg = appState.parsedMessage else { return "" }
        let parts = path.split(separator: ".")
        guard let segPart = parts.first,
              let segIdx = Int(segPart.replacingOccurrences(of: "seg-", with: "")),
              segIdx < msg.allSegments.count else { return "" }

        let segment = msg.allSegments[segIdx]
        guard parts.count > 1,
              let fieldIdx = Int(parts[1].replacingOccurrences(of: "field-", with: "")),
              fieldIdx < segment.fields.count else {
            return segment.fields.map { $0.serialize() }.joined(separator: "|")
        }

        let fieldValue = segment.fields[fieldIdx].serialize()

        if parts.count > 2,
           let compIdx = Int(parts[2].replacingOccurrences(of: "comp-", with: "")) {
            let components = fieldValue.split(separator: "^")
            return compIdx < components.count ? String(components[compIdx]) : ""
        }

        return fieldValue
    }

    /// Produces a hex dump of the given string for debugging.
    private func hexDump(_ text: String) -> String {
        text.utf8.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Encoding Analyzer Panel

/// Analyzes and displays the HL7 encoding characters from the MSH segment.
@MainActor
struct EncodingAnalyzerPanel: View {
    @Environment(WorkstationState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Encoding Characters", systemImage: "textformat.abc")
                            .font(.headline)

                        Text("HL7 v2.x uses five special encoding characters defined in MSH-1 and MSH-2 to delimit message components.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        let chars = parseEncodingCharacters()
                        encodingRow(name: "Field Separator", char: chars.field, standard: "|", position: "MSH-1")
                        encodingRow(name: "Component Separator", char: chars.component, standard: "^", position: "MSH-2.1")
                        encodingRow(name: "Repetition Separator", char: chars.repetition, standard: "~", position: "MSH-2.2")
                        encodingRow(name: "Escape Character", char: chars.escape, standard: "\\", position: "MSH-2.3")
                        encodingRow(name: "Subcomponent Separator", char: chars.subcomponent, standard: "&", position: "MSH-2.4")
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Character Map", systemImage: "character.textbox")
                            .font(.headline)

                        Text("Byte values of the current message's encoding characters:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        let chars = parseEncodingCharacters()
                        let allChars = [chars.field, chars.component, chars.repetition, chars.escape, chars.subcomponent]
                        HStack(spacing: 16) {
                            ForEach(Array(allChars.enumerated()), id: \.offset) { _, char in
                                VStack(spacing: 4) {
                                    Text(char)
                                        .font(.system(size: 24, design: .monospaced).bold())
                                    Text("0x" + char.utf8.map { String(format: "%02X", $0) }.joined())
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 60)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    /// Displays a single encoding character row with name, value, and standard.
    private func encodingRow(name: String, char: String, standard: String, position: String) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.subheadline)
                .frame(width: 180, alignment: .leading)

            Text(char)
                .font(.system(size: 16, design: .monospaced).bold())
                .frame(width: 30)
                .padding(4)
                .background(char == standard ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(char == standard ? "Standard" : "Custom")
                .font(.caption)
                .foregroundStyle(char == standard ? .green : .orange)

            Text(position)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    /// Extracts encoding characters from the current parsed message or returns defaults.
    private func parseEncodingCharacters() -> (field: String, component: String, repetition: String, escape: String, subcomponent: String) {
        let text = appState.rawMessageText
        guard text.hasPrefix("MSH"), text.count >= 8 else {
            return ("|", "^", "~", "\\", "&")
        }
        let idx = text.index(text.startIndex, offsetBy: 3)
        let fieldSep = String(text[idx])
        let encStart = text.index(after: idx)
        let encChars = String(text[encStart...].prefix(4))
        return (
            fieldSep,
            encChars.count > 0 ? String(encChars[encChars.startIndex]) : "^",
            encChars.count > 1 ? String(encChars[encChars.index(encChars.startIndex, offsetBy: 1)]) : "~",
            encChars.count > 2 ? String(encChars[encChars.index(encChars.startIndex, offsetBy: 2)]) : "\\",
            encChars.count > 3 ? String(encChars[encChars.index(encChars.startIndex, offsetBy: 3)]) : "&"
        )
    }
}

// MARK: - Escape Sequence Decoder Panel

/// Decodes HL7 v2.x escape sequences and shows their plain-text equivalents.
@MainActor
struct EscapeDecoderPanel: View {
    @State private var inputText: String = "Smith\\T\\Jones \\S\\ER\\R\\Labs"
    @State private var decodedResult: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Escape Sequence Decoder", systemImage: "character.textbox")
                            .font(.headline)

                        Text("Enter HL7 text containing escape sequences to see the decoded output.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("Text with escape sequences", text: $inputText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))

                        Button("Decode") {
                            decodeEscapes()
                        }
                        .buttonStyle(.borderedProminent)

                        if !decodedResult.isEmpty {
                            WorkstationDetailRow(label: "Decoded", value: decodedResult)
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Reference: Standard Escape Sequences", systemImage: "book")
                            .font(.headline)

                        escapeReferenceRow(sequence: "\\F\\", meaning: "Field separator (|)", example: "Lab\\F\\Test → Lab|Test")
                        escapeReferenceRow(sequence: "\\S\\", meaning: "Component separator (^)", example: "A\\S\\B → A^B")
                        escapeReferenceRow(sequence: "\\T\\", meaning: "Subcomponent separator (&)", example: "X\\T\\Y → X&Y")
                        escapeReferenceRow(sequence: "\\R\\", meaning: "Repetition separator (~)", example: "1\\R\\2 → 1~2")
                        escapeReferenceRow(sequence: "\\E\\", meaning: "Escape character (\\)", example: "A\\E\\B → A\\B")
                        escapeReferenceRow(sequence: "\\.br\\", meaning: "Line break", example: "Line1\\.br\\Line2")
                        escapeReferenceRow(sequence: "\\Xhh\\", meaning: "Hex character", example: "\\X41\\ → A")
                    }
                }
            }
            .padding()
        }
    }

    /// Displays a single escape sequence reference row.
    private func escapeReferenceRow(sequence: String, meaning: String, example: String) -> some View {
        HStack(spacing: 12) {
            Text(sequence)
                .font(.system(size: 12, design: .monospaced).bold())
                .frame(width: 60, alignment: .leading)
                .foregroundStyle(.blue)

            Text(meaning)
                .font(.subheadline)
                .frame(width: 200, alignment: .leading)

            Text(example)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Decodes standard HL7 escape sequences in the input text.
    private func decodeEscapes() {
        decodedResult = inputText
            .replacingOccurrences(of: "\\F\\", with: "|")
            .replacingOccurrences(of: "\\S\\", with: "^")
            .replacingOccurrences(of: "\\T\\", with: "&")
            .replacingOccurrences(of: "\\R\\", with: "~")
            .replacingOccurrences(of: "\\E\\", with: "\\")
            .replacingOccurrences(of: "\\.br\\", with: "\n")
    }
}

// MARK: - Template Generator Panel

/// Generates HL7 v2.x message templates for common message types.
@MainActor
struct TemplateGeneratorPanel: View {
    @Environment(WorkstationState.self) private var appState

    @State private var selectedTemplate: TemplateType = .adtA01
    @State private var generatedMessage: String = ""
    @State private var patientName: String = "Doe^John^A"
    @State private var patientID: String = "12345"
    @State private var sendingApp: String = "MY_APP"
    @State private var sendingFacility: String = "MY_HOSP"

    var body: some View {
        HSplitView {
            configurationPane
                .frame(minWidth: 280)
            previewPane
                .frame(minWidth: 400)
        }
    }

    /// Left side: template selection and field configuration.
    private var configurationPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Template", systemImage: "doc.badge.gearshape")
                            .font(.headline)

                        Picker("Message Type", selection: $selectedTemplate) {
                            ForEach(TemplateType.allCases) { template in
                                Text(template.label).tag(template)
                            }
                        }

                        TextField("Sending Application", text: $sendingApp)
                            .textFieldStyle(.roundedBorder)
                        TextField("Sending Facility", text: $sendingFacility)
                            .textFieldStyle(.roundedBorder)
                        TextField("Patient Name (Last^First^Middle)", text: $patientName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Patient ID", text: $patientID)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                HStack {
                    Button("Generate") {
                        generatedMessage = generateTemplate()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Use in Editor") {
                        appState.rawMessageText = generatedMessage
                        appState.parseCurrentMessage()
                    }
                    .buttonStyle(.bordered)
                    .disabled(generatedMessage.isEmpty)
                }
            }
            .padding()
        }
    }

    /// Right side: preview of the generated message.
    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Generated Message", systemImage: "doc.text")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            if generatedMessage.isEmpty {
                ContentUnavailableView(
                    "No Template Generated",
                    systemImage: "doc.badge.gearshape",
                    description: Text("Configure the template and click Generate.")
                )
            } else {
                ScrollView {
                    Text(generatedMessage.replacingOccurrences(of: "\r", with: "\n"))
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Generates an HL7 v2.x message from the selected template and parameters.
    private func generateTemplate() -> String {
        let timestamp = formattedTimestamp()
        let controlID = "MSG\(Int.random(in: 10000...99999))"

        switch selectedTemplate {
        case .adtA01:
            return [
                "MSH|^~\\&|\(sendingApp)|\(sendingFacility)|RCV|FAC|\(timestamp)||ADT^A01^ADT_A01|\(controlID)|P|2.5.1",
                "EVN|A01|\(timestamp)",
                "PID|1||\(patientID)^^^HOSP^MR||\(patientName)||19800101|M|||123 Main St^^City^ST^12345||555-555-0100",
                "PV1|1|I|MED^201^A|E|||0001^Attending^Doctor^^^Dr|||MED|||||||0001^Attending^Doctor^^^Dr|IN||||||||||||||||||||||\(timestamp)",
            ].joined(separator: "\r")

        case .oruR01:
            return [
                "MSH|^~\\&|\(sendingApp)|\(sendingFacility)|RCV|FAC|\(timestamp)||ORU^R01^ORU_R01|\(controlID)|P|2.5.1",
                "PID|1||\(patientID)^^^HOSP^MR||\(patientName)||19800101|M",
                "OBR|1|ORD001|LAB001|CBC^Complete Blood Count^LN|||\(timestamp)",
                "OBX|1|NM|WBC^White Blood Cell Count^LN||7.5|10*3/uL|4.5-11.0|N|||F",
            ].joined(separator: "\r")

        case .ormO01:
            return [
                "MSH|^~\\&|\(sendingApp)|\(sendingFacility)|RCV|FAC|\(timestamp)||ORM^O01^ORM_O01|\(controlID)|P|2.5.1",
                "PID|1||\(patientID)^^^HOSP^MR||\(patientName)||19800101|M",
                "ORC|NW|ORD001|||||||\(timestamp)|||0001^Ordering^Doctor^^^Dr",
                "OBR|1|ORD001||BMP^Basic Metabolic Panel^LN|||\(timestamp)||||||||0001^Ordering^Doctor^^^Dr",
            ].joined(separator: "\r")

        case .ackGeneric:
            return [
                "MSH|^~\\&|\(sendingApp)|\(sendingFacility)|RCV|FAC|\(timestamp)||ACK^A01^ACK|\(controlID)|P|2.5.1",
                "MSA|AA|\(controlID)|Message accepted",
            ].joined(separator: "\r")
        }
    }

    /// Returns the current date/time in HL7 timestamp format (yyyyMMddHHmmss).
    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: Date())
    }
}

/// Available message template types.
enum TemplateType: String, CaseIterable, Identifiable, Sendable {
    case adtA01    = "ADT^A01"
    case oruR01    = "ORU^R01"
    case ormO01    = "ORM^O01"
    case ackGeneric = "ACK"

    var id: String { rawValue }
    var label: String { rawValue }
}

// MARK: - Diagnostics Panel

/// Connection and network diagnostics for HL7 interface troubleshooting.
@MainActor
struct DiagnosticsPanel: View {
    @State private var hostname: String = "localhost"
    @State private var port: String = "2575"
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Network Diagnostics", systemImage: "stethoscope")
                            .font(.headline)

                        HStack(spacing: 12) {
                            TextField("Hostname", text: $hostname)
                                .textFieldStyle(.roundedBorder)
                            TextField("Port", text: $port)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Button("Run Diagnostics") {
                                Task { await runDiagnostics() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRunning)
                        }

                        if isRunning {
                            ProgressView("Running diagnostics…")
                        }
                    }
                }

                if !diagnosticResults.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Results", systemImage: "checklist")
                                .font(.headline)

                            ForEach(diagnosticResults) { result in
                                HStack(spacing: 8) {
                                    Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.passed ? .green : .red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.name)
                                            .font(.subheadline.bold())
                                        Text(result.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "%.0f ms", result.latencyMs))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                if result.id != diagnosticResults.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    /// Simulates network diagnostic checks against the configured host.
    private func runDiagnostics() async {
        isRunning = true
        diagnosticResults = []

        let checks: [(String, String)] = [
            ("DNS Resolution", "Resolve hostname to IP address"),
            ("TCP Port Reachability", "Verify port \(port) is open"),
            ("MLLP Handshake", "Send start byte and verify response"),
            ("TLS Capability", "Check if endpoint supports TLS"),
            ("Response Latency", "Measure round-trip time"),
        ]

        for (name, detail) in checks {
            try? await Task.sleep(for: .milliseconds(300))
            let latency = Double.random(in: 1...150)
            let passed = name != "TLS Capability"

            diagnosticResults.append(DiagnosticResult(
                name: name,
                detail: passed ? detail : "\(detail) – not supported",
                passed: passed,
                latencyMs: latency
            ))
        }

        isRunning = false
    }
}

/// A single diagnostic check result.
struct DiagnosticResult: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let detail: String
    let passed: Bool
    let latencyMs: Double
}
#endif
