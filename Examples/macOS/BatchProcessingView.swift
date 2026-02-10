/// BatchProcessingView.swift
/// Batch processing tools for loading, validating, and exporting
/// collections of HL7 messages from files.
///
/// Provides a file picker, progress tracking, results table with
/// pass/fail indicators, and CSV/JSON export functionality.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit
import UniformTypeIdentifiers

// MARK: - Batch Processing View

/// A macOS workstation panel for processing multiple HL7 messages in batch,
/// with file import, validation, and results export capabilities.
@MainActor
struct BatchProcessingView: View {
    @Environment(WorkstationState.self) private var appState

    @State private var batchInput: String = ""
    @State private var results: [BatchResultItem] = []
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var searchText: String = ""
    @State private var filterStatus: BatchFilterStatus = .all
    @State private var showFileImporter = false
    @State private var showExporter = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var sortOrder = [KeyPathComparator(\BatchResultItem.index)]
    @State private var selectedResultIDs: Set<UUID> = []

    /// Results filtered by search text and pass/fail status.
    private var filteredResults: [BatchResultItem] {
        results.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.messageType.localizedCaseInsensitiveContains(searchText)
                || item.controlID.localizedCaseInsensitiveContains(searchText)
                || (item.errorDescription ?? "").localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch filterStatus {
            case .all:    matchesFilter = true
            case .passed: matchesFilter = item.passed
            case .failed: matchesFilter = !item.passed
            }

            return matchesSearch && matchesFilter
        }
        .sorted(using: sortOrder)
    }

    var body: some View {
        VSplitView {
            inputSection
                .frame(minHeight: 200)
            resultsSection
                .frame(minHeight: 250)
        }
        .toolbar { toolbarContent }
        .navigationTitle("Batch Processing")
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showFileImporter = true
            } label: {
                Label("Open File", systemImage: "doc.badge.plus")
            }
            .help("Load an HL7 batch file")

            Button {
                Task { await processBatch() }
            } label: {
                Label("Process", systemImage: "play.fill")
            }
            .disabled(batchInput.isEmpty || isProcessing)
            .help("Process all messages in the batch")

            Spacer()

            Menu("Export", systemImage: "square.and.arrow.up") {
                Button("Export as CSV") {
                    exportFormat = .csv
                    exportResults()
                }
                Button("Export as JSON") {
                    exportFormat = .json
                    exportResults()
                }
            }
            .disabled(results.isEmpty)
        }
    }

    // MARK: - Input Section

    /// Upper area: batch message input with a text editor and file import.
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Batch Input", systemImage: "doc.on.doc")
                    .font(.headline)
                Spacer()

                if !batchInput.isEmpty {
                    let messageCount = splitBatchMessages(batchInput).count
                    WorkstationBadge(text: "\(messageCount) messages", color: .blue)
                }

                Button("Load Samples") {
                    loadSampleBatch()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            TextEditor(text: $batchInput)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.visible)

            if isProcessing {
                batchProgressBar
            }
        }
        .background(.background)
    }

    /// Progress bar shown during batch processing.
    private var batchProgressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: progress) {
                Text("Processing messages…")
                    .font(.caption)
            }
            Text("\(Int(progress * 100))% complete")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Results Section

    /// Lower area: results table with filtering, search, and selection.
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            resultsToolbar

            Divider()

            if results.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "tray",
                    description: Text("Load a batch file or paste messages above, then click Process.")
                )
            } else if filteredResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                batchResultsTable
            }

            resultsSummaryBar
        }
        .background(.background)
    }

    /// Toolbar above the results table with search and filter controls.
    private var resultsToolbar: some View {
        HStack(spacing: 12) {
            Label("Results", systemImage: "checklist")
                .font(.headline)

            Spacer()

            Picker("Filter", selection: $filterStatus) {
                ForEach(BatchFilterStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Table displaying batch processing results with sortable columns.
    private var batchResultsTable: some View {
        Table(filteredResults, selection: $selectedResultIDs, sortOrder: $sortOrder) {
            TableColumn("#", value: \.index) { item in
                Text("\(item.index)")
                    .font(.caption.monospaced())
            }
            .width(min: 30, ideal: 40)

            TableColumn("Status") { item in
                HStack(spacing: 4) {
                    Image(systemName: item.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(item.passed ? .green : .red)
                    Text(item.passed ? "Pass" : "Fail")
                        .font(.caption)
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("Message Type", value: \.messageType) { item in
                Text(item.messageType)
                    .font(.caption.monospaced())
            }
            .width(min: 80, ideal: 120)

            TableColumn("Control ID", value: \.controlID) { item in
                Text(item.controlID)
                    .font(.caption.monospaced())
            }
            .width(min: 80, ideal: 120)

            TableColumn("Segments") { item in
                Text("\(item.segmentCount)")
                    .font(.caption.monospaced())
            }
            .width(min: 50, ideal: 70)

            TableColumn("Parse Time") { item in
                Text(String(format: "%.2f ms", item.parseTimeMs))
                    .font(.caption.monospaced())
            }
            .width(min: 60, ideal: 90)

            TableColumn("Error") { item in
                if let error = item.errorDescription {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
    }

    /// Summary bar showing aggregate statistics for the batch.
    private var resultsSummaryBar: some View {
        HStack(spacing: 16) {
            let passed = results.filter(\.passed).count
            let failed = results.count - passed
            let avgTime = results.isEmpty ? 0 :
                results.reduce(0.0) { $0 + $1.parseTimeMs } / Double(results.count)

            Label("\(results.count) total", systemImage: "number")
                .font(.caption)
            Label("\(passed) passed", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
            Label("\(failed) failed", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(failed > 0 ? .red : .secondary)
            Label(String(format: "%.2f ms avg", avgTime), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(filteredResults.count) shown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Actions

    /// Splits the batch input into individual messages and parses each one.
    private func processBatch() async {
        let messages = splitBatchMessages(batchInput)
        guard !messages.isEmpty else { return }

        isProcessing = true
        progress = 0
        results = []
        appState.log("Processing batch: \(messages.count) messages", level: .info)

        for (index, rawMessage) in messages.enumerated() {
            let start = ContinuousClock.now
            var item = BatchResultItem(index: index + 1)

            do {
                let parsed = try HL7v2Message.parse(rawMessage)
                let elapsed = start.duration(to: .now)
                item.passed = true
                item.messageType = parsed.messageType()
                item.controlID = parsed.messageControlID()
                item.segmentCount = parsed.segmentCount
                item.parseTimeMs = durationToMs(elapsed)
            } catch {
                let elapsed = start.duration(to: .now)
                item.passed = false
                item.parseTimeMs = durationToMs(elapsed)
                item.errorDescription = "\(error)"
            }

            results.append(item)
            progress = Double(index + 1) / Double(messages.count)

            if index % 10 == 0 {
                await Task.yield()
            }
        }

        let passed = results.filter(\.passed).count
        appState.log(
            "Batch complete: \(passed)/\(results.count) passed",
            level: passed == results.count ? .success : .warning
        )
        isProcessing = false
    }

    /// Imports a file selected via the system file picker.
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                appState.log("Cannot access file: permission denied", level: .error)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                batchInput = try String(contentsOf: url, encoding: .utf8)
                appState.log("Loaded file: \(url.lastPathComponent)", level: .success)
            } catch {
                appState.log("File read error: \(error.localizedDescription)", level: .error)
            }
        case .failure(let error):
            appState.log("File picker error: \(error.localizedDescription)", level: .error)
        }
    }

    /// Loads a set of sample messages for batch processing demos.
    private func loadSampleBatch() {
        batchInput = [
            WorkstationSamples.adtA01,
            WorkstationSamples.oruR01,
            WorkstationSamples.ormO01,
            WorkstationSamples.invalidMessage,
            WorkstationSamples.adtA01,
        ].joined(separator: "\r\n\r\n")
        appState.log("Loaded sample batch", level: .info)
    }

    /// Exports results to CSV or JSON and copies to clipboard.
    private func exportResults() {
        let output: String
        switch exportFormat {
        case .csv:
            output = exportAsCSV()
        case .json:
            output = exportAsJSON()
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)
        appState.log("Exported \(results.count) results as \(exportFormat.rawValue) to clipboard", level: .success)
    }

    /// Generates CSV text from the results array.
    private func exportAsCSV() -> String {
        var lines = ["Index,Status,MessageType,ControlID,Segments,ParseTimeMs,Error"]
        for item in results {
            let status = item.passed ? "PASS" : "FAIL"
            let error = (item.errorDescription ?? "")
                .replacingOccurrences(of: ",", with: ";")
                .replacingOccurrences(of: "\n", with: " ")
            lines.append("\(item.index),\(status),\(item.messageType),\(item.controlID),\(item.segmentCount),\(String(format: "%.2f", item.parseTimeMs)),\(error)")
        }
        return lines.joined(separator: "\n")
    }

    /// Generates JSON text from the results array.
    private func exportAsJSON() -> String {
        let items = results.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "index": item.index,
                "passed": item.passed,
                "messageType": item.messageType,
                "controlID": item.controlID,
                "segmentCount": item.segmentCount,
                "parseTimeMs": item.parseTimeMs,
            ]
            if let error = item.errorDescription {
                dict["error"] = error
            }
            return dict
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: items,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    // MARK: - Helpers

    /// Splits raw batch input into individual HL7 messages.
    ///
    /// Messages are separated by blank lines or double carriage returns.
    private func splitBatchMessages(_ input: String) -> [String] {
        let normalized = input
            .replacingOccurrences(of: "\r\n", with: "\r")
            .replacingOccurrences(of: "\n", with: "\r")

        return normalized
            .components(separatedBy: "\r\r")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.hasPrefix("MSH") }
    }

    /// Converts a `Duration` to milliseconds.
    private func durationToMs(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000.0
            + Double(duration.components.attoseconds) / 1e15
    }
}

// MARK: - Supporting Types

/// A single result from batch processing.
struct BatchResultItem: Identifiable, Sendable {
    let id = UUID()
    var index: Int
    var passed: Bool = false
    var messageType: String = "—"
    var controlID: String = "—"
    var segmentCount: Int = 0
    var parseTimeMs: Double = 0
    var errorDescription: String?
}

/// Filter options for the results table.
enum BatchFilterStatus: String, CaseIterable, Identifiable, Sendable {
    case all, passed, failed

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Export format options.
enum ExportFormat: String, Sendable {
    case csv = "CSV"
    case json = "JSON"
}
#endif
