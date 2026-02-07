/// The result of validating an HL7 message or component.
public struct ValidationResult: Sendable, Equatable {
    /// The severity of a validation finding.
    public enum Severity: Sendable, Equatable {
        case error
        case warning
        case info
    }

    /// A single validation finding.
    public struct Issue: Sendable, Equatable {
        public let severity: Severity
        public let message: String
        public let location: String?

        public init(severity: Severity, message: String, location: String? = nil) {
            self.severity = severity
            self.message = message
            self.location = location
        }
    }

    public let issues: [Issue]

    /// Whether validation passed with no errors.
    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    public init(issues: [Issue] = []) {
        self.issues = issues
    }
}

/// A type that supports validation against HL7 rules.
public protocol HL7Validatable: Sendable {
    /// Validate the receiver and return a result.
    func validate() -> ValidationResult
}
