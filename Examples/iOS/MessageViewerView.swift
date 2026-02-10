/// MessageViewerView.swift
/// Interactive HL7 v2.x message viewer and editor.
///
/// Provides a split-pane interface where users can enter raw HL7 text
/// in the top editor and see the parsed message tree below. Segments
/// are color-coded by type and errors are highlighted inline.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit

// MARK: - Message Viewer View

/// A two-pane view for editing raw HL7 v2.x messages and inspecting
/// the parsed segment/field tree.
@MainActor
struct MessageViewerView: View {
    @Environment(AppState.self) private var appState

    @State private var parseError: String?
    @State private var isEditorExpanded = true
    @State private var selectedSegmentIndex: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editorSection
                Divider()
                parsedTreeSection
            }
            .navigationTitle("Message Viewer")
            .toolbar { toolbarItems }
        }
        .onAppear { parseCurrentMessage() }
    }

    // MARK: - Editor Section

    /// Raw HL7 text editor with syntax-highlighted preview.
    @ViewBuilder
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeaderView(title: "Raw Message", systemImage: "pencil.and.outline")
                Spacer()
                Button {
                    withAnimation { isEditorExpanded.toggle() }
                } label: {
                    Image(systemName: isEditorExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if isEditorExpanded {
                @Bindable var state = appState
                TextEditor(text: $state.currentMessageText)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 120, maxHeight: 200)
                    .padding(.horizontal)
                    .onChange(of: appState.currentMessageText) {
                        parseCurrentMessage()
                    }
            }

            if let error = parseError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Parsed Tree Section

    /// Displays the parsed message as a navigable segment tree.
    @ViewBuilder
    private var parsedTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeaderView(title: "Parsed Structure", systemImage: "list.bullet.indent")
                Spacer()
                if let msg = appState.parsedMessage {
                    StatusBadge(
                        text: "\(msg.segmentCount) segments",
                        color: .blue
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if let msg = appState.parsedMessage {
                messageInfoBar(msg)
                segmentList(msg)
            } else {
                ContentUnavailableView(
                    "No Parsed Message",
                    systemImage: "doc.text",
                    description: Text("Enter a valid HL7 v2.x message above.")
                )
            }
        }
    }

    /// Compact header showing message metadata.
    private func messageInfoBar(_ message: HL7v2Message) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                DetailRow(label: "Type", value: message.messageType())
                Divider().frame(height: 20)
                DetailRow(label: "Control ID", value: message.messageControlID())
                Divider().frame(height: 20)
                DetailRow(label: "Version", value: message.version())
            }
            .padding(.horizontal)
        }
    }

    /// Scrollable list of parsed segments with expandable fields.
    private func segmentList(_ message: HL7v2Message) -> some View {
        List {
            ForEach(Array(message.allSegments.enumerated()), id: \.offset) { index, segment in
                SegmentRowView(
                    segment: segment,
                    isExpanded: selectedSegmentIndex == index
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegmentIndex = selectedSegmentIndex == index ? nil : index
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu("Samples", systemImage: "doc.on.doc") {
                Button("ADT^A01 – Admit") {
                    appState.currentMessageText = SampleMessages.adtA01
                }
                Button("ORU^R01 – Lab Result") {
                    appState.currentMessageText = SampleMessages.oruR01
                }
                Button("Invalid Message") {
                    appState.currentMessageText = SampleMessages.invalidMessage
                }
            }
        }
    }

    // MARK: - Parsing

    /// Attempts to parse the current raw text into an `HL7v2Message`.
    private func parseCurrentMessage() {
        let text = appState.currentMessageText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            appState.parsedMessage = nil
            parseError = nil
            return
        }
        do {
            let message = try HL7v2Message.parse(text)
            appState.parsedMessage = message
            parseError = nil
            appState.log("Parsed message: \(message.messageType())", level: .success)
        } catch let error as HL7Error {
            appState.parsedMessage = nil
            parseError = describeHL7Error(error)
            appState.log("Parse failed: \(parseError ?? "unknown")", level: .error)
        } catch {
            appState.parsedMessage = nil
            parseError = error.localizedDescription
        }
    }

    /// Produces a user-friendly description of an `HL7Error`.
    private func describeHL7Error(_ error: HL7Error) -> String {
        switch error {
        case .invalidFormat(let msg, _):       return "Invalid format: \(msg)"
        case .missingRequiredField(let msg, _): return "Missing field: \(msg)"
        case .parsingError(let msg, _):        return "Parse error: \(msg)"
        case .validationError(let msg, _):     return "Validation: \(msg)"
        default:                               return "\(error)"
        }
    }
}

// MARK: - Segment Row View

/// Displays a single segment with color-coded ID and expandable field list.
struct SegmentRowView: View {
    let segment: BaseSegment
    let isExpanded: Bool

    /// Returns a color based on the segment type for visual grouping.
    private var segmentColor: Color {
        switch segment.segmentID {
        case "MSH": return .blue
        case "PID": return .green
        case "PV1": return .purple
        case "OBR": return .orange
        case "OBX": return .teal
        case "EVN": return .indigo
        case "NK1": return .mint
        default:    return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(segment.segmentID)
                    .font(.headline.monospaced())
                    .foregroundStyle(segmentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(segmentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text("\(segment.fields.count) fields")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isExpanded {
                fieldDetails
            }
        }
        .padding(.vertical, 4)
    }

    /// Expanded view listing each field with its index and value.
    @ViewBuilder
    private var fieldDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(segment.fields.enumerated()), id: \.offset) { index, field in
                let serialized = field.serialize()
                if !serialized.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(segment.segmentID)-\(index)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                        Text(serialized)
                            .font(.caption.monospaced())
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                }
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
#endif
