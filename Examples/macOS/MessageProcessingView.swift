/// MessageProcessingView.swift
/// Interactive HL7 message processing workstation with split-pane editing,
/// segment inspection, message statistics, and diff comparison.
///
/// Provides a professional macOS split view where users edit raw HL7 text
/// on the left and inspect the parsed structure on the right.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit
import FHIRkit
import HL7v3Kit

// MARK: - Message Processing View

/// The primary message workstation view with a three-area layout:
/// source editor (left), parsed output (right), and statistics bar (bottom).
@MainActor
struct MessageProcessingView: View {
    @Environment(WorkstationState.self) private var appState

    @State private var selectedSegmentID: String?
    @State private var expandedSegments: Set<Int> = []
    @State private var selectedFormat: MessageFormat = .v2Pipe
    @State private var showDiffPanel = false
    @State private var diffMessageText: String = WorkstationSamples.oruR01
    @State private var diffResults: [DiffEntry] = []

    var body: some View {
        VSplitView {
            HSplitView {
                editorPane
                    .frame(minWidth: 350)
                parsedOutputPane
                    .frame(minWidth: 350)
            }
            .frame(minHeight: 350)

            if showDiffPanel {
                diffComparisonPane
                    .frame(minHeight: 200, idealHeight: 250)
            }

            statisticsBar
                .frame(height: 120)
        }
        .toolbar { toolbarContent }
        .navigationTitle("Message Processing")
        .onAppear { appState.parseCurrentMessage() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            formatPicker

            Button {
                appState.parseCurrentMessage()
            } label: {
                Label("Parse", systemImage: "play.fill")
            }
            .help("Parse the current message (⇧⌘P)")

            Button {
                showDiffPanel.toggle()
            } label: {
                Label("Diff", systemImage: "arrow.left.arrow.right")
            }
            .help("Toggle message diff comparison")

            Menu("Samples", systemImage: "doc.on.doc") {
                Button("ADT^A01 – Admit") {
                    appState.rawMessageText = WorkstationSamples.adtA01
                    appState.parseCurrentMessage()
                }
                Button("ORU^R01 – Lab Result") {
                    appState.rawMessageText = WorkstationSamples.oruR01
                    appState.parseCurrentMessage()
                }
                Button("ORM^O01 – Order") {
                    appState.rawMessageText = WorkstationSamples.ormO01
                    appState.parseCurrentMessage()
                }
                Divider()
                Button("Invalid (Error Demo)") {
                    appState.rawMessageText = WorkstationSamples.invalidMessage
                    appState.parseCurrentMessage()
                }
            }
        }
    }

    /// Picker for switching between HL7 format views.
    private var formatPicker: some View {
        Picker("Format", selection: $selectedFormat) {
            ForEach(MessageFormat.allCases) { fmt in
                Text(fmt.label).tag(fmt)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 260)
        .help("Switch display format")
    }

    // MARK: - Editor Pane

    /// Left pane: raw message text editor with monospaced font.
    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Source Editor", systemImage: "pencil.and.outline")
                    .font(.headline)
                Spacer()
                Text("\(appState.rawMessageText.count) chars")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            @Bindable var state = appState
            TextEditor(text: $state.rawMessageText)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.visible)
                .onChange(of: appState.rawMessageText) {
                    appState.parseCurrentMessage()
                }

            if let error = appState.parseErrorDescription {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.08))
            }
        }
        .background(.background)
    }

    // MARK: - Parsed Output Pane

    /// Right pane: interactive segment table with expandable field details.
    private var parsedOutputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Parsed Structure", systemImage: "list.bullet.indent")
                    .font(.headline)
                Spacer()
                if let msg = appState.parsedMessage {
                    WorkstationBadge(
                        text: msg.messageType(),
                        color: .blue
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if let msg = appState.parsedMessage {
                formatSpecificView(msg)
            } else {
                ContentUnavailableView(
                    "No Parsed Message",
                    systemImage: "doc.text",
                    description: Text("Enter a valid HL7 message in the source editor.")
                )
            }
        }
        .background(.background)
    }

    /// Renders the parsed message according to the currently selected format.
    @ViewBuilder
    private func formatSpecificView(_ message: HL7v2Message) -> some View {
        switch selectedFormat {
        case .v2Pipe:
            segmentTableView(message)
        case .v3XML:
            xmlPreview(message)
        case .fhirJSON:
            fhirJSONPreview(message)
        }
    }

    /// Segment table with expandable rows showing field-level detail.
    private func segmentTableView(_ message: HL7v2Message) -> some View {
        List {
            ForEach(Array(message.allSegments.enumerated()), id: \.offset) { index, segment in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSegments.contains(index) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedSegments.insert(index)
                            } else {
                                expandedSegments.remove(index)
                            }
                        }
                    )
                ) {
                    segmentFieldList(segment)
                } label: {
                    segmentHeader(segment, index: index)
                }
            }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
    }

    /// Header row for a segment with color-coded ID and field count.
    private func segmentHeader(_ segment: BaseSegment, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(segment.segmentID)
                .font(.headline.monospaced())
                .foregroundStyle(segmentColor(for: segment.segmentID))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(segmentColor(for: segment.segmentID).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text("Segment \(index)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(segment.fields.count) fields")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    /// Expanded view showing each field with its index and serialized value.
    private func segmentFieldList(_ segment: BaseSegment) -> some View {
        ForEach(Array(segment.fields.enumerated()), id: \.offset) { fieldIndex, field in
            let value = field.serialize()
            if !value.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(segment.segmentID)-\(fieldIndex)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)

                    Text(value)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(4)
                }
                .padding(.vertical, 2)
            }
        }
    }

    /// Renders a placeholder XML representation for HL7 v3.x format preview.
    private func xmlPreview(_ message: HL7v2Message) -> some View {
        ScrollView {
            let xml = generateXMLPreview(message)
            Text(xml)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Renders a placeholder FHIR JSON representation for preview.
    private func fhirJSONPreview(_ message: HL7v2Message) -> some View {
        ScrollView {
            let json = generateFHIRPreview(message)
            Text(json)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Diff Comparison Pane

    /// Bottom pane comparing two HL7 messages side-by-side.
    private var diffComparisonPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Message Diff", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                Spacer()
                Button("Compare") {
                    computeDiff()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comparison Message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    @Bindable var _ = appState
                    TextEditor(text: $diffMessageText)
                        .font(.system(size: 11, design: .monospaced))
                }
                .frame(minWidth: 300)

                diffResultsList
                    .frame(minWidth: 300)
            }
        }
        .background(.background)
    }

    /// Displays diff results as a list of added/removed/changed segments.
    private var diffResultsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Differences")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if diffResults.isEmpty {
                ContentUnavailableView(
                    "No Diff Results",
                    systemImage: "equal.circle",
                    description: Text("Click Compare to diff the two messages.")
                )
            } else {
                List(diffResults) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: entry.kind.icon)
                            .foregroundStyle(entry.kind.color)
                        Text(entry.description)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(2)
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Statistics Bar

    /// Bottom statistics bar showing message metrics at a glance.
    private var statisticsBar: some View {
        GroupBox {
            HStack(spacing: 24) {
                statisticItem(
                    title: "Segments",
                    value: "\(appState.parsedMessage?.segmentCount ?? 0)",
                    icon: "rectangle.split.3x1"
                )
                Divider()
                statisticItem(
                    title: "Total Fields",
                    value: "\(totalFieldCount)",
                    icon: "text.line.first.and.arrowtriangle.forward"
                )
                Divider()
                statisticItem(
                    title: "Message Size",
                    value: formattedSize,
                    icon: "internaldrive"
                )
                Divider()
                statisticItem(
                    title: "Message Type",
                    value: appState.parsedMessage?.messageType() ?? "—",
                    icon: "tag"
                )
                Divider()
                statisticItem(
                    title: "Version",
                    value: appState.parsedMessage?.version() ?? "—",
                    icon: "number"
                )
                Divider()
                statisticItem(
                    title: "Control ID",
                    value: appState.parsedMessage?.messageControlID() ?? "—",
                    icon: "barcode"
                )
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    /// A single statistic item with icon, label, and value.
    private func statisticItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 14, design: .monospaced).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Computed Helpers

    /// Total number of fields across all segments.
    private var totalFieldCount: Int {
        appState.parsedMessage?.allSegments
            .reduce(0) { $0 + $1.fields.count } ?? 0
    }

    /// Human-readable byte size of the raw message.
    private var formattedSize: String {
        let bytes = appState.rawMessageText.utf8.count
        if bytes < 1024 { return "\(bytes) B" }
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    }

    /// Returns a consistent color for known segment types.
    private func segmentColor(for id: String) -> Color {
        switch id {
        case "MSH": return .blue
        case "PID": return .green
        case "PV1": return .purple
        case "OBR": return .orange
        case "OBX": return .teal
        case "EVN": return .indigo
        case "ORC": return .mint
        case "NK1": return .pink
        default:    return .secondary
        }
    }

    /// Generates a simple XML preview string from a parsed v2.x message.
    private func generateXMLPreview(_ message: HL7v2Message) -> String {
        var lines: [String] = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"]
        lines.append("<HL7Message type=\"\(message.messageType())\">")
        for segment in message.allSegments {
            lines.append("  <\(segment.segmentID)>")
            for (i, field) in segment.fields.enumerated() {
                let value = field.serialize()
                if !value.isEmpty {
                    let escaped = value
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    lines.append("    <\(segment.segmentID).\(i)>\(escaped)</\(segment.segmentID).\(i)>")
                }
            }
            lines.append("  </\(segment.segmentID)>")
        }
        lines.append("</HL7Message>")
        return lines.joined(separator: "\n")
    }

    /// Generates a FHIR-style JSON preview from a parsed v2.x message.
    private func generateFHIRPreview(_ message: HL7v2Message) -> String {
        var lines: [String] = ["{"]
        lines.append("  \"resourceType\": \"MessageHeader\",")
        lines.append("  \"eventCoding\": {")
        lines.append("    \"code\": \"\(message.messageType())\"")
        lines.append("  },")
        lines.append("  \"source\": {")
        lines.append("    \"name\": \"HL7 v2.x Conversion\"")
        lines.append("  },")
        lines.append("  \"meta\": {")
        lines.append("    \"versionId\": \"\(message.version())\"")
        lines.append("  },")
        lines.append("  \"segments\": [")
        for (i, segment) in message.allSegments.enumerated() {
            let comma = i < message.allSegments.count - 1 ? "," : ""
            lines.append("    { \"id\": \"\(segment.segmentID)\", \"fieldCount\": \(segment.fields.count) }\(comma)")
        }
        lines.append("  ]")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// Computes a segment-level diff between the primary and comparison messages.
    private func computeDiff() {
        diffResults = []
        let primarySegments = appState.rawMessageText
            .split(separator: "\r").map(String.init)
        let compareSegments = diffMessageText
            .split(separator: "\r").map(String.init)

        let maxCount = max(primarySegments.count, compareSegments.count)
        for i in 0..<maxCount {
            let left = i < primarySegments.count ? primarySegments[i] : nil
            let right = i < compareSegments.count ? compareSegments[i] : nil

            if let l = left, let r = right {
                if l != r {
                    diffResults.append(DiffEntry(
                        kind: .changed,
                        description: "Segment \(i): modified"
                    ))
                }
            } else if left != nil {
                diffResults.append(DiffEntry(
                    kind: .removed,
                    description: "Segment \(i): removed in comparison"
                ))
            } else {
                diffResults.append(DiffEntry(
                    kind: .added,
                    description: "Segment \(i): added in comparison"
                ))
            }
        }

        if diffResults.isEmpty {
            diffResults.append(DiffEntry(kind: .unchanged, description: "Messages are identical"))
        }

        appState.log("Diff complete: \(diffResults.count) difference(s)", level: .info)
    }
}

// MARK: - Supporting Types

/// Display format options for the parsed output pane.
enum MessageFormat: String, CaseIterable, Identifiable, Sendable {
    case v2Pipe   = "v2.x Pipe"
    case v3XML    = "v3.x XML"
    case fhirJSON = "FHIR JSON"

    var id: String { rawValue }
    var label: String { rawValue }
}

/// A single entry in a message diff result.
struct DiffEntry: Identifiable, Sendable {
    let id = UUID()
    let kind: DiffKind
    let description: String
}

/// The type of change detected between two segments.
enum DiffKind: Sendable {
    case added, removed, changed, unchanged

    var icon: String {
        switch self {
        case .added:     return "plus.circle.fill"
        case .removed:   return "minus.circle.fill"
        case .changed:   return "pencil.circle.fill"
        case .unchanged: return "equal.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .added:     return .green
        case .removed:   return .red
        case .changed:   return .orange
        case .unchanged: return .secondary
        }
    }
}
#endif
