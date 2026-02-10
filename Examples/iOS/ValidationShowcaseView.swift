/// ValidationShowcaseView.swift
/// Demonstrates HL7 v2.x and FHIR resource validation capabilities.
///
/// Users can load sample messages (both valid and intentionally broken),
/// run the validation engine, and inspect the results with severity
/// color coding and detailed diagnostics.

#if canImport(SwiftUI)
import SwiftUI
import HL7Core
import HL7v2Kit
import FHIRkit

// MARK: - Validation Showcase View

/// Showcases the library's validation framework for both HL7 v2.x
/// messages and FHIR resources.
@MainActor
struct ValidationShowcaseView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedTab: ValidationTab = .hl7v2
    @State private var v2Results: [ValidationDisplayItem] = []
    @State private var fhirResults: [ValidationDisplayItem] = []
    @State private var isValidating = false
    @State private var selectedSample: SampleOption = .adtA01

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Standard", selection: $selectedTab) {
                    Text("HL7 v2.x").tag(ValidationTab.hl7v2)
                    Text("FHIR R4").tag(ValidationTab.fhir)
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case .hl7v2: hl7v2ValidationPanel
                case .fhir:  fhirValidationPanel
                }
            }
            .navigationTitle("Validation")
        }
    }

    // MARK: - HL7 v2.x Validation

    @ViewBuilder
    private var hl7v2ValidationPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                samplePicker
                runValidationButton { await validateHL7v2() }
                conformanceProfileCard
                resultsSection(v2Results)
            }
            .padding()
        }
    }

    /// Picker for selecting a pre-built sample message.
    private var samplePicker: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Sample Message", systemImage: "doc.badge.gearshape")

                Picker("Sample", selection: $selectedSample) {
                    ForEach(SampleOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedSample) {
                    appState.currentMessageText = selectedSample.messageText
                    v2Results = []
                }

                Text(appState.currentMessageText.prefix(200) + "…")
                    .font(.system(.caption2, design: .monospaced))
                    .lineLimit(5)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    /// Shows metadata about the conformance profile being applied.
    private var conformanceProfileCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "Conformance Profile", systemImage: "list.clipboard")
                DetailRow(label: "Standard", value: "HL7 v2.5.1")
                DetailRow(label: "Checks", value: "Segment order, required fields, data types")
                DetailRow(label: "Encoding", value: "Standard delimiters (|^~\\&)")
            }
        }
    }

    /// Validates the current HL7 v2.x message using `HL7v2Message.validate()`.
    ///
    /// The library's `validate()` method throws on failure, so a successful
    /// call with no error indicates a valid message.
    private func validateHL7v2() async {
        isValidating = true
        v2Results = []
        appState.log("Validating HL7 v2.x message…", level: .info)

        let text = appState.currentMessageText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let message = try HL7v2Message.parse(text)
            try message.validate()

            v2Results = [
                ValidationDisplayItem(
                    severity: .info,
                    message: "Message is valid",
                    location: "—",
                    detail: "All segments and required fields conform to the specification."
                )
            ]
            appState.log("Validation passed", level: .success)
        } catch let error as HL7Error {
            let description: String
            switch error {
            case .validationError(let msg, _): description = msg
            case .invalidFormat(let msg, _):   description = msg
            case .missingRequiredField(let msg, _): description = msg
            case .parsingError(let msg, _):    description = msg
            default:                           description = "\(error)"
            }
            v2Results = [
                ValidationDisplayItem(
                    severity: .error,
                    message: description,
                    location: "Message",
                    detail: nil
                )
            ]
            appState.log("Validation failed: \(description)", level: .error)
        } catch {
            v2Results = [
                ValidationDisplayItem(
                    severity: .error,
                    message: "Unexpected error: \(error.localizedDescription)",
                    location: "Message",
                    detail: nil
                )
            ]
            appState.log("Validation error: \(error)", level: .error)
        }

        isValidating = false
    }

    // MARK: - FHIR Validation

    @ViewBuilder
    private var fhirValidationPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                fhirSampleCard
                runValidationButton { await validateFHIRResource() }
                resultsSection(fhirResults)
            }
            .padding()
        }
    }

    /// Displays the sample FHIR Patient that will be validated.
    private var fhirSampleCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "FHIR Patient Resource", systemImage: "person.text.rectangle")

                Text("A sample Patient resource with intentionally missing\nfields to demonstrate validation rules.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    DetailRow(label: "Resource", value: "Patient")
                    DetailRow(label: "Name", value: "Demo, HL7kit")
                    DetailRow(label: "Gender", value: "male")
                    DetailRow(label: "Birth Date", value: "1990-01-15")
                    DetailRow(label: "Identifier", value: "(missing – should trigger warning)")
                }
            }
        }
    }

    /// Validates a sample `Patient` resource using `FHIRValidator`.
    ///
    /// `FHIRValidator.validate(_:)` returns a `FHIRValidationOutcome` whose
    /// `issues` array contains `FHIRValidationIssue` values with typed
    /// `severity` (an `IssueSeverity` enum) and `details` string.
    private func validateFHIRResource() async {
        isValidating = true
        fhirResults = []
        appState.log("Validating FHIR Patient…", level: .info)

        let patient = Patient(
            resourceType: "Patient",
            id: "demo-001",
            name: [
                HumanName(use: "official", family: "Demo", given: ["HL7kit"])
            ],
            gender: "male",
            birthDate: "1990-01-15"
        )

        let validator = FHIRValidator()
        let outcome = validator.validate(patient)

        if outcome.isValid {
            fhirResults = [
                ValidationDisplayItem(
                    severity: .info,
                    message: "Patient resource is valid",
                    location: "Patient/demo-001",
                    detail: "All required elements present. Resource conforms to base profile."
                )
            ]
            appState.log("FHIR validation passed", level: .success)
        } else {
            fhirResults = outcome.issues.map { issue in
                ValidationDisplayItem(
                    severity: mapFHIRSeverity(issue.severity),
                    message: issue.details,
                    location: issue.expression ?? "unknown",
                    detail: "Code: \(issue.code.rawValue)"
                )
            }
            appState.log("FHIR validation: \(outcome.issues.count) issue(s)", level: .warning)
        }

        isValidating = false
    }

    // MARK: - Shared UI

    /// A prominent button that triggers a validation action.
    private func runValidationButton(_ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "checkmark.shield")
                }
                Text(isValidating ? "Validating…" : "Run Validation")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isValidating)
    }

    /// Renders a list of validation results with severity indicators.
    @ViewBuilder
    private func resultsSection(_ items: [ValidationDisplayItem]) -> some View {
        if !items.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeaderView(title: "Results", systemImage: "checklist")

                    ForEach(items) { item in
                        ValidationIssueRow(item: item)
                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Maps FHIR `IssueSeverity` enum to display severity.
    private func mapFHIRSeverity(_ severity: IssueSeverity) -> DisplaySeverity {
        switch severity {
        case .error, .fatal: return .error
        case .warning:       return .warning
        case .information:   return .info
        }
    }
}

// MARK: - Display Models

/// Tab selection for the validation panel.
enum ValidationTab: String, CaseIterable, Sendable {
    case hl7v2 = "HL7 v2.x"
    case fhir  = "FHIR R4"
}

/// Pre-built sample message options.
enum SampleOption: String, CaseIterable, Identifiable, Sendable {
    case adtA01 = "adt"
    case oruR01 = "oru"
    case invalid = "invalid"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adtA01:  return "ADT^A01 – Admit (valid)"
        case .oruR01:  return "ORU^R01 – Lab Result (valid)"
        case .invalid: return "Malformed Message (errors)"
        }
    }

    var messageText: String {
        switch self {
        case .adtA01:  return SampleMessages.adtA01
        case .oruR01:  return SampleMessages.oruR01
        case .invalid: return SampleMessages.invalidMessage
        }
    }
}

/// Severity level for UI display.
enum DisplaySeverity: String, Sendable {
    case error, warning, info

    var icon: String {
        switch self {
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .green
        }
    }
}

/// A single validation result for display in the results list.
struct ValidationDisplayItem: Identifiable, Sendable {
    let id = UUID()
    let severity: DisplaySeverity
    let message: String
    let location: String
    let detail: String?
}

// MARK: - Validation Issue Row

/// Renders one validation issue with an icon, message, and location.
struct ValidationIssueRow: View {
    let item: ValidationDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.severity.icon)
                    .foregroundStyle(item.severity.color)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if !item.location.isEmpty {
                            Label(item.location, systemImage: "mappin.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let detail = item.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
#endif
