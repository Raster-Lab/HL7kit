/// HL7WorkstationApp.swift
/// Main entry point for the HL7kit macOS workstation application.
///
/// Provides a professional macOS window with NavigationSplitView sidebar,
/// menu bar commands with keyboard shortcuts, and multi-window support.
///
/// Build this file as part of a standalone Xcode project that depends
/// on the HL7kit package.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit
import FHIRkit
import HL7v3Kit

// MARK: - App Entry Point

/// The main macOS application providing a sidebar-driven workstation
/// for HL7 message processing, batch operations, and development tools.
@main
@MainActor
struct HL7WorkstationApp: App {
    /// Shared application state coordinating data across all views.
    @State private var appState = WorkstationState()

    /// Tracks the active sidebar selection.
    @State private var selectedSection: SidebarSection? = .messageProcessing

    var body: some Scene {
        WindowGroup("HL7 Workstation") {
            NavigationSplitView {
                SidebarView(selection: $selectedSection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            } detail: {
                detailView(for: selectedSection)
            }
            .environment(appState)
            .frame(minWidth: 1000, minHeight: 650)
        }
        .commands { workstationCommands }
        .defaultSize(width: 1280, height: 800)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    /// Resolves the active sidebar section to the corresponding detail view.
    @ViewBuilder
    private func detailView(for section: SidebarSection?) -> some View {
        switch section {
        case .messageProcessing:
            MessageProcessingView()
        case .batchProcessing:
            BatchProcessingView()
        case .developmentTools:
            DevelopmentToolsView()
        case .interfaceTesting:
            InterfaceTestingView()
        case nil:
            ContentUnavailableView(
                "Select a Tool",
                systemImage: "sidebar.left",
                description: Text("Choose a tool from the sidebar to get started.")
            )
        }
    }

    /// Menu bar commands with keyboard shortcuts for power users.
    @CommandsBuilder
    private var workstationCommands: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Message") {
                appState.rawMessageText = ""
                selectedSection = .messageProcessing
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Parse Message") {
                appState.parseCurrentMessage()
                selectedSection = .messageProcessing
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Divider()

            Button("Load Sample ADT^A01") {
                appState.rawMessageText = WorkstationSamples.adtA01
                appState.parseCurrentMessage()
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Load Sample ORU^R01") {
                appState.rawMessageText = WorkstationSamples.oruR01
                appState.parseCurrentMessage()
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Load Sample ORM^O01") {
                appState.rawMessageText = WorkstationSamples.ormO01
                appState.parseCurrentMessage()
            }
            .keyboardShortcut("3", modifiers: [.command])
        }

        CommandGroup(after: .toolbar) {
            Button("Message Processing") {
                selectedSection = .messageProcessing
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Batch Processing") {
                selectedSection = .batchProcessing
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Development Tools") {
                selectedSection = .developmentTools
            }
            .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Interface Testing") {
                selectedSection = .interfaceTesting
            }
            .keyboardShortcut("4", modifiers: [.command, .option])
        }
    }
}

// MARK: - Sidebar

/// Sidebar sections representing top-level workstation tools.
enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
    case messageProcessing  = "Message Processing"
    case batchProcessing    = "Batch Processing"
    case developmentTools   = "Development Tools"
    case interfaceTesting   = "Interface Testing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .messageProcessing: return "doc.text.magnifyingglass"
        case .batchProcessing:   return "doc.on.doc"
        case .developmentTools:  return "wrench.and.screwdriver"
        case .interfaceTesting:  return "network"
        }
    }
}

/// Sidebar view listing workstation sections with icons and labels.
@MainActor
struct SidebarView: View {
    @Binding var selection: SidebarSection?

    var body: some View {
        List(SidebarSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .tag(section)
        }
        .navigationTitle("HL7 Workstation")
        .listStyle(.sidebar)
    }
}

// MARK: - Application State

/// Observable state shared across the entire workstation, managing the
/// current message text, parsed result, and application-wide log.
@Observable
@MainActor
final class WorkstationState {
    /// Raw HL7 message text in the editor.
    var rawMessageText: String = WorkstationSamples.adtA01

    /// Most recently parsed HL7 v2.x message, if valid.
    var parsedMessage: HL7v2Message?

    /// Global log entries displayed in the status bar and log panels.
    var logEntries: [WorkstationLogEntry] = []

    /// Human-readable parse error for the current message.
    var parseErrorDescription: String?

    /// Parses `rawMessageText` and updates `parsedMessage`.
    func parseCurrentMessage() {
        let text = rawMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            parsedMessage = nil
            parseErrorDescription = nil
            return
        }
        do {
            parsedMessage = try HL7v2Message.parse(text)
            parseErrorDescription = nil
            log("Parsed: \(parsedMessage?.messageType() ?? "unknown")", level: .success)
        } catch let error as HL7Error {
            parsedMessage = nil
            parseErrorDescription = describeError(error)
            log("Parse failed: \(parseErrorDescription ?? "")", level: .error)
        } catch {
            parsedMessage = nil
            parseErrorDescription = error.localizedDescription
        }
    }

    /// Appends a timestamped log entry.
    func log(_ message: String, level: WorkstationLogLevel = .info) {
        logEntries.append(WorkstationLogEntry(
            timestamp: Date(),
            message: message,
            level: level
        ))
    }

    /// Formats an `HL7Error` for display.
    private func describeError(_ error: HL7Error) -> String {
        switch error {
        case .invalidFormat(let msg, _):        return "Invalid format: \(msg)"
        case .missingRequiredField(let msg, _):  return "Missing field: \(msg)"
        case .parsingError(let msg, _):         return "Parse error: \(msg)"
        case .validationError(let msg, _):      return "Validation: \(msg)"
        default:                                return "\(error)"
        }
    }
}

// MARK: - Log Types

/// Log severity levels with associated colors and icons.
enum WorkstationLogLevel: String, Sendable {
    case info, success, warning, error

    var icon: String {
        switch self {
        case .info:    return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .info:    return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        }
    }
}

/// A single timestamped log entry.
struct WorkstationLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: WorkstationLogLevel
}

// MARK: - Sample Messages

/// Pre-built HL7 v2.x sample messages used throughout the workstation.
enum WorkstationSamples {
    /// ADT^A01 – Admit/Visit Notification.
    static let adtA01: String = [
        "MSH|^~\\&|ADT|HOSPITAL|RCV|FACILITY|20240115120000||ADT^A01^ADT_A01|MSG00001|P|2.5.1",
        "EVN|A01|20240115120000",
        "PID|1||12345^^^HOSP^MR||Doe^John^A||19800101|M|||123 Main St^^Springfield^IL^62701||555-555-1234",
        "PV1|1|I|ICU^101^A|E|||1234^Smith^Jane^^^Dr|||MED||||1|||1234^Smith^Jane^^^Dr|IN||||||||||||||||||||||20240115120000",
    ].joined(separator: "\r")

    /// ORU^R01 – Observation Result (Lab).
    static let oruR01: String = [
        "MSH|^~\\&|LAB|HOSPITAL|RCV|FACILITY|20240115130000||ORU^R01^ORU_R01|MSG00002|P|2.5.1",
        "PID|1||67890^^^HOSP^MR||Smith^Jane^B||19901215|F",
        "OBR|1|ORD001|LAB001|CBC^Complete Blood Count^LN|||20240115100000",
        "OBX|1|NM|WBC^White Blood Cell Count^LN||7.5|10*3/uL|4.5-11.0|N|||F",
        "OBX|2|NM|RBC^Red Blood Cell Count^LN||4.8|10*6/uL|4.0-5.5|N|||F",
        "OBX|3|NM|HGB^Hemoglobin^LN||14.2|g/dL|12.0-16.0|N|||F",
    ].joined(separator: "\r")

    /// ORM^O01 – General Order.
    static let ormO01: String = [
        "MSH|^~\\&|CPOE|HOSPITAL|LAB|FACILITY|20240115140000||ORM^O01^ORM_O01|MSG00003|P|2.5.1",
        "PID|1||11111^^^HOSP^MR||Johnson^Robert^C||19750310|M",
        "ORC|NW|ORD002||||||20240115140000|||1234^Smith^Jane^^^Dr",
        "OBR|1|ORD002||BMP^Basic Metabolic Panel^LN|||20240115140000||||||||1234^Smith^Jane^^^Dr",
    ].joined(separator: "\r")

    /// A deliberately malformed message for error-handling demos.
    static let invalidMessage: String = [
        "MSH|^~\\&|SRC||||||BAD_TYPE|CTL001|P|2.5.1",
        "PID|1||^^^HOSP^MR||^John||INVALID_DATE|X",
    ].joined(separator: "\r")
}

// MARK: - Settings View

/// Application-level settings for the workstation.
@MainActor
struct SettingsView: View {
    @Environment(WorkstationState.self) private var appState

    @AppStorage("editorFontSize") private var editorFontSize: Double = 13
    @AppStorage("showLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("defaultMLLPPort") private var defaultMLLPPort: String = "2575"

    var body: some View {
        TabView {
            Form {
                Section("Editor") {
                    Slider(value: $editorFontSize, in: 10...24, step: 1) {
                        Text("Font Size: \(Int(editorFontSize)) pt")
                    }
                    Toggle("Show Line Numbers", isOn: $showLineNumbers)
                }
            }
            .tabItem { Label("General", systemImage: "gear") }
            .frame(width: 400, height: 200)

            Form {
                Section("MLLP Defaults") {
                    TextField("Default Port", text: $defaultMLLPPort)
                        .frame(width: 100)
                }
            }
            .tabItem { Label("Network", systemImage: "network") }
            .frame(width: 400, height: 200)
        }
        .padding()
    }
}

// MARK: - Shared UI Components

/// Compact key/value row used across workstation panels.
struct WorkstationDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .textSelection(.enabled)
        }
    }
}

/// A colored status badge used for segment counts, pass/fail, etc.
struct WorkstationBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Date Formatting

extension Date {
    /// Compact timestamp for log display (HH:mm:ss.SSS).
    var workstationTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: self)
    }
}
#endif
