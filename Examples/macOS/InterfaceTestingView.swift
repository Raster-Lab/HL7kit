/// InterfaceTestingView.swift
/// Interface testing tools for MLLP server/client simulation,
/// message send/receive testing, and auto-responder configuration.
///
/// Provides a comprehensive interface engine simulator that healthcare
/// integration engineers can use to test HL7 connectivity workflows.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit

// MARK: - Interface Testing View

/// A macOS workstation panel for testing HL7 MLLP interfaces with
/// server/client simulation, connection logging, and timing analysis.
@MainActor
struct InterfaceTestingView: View {
    @Environment(WorkstationState.self) private var appState

    @State private var selectedTab: InterfaceTab = .sendReceive

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()

            switch selectedTab {
            case .sendReceive:   SendReceivePanel()
            case .connectionLog: ConnectionLogPanel()
            case .roundTrip:     RoundTripTimingPanel()
            case .autoResponder: AutoResponderPanel()
            }
        }
        .navigationTitle("Interface Testing")
    }

    /// Tab bar for switching between testing panels.
    private var tabPicker: some View {
        Picker("Panel", selection: $selectedTab) {
            ForEach(InterfaceTab.allCases) { tab in
                Label(tab.label, systemImage: tab.icon).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Available interface testing tabs.
enum InterfaceTab: String, CaseIterable, Identifiable, Sendable {
    case sendReceive   = "Send/Receive"
    case connectionLog = "Connection Log"
    case roundTrip     = "Round-Trip Timing"
    case autoResponder = "Auto-Responder"

    var id: String { rawValue }
    var label: String { rawValue }

    var icon: String {
        switch self {
        case .sendReceive:   return "arrow.up.arrow.down"
        case .connectionLog: return "list.bullet.rectangle"
        case .roundTrip:     return "clock.arrow.2.circlepath"
        case .autoResponder: return "bolt.circle"
        }
    }
}

// MARK: - Send/Receive Panel

/// Simulates MLLP client send and server receive operations with
/// configurable host, port, and message content.
@MainActor
struct SendReceivePanel: View {
    @Environment(WorkstationState.self) private var appState

    @State private var host: String = "localhost"
    @State private var port: String = "2575"
    @State private var connectionState: SimConnectionState = .idle
    @State private var messageToSend: String = WorkstationSamples.adtA01
    @State private var receivedResponse: String = ""
    @State private var framedPreview: String = ""
    @State private var serverMode = false

    var body: some View {
        HSplitView {
            sendPane
                .frame(minWidth: 400)
            receivePane
                .frame(minWidth: 400)
        }
    }

    /// Left pane: connection configuration and message sending.
    private var sendPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("MLLP Client", systemImage: "arrow.up.circle")
                    .font(.headline)
                Spacer()
                connectionIndicator
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    connectionConfig

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message to Send")
                                .font(.subheadline.bold())

                            TextEditor(text: $messageToSend)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(minHeight: 120, maxHeight: 200)
                                .border(Color.gray.opacity(0.3))
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await sendMessage() }
                        } label: {
                            Label("Send Message", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(connectionState == .sending)

                        Button("Frame Preview") {
                            showFramedPreview()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Toggle("Server Mode", isOn: $serverMode)
                            .toggleStyle(.switch)
                            .help("Listen for incoming connections instead of sending")
                    }

                    if !framedPreview.isEmpty {
                        framedPreviewSection
                    }
                }
                .padding()
            }
        }
        .background(.background)
    }

    /// Right pane: received response display.
    private var receivePane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Response", systemImage: "arrow.down.circle")
                    .font(.headline)
                Spacer()
                if !receivedResponse.isEmpty {
                    Button("Clear") {
                        receivedResponse = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if receivedResponse.isEmpty {
                ContentUnavailableView(
                    "No Response",
                    systemImage: "tray",
                    description: Text("Send a message to see the response here.")
                )
            } else {
                ScrollView {
                    Text(receivedResponse)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(.background)
    }

    /// Connection host/port configuration.
    private var connectionConfig: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection")
                    .font(.subheadline.bold())

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Host").font(.caption).foregroundStyle(.secondary)
                        TextField("hostname", text: $host)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port").font(.caption).foregroundStyle(.secondary)
                        TextField("port", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
            }
        }
    }

    /// Colored connection state indicator.
    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionState.color)
                .frame(width: 8, height: 8)
            Text(connectionState.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Shows the MLLP-framed byte representation of the message.
    private var framedPreviewSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("MLLP Frame (hex)")
                    .font(.caption.bold())
                Text(framedPreview)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(6)
            }
        }
    }

    /// Frames the message using `MLLPFramer` and shows the hex preview.
    private func showFramedPreview() {
        let framed = MLLPFramer.frame(messageToSend)
        framedPreview = framed.map { String(format: "%02X", $0) }
            .joined(separator: " ")
        appState.log("Framed message: \(framed.count) bytes", level: .info)
    }

    /// Simulates sending a message via MLLP and receiving a response.
    private func sendMessage() async {
        connectionState = .sending
        receivedResponse = ""
        appState.log("Sending to \(host):\(port)…", level: .info)

        let framed = MLLPFramer.frame(messageToSend)
        let isValid = MLLPFramer.isCompleteFrame(framed)

        // Simulate network round-trip
        try? await Task.sleep(for: .milliseconds(800))

        if isValid {
            connectionState = .connected
            let ackControlID = "ACK\(Int.random(in: 10000...99999))"
            let ack = generateACK(for: messageToSend, controlID: ackControlID)
            receivedResponse = """
                --- MLLP Response ---
                Frame validated: \(isValid)
                Bytes sent: \(framed.count)
                
                --- ACK Message ---
                \(ack)
                
                --- Timing ---
                Simulated latency: ~800ms
                (Real TCP via Network.framework in production)
                """
            appState.log("Message sent successfully, ACK received", level: .success)
        } else {
            connectionState = .error
            receivedResponse = "ERROR: MLLP frame validation failed."
            appState.log("Send failed: invalid frame", level: .error)
        }

        try? await Task.sleep(for: .seconds(2))
        connectionState = .idle
    }

    /// Generates a simulated ACK message for the given input.
    private func generateACK(for message: String, controlID: String) -> String {
        let msgType: String
        if let parsed = try? HL7v2Message.parse(message) {
            msgType = parsed.messageType()
        } else {
            msgType = "UNKNOWN"
        }

        let timestamp = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMddHHmmss"
            return f.string(from: Date())
        }()

        return [
            "MSH|^~\\&|RCV|FACILITY|ADT|HOSPITAL|\(timestamp)||ACK^\(msgType)^ACK|\(controlID)|P|2.5.1",
            "MSA|AA|\(controlID)|Message accepted",
        ].joined(separator: "\r")
    }
}

/// Simulated connection states for the UI.
enum SimConnectionState: Sendable {
    case idle, sending, connected, error

    var label: String {
        switch self {
        case .idle:      return "Idle"
        case .sending:   return "Sending…"
        case .connected: return "Connected"
        case .error:     return "Error"
        }
    }

    var color: Color {
        switch self {
        case .idle:      return .gray
        case .sending:   return .yellow
        case .connected: return .green
        case .error:     return .red
        }
    }
}

// MARK: - Connection Log Panel

/// Displays a scrollable, timestamped log of all interface events.
@MainActor
struct ConnectionLogPanel: View {
    @Environment(WorkstationState.self) private var appState

    @State private var filterLevel: WorkstationLogLevel?
    @State private var searchText: String = ""

    /// Filtered log entries based on level and search text.
    private var filteredEntries: [WorkstationLogEntry] {
        appState.logEntries.filter { entry in
            let matchesLevel = filterLevel == nil || entry.level == filterLevel
            let matchesSearch = searchText.isEmpty
                || entry.message.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            logToolbar

            Divider()

            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Interface events will appear here as you use the testing tools.")
                )
            } else {
                logTable
            }

            logStatusBar
        }
    }

    /// Toolbar with search and filter controls.
    private var logToolbar: some View {
        HStack(spacing: 12) {
            Label("Connection Log", systemImage: "list.bullet.rectangle")
                .font(.headline)

            Spacer()

            Picker("Level", selection: Binding(
                get: { filterLevel ?? .info },
                set: { filterLevel = $0 }
            )) {
                Text("All").tag(WorkstationLogLevel.info)
                Text("Success").tag(WorkstationLogLevel.success)
                Text("Warning").tag(WorkstationLogLevel.warning)
                Text("Error").tag(WorkstationLogLevel.error)
            }
            .frame(width: 120)

            Button("Show All") {
                filterLevel = nil
                searchText = ""
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            TextField("Search logs", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Button("Clear Log") {
                appState.logEntries.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Table of log entries with timestamp, level, and message columns.
    private var logTable: some View {
        Table(filteredEntries) {
            TableColumn("Time") { entry in
                Text(entry.timestamp.workstationTimestamp)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Level") { entry in
                HStack(spacing: 4) {
                    Image(systemName: entry.level.icon)
                        .foregroundStyle(entry.level.color)
                    Text(entry.level.rawValue.capitalized)
                        .font(.caption)
                }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Message") { entry in
                Text(entry.message)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
    }

    /// Status bar showing log entry count.
    private var logStatusBar: some View {
        HStack {
            Text("\(filteredEntries.count) of \(appState.logEntries.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Round-Trip Timing Panel

/// Measures and displays message parse → serialize → parse round-trip
/// timing with statistical analysis.
@MainActor
struct RoundTripTimingPanel: View {
    @Environment(WorkstationState.self) private var appState

    @State private var iterations: Double = 100
    @State private var timingResults: [TimingEntry] = []
    @State private var isRunning = false
    @State private var summary: TimingSummary?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                configSection
                if isRunning { ProgressView("Running timing test…") }
                if let summary { summarySection(summary) }
                if !timingResults.isEmpty { timingChart }
            }
            .padding()
        }
    }

    /// Configuration for the timing benchmark.
    private var configSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Round-Trip Timing", systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)

                Text("Measures parse → serialize → re-parse cycle time for the current message.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Iterations")
                        .font(.subheadline)
                    Slider(value: $iterations, in: 10...1000, step: 10)
                    Text("\(Int(iterations))")
                        .font(.subheadline.monospaced().bold())
                        .frame(width: 50)
                }

                Button {
                    Task { await runTimingTest() }
                } label: {
                    Label("Run Timing Test", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
            }
        }
    }

    /// Displays aggregate timing statistics.
    private func summarySection(_ s: TimingSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Summary", systemImage: "chart.bar")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    timingMetric(label: "Min", value: String(format: "%.3f ms", s.minMs), color: .green)
                    timingMetric(label: "Max", value: String(format: "%.3f ms", s.maxMs), color: .red)
                    timingMetric(label: "Average", value: String(format: "%.3f ms", s.avgMs), color: .blue)
                    timingMetric(label: "Throughput", value: String(format: "%.0f msg/s", s.throughput), color: .purple)
                }
            }
        }
    }

    /// A single timing metric card.
    private func timingMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, design: .monospaced).bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Visual chart of individual timing entries.
    private var timingChart: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Timing Distribution", systemImage: "chart.bar.xaxis")
                    .font(.headline)

                let maxTime = timingResults.map(\.durationMs).max() ?? 1
                let displayedResults = Array(timingResults.prefix(50))

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(displayedResults) { entry in
                            let height = max(4, (entry.durationMs / maxTime) * 100)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(entry.passed ? Color.blue : Color.red)
                                .frame(width: 8, height: height)
                                .help(String(format: "%.3f ms", entry.durationMs))
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: 120)

                if timingResults.count > 50 {
                    Text("Showing first 50 of \(timingResults.count) results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Runs the parse → serialize → re-parse timing test.
    private func runTimingTest() async {
        isRunning = true
        timingResults = []
        summary = nil
        let count = Int(iterations)
        let message = appState.rawMessageText

        appState.log("Starting round-trip timing: \(count) iterations", level: .info)

        for i in 0..<count {
            let start = ContinuousClock.now
            var passed = true

            do {
                let parsed = try HL7v2Message.parse(message)
                let serialized = try parsed.serialize()
                _ = try HL7v2Message.parse(serialized)
            } catch {
                passed = false
            }

            let elapsed = start.duration(to: .now)
            let ms = Double(elapsed.components.seconds) * 1000.0
                + Double(elapsed.components.attoseconds) / 1e15

            timingResults.append(TimingEntry(
                index: i + 1,
                durationMs: ms,
                passed: passed
            ))

            if i % 20 == 0 { await Task.yield() }
        }

        let times = timingResults.map(\.durationMs)
        let totalMs = times.reduce(0, +)
        summary = TimingSummary(
            minMs: times.min() ?? 0,
            maxMs: times.max() ?? 0,
            avgMs: times.isEmpty ? 0 : totalMs / Double(times.count),
            throughput: totalMs > 0 ? Double(times.count) / (totalMs / 1000.0) : 0
        )

        appState.log(
            "Timing complete: avg \(String(format: "%.3f", summary?.avgMs ?? 0)) ms",
            level: .success
        )
        isRunning = false
    }
}

/// A single timing measurement entry.
struct TimingEntry: Identifiable, Sendable {
    let id = UUID()
    let index: Int
    let durationMs: Double
    let passed: Bool
}

/// Aggregate timing statistics.
struct TimingSummary: Sendable {
    let minMs: Double
    let maxMs: Double
    let avgMs: Double
    let throughput: Double
}

// MARK: - Auto-Responder Panel

/// Configures automatic ACK responses for incoming HL7 messages,
/// with customizable response codes and delay simulation.
@MainActor
struct AutoResponderPanel: View {
    @Environment(WorkstationState.self) private var appState

    @State private var isEnabled = false
    @State private var responseCode: ACKCode = .aa
    @State private var simulatedDelayMs: Double = 100
    @State private var listenPort: String = "2575"
    @State private var responseCount: Int = 0
    @State private var lastIncomingMessage: String = ""
    @State private var lastGeneratedACK: String = ""

    var body: some View {
        HSplitView {
            configPane
                .frame(minWidth: 350)
            previewPane
                .frame(minWidth: 400)
        }
    }

    /// Left pane: auto-responder configuration.
    private var configPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Auto-Responder", systemImage: "bolt.circle")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }

                        Text(isEnabled ? "Listening for incoming messages…" : "Enable to start listening.")
                            .font(.subheadline)
                            .foregroundStyle(isEnabled ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Listen Port").font(.caption).foregroundStyle(.secondary)
                            TextField("2575", text: $listenPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Response Configuration")
                            .font(.subheadline.bold())

                        Picker("ACK Code", selection: $responseCode) {
                            ForEach(ACKCode.allCases) { code in
                                Text(code.label).tag(code)
                            }
                        }

                        HStack {
                            Text("Simulated Delay")
                                .font(.subheadline)
                            Slider(value: $simulatedDelayMs, in: 0...2000, step: 50)
                            Text("\(Int(simulatedDelayMs)) ms")
                                .font(.caption.monospaced())
                                .frame(width: 60)
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Statistics")
                            .font(.subheadline.bold())

                        WorkstationDetailRow(label: "Status", value: isEnabled ? "Active" : "Inactive")
                        WorkstationDetailRow(label: "Port", value: listenPort)
                        WorkstationDetailRow(label: "Response Code", value: responseCode.rawValue)
                        WorkstationDetailRow(label: "Responses Sent", value: "\(responseCount)")
                    }
                }

                Button("Simulate Incoming Message") {
                    simulateIncoming()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isEnabled)
            }
            .padding()
        }
    }

    /// Right pane: preview of last incoming message and generated ACK.
    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Last Exchange", systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            if lastIncomingMessage.isEmpty {
                ContentUnavailableView(
                    "No Messages Yet",
                    systemImage: "tray",
                    description: Text("Enable the auto-responder and simulate or receive a message.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Incoming Message")
                                    .font(.subheadline.bold())
                                Text(lastIncomingMessage.replacingOccurrences(of: "\r", with: "\n"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }

                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Generated ACK")
                                    .font(.subheadline.bold())
                                Text(lastGeneratedACK.replacingOccurrences(of: "\r", with: "\n"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(.background)
    }

    /// Simulates receiving an incoming HL7 message and generating an ACK.
    private func simulateIncoming() {
        let incoming = WorkstationSamples.adtA01
        lastIncomingMessage = incoming

        let timestamp = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMddHHmmss"
            return f.string(from: Date())
        }()

        let controlID: String
        if let parsed = try? HL7v2Message.parse(incoming) {
            controlID = parsed.messageControlID()
        } else {
            controlID = "UNKNOWN"
        }

        let ackText: String
        switch responseCode {
        case .aa:
            ackText = "Message accepted"
        case .ae:
            ackText = "Application error"
        case .ar:
            ackText = "Application reject"
        }

        lastGeneratedACK = [
            "MSH|^~\\&|RCV|FACILITY|ADT|HOSPITAL|\(timestamp)||ACK^A01^ACK|ACK\(Int.random(in: 10000...99999))|P|2.5.1",
            "MSA|\(responseCode.rawValue)|\(controlID)|\(ackText)",
        ].joined(separator: "\r")

        responseCount += 1
        appState.log(
            "Auto-responder: sent \(responseCode.rawValue) for \(controlID)",
            level: responseCode == .aa ? .success : .warning
        )
    }
}

/// HL7 acknowledgment code options.
enum ACKCode: String, CaseIterable, Identifiable, Sendable {
    case aa = "AA"
    case ae = "AE"
    case ar = "AR"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aa: return "AA – Accept"
        case .ae: return "AE – Error"
        case .ar: return "AR – Reject"
        }
    }
}
#endif
