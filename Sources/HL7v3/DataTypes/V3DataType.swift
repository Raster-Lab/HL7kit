import HL7Core

/// HL7 v3 data types used throughout the RIM and CDA.

/// Instance Identifier (II) — a unique identifier with root OID and extension.
public struct InstanceIdentifier: Sendable, Equatable {
    /// The root OID.
    public var root: String
    /// The extension value.
    public var `extension`: String?

    public init(root: String, extension: String? = nil) {
        self.root = root
        self.extension = `extension`
    }
}

/// A coded value (CD/CE/CS) with code system reference.
public struct CodedValue: Sendable, Equatable {
    /// The code value.
    public var code: String
    /// The code system OID.
    public var codeSystem: String?
    /// The code system name.
    public var codeSystemName: String?
    /// Human-readable display name.
    public var displayName: String?

    public init(
        code: String,
        codeSystem: String? = nil,
        codeSystemName: String? = nil,
        displayName: String? = nil
    ) {
        self.code = code
        self.codeSystem = codeSystem
        self.codeSystemName = codeSystemName
        self.displayName = displayName
    }
}

/// Null flavor values indicating why a value is absent.
public enum NullFlavor: String, Sendable, Equatable {
    /// No information.
    case noInformation = "NI"
    /// Other.
    case other = "OTH"
    /// Masked.
    case masked = "MSK"
    /// Not applicable.
    case notApplicable = "NA"
    /// Unknown.
    case unknown = "UNK"
    /// Asked but unknown.
    case askedButUnknown = "ASKU"
    /// Not asked.
    case notAsked = "NASK"
    /// Temporarily unavailable.
    case temporarilyUnavailable = "NAV"
}
