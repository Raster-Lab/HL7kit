/// HL7kitDemoApp.swift
/// Main entry point for the HL7kit iOS demo application.
///
/// This SwiftUI app provides a tabbed interface showcasing the core
/// capabilities of the HL7kit library: message viewing/editing,
/// network testing with MLLP and FHIR, validation, and performance
/// benchmarking.
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

/// The main application struct providing TabView-based navigation.
@main
@MainActor
struct HL7kitDemoApp: App {
    /// Shared view model that coordinates state across tabs.
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

// MARK: - Root Content View

/// Root view hosting the tab navigation.
@MainActor
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            MessageViewerView()
                .tabItem {
                    Label("Messages", systemImage: "doc.text.magnifyingglass")
                }

            NetworkTestingView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }

            ValidationShowcaseView()
                .tabItem {
                    Label("Validation", systemImage: "checkmark.shield")
                }

            PerformanceDemoView()
                .tabItem {
                    Label("Performance", systemImage: "gauge.with.dots.needle.33percent")
                }
        }
        .tint(.blue)
    }
}

// MARK: - Application State

/// Observable application state shared across all tabs.
///
/// Uses the `@Observable` macro (iOS 17+) for lightweight reactivity
/// without requiring `ObservableObject` + `@Published`.
@Observable
@MainActor
final class AppState {
    /// The raw HL7 v2.x message text currently loaded in the editor.
    var currentMessageText: String = SampleMessages.adtA01

    /// Most recently parsed message, if parsing succeeded.
    var parsedMessage: HL7v2Message?

    /// Accumulated log entries across tabs.
    var logEntries: [LogEntry] = []

    /// Appends a timestamped log entry.
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(
            timestamp: Date(),
            message: message,
            level: level
        )
        logEntries.append(entry)
    }
}

// MARK: - Log Types

/// Severity level for log entries displayed in the UI.
enum LogLevel: String, Sendable {
    case info = "ℹ️"
    case success = "✅"
    case warning = "⚠️"
    case error = "❌"

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
struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel
}

// MARK: - Sample Messages

/// Pre-built HL7 v2.x sample messages for quick demos.
enum SampleMessages {
    /// ADT^A01 – Admit/Visit Notification.
    static let adtA01: String = """
        MSH|^~\\&|ADT|HOSPITAL|RCV|FACILITY|20240115120000||ADT^A01^ADT_A01|MSG00001|P|2.5.1
        EVN|A01|20240115120000
        PID|1||12345^^^HOSP^MR||Doe^John^A||19800101|M|||123 Main St^^Springfield^IL^62701||555-555-1234
        PV1|1|I|ICU^101^A|E|||1234^Smith^Jane^^^Dr|||MED||||1|||1234^Smith^Jane^^^Dr|IN||||||||||||||||||||||20240115120000
        """
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "        ", with: "")

    /// ORU^R01 – Observation Result.
    static let oruR01: String = """
        MSH|^~\\&|LAB|HOSPITAL|RCV|FACILITY|20240115130000||ORU^R01^ORU_R01|MSG00002|P|2.5.1
        PID|1||67890^^^HOSP^MR||Smith^Jane^B||19901215|F
        OBR|1|ORD001|LAB001|CBC^Complete Blood Count^LN|||20240115100000
        OBX|1|NM|WBC^White Blood Cell Count^LN||7.5|10*3/uL|4.5-11.0|N|||F
        OBX|2|NM|RBC^Red Blood Cell Count^LN||4.8|10*6/uL|4.0-5.5|N|||F
        OBX|3|NM|HGB^Hemoglobin^LN||14.2|g/dL|12.0-16.0|N|||F
        """
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "        ", with: "")

    /// A deliberately malformed message for validation demos.
    static let invalidMessage: String = """
        MSH|^~\\&|SRC||||||BAD_TYPE|CTL001|P|2.5.1
        PID|1||^^^HOSP^MR||^John||INVALID_DATE|X
        """
        .trimmingCharacters(in: .whitespaces)
        .replacingOccurrences(of: "        ", with: "")
}

// MARK: - Shared UI Components

/// A styled section header used across multiple tabs.
struct SectionHeaderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

/// Displays a key/value pair in a compact row.
struct DetailRow: View {
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
                .foregroundStyle(.primary)
        }
    }
}

/// A reusable status badge with color coding.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Date Formatting

extension Date {
    /// Compact timestamp string for log display.
    var logTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: self)
    }
}
#endif
