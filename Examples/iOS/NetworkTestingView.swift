/// NetworkTestingView.swift
/// Network testing tools for MLLP and FHIR REST connectivity.
///
/// Provides a dual-panel interface: the top section handles HL7 v2.x
/// messages over MLLP (TCP with Minimal Lower Layer Protocol framing),
/// while the bottom section exercises the FHIR RESTful client against
/// a configurable server endpoint.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit
import FHIRkit

// MARK: - Network Testing View

/// Tab view for testing MLLP connections and FHIR REST operations.
@MainActor
struct NetworkTestingView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPanel: NetworkPanel = .mllp

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Panel", selection: $selectedPanel) {
                    Text("MLLP").tag(NetworkPanel.mllp)
                    Text("FHIR REST").tag(NetworkPanel.fhir)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedPanel {
                case .mllp: MLLPTestingPanel()
                case .fhir: FHIRTestingPanel()
                }
            }
            .navigationTitle("Network Testing")
        }
    }
}

/// The active network panel selection.
enum NetworkPanel: String, CaseIterable, Sendable {
    case mllp = "MLLP"
    case fhir = "FHIR REST"
}

// MARK: - MLLP Testing Panel

/// Tests MLLP framing, connection to a remote HL7 listener, and
/// displays framed/deframed message bytes.
@MainActor
struct MLLPTestingPanel: View {
    @Environment(AppState.self) private var appState

    @State private var host: String = "localhost"
    @State private var port: String = "2575"
    @State private var connectionStatus: ConnectionStatus = .disconnected
    @State private var responseText: String = ""
    @State private var framedHex: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionSection
                framingDemoSection
                responseSection
            }
            .padding()
        }
    }

    // MARK: Connection Configuration

    @ViewBuilder
    private var connectionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Connection", systemImage: "cable.connector")

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Host").font(.caption).foregroundStyle(.secondary)
                        TextField("hostname", text: $host)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port").font(.caption).foregroundStyle(.secondary)
                        TextField("port", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                }

                HStack {
                    statusIndicator
                    Spacer()
                    Button("Test Connection") {
                        Task { await testMLLPConnection() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(connectionStatus == .connecting)
                }
            }
        }
    }

    /// Colored dot indicating current connection state.
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionStatus.color)
                .frame(width: 10, height: 10)
            Text(connectionStatus.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Framing Demo

    @ViewBuilder
    private var framingDemoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "MLLP Framing", systemImage: "rectangle.split.3x1")

                Button("Frame Current Message") {
                    frameCurrentMessage()
                }
                .buttonStyle(.bordered)

                if !framedHex.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Framed bytes (hex)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(framedHex)
                            .font(.system(.caption2, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: Response Viewer

    @ViewBuilder
    private var responseSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "Response", systemImage: "arrow.down.doc")

                if responseText.isEmpty {
                    Text("No response yet. Test a connection to see results.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Text(responseText)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: Actions

    /// Frames the active message using `MLLPFramer` and shows hex output.
    private func frameCurrentMessage() {
        let raw = appState.currentMessageText
        let framedData = MLLPFramer.frame(raw)
        framedHex = framedData.map { String(format: "%02X", $0) }
            .joined(separator: " ")
        appState.log("Framed message: \(framedData.count) bytes", level: .info)

        // Round-trip: verify deframing recovers original text
        do {
            let recovered = try MLLPFramer.deframe(framedData)
            let matches = recovered == raw
            appState.log(
                "Deframe round-trip: \(matches ? "OK" : "MISMATCH")",
                level: matches ? .success : .warning
            )
        } catch {
            appState.log("Deframe failed: \(error)", level: .error)
        }
    }

    /// Simulates an MLLP connection test (actual TCP requires Network.framework).
    private func testMLLPConnection() async {
        connectionStatus = .connecting
        responseText = ""
        appState.log("Connecting to \(host):\(port)…", level: .info)

        // Simulate network delay – real implementation would use NWConnection
        try? await Task.sleep(for: .seconds(1))

        let framedData = MLLPFramer.frame(appState.currentMessageText)
        let isValid = MLLPFramer.isCompleteFrame(framedData)

        if isValid {
            connectionStatus = .connected
            responseText = """
                [Simulated] MLLP frame validated successfully.
                Host: \(host):\(port)
                Frame size: \(framedData.count) bytes
                Contains start byte: \(MLLPFramer.containsStartByte(framedData))
                Complete frame: \(isValid)
                
                In production, use NWConnection from Network.framework
                to establish a real TCP connection to the HL7 listener.
                """
            appState.log("MLLP frame validated", level: .success)
        } else {
            connectionStatus = .error
            responseText = "Frame validation failed."
            appState.log("MLLP frame invalid", level: .error)
        }
    }
}

// MARK: - Connection Status

/// Represents the current state of a network connection attempt.
enum ConnectionStatus: Sendable {
    case disconnected, connecting, connected, error

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting…"
        case .connected:    return "Connected"
        case .error:        return "Error"
        }
    }

    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting:   return .yellow
        case .connected:    return .green
        case .error:        return .red
        }
    }
}

// MARK: - FHIR Testing Panel

/// Exercises the FHIR REST client against a configurable base URL.
@MainActor
struct FHIRTestingPanel: View {
    @Environment(AppState.self) private var appState

    @State private var baseURL: String = "https://hapi.fhir.org/baseR4"
    @State private var resourceType: String = "Patient"
    @State private var resourceID: String = ""
    @State private var responseJSON: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                serverConfigSection
                operationsSection
                fhirResponseSection
            }
            .padding()
        }
    }

    // MARK: Server Configuration

    @ViewBuilder
    private var serverConfigSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "FHIR Server", systemImage: "server.rack")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Base URL").font(.caption).foregroundStyle(.secondary)
                    TextField("https://fhir.example.org/baseR4", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resource").font(.caption).foregroundStyle(.secondary)
                        TextField("Patient", text: $resourceType)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ID (optional)").font(.caption).foregroundStyle(.secondary)
                        TextField("123", text: $resourceID)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    // MARK: Operations

    @ViewBuilder
    private var operationsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Operations", systemImage: "arrow.triangle.2.circlepath")

                HStack(spacing: 12) {
                    Button("Read") {
                        Task { await performRead() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Search") {
                        Task { await performSearch() }
                    }
                    .buttonStyle(.bordered)

                    Button("Create Sample") {
                        Task { await createSamplePatient() }
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(isLoading)

                if isLoading {
                    ProgressView("Communicating with server…")
                        .frame(maxWidth: .infinity)
                }

                if let error = errorMessage {
                    Label(error, systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Response Display

    @ViewBuilder
    private var fhirResponseSection: some View {
        if !responseJSON.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeaderView(title: "Response", systemImage: "doc.text")
                    ScrollView(.horizontal) {
                        Text(responseJSON)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 300)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: FHIR Client Actions

    /// Reads a FHIR resource by type and ID using `FHIRClient`.
    ///
    /// `FHIRClient.read()` returns a `FHIRResponse<T>` wrapper; access
    /// the decoded resource via `.resource`.
    private func performRead() async {
        guard let url = URL(string: baseURL) else {
            errorMessage = "Invalid base URL"
            return
        }
        isLoading = true
        errorMessage = nil
        appState.log("FHIR Read: \(resourceType)/\(resourceID)", level: .info)

        do {
            let config = FHIRClientConfiguration(baseURL: url)
            let client = FHIRClient(configuration: config)
            let response = try await client.read(Patient.self, id: resourceID)
            let patient = response.resource
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(patient)
            responseJSON = String(data: data, encoding: .utf8) ?? "{}"
            appState.log("Read successful: \(patient.id ?? "unknown")", level: .success)
        } catch {
            errorMessage = "Read failed: \(error.localizedDescription)"
            responseJSON = ""
            appState.log("FHIR Read error: \(error)", level: .error)
        }

        isLoading = false
    }

    /// Searches for resources with default parameters.
    ///
    /// `FHIRClient.search()` takes a `Resource` type and optional query
    /// parameters, returning a `FHIRResponse<Bundle>`.
    private func performSearch() async {
        guard let url = URL(string: baseURL) else {
            errorMessage = "Invalid base URL"
            return
        }
        isLoading = true
        errorMessage = nil
        appState.log("FHIR Search: \(resourceType)", level: .info)

        do {
            let config = FHIRClientConfiguration(baseURL: url)
            let client = FHIRClient(configuration: config)
            let response = try await client.search(Patient.self, parameters: [:])
            let bundle = response.resource
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(bundle)
            responseJSON = String(data: data, encoding: .utf8) ?? "{}"
            appState.log("Search returned bundle", level: .success)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            responseJSON = ""
            appState.log("FHIR Search error: \(error)", level: .error)
        }

        isLoading = false
    }

    /// Creates a sample `Patient` resource on the server.
    ///
    /// Demonstrates constructing a FHIR `Patient` with `HumanName` and
    /// posting it via `FHIRClient.create()`.
    private func createSamplePatient() async {
        guard let url = URL(string: baseURL) else {
            errorMessage = "Invalid base URL"
            return
        }
        isLoading = true
        errorMessage = nil

        let patient = Patient(
            resourceType: "Patient",
            id: nil,
            name: [
                HumanName(use: "official", family: "Demo", given: ["HL7kit"])
            ],
            gender: "male",
            birthDate: "1990-01-15"
        )

        appState.log("Creating sample Patient…", level: .info)

        do {
            let config = FHIRClientConfiguration(baseURL: url)
            let client = FHIRClient(configuration: config)
            let response = try await client.create(patient)
            let created = response.resource
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(created)
            responseJSON = String(data: data, encoding: .utf8) ?? "{}"
            appState.log("Patient created: \(created.id ?? "n/a")", level: .success)
        } catch {
            errorMessage = "Create failed: \(error.localizedDescription)"
            responseJSON = ""
            appState.log("FHIR Create error: \(error)", level: .error)
        }

        isLoading = false
    }
}
#endif
